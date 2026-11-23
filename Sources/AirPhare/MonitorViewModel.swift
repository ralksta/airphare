import AppKit
import Foundation
import AirPhareCore
import Network
import ServiceManagement

@Observable
@MainActor
final class MonitorViewModel {
    private static let legacySettingsKey = "de.ralksta.airphare.settings.v1"
    private static let settingsKey = "de.ralksta.airphare.settings.v2"

    var wifi: WiFiSnapshot?
    var latency: LatencySnapshot?
    var dns: DNSSnapshot?
    var rfScan: RFScanResult?
    var networkQuality: NetworkQualityResult?
    var report: HealthReport
    var history: [CheckSample] = []
    var logEntryCount: Int = 0

    // Wi-Fi control center state
    var wifiPowerOn: Bool = true
    var preferredNetworks: [String] = []
    var nearbyNetworks: [NearbyNetwork] = []
    var isScanningNearby = false
    var nearbyNeedsLocationPermission = false
    var connectingSSID: String?
    var connectionError: String?
    private var lastNearbyScanDate: Date?

    var isChecking = false
    var isRunningBenchmark = false
    var isRunningRFScan = false
    var isReconnecting = false
    var progressMessage: String?
    var lastCheckDate: Date?
    var launchAtLoginEnabled = false

    var settings: MonitorSettings {
        didSet {
            saveSettings()
            if oldValue.checkIntervalMinutes != settings.checkIntervalMinutes {
                restartScheduler()
            }
            recomputeReport(sendNotifications: false)
        }
    }

    var lang: ResolvedLanguage {
        settings.language.resolved()
    }

    private let service = DiagnosticsService()
    let historyLogger = HistoryLogger()
    let notifications = AlertNotificationManager()
    var onMenuBarUpdate: (() -> Void)?
    private var schedulerTask: Task<Void, Never>?
    private var pathMonitor: NWPathMonitor?
    private var pathChangeTask: Task<Void, Never>?
    private var didStart = false

    init() {
        let loadedSettings: MonitorSettings
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(MonitorSettings.self, from: data) {
            loadedSettings = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: Self.legacySettingsKey),
                  var migrated = try? JSONDecoder().decode(MonitorSettings.self, from: legacyData) {
            migrated.showMenuBarMetrics = false
            loadedSettings = migrated
            if let encoded = try? JSONEncoder().encode(migrated) {
                UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
            }
        } else {
            loadedSettings = .default
        }
        self.settings = loadedSettings
        let initialLang = loadedSettings.language.resolved()
        self.report = HealthReport(
            severity: .ok,
            headline: L10n.t(.startingFirstCheck, lang: initialLang),
            alerts: [],
            bottleneckSummary: L10n.t(.waitingForMetrics, lang: initialLang)
        )
        refreshLaunchAtLoginState()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        notifications.onLocationAuthChanged = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshOnLocationGranted()
            }
        }
        notifications.requestPermissionsIfAvailable()
        startPathMonitor()
        restartScheduler()
        Task {
            self.history = await historyLogger.loadRecentSamples(limit: 48)
            self.logEntryCount = await historyLogger.entryCount()
            await runLightweightCheck()
        }
    }

    func onPopoverOpen() {
        guard wifiPowerOn else { return }
        Task {
            await refreshNearbyNetworks(forceActiveScan: false)
        }
    }

    private func refreshOnLocationGranted() async {
        let snap = await service.collectWiFiSnapshot()
        self.wifi = snap
        self.wifiPowerOn = snap.powerOn
        await refreshNearbyNetworks(forceActiveScan: true)
    }

    var menuBarTitle: String {
        guard settings.showMenuBarMetrics else { return "" }
        guard let wifi, wifi.isConnected else { return L10n.t(.offline, lang: lang) }
        return "\(wifi.band.shortLabel) K\(wifi.channel) · \(wifi.snr)dB"
    }

    var menuBarSymbol: String {
        if !wifiPowerOn {
            return "wifi.slash"
        }
        switch report.severity {
        case .ok: return "wifi"
        case .warning: return "wifi.exclamationmark"
        case .critical: return "wifi.slash"
        }
    }

    /// Known networks actually in range right now (matching Apple's Wi-Fi menu behavior).
    /// Falls back to top 2 saved networks only if macOS hides nearby SSIDs (missing Location permission).
    var displayedKnownNetworks: [String] {
        var list: [String] = []
        if let active = wifi?.ssid, !active.isEmpty {
            list.append(active)
        }

        if !nearbyNetworks.isEmpty {
            let inRangeKnown = nearbyNetworks.filter { $0.isKnown }.map(\.ssid)
            for ssid in inRangeKnown where !list.contains(ssid) {
                list.append(ssid)
            }
            return list
        }

        for ssid in preferredNetworks where !list.contains(ssid) {
            list.append(ssid)
            if list.count >= 2 { break }
        }
        return list
    }

    var otherNearbyNetworks: [NearbyNetwork] {
        let shown = Set(displayedKnownNetworks)
        return nearbyNetworks.filter { !shown.contains($0.ssid) }
    }

    func runLightweightCheck(eventType: LogEventType = .check) async {
        guard !isChecking && !isRunningBenchmark && !isReconnecting else { return }
        isChecking = true
        progressMessage = L10n.t(.progChecking, lang: lang)
        defer {
            isChecking = false
            progressMessage = nil
        }

        let wifiSnap = await service.collectWiFiSnapshot()
        self.wifi = wifiSnap
        self.wifiPowerOn = wifiSnap.powerOn

        if preferredNetworks.isEmpty {
            self.preferredNetworks = await service.fetchPreferredNetworks(interfaceName: wifiSnap.interfaceName)
        }

        let cached = await service.cachedNearbyNetworks(knownSSIDs: Set(preferredNetworks))
        if !cached.networks.isEmpty {
            self.nearbyNetworks = cached.networks
            self.nearbyNeedsLocationPermission = false
        } else if cached.locationRequired {
            self.nearbyNeedsLocationPermission = true
        }

        if wifiSnap.isConnected {
            let latSnap = await service.runIdleLatencyCheck(packetCount: 5)
            self.latency = latSnap

            let dnsSnap = await service.runDNSCheck()
            self.dns = dnsSnap

            let sample = CheckSample(
                snr: wifiSnap.snr,
                gatewayAvgMs: latSnap.gateway?.avgMs,
                internetAvgMs: latSnap.ipv4Internet?.avgMs,
                ipv6Reachable: latSnap.ipv6Internet?.isReachable,
                channel: wifiSnap.channel,
                band: wifiSnap.band
            )
            history.append(sample)
            if history.count > 48 {
                history.removeFirst(history.count - 48)
            }
        } else {
            self.latency = nil
            self.dns = nil
        }

        lastCheckDate = .now
        recomputeReport(sendNotifications: true)
        await recordLog(eventType: eventType, includeNetworkQuality: false)
    }

    func runRFScanOnly() async {
        guard !isRunningRFScan && !isRunningBenchmark && !isReconnecting else { return }
        isRunningRFScan = true
        progressMessage = L10n.t(.progScanningNeighbors, lang: lang)
        defer {
            isRunningRFScan = false
            progressMessage = nil
        }

        let scan = await service.runRFScan(lang: lang)
        self.rfScan = scan
        recomputeReport(sendNotifications: false)
        await recordLog(eventType: .rfScan, includeNetworkQuality: false)
    }

    /// Full sequential benchmark: 1) Wi-Fi + RF Scan -> 2) Idle Pings (15x) -> 3) DNS -> 4) networkQuality
    func runFullBenchmark() async {
        guard !isRunningBenchmark && !isReconnecting else { return }
        isRunningBenchmark = true
        defer {
            isRunningBenchmark = false
            progressMessage = nil
        }

        progressMessage = L10n.t(.progBenchStep1, lang: lang)
        let wifiSnap = await service.collectWiFiSnapshot()
        self.wifi = wifiSnap
        self.rfScan = await service.runRFScan(lang: lang)

        guard wifiSnap.isConnected else {
            recomputeReport(sendNotifications: false)
            await recordLog(eventType: .benchmark, includeNetworkQuality: false)
            return
        }

        progressMessage = L10n.t(.progBenchStep2, lang: lang)
        let latSnap = await service.runIdleLatencyCheck(packetCount: 15)
        self.latency = latSnap

        progressMessage = L10n.t(.progBenchStep3, lang: lang)
        let dnsSnap = await service.runDNSCheck()
        self.dns = dnsSnap

        progressMessage = L10n.t(.progBenchStep4, lang: lang)
        if let nq = await service.runNetworkQuality(maxRuntimeSeconds: 15) {
            self.networkQuality = nq
        }

        let sample = CheckSample(
            snr: wifiSnap.snr,
            gatewayAvgMs: latSnap.gateway?.avgMs,
            internetAvgMs: latSnap.ipv4Internet?.avgMs,
            ipv6Reachable: latSnap.ipv6Internet?.isReachable,
            channel: wifiSnap.channel,
            band: wifiSnap.band
        )
        history.append(sample)
        if history.count > 48 {
            history.removeFirst(history.count - 48)
        }

        lastCheckDate = .now
        recomputeReport(sendNotifications: false)
        await recordLog(eventType: .benchmark, includeNetworkQuality: true)
    }

    func reconnectWiFi() async {
        guard !isReconnecting else { return }
        isReconnecting = true
        progressMessage = L10n.t(.progReconnecting, lang: lang)
        defer {
            isReconnecting = false
            progressMessage = nil
        }

        let iface = wifi?.interfaceName ?? "en0"
        _ = await service.reconnectWiFi(interfaceName: iface)
        notifications.resetCooldowns()
        isReconnecting = false
        await runLightweightCheck(eventType: .wifiReset)
    }

    func openLogFolder() {
        let dir = historyLogger.directoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: historyLogger.csvFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([historyLogger.csvFileURL])
        } else {
            NSWorkspace.shared.open(dir)
        }
    }

    private func recordLog(eventType: LogEventType, includeNetworkQuality: Bool) async {
        // Always evaluate an English report for consistent English CSV logs regardless of UI language
        let englishReport = HealthEvaluator.evaluate(
            wifi: wifi,
            latency: latency,
            dns: dns,
            rfScan: rfScan,
            settings: settings,
            lang: .en
        )
        await historyLogger.log(
            eventType: eventType,
            wifi: wifi,
            latency: latency,
            dns: dns,
            rfScan: rfScan,
            networkQuality: includeNetworkQuality ? networkQuality : nil,
            report: englishReport
        )
        self.logEntryCount = await historyLogger.entryCount()
    }

    func performQuickAction(_ action: QuickAction) {
        switch action {
        case .reconnectWiFi:
            Task { await reconnectWiFi() }
        case .runRFScan:
            Task { await runRFScanOnly() }
        case .openRouterSettings:
            openRouterURL()
        case .none:
            break
        }
    }

    func openRouterURL() {
        let trimmed = settings.routerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else { return }
        NSWorkspace.shared.open(url)
    }

    func openSystemWiFiSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func toggleWiFiPower(_ enabled: Bool) async {
        guard !isReconnecting else { return }
        wifiPowerOn = enabled
        onMenuBarUpdate?()
        connectionError = nil
        isReconnecting = true
        progressMessage = L10n.t(enabled ? .progTurningOn : .progTurningOff, lang: lang)
        defer {
            isReconnecting = false
            progressMessage = nil
        }

        let iface = wifi?.interfaceName ?? "en0"
        _ = await service.setWiFiPower(enabled: enabled, interfaceName: iface)
        isReconnecting = false
        await runLightweightCheck()
    }

    func scanNearbyForPicker() async {
        await refreshNearbyNetworks(forceActiveScan: true)
    }

    private func refreshNearbyNetworks(forceActiveScan: Bool) async {
        guard !isScanningNearby && wifiPowerOn else { return }

        let iface = wifi?.interfaceName ?? "en0"
        if preferredNetworks.isEmpty {
            preferredNetworks = await service.fetchPreferredNetworks(interfaceName: iface)
        }
        let knownSet = Set(preferredNetworks)

        let cached = await service.cachedNearbyNetworks(knownSSIDs: knownSet)
        if !cached.networks.isEmpty {
            nearbyNetworks = cached.networks
            nearbyNeedsLocationPermission = false
            if !forceActiveScan { return }
        }

        if !forceActiveScan,
           let last = lastNearbyScanDate,
           Date().timeIntervalSince(last) < 120 {
            return
        }

        guard !isChecking && !isRunningBenchmark && !isReconnecting else { return }

        isScanningNearby = true
        defer { isScanningNearby = false }

        let result = await service.scanNearbyNetworks(knownSSIDs: knownSet)
        lastNearbyScanDate = .now
        nearbyNetworks = result.networks
        nearbyNeedsLocationPermission = result.locationRequired
    }

    func connectToNetwork(ssid: String, password: String? = nil) async {
        guard connectingSSID == nil else { return }
        connectingSSID = ssid
        connectionError = nil
        progressMessage = L10n.fmt(.progConnectingTo, lang: lang, ssid)
        defer {
            connectingSSID = nil
            progressMessage = nil
        }

        let iface = wifi?.interfaceName ?? "en0"
        let res = await service.connectToNetwork(ssid: ssid, password: password, interfaceName: iface, lang: lang)
        if res.success {
            preferredNetworks = await service.fetchPreferredNetworks(interfaceName: iface)
            notifications.resetCooldowns()
            connectingSSID = nil
            await runLightweightCheck()
        } else {
            connectionError = res.message
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginState()
        } catch {
            refreshLaunchAtLoginState()
        }
    }

    private func refreshLaunchAtLoginState() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            launchAtLoginEnabled = false
            return
        }
        launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
    }

    private func recomputeReport(sendNotifications: Bool) {
        let evaluated = HealthEvaluator.evaluate(
            wifi: wifi,
            latency: latency,
            dns: dns,
            rfScan: rfScan,
            settings: settings,
            lang: lang
        )
        self.report = evaluated
        onMenuBarUpdate?()
        if sendNotifications {
            notifications.notifyIfNeeded(alerts: evaluated.alerts, enabled: settings.notificationsEnabled)
        }
    }

    private func restartScheduler() {
        schedulerTask?.cancel()
        let minutes = max(1, settings.checkIntervalMinutes)
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(minutes * 60))
                guard !Task.isCancelled else { break }
                await self?.runLightweightCheck()
            }
        }
    }

    private func startPathMonitor() {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pathChangeTask?.cancel()
                self.pathChangeTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(6))
                    guard !Task.isCancelled else { return }
                    await self?.runLightweightCheck()
                }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .utility))
        self.pathMonitor = monitor
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.settingsKey)
        }
    }
}

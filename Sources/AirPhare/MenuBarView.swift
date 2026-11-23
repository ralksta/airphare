import AirPhareCore
import SwiftUI

struct MenuBarView: View {
    private enum PopoverTab: Hashable {
        case live
        case stats
    }

    @Bindable var vm: MonitorViewModel
    @State private var selectedTab: PopoverTab = .live
    @State private var showSettings = false
    @State private var showOtherNetworks = false
    @State private var passwordPromptSSID: String?
    @State private var passwordInput = ""

    private var lang: ResolvedLanguage { vm.lang }
    private func t(_ key: L10nKey) -> String { L10n.t(key, lang: lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            if showSettings {
                SettingsInlineView(vm: vm, onClose: { showSettings = false })
            } else {
                Picker("", selection: $selectedTab) {
                    Text(t(.tabLive)).tag(PopoverTab.live)
                    Text(t(.tabStats)).tag(PopoverTab.stats)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if selectedTab == .stats {
                    StatsView(vm: vm)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        if vm.wifiPowerOn {
                            networksPickerSection
                        }

                        if !vm.report.alerts.isEmpty {
                            alertsSection
                        }

                        if vm.wifiPowerOn {
                            wifiCard
                            latencyAndDNSCard

                            if let nq = vm.networkQuality {
                                networkQualityCard(nq)
                            }

                            if let rf = vm.rfScan {
                                rfRecommendationCard(rf)
                            }

                            if vm.history.count >= 2 {
                                historyCard
                            }
                        }
                    }
                }

                Divider()
                actionBar
            }
        }
        .padding(14)
        .frame(width: 395)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            vm.startIfNeeded()
        }
        .onChange(of: showOtherNetworks) { _, expanded in
            if expanded {
                Task { await vm.scanNearbyForPicker() }
            } else {
                passwordPromptSSID = nil
                passwordInput = ""
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(t(.wifiTitle))
                        .font(.headline)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(vm.wifiPowerOn ? vm.report.headline : t(.wifiOff))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let msg = vm.progressMessage {
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let date = vm.lastCheckDate {
                    Text(L10n.fmt(.statusUpdatedAt, lang: lang, date.formatted(date: .omitted, time: .shortened), vm.settings.checkIntervalMinutes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { vm.wifiPowerOn },
                set: { newValue in
                    Task { await vm.toggleWiFiPower(newValue) }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(vm.isReconnecting)
            .accessibilityLabel(t(.toggleWiFiAccessibility))

            Button {
                showSettings.toggle()
            } label: {
                Image(systemName: showSettings ? "xmark.circle" : "gearshape")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showSettings ? t(.closeSettingsAccessibility) : t(.openSettingsAccessibility))
        }
    }

    private var networksPickerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(t(.knownNetworks))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if vm.displayedKnownNetworks.isEmpty {
                    Text(t(.noSavedNetworks))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.displayedKnownNetworks, id: \.self) { ssid in
                        knownNetworkRow(ssid: ssid)
                    }
                }

                if vm.wifi?.isConnected == true && vm.wifi?.ssid == nil {
                    HStack(spacing: 6) {
                        Text(t(.locationHintKnown))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(t(.allowButton)) {
                            vm.notifications.requestLocationForSSID()
                        }
                        .controlSize(.mini)
                    }
                    .padding(.top, 2)
                }

                if let err = vm.connectionError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }

                Divider()
                    .padding(.vertical, 2)

                DisclosureGroup(isExpanded: $showOtherNetworks) {
                    otherNetworksList
                        .padding(.top, 4)
                } label: {
                    HStack {
                        Text(t(.otherNetworks))
                            .font(.caption.weight(.medium))
                        if vm.isScanningNearby {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                }
            }
        }
    }

    private func knownNetworkRow(ssid: String) -> some View {
        let isActive = (vm.wifi?.isConnected == true) && (vm.wifi?.ssid == ssid)
        let isConnecting = (vm.connectingSSID == ssid)

        return Button {
            guard !isActive else { return }
            Task { await vm.connectToNetwork(ssid: ssid) }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: 24, height: 24)
                    Image(systemName: "wifi")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isActive ? .white : .primary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(ssid)
                        .font(.subheadline.weight(isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isActive, let wifi = vm.wifi {
                        Text("\(wifi.band.shortLabel) · K\(wifi.channel) · \(wifi.snr) dB SNR")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                } else if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(vm.connectingSSID != nil || vm.isReconnecting)
        .accessibilityLabel(isActive ? L10n.fmt(.connectedA11y, lang: lang, ssid) : L10n.fmt(.connectToA11y, lang: lang, ssid))
    }

    @ViewBuilder
    private var otherNetworksList: some View {
        if vm.isScanningNearby && vm.otherNearbyNetworks.isEmpty {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(t(.scanningNearby))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else if vm.nearbyNeedsLocationPermission {
            VStack(alignment: .leading, spacing: 6) {
                Text(t(.locationHintNearby))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button(t(.allowLocationButton)) {
                    vm.notifications.requestLocationForSSID()
                }
                .controlSize(.small)
            }
            .padding(.vertical, 4)
        } else if vm.otherNearbyNetworks.isEmpty {
            HStack {
                Text(t(.noOtherNetworks))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(t(.rescanButton)) {
                    Task { await vm.scanNearbyForPicker() }
                }
                .controlSize(.mini)
            }
            .padding(.vertical, 2)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(vm.otherNearbyNetworks.prefix(10)) { net in
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                if net.isSecure && !net.isKnown {
                                    if passwordPromptSSID == net.ssid {
                                        passwordPromptSSID = nil
                                    } else {
                                        passwordPromptSSID = net.ssid
                                        passwordInput = ""
                                    }
                                } else {
                                    Task { await vm.connectToNetwork(ssid: net.ssid) }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "wifi")
                                        .font(.caption)
                                        .frame(width: 18)
                                    Text(net.ssid)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(net.band.shortLabel) K\(net.channel)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    if net.isSecure {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)

                            if passwordPromptSSID == net.ssid {
                                HStack(spacing: 6) {
                                    SecureField(t(.wifiPasswordPlaceholder), text: $passwordInput)
                                        .textFieldStyle(.roundedBorder)
                                        .controlSize(.small)
                                        .onSubmit {
                                            submitOtherNetworkPassword(ssid: net.ssid)
                                        }
                                    Button(t(.connectButton)) {
                                        submitOtherNetworkPassword(ssid: net.ssid)
                                    }
                                    .controlSize(.small)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(passwordInput.isEmpty || vm.connectingSSID != nil)
                                }
                                .padding(.leading, 22)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }

    private func submitOtherNetworkPassword(ssid: String) {
        let pw = passwordInput
        passwordPromptSSID = nil
        passwordInput = ""
        Task { await vm.connectToNetwork(ssid: ssid, password: pw) }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(vm.report.alerts) { alert in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: alert.severity == .critical ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(alert.severity == .critical ? .red : .orange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .font(.subheadline.weight(.semibold))
                            Text(alert.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(L10n.fmt(.alertTipPrefix, lang: lang, alert.actionHint))
                                .font(.caption.weight(.medium))
                        }
                    }

                    if alert.quickAction != .none {
                        HStack {
                            Spacer()
                            Button(actionLabel(for: alert.quickAction)) {
                                vm.performQuickAction(alert.quickAction)
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                            .tint(alert.severity == .critical ? .red : .orange)
                            .disabled(vm.isReconnecting || vm.isRunningBenchmark)
                        }
                    }
                }
                .padding(9)
                .background((alert.severity == .critical ? Color.red : Color.orange).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var wifiCard: some View {
        GroupBox {
            if let wifi = vm.wifi, wifi.isConnected {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(L10n.fmt(.cardRadioLink, lang: lang, wifi.interfaceName), systemImage: "dot.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(wifi.phyMode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        metricColumn(title: t(.metricBandChannel), value: "\(wifi.band.shortLabel) · K\(wifi.channel) (\(wifi.channelWidthMHz)M)")
                        metricColumn(title: t(.metricSignalSNR), value: "\(wifi.rssi) dBm · \(wifi.snr) dB")
                        metricColumn(title: t(.metricLinkRate), value: "\(Int(wifi.txRateMbps)) Mbps")
                    }

                    HStack(spacing: 6) {
                        let prefixCount = wifi.activeGlobalIPv6Prefixes.count
                        Image(systemName: prefixCount == 1 ? "checkmark.shield" : (prefixCount > 1 ? "exclamationmark.shield" : "minus.circle"))
                            .font(.caption)
                            .foregroundStyle(prefixCount == 1 ? .green : (prefixCount > 1 ? .orange : .secondary))
                        Text(ipv6PrefixSummary(wifi))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } else {
                Text(t(.noActiveWiFi))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var latencyAndDNSCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(t(.cardLatencyDNS), systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(wifiVsIspBadge)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(wifiVsIspColor.opacity(0.15))
                        .foregroundStyle(wifiVsIspColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    metricColumn(
                        title: t(.metricRouterHop1),
                        value: formatPing(vm.latency?.gateway)
                    )
                    metricColumn(
                        title: t(.metricIPv4),
                        value: formatPing(vm.latency?.ipv4Internet)
                    )
                    metricColumn(
                        title: t(.metricIPv6),
                        value: formatPing(vm.latency?.ipv6Internet, missingLabel: "–")
                    )
                }

                if let dns = vm.dns {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            metricColumn(
                                title: dns.activeResolver ?? "DNS",
                                value: dns.activeLatencyMs.map { "\($0) ms" } ?? "–"
                            )
                            metricColumn(
                                title: "1.1.1.1",
                                value: dns.referenceLatencyMs.map { "\($0) ms" } ?? "–"
                            )
                            metricColumn(
                                title: "8.8.8.8",
                                value: dns.googleLatencyMs.map { "\($0) ms" } ?? "–"
                            )
                            if let gw = dns.routerHost, gw != dns.activeResolver {
                                metricColumn(
                                    title: t(.dnsRouterLabel),
                                    value: dns.routerLatencyMs.map { "\($0) ms" } ?? "–"
                                )
                            }
                        }

                        if let best = dns.fastestServer {
                            Text(L10n.fmt(.dnsFastestBadge, lang: lang, best.label, best.latencyMs))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
    }

    private func networkQualityCard(_ nq: NetworkQualityResult) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(t(.cardThroughputBufferbloat), systemImage: "speedometer")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(nq.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    metricColumn(title: t(.metricDownlink), value: String(format: "%.0f Mbps", nq.downlinkMbps))
                    metricColumn(title: t(.metricUplink), value: String(format: "%.0f Mbps", nq.uplinkMbps))
                    metricColumn(title: t(.metricLoadedRPM), value: "\(Int(nq.loadedLatencyMs)) ms · \(nq.responsivenessRPM)")
                }

                Text(L10n.fmt(
                    .throughputSummary,
                    lang: lang,
                    nq.idleLatencyMs,
                    nq.responsivenessRating(lang: lang),
                    t(nq.ecnEnabled ? .onLabel : .offLabel)
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func rfRecommendationCard(_ rf: RFScanResult) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(L10n.fmt(.cardRFEnvironment, lang: lang, rf.totalNetworks), systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(rf.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let best5 = rf.recommended5GHz {
                    Text(LocalizedStringKey(L10n.fmt(.best5GHzChannel, lang: lang, best5.channel, best5.overlappingAPCount, best5.note)))
                        .font(.caption)
                }
                if let best2 = rf.recommended2GHz {
                    Text(LocalizedStringKey(L10n.fmt(.best2GHzChannel, lang: lang, best2.channel, best2.overlappingAPCount)))
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    ForEach(rf.scores5GHz) { item in
                        VStack(spacing: 1) {
                            Text("K\(item.channel)")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                            Text("\(item.overlappingAPCount) AP")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(item.overlappingAPCount == 0 ? .green : (item.overlappingAPCount == 1 ? .primary : .orange))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
        }
    }

    private var historyCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                let snrValues = vm.history.compactMap { $0.snr.map(Double.init) }
                if snrValues.count >= 2 {
                    SparklineView(values: snrValues, tint: .blue, label: "SNR", unit: "dB", lang: lang)
                }

                let gwValues = vm.history.compactMap { $0.gatewayAvgMs }
                if gwValues.count >= 2 {
                    SparklineView(values: gwValues, tint: .green, label: t(.sparklineHop1Ping), unit: "ms", lang: lang)
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    Task { await vm.runLightweightCheck() }
                } label: {
                    Label(t(.btnQuickCheck), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!vm.wifiPowerOn || vm.isChecking || vm.isRunningBenchmark || vm.isReconnecting)

                Button {
                    Task { await vm.runFullBenchmark() }
                } label: {
                    Label(t(.btnFullBenchmark), systemImage: "bolt.horizontal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.wifiPowerOn || vm.isRunningBenchmark || vm.isReconnecting)
            }
            .controlSize(.small)

            HStack(spacing: 6) {
                Button {
                    Task { await vm.runRFScanOnly() }
                } label: {
                    Label(t(.btnChannelScan), systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(!vm.wifiPowerOn || vm.isRunningRFScan || vm.isRunningBenchmark || vm.isReconnecting)

                Button {
                    Task { await vm.reconnectWiFi() }
                } label: {
                    Label(t(.btnReset), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!vm.wifiPowerOn || vm.isReconnecting || vm.isRunningBenchmark)

                Button {
                    vm.openLogFolder()
                } label: {
                    Label(vm.logEntryCount > 0 ? "\(t(.btnLog)) (\(vm.logEntryCount))" : t(.btnLog), systemImage: "doc.text")
                }
                .accessibilityLabel(t(.btnLogA11y))

                Button {
                    vm.openHTMLReport()
                } label: {
                    Label(
                        vm.reportOpenedFeedback ? t(.btnReportCopied) : t(.btnCopyReport),
                        systemImage: vm.reportOpenedFeedback ? "checkmark" : "doc.richtext"
                    )
                }

                Spacer()

                Button(t(.btnRouter)) {
                    vm.openRouterURL()
                }
            }
            .controlSize(.small)

            HStack {
                Button(t(.btnWiFiSettings)) {
                    vm.openSystemWiFiSettings()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(t(.btnQuit)) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    private func metricColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusIcon: String {
        if !vm.wifiPowerOn { return "wifi.slash" }
        switch vm.report.severity {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        if !vm.wifiPowerOn { return .secondary }
        switch vm.report.severity {
        case .ok: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var wifiVsIspBadge: String {
        if vm.report.alerts.contains(where: { $0.category == .wifiJitter || $0.category == .lowSNR || $0.category == .wrongBand2GHz }) {
            return t(.badgeWiFiIssue)
        }
        if vm.report.alerts.contains(where: { $0.category == .ispIssue }) {
            return t(.badgeISPIssue)
        }
        if vm.report.alerts.contains(where: { $0.category == .ipv6Broken }) {
            return t(.badgeIPv6Down)
        }
        return t(.badgeAllOK)
    }

    private var wifiVsIspColor: Color {
        if vm.report.alerts.contains(where: { $0.severity == .critical }) {
            return .red
        }
        if vm.report.alerts.contains(where: { $0.category == .wifiJitter || $0.category == .ispIssue || $0.category == .wrongBand2GHz }) {
            return .orange
        }
        return .green
    }

    private func ipv6PrefixSummary(_ wifi: WiFiSnapshot) -> String {
        if wifi.activeGlobalIPv6Prefixes.isEmpty {
            return t(.ipv6NoGlobalPrefix)
        }
        if wifi.activeGlobalIPv6Prefixes.count == 1 {
            return L10n.fmt(.ipv6CleanPrefix, lang: lang, wifi.activeGlobalIPv6Prefixes[0])
        }
        return L10n.fmt(.ipv6MultiplePrefixes, lang: lang, wifi.activeGlobalIPv6Prefixes.count)
    }

    private func formatPing(_ stats: PingStats?, missingLabel: String = "–") -> String {
        guard let stats else { return missingLabel }
        if !stats.isReachable {
            return t(.loss100)
        }
        guard let avg = stats.avgMs else { return "OK" }
        if stats.packetLossPercent > 0 {
            return String(format: "%.0f ms (%.0f%%)", avg, stats.packetLossPercent)
        }
        return String(format: "%.1f ms", avg)
    }

    private func actionLabel(for action: QuickAction) -> String {
        switch action {
        case .reconnectWiFi: return t(.actionReconnectWiFi)
        case .runRFScan: return t(.actionRunRFScan)
        case .openRouterSettings: return t(.actionOpenRouter)
        case .none: return ""
        }
    }
}

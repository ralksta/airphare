import CoreWLAN
import Foundation

public actor DiagnosticsService {

    public init() {}

    public func collectWiFiSnapshot() async -> WiFiSnapshot {
        let client = CWWiFiClient.shared()
        let iface = client.interface()
        let ifaceName = iface?.interfaceName ?? "en0"

        let ifconfigRes = await ShellRunner.run(
            executable: "/sbin/ifconfig",
            arguments: [ifaceName],
            timeoutSeconds: 5
        )
        let prefixes = OutputParsers.parseIPv6Prefixes(ifconfigOutput: ifconfigRes.stdout)
        let ipv4Address = OutputParsers.parseIPv4Address(ifconfigOutput: ifconfigRes.stdout)

        let netstatRes = await ShellRunner.run(
            executable: "/usr/sbin/netstat",
            arguments: ["-I", ifaceName, "-b", "-n", "-d"],
            timeoutSeconds: 5
        )
        let ifCounters = OutputParsers.parseInterfaceErrors(netstatOutput: netstatRes.stdout)

        guard let iface else {
            return WiFiSnapshot(
                interfaceName: ifaceName,
                powerOn: false,
                isConnected: false,
                ssid: nil,
                bssid: nil,
                countryCode: nil,
                band: .unknown,
                channel: 0,
                channelWidthMHz: 0,
                phyMode: "–",
                rssi: 0,
                noise: 0,
                txRateMbps: 0,
                ipv4Address: ipv4Address,
                activeGlobalIPv6Prefixes: prefixes.active,
                deprecatedIPv6Prefixes: prefixes.deprecated,
                interfaceInputErrors: ifCounters?.ierrs,
                interfaceOutputErrors: ifCounters?.oerrs,
                interfaceDrops: ifCounters?.drops
            )
        }

        let powerOn = iface.powerOn()
        let rssi = iface.rssiValue()
        let noise = iface.noiseMeasurement()
        let txRate = iface.transmitRate()
        let wlanChannel = iface.wlanChannel()
        let channelNumber = wlanChannel?.channelNumber ?? 0
        let band = mapBand(wlanChannel?.channelBand)
        let widthMHz = mapWidth(wlanChannel?.channelWidth)
        let phyMode = mapPHYMode(iface.activePHYMode())
        let isConnected = powerOn && (channelNumber > 0 || rssi != 0)

        return WiFiSnapshot(
            interfaceName: ifaceName,
            powerOn: powerOn,
            isConnected: isConnected,
            ssid: iface.ssid(),
            bssid: iface.bssid(),
            countryCode: iface.countryCode(),
            band: band,
            channel: channelNumber,
            channelWidthMHz: widthMHz,
            phyMode: phyMode,
            rssi: rssi,
            noise: noise,
            txRateMbps: txRate,
            ipv4Address: ipv4Address,
            activeGlobalIPv6Prefixes: prefixes.active,
            deprecatedIPv6Prefixes: prefixes.deprecated,
            interfaceInputErrors: ifCounters?.ierrs,
            interfaceOutputErrors: ifCounters?.oerrs,
            interfaceDrops: ifCounters?.drops
        )
    }

    public func setWiFiPower(enabled: Bool, interfaceName: String = "en0") async -> Bool {
        let state = enabled ? "on" : "off"
        let res = await ShellRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-setairportpower", interfaceName, state],
            timeoutSeconds: 8
        )
        guard res.exitCode == 0 else { return false }
        try? await Task.sleep(for: .seconds(enabled ? 3 : 1))
        return true
    }

    public func fetchPreferredNetworks(interfaceName: String = "en0") async -> [String] {
        let res = await ShellRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-listpreferredwirelessnetworks", interfaceName],
            timeoutSeconds: 6
        )
        guard res.exitCode == 0 else { return [] }
        return OutputParsers.parsePreferredNetworks(res.stdout)
    }

    /// Zero-jitter read of macOS's already-cached nearby networks (no active radio scan!)
    public func cachedNearbyNetworks(knownSSIDs: Set<String>) -> (networks: [NearbyNetwork], locationRequired: Bool) {
        guard let iface = CWWiFiClient.shared().interface(),
              let rawNetworks = iface.cachedScanResults(),
              !rawNetworks.isEmpty else {
            return ([], false)
        }
        return parseRawNetworks(rawNetworks, knownSSIDs: knownSSIDs)
    }

    /// On-demand active scan for the Wi-Fi picker ("Andere Netzwerke" / popover open when cache empty)
    public func scanNearbyNetworks(knownSSIDs: Set<String>) async -> (networks: [NearbyNetwork], locationRequired: Bool) {
        guard let iface = CWWiFiClient.shared().interface(),
              let rawNetworks = try? iface.scanForNetworks(withName: nil) else {
            return ([], false)
        }
        return parseRawNetworks(rawNetworks, knownSSIDs: knownSSIDs)
    }

    private func parseRawNetworks(
        _ rawNetworks: Set<CWNetwork>,
        knownSSIDs: Set<String>
    ) -> (networks: [NearbyNetwork], locationRequired: Bool) {
        var bySSID: [String: NearbyNetwork] = [:]
        var foundHiddenOnly = !rawNetworks.isEmpty

        for net in rawNetworks {
            guard let ssid = net.ssid, !ssid.isEmpty else { continue }
            foundHiddenOnly = false

            let ch = net.wlanChannel
            let band = mapBand(ch?.channelBand)
            let channelNum = ch?.channelNumber ?? 0
            let isSecure = !net.supportsSecurity(.none)
            let candidate = NearbyNetwork(
                ssid: ssid,
                rssi: net.rssiValue,
                band: band,
                channel: channelNum,
                isSecure: isSecure,
                isKnown: knownSSIDs.contains(ssid)
            )

            if let existing = bySSID[ssid] {
                if candidate.rssi > existing.rssi {
                    bySSID[ssid] = candidate
                }
            } else {
                bySSID[ssid] = candidate
            }
        }

        let sorted = bySSID.values.sorted { lhs, rhs in
            if lhs.rssi != rhs.rssi { return lhs.rssi > rhs.rssi }
            return lhs.ssid.localizedCaseInsensitiveCompare(rhs.ssid) == .orderedAscending
        }

        return (sorted, foundHiddenOnly)
    }

    /// Connects to a known network (password = nil uses macOS Keychain) or a new network with password
    public func connectToNetwork(
        ssid: String,
        password: String?,
        interfaceName: String = "en0",
        lang: ResolvedLanguage = .en
    ) async -> WiFiActionResult {
        var args = ["-setairportnetwork", interfaceName, ssid]
        if let password, !password.isEmpty {
            args.append(password)
        }

        let res = await ShellRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: args,
            timeoutSeconds: 18
        )

        let combined = (res.stdout + "\n" + res.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = combined.lowercased()
        let failedText = lower.contains("could not find")
            || lower.contains("failed to join")
            || lower.contains("error:")
            || lower.contains("not a wi-fi")

        if res.exitCode == 0 && !failedText {
            try? await Task.sleep(for: .seconds(3))
            return WiFiActionResult(success: true, message: nil)
        }

        let cleanMsg: String
        if lower.contains("could not find") {
            cleanMsg = L10n.fmt(.networkNotFound, lang: lang, ssid)
        } else if lower.contains("failed to join") {
            cleanMsg = L10n.fmt(.networkJoinFailed, lang: lang, ssid)
        } else {
            cleanMsg = combined.isEmpty ? L10n.fmt(.networkJoinGenericFailed, lang: lang, ssid) : combined
        }
        return WiFiActionResult(success: false, message: cleanMsg)
    }

    /// Runs strictly sequential idle latency probes: Gateway -> IPv4 (1.1.1.1) -> IPv6 (2606:4700:4700::1111)
    public func runIdleLatencyCheck(packetCount: Int = 5) async -> LatencySnapshot {
        let routeRes = await ShellRunner.run(
            executable: "/sbin/route",
            arguments: ["-n", "get", "default"],
            timeoutSeconds: 5
        )
        let gatewayHost = OutputParsers.parseDefaultGateway(routeOutput: routeRes.stdout)

        let countStr = String(max(3, packetCount))
        var gwStats: PingStats?
        if let gw = gatewayHost {
            let gwRes = await ShellRunner.run(
                executable: "/sbin/ping",
                arguments: ["-c", countStr, "-i", "0.2", "-t", String(max(4, packetCount)), gw],
                timeoutSeconds: TimeInterval(packetCount + 6)
            )
            gwStats = OutputParsers.parsePingOutput(gwRes.stdout, host: gw)
        }

        let v4Res = await ShellRunner.run(
            executable: "/sbin/ping",
            arguments: ["-c", countStr, "-i", "0.2", "-t", String(max(4, packetCount)), "1.1.1.1"],
            timeoutSeconds: TimeInterval(packetCount + 6)
        )
        let v4Stats = OutputParsers.parsePingOutput(v4Res.stdout, host: "1.1.1.1")

        // Only probe IPv6 if we actually have any global IPv6 address or default IPv6 route
        let v6RouteRes = await ShellRunner.run(
            executable: "/sbin/route",
            arguments: ["-n", "get", "-inet6", "default"],
            timeoutSeconds: 4
        )
        var v6Stats: PingStats?
        if v6RouteRes.exitCode == 0 && v6RouteRes.stdout.contains("gateway:") {
            let v6Host = "2606:4700:4700::1111"
            let v6Res = await ShellRunner.run(
                executable: "/sbin/ping6",
                arguments: ["-c", countStr, "-i", "0.2", v6Host],
                timeoutSeconds: TimeInterval(packetCount + 6)
            )
            v6Stats = OutputParsers.parsePingOutput(v6Res.stdout, host: v6Host)
        }

        return LatencySnapshot(
            gatewayHost: gatewayHost,
            gateway: gwStats,
            ipv4Internet: v4Stats,
            ipv6Internet: v6Stats
        )
    }

    public func runDNSCheck(gatewayHost: String? = nil) async -> DNSSnapshot {
        let scutilRes = await ShellRunner.run(
            executable: "/usr/sbin/scutil",
            arguments: ["--dns"],
            timeoutSeconds: 5
        )
        let primaryResolver = OutputParsers.parsePrimaryDNSResolver(scutilOutput: scutilRes.stdout)
        let nonce = Int(Date().timeIntervalSince1970)

        var activeMs: Int?
        if let resolver = primaryResolver {
            let digActive = await ShellRunner.run(
                executable: "/usr/bin/dig",
                arguments: ["@\(resolver)", "ap-\(nonce)-a.wikipedia.org", "+tries=1", "+time=3", "+stats"],
                timeoutSeconds: 6
            )
            activeMs = OutputParsers.parseDigQueryTime(digOutput: digActive.stdout)
        }

        let digCF = await ShellRunner.run(
            executable: "/usr/bin/dig",
            arguments: ["@1.1.1.1", "ap-\(nonce)-cf.wikipedia.org", "+tries=1", "+time=3", "+stats"],
            timeoutSeconds: 6
        )
        let cfMs = OutputParsers.parseDigQueryTime(digOutput: digCF.stdout)

        let digGoogle = await ShellRunner.run(
            executable: "/usr/bin/dig",
            arguments: ["@8.8.8.8", "ap-\(nonce)-gg.wikipedia.org", "+tries=1", "+time=3", "+stats"],
            timeoutSeconds: 6
        )
        let googleMs = OutputParsers.parseDigQueryTime(digOutput: digGoogle.stdout)

        var routerMs: Int?
        if let gw = gatewayHost, !gw.isEmpty {
            if gw == primaryResolver {
                routerMs = activeMs
            } else {
                let digGW = await ShellRunner.run(
                    executable: "/usr/bin/dig",
                    arguments: ["@\(gw)", "ap-\(nonce)-gw.wikipedia.org", "+tries=1", "+time=3", "+stats"],
                    timeoutSeconds: 6
                )
                routerMs = OutputParsers.parseDigQueryTime(digOutput: digGW.stdout)
            }
        }

        return DNSSnapshot(
            activeResolver: primaryResolver,
            activeLatencyMs: activeMs,
            referenceServer: "1.1.1.1",
            referenceLatencyMs: cfMs,
            googleLatencyMs: googleMs,
            routerHost: gatewayHost,
            routerLatencyMs: routerMs
        )
    }

    /// On-demand RF scan (never called on fast background timers to avoid channel-switching jitter!)
    public func runRFScan(lang: ResolvedLanguage = .en) async -> RFScanResult {
        var scanned: [ScannedNetwork] = []

        if let iface = CWWiFiClient.shared().interface(),
           let networks = try? iface.scanForNetworks(withName: nil),
           !networks.isEmpty {
            scanned = networks.compactMap { net -> ScannedNetwork? in
                guard let ch = net.wlanChannel else { return nil }
                return ScannedNetwork(
                    channel: ch.channelNumber,
                    band: mapBand(ch.channelBand),
                    channelWidthMHz: mapWidth(ch.channelWidth),
                    rssi: net.rssiValue
                )
            }
        }

        // Fallback to system_profiler if CoreWLAN returned empty
        if scanned.isEmpty {
            let sp = await ShellRunner.run(
                executable: "/usr/sbin/system_profiler",
                arguments: ["SPAirPortDataType"],
                timeoutSeconds: 20
            )
            scanned = OutputParsers.parseSystemProfilerNetworks(sp.stdout)
        }

        return ChannelAnalyzer.analyze(networks: scanned, lang: lang)
    }

    /// On-demand throughput & bufferbloat test using Apple's built-in `networkQuality -c`
    public func runNetworkQuality(maxRuntimeSeconds: Int = 15) async -> NetworkQualityResult? {
        let res = await ShellRunner.run(
            executable: "/usr/bin/networkQuality",
            arguments: ["-c", "-M", String(maxRuntimeSeconds)],
            timeoutSeconds: TimeInterval(maxRuntimeSeconds + 25)
        )
        return OutputParsers.parseNetworkQualityJSON(res.stdout)
    }

    /// Cycles Wi-Fi power off for 3s then on — clears stale IPv6 prefixes and triggers clean reconnect
    public func reconnectWiFi(interfaceName: String = "en0") async -> Bool {
        let off = await ShellRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-setairportpower", interfaceName, "off"],
            timeoutSeconds: 8
        )
        guard off.exitCode == 0 else { return false }
        try? await Task.sleep(for: .seconds(3))
        let on = await ShellRunner.run(
            executable: "/usr/sbin/networksetup",
            arguments: ["-setairportpower", interfaceName, "on"],
            timeoutSeconds: 8
        )
        guard on.exitCode == 0 else { return false }
        // Give macOS a moment to re-associate and acquire IPv4/IPv6
        try? await Task.sleep(for: .seconds(5))
        return true
    }

    private func mapBand(_ band: CWChannelBand?) -> WiFiBand {
        guard let band else { return .unknown }
        switch band {
        case .band2GHz: return .band2GHz
        case .band5GHz: return .band5GHz
        case .band6GHz: return .band6GHz
        default: return .unknown
        }
    }

    private func mapWidth(_ width: CWChannelWidth?) -> Int {
        guard let width else { return 0 }
        switch width {
        case .width20MHz: return 20
        case .width40MHz: return 40
        case .width80MHz: return 80
        case .width160MHz: return 160
        default: return 0
        }
    }

    private func mapPHYMode(_ mode: CWPHYMode) -> String {
        switch mode {
        case .mode11a: return "802.11a"
        case .mode11b: return "802.11b"
        case .mode11g: return "802.11g"
        case .mode11n: return "802.11n (Wi-Fi 4)"
        case .mode11ac: return "802.11ac (Wi-Fi 5)"
        case .mode11ax: return "802.11ax (Wi-Fi 6)"
        default: return "802.11"
        }
    }
}

import Foundation
import Testing
@testable import AirPhareCore

@Suite("AirPhareCore Parsers & Diagnostics")
struct AirPhareCoreTests {

    @Test("Parse IPv4 ping output with jitter")
    func parsePingIPv4() {
        let output = """
        PING 192.168.2.1 (192.168.2.1): 56 data bytes
        64 bytes from 192.168.2.1: icmp_seq=0 ttl=64 time=4.430 ms

        --- 192.168.2.1 ping statistics ---
        30 packets transmitted, 30 packets received, 0.0% packet loss
        round-trip min/avg/max/stddev = 3.583/11.109/95.813/19.106 ms
        """

        let stats = OutputParsers.parsePingOutput(output, host: "192.168.2.1")
        #expect(stats != nil)
        #expect(stats?.transmitted == 30)
        #expect(stats?.received == 30)
        #expect(stats?.packetLossPercent == 0.0)
        #expect(stats?.minMs == 3.583)
        #expect(stats?.avgMs == 11.109)
        #expect(stats?.maxMs == 95.813)
        #expect(stats?.stddevMs == 19.106)
        #expect(stats?.isReachable == true)
    }

    @Test("Parse IPv6 ping6 output with std-dev spelling and 100% loss")
    func parsePingIPv6() {
        let okOutput = """
        --- 2606:4700:4700::1111 ping6 statistics ---
        30 packets transmitted, 30 packets received, 0.0% packet loss
        round-trip min/avg/max/std-dev = 6.660/16.103/86.828/20.999 ms
        """
        let okStats = OutputParsers.parsePingOutput(okOutput, host: "2606:4700:4700::1111")
        #expect(okStats?.isReachable == true)
        #expect(okStats?.stddevMs == 20.999)

        let lossOutput = """
        --- 2606:4700:4700::1111 ping6 statistics ---
        30 packets transmitted, 0 packets received, 100.0% packet loss
        """
        let lossStats = OutputParsers.parsePingOutput(lossOutput, host: "2606:4700:4700::1111")
        #expect(lossStats?.packetLossPercent == 100.0)
        #expect(lossStats?.isReachable == false)
    }

    @Test("Detect multiple active IPv6 prefixes vs deprecated prefixes")
    func parseIPv6Prefixes() {
        let staleIfconfig = """
        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
        \tinet6 fe80::109b:7fc8:70a2:f699%en0 prefixlen 64 secured scopeid 0xe
        \tinet 192.168.2.50 netmask 0xffffff00 broadcast 192.168.2.255
        \tinet6 2001:db8:1111:a001:1439:437b:69b2:df17 prefixlen 64 deprecated autoconf secured
        \tinet6 2001:db8:1111:a002:14cf:b52b:20ed:a81e prefixlen 64 autoconf secured
        \tinet6 2001:db8:1111:a003:6e:c826:b89a:1d8 prefixlen 64 autoconf secured
        """

        let parsed = OutputParsers.parseIPv6Prefixes(ifconfigOutput: staleIfconfig)
        #expect(parsed.active == ["2001:db8:1111:a002::/64", "2001:db8:1111:a003::/64"])
        #expect(parsed.deprecated == ["2001:db8:1111:a001::/64"])
    }

    @Test("Parse networkQuality JSON output")
    func parseNetworkQuality() {
        let json = """
        {
          "base_rtt" : 14.63,
          "dl_throughput" : 253923568,
          "ul_throughput" : 125491944,
          "responsiveness" : 1021.73,
          "test_endpoint" : "deber5-edge-bx-004.aaplimg.com",
          "other" : {
            "ecn_values" : { "ecn_disabled" : 44 },
            "l4s_enablement" : { "disabled" : 44 }
          }
        }
        """

        let result = OutputParsers.parseNetworkQualityJSON(json)
        #expect(result != nil)
        #expect(Int(result!.downlinkMbps.rounded()) == 254)
        #expect(Int(result!.uplinkMbps.rounded()) == 125)
        #expect(result?.responsivenessRPM == 1022)
        #expect(result?.responsivenessRating == "High")
        #expect(result?.responsivenessRating(lang: .de) == "Hoch")
        #expect(result?.ecnEnabled == false)
        #expect(result?.l4sEnabled == false)
    }

    @Test("ChannelAnalyzer recommends Channel 100 on 5 GHz and Channel 1 on 2.4 GHz")
    func analyzeCongestedEnvironment() {
        let networks: [ScannedNetwork] = [
            // 5 GHz congested on 36-64
            ScannedNetwork(channel: 36, band: .band5GHz, channelWidthMHz: 80, rssi: -66),
            ScannedNetwork(channel: 36, band: .band5GHz, channelWidthMHz: 80, rssi: -75),
            ScannedNetwork(channel: 36, band: .band5GHz, channelWidthMHz: 80, rssi: -78),
            ScannedNetwork(channel: 60, band: .band5GHz, channelWidthMHz: 160, rssi: -70),
            ScannedNetwork(channel: 104, band: .band5GHz, channelWidthMHz: 80, rssi: -82),
            // 2.4 GHz
            ScannedNetwork(channel: 1, band: .band2GHz, channelWidthMHz: 20, rssi: -80),
            ScannedNetwork(channel: 6, band: .band2GHz, channelWidthMHz: 20, rssi: -72),
            ScannedNetwork(channel: 6, band: .band2GHz, channelWidthMHz: 20, rssi: -75),
            ScannedNetwork(channel: 11, band: .band2GHz, channelWidthMHz: 40, rssi: -63),
            ScannedNetwork(channel: 11, band: .band2GHz, channelWidthMHz: 20, rssi: -65)
        ]

        let result = ChannelAnalyzer.analyze(networks: networks)
        #expect(result.recommended5GHz?.channel == 100 || result.recommended5GHz?.channel == 116)
        #expect(result.recommended5GHz?.channel != 36)
        #expect(result.recommended2GHz?.channel == 1)
    }

    @Test("HealthEvaluator catches DFS drift, IPv6 blackhole, and all-green state")
    func healthEvaluationRules() {
        let settings = MonitorSettings.default

        // Broken IPv6 + DFS drift to Ch 36
        let badWiFi = WiFiSnapshot(
            interfaceName: "en0",
            isConnected: true,
            ssid: "HomeWiFi-5G",
            band: .band5GHz,
            channel: 36,
            channelWidthMHz: 80,
            phyMode: "802.11ac (Wi-Fi 5)",
            rssi: -68,
            noise: -93,
            txRateMbps: 390,
            activeGlobalIPv6Prefixes: ["2001:db8:1111:a002::/64", "2001:db8:1111:a003::/64"]
        )
        let badLatency = LatencySnapshot(
            gatewayHost: "192.168.2.1",
            gateway: PingStats(host: "192.168.2.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 4, avgMs: 11, maxMs: 50, stddevMs: 10),
            ipv4Internet: PingStats(host: "1.1.1.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 6, avgMs: 15, maxMs: 55, stddevMs: 10),
            ipv6Internet: PingStats(host: "2606:4700:4700::1111", transmitted: 5, received: 0, packetLossPercent: 100, minMs: nil, avgMs: nil, maxMs: nil, stddevMs: nil)
        )

        let badReport = HealthEvaluator.evaluate(
            wifi: badWiFi,
            latency: badLatency,
            dns: nil,
            rfScan: nil,
            settings: settings
        )
        #expect(badReport.severity == .critical)
        #expect(badReport.alerts.contains(where: { $0.category == .ipv6Broken }))
        #expect(badReport.alerts.contains(where: { $0.category == .channelDrift }))

        // Clean healthy state on Ch 100
        let goodWiFi = WiFiSnapshot(
            interfaceName: "en0",
            isConnected: true,
            ssid: "HomeWiFi-5G",
            band: .band5GHz,
            channel: 100,
            channelWidthMHz: 80,
            phyMode: "802.11ac (Wi-Fi 5)",
            rssi: -62,
            noise: -95,
            txRateMbps: 585,
            activeGlobalIPv6Prefixes: ["2001:db8:1111:a003::/64"]
        )
        let goodLatency = LatencySnapshot(
            gatewayHost: "192.168.2.1",
            gateway: PingStats(host: "192.168.2.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 4, avgMs: 6, maxMs: 12, stddevMs: 2),
            ipv4Internet: PingStats(host: "1.1.1.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 6, avgMs: 8, maxMs: 14, stddevMs: 2),
            ipv6Internet: PingStats(host: "2606:4700:4700::1111", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 7, avgMs: 9, maxMs: 15, stddevMs: 2)
        )
        let goodDNS = DNSSnapshot(activeResolver: "100.100.100.100", activeLatencyMs: 21, referenceLatencyMs: 18)

        let goodReport = HealthEvaluator.evaluate(
            wifi: goodWiFi,
            latency: goodLatency,
            dns: goodDNS,
            rfScan: nil,
            settings: settings
        )
        #expect(goodReport.severity == .ok)
        #expect(goodReport.alerts.isEmpty)
    }

    @Test("HistoryLogger writes rich English CSV with SSID & metrics and reloads recent samples")
    func historyLoggerWritesAndReloads() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("airphare-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let logger = HistoryLogger(directoryURL: tmpDir)
        let wifi = WiFiSnapshot(
            interfaceName: "en0",
            powerOn: true,
            isConnected: true,
            ssid: "HomeWiFi-5G",
            bssid: "aa:bb:cc:dd:ee:ff",
            countryCode: "DE",
            band: .band5GHz,
            channel: 100,
            channelWidthMHz: 80,
            phyMode: "802.11ac (Wi-Fi 5)",
            rssi: -62,
            noise: -95,
            txRateMbps: 585,
            ipv4Address: "192.168.2.50",
            activeGlobalIPv6Prefixes: ["2001:db8:1111:a003::/64"],
            interfaceInputErrors: 0,
            interfaceOutputErrors: 0,
            interfaceDrops: 42
        )
        let latency = LatencySnapshot(
            gatewayHost: "192.168.2.1",
            gateway: PingStats(host: "192.168.2.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 4, avgMs: 6.5, maxMs: 12, stddevMs: 2),
            ipv4Internet: PingStats(host: "1.1.1.1", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 6, avgMs: 8.2, maxMs: 14, stddevMs: 2),
            ipv6Internet: PingStats(host: "2606:4700:4700::1111", transmitted: 5, received: 5, packetLossPercent: 0, minMs: 7, avgMs: 9.1, maxMs: 15, stddevMs: 2)
        )
        let dns = DNSSnapshot(activeResolver: "100.100.100.100", activeLatencyMs: 21, referenceLatencyMs: 18)
        let report = HealthEvaluator.evaluate(wifi: wifi, latency: latency, dns: dns, rfScan: nil, settings: .default, lang: .en)

        await logger.log(eventType: .check, wifi: wifi, latency: latency, dns: dns, rfScan: nil, networkQuality: nil, report: report)
        await logger.log(eventType: .benchmark, wifi: wifi, latency: latency, dns: dns, rfScan: nil, networkQuality: NetworkQualityResult(
            downlinkMbps: 200, uplinkMbps: 203, idleLatencyMs: 13.4, loadedLatencyMs: 92.0,
            responsivenessRPM: 652, ecnEnabled: false, l4sEnabled: false, endpoint: "edge"
        ), report: report)

        let count = await logger.entryCount()
        #expect(count == 2)

        let csvText = try String(contentsOf: logger.csvFileURL, encoding: .utf8)
        #expect(csvText.contains("HomeWiFi-5G"))
        #expect(csvText.contains("aa:bb:cc:dd:ee:ff"))
        #expect(csvText.contains("192.168.2.50"))
        #expect(csvText.contains("5 GHz"))
        #expect(csvText.contains("Medium"))
        #expect(csvText.contains(",42,"))

        let samples = await logger.loadRecentSamples(limit: 10)
        #expect(samples.count == 2)
        #expect(samples.first?.snr == 33)
        #expect(samples.first?.channel == 100)
        #expect(samples.first?.gatewayAvgMs == 6.5)
        #expect(samples.first?.ipv6Reachable == true)
    }

    @Test("Parse preferred Wi-Fi networks in priority order")
    func parsePreferredNetworks() {
        let output = """
        Preferred networks on en0:
        \tHomeWiFi-5G
        \tHomeWiFi
        \tMyPhone
        \tHomeWiFi-5G
        """

        let list = OutputParsers.parsePreferredNetworks(output)
        #expect(list == ["HomeWiFi-5G", "HomeWiFi", "MyPhone"])
    }

    @Test("All localization keys exist across EN, DE, IT, FR, ES, NL")
    func localizationCompleteness() {
        for lang in ResolvedLanguage.allCases {
            for key in L10nKey.allCases {
                let value = L10n.t(key, lang: lang)
                #expect(!value.isEmpty)
                #expect(value != key.rawValue)
            }
        }

        #expect(AppLanguage.system.resolved(preferredLanguages: ["de-DE"]) == .de)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["it-IT"]) == .it)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["fr-FR"]) == .fr)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["es-ES"]) == .es)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["nl-NL"]) == .nl)
        #expect(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]) == .en)
    }
}

import Foundation

public enum OutputParsers {

    public static func parsePingOutput(_ output: String, host: String) -> PingStats? {
        // Example IPv4:
        // 30 packets transmitted, 30 packets received, 0.0% packet loss
        // round-trip min/avg/max/stddev = 3.583/11.109/95.813/19.106 ms
        // Example IPv6:
        // 30 packets transmitted, 30 packets received, 0.0% packet loss
        // round-trip min/avg/max/std-dev = 6.660/16.103/86.828/20.999 ms
        let lines = output.components(separatedBy: .newlines)

        var transmitted: Int?
        var received: Int?
        var loss: Double?

        let packetPattern = try? NSRegularExpression(
            pattern: #"(\d+)\s+packets transmitted,\s+(\d+)\s+packets received,\s+([0-9.]+)%\s+packet loss"#
        )
        let rttPattern = try? NSRegularExpression(
            pattern: #"min/avg/max/(?:stddev|std-dev)\s*=\s*([0-9.]+)/([0-9.]+)/([0-9.]+)/([0-9.]+)\s*ms"#
        )

        var minMs: Double?
        var avgMs: Double?
        var maxMs: Double?
        var stddevMs: Double?

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if transmitted == nil, let match = packetPattern?.firstMatch(in: line, range: range) {
                transmitted = extractInt(match, at: 1, in: line)
                received = extractInt(match, at: 2, in: line)
                loss = extractDouble(match, at: 3, in: line)
            }
            if minMs == nil, let match = rttPattern?.firstMatch(in: line, range: range) {
                minMs = extractDouble(match, at: 1, in: line)
                avgMs = extractDouble(match, at: 2, in: line)
                maxMs = extractDouble(match, at: 3, in: line)
                stddevMs = extractDouble(match, at: 4, in: line)
            }
        }

        guard let tx = transmitted, let rx = received, let packetLoss = loss else {
            return nil
        }

        return PingStats(
            host: host,
            transmitted: tx,
            received: rx,
            packetLossPercent: packetLoss,
            minMs: minMs,
            avgMs: avgMs,
            maxMs: maxMs,
            stddevMs: stddevMs
        )
    }

    public static func parseIPv6Prefixes(ifconfigOutput: String) -> (active: [String], deprecated: [String]) {
        var activeSet = Set<String>()
        var deprecatedSet = Set<String>()

        for rawLine in ifconfigOutput.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("inet6 ") else { continue }
            let parts = line.split(separator: " ")
            guard parts.count >= 2 else { continue }

            let address = String(parts[1]).components(separatedBy: "%").first ?? ""
            let lower = address.lowercased()

            // Skip link-local (fe80::), loopback (::1), ULA (fc/fd)
            if lower.hasPrefix("fe80:") || lower == "::1" || lower.hasPrefix("fc") || lower.hasPrefix("fd") {
                continue
            }

            // Global unicast (2000::/3 -> starts with 2 or 3)
            guard lower.hasPrefix("2") || lower.hasPrefix("3") else { continue }

            let groups = lower.split(separator: ":")
            guard groups.count >= 4 else { continue }
            let prefix64 = groups.prefix(4).joined(separator: ":") + "::/64"

            if line.contains("deprecated") {
                deprecatedSet.insert(prefix64)
            } else {
                activeSet.insert(prefix64)
            }
        }

        // If a prefix has any non-deprecated address, treat it as active
        let onlyDeprecated = deprecatedSet.subtracting(activeSet)
        return (active: activeSet.sorted(), deprecated: onlyDeprecated.sorted())
    }

    public static func parseIPv4Address(ifconfigOutput: String) -> String? {
        for rawLine in ifconfigOutput.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("inet ") else { continue }
            let parts = line.split(separator: " ")
            if parts.count >= 2 {
                let ip = String(parts[1])
                if ip != "127.0.0.1" { return ip }
            }
        }
        return nil
    }

    public static func parseInterfaceErrors(netstatOutput: String) -> (ierrs: UInt64, oerrs: UInt64, drops: UInt64)? {
        // netstat -I en0 -b -n -d
        // Name  Mtu  Network  Address  Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll Drop
        // en0   1500 <Link#14> aa:bb... 123   0     456    789   0     1011   0    2101
        for rawLine in netstatOutput.components(separatedBy: .newlines) {
            guard rawLine.contains("<Link#") else { continue }
            let cols = rawLine.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            // cols: [0]=Name [1]=Mtu [2]=<Link#> [3]=MAC [4]=Ipkts [5]=Ierrs [6]=Ibytes [7]=Opkts [8]=Oerrs [9]=Obytes [10]=Coll [11]=Drop
            guard cols.count >= 12,
                  let ierrs = UInt64(cols[5]),
                  let oerrs = UInt64(cols[8]),
                  let drops = UInt64(cols[11]) else {
                continue
            }
            return (ierrs: ierrs, oerrs: oerrs, drops: drops)
        }
        return nil
    }

    public static func parseDefaultGateway(routeOutput: String) -> String? {
        for rawLine in routeOutput.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("gateway:") {
                let value = line.replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    return value
                }
            }
        }
        return nil
    }

    public static func parsePrimaryDNSResolver(scutilOutput: String) -> String? {
        // Parse the first resolver block (resolver #1) and return its first IPv4 or IPv6 nameserver
        var inFirstResolver = false
        for rawLine in scutilOutput.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("resolver #1") {
                inFirstResolver = true
                continue
            }
            if inFirstResolver && line.hasPrefix("resolver #") {
                break
            }
            if inFirstResolver && line.hasPrefix("nameserver[0]") {
                if let colonIdx = line.firstIndex(of: ":") {
                    let value = line[line.index(after: colonIdx)...]
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        return value
                    }
                }
            }
        }
        return nil
    }

    public static func parseDigQueryTime(digOutput: String) -> Int? {
        let pattern = try? NSRegularExpression(pattern: #"Query time:\s*(\d+)\s*msec"#)
        for line in digOutput.components(separatedBy: .newlines) {
            let range = NSRange(line.startIndex..., in: line)
            if let match = pattern?.firstMatch(in: line, range: range) {
                return extractInt(match, at: 1, in: line)
            }
        }
        return nil
    }

    private struct RawNetworkQuality: Decodable {
        let dl_throughput: Double?
        let ul_throughput: Double?
        let base_rtt: Double?
        let responsiveness: Double?
        let test_endpoint: String?
        let other: OtherInfo?

        struct OtherInfo: Decodable {
            let ecn_values: [String: Int]?
            let l4s_enablement: [String: Int]?
        }
    }

    public static func parseNetworkQualityJSON(_ jsonString: String, timestamp: Date = .now) -> NetworkQualityResult? {
        // Strip leading progress/whitespace before first '{'
        guard let startIdx = jsonString.firstIndex(of: "{") else { return nil }
        let trimmed = String(jsonString[startIdx...])
        guard let data = trimmed.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawNetworkQuality.self, from: data),
              let dl = raw.dl_throughput,
              let ul = raw.ul_throughput,
              let rpm = raw.responsiveness,
              rpm > 0 else {
            return nil
        }

        let dlMbps = dl / 1_000_000.0
        let ulMbps = ul / 1_000_000.0
        let idleMs = raw.base_rtt ?? 0
        let loadedMs = 60_000.0 / rpm

        let ecnEnabled = (raw.other?.ecn_values?.keys.contains(where: { !$0.contains("disabled") }) ?? false)
        let l4sEnabled = (raw.other?.l4s_enablement?.keys.contains(where: { !$0.contains("disabled") }) ?? false)

        return NetworkQualityResult(
            downlinkMbps: dlMbps,
            uplinkMbps: ulMbps,
            idleLatencyMs: idleMs,
            loadedLatencyMs: loadedMs,
            responsivenessRPM: Int(rpm.rounded()),
            ecnEnabled: ecnEnabled,
            l4sEnabled: l4sEnabled,
            endpoint: raw.test_endpoint,
            timestamp: timestamp
        )
    }

    public static func parsePreferredNetworks(_ output: String) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for rawLine in output.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("Preferred networks on ") || trimmed.hasPrefix("There aren't any") {
                continue
            }
            if seen.insert(trimmed).inserted {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    public static func parseSystemProfilerNetworks(_ output: String) -> [ScannedNetwork] {
        // Fallback RF parser from `system_profiler SPAirPortDataType` "Other Local Wi-Fi Networks:"
        var inOtherSection = false
        var results: [ScannedNetwork] = []

        var currentChannel: Int?
        var currentBand: WiFiBand = .unknown
        var currentWidth: Int = 20
        var currentRSSI: Int?

        let channelRegex = try? NSRegularExpression(
            pattern: #"Channel:\s*(\d+)\s*\((2GHz|5GHz|6GHz),\s*(\d+)MHz\)"#
        )
        let signalRegex = try? NSRegularExpression(
            pattern: #"Signal / Noise:\s*(-?\d+)\s*dBm"#
        )

        func flush() {
            if let ch = currentChannel, currentBand != .unknown {
                results.append(ScannedNetwork(
                    channel: ch,
                    band: currentBand,
                    channelWidthMHz: currentWidth,
                    rssi: currentRSSI
                ))
            }
            currentChannel = nil
            currentBand = .unknown
            currentWidth = 20
            currentRSSI = nil
        }

        for rawLine in output.components(separatedBy: .newlines) {
            if rawLine.contains("Other Local Wi-Fi Networks:") {
                inOtherSection = true
                continue
            }
            if inOtherSection && rawLine.trimmingCharacters(in: .whitespaces).hasPrefix("awdl0:") {
                flush()
                break
            }
            guard inOtherSection else { continue }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix(":") && !trimmed.contains("PHY Mode") && !trimmed.contains("Channel") {
                flush()
                continue
            }

            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = channelRegex?.firstMatch(in: trimmed, range: range) {
                currentChannel = extractInt(match, at: 1, in: trimmed)
                if let bandStr = extractString(match, at: 2, in: trimmed) {
                    switch bandStr {
                    case "2GHz": currentBand = .band2GHz
                    case "5GHz": currentBand = .band5GHz
                    case "6GHz": currentBand = .band6GHz
                    default: currentBand = .unknown
                    }
                }
                currentWidth = extractInt(match, at: 3, in: trimmed) ?? 20
            } else if let match = signalRegex?.firstMatch(in: trimmed, range: range) {
                currentRSSI = extractInt(match, at: 1, in: trimmed)
            }
        }
        flush()
        return results
    }

    private static func extractString(_ match: NSTextCheckingResult, at index: Int, in string: String) -> String? {
        guard let range = Range(match.range(at: index), in: string) else { return nil }
        return String(string[range])
    }

    private static func extractInt(_ match: NSTextCheckingResult, at index: Int, in string: String) -> Int? {
        extractString(match, at: index, in: string).flatMap(Int.init)
    }

    private static func extractDouble(_ match: NSTextCheckingResult, at index: Int, in string: String) -> Double? {
        extractString(match, at: index, in: string).flatMap(Double.init)
    }
}

import Foundation

public enum MarkdownReportBuilder {

    public static func build(
        wifi: WiFiSnapshot?,
        latency: LatencySnapshot?,
        dns: DNSSnapshot?,
        rfScan: RFScanResult?,
        networkQuality: NetworkQualityResult?,
        report: HealthReport,
        stats24h: AnalyticsSummary? = nil,
        timestamp: Date = .now
    ) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        var lines: [String] = []
        lines.append("# AirPhare Diagnostic Report")
        lines.append("")
        lines.append("- **Timestamp:** `\(iso.string(from: timestamp))`")
        lines.append("- **Status:** \(report.headline)")
        lines.append("")

        if !report.alerts.isEmpty {
            lines.append("## Active Alerts")
            for alert in report.alerts {
                let badge = alert.severity == .critical ? "CRITICAL" : "WARNING"
                lines.append("- **[\(badge)] \(alert.title):** \(alert.message) *(Tip: \(alert.actionHint))*")
            }
            lines.append("")
        }

        lines.append("## Wi-Fi Link")
        if let wifi, wifi.isConnected {
            lines.append("| Metric | Value |")
            lines.append("|---|---|")
            lines.append("| Interface | `\(wifi.interfaceName)` |")
            lines.append("| Network (SSID) | `\(wifi.ssid ?? "Redacted")` |")
            if let bssid = wifi.bssid {
                lines.append("| Access Point (BSSID) | `\(bssid)` |")
            }
            lines.append("| Band / Channel | `\(wifi.band.englishLabel)`, Ch `\(wifi.channel)` (`\(wifi.channelWidthMHz) MHz`) |")
            lines.append("| PHY Mode | `\(wifi.phyMode)` |")
            lines.append("| Signal / Noise / SNR | `\(wifi.rssi) dBm` / `\(wifi.noise) dBm` (**`\(wifi.snr) dB`**) |")
            lines.append("| Link Rate | `\(Int(wifi.txRateMbps)) Mbps` |")
            if let ip = wifi.ipv4Address {
                lines.append("| IPv4 Address | `\(ip)` |")
            }
            lines.append("| Active IPv6 Prefixes | `\(wifi.activeGlobalIPv6Prefixes.isEmpty ? "None" : wifi.activeGlobalIPv6Prefixes.joined(separator: ", "))` |")
            if let drops = wifi.interfaceDrops {
                lines.append("| Interface Drops / Errors | Drops `\(drops)` · Ierrs `\(wifi.interfaceInputErrors ?? 0)` · Oerrs `\(wifi.interfaceOutputErrors ?? 0)` |")
            }
        } else {
            lines.append("_No active Wi-Fi connection._")
        }
        lines.append("")

        if let latency {
            lines.append("## Hop-by-Hop Idle Latency")
            lines.append("| Target | Loss | Min / Avg / Max (Stddev) |")
            lines.append("|---|---:|---|")
            lines.append(formatPingRow(label: "Gateway (`\(latency.gatewayHost ?? "–")`)", stats: latency.gateway))
            lines.append(formatPingRow(label: "IPv4 (`1.1.1.1`)", stats: latency.ipv4Internet))
            lines.append(formatPingRow(label: "IPv6 (`2606:4700:4700::1111`)", stats: latency.ipv6Internet))
            lines.append("")
        }

        if let dns {
            lines.append("## DNS Uncached Latency Comparison")
            lines.append("| Resolver | Role | Query Time |")
            lines.append("|---|---|---:|")
            if let active = dns.activeResolver {
                lines.append("| `\(active)` | Active System DNS | \(dns.activeLatencyMs.map { "\($0) ms" } ?? "–") |")
            }
            lines.append("| `1.1.1.1` | Cloudflare | \(dns.referenceLatencyMs.map { "\($0) ms" } ?? "–") |")
            if let google = dns.googleLatencyMs {
                lines.append("| `8.8.8.8` | Google | \(google) ms |")
            }
            if let gw = dns.routerHost, gw != dns.activeResolver {
                lines.append("| `\(gw)` | Router | \(dns.routerLatencyMs.map { "\($0) ms" } ?? "–") |")
            }
            if let best = dns.fastestServer {
                lines.append("")
                lines.append("Fastest measured DNS: **`\(best.label)` (\(best.latencyMs) ms)**")
            }
            lines.append("")
        }

        if let nq = networkQuality {
            lines.append("## Throughput & Bufferbloat (`networkQuality`)")
            lines.append("- **Downlink:** `\(String(format: "%.1f", nq.downlinkMbps)) Mbps`")
            lines.append("- **Uplink:** `\(String(format: "%.1f", nq.uplinkMbps)) Mbps`")
            lines.append("- **Idle Latency:** `\(String(format: "%.1f", nq.idleLatencyMs)) ms`")
            lines.append("- **Loaded Latency / Responsiveness:** `\(Int(nq.loadedLatencyMs)) ms` (**`\(nq.responsivenessRPM) RPM`**, \(nq.responsivenessRating(lang: .en)))")
            lines.append("- **ECN / L4S:** ECN `\(nq.ecnEnabled ? "Enabled" : "Disabled")` · L4S `\(nq.l4sEnabled ? "Enabled" : "Disabled")`")
            lines.append("")
        }

        if let rf = rfScan {
            lines.append("## RF Channel Recommendations (\(rf.totalNetworks) networks scanned)")
            if let best5 = rf.recommended5GHz {
                lines.append("- **Best 5 GHz Channel:** Ch `\(best5.channel)` (\(best5.overlappingAPCount) overlapping APs · \(best5.note))")
            }
            if let best2 = rf.recommended2GHz {
                lines.append("- **Best 2.4 GHz Channel:** Ch `\(best2.channel)` (\(best2.overlappingAPCount) overlapping APs · 20 MHz)")
            }
            lines.append("")
        }

        if let s = stats24h, s.totalChecks > 0 {
            lines.append("## Last 24h Summary (\(s.totalChecks) checks)")
            lines.append("- **Uptime:** `\(String(format: "%.1f", s.uptimePercent))%`")
            if let snr = s.avgSNR {
                lines.append("- **Avg / Min SNR:** `\(String(format: "%.1f", snr)) dB` / `\(s.minSNR ?? 0) dB`")
            }
            if let gw = s.avgGatewayMs {
                lines.append("- **Avg / Max Gateway Ping:** `\(String(format: "%.1f", gw)) ms` / `\(String(format: "%.1f", s.maxGatewayMs ?? gw)) ms`")
            }
            lines.append("- **Incidents:** DFS drift `\(s.dfsDriftCount)` · 2.4 GHz fallback `\(s.wrongBandCount)` · IPv6 outages `\(s.ipv6OutageCount)` · Wi-Fi jitter `\(s.wifiJitterCount)` · ISP issues `\(s.ispIssueCount)`")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func formatPingRow(label: String, stats: PingStats?) -> String {
        guard let stats else { return "| \(label) | – | – |" }
        let loss = String(format: "%.0f%%", stats.packetLossPercent)
        if !stats.isReachable {
            return "| \(label) | **\(loss)** | Unreachable |"
        }
        let minS = stats.minMs.map { String(format: "%.1f", $0) } ?? "–"
        let avgS = stats.avgMs.map { String(format: "%.1f", $0) } ?? "–"
        let maxS = stats.maxMs.map { String(format: "%.1f", $0) } ?? "–"
        let stdS = stats.stddevMs.map { String(format: "%.1f", $0) } ?? "–"
        return "| \(label) | \(loss) | `\(minS)` / **`\(avgS)`** / `\(maxS)` ms (σ `\(stdS)`) |"
    }
}

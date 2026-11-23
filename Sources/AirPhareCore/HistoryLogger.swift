import Foundation

public enum LogEventType: String, Sendable {
    case check = "check"
    case benchmark = "benchmark"
    case rfScan = "rf_scan"
    case wifiReset = "wifi_reset"
}

public actor HistoryLogger {
    public nonisolated let directoryURL: URL
    public nonisolated let csvFileURL: URL

    public static let csvColumns: [String] = [
        "timestamp",
        "event_type",
        "severity",
        "interface",
        "power_on",
        "connected",
        "ssid",
        "bssid",
        "country_code",
        "band",
        "channel",
        "width_mhz",
        "phy_mode",
        "rssi_dbm",
        "noise_dbm",
        "snr_db",
        "tx_rate_mbps",
        "ipv4_address",
        "ipv6_active_prefix_count",
        "ipv6_active_prefixes",
        "ipv6_deprecated_prefix_count",
        "if_ierrs",
        "if_oerrs",
        "if_drops",
        "gateway_host",
        "gw_min_ms",
        "gw_avg_ms",
        "gw_max_ms",
        "gw_stddev_ms",
        "gw_loss_pct",
        "v4_min_ms",
        "v4_avg_ms",
        "v4_max_ms",
        "v4_stddev_ms",
        "v4_loss_pct",
        "v6_min_ms",
        "v6_avg_ms",
        "v6_max_ms",
        "v6_stddev_ms",
        "v6_loss_pct",
        "dns_resolver",
        "dns_ms",
        "dns_ref_server",
        "dns_ref_ms",
        "dns_google_ms",
        "dns_router_host",
        "dns_router_ms",
        "rf_total_networks",
        "rf_best_5ghz_channel",
        "rf_best_2ghz_channel",
        "dl_mbps",
        "ul_mbps",
        "nq_idle_ms",
        "nq_loaded_ms",
        "nq_rpm",
        "nq_rating",
        "nq_ecn",
        "nq_l4s",
        "nq_endpoint",
        "alert_count",
        "alerts"
    ]

    private static var csvHeader: String {
        csvColumns.joined(separator: ",")
    }

    private static let maxFileBytes: UInt64 = 10 * 1024 * 1024 // 10 MB

    public init(directoryURL: URL? = nil) {
        let baseDir: URL
        if let directoryURL {
            baseDir = directoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            baseDir = appSupport.appendingPathComponent("AirPhare", isDirectory: true)
        }
        self.directoryURL = baseDir
        self.csvFileURL = baseDir.appendingPathComponent("airphare-log.csv")
    }

    /// Logs a full English diagnostic record to CSV (independent of UI language).
    public func log(
        eventType: LogEventType,
        wifi: WiFiSnapshot?,
        latency: LatencySnapshot?,
        dns: DNSSnapshot?,
        rfScan: RFScanResult? = nil,
        networkQuality: NetworkQualityResult?,
        report: HealthReport,
        timestamp: Date = .now
    ) {
        do {
            try ensureDirectoryAndHeader(now: timestamp)
            try rotateIfTooLarge(now: timestamp)

            let iso = Self.formatISO(timestamp)
            let alertsText = report.alerts
                .map { "\($0.category.rawValue): \($0.title)" }
                .joined(separator: " | ")

            let columns: [String] = [
                iso,
                eventType.rawValue,
                severityLabel(report.severity),
                wifi?.interfaceName ?? "",
                wifi.map { $0.powerOn ? "true" : "false" } ?? "",
                wifi.map { $0.isConnected ? "true" : "false" } ?? "",
                wifi?.ssid ?? "",
                wifi?.bssid ?? "",
                wifi?.countryCode ?? "",
                wifi?.band.englishLabel ?? "",
                wifi.map { String($0.channel) } ?? "",
                wifi.map { String($0.channelWidthMHz) } ?? "",
                wifi?.phyMode ?? "",
                wifi.map { String($0.rssi) } ?? "",
                wifi.map { String($0.noise) } ?? "",
                wifi.map { String($0.snr) } ?? "",
                wifi.map { String(format: "%.0f", $0.txRateMbps) } ?? "",
                wifi?.ipv4Address ?? "",
                wifi.map { String($0.activeGlobalIPv6Prefixes.count) } ?? "",
                wifi?.activeGlobalIPv6Prefixes.joined(separator: " | ") ?? "",
                wifi.map { String($0.deprecatedIPv6Prefixes.count) } ?? "",
                wifi?.interfaceInputErrors.map(String.init) ?? "",
                wifi?.interfaceOutputErrors.map(String.init) ?? "",
                wifi?.interfaceDrops.map(String.init) ?? "",
                latency?.gatewayHost ?? "",
                formatOpt(latency?.gateway?.minMs),
                formatOpt(latency?.gateway?.avgMs),
                formatOpt(latency?.gateway?.maxMs),
                formatOpt(latency?.gateway?.stddevMs),
                formatOpt(latency?.gateway?.packetLossPercent),
                formatOpt(latency?.ipv4Internet?.minMs),
                formatOpt(latency?.ipv4Internet?.avgMs),
                formatOpt(latency?.ipv4Internet?.maxMs),
                formatOpt(latency?.ipv4Internet?.stddevMs),
                formatOpt(latency?.ipv4Internet?.packetLossPercent),
                formatOpt(latency?.ipv6Internet?.minMs),
                formatOpt(latency?.ipv6Internet?.avgMs),
                formatOpt(latency?.ipv6Internet?.maxMs),
                formatOpt(latency?.ipv6Internet?.stddevMs),
                formatOpt(latency?.ipv6Internet?.packetLossPercent),
                dns?.activeResolver ?? "",
                dns?.activeLatencyMs.map(String.init) ?? "",
                dns?.referenceServer ?? "",
                dns?.referenceLatencyMs.map(String.init) ?? "",
                dns?.googleLatencyMs.map(String.init) ?? "",
                dns?.routerHost ?? "",
                dns?.routerLatencyMs.map(String.init) ?? "",
                rfScan.map { String($0.totalNetworks) } ?? "",
                rfScan?.recommended5GHz.map { String($0.channel) } ?? "",
                rfScan?.recommended2GHz.map { String($0.channel) } ?? "",
                formatOpt(networkQuality?.downlinkMbps),
                formatOpt(networkQuality?.uplinkMbps),
                formatOpt(networkQuality?.idleLatencyMs),
                formatOpt(networkQuality?.loadedLatencyMs),
                networkQuality.map { String($0.responsivenessRPM) } ?? "",
                networkQuality?.responsivenessRating(lang: .en) ?? "",
                networkQuality.map { $0.ecnEnabled ? "true" : "false" } ?? "",
                networkQuality.map { $0.l4sEnabled ? "true" : "false" } ?? "",
                networkQuality?.endpoint ?? "",
                String(report.alerts.count),
                alertsText
            ]

            let line = columns.map(Self.csvEscape).joined(separator: ",") + "\n"
            guard let data = line.data(using: .utf8) else { return }

            let handle = try FileHandle(forWritingTo: csvFileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Silently ignore disk errors to never crash monitoring loop
        }
    }

    public func loadRecentSamples(limit: Int = 48) -> [CheckSample] {
        guard let content = try? String(contentsOf: csvFileURL, encoding: .utf8) else {
            return []
        }

        let allLines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = allLines.first else { return [] }

        let headerCols = Self.parseCSVRow(headerLine)
        var colIndex: [String: Int] = [:]
        for (idx, name) in headerCols.enumerated() {
            colIndex[name] = idx
        }

        func value(_ name: String, in cols: [String]) -> String? {
            guard let idx = colIndex[name], idx < cols.count else { return nil }
            let val = cols[idx]
            return val.isEmpty ? nil : val
        }

        let recentLines = allLines.dropFirst().suffix(limit)
        let formatter = ISO8601DateFormatter()

        return recentLines.compactMap { line -> CheckSample? in
            let cols = Self.parseCSVRow(line)
            guard !cols.isEmpty else { return nil }
            let date = value("timestamp", in: cols).flatMap { formatter.date(from: $0) } ?? .now
            let band = value("band", in: cols).flatMap(WiFiBand.fromCSVLabel)
            let channel = value("channel", in: cols).flatMap(Int.init)
            let snr = value("snr_db", in: cols).flatMap(Int.init)
            let gwAvg = value("gw_avg_ms", in: cols).flatMap(Double.init)
            let v4Avg = value("v4_avg_ms", in: cols).flatMap(Double.init)
            let v6Loss = value("v6_loss_pct", in: cols).flatMap(Double.init)
            let v6Ok = v6Loss.map { $0 < 100.0 }

            return CheckSample(
                timestamp: date,
                snr: snr,
                gatewayAvgMs: gwAvg,
                internetAvgMs: v4Avg,
                ipv6Reachable: v6Ok,
                channel: channel,
                band: band
            )
        }
    }

    public func entryCount() -> Int {
        guard let content = try? String(contentsOf: csvFileURL, encoding: .utf8) else {
            return 0
        }
        let nonEmpty = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return max(0, nonEmpty.count - 1)
    }

    private func ensureDirectoryAndHeader(now: Date) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        if fm.fileExists(atPath: csvFileURL.path) {
            // If CSV header schema changed (e.g., upgraded from older version), archive old log cleanly
            if let existing = try? String(contentsOf: csvFileURL, encoding: .utf8),
               let firstLine = existing.components(separatedBy: .newlines).first,
               firstLine != Self.csvHeader {
                let df = DateFormatter()
                df.dateFormat = "yyyyMMdd-HHmmss"
                let legacyURL = directoryURL.appendingPathComponent("airphare-log-legacy-\(df.string(from: now)).csv")
                try fm.moveItem(at: csvFileURL, to: legacyURL)
            }
        }
        if !fm.fileExists(atPath: csvFileURL.path) {
            try (Self.csvHeader + "\n").write(to: csvFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func rotateIfTooLarge(now: Date) throws {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: csvFileURL.path),
              let size = attrs[.size] as? UInt64,
              size >= Self.maxFileBytes else {
            return
        }
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let archiveURL = directoryURL.appendingPathComponent("airphare-log-\(df.string(from: now)).csv")
        try fm.moveItem(at: csvFileURL, to: archiveURL)
        try (Self.csvHeader + "\n").write(to: csvFileURL, atomically: true, encoding: .utf8)
    }

    private func severityLabel(_ severity: HealthSeverity) -> String {
        switch severity {
        case .ok: return "ok"
        case .warning: return "warning"
        case .critical: return "critical"
        }
    }

    private func formatOpt(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value)
    }

    private static func formatISO(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    public static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    public static func parseCSVRow(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let ch = iterator.next() {
            if inQuotes {
                if ch == "\"" {
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else if next == "," {
                            inQuotes = false
                            result.append(current)
                            current = ""
                        } else {
                            inQuotes = false
                            current.append(next)
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == "," {
                    result.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        result.append(current)
        return result
    }
}

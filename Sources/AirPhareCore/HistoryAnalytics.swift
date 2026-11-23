import Foundation

public enum AnalyticsWindow: String, CaseIterable, Identifiable, Sendable {
    case last24Hours
    case last7Days

    public var id: String { rawValue }

    public var durationSeconds: TimeInterval {
        switch self {
        case .last24Hours: return 24 * 3600
        case .last7Days: return 7 * 24 * 3600
        }
    }
}

public struct AnalyticsPoint: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let snr: Int?
    public let gatewayAvgMs: Double?
    public let internetAvgMs: Double?
    public let channel: Int?
    public let band: WiFiBand?
    public let isConnected: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        snr: Int?,
        gatewayAvgMs: Double?,
        internetAvgMs: Double?,
        channel: Int?,
        band: WiFiBand?,
        isConnected: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.snr = snr
        self.gatewayAvgMs = gatewayAvgMs
        self.internetAvgMs = internetAvgMs
        self.channel = channel
        self.band = band
        self.isConnected = isConnected
    }
}

public struct AnalyticsSummary: Sendable, Equatable {
    public let window: AnalyticsWindow
    public let totalChecks: Int
    public let uptimePercent: Double
    public let avgSNR: Double?
    public let minSNR: Int?
    public let avgGatewayMs: Double?
    public let maxGatewayMs: Double?
    public let avgInternetMs: Double?
    public let dfsDriftCount: Int
    public let wrongBandCount: Int
    public let ipv6OutageCount: Int
    public let wifiJitterCount: Int
    public let ispIssueCount: Int
    public let uniqueSSIDs: [String]
    public let points: [AnalyticsPoint]

    public var totalIncidents: Int {
        dfsDriftCount + wrongBandCount + ipv6OutageCount + wifiJitterCount + ispIssueCount
    }

    public init(
        window: AnalyticsWindow,
        totalChecks: Int,
        uptimePercent: Double,
        avgSNR: Double?,
        minSNR: Int?,
        avgGatewayMs: Double?,
        maxGatewayMs: Double?,
        avgInternetMs: Double?,
        dfsDriftCount: Int,
        wrongBandCount: Int,
        ipv6OutageCount: Int,
        wifiJitterCount: Int,
        ispIssueCount: Int,
        uniqueSSIDs: [String],
        points: [AnalyticsPoint]
    ) {
        self.window = window
        self.totalChecks = totalChecks
        self.uptimePercent = uptimePercent
        self.avgSNR = avgSNR
        self.minSNR = minSNR
        self.avgGatewayMs = avgGatewayMs
        self.maxGatewayMs = maxGatewayMs
        self.avgInternetMs = avgInternetMs
        self.dfsDriftCount = dfsDriftCount
        self.wrongBandCount = wrongBandCount
        self.ipv6OutageCount = ipv6OutageCount
        self.wifiJitterCount = wifiJitterCount
        self.ispIssueCount = ispIssueCount
        self.uniqueSSIDs = uniqueSSIDs
        self.points = points
    }
}

public enum HistoryAnalytics {

    public static func analyzeCSV(
        at url: URL,
        window: AnalyticsWindow,
        now: Date = .now
    ) -> AnalyticsSummary {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return empty(window: window)
        }
        return analyzeCSVText(content, window: window, now: now)
    }

    public static func analyzeCSVText(
        _ content: String,
        window: AnalyticsWindow,
        now: Date = .now
    ) -> AnalyticsSummary {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else {
            return empty(window: window)
        }

        let headers = HistoryLogger.parseCSVRow(headerLine)
        var colIndex: [String: Int] = [:]
        for (idx, name) in headers.enumerated() {
            colIndex[name] = idx
        }

        func value(_ name: String, in cols: [String]) -> String? {
            guard let idx = colIndex[name], idx < cols.count else { return nil }
            let val = cols[idx]
            return val.isEmpty ? nil : val
        }

        let cutoff = now.addingTimeInterval(-window.durationSeconds)
        let iso = ISO8601DateFormatter()

        var totalChecks = 0
        var connectedChecks = 0
        var snrValues: [Int] = []
        var gwAvgValues: [Double] = []
        var gwMaxValues: [Double] = []
        var v4AvgValues: [Double] = []
        var dfsDriftCount = 0
        var wrongBandCount = 0
        var ipv6OutageCount = 0
        var wifiJitterCount = 0
        var ispIssueCount = 0
        var ssids = Set<String>()
        var points: [AnalyticsPoint] = []

        for line in lines.dropFirst() {
            let cols = HistoryLogger.parseCSVRow(line)
            guard let tsStr = value("timestamp", in: cols),
                  let date = iso.date(from: tsStr),
                  date >= cutoff else {
                continue
            }

            totalChecks += 1
            let connected = value("connected", in: cols).map { $0.lowercased() == "true" } ?? true
            if connected { connectedChecks += 1 }

            if let ssid = value("ssid", in: cols) {
                ssids.insert(ssid)
            }

            let snr = value("snr_db", in: cols).flatMap(Int.init)
            if let snr { snrValues.append(snr) }

            let gwAvg = value("gw_avg_ms", in: cols).flatMap(Double.init)
            if let gwAvg { gwAvgValues.append(gwAvg) }

            let gwMax = value("gw_max_ms", in: cols).flatMap(Double.init)
            if let gwMax { gwMaxValues.append(gwMax) }

            let v4Avg = value("v4_avg_ms", in: cols).flatMap(Double.init)
            if let v4Avg { v4AvgValues.append(v4Avg) }

            let alerts = value("alerts", in: cols) ?? ""
            if alerts.contains(AlertCategory.channelDrift.rawValue) { dfsDriftCount += 1 }
            if alerts.contains(AlertCategory.wrongBand2GHz.rawValue) { wrongBandCount += 1 }
            if alerts.contains(AlertCategory.ipv6Broken.rawValue) {
                ipv6OutageCount += 1
            } else if let v6Loss = value("v6_loss_pct", in: cols).flatMap(Double.init), v6Loss >= 100.0 {
                ipv6OutageCount += 1
            }
            if alerts.contains(AlertCategory.wifiJitter.rawValue) { wifiJitterCount += 1 }
            if alerts.contains(AlertCategory.ispIssue.rawValue) { ispIssueCount += 1 }

            let channel = value("channel", in: cols).flatMap(Int.init)
            let band = value("band", in: cols).flatMap(WiFiBand.fromCSVLabel)

            points.append(AnalyticsPoint(
                timestamp: date,
                snr: snr,
                gatewayAvgMs: gwAvg,
                internetAvgMs: v4Avg,
                channel: channel,
                band: band,
                isConnected: connected
            ))
        }

        // Downsample chart points to max 120 for crisp rendering over 7d
        let chartPoints: [AnalyticsPoint]
        if points.count > 120 {
            let strideStep = max(1, points.count / 120)
            chartPoints = stride(from: 0, to: points.count, by: strideStep).map { points[$0] }
        } else {
            chartPoints = points
        }

        let uptime = totalChecks > 0 ? (Double(connectedChecks) / Double(totalChecks)) * 100.0 : 0.0
        let avgSNR = snrValues.isEmpty ? nil : Double(snrValues.reduce(0, +)) / Double(snrValues.count)
        let avgGW = gwAvgValues.isEmpty ? nil : gwAvgValues.reduce(0, +) / Double(gwAvgValues.count)
        let avgV4 = v4AvgValues.isEmpty ? nil : v4AvgValues.reduce(0, +) / Double(v4AvgValues.count)

        return AnalyticsSummary(
            window: window,
            totalChecks: totalChecks,
            uptimePercent: uptime,
            avgSNR: avgSNR,
            minSNR: snrValues.min(),
            avgGatewayMs: avgGW,
            maxGatewayMs: gwMaxValues.max(),
            avgInternetMs: avgV4,
            dfsDriftCount: dfsDriftCount,
            wrongBandCount: wrongBandCount,
            ipv6OutageCount: ipv6OutageCount,
            wifiJitterCount: wifiJitterCount,
            ispIssueCount: ispIssueCount,
            uniqueSSIDs: ssids.sorted(),
            points: chartPoints
        )
    }

    private static func empty(window: AnalyticsWindow) -> AnalyticsSummary {
        AnalyticsSummary(
            window: window,
            totalChecks: 0,
            uptimePercent: 0,
            avgSNR: nil,
            minSNR: nil,
            avgGatewayMs: nil,
            maxGatewayMs: nil,
            avgInternetMs: nil,
            dfsDriftCount: 0,
            wrongBandCount: 0,
            ipv6OutageCount: 0,
            wifiJitterCount: 0,
            ispIssueCount: 0,
            uniqueSSIDs: [],
            points: []
        )
    }
}

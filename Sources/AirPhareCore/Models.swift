import Foundation

public enum WiFiBand: String, Codable, Sendable, CaseIterable {
    case band2GHz = "2,4 GHz"
    case band5GHz = "5 GHz"
    case band6GHz = "6 GHz"
    case unknown = "Unbekannt"

    public var shortLabel: String {
        switch self {
        case .band2GHz: return "2.4G"
        case .band5GHz: return "5G"
        case .band6GHz: return "6G"
        case .unknown: return "?"
        }
    }

    public var englishLabel: String {
        switch self {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        case .unknown: return "unknown"
        }
    }

    public static func fromCSVLabel(_ value: String) -> WiFiBand? {
        if let direct = WiFiBand(rawValue: value) { return direct }
        switch value.lowercased() {
        case "2.4 ghz", "2.4g": return .band2GHz
        case "5 ghz", "5g": return .band5GHz
        case "6 ghz", "6g": return .band6GHz
        case "unknown": return .unknown
        default: return nil
        }
    }
}

public struct WiFiSnapshot: Codable, Sendable, Equatable {
    public let interfaceName: String
    public let powerOn: Bool
    public let isConnected: Bool
    public let ssid: String?
    public let bssid: String?
    public let countryCode: String?
    public let band: WiFiBand
    public let channel: Int
    public let channelWidthMHz: Int
    public let phyMode: String
    public let rssi: Int
    public let noise: Int
    public let txRateMbps: Double
    public let ipv4Address: String?
    public let activeGlobalIPv6Prefixes: [String]
    public let deprecatedIPv6Prefixes: [String]
    public let interfaceInputErrors: UInt64?
    public let interfaceOutputErrors: UInt64?
    public let interfaceDrops: UInt64?
    public let timestamp: Date

    public var snr: Int {
        rssi - noise
    }

    public init(
        interfaceName: String,
        powerOn: Bool = true,
        isConnected: Bool,
        ssid: String?,
        bssid: String? = nil,
        countryCode: String? = nil,
        band: WiFiBand,
        channel: Int,
        channelWidthMHz: Int,
        phyMode: String,
        rssi: Int,
        noise: Int,
        txRateMbps: Double,
        ipv4Address: String? = nil,
        activeGlobalIPv6Prefixes: [String] = [],
        deprecatedIPv6Prefixes: [String] = [],
        interfaceInputErrors: UInt64? = nil,
        interfaceOutputErrors: UInt64? = nil,
        interfaceDrops: UInt64? = nil,
        timestamp: Date = .now
    ) {
        self.interfaceName = interfaceName
        self.powerOn = powerOn
        self.isConnected = isConnected
        self.ssid = ssid
        self.bssid = bssid
        self.countryCode = countryCode
        self.band = band
        self.channel = channel
        self.channelWidthMHz = channelWidthMHz
        self.phyMode = phyMode
        self.rssi = rssi
        self.noise = noise
        self.txRateMbps = txRateMbps
        self.ipv4Address = ipv4Address
        self.activeGlobalIPv6Prefixes = activeGlobalIPv6Prefixes
        self.deprecatedIPv6Prefixes = deprecatedIPv6Prefixes
        self.interfaceInputErrors = interfaceInputErrors
        self.interfaceOutputErrors = interfaceOutputErrors
        self.interfaceDrops = interfaceDrops
        self.timestamp = timestamp
    }
}

public struct NearbyNetwork: Codable, Sendable, Equatable, Identifiable {
    public var id: String { ssid }
    public let ssid: String
    public let rssi: Int
    public let band: WiFiBand
    public let channel: Int
    public let isSecure: Bool
    public let isKnown: Bool

    public init(
        ssid: String,
        rssi: Int,
        band: WiFiBand,
        channel: Int,
        isSecure: Bool,
        isKnown: Bool
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.band = band
        self.channel = channel
        self.isSecure = isSecure
        self.isKnown = isKnown
    }
}

public struct WiFiActionResult: Sendable, Equatable {
    public let success: Bool
    public let message: String?

    public init(success: Bool, message: String? = nil) {
        self.success = success
        self.message = message
    }
}

public struct PingStats: Codable, Sendable, Equatable {
    public let host: String
    public let transmitted: Int
    public let received: Int
    public let packetLossPercent: Double
    public let minMs: Double?
    public let avgMs: Double?
    public let maxMs: Double?
    public let stddevMs: Double?

    public var isReachable: Bool {
        received > 0 && packetLossPercent < 100.0
    }

    public init(
        host: String,
        transmitted: Int,
        received: Int,
        packetLossPercent: Double,
        minMs: Double?,
        avgMs: Double?,
        maxMs: Double?,
        stddevMs: Double?
    ) {
        self.host = host
        self.transmitted = transmitted
        self.received = received
        self.packetLossPercent = packetLossPercent
        self.minMs = minMs
        self.avgMs = avgMs
        self.maxMs = maxMs
        self.stddevMs = stddevMs
    }
}

public struct LatencySnapshot: Codable, Sendable, Equatable {
    public let gatewayHost: String?
    public let gateway: PingStats?
    public let ipv4Internet: PingStats?
    public let ipv6Internet: PingStats?
    public let timestamp: Date

    public init(
        gatewayHost: String?,
        gateway: PingStats?,
        ipv4Internet: PingStats?,
        ipv6Internet: PingStats?,
        timestamp: Date = .now
    ) {
        self.gatewayHost = gatewayHost
        self.gateway = gateway
        self.ipv4Internet = ipv4Internet
        self.ipv6Internet = ipv6Internet
        self.timestamp = timestamp
    }
}

public struct DNSSnapshot: Codable, Sendable, Equatable {
    public let activeResolver: String?
    public let activeLatencyMs: Int?
    public let referenceServer: String
    public let referenceLatencyMs: Int?
    public let googleLatencyMs: Int?
    public let routerHost: String?
    public let routerLatencyMs: Int?
    public let timestamp: Date

    public var fastestServer: (label: String, latencyMs: Int)? {
        var candidates: [(String, Int)] = []
        if let active = activeResolver, let ms = activeLatencyMs {
            candidates.append((active, ms))
        }
        if let ms = referenceLatencyMs {
            candidates.append((referenceServer, ms))
        }
        if let ms = googleLatencyMs {
            candidates.append(("8.8.8.8", ms))
        }
        if let gw = routerHost, let ms = routerLatencyMs, gw != activeResolver {
            candidates.append((gw, ms))
        }
        return candidates.min(by: { $0.1 < $1.1 })
    }

    public init(
        activeResolver: String?,
        activeLatencyMs: Int?,
        referenceServer: String = "1.1.1.1",
        referenceLatencyMs: Int?,
        googleLatencyMs: Int? = nil,
        routerHost: String? = nil,
        routerLatencyMs: Int? = nil,
        timestamp: Date = .now
    ) {
        self.activeResolver = activeResolver
        self.activeLatencyMs = activeLatencyMs
        self.referenceServer = referenceServer
        self.referenceLatencyMs = referenceLatencyMs
        self.googleLatencyMs = googleLatencyMs
        self.routerHost = routerHost
        self.routerLatencyMs = routerLatencyMs
        self.timestamp = timestamp
    }
}

public struct ScannedNetwork: Codable, Sendable, Equatable {
    public let channel: Int
    public let band: WiFiBand
    public let channelWidthMHz: Int
    public let rssi: Int?

    public init(channel: Int, band: WiFiBand, channelWidthMHz: Int, rssi: Int? = nil) {
        self.channel = channel
        self.band = band
        self.channelWidthMHz = channelWidthMHz
        self.rssi = rssi
    }
}

public struct ChannelScore: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(band.rawValue)-\(channel)" }
    public let channel: Int
    public let band: WiFiBand
    public let overlappingAPCount: Int
    public let strongestInterfererRSSI: Int?
    public let isDFS: Bool
    public let isWeatherRadarDFS: Bool
    public let score: Double
    public let note: String

    public init(
        channel: Int,
        band: WiFiBand,
        overlappingAPCount: Int,
        strongestInterfererRSSI: Int?,
        isDFS: Bool,
        isWeatherRadarDFS: Bool,
        score: Double,
        note: String
    ) {
        self.channel = channel
        self.band = band
        self.overlappingAPCount = overlappingAPCount
        self.strongestInterfererRSSI = strongestInterfererRSSI
        self.isDFS = isDFS
        self.isWeatherRadarDFS = isWeatherRadarDFS
        self.score = score
        self.note = note
    }
}

public struct RFScanResult: Codable, Sendable, Equatable {
    public let totalNetworks: Int
    public let recommended5GHz: ChannelScore?
    public let recommended2GHz: ChannelScore?
    public let scores5GHz: [ChannelScore]
    public let scores2GHz: [ChannelScore]
    public let timestamp: Date

    public init(
        totalNetworks: Int,
        recommended5GHz: ChannelScore?,
        recommended2GHz: ChannelScore?,
        scores5GHz: [ChannelScore],
        scores2GHz: [ChannelScore],
        timestamp: Date = .now
    ) {
        self.totalNetworks = totalNetworks
        self.recommended5GHz = recommended5GHz
        self.recommended2GHz = recommended2GHz
        self.scores5GHz = scores5GHz
        self.scores2GHz = scores2GHz
        self.timestamp = timestamp
    }
}

public struct NetworkQualityResult: Codable, Sendable, Equatable {
    public let downlinkMbps: Double
    public let uplinkMbps: Double
    public let idleLatencyMs: Double
    public let loadedLatencyMs: Double
    public let responsivenessRPM: Int
    public let ecnEnabled: Bool
    public let l4sEnabled: Bool
    public let endpoint: String?
    public let timestamp: Date

    public func responsivenessRating(lang: ResolvedLanguage) -> String {
        switch responsivenessRPM {
        case 1000...: return L10n.t(.ratingHigh, lang: lang)
        case 300..<1000: return L10n.t(.ratingMedium, lang: lang)
        default: return L10n.t(.ratingLow, lang: lang)
        }
    }

    public var responsivenessRating: String {
        responsivenessRating(lang: .en)
    }

    public init(
        downlinkMbps: Double,
        uplinkMbps: Double,
        idleLatencyMs: Double,
        loadedLatencyMs: Double,
        responsivenessRPM: Int,
        ecnEnabled: Bool,
        l4sEnabled: Bool,
        endpoint: String?,
        timestamp: Date = .now
    ) {
        self.downlinkMbps = downlinkMbps
        self.uplinkMbps = uplinkMbps
        self.idleLatencyMs = idleLatencyMs
        self.loadedLatencyMs = loadedLatencyMs
        self.responsivenessRPM = responsivenessRPM
        self.ecnEnabled = ecnEnabled
        self.l4sEnabled = l4sEnabled
        self.endpoint = endpoint
        self.timestamp = timestamp
    }
}

public enum HealthSeverity: Int, Codable, Sendable, Comparable {
    case ok = 0
    case warning = 1
    case critical = 2

    public static func < (lhs: HealthSeverity, rhs: HealthSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum AlertCategory: String, Codable, Sendable {
    case disconnected
    case wrongBand2GHz
    case channelDrift
    case lowSNR
    case ipv6Broken
    case ipv6StalePrefix
    case wifiJitter
    case ispIssue
    case slowDNS
    case betterChannelAvailable
}

public enum QuickAction: String, Codable, Sendable {
    case none
    case reconnectWiFi
    case runRFScan
    case openRouterSettings
}

public struct HealthAlert: Codable, Sendable, Equatable, Identifiable {
    public var id: String { category.rawValue }
    public let category: AlertCategory
    public let severity: HealthSeverity
    public let title: String
    public let message: String
    public let actionHint: String
    public let quickAction: QuickAction

    public init(
        category: AlertCategory,
        severity: HealthSeverity,
        title: String,
        message: String,
        actionHint: String,
        quickAction: QuickAction = .none
    ) {
        self.category = category
        self.severity = severity
        self.title = title
        self.message = message
        self.actionHint = actionHint
        self.quickAction = quickAction
    }
}

public struct HealthReport: Sendable, Equatable {
    public let severity: HealthSeverity
    public let headline: String
    public let alerts: [HealthAlert]
    public let bottleneckSummary: String

    public init(
        severity: HealthSeverity,
        headline: String,
        alerts: [HealthAlert],
        bottleneckSummary: String
    ) {
        self.severity = severity
        self.headline = headline
        self.alerts = alerts
        self.bottleneckSummary = bottleneckSummary
    }
}

public struct CheckSample: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let snr: Int?
    public let gatewayAvgMs: Double?
    public let internetAvgMs: Double?
    public let ipv6Reachable: Bool?
    public let channel: Int?
    public let band: WiFiBand?

    public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        snr: Int?,
        gatewayAvgMs: Double?,
        internetAvgMs: Double?,
        ipv6Reachable: Bool?,
        channel: Int?,
        band: WiFiBand?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.snr = snr
        self.gatewayAvgMs = gatewayAvgMs
        self.internetAvgMs = internetAvgMs
        self.ipv6Reachable = ipv6Reachable
        self.channel = channel
        self.band = band
    }
}

public struct MonitorSettings: Codable, Sendable, Equatable {
    public var language: AppLanguage
    public var preferred5GHzChannel: Int
    public var expect5GHz: Bool
    public var checkIntervalMinutes: Int
    public var routerURL: String
    public var notificationsEnabled: Bool
    public var showMenuBarMetrics: Bool
    public var snrWarningThreshold: Int
    public var gatewayAvgWarningMs: Double
    public var dnsWarningMs: Int

    public static let `default` = MonitorSettings(
        language: .system,
        preferred5GHzChannel: 100,
        expect5GHz: true,
        checkIntervalMinutes: 5,
        routerURL: "http://speedport.ip",
        notificationsEnabled: true,
        showMenuBarMetrics: false,
        snrWarningThreshold: 22,
        gatewayAvgWarningMs: 35.0,
        dnsWarningMs: 80
    )

    public init(
        language: AppLanguage = .system,
        preferred5GHzChannel: Int,
        expect5GHz: Bool,
        checkIntervalMinutes: Int,
        routerURL: String,
        notificationsEnabled: Bool,
        showMenuBarMetrics: Bool,
        snrWarningThreshold: Int,
        gatewayAvgWarningMs: Double,
        dnsWarningMs: Int
    ) {
        self.language = language
        self.preferred5GHzChannel = preferred5GHzChannel
        self.expect5GHz = expect5GHz
        self.checkIntervalMinutes = checkIntervalMinutes
        self.routerURL = routerURL
        self.notificationsEnabled = notificationsEnabled
        self.showMenuBarMetrics = showMenuBarMetrics
        self.snrWarningThreshold = snrWarningThreshold
        self.gatewayAvgWarningMs = gatewayAvgWarningMs
        self.dnsWarningMs = dnsWarningMs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let def = MonitorSettings.default
        self.language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? def.language
        self.preferred5GHzChannel = try c.decodeIfPresent(Int.self, forKey: .preferred5GHzChannel) ?? def.preferred5GHzChannel
        self.expect5GHz = try c.decodeIfPresent(Bool.self, forKey: .expect5GHz) ?? def.expect5GHz
        self.checkIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .checkIntervalMinutes) ?? def.checkIntervalMinutes
        self.routerURL = try c.decodeIfPresent(String.self, forKey: .routerURL) ?? def.routerURL
        self.notificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? def.notificationsEnabled
        self.showMenuBarMetrics = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarMetrics) ?? def.showMenuBarMetrics
        self.snrWarningThreshold = try c.decodeIfPresent(Int.self, forKey: .snrWarningThreshold) ?? def.snrWarningThreshold
        self.gatewayAvgWarningMs = try c.decodeIfPresent(Double.self, forKey: .gatewayAvgWarningMs) ?? def.gatewayAvgWarningMs
        self.dnsWarningMs = try c.decodeIfPresent(Int.self, forKey: .dnsWarningMs) ?? def.dnsWarningMs
    }
}

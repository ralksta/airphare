import Foundation

public enum ResolvedLanguage: String, Codable, Sendable, CaseIterable {
    case en
    case de
    case it
    case fr
    case es
    case nl
}

public enum AppLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case en
    case de
    case it
    case fr
    case es
    case nl

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "System (Auto)"
        case .en: return "English"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .fr: return "Français"
        case .es: return "Español"
        case .nl: return "Nederlands"
        }
    }

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .en: return .en
        case .de: return .de
        case .it: return .it
        case .fr: return .fr
        case .es: return .es
        case .nl: return .nl
        case .system:
            for tag in preferredLanguages {
                let code = tag.lowercased().prefix(2)
                if let match = ResolvedLanguage(rawValue: String(code)) {
                    return match
                }
            }
            return .en
        }
    }
}

public enum L10nKey: String, CaseIterable, Sendable {
    // Bands & generic
    case bandUnknown
    case ratingHigh
    case ratingMedium
    case ratingLow
    case onLabel
    case offLabel
    case offline

    // Header & status
    case wifiTitle
    case wifiOff
    case startingFirstCheck
    case waitingForMetrics
    case statusUpdatedAt
    case statusEveryMin
    case menuBarAccessibility
    case toggleWiFiAccessibility
    case openSettingsAccessibility
    case closeSettingsAccessibility

    // Known & other networks
    case knownNetworks
    case noSavedNetworks
    case locationHintKnown
    case allowButton
    case otherNetworks
    case scanningNearby
    case locationHintNearby
    case allowLocationButton
    case noOtherNetworks
    case rescanButton
    case wifiPasswordPlaceholder
    case connectButton
    case connectedA11y
    case connectToA11y
    case networkNotFound
    case networkJoinFailed
    case networkJoinGenericFailed

    // Alerts & Evaluator
    case alertTipPrefix
    case alertDisconnectedTitle
    case alertDisconnectedMsg
    case alertDisconnectedHint
    case headlineDisconnected
    case bottleneckDisconnected

    case alertWrongBandTitle
    case alertWrongBandMsg
    case alertWrongBandHint

    case alertChannelDriftTitle
    case alertChannelDriftMsg
    case alertChannelDriftHint

    case alertLowSNRTitle
    case alertLowSNRMsg
    case alertLowSNRHInt

    case alertIPv6BrokenTitle
    case alertIPv6BrokenMultiMsg
    case alertIPv6BrokenLoopMsg
    case alertIPv6BrokenHint

    case alertIPv6StaleTitle
    case alertIPv6StaleMsg
    case alertIPv6StaleHint

    case alertWiFiJitterTitle
    case alertWiFiJitterMsg
    case alertWiFiJitterHint

    case alertISPIssueTitle
    case alertISPIssueMsg
    case alertISPIssueHint

    case alertSlowDNSTitle
    case alertSlowDNSMsg
    case alertSlowDNSHint

    case alertBetterChannelTitle
    case alertBetterChannelMsg
    case alertBetterChannelHint

    case headlineOK
    case headlineWarningFallback
    case headlineCriticalFallback
    case bottleneckOK
    case bottleneckDetailsFallback
    case bottleneckCheckNowFallback

    // Quick Actions
    case actionReconnectWiFi
    case actionRunRFScan
    case actionOpenRouter

    // Cards
    case cardRadioLink
    case metricBandChannel
    case metricSignalSNR
    case metricLinkRate
    case noActiveWiFi
    case ipv6NoGlobalPrefix
    case ipv6CleanPrefix
    case ipv6MultiplePrefixes

    case cardLatencyDNS
    case badgeWiFiIssue
    case badgeISPIssue
    case badgeIPv6Down
    case badgeAllOK
    case metricRouterHop1
    case metricIPv4
    case metricIPv6
    case loss100
    case dnsActiveLabel

    case cardThroughputBufferbloat
    case metricDownlink
    case metricUplink
    case metricLoadedRPM
    case throughputSummary

    case cardRFEnvironment
    case best5GHzChannel
    case best2GHzChannel
    case channelNoteWeatherDFS
    case channelNoteHighPowerDFS
    case channelNoteDFS200
    case channelNoteNoDFS
    case channelNote20MHz

    case sparklineHop1Ping
    case sparklineHistoryA11y

    // Action Bar
    case btnQuickCheck
    case btnFullBenchmark
    case btnChannelScan
    case btnReset
    case btnLog
    case btnLogA11y
    case btnRouter
    case btnWiFiSettings
    case btnQuit

    // Progress messages
    case progChecking
    case progScanningNeighbors
    case progBenchStep1
    case progBenchStep2
    case progBenchStep3
    case progBenchStep4
    case progReconnecting
    case progTurningOn
    case progTurningOff
    case progConnectingTo

    // Settings
    case settingsSectionMonitoring
    case settingsLanguage
    case settingsInterval
    case settingsEveryMinutes
    case settingsPreferredChannel
    case settingsChannelAny
    case settingsChannelN
    case settingsWarn2GHz
    case settingsNotifications
    case settingsShowMenuBarMetrics
    case settingsSectionThresholds
    case settingsSNRThreshold
    case settingsGatewayThreshold
    case settingsDNSThreshold
    case settingsRouterURL
    case settingsSectionSystem
    case settingsLaunchAtLogin
    case settingsRequestLocation
    case settingsDefaults
    case settingsDone
}

public enum L10n {
    public static func t(_ key: L10nKey, lang: ResolvedLanguage) -> String {
        switch lang {
        case .en: return en[key] ?? key.rawValue
        case .de: return de[key] ?? en[key] ?? key.rawValue
        case .it: return it[key] ?? en[key] ?? key.rawValue
        case .fr: return fr[key] ?? en[key] ?? key.rawValue
        case .es: return es[key] ?? en[key] ?? key.rawValue
        case .nl: return nl[key] ?? en[key] ?? key.rawValue
        }
    }

    public static func fmt(_ key: L10nKey, lang: ResolvedLanguage, _ args: CVarArg...) -> String {
        let template = t(key, lang: lang)
        return String(format: template, locale: Locale(identifier: lang.rawValue), arguments: args)
    }

    // MARK: - English (EN)
    private static let en: [L10nKey: String] = [
        .bandUnknown: "Unknown",
        .ratingHigh: "High",
        .ratingMedium: "Medium",
        .ratingLow: "Low",
        .onLabel: "On",
        .offLabel: "Off",
        .offline: "Offline",

        .wifiTitle: "Wi-Fi",
        .wifiOff: "Turned Off",
        .startingFirstCheck: "Running initial check…",
        .waitingForMetrics: "Waiting for measurements",
        .statusUpdatedAt: "Updated: %@ · Every %d min",
        .statusEveryMin: "Every %d min",
        .menuBarAccessibility: "AirPhare Wi-Fi Monitor",
        .toggleWiFiAccessibility: "Toggle Wi-Fi power",
        .openSettingsAccessibility: "Open settings",
        .closeSettingsAccessibility: "Close settings",

        .knownNetworks: "Known Networks",
        .noSavedNetworks: "No saved networks found.",
        .locationHintKnown: "Allow Location Services to filter by range & show active SSID.",
        .allowButton: "Allow",
        .otherNetworks: "Other Networks",
        .scanningNearby: "Scanning nearby networks…",
        .locationHintNearby: "macOS hides nearby Wi-Fi names without Location permission.",
        .allowLocationButton: "Allow Location Access",
        .noOtherNetworks: "No other networks found.",
        .rescanButton: "Rescan",
        .wifiPasswordPlaceholder: "Wi-Fi Password",
        .connectButton: "Connect",
        .connectedA11y: "%@, connected",
        .connectToA11y: "Connect to %@",
        .networkNotFound: "Network “%@” is not in range.",
        .networkJoinFailed: "Failed to join “%@” (check password).",
        .networkJoinGenericFailed: "Failed to connect to “%@”.",

        .alertTipPrefix: "Tip: %@",
        .alertDisconnectedTitle: "Wi-Fi Not Connected",
        .alertDisconnectedMsg: "Your Mac currently has no active Wi-Fi connection.",
        .alertDisconnectedHint: "Turn Wi-Fi on or reconnect.",
        .headlineDisconnected: "Wi-Fi Disconnected",
        .bottleneckDisconnected: "No active Wi-Fi connection",

        .alertWrongBandTitle: "Fell back to slow 2.4 GHz band",
        .alertWrongBandMsg: "Currently connected on 2.4 GHz (Ch %d, %d Mbps).",
        .alertWrongBandHint: "Switch back to your 5 GHz network or reconnect Wi-Fi.",

        .alertChannelDriftTitle: "Router changed 5 GHz channel",
        .alertChannelDriftMsg: "Expected: Ch %d (80 MHz), active: Ch %d.",
        .alertChannelDriftHint: "Likely a DFS radar fallback — check router or run a channel scan.",

        .alertLowSNRTitle: "Weak Wi-Fi signal (SNR %d dB)",
        .alertLowSNRMsg: "Signal %d dBm / Noise %d dBm (Rate: %d Mbps).",
        .alertLowSNRHInt: "Check router placement or run a channel scan for less interference.",

        .alertIPv6BrokenTitle: "IPv6 unreachable (100% packet loss)",
        .alertIPv6BrokenMultiMsg: "A stale IPv6 prefix is stuck on %@ (%d active prefixes).",
        .alertIPv6BrokenLoopMsg: "IPv4 works, but IPv6 packets are dropped (routing loop / prefix bug).",
        .alertIPv6BrokenHint: "Click “Reconnect Wi-Fi” to flush the stale IPv6 prefix immediately.",

        .alertIPv6StaleTitle: "Multiple active IPv6 prefixes detected",
        .alertIPv6StaleMsg: "%@ currently holds %d active global IPv6 prefixes.",
        .alertIPv6StaleHint: "If connections stall, click “Reconnect Wi-Fi”.",

        .alertWiFiJitterTitle: "Wi-Fi jitter on Hop 1 to router",
        .alertWiFiJitterMsg: "Gateway (%@): avg %@ ms, max %@ ms, loss %.0f%%.",
        .alertWiFiJitterHint: "Issue is local to Wi-Fi — run a channel scan or check signal.",

        .alertISPIssueTitle: "ISP line degraded (Wi-Fi OK)",
        .alertISPIssueMsg: "Router clean (%@ ms), but 1.1.1.1 avg %@ ms (%.0f%% loss).",
        .alertISPIssueHint: "Not a Wi-Fi problem — check DSL/fiber line status in your router.",

        .alertSlowDNSTitle: "DNS resolution is slow (%d ms)",
        .alertSlowDNSMsg: "Active resolver (%@) took %d ms vs. %@ (%d ms).",
        .alertSlowDNSHint: "Check Pi-hole / Tailscale DNS or try a Wi-Fi reset.",

        .alertBetterChannelTitle: "Cleaner 5 GHz channel available (Ch %d)",
        .alertBetterChannelMsg: "Current Ch %d has %d overlapping APs; Ch %d has only %d.",
        .alertBetterChannelHint: "Switch your router to Channel %d.",

        .headlineOK: "Everything looks great",
        .headlineWarningFallback: "Minor network issue",
        .headlineCriticalFallback: "Network issue detected",
        .bottleneckOK: "%@ Ch %d · SNR %d dB · Healthy",
        .bottleneckDetailsFallback: "Check details",
        .bottleneckCheckNowFallback: "Check immediately",

        .actionReconnectWiFi: "Reconnect Wi-Fi",
        .actionRunRFScan: "Run Channel Scan",
        .actionOpenRouter: "Open Router",

        .cardRadioLink: "Wi-Fi Link (%@)",
        .metricBandChannel: "Band / Channel",
        .metricSignalSNR: "Signal / SNR",
        .metricLinkRate: "Link Rate",
        .noActiveWiFi: "Not connected to any Wi-Fi network.",
        .ipv6NoGlobalPrefix: "IPv6: no global prefix",
        .ipv6CleanPrefix: "IPv6 clean (%@)",
        .ipv6MultiplePrefixes: "IPv6: %d active prefixes (reset recommended!)",

        .cardLatencyDNS: "Latency (Idle) & DNS",
        .badgeWiFiIssue: "Wi-Fi issue",
        .badgeISPIssue: "ISP issue",
        .badgeIPv6Down: "IPv6 down",
        .badgeAllOK: "Wi-Fi & ISP OK",
        .metricRouterHop1: "Router (Hop 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100% Loss",
        .dnsActiveLabel: "Active DNS (%@):",

        .cardThroughputBufferbloat: "Throughput & Bufferbloat",
        .metricDownlink: "Downlink",
        .metricUplink: "Uplink",
        .metricLoadedRPM: "Loaded / RPM",
        .throughputSummary: "Idle: %.1f ms · Rating: %@ · ECN: %@",

        .cardRFEnvironment: "RF Environment (%d networks)",
        .best5GHzChannel: "Best 5 GHz channel: **Ch %d** (%d interferers · %@)",
        .best2GHzChannel: "Best 2.4 GHz channel: **Ch %d** (%d interferers · 20 MHz)",
        .channelNoteWeatherDFS: "Weather-radar DFS (up to 10 min CAC)",
        .channelNoteHighPowerDFS: "DFS (1 min), up to 1000 mW ETSI",
        .channelNoteDFS200: "DFS (1 min), max 200 mW",
        .channelNoteNoDFS: "Non-DFS, max 200 mW",
        .channelNote20MHz: "20 MHz recommended",

        .sparklineHop1Ping: "Hop-1 Ping",
        .sparklineHistoryA11y: "%@ history",

        .btnQuickCheck: "Quick Check",
        .btnFullBenchmark: "Full Benchmark",
        .btnChannelScan: "Channel Scan",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "Reveal CSV log in Finder",
        .btnRouter: "Router",
        .btnWiFiSettings: "Wi-Fi Settings…",
        .btnQuit: "Quit",

        .progChecking: "Checking Wi-Fi, latency & DNS…",
        .progScanningNeighbors: "Scanning nearby Wi-Fi networks…",
        .progBenchStep1: "1/4: Wi-Fi link & RF scan…",
        .progBenchStep2: "2/4: Idle latency (Gateway, IPv4, IPv6)…",
        .progBenchStep3: "3/4: DNS benchmark…",
        .progBenchStep4: "4/4: Throughput & bufferbloat (networkQuality)…",
        .progReconnecting: "Cycling Wi-Fi off for 3s & back on…",
        .progTurningOn: "Turning Wi-Fi on…",
        .progTurningOff: "Turning Wi-Fi off…",
        .progConnectingTo: "Connecting to %@…",

        .settingsSectionMonitoring: "Monitoring",
        .settingsLanguage: "Language",
        .settingsInterval: "Check Interval",
        .settingsEveryMinutes: "Every %d min",
        .settingsPreferredChannel: "Preferred 5 GHz Channel",
        .settingsChannelAny: "Any",
        .settingsChannelN: "Channel %d",
        .settingsWarn2GHz: "Warn on 2.4 GHz fallback",
        .settingsNotifications: "macOS Notifications",
        .settingsShowMenuBarMetrics: "Show metrics in menu bar",
        .settingsSectionThresholds: "Thresholds & Router",
        .settingsSNRThreshold: "SNR warning below: %d dB",
        .settingsGatewayThreshold: "Gateway ping warning: %d ms",
        .settingsDNSThreshold: "DNS warning above: %d ms",
        .settingsRouterURL: "Router URL",
        .settingsSectionSystem: "System",
        .settingsLaunchAtLogin: "Launch at Login",
        .settingsRequestLocation: "Request Location Access for SSIDs",
        .settingsDefaults: "Defaults",
        .settingsDone: "Done"
    ]

    // MARK: - German (DE)
    private static let de: [L10nKey: String] = [
        .bandUnknown: "Unbekannt",
        .ratingHigh: "Hoch",
        .ratingMedium: "Mittel",
        .ratingLow: "Niedrig",
        .onLabel: "An",
        .offLabel: "Aus",
        .offline: "Offline",

        .wifiTitle: "WLAN",
        .wifiOff: "Ausgeschaltet",
        .startingFirstCheck: "Starte ersten Check…",
        .waitingForMetrics: "Warte auf Messwerte",
        .statusUpdatedAt: "Stand: %@ · Alle %d Min.",
        .statusEveryMin: "Alle %d Min.",
        .menuBarAccessibility: "AirPhare WLAN-Monitor",
        .toggleWiFiAccessibility: "WLAN ein- oder ausschalten",
        .openSettingsAccessibility: "Einstellungen öffnen",
        .closeSettingsAccessibility: "Einstellungen schließen",

        .knownNetworks: "Bekannte Netzwerke",
        .noSavedNetworks: "Keine gespeicherten Netzwerke gefunden.",
        .locationHintKnown: "Ortungsdienste freigeben → filtert nach Reichweite & zeigt aktives WLAN.",
        .allowButton: "Freigeben",
        .otherNetworks: "Andere Netzwerke",
        .scanningNearby: "Suche Netzwerke in der Nähe…",
        .locationHintNearby: "macOS blendet fremde WLAN-Namen ohne Standortfreigabe aus.",
        .allowLocationButton: "Standortfreigabe erlauben",
        .noOtherNetworks: "Keine weiteren Netzwerke gefunden.",
        .rescanButton: "Neu scannen",
        .wifiPasswordPlaceholder: "WLAN-Passwort",
        .connectButton: "Verbinden",
        .connectedA11y: "%@, verbunden",
        .connectToA11y: "Mit %@ verbinden",
        .networkNotFound: "Netzwerk „%@“ gerade nicht in Reichweite.",
        .networkJoinFailed: "Verbindung zu „%@“ fehlgeschlagen (Passwort prüfen).",
        .networkJoinGenericFailed: "Verbindung zu „%@“ fehlgeschlagen.",

        .alertTipPrefix: "Tipp: %@",
        .alertDisconnectedTitle: "Kein WLAN verbunden",
        .alertDisconnectedMsg: "Dein Mac hat gerade keine aktive WLAN-Verbindung.",
        .alertDisconnectedHint: "WLAN einschalten oder neu verbinden.",
        .headlineDisconnected: "WLAN getrennt",
        .bottleneckDisconnected: "Keine aktive WLAN-Verbindung",

        .alertWrongBandTitle: "Im langsamen 2,4-GHz-Band gelandet",
        .alertWrongBandMsg: "Aktuell verbunden auf 2,4 GHz (Kanal %d, %d Mbit/s).",
        .alertWrongBandHint: "Wechsle zurück auf dein 5-GHz-Netz oder verbinde das WLAN neu.",

        .alertChannelDriftTitle: "Router hat den 5-GHz-Kanal gewechselt",
        .alertChannelDriftMsg: "Erwartet: Kanal %d (80 MHz), aktiv: Kanal %d.",
        .alertChannelDriftHint: "Wahrscheinlich DFS-Radar-Sprung — im Router prüfen oder Kanal-Scan starten.",

        .alertLowSNRTitle: "Schwaches WLAN-Signal (SNR %d dB)",
        .alertLowSNRMsg: "Empfang bei %d dBm / Rauschen %d dBm (Rate: %d Mbit/s).",
        .alertLowSNRHInt: "Router-Standort prüfen oder Kanal-Scan für weniger Störung laufen lassen.",

        .alertIPv6BrokenTitle: "IPv6 hängt (100 % Paketverlust)",
        .alertIPv6BrokenMultiMsg: "Altes IPv6-Präfix klebt noch auf %@ (%d aktive Präfixe).",
        .alertIPv6BrokenLoopMsg: "IPv4 läuft, aber IPv6-Pakete gehen verloren (Routing-Loop/Präfix-Bug).",
        .alertIPv6BrokenHint: "Klick auf „WLAN neu verbinden“ — das wirft das tote IPv6-Präfix sofort raus!",

        .alertIPv6StaleTitle: "Mehrere aktive IPv6-Präfixe erkannt",
        .alertIPv6StaleMsg: "Auf %@ sind %d aktive IPv6-Präfixe hinterlegt.",
        .alertIPv6StaleHint: "Bei Stottern kurz „WLAN neu verbinden“ klicken.",

        .alertWiFiJitterTitle: "WLAN-Jitter auf Hop 1 zum Router",
        .alertWiFiJitterMsg: "Gateway (%@): Ø %@ ms, Max %@ ms, Verlust %.0f %%.",
        .alertWiFiJitterHint: "Problem liegt im lokalen WLAN — Kanal-Scan starten oder Signal prüfen.",

        .alertISPIssueTitle: "ISP-Leitung auffällig (WLAN ok)",
        .alertISPIssueMsg: "Router sauber (%@ ms), aber 1.1.1.1 bei Ø %@ ms (%.0f %% Verlust).",
        .alertISPIssueHint: "Kein WLAN-Fehler — DSL/Glasfaser-Status im Router prüfen.",

        .alertSlowDNSTitle: "DNS-Auflösung gerade träge (%d ms)",
        .alertSlowDNSMsg: "Aktiver Resolver (%@) braucht %d ms vs. %@ (%d ms).",
        .alertSlowDNSHint: "Pi-hole / Tailscale DNS prüfen oder WLAN-Reset testen.",

        .alertBetterChannelTitle: "Saubererer 5-GHz-Kanal verfügbar (Kanal %d)",
        .alertBetterChannelMsg: "Aktuell Kanal %d hat %d überlappende APs, Kanal %d nur %d.",
        .alertBetterChannelHint: "Im Router auf Kanal %d wechseln.",

        .headlineOK: "Alles im grünen Bereich",
        .headlineWarningFallback: "Leichte Auffälligkeit",
        .headlineCriticalFallback: "Netzwerk-Störung erkannt",
        .bottleneckOK: "%@ K%d · SNR %d dB · Leitung sauber",
        .bottleneckDetailsFallback: "Details prüfen",
        .bottleneckCheckNowFallback: "Sofort prüfen",

        .actionReconnectWiFi: "WLAN neu verbinden",
        .actionRunRFScan: "Kanal-Scan starten",
        .actionOpenRouter: "Router öffnen",

        .cardRadioLink: "Funk-Link (%@)",
        .metricBandChannel: "Band / Kanal",
        .metricSignalSNR: "Signal / SNR",
        .metricLinkRate: "Link-Rate",
        .noActiveWiFi: "Kein aktives WLAN verbunden.",
        .ipv6NoGlobalPrefix: "IPv6: kein globales Präfix",
        .ipv6CleanPrefix: "IPv6 sauber (%@)",
        .ipv6MultiplePrefixes: "IPv6: %d aktive Präfixe (Reset empfohlen!)",

        .cardLatencyDNS: "Latenz (Idle) & DNS",
        .badgeWiFiIssue: "WLAN auffällig",
        .badgeISPIssue: "ISP auffällig",
        .badgeIPv6Down: "IPv6 hängt",
        .badgeAllOK: "WLAN & ISP ok",
        .metricRouterHop1: "Router (Hop 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100 % Loss",
        .dnsActiveLabel: "DNS aktiv (%@):",

        .cardThroughputBufferbloat: "Durchsatz & Bufferbloat",
        .metricDownlink: "Downlink",
        .metricUplink: "Uplink",
        .metricLoadedRPM: "Loaded / RPM",
        .throughputSummary: "Idle: %.1f ms · Bewertung: %@ · ECN: %@",

        .cardRFEnvironment: "Funk-Umfeld (%d Netze)",
        .best5GHzChannel: "Bester 5-GHz-Kanal: **Kanal %d** (%d Störer · %@)",
        .best2GHzChannel: "Bester 2,4-GHz-Kanal: **Kanal %d** (%d Störer · 20 MHz)",
        .channelNoteWeatherDFS: "Wetterradar-DFS (bis 10 Min. Wartezeit)",
        .channelNoteHighPowerDFS: "DFS (1 Min.), bis 1000 mW erlaubt",
        .channelNoteDFS200: "DFS (1 Min.), max. 200 mW",
        .channelNoteNoDFS: "Kein DFS, max. 200 mW",
        .channelNote20MHz: "20 MHz empfohlen",

        .sparklineHop1Ping: "Hop-1 Ping",
        .sparklineHistoryA11y: "%@ Verlauf",

        .btnQuickCheck: "Schnell-Check",
        .btnFullBenchmark: "Voll-Benchmark",
        .btnChannelScan: "Kanal-Scan",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "Protokoll-Datei im Finder öffnen",
        .btnRouter: "Router",
        .btnWiFiSettings: "WLAN-Einstellungen …",
        .btnQuit: "Beenden",

        .progChecking: "Prüfe WLAN, Latenz & DNS…",
        .progScanningNeighbors: "Scanne Nachbar-WLANs…",
        .progBenchStep1: "1/4: WLAN-Link & Nachbar-Scan…",
        .progBenchStep2: "2/4: Idle-Latenz (Gateway, IPv4, IPv6)…",
        .progBenchStep3: "3/4: DNS-Benchmark…",
        .progBenchStep4: "4/4: Durchsatz & Bufferbloat (networkQuality)…",
        .progReconnecting: "Schalte WLAN 3 Sek. aus & wieder ein…",
        .progTurningOn: "Schalte WLAN ein…",
        .progTurningOff: "Schalte WLAN aus…",
        .progConnectingTo: "Verbinde mit %@…",

        .settingsSectionMonitoring: "Überwachung",
        .settingsLanguage: "Sprache",
        .settingsInterval: "Check-Intervall",
        .settingsEveryMinutes: "Alle %d Min.",
        .settingsPreferredChannel: "Erwarteter 5-GHz-Kanal",
        .settingsChannelAny: "Egal",
        .settingsChannelN: "Kanal %d",
        .settingsWarn2GHz: "Warnen bei 2,4-GHz-Rückfall",
        .settingsNotifications: "macOS-Benachrichtigungen",
        .settingsShowMenuBarMetrics: "Werte in Menüleiste anzeigen",
        .settingsSectionThresholds: "Schwellenwerte & Router",
        .settingsSNRThreshold: "SNR-Warnung unter: %d dB",
        .settingsGatewayThreshold: "Gateway-Ping Warnung: %d ms",
        .settingsDNSThreshold: "DNS-Warnung über: %d ms",
        .settingsRouterURL: "Router-Adresse",
        .settingsSectionSystem: "System",
        .settingsLaunchAtLogin: "Bei Anmeldung starten",
        .settingsRequestLocation: "Standortfreigabe für SSID anfragen",
        .settingsDefaults: "Standardwerte",
        .settingsDone: "Fertig"
    ]

    // MARK: - Italian (IT)
    private static let it: [L10nKey: String] = [
        .bandUnknown: "Sconosciuto",
        .ratingHigh: "Alta",
        .ratingMedium: "Media",
        .ratingLow: "Bassa",
        .onLabel: "Attivo",
        .offLabel: "Disattivo",
        .offline: "Offline",

        .wifiTitle: "Wi-Fi",
        .wifiOff: "Disattivato",
        .startingFirstCheck: "Avvio primo controllo…",
        .waitingForMetrics: "In attesa di misurazioni",
        .statusUpdatedAt: "Aggiornato: %@ · Ogni %d min",
        .statusEveryMin: "Ogni %d min",
        .menuBarAccessibility: "Monitor Wi-Fi AirPhare",
        .toggleWiFiAccessibility: "Attiva o disattiva Wi-Fi",
        .openSettingsAccessibility: "Apri impostazioni",
        .closeSettingsAccessibility: "Chiudi impostazioni",

        .knownNetworks: "Reti note",
        .noSavedNetworks: "Nessuna rete salvata trovata.",
        .locationHintKnown: "Consenti Localizzazione per filtrare per portata e mostrare la rete attiva.",
        .allowButton: "Consenti",
        .otherNetworks: "Altre reti",
        .scanningNearby: "Ricerca reti nelle vicinanze…",
        .locationHintNearby: "macOS nasconde i nomi Wi-Fi senza permesso di localizzazione.",
        .allowLocationButton: "Consenti localizzazione",
        .noOtherNetworks: "Nessun'altra rete trovata.",
        .rescanButton: "Ripeti scansione",
        .wifiPasswordPlaceholder: "Password Wi-Fi",
        .connectButton: "Connetti",
        .connectedA11y: "%@, connesso",
        .connectToA11y: "Connetti a %@",
        .networkNotFound: "La rete “%@” non è nel raggio d'azione.",
        .networkJoinFailed: "Connessione a “%@” non riuscita (controlla la password).",
        .networkJoinGenericFailed: "Impossibile connettersi a “%@”.",

        .alertTipPrefix: "Consiglio: %@",
        .alertDisconnectedTitle: "Wi-Fi non connesso",
        .alertDisconnectedMsg: "Il tuo Mac non ha attualmente una connessione Wi-Fi attiva.",
        .alertDisconnectedHint: "Attiva il Wi-Fi o riconnettiti.",
        .headlineDisconnected: "Wi-Fi disconnesso",
        .bottleneckDisconnected: "Nessuna connessione Wi-Fi attiva",

        .alertWrongBandTitle: "Passato alla banda lenta a 2,4 GHz",
        .alertWrongBandMsg: "Connesso su 2,4 GHz (Canale %d, %d Mbps).",
        .alertWrongBandHint: "Torna alla rete a 5 GHz o riconnetti il Wi-Fi.",

        .alertChannelDriftTitle: "Il router ha cambiato canale 5 GHz",
        .alertChannelDriftMsg: "Atteso: Canale %d (80 MHz), attivo: Canale %d.",
        .alertChannelDriftHint: "Probabile cambio radar DFS — controlla il router o avvia una scansione.",

        .alertLowSNRTitle: "Segnale Wi-Fi debole (SNR %d dB)",
        .alertLowSNRMsg: "Segnale %d dBm / Rumore %d dBm (Velocità: %d Mbps).",
        .alertLowSNRHInt: "Controlla la posizione del router o avvia una scansione canali.",

        .alertIPv6BrokenTitle: "IPv6 non raggiungibile (100% perdita pacchetti)",
        .alertIPv6BrokenMultiMsg: "Un prefisso IPv6 obsoleto è bloccato su %@ (%d prefissi attivi).",
        .alertIPv6BrokenLoopMsg: "IPv4 funziona, ma i pacchetti IPv6 vengono persi (loop di routing).",
        .alertIPv6BrokenHint: "Clicca “Riconnetti Wi-Fi” per azzerare subito il vecchio prefisso IPv6.",

        .alertIPv6StaleTitle: "Rilevati più prefissi IPv6 attivi",
        .alertIPv6StaleMsg: "Su %@ sono presenti %d prefissi IPv6 globali attivi.",
        .alertIPv6StaleHint: "In caso di rallentamenti clicca “Riconnetti Wi-Fi”.",

        .alertWiFiJitterTitle: "Jitter Wi-Fi su Hop 1 verso il router",
        .alertWiFiJitterMsg: "Gateway (%@): media %@ ms, max %@ ms, perdita %.0f%%.",
        .alertWiFiJitterHint: "Problema locale del Wi-Fi — avvia una scansione canali o verifica il segnale.",

        .alertISPIssueTitle: "Linea ISP anomala (Wi-Fi OK)",
        .alertISPIssueMsg: "Router pulito (%@ ms), ma 1.1.1.1 a media %@ ms (%.0f%% perdita).",
        .alertISPIssueHint: "Non è un problema Wi-Fi — verifica lo stato DSL/fibra nel router.",

        .alertSlowDNSTitle: "Risoluzione DNS lenta (%d ms)",
        .alertSlowDNSMsg: "Resolver attivo (%@): %d ms contro %@ (%d ms).",
        .alertSlowDNSHint: "Controlla Pi-hole / Tailscale DNS o prova un reset Wi-Fi.",

        .alertBetterChannelTitle: "Canale 5 GHz più libero disponibile (Canale %d)",
        .alertBetterChannelMsg: "Il canale %d ha %d AP sovrapposti; il canale %d solo %d.",
        .alertBetterChannelHint: "Imposta il router sul Canale %d.",

        .headlineOK: "Tutto funziona alla grande",
        .headlineWarningFallback: "Lieve anomalia di rete",
        .headlineCriticalFallback: "Problema di rete rilevato",
        .bottleneckOK: "%@ K%d · SNR %d dB · Linea stabile",
        .bottleneckDetailsFallback: "Controlla i dettagli",
        .bottleneckCheckNowFallback: "Verifica subito",

        .actionReconnectWiFi: "Riconnetti Wi-Fi",
        .actionRunRFScan: "Scansione canali",
        .actionOpenRouter: "Apri router",

        .cardRadioLink: "Collegamento Wi-Fi (%@)",
        .metricBandChannel: "Banda / Canale",
        .metricSignalSNR: "Segnale / SNR",
        .metricLinkRate: "Velocità link",
        .noActiveWiFi: "Nessuna rete Wi-Fi connessa.",
        .ipv6NoGlobalPrefix: "IPv6: nessun prefisso globale",
        .ipv6CleanPrefix: "IPv6 pulito (%@)",
        .ipv6MultiplePrefixes: "IPv6: %d prefissi attivi (reset consigliato!)",

        .cardLatencyDNS: "Latenza (Idle) & DNS",
        .badgeWiFiIssue: "Problema Wi-Fi",
        .badgeISPIssue: "Problema ISP",
        .badgeIPv6Down: "IPv6 bloccato",
        .badgeAllOK: "Wi-Fi e ISP OK",
        .metricRouterHop1: "Router (Hop 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100% Persi",
        .dnsActiveLabel: "DNS attivo (%@):",

        .cardThroughputBufferbloat: "Velocità & Bufferbloat",
        .metricDownlink: "Download",
        .metricUplink: "Upload",
        .metricLoadedRPM: "Carico / RPM",
        .throughputSummary: "Idle: %.1f ms · Valutazione: %@ · ECN: %@",

        .cardRFEnvironment: "Ambiente RF (%d reti)",
        .best5GHzChannel: "Miglior canale 5 GHz: **Canale %d** (%d interferenze · %@)",
        .best2GHzChannel: "Miglior canale 2,4 GHz: **Canale %d** (%d interferenze · 20 MHz)",
        .channelNoteWeatherDFS: "DFS radar meteo (attesa fino a 10 min)",
        .channelNoteHighPowerDFS: "DFS (1 min), fino a 1000 mW ETSI",
        .channelNoteDFS200: "DFS (1 min), max 200 mW",
        .channelNoteNoDFS: "Senza DFS, max 200 mW",
        .channelNote20MHz: "20 MHz consigliati",

        .sparklineHop1Ping: "Ping Hop 1",
        .sparklineHistoryA11y: "Cronologia %@",

        .btnQuickCheck: "Check rapido",
        .btnFullBenchmark: "Benchmark completo",
        .btnChannelScan: "Scansione",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "Mostra file CSV nel Finder",
        .btnRouter: "Router",
        .btnWiFiSettings: "Impostazioni Wi-Fi…",
        .btnQuit: "Esci",

        .progChecking: "Controllo Wi-Fi, latenza e DNS…",
        .progScanningNeighbors: "Scansione reti vicine…",
        .progBenchStep1: "1/4: Link Wi-Fi e scansione RF…",
        .progBenchStep2: "2/4: Latenza idle (Gateway, IPv4, IPv6)…",
        .progBenchStep3: "3/4: Benchmark DNS…",
        .progBenchStep4: "4/4: Velocità e bufferbloat (networkQuality)…",
        .progReconnecting: "Riavvio Wi-Fi (3 sec)…",
        .progTurningOn: "Attivazione Wi-Fi…",
        .progTurningOff: "Disattivazione Wi-Fi…",
        .progConnectingTo: "Connessione a %@…",

        .settingsSectionMonitoring: "Monitoraggio",
        .settingsLanguage: "Lingua",
        .settingsInterval: "Intervallo controlli",
        .settingsEveryMinutes: "Ogni %d min",
        .settingsPreferredChannel: "Canale 5 GHz preferito",
        .settingsChannelAny: "Qualsiasi",
        .settingsChannelN: "Canale %d",
        .settingsWarn2GHz: "Avvisa su passaggio a 2,4 GHz",
        .settingsNotifications: "Notifiche macOS",
        .settingsShowMenuBarMetrics: "Mostra metriche nella barra menu",
        .settingsSectionThresholds: "Soglie & Router",
        .settingsSNRThreshold: "Avviso SNR sotto: %d dB",
        .settingsGatewayThreshold: "Avviso ping gateway: %d ms",
        .settingsDNSThreshold: "Avviso DNS sopra: %d ms",
        .settingsRouterURL: "Indirizzo router",
        .settingsSectionSystem: "Sistema",
        .settingsLaunchAtLogin: "Avvia al login",
        .settingsRequestLocation: "Richiedi accesso posizione per SSID",
        .settingsDefaults: "Predefiniti",
        .settingsDone: "Fine"
    ]

    // MARK: - French (FR)
    private static let fr: [L10nKey: String] = [
        .bandUnknown: "Inconnu",
        .ratingHigh: "Élevée",
        .ratingMedium: "Moyenne",
        .ratingLow: "Faible",
        .onLabel: "Activé",
        .offLabel: "Désactivé",
        .offline: "Hors ligne",

        .wifiTitle: "Wi-Fi",
        .wifiOff: "Désactivé",
        .startingFirstCheck: "Premier contrôle en cours…",
        .waitingForMetrics: "En attente de mesures",
        .statusUpdatedAt: "Mis à jour : %@ · Toutes les %d min",
        .statusEveryMin: "Toutes les %d min",
        .menuBarAccessibility: "Moniteur Wi-Fi AirPhare",
        .toggleWiFiAccessibility: "Activer ou désactiver le Wi-Fi",
        .openSettingsAccessibility: "Ouvrir les réglages",
        .closeSettingsAccessibility: "Fermer les réglages",

        .knownNetworks: "Réseaux connus",
        .noSavedNetworks: "Aucun réseau enregistré trouvé.",
        .locationHintKnown: "Autorisez la localisation pour filtrer par portée et voir le SSID actif.",
        .allowButton: "Autoriser",
        .otherNetworks: "Autres réseaux",
        .scanningNearby: "Recherche des réseaux à proximité…",
        .locationHintNearby: "macOS masque les noms Wi-Fi sans autorisation de localisation.",
        .allowLocationButton: "Autoriser la localisation",
        .noOtherNetworks: "Aucun autre réseau trouvé.",
        .rescanButton: "Rescanner",
        .wifiPasswordPlaceholder: "Mot de passe Wi-Fi",
        .connectButton: "Connecter",
        .connectedA11y: "%@, connecté",
        .connectToA11y: "Se connecter à %@",
        .networkNotFound: "Le réseau « %@ » est hors de portée.",
        .networkJoinFailed: "Échec de connexion à « %@ » (vérifiez le mot de passe).",
        .networkJoinGenericFailed: "Impossible de se connecter à « %@ ».",

        .alertTipPrefix: "Conseil : %@",
        .alertDisconnectedTitle: "Wi-Fi déconnecté",
        .alertDisconnectedMsg: "Votre Mac n'a actuellement aucune connexion Wi-Fi active.",
        .alertDisconnectedHint: "Activez le Wi-Fi ou reconnectez-vous.",
        .headlineDisconnected: "Wi-Fi déconnecté",
        .bottleneckDisconnected: "Aucune connexion Wi-Fi active",

        .alertWrongBandTitle: "Basculé sur la bande lente 2,4 GHz",
        .alertWrongBandMsg: "Actuellement sur 2,4 GHz (Canal %d, %d Mbit/s).",
        .alertWrongBandHint: "Revenez sur votre réseau 5 GHz ou reconnectez le Wi-Fi.",

        .alertChannelDriftTitle: "Le routeur a changé de canal 5 GHz",
        .alertChannelDriftMsg: "Attendu : Canal %d (80 MHz), actif : Canal %d.",
        .alertChannelDriftHint: "Probable bascule radar DFS — vérifiez le routeur ou lancez un scan.",

        .alertLowSNRTitle: "Signal Wi-Fi faible (SNR %d dB)",
        .alertLowSNRMsg: "Signal %d dBm / Bruit %d dBm (Débit : %d Mbit/s).",
        .alertLowSNRHInt: "Vérifiez l'emplacement du routeur ou lancez un scan de canaux.",

        .alertIPv6BrokenTitle: "IPv6 inaccessible (100 % de perte)",
        .alertIPv6BrokenMultiMsg: "Un ancien préfixe IPv6 reste bloqué sur %@ (%d préfixes actifs).",
        .alertIPv6BrokenLoopMsg: "IPv4 fonctionne, mais les paquets IPv6 sont perdus (boucle de routage).",
        .alertIPv6BrokenHint: "Cliquez sur « Reconnecter Wi-Fi » pour purger l'ancien préfixe IPv6.",

        .alertIPv6StaleTitle: "Plusieurs préfixes IPv6 actifs détectés",
        .alertIPv6StaleMsg: "%@ possède actuellement %d préfixes IPv6 globaux actifs.",
        .alertIPv6StaleHint: "En cas de lenteurs, cliquez sur « Reconnecter Wi-Fi ».",

        .alertWiFiJitterTitle: "Gigue Wi-Fi sur le saut 1 vers le routeur",
        .alertWiFiJitterMsg: "Passerelle (%@) : moy. %@ ms, max %@ ms, perte %.0f %%.",
        .alertWiFiJitterHint: "Problème local Wi-Fi — lancez un scan de canaux ou vérifiez le signal.",

        .alertISPIssueTitle: "Ligne FAI perturbée (Wi-Fi OK)",
        .alertISPIssueMsg: "Routeur stable (%@ ms), mais 1.1.1.1 à moy. %@ ms (%.0f %% perte).",
        .alertISPIssueHint: "Pas un souci Wi-Fi — vérifiez l'état DSL/fibre sur votre routeur.",

        .alertSlowDNSTitle: "Résolution DNS lente (%d ms)",
        .alertSlowDNSMsg: "Résolveur actif (%@) : %d ms contre %@ (%d ms).",
        .alertSlowDNSHint: "Vérifiez Pi-hole / Tailscale DNS ou tentez un reset Wi-Fi.",

        .alertBetterChannelTitle: "Canal 5 GHz plus libre disponible (Canal %d)",
        .alertBetterChannelMsg: "Le canal %d a %d AP en chevauchement ; le canal %d seulement %d.",
        .alertBetterChannelHint: "Passez votre routeur sur le Canal %d.",

        .headlineOK: "Tout est au vert",
        .headlineWarningFallback: "Légère anomalie réseau",
        .headlineCriticalFallback: "Problème réseau détecté",
        .bottleneckOK: "%@ C%d · SNR %d dB · Ligne saine",
        .bottleneckDetailsFallback: "Voir les détails",
        .bottleneckCheckNowFallback: "Vérifier immédiatement",

        .actionReconnectWiFi: "Reconnecter Wi-Fi",
        .actionRunRFScan: "Scanner les canaux",
        .actionOpenRouter: "Ouvrir le routeur",

        .cardRadioLink: "Lien Wi-Fi (%@)",
        .metricBandChannel: "Bande / Canal",
        .metricSignalSNR: "Signal / SNR",
        .metricLinkRate: "Débit lien",
        .noActiveWiFi: "Aucun réseau Wi-Fi connecté.",
        .ipv6NoGlobalPrefix: "IPv6 : aucun préfixe global",
        .ipv6CleanPrefix: "IPv6 sain (%@)",
        .ipv6MultiplePrefixes: "IPv6 : %d préfixes actifs (reset conseillé !)",

        .cardLatencyDNS: "Latence (Idle) & DNS",
        .badgeWiFiIssue: "Souci Wi-Fi",
        .badgeISPIssue: "Souci FAI",
        .badgeIPv6Down: "IPv6 bloqué",
        .badgeAllOK: "Wi-Fi & FAI OK",
        .metricRouterHop1: "Routeur (Saut 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100 % Perte",
        .dnsActiveLabel: "DNS actif (%@) :",

        .cardThroughputBufferbloat: "Débit & Bufferbloat",
        .metricDownlink: "Descendant",
        .metricUplink: "Montant",
        .metricLoadedRPM: "Charge / RPM",
        .throughputSummary: "Repos : %.1f ms · Note : %@ · ECN : %@",

        .cardRFEnvironment: "Environnement RF (%d réseaux)",
        .best5GHzChannel: "Meilleur canal 5 GHz : **Canal %d** (%d interférences · %@)",
        .best2GHzChannel: "Meilleur canal 2,4 GHz : **Canal %d** (%d interférences · 20 MHz)",
        .channelNoteWeatherDFS: "DFS radar météo (jusqu'à 10 min d'attente)",
        .channelNoteHighPowerDFS: "DFS (1 min), jusqu'à 1000 mW ETSI",
        .channelNoteDFS200: "DFS (1 min), max 200 mW",
        .channelNoteNoDFS: "Sans DFS, max 200 mW",
        .channelNote20MHz: "20 MHz recommandés",

        .sparklineHop1Ping: "Ping Saut 1",
        .sparklineHistoryA11y: "Historique %@",

        .btnQuickCheck: "Check rapide",
        .btnFullBenchmark: "Benchmark complet",
        .btnChannelScan: "Scan canaux",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "Afficher le fichier CSV dans le Finder",
        .btnRouter: "Routeur",
        .btnWiFiSettings: "Réglages Wi-Fi…",
        .btnQuit: "Quitter",

        .progChecking: "Vérification Wi-Fi, latence & DNS…",
        .progScanningNeighbors: "Scan des réseaux voisins…",
        .progBenchStep1: "1/4 : Lien Wi-Fi & scan RF…",
        .progBenchStep2: "2/4 : Latence au repos (Passerelle, IPv4, IPv6)…",
        .progBenchStep3: "3/4 : Benchmark DNS…",
        .progBenchStep4: "4/4 : Débit & bufferbloat (networkQuality)…",
        .progReconnecting: "Redémarrage Wi-Fi (3 s)…",
        .progTurningOn: "Activation du Wi-Fi…",
        .progTurningOff: "Désactivation du Wi-Fi…",
        .progConnectingTo: "Connexion à %@…",

        .settingsSectionMonitoring: "Surveillance",
        .settingsLanguage: "Langue",
        .settingsInterval: "Intervalle de contrôle",
        .settingsEveryMinutes: "Toutes les %d min",
        .settingsPreferredChannel: "Canal 5 GHz préféré",
        .settingsChannelAny: "Indifférent",
        .settingsChannelN: "Canal %d",
        .settingsWarn2GHz: "Alerter en cas de bascule 2,4 GHz",
        .settingsNotifications: "Notifications macOS",
        .settingsShowMenuBarMetrics: "Afficher les valeurs dans la barre",
        .settingsSectionThresholds: "Seuils & Routeur",
        .settingsSNRThreshold: "Alerte SNR sous : %d dB",
        .settingsGatewayThreshold: "Alerte ping passerelle : %d ms",
        .settingsDNSThreshold: "Alerte DNS au-dessus de : %d ms",
        .settingsRouterURL: "Adresse du routeur",
        .settingsSectionSystem: "Système",
        .settingsLaunchAtLogin: "Lancer à l'ouverture de session",
        .settingsRequestLocation: "Demander la localisation pour les SSID",
        .settingsDefaults: "Par défaut",
        .settingsDone: "Terminé"
    ]

    // MARK: - Spanish (ES)
    private static let es: [L10nKey: String] = [
        .bandUnknown: "Desconocido",
        .ratingHigh: "Alta",
        .ratingMedium: "Media",
        .ratingLow: "Baja",
        .onLabel: "Activado",
        .offLabel: "Desactivado",
        .offline: "Sin conexión",

        .wifiTitle: "Wi-Fi",
        .wifiOff: "Desactivado",
        .startingFirstCheck: "Iniciando primera comprobación…",
        .waitingForMetrics: "Esperando mediciones",
        .statusUpdatedAt: "Actualizado: %@ · Cada %d min",
        .statusEveryMin: "Cada %d min",
        .menuBarAccessibility: "Monitor Wi-Fi AirPhare",
        .toggleWiFiAccessibility: "Activar o desactivar Wi-Fi",
        .openSettingsAccessibility: "Abrir ajustes",
        .closeSettingsAccessibility: "Cerrar ajustes",

        .knownNetworks: "Redes conocidas",
        .noSavedNetworks: "No se encontraron redes guardadas.",
        .locationHintKnown: "Permite Localización para filtrar por alcance y ver la red activa.",
        .allowButton: "Permitir",
        .otherNetworks: "Otras redes",
        .scanningNearby: "Buscando redes cercanas…",
        .locationHintNearby: "macOS oculta los nombres Wi-Fi sin permiso de localización.",
        .allowLocationButton: "Permitir localización",
        .noOtherNetworks: "No se encontraron otras redes.",
        .rescanButton: "Reescanear",
        .wifiPasswordPlaceholder: "Contraseña Wi-Fi",
        .connectButton: "Conectar",
        .connectedA11y: "%@, conectado",
        .connectToA11y: "Conectar a %@",
        .networkNotFound: "La red “%@” no está al alcance.",
        .networkJoinFailed: "Error al conectar a “%@” (revisa la contraseña).",
        .networkJoinGenericFailed: "No se pudo conectar a “%@”.",

        .alertTipPrefix: "Consejo: %@",
        .alertDisconnectedTitle: "Wi-Fi no conectado",
        .alertDisconnectedMsg: "Tu Mac no tiene una conexión Wi-Fi activa en este momento.",
        .alertDisconnectedHint: "Activa el Wi-Fi o vuelve a conectarte.",
        .headlineDisconnected: "Wi-Fi desconectado",
        .bottleneckDisconnected: "Sin conexión Wi-Fi activa",

        .alertWrongBandTitle: "Conectado a la banda lenta de 2,4 GHz",
        .alertWrongBandMsg: "Conectado en 2,4 GHz (Canal %d, %d Mbps).",
        .alertWrongBandHint: "Vuelve a tu red de 5 GHz o reconecta el Wi-Fi.",

        .alertChannelDriftTitle: "El router cambió el canal de 5 GHz",
        .alertChannelDriftMsg: "Esperado: Canal %d (80 MHz), activo: Canal %d.",
        .alertChannelDriftHint: "Probable salto por radar DFS — revisa el router o escanea canales.",

        .alertLowSNRTitle: "Señal Wi-Fi débil (SNR %d dB)",
        .alertLowSNRMsg: "Señal %d dBm / Ruido %d dBm (Tasa: %d Mbps).",
        .alertLowSNRHInt: "Revisa la ubicación del router o escanea canales menos saturados.",

        .alertIPv6BrokenTitle: "IPv6 inaccesible (100% pérdida de paquetes)",
        .alertIPv6BrokenMultiMsg: "Un prefijo IPv6 antiguo sigue en %@ (%d prefijos activos).",
        .alertIPv6BrokenLoopMsg: "IPv4 funciona, pero los paquetes IPv6 se pierden (bucle de enrutamiento).",
        .alertIPv6BrokenHint: "Pulsa “Reconectar Wi-Fi” para limpiar el prefijo IPv6 al instante.",

        .alertIPv6StaleTitle: "Varios prefijos IPv6 activos detectados",
        .alertIPv6StaleMsg: "%@ tiene %d prefijos IPv6 globales activos.",
        .alertIPv6StaleHint: "Si notas cortes, pulsa “Reconectar Wi-Fi”.",

        .alertWiFiJitterTitle: "Jitter Wi-Fi en el salto 1 al router",
        .alertWiFiJitterMsg: "Puerta de enlace (%@): media %@ ms, máx %@ ms, pérdida %.0f%%.",
        .alertWiFiJitterHint: "Problema local del Wi-Fi — escanea canales o comprueba la señal.",

        .alertISPIssueTitle: "Línea del ISP inestable (Wi-Fi OK)",
        .alertISPIssueMsg: "Router estable (%@ ms), pero 1.1.1.1 en media %@ ms (%.0f%% pérdida).",
        .alertISPIssueHint: "No es problema del Wi-Fi — revisa DSL/fibra en tu router.",

        .alertSlowDNSTitle: "Resolución DNS lenta (%d ms)",
        .alertSlowDNSMsg: "Resolver activo (%@): %d ms frente a %@ (%d ms).",
        .alertSlowDNSHint: "Revisa Pi-hole / Tailscale DNS o prueba un reset de Wi-Fi.",

        .alertBetterChannelTitle: "Canal 5 GHz más limpio disponible (Canal %d)",
        .alertBetterChannelMsg: "El canal %d tiene %d AP superpuestos; el canal %d solo %d.",
        .alertBetterChannelHint: "Cambia tu router al Canal %d.",

        .headlineOK: "Todo funciona perfecto",
        .headlineWarningFallback: "Aviso leve de red",
        .headlineCriticalFallback: "Problema de red detectado",
        .bottleneckOK: "%@ C%d · SNR %d dB · Línea estable",
        .bottleneckDetailsFallback: "Ver detalles",
        .bottleneckCheckNowFallback: "Comprobar ahora",

        .actionReconnectWiFi: "Reconectar Wi-Fi",
        .actionRunRFScan: "Escanear canales",
        .actionOpenRouter: "Abrir router",

        .cardRadioLink: "Enlace Wi-Fi (%@)",
        .metricBandChannel: "Banda / Canal",
        .metricSignalSNR: "Señal / SNR",
        .metricLinkRate: "Tasa enlace",
        .noActiveWiFi: "No hay ninguna red Wi-Fi conectada.",
        .ipv6NoGlobalPrefix: "IPv6: sin prefijo global",
        .ipv6CleanPrefix: "IPv6 limpio (%@)",
        .ipv6MultiplePrefixes: "IPv6: %d prefijos activos (¡reset recomendado!)",

        .cardLatencyDNS: "Latencia (Reposo) y DNS",
        .badgeWiFiIssue: "Problema Wi-Fi",
        .badgeISPIssue: "Problema ISP",
        .badgeIPv6Down: "IPv6 caído",
        .badgeAllOK: "Wi-Fi e ISP OK",
        .metricRouterHop1: "Router (Salto 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100% Pérd.",
        .dnsActiveLabel: "DNS activo (%@):",

        .cardThroughputBufferbloat: "Velocidad y Bufferbloat",
        .metricDownlink: "Bajada",
        .metricUplink: "Subida",
        .metricLoadedRPM: "Carga / RPM",
        .throughputSummary: "Reposo: %.1f ms · Nota: %@ · ECN: %@",

        .cardRFEnvironment: "Entorno RF (%d redes)",
        .best5GHzChannel: "Mejor canal 5 GHz: **Canal %d** (%d interferencias · %@)",
        .best2GHzChannel: "Mejor canal 2,4 GHz: **Canal %d** (%d interferencias · 20 MHz)",
        .channelNoteWeatherDFS: "DFS radar meteorológico (hasta 10 min)",
        .channelNoteHighPowerDFS: "DFS (1 min), hasta 1000 mW ETSI",
        .channelNoteDFS200: "DFS (1 min), máx. 200 mW",
        .channelNoteNoDFS: "Sin DFS, máx. 200 mW",
        .channelNote20MHz: "20 MHz recomendados",

        .sparklineHop1Ping: "Ping Salto 1",
        .sparklineHistoryA11y: "Historial de %@",

        .btnQuickCheck: "Check rápido",
        .btnFullBenchmark: "Benchmark completo",
        .btnChannelScan: "Canales",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "Mostrar registro CSV en Finder",
        .btnRouter: "Router",
        .btnWiFiSettings: "Ajustes de Wi-Fi…",
        .btnQuit: "Salir",

        .progChecking: "Comprobando Wi-Fi, latencia y DNS…",
        .progScanningNeighbors: "Escaneando redes cercanas…",
        .progBenchStep1: "1/4: Enlace Wi-Fi y escaneo RF…",
        .progBenchStep2: "2/4: Latencia en reposo (Router, IPv4, IPv6)…",
        .progBenchStep3: "3/4: Benchmark DNS…",
        .progBenchStep4: "4/4: Velocidad y bufferbloat (networkQuality)…",
        .progReconnecting: "Reiniciando Wi-Fi (3 s)…",
        .progTurningOn: "Activando Wi-Fi…",
        .progTurningOff: "Desactivando Wi-Fi…",
        .progConnectingTo: "Conectando a %@…",

        .settingsSectionMonitoring: "Supervisión",
        .settingsLanguage: "Idioma",
        .settingsInterval: "Intervalo de control",
        .settingsEveryMinutes: "Cada %d min",
        .settingsPreferredChannel: "Canal 5 GHz preferido",
        .settingsChannelAny: "Cualquiera",
        .settingsChannelN: "Canal %d",
        .settingsWarn2GHz: "Avisar si baja a 2,4 GHz",
        .settingsNotifications: "Notificaciones de macOS",
        .settingsShowMenuBarMetrics: "Mostrar métricas en la barra",
        .settingsSectionThresholds: "Umbrales y Router",
        .settingsSNRThreshold: "Aviso SNR menor de: %d dB",
        .settingsGatewayThreshold: "Aviso ping router: %d ms",
        .settingsDNSThreshold: "Aviso DNS mayor de: %d ms",
        .settingsRouterURL: "Dirección del router",
        .settingsSectionSystem: "Sistema",
        .settingsLaunchAtLogin: "Abrir al iniciar sesión",
        .settingsRequestLocation: "Solicitar localización para SSID",
        .settingsDefaults: "Restablecer",
        .settingsDone: "Listo"
    ]

    // MARK: - Dutch (NL)
    private static let nl: [L10nKey: String] = [
        .bandUnknown: "Onbekend",
        .ratingHigh: "Hoog",
        .ratingMedium: "Gemiddeld",
        .ratingLow: "Laag",
        .onLabel: "Aan",
        .offLabel: "Uit",
        .offline: "Offline",

        .wifiTitle: "Wi-Fi",
        .wifiOff: "Uitgeschakeld",
        .startingFirstCheck: "Eerste controle starten…",
        .waitingForMetrics: "Wachten op metingen",
        .statusUpdatedAt: "Bijgewerkt: %@ · Elke %d min",
        .statusEveryMin: "Elke %d min",
        .menuBarAccessibility: "AirPhare Wi-Fi Monitor",
        .toggleWiFiAccessibility: "Wi-Fi aan- of uitzetten",
        .openSettingsAccessibility: "Instellingen openen",
        .closeSettingsAccessibility: "Instellingen sluiten",

        .knownNetworks: "Bekende netwerken",
        .noSavedNetworks: "Geen opgeslagen netwerken gevonden.",
        .locationHintKnown: "Sta Locatievoorzieningen toe om op bereik te filteren en actieve SSID te tonen.",
        .allowButton: "Toestaan",
        .otherNetworks: "Andere netwerken",
        .scanningNearby: "Netwerken in de buurt scannen…",
        .locationHintNearby: "macOS verbergt Wi-Fi-namen zonder locatietoestemming.",
        .allowLocationButton: "Locatietoegang toestaan",
        .noOtherNetworks: "Geen andere netwerken gevonden.",
        .rescanButton: "Opnieuw scannen",
        .wifiPasswordPlaceholder: "Wi-Fi-wachtwoord",
        .connectButton: "Verbinden",
        .connectedA11y: "%@, verbonden",
        .connectToA11y: "Verbinden met %@",
        .networkNotFound: "Netwerk “%@” is buiten bereik.",
        .networkJoinFailed: "Verbinden met “%@” mislukt (controleer wachtwoord).",
        .networkJoinGenericFailed: "Kon niet verbinden met “%@”.",

        .alertTipPrefix: "Tip: %@",
        .alertDisconnectedTitle: "Geen Wi-Fi verbonden",
        .alertDisconnectedMsg: "Je Mac heeft momenteel geen actieve Wi-Fi-verbinding.",
        .alertDisconnectedHint: "Schakel Wi-Fi in of maak opnieuw verbinding.",
        .headlineDisconnected: "Wi-Fi verbroken",
        .bottleneckDisconnected: "Geen actieve Wi-Fi-verbinding",

        .alertWrongBandTitle: "Teruggevallen op trage 2,4 GHz-band",
        .alertWrongBandMsg: "Momenteel op 2,4 GHz (Kanaal %d, %d Mbps).",
        .alertWrongBandHint: "Schakel terug naar je 5 GHz-netwerk of herverbind Wi-Fi.",

        .alertChannelDriftTitle: "Router heeft 5 GHz-kanaal gewijzigd",
        .alertChannelDriftMsg: "Verwacht: Kanaal %d (80 MHz), actief: Kanaal %d.",
        .alertChannelDriftHint: "Waarschijnlijk DFS-radarsprong — check router of start kanaalscan.",

        .alertLowSNRTitle: "Zwak Wi-Fi-signaal (SNR %d dB)",
        .alertLowSNRMsg: "Signaal %d dBm / Ruis %d dBm (Snelheid: %d Mbps).",
        .alertLowSNRHInt: "Controleer routerpositie of start een kanaalscan voor minder storing.",

        .alertIPv6BrokenTitle: "IPv6 onbereikbaar (100% pakketverlies)",
        .alertIPv6BrokenMultiMsg: "Een oud IPv6-prefix blijft hangen op %@ (%d actieve prefixes).",
        .alertIPv6BrokenLoopMsg: "IPv4 werkt, maar IPv6-pakketten gaan verloren (routing-loop).",
        .alertIPv6BrokenHint: "Klik op “Wi-Fi opnieuw verbinden” om het oude IPv6-prefix te wissen.",

        .alertIPv6StaleTitle: "Meerdere actieve IPv6-prefixes gedetecteerd",
        .alertIPv6StaleMsg: "%@ heeft momenteel %d actieve globale IPv6-prefixes.",
        .alertIPv6StaleHint: "Klik bij haperingen op “Wi-Fi opnieuw verbinden”.",

        .alertWiFiJitterTitle: "Wi-Fi-jitter op Hop 1 naar router",
        .alertWiFiJitterMsg: "Gateway (%@): gem. %@ ms, max %@ ms, verlies %.0f%%.",
        .alertWiFiJitterHint: "Lokaal Wi-Fi-probleem — start een kanaalscan of check het signaal.",

        .alertISPIssueTitle: "ISP-verbinding verstoord (Wi-Fi OK)",
        .alertISPIssueMsg: "Router stabiel (%@ ms), maar 1.1.1.1 gem. %@ ms (%.0f%% verlies).",
        .alertISPIssueHint: "Geen Wi-Fi-fout — controleer DSL/glasvezelstatus in je router.",

        .alertSlowDNSTitle: "DNS-omzetting is traag (%d ms)",
        .alertSlowDNSMsg: "Actieve resolver (%@) duurt %d ms vs. %@ (%d ms).",
        .alertSlowDNSHint: "Controleer Pi-hole / Tailscale DNS of probeer een Wi-Fi-reset.",

        .alertBetterChannelTitle: "Schoner 5 GHz-kanaal beschikbaar (Kanaal %d)",
        .alertBetterChannelMsg: "Huidig kanaal %d heeft %d overlappende AP's; kanaal %d slechts %d.",
        .alertBetterChannelHint: "Zet je router op Kanaal %d.",

        .headlineOK: "Alles in topconditie",
        .headlineWarningFallback: "Lichte netwerkmelding",
        .headlineCriticalFallback: "Netwerkstoring gedetecteerd",
        .bottleneckOK: "%@ K%d · SNR %d dB · Verbinding stabiel",
        .bottleneckDetailsFallback: "Details bekijken",
        .bottleneckCheckNowFallback: "Direct controleren",

        .actionReconnectWiFi: "Wi-Fi opnieuw verbinden",
        .actionRunRFScan: "Kanaalscan starten",
        .actionOpenRouter: "Router openen",

        .cardRadioLink: "Wi-Fi-verbinding (%@)",
        .metricBandChannel: "Band / Kanaal",
        .metricSignalSNR: "Signaal / SNR",
        .metricLinkRate: "Linksnelheid",
        .noActiveWiFi: "Niet verbonden met een Wi-Fi-netwerk.",
        .ipv6NoGlobalPrefix: "IPv6: geen globaal prefix",
        .ipv6CleanPrefix: "IPv6 schoon (%@)",
        .ipv6MultiplePrefixes: "IPv6: %d actieve prefixes (reset aanbevolen!)",

        .cardLatencyDNS: "Latentie (Idle) & DNS",
        .badgeWiFiIssue: "Wi-Fi-storing",
        .badgeISPIssue: "ISP-storing",
        .badgeIPv6Down: "IPv6 offline",
        .badgeAllOK: "Wi-Fi & ISP OK",
        .metricRouterHop1: "Router (Hop 1)",
        .metricIPv4: "IPv4 (1.1.1.1)",
        .metricIPv6: "IPv6 (CF)",
        .loss100: "100% Verlies",
        .dnsActiveLabel: "Actieve DNS (%@):",

        .cardThroughputBufferbloat: "Snelheid & Bufferbloat",
        .metricDownlink: "Download",
        .metricUplink: "Upload",
        .metricLoadedRPM: "Belast / RPM",
        .throughputSummary: "Idle: %.1f ms · Score: %@ · ECN: %@",

        .cardRFEnvironment: "RF-omgeving (%d netwerken)",
        .best5GHzChannel: "Beste 5 GHz-kanaal: **Kanaal %d** (%d stoorzenders · %@)",
        .best2GHzChannel: "Beste 2,4 GHz-kanaal: **Kanaal %d** (%d stoorzenders · 20 MHz)",
        .channelNoteWeatherDFS: "Weerradar-DFS (tot 10 min wachttijd)",
        .channelNoteHighPowerDFS: "DFS (1 min), tot 1000 mW ETSI",
        .channelNoteDFS200: "DFS (1 min), max. 200 mW",
        .channelNoteNoDFS: "Geen DFS, max. 200 mW",
        .channelNote20MHz: "20 MHz aanbevolen",

        .sparklineHop1Ping: "Hop-1 Ping",
        .sparklineHistoryA11y: "%@ geschiedenis",

        .btnQuickCheck: "Snelle check",
        .btnFullBenchmark: "Volledige test",
        .btnChannelScan: "Kanaalscan",
        .btnReset: "Reset",
        .btnLog: "Log",
        .btnLogA11y: "CSV-logbestand tonen in Finder",
        .btnRouter: "Router",
        .btnWiFiSettings: "Wi-Fi-instellingen…",
        .btnQuit: "Stoppen",

        .progChecking: "Wi-Fi, latentie & DNS controleren…",
        .progScanningNeighbors: "Netwerken in de buurt scannen…",
        .progBenchStep1: "1/4: Wi-Fi-link & RF-scan…",
        .progBenchStep2: "2/4: Idle-latentie (Gateway, IPv4, IPv6)…",
        .progBenchStep3: "3/4: DNS-benchmark…",
        .progBenchStep4: "4/4: Snelheid & bufferbloat (networkQuality)…",
        .progReconnecting: "Wi-Fi 3 sec uit & weer aan…",
        .progTurningOn: "Wi-Fi inschakelen…",
        .progTurningOff: "Wi-Fi uitschakelen…",
        .progConnectingTo: "Verbinden met %@…",

        .settingsSectionMonitoring: "Bewaking",
        .settingsLanguage: "Taal",
        .settingsInterval: "Controle-interval",
        .settingsEveryMinutes: "Elke %d min",
        .settingsPreferredChannel: "Voorkeurskanaal 5 GHz",
        .settingsChannelAny: "Willekeurig",
        .settingsChannelN: "Kanaal %d",
        .settingsWarn2GHz: "Waarschuwen bij 2,4 GHz-terugval",
        .settingsNotifications: "macOS-meldingen",
        .settingsShowMenuBarMetrics: "Waarden in menubalk tonen",
        .settingsSectionThresholds: "Drempelwaarden & Router",
        .settingsSNRThreshold: "SNR-waarschuwing onder: %d dB",
        .settingsGatewayThreshold: "Gateway-ping waarschuwing: %d ms",
        .settingsDNSThreshold: "DNS-waarschuwing boven: %d ms",
        .settingsRouterURL: "Router-adres",
        .settingsSectionSystem: "Systeem",
        .settingsLaunchAtLogin: "Starten bij inloggen",
        .settingsRequestLocation: "Locatietoegang voor SSID vragen",
        .settingsDefaults: "Standaard",
        .settingsDone: "Klaar"
    ]
}

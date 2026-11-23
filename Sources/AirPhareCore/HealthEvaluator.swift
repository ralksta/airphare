import Foundation

public enum HealthEvaluator {

    public static func evaluate(
        wifi: WiFiSnapshot?,
        latency: LatencySnapshot?,
        dns: DNSSnapshot?,
        rfScan: RFScanResult?,
        settings: MonitorSettings,
        lang: ResolvedLanguage = .en
    ) -> HealthReport {
        var alerts: [HealthAlert] = []

        guard let wifi, wifi.isConnected else {
            alerts.append(HealthAlert(
                category: .disconnected,
                severity: .critical,
                title: L10n.t(.alertDisconnectedTitle, lang: lang),
                message: L10n.t(.alertDisconnectedMsg, lang: lang),
                actionHint: L10n.t(.alertDisconnectedHint, lang: lang),
                quickAction: .reconnectWiFi
            ))
            return HealthReport(
                severity: .critical,
                headline: L10n.t(.headlineDisconnected, lang: lang),
                alerts: alerts,
                bottleneckSummary: L10n.t(.bottleneckDisconnected, lang: lang)
            )
        }

        // 1. Check 2.4 GHz fallback
        if settings.expect5GHz && wifi.band == .band2GHz {
            alerts.append(HealthAlert(
                category: .wrongBand2GHz,
                severity: .warning,
                title: L10n.t(.alertWrongBandTitle, lang: lang),
                message: L10n.fmt(.alertWrongBandMsg, lang: lang, wifi.channel, Int(wifi.txRateMbps)),
                actionHint: L10n.t(.alertWrongBandHint, lang: lang),
                quickAction: .reconnectWiFi
            ))
        }

        // 2. Check DFS channel drift on 5 GHz
        if wifi.band == .band5GHz && settings.preferred5GHzChannel > 0 {
            let expectedRange = ChannelAnalyzer.channelRange5GHz(primary: settings.preferred5GHzChannel, widthMHz: 80)
            if !expectedRange.contains(wifi.channel) {
                alerts.append(HealthAlert(
                    category: .channelDrift,
                    severity: .warning,
                    title: L10n.t(.alertChannelDriftTitle, lang: lang),
                    message: L10n.fmt(.alertChannelDriftMsg, lang: lang, settings.preferred5GHzChannel, wifi.channel),
                    actionHint: L10n.t(.alertChannelDriftHint, lang: lang),
                    quickAction: .openRouterSettings
                ))
            }
        }

        // 3. Check Signal / SNR
        if wifi.snr < settings.snrWarningThreshold || wifi.rssi < -72 {
            let severity: HealthSeverity = wifi.snr < 15 ? .critical : .warning
            alerts.append(HealthAlert(
                category: .lowSNR,
                severity: severity,
                title: L10n.fmt(.alertLowSNRTitle, lang: lang, wifi.snr),
                message: L10n.fmt(.alertLowSNRMsg, lang: lang, wifi.rssi, wifi.noise, Int(wifi.txRateMbps)),
                actionHint: L10n.t(.alertLowSNRHInt, lang: lang),
                quickAction: .runRFScan
            ))
        }

        // 4. Check IPv6 stale prefix / blackhole
        let ipv4Ok = latency?.ipv4Internet?.isReachable ?? false
        let ipv6Broken = (latency?.ipv6Internet != nil) && !(latency?.ipv6Internet?.isReachable ?? true) && ipv4Ok
        let hasMultipleActiveIPv6 = wifi.activeGlobalIPv6Prefixes.count > 1

        if ipv6Broken {
            let msg = hasMultipleActiveIPv6
                ? L10n.fmt(.alertIPv6BrokenMultiMsg, lang: lang, wifi.interfaceName, wifi.activeGlobalIPv6Prefixes.count)
                : L10n.t(.alertIPv6BrokenLoopMsg, lang: lang)
            alerts.append(HealthAlert(
                category: .ipv6Broken,
                severity: .critical,
                title: L10n.t(.alertIPv6BrokenTitle, lang: lang),
                message: msg,
                actionHint: L10n.t(.alertIPv6BrokenHint, lang: lang),
                quickAction: .reconnectWiFi
            ))
        } else if hasMultipleActiveIPv6 {
            alerts.append(HealthAlert(
                category: .ipv6StalePrefix,
                severity: .warning,
                title: L10n.t(.alertIPv6StaleTitle, lang: lang),
                message: L10n.fmt(.alertIPv6StaleMsg, lang: lang, wifi.interfaceName, wifi.activeGlobalIPv6Prefixes.count),
                actionHint: L10n.t(.alertIPv6StaleHint, lang: lang),
                quickAction: .reconnectWiFi
            ))
        }

        // 5. Hop-by-Hop Wi-Fi vs. ISP isolation
        if let gw = latency?.gateway {
            let gwAvg = gw.avgMs ?? 0
            if gw.packetLossPercent > 0 || gwAvg > settings.gatewayAvgWarningMs {
                let severity: HealthSeverity = (gw.packetLossPercent >= 10 || gwAvg > 50) ? .critical : .warning
                alerts.append(HealthAlert(
                    category: .wifiJitter,
                    severity: severity,
                    title: L10n.t(.alertWiFiJitterTitle, lang: lang),
                    message: L10n.fmt(.alertWiFiJitterMsg, lang: lang, gw.host, formatMs(gw.avgMs), formatMs(gw.maxMs), gw.packetLossPercent),
                    actionHint: L10n.t(.alertWiFiJitterHint, lang: lang),
                    quickAction: .runRFScan
                ))
            } else if let inet = latency?.ipv4Internet {
                let inetAvg = inet.avgMs ?? 0
                if inet.packetLossPercent > 0 || (inetAvg - gwAvg) > 35 {
                    alerts.append(HealthAlert(
                        category: .ispIssue,
                        severity: inet.packetLossPercent >= 10 ? .critical : .warning,
                        title: L10n.t(.alertISPIssueTitle, lang: lang),
                        message: L10n.fmt(.alertISPIssueMsg, lang: lang, formatMs(gw.avgMs), formatMs(inet.avgMs), inet.packetLossPercent),
                        actionHint: L10n.t(.alertISPIssueHint, lang: lang),
                        quickAction: .openRouterSettings
                    ))
                }
            }
        }

        // 6. DNS latency check
        if let dns, let activeMs = dns.activeLatencyMs {
            let refMs = dns.referenceLatencyMs ?? 20
            if activeMs > settings.dnsWarningMs && (activeMs - refMs) > 35 {
                let resolverName = dns.activeResolver ?? L10n.t(.bandUnknown, lang: lang)
                alerts.append(HealthAlert(
                    category: .slowDNS,
                    severity: .warning,
                    title: L10n.fmt(.alertSlowDNSTitle, lang: lang, activeMs),
                    message: L10n.fmt(.alertSlowDNSMsg, lang: lang, resolverName, activeMs, dns.referenceServer, refMs),
                    actionHint: L10n.t(.alertSlowDNSHint, lang: lang),
                    quickAction: .reconnectWiFi
                ))
            }
        }

        // 7. Better 5 GHz channel suggestion (only if RF scan was run recently)
        if let rf = rfScan, wifi.band == .band5GHz, let best = rf.recommended5GHz {
            let currentBlock = ChannelAnalyzer.channelRange5GHz(primary: wifi.channel, widthMHz: 80)
            if !currentBlock.contains(best.channel) {
                if let currentScore = rf.scores5GHz.first(where: { currentBlock.contains($0.channel) }),
                   (currentScore.overlappingAPCount - best.overlappingAPCount) >= 2 {
                    alerts.append(HealthAlert(
                        category: .betterChannelAvailable,
                        severity: .warning,
                        title: L10n.fmt(.alertBetterChannelTitle, lang: lang, best.channel),
                        message: L10n.fmt(.alertBetterChannelMsg, lang: lang, wifi.channel, currentScore.overlappingAPCount, best.channel, best.overlappingAPCount),
                        actionHint: L10n.fmt(.alertBetterChannelHint, lang: lang, best.channel),
                        quickAction: .openRouterSettings
                    ))
                }
            }
        }

        let sortedAlerts = alerts.sorted { $0.severity > $1.severity }
        let overall = sortedAlerts.first?.severity ?? .ok

        let headline: String
        let bottleneck: String
        switch overall {
        case .ok:
            headline = L10n.t(.headlineOK, lang: lang)
            bottleneck = L10n.fmt(.bottleneckOK, lang: lang, wifi.band.shortLabel, wifi.channel, wifi.snr)
        case .warning:
            headline = sortedAlerts.first?.title ?? L10n.t(.headlineWarningFallback, lang: lang)
            bottleneck = sortedAlerts.first?.actionHint ?? L10n.t(.bottleneckDetailsFallback, lang: lang)
        case .critical:
            headline = sortedAlerts.first?.title ?? L10n.t(.headlineCriticalFallback, lang: lang)
            bottleneck = sortedAlerts.first?.actionHint ?? L10n.t(.bottleneckCheckNowFallback, lang: lang)
        }

        return HealthReport(
            severity: overall,
            headline: headline,
            alerts: sortedAlerts,
            bottleneckSummary: bottleneck
        )
    }

    private static func formatMs(_ val: Double?) -> String {
        guard let val else { return "–" }
        return String(format: "%.1f", val)
    }
}

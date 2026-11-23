import Foundation

public enum HTMLReportBuilder {

    public static func build(
        wifi: WiFiSnapshot?,
        latency: LatencySnapshot?,
        dns: DNSSnapshot?,
        rfScan: RFScanResult?,
        networkQuality: NetworkQualityResult?,
        report: HealthReport,
        stats24h: AnalyticsSummary? = nil,
        lang: ResolvedLanguage = .en,
        appVersion: String = "1.1.1",
        logoDataURI: String? = nil,
        timestamp: Date = .now
    ) -> String {
        let copy = ReportCopy(lang: lang)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoTimestamp = iso.string(from: timestamp)

        let displayDate = DateFormatter()
        displayDate.locale = Locale(identifier: copy.localeIdentifier)
        displayDate.dateStyle = .medium
        displayDate.timeStyle = .short
        let formattedTimestamp = displayDate.string(from: timestamp)

        let statusClass: String
        let statusLabel: String
        switch report.severity {
        case .ok:
            statusClass = "is-ok"
            statusLabel = copy.statusOK
        case .warning:
            statusClass = "is-warn"
            statusLabel = copy.statusWarn
        case .critical:
            statusClass = "is-crit"
            statusLabel = copy.statusCrit
        }

        let logoMarkup: String
        if let logoDataURI, !logoDataURI.isEmpty {
            logoMarkup = #"<img class="brand-mark" src="\#(escapeHTML(logoDataURI))" alt="AirPhare" width="44" height="44">"#
        } else {
            logoMarkup = fallbackSVGLogo
        }

        // Build sections & dynamic anchor nav
        var navItems: [(id: String, label: String)] = []
        var sections: [String] = []

        if !report.alerts.isEmpty {
            navItems.append(("alerts", copy.navAlerts))
            sections.append(buildAlertsSection(alerts: report.alerts, copy: copy))
        }

        navItems.append(("wifi", copy.navWiFi))
        sections.append(buildWiFiSection(wifi: wifi, copy: copy))

        if let latency {
            navItems.append(("latency", copy.navLatency))
            sections.append(buildLatencySection(latency: latency, copy: copy))
        }

        if let dns {
            navItems.append(("dns", copy.navDNS))
            sections.append(buildDNSSection(dns: dns, copy: copy))
        }

        if let nq = networkQuality {
            navItems.append(("throughput", copy.navThroughput))
            sections.append(buildNetworkQualitySection(nq: nq, lang: lang, copy: copy))
        }

        if let rf = rfScan {
            navItems.append(("rf", copy.navRFScan))
            sections.append(buildRFScanSection(rf: rf, copy: copy))
        }

        if let s = stats24h, s.totalChecks > 0 {
            navItems.append(("history", copy.navStats24h))
            sections.append(buildStats24hSection(stats: s, copy: copy))
        }

        let navMarkup = navItems.map { item in
            "<a href=\"#\(item.id)\">\(escapeHTML(item.label))</a>"
        }.joined(separator: "\n")

        let instrumentStrip = buildInstrumentStrip(wifi: wifi, latency: latency, stats24h: stats24h, copy: copy)

        return """
        <!DOCTYPE html>
        <html lang="\(lang.rawValue)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>AirPhare — \(escapeHTML(copy.reportTitle))</title>
        <style>
        \(cssStyles)
        </style>
        </head>
        <body>
        <div class="sheet">
          <header class="masthead">
            <div class="brand">
              \(logoMarkup)
              <div class="brand-meta">
                <div class="brand-line">
                  <span class="brand-name">AirPhare</span>
                  <span class="brand-sep">/</span>
                  <span class="brand-doc">\(escapeHTML(copy.reportTitle))</span>
                  <span class="version-tag">v\(escapeHTML(appVersion))</span>
                </div>
                <div class="meta-line">
                  <span>\(escapeHTML(copy.generatedAt)) \(escapeHTML(formattedTimestamp))</span>
                  <span class="meta-dot">·</span>
                  <span>\(escapeHTML(wifi?.ssid ?? copy.noActiveWiFiShort))</span>
                </div>
              </div>
            </div>

            <div class="toolbar no-print">
              <label class="switch-control" for="help-master-toggle" title="\(escapeHTML(copy.toggleHelpTooltip))">
                <input type="checkbox" id="help-master-toggle">
                <span class="switch-track" aria-hidden="true"></span>
                <span class="switch-label">\(escapeHTML(copy.explanationsToggle))</span>
              </label>
              <button type="button" class="action-btn" onclick="window.print()">
                <svg width="14" height="14" viewBox="0 0 16 16" fill="none" aria-hidden="true">
                  <path d="M4 6V2.5h8V6M4 11.5H2.5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h11a1 1 0 0 1 1 1v3.5a1 1 0 0 1-1 1H12M4.5 9.5h7v4h-7v-4Z" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span>\(escapeHTML(copy.printPDF))</span>
              </button>
            </div>
          </header>

          <section class="summary-band" aria-label="Status">
            <div class="status-row \(statusClass)">
              <span class="status-indicator" aria-hidden="true"></span>
              <span class="status-state">\(escapeHTML(statusLabel))</span>
              <span class="status-divider" aria-hidden="true">—</span>
              <span class="status-headline">\(escapeHTML(report.headline))</span>
            </div>
            \(instrumentStrip)
          </section>

          <nav class="section-rail no-print" aria-label="Sections">
            \(navMarkup)
          </nav>

          <main class="report-body">
            \(sections.joined(separator: "\n"))
          </main>

          <footer class="colophon">
            <span>AirPhare v\(escapeHTML(appVersion)) · \(escapeHTML(copy.footerNote))</span>
            <span class="mono">\(escapeHTML(isoTimestamp))</span>
          </footer>
        </div>

        <script>
        (function() {
          const toggle = document.getElementById('help-master-toggle');
          if (!toggle) return;
          const getPanels = () => Array.from(document.querySelectorAll('details.explain'));

          function syncToggle() {
            const panels = getPanels();
            const openCount = panels.filter(p => p.open).length;
            toggle.checked = panels.length > 0 && openCount === panels.length;
            toggle.indeterminate = openCount > 0 && openCount < panels.length;
          }

          toggle.addEventListener('change', function() {
            const open = toggle.checked;
            getPanels().forEach(p => { p.open = open; });
            syncToggle();
          });

          getPanels().forEach(p => p.addEventListener('toggle', syncToggle));
          syncToggle();
        })();
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Instrument Strip (KPI Row)

    private static func buildInstrumentStrip(
        wifi: WiFiSnapshot?,
        latency: LatencySnapshot?,
        stats24h: AnalyticsSummary?,
        copy: ReportCopy
    ) -> String {
        // 1. Signal / SNR with subtle precision bar
        let snrValue: String
        let snrSub: String
        let snrTone: String
        let snrBarHTML: String
        if let wifi, wifi.isConnected {
            snrValue = "\(wifi.snr) dB"
            snrSub = "\(wifi.band.englishLabel) · Ch \(wifi.channel) · \(wifi.channelWidthMHz) MHz"
            if wifi.snr >= 25 { snrTone = "is-ok" }
            else if wifi.snr >= 15 { snrTone = "is-warn" }
            else { snrTone = "is-crit" }
            let pct = max(4, min(100, Int((Double(wifi.snr) / 45.0) * 100.0)))
            snrBarHTML = #"<div class="meter" aria-hidden="true"><div class="meter-fill \#(snrTone)" style="width:\#(pct)%"></div></div>"#
        } else {
            snrValue = copy.offline
            snrSub = copy.noActiveWiFiShort
            snrTone = "is-crit"
            snrBarHTML = ""
        }

        // 2. Gateway Ping
        let gwValue: String
        let gwSub: String
        let gwTone: String
        if let gw = latency?.gateway {
            if !gw.isReachable {
                gwValue = copy.unreachable
                gwSub = "100% \(copy.loss)"
                gwTone = "is-crit"
            } else if let avg = gw.avgMs {
                gwValue = String(format: "%.1f ms", avg)
                gwSub = latency?.gatewayHost ?? copy.targetGateway
                if gw.packetLossPercent > 0 || avg > 15 { gwTone = "is-crit" }
                else if avg > 5 { gwTone = "is-warn" }
                else { gwTone = "is-ok" }
            } else {
                gwValue = "OK"
                gwSub = latency?.gatewayHost ?? copy.targetGateway
                gwTone = "is-ok"
            }
        } else {
            gwValue = "—"
            gwSub = copy.notMeasured
            gwTone = "is-muted"
        }

        // 3. Internet Ping
        let inetValue: String
        let inetSub: String
        let inetTone: String
        if let v4 = latency?.ipv4Internet {
            if !v4.isReachable {
                inetValue = copy.unreachable
                inetSub = "IPv4 1.1.1.1"
                inetTone = "is-crit"
            } else if let avg = v4.avgMs {
                inetValue = String(format: "%.1f ms", avg)
                if let v6 = latency?.ipv6Internet {
                    if v6.isReachable, let v6Avg = v6.avgMs {
                        inetSub = String(format: "IPv6 %.1f ms", v6Avg)
                    } else {
                        inetSub = "IPv6 \(copy.unreachable)"
                    }
                } else {
                    inetSub = "IPv4 1.1.1.1"
                }
                if v4.packetLossPercent > 0 || avg > 60 { inetTone = "is-crit" }
                else if avg > 30 { inetTone = "is-warn" }
                else { inetTone = "is-ok" }
            } else {
                inetValue = "OK"
                inetSub = "IPv4 1.1.1.1"
                inetTone = "is-ok"
            }
        } else {
            inetValue = "—"
            inetSub = copy.notMeasured
            inetTone = "is-muted"
        }

        // 4. 24h Uptime or Link Rate
        let fourthTitle: String
        let fourthValue: String
        let fourthSub: String
        let fourthTone: String
        if let s = stats24h, s.totalChecks > 0 {
            fourthTitle = copy.kpiUptime24h
            fourthValue = String(format: "%.1f%%", s.uptimePercent)
            fourthSub = "\(s.totalChecks) \(copy.checks)"
            if s.uptimePercent >= 99.0 { fourthTone = "is-ok" }
            else if s.uptimePercent >= 95.0 { fourthTone = "is-warn" }
            else { fourthTone = "is-crit" }
        } else if let wifi, wifi.isConnected {
            fourthTitle = copy.kpiLinkRate
            fourthValue = "\(Int(wifi.txRateMbps)) Mbps"
            fourthSub = wifi.phyMode
            if wifi.txRateMbps >= 300 { fourthTone = "is-ok" }
            else if wifi.txRateMbps >= 100 { fourthTone = "is-warn" }
            else { fourthTone = "is-crit" }
        } else {
            fourthTitle = copy.kpiLinkRate
            fourthValue = "—"
            fourthSub = copy.notMeasured
            fourthTone = "is-muted"
        }

        return """
        <div class="instrument-strip">
          \(metricCell(label: copy.kpiSignalSNR, value: snrValue, sub: snrSub, tone: snrTone, extraHTML: snrBarHTML))
          \(metricCell(label: copy.kpiGatewayPing, value: gwValue, sub: gwSub, tone: gwTone))
          \(metricCell(label: copy.kpiInternetPing, value: inetValue, sub: inetSub, tone: inetTone))
          \(metricCell(label: fourthTitle, value: fourthValue, sub: fourthSub, tone: fourthTone))
        </div>
        """
    }

    private static func metricCell(
        label: String,
        value: String,
        sub: String,
        tone: String,
        extraHTML: String = ""
    ) -> String {
        """
        <div class="instrument-cell">
          <div class="inst-label">\(escapeHTML(label))</div>
          <div class="inst-value-row">
            <span class="tone-dot \(tone)" aria-hidden="true"></span>
            <span class="inst-value">\(escapeHTML(value))</span>
          </div>
          \(extraHTML)
          <div class="inst-sub">\(escapeHTML(sub))</div>
        </div>
        """
    }

    // MARK: - Sections

    private static func buildAlertsSection(alerts: [HealthAlert], copy: ReportCopy) -> String {
        let items = alerts.map { alert in
            let cls = alert.severity == .critical ? "is-crit" : "is-warn"
            let badge = alert.severity == .critical ? copy.badgeCritical : copy.badgeWarning
            return """
            <div class="finding \(cls)">
              <div class="finding-head">
                <span class="finding-tag">\(escapeHTML(badge))</span>
                <span class="finding-title">\(escapeHTML(alert.title))</span>
              </div>
              <p class="finding-desc">\(escapeHTML(alert.message))</p>
              <p class="finding-action"><strong>\(escapeHTML(copy.tipLabel)):</strong> \(escapeHTML(alert.actionHint))</p>
            </div>
            """
        }.joined(separator: "\n")

        return """
        <section id="alerts" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secAlerts)) <span class="section-count">\(alerts.count)</span></h2>
          </div>
          <div class="findings-list">
            \(items)
          </div>
        </section>
        """
    }

    private static func buildWiFiSection(wifi: WiFiSnapshot?, copy: ReportCopy) -> String {
        let body: String
        if let wifi, wifi.isConnected {
            var rows: [(String, String)] = [
                (copy.metricInterface, mono(wifi.interfaceName)),
                (copy.metricSSID, escapeHTML(wifi.ssid ?? copy.redacted))
            ]
            if let bssid = wifi.bssid {
                rows.append((copy.metricBSSID, mono(bssid)))
            }
            rows.append((
                copy.metricBandChannel,
                "\(escapeHTML(wifi.band.englishLabel)) · Ch \(mono("\(wifi.channel)")) · \(wifi.channelWidthMHz) MHz"
            ))
            rows.append((copy.metricPHYMode, escapeHTML(wifi.phyMode)))
            rows.append((
                copy.metricSignalNoiseSNR,
                "\(mono("\(wifi.rssi) dBm")) / \(mono("\(wifi.noise) dBm")) &nbsp;·&nbsp; <strong>SNR \(mono("\(wifi.snr) dB"))</strong>"
            ))
            rows.append((copy.metricLinkRate, mono("\(Int(wifi.txRateMbps)) Mbps")))
            if let ip = wifi.ipv4Address {
                rows.append((copy.metricIPv4, mono(ip)))
            }
            let ipv6Text = wifi.activeGlobalIPv6Prefixes.isEmpty
                ? copy.noneLabel
                : wifi.activeGlobalIPv6Prefixes.joined(separator: ", ")
            rows.append((copy.metricIPv6Prefixes, mono(ipv6Text)))
            if let drops = wifi.interfaceDrops {
                let errSummary = "Drops \(mono("\(drops)")) · Ierrs \(mono("\(wifi.interfaceInputErrors ?? 0)")) · Oerrs \(mono("\(wifi.interfaceOutputErrors ?? 0)"))"
                rows.append((copy.metricInterfaceErrors, errSummary))
            }
            body = buildSpecTable(rows: rows)
        } else {
            body = #"<p class="empty-state">\#(escapeHTML(copy.noActiveWiFi))</p>"#
        }

        return """
        <section id="wifi" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secWiFi))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpWiFi))
          </div>
          \(body)
        </section>
        """
    }

    private static func buildLatencySection(latency: LatencySnapshot, copy: ReportCopy) -> String {
        let pathDiagram = buildHopPathDiagram(latency: latency, copy: copy)
        let rows = [
            formatPingRow(label: "\(escapeHTML(copy.targetGateway)) <span class=\"sub-mono\">\(escapeHTML(latency.gatewayHost ?? "—"))</span>", stats: latency.gateway, copy: copy),
            formatPingRow(label: "IPv4 <span class=\"sub-mono\">1.1.1.1</span>", stats: latency.ipv4Internet, copy: copy),
            formatPingRow(label: "IPv6 <span class=\"sub-mono\">2606:4700:4700::1111</span>", stats: latency.ipv6Internet, copy: copy)
        ].joined(separator: "\n")

        return """
        <section id="latency" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secLatency))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpLatency))
          </div>
          \(pathDiagram)
          <div class="table-scroll">
            <table class="data-table">
              <thead>
                <tr>
                  <th>\(escapeHTML(copy.colTarget))</th>
                  <th class="num">\(escapeHTML(copy.colLoss))</th>
                  <th class="num">\(escapeHTML(copy.colMinAvgMax))</th>
                  <th class="num">\(escapeHTML(copy.colJitter))</th>
                </tr>
              </thead>
              <tbody>
                \(rows)
              </tbody>
            </table>
          </div>
        </section>
        """
    }

    private static func buildHopPathDiagram(latency: LatencySnapshot, copy: ReportCopy) -> String {
        let gwText: String
        let gwTone: String
        if let gw = latency.gateway {
            if !gw.isReachable {
                gwText = "100% \(copy.loss)"
                gwTone = "is-crit"
            } else if let avg = gw.avgMs {
                gwText = String(format: "%.1f ms", avg)
                gwTone = (gw.packetLossPercent > 0 || avg > 15) ? "is-crit" : (avg > 5 ? "is-warn" : "is-ok")
            } else {
                gwText = "OK"
                gwTone = "is-ok"
            }
        } else {
            gwText = "—"
            gwTone = "is-muted"
        }

        let inetText: String
        let inetTone: String
        if let v4 = latency.ipv4Internet {
            if !v4.isReachable {
                inetText = "100% \(copy.loss)"
                inetTone = "is-crit"
            } else if let avg = v4.avgMs {
                inetText = String(format: "%.1f ms", avg)
                inetTone = (v4.packetLossPercent > 0 || avg > 60) ? "is-crit" : (avg > 30 ? "is-warn" : "is-ok")
            } else {
                inetText = "OK"
                inetTone = "is-ok"
            }
        } else {
            inetText = "—"
            inetTone = "is-muted"
        }

        return """
        <div class="hop-diagram" aria-label="Network Path">
          <div class="hop-node">
            <span class="hop-title">Mac</span>
            <span class="hop-sub">\(escapeHTML(copy.hopLocal))</span>
          </div>
          <div class="hop-link \(gwTone)">
            <span class="hop-metric">\(escapeHTML(gwText))</span>
            <span class="hop-line"></span>
            <span class="hop-caption">Wi-Fi</span>
          </div>
          <div class="hop-node">
            <span class="hop-title">\(escapeHTML(copy.targetGateway))</span>
            <span class="hop-sub mono">\(escapeHTML(latency.gatewayHost ?? "Router"))</span>
          </div>
          <div class="hop-link \(inetTone)">
            <span class="hop-metric">\(escapeHTML(inetText))</span>
            <span class="hop-line"></span>
            <span class="hop-caption">ISP / Internet</span>
          </div>
          <div class="hop-node">
            <span class="hop-title">Internet</span>
            <span class="hop-sub mono">1.1.1.1</span>
          </div>
        </div>
        """
    }

    private static func formatPingRow(label: String, stats: PingStats?, copy: ReportCopy) -> String {
        guard let stats else {
            return "<tr><td>\(label)</td><td class=\"num muted\">—</td><td class=\"num muted\">\(escapeHTML(copy.notMeasured))</td><td class=\"num muted\">—</td></tr>"
        }
        if !stats.isReachable {
            return "<tr><td>\(label)</td><td class=\"num text-crit\">100%</td><td class=\"num text-crit\">\(escapeHTML(copy.unreachable))</td><td class=\"num muted\">—</td></tr>"
        }
        let lossClass = stats.packetLossPercent > 0 ? "text-crit" : "muted"
        let lossText = String(format: "%.0f%%", stats.packetLossPercent)
        let rangeText: String
        if let min = stats.minMs, let avg = stats.avgMs, let max = stats.maxMs {
            rangeText = String(format: "%.1f / <strong>%.1f</strong> / %.1f ms", min, avg, max)
        } else {
            rangeText = "OK"
        }
        let jitterText = stats.stddevMs.map { String(format: "±%.1f ms", $0) } ?? "—"
        return "<tr><td>\(label)</td><td class=\"num mono \(lossClass)\">\(lossText)</td><td class=\"num mono\">\(rangeText)</td><td class=\"num mono muted\">\(jitterText)</td></tr>"
    }

    private static func buildDNSSection(dns: DNSSnapshot, copy: ReportCopy) -> String {
        var entries: [(resolver: String, role: String, ms: Int?)] = []
        if let active = dns.activeResolver {
            entries.append((active, copy.dnsActiveSystem, dns.activeLatencyMs))
        }
        entries.append((dns.referenceServer, "Cloudflare", dns.referenceLatencyMs))
        if let google = dns.googleLatencyMs {
            entries.append(("8.8.8.8", "Google", google))
        }
        if let gw = dns.routerHost, gw != dns.activeResolver {
            entries.append((gw, "Router", dns.routerLatencyMs))
        }

        let maxMs = max(1, entries.compactMap(\.ms).max() ?? 1)
        let fastestLabel = dns.fastestServer?.label

        let rows = entries.map { entry in
            let isFastest = (fastestLabel == entry.resolver && entry.ms != nil)
            let badge = isFastest ? #" <span class="inline-tag">\#(escapeHTML(copy.fastestBadge))</span>"# : ""
            let timeCell: String
            if let ms = entry.ms {
                let pct = max(6, Int((Double(ms) / Double(maxMs)) * 100.0))
                let barClass = isFastest ? "bar-fill is-accent" : "bar-fill"
                timeCell = """
                <div class="bar-cell">
                  <div class="bar-track" aria-hidden="true"><div class="\(barClass)" style="width:\(pct)%"></div></div>
                  <span class="mono\(isFastest ? " strong" : "")">\(ms) ms</span>
                </div>
                """
            } else {
                timeCell = #"<span class="muted">—</span>"#
            }
            return "<tr><td class=\"mono\">\(escapeHTML(entry.resolver))\(badge)</td><td class=\"muted\">\(escapeHTML(entry.role))</td><td class=\"num\">\(timeCell)</td></tr>"
        }.joined(separator: "\n")

        return """
        <section id="dns" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secDNS))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpDNS))
          </div>
          <div class="table-scroll">
            <table class="data-table">
              <thead>
                <tr>
                  <th>\(escapeHTML(copy.colResolver))</th>
                  <th>\(escapeHTML(copy.colRole))</th>
                  <th class="num">\(escapeHTML(copy.colQueryTime))</th>
                </tr>
              </thead>
              <tbody>
                \(rows)
              </tbody>
            </table>
          </div>
        </section>
        """
    }

    private static func buildNetworkQualitySection(
        nq: NetworkQualityResult,
        lang: ResolvedLanguage,
        copy: ReportCopy
    ) -> String {
        let rating = nq.responsivenessRating(lang: lang)
        let toneClass: String
        switch nq.responsivenessRPM {
        case 1000...: toneClass = "is-ok"
        case 300..<1000: toneClass = "is-warn"
        default: toneClass = "is-crit"
        }

        let rows: [(String, String)] = [
            (copy.metricDownlink, mono(String(format: "%.1f Mbps", nq.downlinkMbps))),
            (copy.metricUplink, mono(String(format: "%.1f Mbps", nq.uplinkMbps))),
            (copy.metricIdleLatency, mono(String(format: "%.1f ms", nq.idleLatencyMs))),
            (
                copy.metricLoadedLatency,
                "\(mono("\(Int(nq.loadedLatencyMs)) ms")) &nbsp;·&nbsp; <strong>\(mono("\(nq.responsivenessRPM) RPM"))</strong> <span class=\"rating-chip \(toneClass)\">\(escapeHTML(rating))</span>"
            ),
            (
                "ECN / L4S",
                "ECN \(escapeHTML(nq.ecnEnabled ? copy.enabled : copy.disabled)) · L4S \(escapeHTML(nq.l4sEnabled ? copy.enabled : copy.disabled))"
            )
        ]

        return """
        <section id="throughput" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secThroughput))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpThroughput))
          </div>
          \(buildSpecTable(rows: rows))
        </section>
        """
    }

    private static func buildRFScanSection(rf: RFScanResult, copy: ReportCopy) -> String {
        var rows: [(String, String)] = [
            (copy.metricScannedNetworks, mono("\(rf.totalNetworks)"))
        ]
        if let best5 = rf.recommended5GHz {
            let detail = "<strong>Ch \(mono("\(best5.channel)"))</strong> &nbsp;·&nbsp; \(best5.overlappingAPCount) \(escapeHTML(copy.overlappingAPs)) &nbsp;·&nbsp; <span class=\"muted\">\(escapeHTML(best5.note))</span>"
            rows.append((copy.metricBest5GHz, detail))
        }
        if let best2 = rf.recommended2GHz {
            let detail = "<strong>Ch \(mono("\(best2.channel)"))</strong> &nbsp;·&nbsp; \(best2.overlappingAPCount) \(escapeHTML(copy.overlappingAPs)) &nbsp;·&nbsp; <span class=\"muted\">20 MHz</span>"
            rows.append((copy.metricBest2GHz, detail))
        }

        return """
        <section id="rf" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secRFScan))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpRFScan))
          </div>
          \(buildSpecTable(rows: rows))
        </section>
        """
    }

    private static func buildStats24hSection(stats: AnalyticsSummary, copy: ReportCopy) -> String {
        var rows: [(String, String)] = [
            (copy.metricChecks, mono("\(stats.totalChecks)")),
            (copy.metricUptime, "<strong>\(mono(String(format: "%.1f%%", stats.uptimePercent)))</strong>")
        ]
        if let snr = stats.avgSNR {
            rows.append((
                copy.metricAvgMinSNR,
                "\(mono(String(format: "%.1f dB", snr))) / \(mono("\(stats.minSNR ?? 0) dB"))"
            ))
        }
        if let gw = stats.avgGatewayMs {
            rows.append((
                copy.metricAvgMaxGW,
                "\(mono(String(format: "%.1f ms", gw))) / \(mono(String(format: "%.1f ms", stats.maxGatewayMs ?? gw)))"
            ))
        }
        let incidents = [
            "\(copy.incDFS) \(mono("\(stats.dfsDriftCount)"))",
            "\(copy.inc24Fallback) \(mono("\(stats.wrongBandCount)"))",
            "\(copy.incIPv6) \(mono("\(stats.ipv6OutageCount)"))",
            "\(copy.incWiFiJitter) \(mono("\(stats.wifiJitterCount)"))",
            "\(copy.incISP) \(mono("\(stats.ispIssueCount)"))"
        ].joined(separator: " &nbsp;·&nbsp; ")
        rows.append((copy.metricIncidents, incidents))

        return """
        <section id="history" class="report-section">
          <div class="section-head">
            <h2>\(escapeHTML(copy.secStats24h))</h2>
            \(explainPanel(label: copy.helpLabel, items: copy.helpStats24h))
          </div>
          \(buildSpecTable(rows: rows))
        </section>
        """
    }

    // MARK: - Helpers

    private static func buildSpecTable(rows: [(String, String)]) -> String {
        let body = rows.map { key, val in
            "<tr><th scope=\"row\">\(escapeHTML(key))</th><td>\(val)</td></tr>"
        }.joined(separator: "\n")

        return """
        <div class="table-scroll">
          <table class="spec-table">
            <tbody>
              \(body)
            </tbody>
          </table>
        </div>
        """
    }

    private static func explainPanel(label: String, items: [(term: String, explanation: String)]) -> String {
        let dlItems = items.map { item in
            "<div class=\"gloss-row\"><dt>\(escapeHTML(item.term))</dt><dd>\(escapeHTML(item.explanation))</dd></div>"
        }.joined(separator: "\n")

        return """
        <details class="explain">
          <summary>
            <span class="info-glyph" aria-hidden="true">?</span>
            <span>\(escapeHTML(label))</span>
          </summary>
          <dl class="glossary">
            \(dlItems)
          </dl>
        </details>
        """
    }

    private static func mono(_ text: String) -> String {
        "<span class=\"mono\">\(escapeHTML(text))</span>"
    }

    public static func escapeHTML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }

    // MARK: - 6-Language Localization (EN, DE, IT, FR, ES, NL)

    private struct ReportCopy {
        let lang: ResolvedLanguage

        private func pick(
            en: String,
            de: String,
            it: String,
            fr: String,
            es: String,
            nl: String
        ) -> String {
            switch lang {
            case .en: return en
            case .de: return de
            case .it: return it
            case .fr: return fr
            case .es: return es
            case .nl: return nl
            }
        }

        var localeIdentifier: String {
            pick(en: "en_US", de: "de_DE", it: "it_IT", fr: "fr_FR", es: "es_ES", nl: "nl_NL")
        }

        var reportTitle: String {
            pick(
                en: "Diagnostic Report",
                de: "Diagnosebericht",
                it: "Report diagnostico",
                fr: "Rapport de diagnostic",
                es: "Informe de diagnóstico",
                nl: "Diagnoserapport"
            )
        }

        var generatedAt: String {
            pick(en: "Generated", de: "Erstellt", it: "Generato", fr: "Généré le", es: "Generado", nl: "Gegenereerd")
        }

        var explanationsToggle: String {
            pick(
                en: "Explanations",
                de: "Erklärungen",
                it: "Spiegazioni",
                fr: "Explications",
                es: "Explicaciones",
                nl: "Uitleg"
            )
        }

        var toggleHelpTooltip: String {
            pick(
                en: "Show or hide metric explanations in all sections",
                de: "Erklärungen in allen Abschnitten ein- oder ausblenden",
                it: "Mostra o nascondi le spiegazioni in tutte le sezioni",
                fr: "Afficher ou masquer les explications dans toutes les sections",
                es: "Mostrar u ocultar las explicaciones en todas las secciones",
                nl: "Toon of verberg uitleg in alle secties"
            )
        }

        var printPDF: String {
            pick(en: "Print / PDF", de: "Drucken / PDF", it: "Stampa / PDF", fr: "Imprimer / PDF", es: "Imprimir / PDF", nl: "Afdrukken / PDF")
        }

        var helpLabel: String {
            pick(en: "Explain", de: "Erklärung", it: "Guida", fr: "Explication", es: "Explicación", nl: "Uitleg")
        }

        var footerNote: String {
            pick(
                en: "Generated locally on your Mac",
                de: "Lokal auf deinem Mac erstellt",
                it: "Generato localmente sul tuo Mac",
                fr: "Généré localement sur votre Mac",
                es: "Generado localmente en tu Mac",
                nl: "Lokaal gegenereerd op je Mac"
            )
        }

        var statusOK: String {
            pick(en: "Healthy", de: "Optimal", it: "Ottimale", fr: "Nominal", es: "Óptimo", nl: "Gezond")
        }
        var statusWarn: String {
            pick(en: "Warning", de: "Hinweis", it: "Avviso", fr: "Avertissement", es: "Aviso", nl: "Waarschuwing")
        }
        var statusCrit: String {
            pick(en: "Critical", de: "Kritisch", it: "Critico", fr: "Critique", es: "Crítico", nl: "Kritiek")
        }

        var kpiSignalSNR: String {
            pick(en: "Signal (SNR)", de: "Signal (SNR)", it: "Segnale (SNR)", fr: "Signal (SNR)", es: "Señal (SNR)", nl: "Signaal (SNR)")
        }
        var kpiGatewayPing: String {
            pick(en: "Gateway Ping", de: "Gateway-Ping", it: "Ping Gateway", fr: "Ping passerelle", es: "Ping puerta enlace", nl: "Gateway-ping")
        }
        var kpiInternetPing: String {
            pick(en: "Internet Ping", de: "Internet-Ping", it: "Ping Internet", fr: "Ping Internet", es: "Ping Internet", nl: "Internet-ping")
        }
        var kpiUptime24h: String {
            pick(en: "24h Uptime", de: "24h-Uptime", it: "Uptime 24h", fr: "Dispo. 24h", es: "Disp. 24h", nl: "24u-uptime")
        }
        var kpiLinkRate: String {
            pick(en: "Link Rate", de: "Link-Rate", it: "Velocità link", fr: "Débit lien", es: "Velocidad enlace", nl: "Linksnelheid")
        }

        var navAlerts: String { pick(en: "Alerts", de: "Hinweise", it: "Avvisi", fr: "Alertes", es: "Alertas", nl: "Meldingen") }
        var navWiFi: String { pick(en: "Wi-Fi", de: "WLAN", it: "Wi-Fi", fr: "Wi-Fi", es: "Wi-Fi", nl: "Wi-Fi") }
        var navLatency: String { pick(en: "Latency", de: "Latenz", it: "Latenza", fr: "Latence", es: "Latencia", nl: "Latentie") }
        var navDNS: String { "DNS" }
        var navThroughput: String { pick(en: "Throughput", de: "Durchsatz", it: "Throughput", fr: "Débit", es: "Rendimiento", nl: "Doorvoer") }
        var navRFScan: String { pick(en: "Channels", de: "Kanäle", it: "Canali", fr: "Canaux", es: "Canales", nl: "Kanalen") }
        var navStats24h: String { "24h" }

        var offline: String { "Offline" }
        var unreachable: String {
            pick(en: "Unreachable", de: "Nicht erreichbar", it: "Irraggiungibile", fr: "Injoignable", es: "Inaccesible", nl: "Onbereikbaar")
        }
        var notMeasured: String {
            pick(en: "Not measured", de: "Nicht gemessen", it: "Non misurato", fr: "Non mesuré", es: "No medido", nl: "Niet gemeten")
        }
        var loss: String {
            pick(en: "loss", de: "Verlust", it: "persi", fr: "perte", es: "pérdida", nl: "verlies")
        }
        var checks: String {
            pick(en: "checks", de: "Prüfungen", it: "controlli", fr: "mesures", es: "pruebas", nl: "metingen")
        }
        var noActiveWiFi: String {
            pick(
                en: "No active Wi-Fi connection.",
                de: "Keine aktive WLAN-Verbindung.",
                it: "Nessuna connessione Wi-Fi attiva.",
                fr: "Aucune connexion Wi-Fi active.",
                es: "Sin conexión Wi-Fi activa.",
                nl: "Geen actieve Wi-Fi-verbinding."
            )
        }
        var noActiveWiFiShort: String {
            pick(en: "No Wi-Fi", de: "Kein WLAN", it: "Nessun Wi-Fi", fr: "Aucun Wi-Fi", es: "Sin Wi-Fi", nl: "Geen Wi-Fi")
        }
        var redacted: String {
            pick(en: "Redacted", de: "Verborgen", it: "Nascosto", fr: "Masqué", es: "Oculto", nl: "Verborgen")
        }
        var noneLabel: String {
            pick(en: "None", de: "Keine", it: "Nessuno", fr: "Aucun", es: "Ninguno", nl: "Geen")
        }
        var enabled: String {
            pick(en: "Enabled", de: "Aktiv", it: "Attivo", fr: "Activé", es: "Activado", nl: "Ingeschakeld")
        }
        var disabled: String {
            pick(en: "Disabled", de: "Inaktiv", it: "Disattivo", fr: "Désactivé", es: "Desactivado", nl: "Uitgeschakeld")
        }
        var hopLocal: String {
            pick(en: "This device", de: "Dieses Gerät", it: "Questo Mac", fr: "Cet appareil", es: "Este equipo", nl: "Dit apparaat")
        }

        var secAlerts: String {
            pick(en: "Active Findings", de: "Aktive Hinweise", it: "Avvisi attivi", fr: "Alertes actives", es: "Alertas activas", nl: "Actieve meldingen")
        }
        var badgeCritical: String {
            pick(en: "Critical", de: "Kritisch", it: "Critico", fr: "Critique", es: "Crítico", nl: "Kritiek")
        }
        var badgeWarning: String {
            pick(en: "Warning", de: "Warnung", it: "Avviso", fr: "Avertissement", es: "Aviso", nl: "Waarschuwing")
        }
        var tipLabel: String {
            pick(en: "Recommendation", de: "Empfehlung", it: "Consiglio", fr: "Conseil", es: "Recomendación", nl: "Advies")
        }

        var secWiFi: String {
            pick(en: "Wi-Fi Link", de: "WLAN-Verbindung", it: "Collegamento Wi-Fi", fr: "Connexion Wi-Fi", es: "Conexión Wi-Fi", nl: "Wi-Fi-verbinding")
        }
        var secLatency: String {
            pick(en: "Hop-by-Hop Latency", de: "Hop-by-Hop-Latenz", it: "Latenza Hop-by-Hop", fr: "Latence saut par saut", es: "Latencia salto a salto", nl: "Hop-by-hop-latentie")
        }
        var secDNS: String {
            pick(en: "DNS Resolution (Uncached)", de: "DNS-Auflösung (Uncached)", it: "Risoluzione DNS (Uncached)", fr: "Résolution DNS (sans cache)", es: "Resolución DNS (sin caché)", nl: "DNS-resolutie (zonder cache)")
        }
        var secThroughput: String {
            pick(en: "Throughput & Bufferbloat", de: "Durchsatz & Bufferbloat", it: "Throughput e Bufferbloat", fr: "Débit et Bufferbloat", es: "Rendimiento y Bufferbloat", nl: "Doorvoer & Bufferbloat")
        }
        var secRFScan: String {
            pick(en: "RF Channel Analysis", de: "RF-Kanalanalyse", it: "Analisi canali RF", fr: "Analyse des canaux RF", es: "Análisis de canales RF", nl: "RF-kanaalanalyse")
        }
        var secStats24h: String {
            pick(en: "24-Hour History", de: "24-Stunden-Verlauf", it: "Storico ultime 24 ore", fr: "Historique 24 heures", es: "Historial de 24 horas", nl: "24-uurs overzicht")
        }

        var colTarget: String { pick(en: "Target", de: "Ziel", it: "Destinazione", fr: "Cible", es: "Destino", nl: "Doel") }
        var colLoss: String { pick(en: "Loss", de: "Verlust", it: "Perdita", fr: "Perte", es: "Pérdida", nl: "Verlies") }
        var colMinAvgMax: String { pick(en: "Min / Avg / Max", de: "Min / Ø / Max", it: "Min / Media / Max", fr: "Min / Moy / Max", es: "Mín / Prom / Máx", nl: "Min / Gem / Max") }
        var colJitter: String { "Jitter" }
        var colResolver: String { "Resolver" }
        var colRole: String { pick(en: "Role", de: "Rolle", it: "Ruolo", fr: "Rôle", es: "Función", nl: "Rol") }
        var colQueryTime: String { pick(en: "Query Time", de: "Antwortzeit", it: "Tempo risposta", fr: "Temps de réponse", es: "Tiempo consulta", nl: "Reactietijd") }

        var metricInterface: String { "Interface" }
        var metricSSID: String { pick(en: "Network (SSID)", de: "Netzwerk (SSID)", it: "Rete (SSID)", fr: "Réseau (SSID)", es: "Red (SSID)", nl: "Netwerk (SSID)") }
        var metricBSSID: String { "Access Point (BSSID)" }
        var metricBandChannel: String { pick(en: "Band & Channel", de: "Band & Kanal", it: "Banda e canale", fr: "Bande et canal", es: "Banda y canal", nl: "Band & kanaal") }
        var metricPHYMode: String { pick(en: "PHY Mode", de: "PHY-Modus", it: "Modalità PHY", fr: "Mode PHY", es: "Modo PHY", nl: "PHY-modus") }
        var metricSignalNoiseSNR: String { pick(en: "Signal / Noise / SNR", de: "Signal / Rauschen / SNR", it: "Segnale / Rumore / SNR", fr: "Signal / Bruit / SNR", es: "Señal / Ruido / SNR", nl: "Signaal / Ruis / SNR") }
        var metricLinkRate: String { pick(en: "Link Rate", de: "Link-Rate", it: "Velocità link", fr: "Débit lien", es: "Velocidad enlace", nl: "Linksnelheid") }
        var metricIPv4: String { pick(en: "IPv4 Address", de: "IPv4-Adresse", it: "Indirizzo IPv4", fr: "Adresse IPv4", es: "Dirección IPv4", nl: "IPv4-adres") }
        var metricIPv6Prefixes: String { pick(en: "Active IPv6 Prefixes", de: "Aktive IPv6-Präfixe", it: "Prefissi IPv6 attivi", fr: "Préfixes IPv6 actifs", es: "Prefijos IPv6 activos", nl: "Actieve IPv6-prefixen") }
        var metricInterfaceErrors: String { pick(en: "Interface Drops / Errors", de: "Interface-Drops / Fehler", it: "Drop / Errori interfaccia", fr: "Pertes / Erreurs interface", es: "Descartes / Errores", nl: "Interface-drops / fouten") }

        var targetGateway: String { "Gateway" }
        var dnsActiveSystem: String { pick(en: "Active System DNS", de: "Aktiver System-DNS", it: "DNS di sistema", fr: "DNS système actif", es: "DNS del sistema", nl: "Actieve systeem-DNS") }
        var fastestBadge: String { pick(en: "Fastest", de: "Schnellster", it: "Più veloce", fr: "Plus rapide", es: "Más rápido", nl: "Snelste") }

        var metricDownlink: String { pick(en: "Downlink", de: "Download (Downlink)", it: "Download (Downlink)", fr: "Téléchargement (Downlink)", es: "Descarga (Downlink)", nl: "Download (Downlink)") }
        var metricUplink: String { pick(en: "Uplink", de: "Upload (Uplink)", it: "Upload (Uplink)", fr: "Envoi (Uplink)", es: "Subida (Uplink)", nl: "Upload (Uplink)") }
        var metricIdleLatency: String { pick(en: "Idle Latency", de: "Ruhelatenz (Idle)", it: "Latenza a riposo", fr: "Latence au repos", es: "Latencia en reposo", nl: "Rustlatentie") }
        var metricLoadedLatency: String { pick(en: "Loaded Latency / RPM", de: "Lastlatenz / RPM", it: "Latenza sotto carico / RPM", fr: "Latence en charge / RPM", es: "Latencia bajo carga / RPM", nl: "Belaste latentie / RPM") }

        var metricScannedNetworks: String { pick(en: "Networks Scanned", de: "Gescannte Netzwerke", it: "Reti rilevate", fr: "Réseaux détectés", es: "Redes escaneadas", nl: "Gescande netwerken") }
        var metricBest5GHz: String { pick(en: "Best 5 GHz Channel", de: "Bester 5-GHz-Kanal", it: "Miglior canale 5 GHz", fr: "Meilleur canal 5 GHz", es: "Mejor canal 5 GHz", nl: "Beste 5 GHz-kanaal") }
        var metricBest2GHz: String { pick(en: "Best 2.4 GHz Channel", de: "Bester 2,4-GHz-Kanal", it: "Miglior canale 2,4 GHz", fr: "Meilleur canal 2,4 GHz", es: "Mejor canal 2,4 GHz", nl: "Beste 2,4 GHz-kanaal") }
        var overlappingAPs: String { pick(en: "overlapping APs", de: "überlappende APs", it: "AP sovrapposti", fr: "PA chevauchants", es: "AP solapados", nl: "overlappende AP's") }

        var metricChecks: String { pick(en: "Total Checks", de: "Prüfungen gesamt", it: "Controlli totali", fr: "Mesures totales", es: "Pruebas totales", nl: "Aantal metingen") }
        var metricUptime: String { pick(en: "Uptime", de: "Verfügbarkeit", it: "Disponibilità", fr: "Disponibilité", es: "Disponibilidad", nl: "Beschikbaarheid") }
        var metricAvgMinSNR: String { pick(en: "Avg / Min SNR", de: "Ø / Min SNR", it: "SNR medio / min", fr: "SNR moy / min", es: "SNR prom / mín", nl: "Gem / Min SNR") }
        var metricAvgMaxGW: String { pick(en: "Avg / Max Gateway", de: "Ø / Max Gateway", it: "Gateway medio / max", fr: "Passerelle moy / max", es: "Gateway prom / máx", nl: "Gem / Max gateway") }
        var metricIncidents: String { pick(en: "Incidents", de: "Ereignisse", it: "Eventi", fr: "Incidents", es: "Incidencias", nl: "Incidenten") }

        var incDFS: String { "DFS" }
        var inc24Fallback: String { pick(en: "2.4 GHz fallback", de: "2,4-GHz-Fallback", it: "Fallback 2,4 GHz", fr: "Repli 2,4 GHz", es: "Caída 2,4 GHz", nl: "2,4 GHz-terugval") }
        var incIPv6: String { pick(en: "IPv6 outages", de: "IPv6-Ausfälle", it: "Guasti IPv6", fr: "Pannes IPv6", es: "Cortes IPv6", nl: "IPv6-uitval") }
        var incWiFiJitter: String { pick(en: "Wi-Fi jitter", de: "WLAN-Jitter", it: "Jitter Wi-Fi", fr: "Gigue Wi-Fi", es: "Jitter Wi-Fi", nl: "Wi-Fi-jitter") }
        var incISP: String { pick(en: "ISP issues", de: "ISP-Probleme", it: "Problemi ISP", fr: "Incidents FAI", es: "Fallos ISP", nl: "ISP-problemen") }

        // MARK: Explanations (all 6 languages)

        var helpWiFi: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("SNR (Signal-Rausch-Abstand)", "Differenz zwischen Signal (RSSI) und Hintergrundrauschen. Ab 25 dB sehr stabil, 15–24 dB mittelmäßig, unter 15 dB drohen Aussetzer."),
                    ("Band & Kanalbreite", "5 GHz und 6 GHz sind schneller und störungsärmer als 2,4 GHz. Breitere Kanäle (80/160 MHz) liefern mehr Tempo, überlappen aber eher mit Nachbarnetzen."),
                    ("IPv6-Präfixe", "Genau ein aktives globales Präfix ist ideal. Veraltete Präfixe nach Router-Neustarts können Seitenaufrufe verzögern."),
                    ("Interface-Drops", "Einzelne verworfene Pakete sind normal; stark steigende Werte deuten auf Funkstörungen hin.")
                ]
            case .it:
                return [
                    ("SNR (Rapporto segnale/rumore)", "Differenza tra segnale (RSSI) e rumore di fondo. ≥ 25 dB è ottimo, 15–24 dB discreto, sotto 15 dB rischio disconnessioni."),
                    ("Banda e ampiezza canale", "5 GHz e 6 GHz sono più veloci e meno affollati del 2,4 GHz. Canali più larghi (80/160 MHz) aumentano la velocità ma soffrono di più le interferenze."),
                    ("Prefissi IPv6", "Un solo prefisso globale attivo è l'ideale. Prefissi obsoleti possono rallentare l'apertura delle pagine."),
                    ("Drop interfaccia", "Qualche pacchetto perso è normale; valori in forte crescita indicano interferenze radio.")
                ]
            case .fr:
                return [
                    ("SNR (Rapport signal/bruit)", "Écart entre le signal (RSSI) et le bruit ambiant. ≥ 25 dB est solide, 15–24 dB moyen, sous 15 dB des coupures surviennent."),
                    ("Bande et largeur de canal", "5 GHz et 6 GHz sont plus rapides et moins saturés que 2,4 GHz. Des canaux larges (80/160 MHz) augmentent le débit mais chevauchent plus vite les voisins."),
                    ("Préfixes IPv6", "Un seul préfixe global actif est idéal. Des préfixes obsolètes après redémarrage du routeur peuvent ralentir la navigation."),
                    ("Pertes d'interface", "Quelques paquets perdus sont normaux ; une hausse rapide signale des interférences radio.")
                ]
            case .es:
                return [
                    ("SNR (Relación señal/ruido)", "Diferencia entre la señal (RSSI) y el ruido de fondo. ≥ 25 dB es sólido, 15–24 dB aceptable y < 15 dB suele provocar cortes."),
                    ("Banda y ancho de canal", "5 GHz y 6 GHz son más rápidos y limpios que 2,4 GHz. Canales anchos (80/160 MHz) ofrecen mayor velocidad pero más riesgo de solapamiento."),
                    ("Prefijos IPv6", "Lo ideal es un único prefijo global activo. Prefijos obsoletos tras reinicios del router pueden causar bloqueos."),
                    ("Descartes de interfaz", "Descartes ocasionales son normales; un aumento rápido indica interferencias inalámbricas.")
                ]
            case .nl:
                return [
                    ("SNR (Signaal-ruisverhouding)", "Verschil tussen signaal (RSSI) en achtergrondruis. ≥ 25 dB is sterk, 15–24 dB redelijk, onder 15 dB kans op wegvallen."),
                    ("Band & kanaalbreedte", "5 GHz en 6 GHz zijn sneller en rustiger dan 2,4 GHz. Bredere kanalen (80/160 MHz) geven meer snelheid maar overlappen sneller met buren."),
                    ("IPv6-prefixen", "Eén actief globaal prefix is ideaal. Verouderde prefixen na een router-herstart kunnen vertraging veroorzaken."),
                    ("Interface-drops", "Af en toe een drop is normaal; snel stijgende aantallen wijzen op draadloze storing.")
                ]
            case .en:
                return [
                    ("SNR (Signal-to-Noise Ratio)", "Gap between Wi-Fi signal (RSSI) and background noise. ≥ 25 dB is strong, 15–24 dB is fair, and < 15 dB risks drops."),
                    ("Band & Channel Width", "5 GHz and 6 GHz are faster and cleaner than 2.4 GHz. Wider channels (80/160 MHz) increase speed but overlap more easily with neighbors."),
                    ("IPv6 Prefixes", "One active global prefix is ideal. Stale prefixes after a router reconnect can stall web requests."),
                    ("Interface Drops", "Occasional drops are normal; rapidly rising counts point to RF interference.")
                ]
            }
        }

        var helpLatency: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("WLAN vs. ISP trennen", "Hoher Gateway-Ping (> 10 ms) oder Paketverlust zeigt ein lokales WLAN-/Router-Problem. Niedriger Gateway-Ping (< 3 ms) bei hohem Internet-Ping weist auf den Internetanbieter (ISP) hin."),
                    ("Jitter (± Stddev)", "Schwankung der Antwortzeiten. Unter 5 ms bleiben Video-Calls und Echtzeit-Apps flüssig."),
                    ("Paketverlust", "Optimal sind 0 %. Schon 1–2 % verursachen Aussetzer bei Sprache, Video und SSH.")
                ]
            case .it:
                return [
                    ("Wi-Fi vs. ISP", "Un ping alto verso il gateway (> 10 ms) indica un problema Wi-Fi locale. Gateway veloce (< 3 ms) ma Internet lento indica un problema del provider (ISP)."),
                    ("Jitter", "Variazione della latenza nel tempo. Sotto 5 ms videochiamate e giochi restano fluidi."),
                    ("Perdita pacchetti", "L'ideale è 0%. Anche l'1–2% causa interruzioni in chiamate e streaming.")
                ]
            case .fr:
                return [
                    ("Wi-Fi vs FAI", "Un ping élevé vers la passerelle (> 10 ms) signale un souci Wi-Fi local. Une passerelle rapide (< 3 ms) avec un ping Internet élevé indique un problème du FAI."),
                    ("Gigue (Jitter)", "Variation du temps de réponse. Sous 5 ms, les appels vidéo restent fluides."),
                    ("Perte de paquets", "0 % est idéal. Dès 1–2 %, des coupures apparaissent en visio ou SSH.")
                ]
            case .es:
                return [
                    ("Wi-Fi frente a ISP", "Latencia alta hacia el gateway (> 10 ms) apunta al Wi-Fi local. Gateway bajo (< 3 ms) con Internet alto apunta al proveedor (ISP)."),
                    ("Jitter", "Variación entre pings. Por debajo de 5 ms las videollamadas van fluidas."),
                    ("Pérdida de paquetes", "0 % es lo ideal. Incluso un 1–2 % genera cortes en llamadas y SSH.")
                ]
            case .nl:
                return [
                    ("Wi-Fi vs. ISP", "Hoge gateway-ping (> 10 ms) wijst op een lokaal Wi-Fi-probleem. Lage gateway-ping (< 3 ms) met hoge internet-ping wijst op de provider (ISP)."),
                    ("Jitter", "Schommeling in responstijd. Onder 5 ms blijven videogesprekken vloeiend."),
                    ("Pakketverlies", "0% is ideaal. Zelfs 1–2% geeft haperingen bij spraak, video en SSH.")
                ]
            case .en:
                return [
                    ("Wi-Fi vs. ISP", "High gateway latency (> 10 ms) or loss points to local Wi-Fi/router issues. A low gateway ping (< 3 ms) with high internet latency points to your ISP."),
                    ("Jitter", "Latency variation over time. Below 5 ms keeps video calls and interactive sessions smooth."),
                    ("Packet Loss", "0% is ideal. Even 1–2% loss causes noticeable stuttering in calls and SSH.")
                ]
            }
        }

        var helpDNS: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("Uncached Abfrage", "Misst die reale Auflösungszeit einer nicht zwischengespeicherten Domain. Langsames DNS lässt Webseiten träge wirken."),
                    ("Resolver-Wahl", "Ist der aktive System-DNS deutlich langsamer als 1.1.1.1 oder 8.8.8.8, lohnt sich ein Wechsel im Router oder in macOS.")
                ]
            case .it:
                return [
                    ("Query senza cache", "Misura il tempo reale per risolvere un dominio non in cache. Un DNS lento rende la navigazione poco reattiva."),
                    ("Scelta del resolver", "Se il DNS di sistema è molto più lento di 1.1.1.1 o 8.8.8.8, conviene cambiarlo sul router o su macOS.")
                ]
            case .fr:
                return [
                    ("Requête sans cache", "Mesure le temps réel de résolution d'un domaine non mis en cache. Un DNS lent donne une impression de lenteur web."),
                    ("Choix du résolveur", "Si le DNS système est nettement plus lent que 1.1.1.1 ou 8.8.8.8, changer de DNS dans le routeur ou macOS aide.")
                ]
            case .es:
                return [
                    ("Consulta sin caché", "Mide el tiempo real de resolución de un dominio nuevo. Un DNS lento hace que la navegación se sienta pesada."),
                    ("Elección de DNS", "Si tu DNS del sistema es mucho más lento que 1.1.1.1 u 8.8.8.8, conviene cambiarlo en el router o en macOS.")
                ]
            case .nl:
                return [
                    ("Query zonder cache", "Meet de echte opzoektijd van een nieuw domein. Trage DNS laat websites traag aanvoelen."),
                    ("Resolver kiezen", "Is je systeem-DNS duidelijk trager dan 1.1.1.1 of 8.8.8.8, dan helpt overstappen in je router of macOS.")
                ]
            case .en:
                return [
                    ("Uncached Query", "Measures real lookup time for a non-cached domain. Slow DNS makes web browsing feel sluggish."),
                    ("Choosing a Resolver", "If your system DNS is consistently slower than 1.1.1.1 or 8.8.8.8, switching resolvers in your router or macOS helps.")
                ]
            }
        }

        var helpThroughput: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("Responsiveness (RPM)", "Apple misst mit Roundtrips Per Minute (RPM) die Reaktionsfreude unter Volllast: ≥ 1000 hoch, 300–999 mittel, < 300 niedrig."),
                    ("Bufferbloat", "Steigt die Lastlatenz stark gegenüber der Ruhelatenz, stauen sich Pakete im Router-Puffer. SQM/QoS im Router behebt das."),
                    ("ECN / L4S", "Stauerkennung ohne Paketverlust – hält die Latenz bei großen Downloads niedrig, wenn Router und ISP es unterstützen.")
                ]
            case .it:
                return [
                    ("Reattività (RPM)", "I Roundtrips Per Minute di Apple misurano la reattività sotto carico: ≥ 1000 alta, 300–999 media, < 300 bassa."),
                    ("Bufferbloat", "Se la latenza sotto carico sale molto rispetto a quella a riposo, i buffer del router si riempiono. Attivare SQM/QoS aiuta."),
                    ("ECN / L4S", "Segnalazione moderna della congestione che riduce i picchi di latenza sotto carico.")
                ]
            case .fr:
                return [
                    ("Réactivité (RPM)", "Les allers-retours par minute d'Apple mesurent la réactivité en charge : ≥ 1000 élevée, 300–999 moyenne, < 300 faible."),
                    ("Bufferbloat", "Si la latence explose en charge, les tampons du routeur saturent. Activer SQM/QoS corrige ce phénomène."),
                    ("ECN / L4S", "Signalisation de congestion sans perte de paquets, réduisant la latence en téléchargement.")
                ]
            case .es:
                return [
                    ("Capacidad de respuesta (RPM)", "Los RPM de Apple miden la agilidad bajo carga: ≥ 1000 alta, 300–999 media, < 300 baja."),
                    ("Bufferbloat", "Si la latencia bajo carga se dispara frente al reposo, los búferes del router se saturan. Activar SQM/QoS ayuda."),
                    ("ECN / L4S", "Control moderno de congestión que mantiene baja la latencia durante descargas intensas.")
                ]
            case .nl:
                return [
                    ("Responsiviteit (RPM)", "Apple's Roundtrips Per Minute meten hoe vlot je lijn onder belasting blijft: ≥ 1000 hoog, 300–999 gemiddeld, < 300 laag."),
                    ("Bufferbloat", "Schiet de belaste latentie omhoog, dan lopen routerbuffers vol. SQM/QoS in de router lost dit op."),
                    ("ECN / L4S", "Moderne congestiesignalering die latentiepieken tijdens downloads vermindert.")
                ]
            case .en:
                return [
                    ("Responsiveness (RPM)", "Apple’s Roundtrips Per Minute rate link agility under load: ≥ 1000 High, 300–999 Medium, < 300 Low."),
                    ("Bufferbloat", "A sharp jump from idle to loaded latency means packets queue in router buffers. Enabling SQM/QoS helps."),
                    ("ECN / L4S", "Modern congestion signaling that keeps latency low during heavy downloads when supported end-to-end.")
                ]
            }
        }

        var helpRFScan: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("Überlappende APs", "Weniger Nachbarnetze auf demselben Kanal bedeuten weniger Wartezeit auf dem Funkmedium und höheren Durchsatz."),
                    ("DFS-Kanäle (5 GHz)", "Kanäle 52–144 teilen sich Frequenzen mit Radar. Bei Radarerkennung wechselt der Router den Kanal (kurzer Aussetzer). Kanäle 36–48 sind DFS-frei.")
                ]
            case .it:
                return [
                    ("AP sovrapposti", "Meno reti vicine sullo stesso canale significano meno contesa radio e velocità più stabili."),
                    ("Canali DFS (5 GHz)", "I canali 52–144 condividono lo spettro con i radar; in caso di rilevamento il router cambia canale. I canali 36–48 sono privi di DFS.")
                ]
            case .fr:
                return [
                    ("PA chevauchants", "Moins de réseaux voisins sur le même canal signifie moins de congestion radio et un meilleur débit."),
                    ("Canaux DFS (5 GHz)", "Les canaux 52–144 partagent le spectre avec les radars, pouvant forcer un changement de canal. Les canaux 36–48 sont sans DFS.")
                ]
            case .es:
                return [
                    ("AP solapados", "Menos redes vecinas en el mismo canal implican menor congestión y mayor velocidad real."),
                    ("Canales DFS (5 GHz)", "Los canales 52–144 comparten espectro con radares y pueden forzar cambios de canal. Los canales 36–48 no usan DFS.")
                ]
            case .nl:
                return [
                    ("Overlappende AP's", "Minder buurnetwerken op hetzelfde kanaal geeft minder radiodrukte en hogere snelheid."),
                    ("DFS-kanalen (5 GHz)", "Kanalen 52–144 delen spectrum met radar, waardoor routers kunnen verspringen. Kanalen 36–48 zijn DFS-vrij.")
                ]
            case .en:
                return [
                    ("Overlapping APs", "Fewer neighboring networks on your channel mean less airtime contention and higher throughput."),
                    ("DFS Channels (5 GHz)", "Channels 52–144 share spectrum with radar and may trigger channel shifts. Channels 36–48 are non-DFS.")
                ]
            }
        }

        var helpStats24h: [(term: String, explanation: String)] {
            switch lang {
            case .de:
                return [
                    ("Verfügbarkeit", "Anteil der regelmäßigen Prüfungen in den letzten 24 Stunden mit stabiler Verbindung."),
                    ("DFS- & 2,4-GHz-Ereignisse", "Zählt unbemerkte Kanalwechsel durch Radar sowie Rückfälle ins langsamere 2,4-GHz-Band."),
                    ("WLAN-Jitter vs. ISP", "Trennt wiederkehrende lokale Funkprobleme von Störungen beim Internetanbieter.")
                ]
            case .it:
                return [
                    ("Disponibilità", "Percentuale dei controlli delle ultime 24 ore con connessione funzionante."),
                    ("Eventi DFS e 2,4 GHz", "Conta i cambi canale dovuti a radar e i passaggi imprevisti alla banda 2,4 GHz."),
                    ("Jitter Wi-Fi vs. ISP", "Distingue i disturbi radio locali dai problemi del provider Internet.")
                ]
            case .fr:
                return [
                    ("Disponibilité", "Part des mesures des dernières 24 heures présentant une connexion saine."),
                    ("DFS et repli 2,4 GHz", "Compte les changements de canal radar et les bascules vers la bande 2,4 GHz."),
                    ("Gigue Wi-Fi vs FAI", "Distingue les perturbations Wi-Fi locales des incidents du fournisseur d'accès.")
                ]
            case .es:
                return [
                    ("Disponibilidad", "Porcentaje de comprobaciones de las últimas 24 horas con conexión estable."),
                    ("Eventos DFS y 2,4 GHz", "Registra cambios de canal por radar y caídas a la banda más lenta de 2,4 GHz."),
                    ("Jitter Wi-Fi vs. ISP", "Separa problemas locales de radiofrecuencia de fallos del proveedor.")
                ]
            case .nl:
                return [
                    ("Beschikbaarheid", "Percentage metingen in de afgelopen 24 uur met een gezonde verbinding."),
                    ("DFS & 2,4 GHz", "Telt kanaalwissels door radar en terugval naar de tragere 2,4 GHz-band."),
                    ("Wi-Fi-jitter vs. ISP", "Onderscheidt lokale Wi-Fi-storingen van problemen bij de internetprovider.")
                ]
            case .en:
                return [
                    ("Uptime", "Share of periodic checks over the last 24 hours with a healthy connection."),
                    ("DFS & 2.4 GHz Events", "Counts silent radar-triggered channel shifts and fallbacks to the slower 2.4 GHz band."),
                    ("Wi-Fi Jitter vs. ISP", "Separates recurring local RF interference from upstream provider issues.")
                ]
            }
        }
    }

    // MARK: - Fallback SVG Logo

    private static let fallbackSVGLogo = """
    <svg class="brand-mark" viewBox="0 0 64 64" width="44" height="44" xmlns="http://www.w3.org/2000/svg" aria-label="AirPhare">
      <defs>
        <linearGradient id="ap-bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#07142b"/>
          <stop offset="100%" stop-color="#0d2a45"/>
        </linearGradient>
        <linearGradient id="ap-wave" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stop-color="#00c8ff"/>
          <stop offset="100%" stop-color="#00e5a0"/>
        </linearGradient>
      </defs>
      <rect width="64" height="64" rx="14" fill="url(#ap-bg)"/>
      <path d="M16 24 A22 22 0 0 1 48 24" fill="none" stroke="url(#ap-wave)" stroke-width="2.6" stroke-linecap="round"/>
      <path d="M21 29 A15 15 0 0 1 43 29" fill="none" stroke="url(#ap-wave)" stroke-width="2.4" stroke-linecap="round"/>
      <path d="M26 34 A8 8 0 0 1 38 34" fill="none" stroke="url(#ap-wave)" stroke-width="2.2" stroke-linecap="round"/>
      <polygon points="27,54 37,54 35,36 29,36" fill="#dce7f2"/>
      <rect x="28" y="32" width="8" height="4" rx="1" fill="#8ff7e8"/>
      <polygon points="26,32 38,32 32,27" fill="#b8cbe0"/>
      <rect x="30.5" y="48" width="3" height="6" rx="1" fill="#1b3554"/>
    </svg>
    """

    // MARK: - Editorial / Technical Instrument CSS

    private static let cssStyles = """
    :root {
      --canvas: #f4f5f7;
      --paper: #ffffff;
      --subtle: #f8f9fb;
      --line: #e4e7ec;
      --line-strong: #d0d5dd;
      --ink: #101828;
      --ink-2: #475467;
      --ink-3: #667085;
      --accent: #0a6c8f;
      --accent-soft: #eef7fa;
      --ok: #0d8a5a;
      --ok-soft: #ecfdf3;
      --warn: #b56800;
      --warn-soft: #fffaeb;
      --crit: #c9302c;
      --crit-soft: #fef3f2;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --canvas: #0b0e14;
        --paper: #121720;
        --subtle: #171d28;
        --line: #232c3b;
        --line-strong: #323e52;
        --ink: #f1f5f9;
        --ink-2: #a0aec0;
        --ink-3: #718096;
        --accent: #3db8e0;
        --accent-soft: rgba(61, 184, 224, 0.12);
        --ok: #34d399;
        --ok-soft: rgba(52, 211, 153, 0.12);
        --warn: #fbbf24;
        --warn-soft: rgba(251, 191, 36, 0.12);
        --crit: #f87171;
        --crit-soft: rgba(248, 113, 113, 0.14);
      }
    }

    * { box-sizing: border-box; }
    html { scroll-behavior: smooth; }

    body {
      margin: 0;
      padding: 28px 18px 48px;
      background: var(--canvas);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", "Segoe UI", sans-serif;
      font-size: 14px;
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
    }

    .sheet {
      max-width: 880px;
      margin: 0 auto;
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 12px;
      overflow: hidden;
    }

    /* Masthead */
    .masthead {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 20px;
      flex-wrap: wrap;
      padding: 22px 28px;
      border-bottom: 1px solid var(--line);
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 14px;
      min-width: 0;
    }

    .brand-mark {
      width: 44px;
      height: 44px;
      border-radius: 10px;
      flex-shrink: 0;
      display: block;
    }

    .brand-meta { min-width: 0; }

    .brand-line {
      display: flex;
      align-items: baseline;
      gap: 8px;
      flex-wrap: wrap;
    }

    .brand-name {
      font-size: 17px;
      font-weight: 700;
      letter-spacing: -0.02em;
    }

    .brand-sep { color: var(--line-strong); font-weight: 300; }

    .brand-doc {
      font-size: 15px;
      font-weight: 500;
      color: var(--ink-2);
    }

    .version-tag {
      font-family: ui-monospace, "SF Mono", Menlo, monospace;
      font-size: 11px;
      color: var(--ink-3);
      padding: 1px 6px;
      border: 1px solid var(--line);
      border-radius: 4px;
    }

    .meta-line {
      margin-top: 2px;
      font-size: 12.5px;
      color: var(--ink-3);
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: wrap;
    }

    .meta-dot { opacity: 0.6; }

    /* Toolbar */
    .toolbar {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .switch-control {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      user-select: none;
      font-size: 13px;
      font-weight: 500;
      color: var(--ink-2);
    }

    .switch-control input {
      position: absolute;
      opacity: 0;
      width: 1px;
      height: 1px;
    }

    .switch-track {
      width: 32px;
      height: 18px;
      border-radius: 999px;
      background: var(--line-strong);
      position: relative;
      transition: background 0.16s ease;
    }

    .switch-track::after {
      content: "";
      position: absolute;
      top: 2px;
      left: 2px;
      width: 14px;
      height: 14px;
      border-radius: 50%;
      background: #ffffff;
      box-shadow: 0 1px 2px rgba(0, 0, 0, 0.22);
      transition: transform 0.16s ease;
    }

    .switch-control input:checked + .switch-track {
      background: var(--accent);
    }

    .switch-control input:checked + .switch-track::after {
      transform: translateX(14px);
    }

    .switch-control input:focus-visible + .switch-track {
      outline: 2px solid var(--accent);
      outline-offset: 2px;
    }

    .action-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 12px;
      font-family: inherit;
      font-size: 12.5px;
      font-weight: 500;
      color: var(--ink);
      background: var(--paper);
      border: 1px solid var(--line-strong);
      border-radius: 7px;
      cursor: pointer;
      transition: background 0.12s ease, border-color 0.12s ease;
    }

    .action-btn:hover {
      background: var(--subtle);
      border-color: var(--ink-3);
    }

    /* Summary Band + Instrument Strip */
    .summary-band {
      border-bottom: 1px solid var(--line);
    }

    .status-row {
      display: flex;
      align-items: center;
      gap: 9px;
      padding: 12px 28px;
      font-size: 13.5px;
      border-bottom: 1px solid var(--line);
      background: var(--subtle);
    }

    .status-row.is-ok { background: var(--ok-soft); }
    .status-row.is-warn { background: var(--warn-soft); }
    .status-row.is-crit { background: var(--crit-soft); }

    .status-indicator {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .status-row.is-ok .status-indicator { background: var(--ok); }
    .status-row.is-warn .status-indicator { background: var(--warn); }
    .status-row.is-crit .status-indicator { background: var(--crit); }

    .status-state {
      font-weight: 600;
    }

    .status-row.is-ok .status-state { color: var(--ok); }
    .status-row.is-warn .status-state { color: var(--warn); }
    .status-row.is-crit .status-state { color: var(--crit); }

    .status-divider { color: var(--ink-3); }
    .status-headline { color: var(--ink); font-weight: 500; }

    .instrument-strip {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
    }

    .instrument-cell {
      padding: 16px 22px;
      border-right: 1px solid var(--line);
    }

    .instrument-cell:first-child { padding-left: 28px; }
    .instrument-cell:last-child { border-right: none; padding-right: 28px; }

    @media (max-width: 720px) {
      .instrument-strip { grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .instrument-cell { padding: 14px 20px; border-bottom: 1px solid var(--line); }
      .instrument-cell:nth-child(2n) { border-right: none; }
      .instrument-cell:nth-last-child(-n+2) { border-bottom: none; }
    }

    .inst-label {
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--ink-3);
    }

    .inst-value-row {
      margin-top: 6px;
      display: flex;
      align-items: center;
      gap: 7px;
    }

    .tone-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      flex-shrink: 0;
    }

    .tone-dot.is-ok { background: var(--ok); }
    .tone-dot.is-warn { background: var(--warn); }
    .tone-dot.is-crit { background: var(--crit); }
    .tone-dot.is-muted { background: var(--line-strong); }

    .inst-value {
      font-size: 20px;
      font-weight: 650;
      letter-spacing: -0.02em;
      font-variant-numeric: tabular-nums;
    }

    .meter {
      margin-top: 7px;
      height: 3px;
      border-radius: 2px;
      background: var(--line);
      overflow: hidden;
    }

    .meter-fill { height: 100%; border-radius: 2px; }
    .meter-fill.is-ok { background: var(--ok); }
    .meter-fill.is-warn { background: var(--warn); }
    .meter-fill.is-crit { background: var(--crit); }

    .inst-sub {
      margin-top: 5px;
      font-size: 12px;
      color: var(--ink-3);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    /* Section Rail */
    .section-rail {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 8px 24px;
      border-bottom: 1px solid var(--line);
      background: var(--subtle);
      overflow-x: auto;
    }

    .section-rail a {
      text-decoration: none;
      color: var(--ink-2);
      font-size: 12.5px;
      font-weight: 500;
      padding: 4px 10px;
      border-radius: 6px;
      white-space: nowrap;
      transition: background 0.12s ease, color 0.12s ease;
    }

    .section-rail a:hover {
      background: var(--paper);
      color: var(--ink);
    }

    /* Report Body */
    .report-body {
      padding: 6px 28px 18px;
    }

    .report-section {
      padding: 22px 0;
      border-bottom: 1px solid var(--line);
    }

    .report-section:last-child { border-bottom: none; }

    .section-head {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      gap: 12px;
      flex-wrap: wrap;
      margin-bottom: 14px;
    }

    .section-head h2 {
      margin: 0;
      font-size: 14.5px;
      font-weight: 650;
      letter-spacing: -0.01em;
      display: inline-flex;
      align-items: center;
      gap: 8px;
    }

    .section-count {
      font-size: 11.5px;
      font-weight: 600;
      color: var(--ink-3);
      background: var(--subtle);
      border: 1px solid var(--line);
      padding: 0 7px;
      border-radius: 999px;
    }

    /* Explain Disclosure */
    details.explain {
      max-width: 100%;
    }

    details.explain[open] {
      width: 100%;
    }

    details.explain > summary {
      list-style: none;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 3px 9px 3px 6px;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 500;
      color: var(--accent);
      background: transparent;
      border: 1px solid transparent;
      cursor: pointer;
      user-select: none;
      transition: background 0.12s ease, border-color 0.12s ease;
    }

    details.explain > summary::-webkit-details-marker { display: none; }

    details.explain > summary:hover,
    details.explain[open] > summary {
      background: var(--accent-soft);
      border-color: var(--line);
    }

    .info-glyph {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 16px;
      height: 16px;
      border-radius: 50%;
      border: 1.25px solid currentColor;
      font-size: 10.5px;
      font-weight: 700;
      line-height: 1;
    }

    .glossary {
      margin: 12px 0 2px;
      padding: 12px 16px;
      background: var(--subtle);
      border-left: 2px solid var(--accent);
      border-radius: 0 6px 6px 0;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }

    .gloss-row {
      display: grid;
      grid-template-columns: 200px 1fr;
      gap: 12px;
      font-size: 12.5px;
      line-height: 1.48;
    }

    @media (max-width: 640px) {
      .gloss-row { grid-template-columns: 1fr; gap: 2px; }
    }

    .gloss-row dt {
      font-weight: 600;
      color: var(--ink);
    }

    .gloss-row dd {
      margin: 0;
      color: var(--ink-2);
    }

    /* Findings (Alerts) */
    .findings-list {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }

    .finding {
      padding: 12px 14px;
      border: 1px solid var(--line);
      border-left: 3px solid var(--line-strong);
      border-radius: 8px;
      background: var(--subtle);
    }

    .finding.is-warn { border-left-color: var(--warn); background: var(--warn-soft); }
    .finding.is-crit { border-left-color: var(--crit); background: var(--crit-soft); }

    .finding-head {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .finding-tag {
      font-size: 10.5px;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }

    .finding.is-warn .finding-tag { color: var(--warn); }
    .finding.is-crit .finding-tag { color: var(--crit); }

    .finding-title { font-weight: 600; font-size: 13.5px; }
    .finding-desc { margin: 4px 0 0; font-size: 13px; color: var(--ink-2); }
    .finding-action { margin: 4px 0 0; font-size: 12.5px; color: var(--ink-2); }

    /* Hop Path Diagram */
    .hop-diagram {
      display: grid;
      grid-template-columns: auto 1fr auto 1fr auto;
      align-items: center;
      gap: 12px;
      padding: 14px 18px;
      margin-bottom: 16px;
      background: var(--subtle);
      border: 1px solid var(--line);
      border-radius: 8px;
    }

    @media (max-width: 600px) {
      .hop-diagram { grid-template-columns: 1fr; text-align: center; }
      .hop-line { display: none; }
    }

    .hop-node {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }

    .hop-title { font-size: 13px; font-weight: 600; }
    .hop-sub { font-size: 11.5px; color: var(--ink-3); }

    .hop-link {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 3px;
    }

    .hop-metric {
      font-family: ui-monospace, "SF Mono", Menlo, monospace;
      font-size: 12px;
      font-weight: 600;
      font-variant-numeric: tabular-nums;
    }

    .hop-link.is-ok .hop-metric { color: var(--ok); }
    .hop-link.is-warn .hop-metric { color: var(--warn); }
    .hop-link.is-crit .hop-metric { color: var(--crit); }
    .hop-link.is-muted .hop-metric { color: var(--ink-3); }

    .hop-line {
      width: 100%;
      height: 2px;
      border-radius: 1px;
      background: var(--line-strong);
    }

    .hop-link.is-ok .hop-line { background: var(--ok); opacity: 0.55; }
    .hop-link.is-warn .hop-line { background: var(--warn); opacity: 0.65; }
    .hop-link.is-crit .hop-line { background: var(--crit); opacity: 0.7; }

    .hop-caption {
      font-size: 10.5px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--ink-3);
    }

    /* Tables */
    .table-scroll { overflow-x: auto; }

    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13.5px;
    }

    .spec-table th {
      width: 34%;
      text-align: left;
      font-weight: 500;
      color: var(--ink-2);
      padding: 8px 12px 8px 0;
      border-bottom: 1px solid var(--line);
      vertical-align: top;
    }

    .spec-table td {
      padding: 8px 0;
      border-bottom: 1px solid var(--line);
      color: var(--ink);
    }

    .spec-table tr:last-child th,
    .spec-table tr:last-child td { border-bottom: none; }

    .data-table thead th {
      text-align: left;
      font-size: 11px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--ink-3);
      padding: 0 10px 8px;
      border-bottom: 1px solid var(--line-strong);
    }

    .data-table thead th:first-child { padding-left: 0; }
    .data-table thead th:last-child { padding-right: 0; }

    .data-table tbody td {
      padding: 9px 10px;
      border-bottom: 1px solid var(--line);
      vertical-align: middle;
    }

    .data-table tbody td:first-child { padding-left: 0; }
    .data-table tbody td:last-child { padding-right: 0; }
    .data-table tbody tr:last-child td { border-bottom: none; }

    .num { text-align: right; }
    .mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12.5px; font-variant-numeric: tabular-nums; }
    .sub-mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 12px; color: var(--ink-3); margin-left: 6px; }
    .muted { color: var(--ink-3); }
    .strong { font-weight: 600; }
    .text-crit { color: var(--crit); font-weight: 600; }

    .inline-tag {
      display: inline-block;
      margin-left: 7px;
      padding: 1px 6px;
      border-radius: 4px;
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
      font-size: 11px;
      font-weight: 600;
      color: var(--accent);
      background: var(--accent-soft);
    }

    .rating-chip {
      display: inline-block;
      margin-left: 6px;
      padding: 1px 7px;
      border-radius: 4px;
      font-size: 11.5px;
      font-weight: 600;
    }

    .rating-chip.is-ok { color: var(--ok); background: var(--ok-soft); }
    .rating-chip.is-warn { color: var(--warn); background: var(--warn-soft); }
    .rating-chip.is-crit { color: var(--crit); background: var(--crit-soft); }

    /* DNS Latency Bars */
    .bar-cell {
      display: inline-flex;
      align-items: center;
      justify-content: flex-end;
      gap: 10px;
      min-width: 140px;
    }

    .bar-track {
      width: 72px;
      height: 5px;
      border-radius: 3px;
      background: var(--line);
      overflow: hidden;
    }

    .bar-fill {
      height: 100%;
      border-radius: 3px;
      background: var(--ink-3);
      opacity: 0.55;
    }

    .bar-fill.is-accent {
      background: var(--accent);
      opacity: 1;
    }

    .empty-state {
      margin: 0;
      color: var(--ink-3);
      font-style: italic;
    }

    /* Footer */
    .colophon {
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      flex-wrap: wrap;
      padding: 14px 28px;
      border-top: 1px solid var(--line);
      background: var(--subtle);
      font-size: 12px;
      color: var(--ink-3);
    }

    /* Print / PDF */
    @media print {
      :root {
        --canvas: #ffffff;
        --paper: #ffffff;
        --subtle: #f8f9fb;
        --line: #d8dee6;
        --line-strong: #bfc7d4;
        --ink: #101828;
        --ink-2: #344054;
        --ink-3: #667085;
      }
      body { padding: 0; background: #ffffff; }
      .sheet { max-width: none; border: none; border-radius: 0; }
      .no-print { display: none !important; }
      .status-row, .finding, .hop-diagram, .meter-fill, .bar-fill {
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .report-section { break-inside: avoid; }
      details.explain:not([open]) > summary { display: none; }
    }
    """
}

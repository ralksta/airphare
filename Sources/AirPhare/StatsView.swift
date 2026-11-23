import AirPhareCore
import Charts
import SwiftUI

struct StatsView: View {
    @Bindable var vm: MonitorViewModel

    private var lang: ResolvedLanguage { vm.lang }
    private func t(_ key: L10nKey) -> String { L10n.t(key, lang: lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("", selection: $vm.analyticsWindow) {
                    Text(t(.window24h)).tag(AnalyticsWindow.last24Hours)
                    Text(t(.window7d)).tag(AnalyticsWindow.last7Days)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Spacer()

                if let summary = vm.analyticsSummary, summary.totalChecks > 0 {
                    Text(L10n.fmt(.statsChecksCount, lang: lang, summary.totalChecks))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let summary = vm.analyticsSummary, summary.totalChecks > 0 {
                kpiGrid(summary)
                incidentsCard(summary)
                chartsSection(summary)
            } else {
                GroupBox {
                    Text(t(.statsNoData))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            Task { await vm.refreshAnalytics() }
        }
        .onChange(of: vm.analyticsWindow) { _, _ in
            Task { await vm.refreshAnalytics() }
        }
    }

    private func kpiGrid(_ s: AnalyticsSummary) -> some View {
        GroupBox {
            HStack(spacing: 10) {
                kpiItem(
                    title: t(.statsUptime),
                    value: String(format: "%.1f%%", s.uptimePercent),
                    tint: s.uptimePercent >= 99 ? .green : .orange
                )
                kpiItem(
                    title: t(.statsAvgSNR),
                    value: s.avgSNR.map { String(format: "%.0f dB", $0) } ?? "–",
                    tint: (s.avgSNR ?? 30) >= 25 ? .blue : .orange
                )
                kpiItem(
                    title: t(.statsAvgGateway),
                    value: s.avgGatewayMs.map { String(format: "%.1f ms", $0) } ?? "–",
                    tint: (s.avgGatewayMs ?? 10) <= 20 ? .green : .orange
                )
                kpiItem(
                    title: t(.statsAvgInternet),
                    value: s.avgInternetMs.map { String(format: "%.1f ms", $0) } ?? "–",
                    tint: .primary
                )
            }
        }
    }

    private func kpiItem(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func incidentsCard(_ s: AnalyticsSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(t(.statsIncidentsTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    incidentChip(label: t(.statsIncidentDFS), count: s.dfsDriftCount)
                    incidentChip(label: t(.statsIncident2GHz), count: s.wrongBandCount)
                    incidentChip(label: t(.statsIncidentIPv6), count: s.ipv6OutageCount)
                    incidentChip(label: t(.statsIncidentJitter), count: s.wifiJitterCount)
                    incidentChip(label: t(.statsIncidentISP), count: s.ispIssueCount)
                }
            }
        }
    }

    private func incidentChip(label: String, count: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(count == 0 ? .green : .orange)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background((count == 0 ? Color.green : Color.orange).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func chartsSection(_ s: AnalyticsSummary) -> some View {
        let snrPoints = s.points.filter { $0.snr != nil }
        if snrPoints.count >= 2 {
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(.statsChartSNR))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Chart(snrPoints) { pt in
                        AreaMark(
                            x: .value("Time", pt.timestamp),
                            y: .value("SNR", pt.snr ?? 0)
                        )
                        .foregroundStyle(.blue.opacity(0.18))

                        LineMark(
                            x: .value("Time", pt.timestamp),
                            y: .value("SNR", pt.snr ?? 0)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1.75))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .frame(height: 82)
                }
            }
        }

        let latencyPoints = s.points.filter { $0.gatewayAvgMs != nil || $0.internetAvgMs != nil }
        if latencyPoints.count >= 2 {
            GroupBox {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t(.statsChartLatency))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Chart {
                        ForEach(latencyPoints) { pt in
                            if let gw = pt.gatewayAvgMs {
                                LineMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("ms", gw),
                                    series: .value("Series", "Router")
                                )
                                .foregroundStyle(.green)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            }
                            if let inet = pt.internetAvgMs {
                                LineMark(
                                    x: .value("Time", pt.timestamp),
                                    y: .value("ms", inet),
                                    series: .value("Series", "IPv4")
                                )
                                .foregroundStyle(.orange)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .frame(height: 82)
                }
            }
        }
    }
}

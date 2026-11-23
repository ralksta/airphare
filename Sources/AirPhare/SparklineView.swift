import AirPhareCore
import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let tint: Color
    let label: String
    let unit: String
    let lang: ResolvedLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let last = values.last {
                    Text("\(String(format: "%.0f", last)) \(unit)")
                        .font(.caption2.monospacedDigit().weight(.medium))
                        .foregroundStyle(tint)
                }
            }

            GeometryReader { geo in
                Canvas { context, size in
                    guard values.count >= 2 else { return }
                    let minVal = (values.min() ?? 0) * 0.9
                    let maxVal = max((values.max() ?? 1) * 1.1, minVal + 1)
                    let span = maxVal - minVal

                    var path = Path()
                    for (idx, val) in values.enumerated() {
                        let x = size.width * CGFloat(idx) / CGFloat(values.count - 1)
                        let normalized = CGFloat((val - minVal) / span)
                        let y = size.height - (normalized * (size.height - 4)) - 2
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(tint),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 26)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.fmt(.sparklineHistoryA11y, lang: lang, label))
    }
}

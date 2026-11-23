import Foundation

public enum ChannelAnalyzer {

    /// ETSI / Germany 5 GHz 80 MHz primary candidate blocks
    private struct FiveGHzBlock {
        let primary: Int
        let range: ClosedRange<Int>
        let isDFS: Bool
        let isWeatherRadar: Bool
        let highPowerETSI: Bool // 1000 mW allowed on ch 100-140 in DE vs 200 mW on 36-64
    }

    private static let fiveGHzBlocks: [FiveGHzBlock] = [
        FiveGHzBlock(primary: 36, range: 36...48, isDFS: false, isWeatherRadar: false, highPowerETSI: false),
        FiveGHzBlock(primary: 52, range: 52...64, isDFS: true, isWeatherRadar: false, highPowerETSI: false),
        FiveGHzBlock(primary: 100, range: 100...112, isDFS: true, isWeatherRadar: false, highPowerETSI: true),
        FiveGHzBlock(primary: 116, range: 116...128, isDFS: true, isWeatherRadar: true, highPowerETSI: true)
    ]

    public static func analyze(
        networks: [ScannedNetwork],
        lang: ResolvedLanguage = .en,
        timestamp: Date = .now
    ) -> RFScanResult {
        let fiveG = networks.filter { $0.band == .band5GHz }
        let twoG = networks.filter { $0.band == .band2GHz }

        let scores5 = fiveGHzBlocks.map { block -> ChannelScore in
            var overlapCount = 0
            var strongest: Int?

            for net in fiveG {
                let netRange = channelRange5GHz(primary: net.channel, widthMHz: net.channelWidthMHz)
                if netRange.overlaps(block.range) {
                    overlapCount += 1
                    if let rssi = net.rssi {
                        strongest = max(strongest ?? Int.min, rssi)
                    }
                }
            }

            // Lower score = better
            var penalty = Double(overlapCount) * 10.0
            if let strong = strongest, strong > -70 {
                penalty += Double(strong + 75) * 0.5
            }
            if block.highPowerETSI {
                penalty -= 2.5 // Bonus for 1000 mW ETSI power budget on ch 100+
            }
            if block.isWeatherRadar {
                penalty += 6.0 // Penalty for 10-min weather radar CAC in DE
            }

            let note: String
            if block.isWeatherRadar {
                note = L10n.t(.channelNoteWeatherDFS, lang: lang)
            } else if block.highPowerETSI {
                note = L10n.t(.channelNoteHighPowerDFS, lang: lang)
            } else if block.isDFS {
                note = L10n.t(.channelNoteDFS200, lang: lang)
            } else {
                note = L10n.t(.channelNoteNoDFS, lang: lang)
            }

            return ChannelScore(
                channel: block.primary,
                band: .band5GHz,
                overlappingAPCount: overlapCount,
                strongestInterfererRSSI: strongest,
                isDFS: block.isDFS,
                isWeatherRadarDFS: block.isWeatherRadar,
                score: penalty,
                note: note
            )
        }.sorted { $0.score < $1.score }

        let twoGCandidates = [1, 6, 11]
        let scores2 = twoGCandidates.map { candidate -> ChannelScore in
            var overlapCount = 0
            var strongest: Int?

            for net in twoG {
                let radius = net.channelWidthMHz >= 40 ? 6 : 3
                if abs(net.channel - candidate) <= radius {
                    overlapCount += 1
                    if let rssi = net.rssi {
                        strongest = max(strongest ?? Int.min, rssi)
                    }
                }
            }

            var penalty = Double(overlapCount) * 10.0
            if let strong = strongest, strong > -70 {
                penalty += Double(strong + 75) * 0.5
            }

            return ChannelScore(
                channel: candidate,
                band: .band2GHz,
                overlappingAPCount: overlapCount,
                strongestInterfererRSSI: strongest,
                isDFS: false,
                isWeatherRadarDFS: false,
                score: penalty,
                note: L10n.t(.channelNote20MHz, lang: lang)
            )
        }.sorted { $0.score < $1.score }

        return RFScanResult(
            totalNetworks: networks.count,
            recommended5GHz: scores5.first,
            recommended2GHz: scores2.first,
            scores5GHz: scores5,
            scores2GHz: scores2,
            timestamp: timestamp
        )
    }

    public static func channelRange5GHz(primary: Int, widthMHz: Int) -> ClosedRange<Int> {
        switch widthMHz {
        case 160:
            if (36...64).contains(primary) { return 36...64 }
            if (100...128).contains(primary) { return 100...128 }
            return primary...primary
        case 80:
            if (36...48).contains(primary) { return 36...48 }
            if (52...64).contains(primary) { return 52...64 }
            if (100...112).contains(primary) { return 100...112 }
            if (116...128).contains(primary) { return 116...128 }
            if (132...144).contains(primary) { return 132...144 }
            if (149...161).contains(primary) { return 149...161 }
            return primary...primary
        case 40:
            let base = primary - ((primary - 36) % 8)
            return base...(base + 4)
        default:
            return primary...primary
        }
    }
}

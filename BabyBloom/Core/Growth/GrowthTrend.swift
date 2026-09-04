import Foundation

/// Whether the baby is sliding down the chart, as opposed to sitting low on it.
///
/// A single percentile is a snapshot and a poor alarm: a baby can sit at the 9th
/// centile for a year in perfect health, while a baby falling from the 75th to
/// the 25th over two months is the one worth a look. What matters clinically is
/// sustained movement *across* centile spaces.
///
/// The CLINICAL question is downward-only, and stays that way: a fast climb is
/// not a faltering-growth concern and raises no flag. It is still reported,
/// because the alternative was to call it stability — see `crossingUp`.
///
/// Thresholds follow NICE faltering-growth guidance, which scales the trigger by
/// where the baby started: a fall of one centile space matters for a baby born
/// below the 9th centile, two for a baby born between the 9th and 91st, three
/// for a baby born above the 91st.
///
/// Ages take the **corrected** age for a baby born preterm.
enum GrowthTrend {

    /// One centile space on the standard chart lines (0.4th, 2nd, 9th, 25th,
    /// 50th, 75th, 91st, 98th, 99.6th) is two thirds of a standard deviation.
    /// Working in z rather than in percentile points keeps the spacing uniform —
    /// percentile points are compressed in the tails and would understate a fall
    /// exactly where it matters most.
    static let zPerCentileSpace = 2.0 / 3.0

    /// Enough history to tell a trend from a wobble.
    static let minimumMeasurements = 3
    static let minimumSpanDays = 28

    /// How far back the comparison's REFERENCES may reach, in days. It bounds
    /// the peak, the trough and the starting point — never the evidence gates,
    /// which read the whole history.
    ///
    /// Unbounded, the peak is the all-time maximum, and an ordinary regression
    /// to the mean becomes a PERMANENT flag: a baby that touched the 91st
    /// centile at two months and settled on the 50th by eighteen is measured
    /// against a peak a year in the past, and nothing it does afterwards can
    /// lower that peak or clear the drop. Six months is long enough to contain
    /// the fall NICE describes — weeks to months — and short enough that the
    /// comparison is still about where this baby is heading now.
    ///
    /// The cost is deliberate and worth naming: a fall slow enough to stay
    /// under two centile spaces inside every 180-day window is never reported,
    /// however far it travels over years. That is outside NICE's scope — its
    /// thresholds describe a fall over weeks to months — and catching it would
    /// mean reinstating the permanent flag this bound exists to remove. The
    /// number is a judgement rather than a published threshold; the owner may
    /// retune it.
    static let peakLookbackDays = 180

    /// A rise past this many centile spaces is named as a crossing rather than
    /// reported as stability.
    ///
    /// A flat two, deliberately not `thresholdSpaces`: the NICE scaling exists
    /// because a baby born small has less room to fall before it matters, and
    /// that argument has no upward counterpart. Two spaces is the middle rule,
    /// and the same distance a fall needs for a baby born mid-chart.
    static let upwardCrossingSpaces: Double = 2

    enum Assessment: Equatable {
        /// Fewer than three weighings, or less than four weeks of history.
        case insufficientData
        /// Neither a fall nor a rise past the threshold — the excursion is
        /// bounded in both directions, which is what makes the card's green
        /// tick a statement rather than a default.
        case stable
        /// Sustained fall, in centile spaces, past the threshold for this baby.
        case sustainedDrop(spaces: Double)
        /// Sustained rise past `upwardCrossingSpaces`. Not a concern and never
        /// styled as one; it exists because "holding its channel" is untrue of
        /// a baby climbing from the 50th to the 99th centile.
        case crossingUp(spaces: Double)
    }

    /// How many centile spaces of fall are meaningful for a baby that started at
    /// this birth percentile. Unknown birth weight — and any preterm baby, whose
    /// birth percentile cannot be read off a term chart — takes the middle rule.
    static func thresholdSpaces(birthPercentile: Double?) -> Double {
        guard let p = birthPercentile else { return 2 }
        if p < 9 { return 1 }
        if p > 91 { return 3 }
        return 2
    }

    /// Assesses the weight history. `birthPercentile` may be nil.
    static func assess(
        measurements: [WeightMeasurement],
        correctedBirthDate: Date,
        isMale: Bool,
        birthPercentile: Double?
    ) -> Assessment {
        // Every weighing the WHO tables can actually score, each keeping its own
        // date. The gates below are then evaluated on THIS array rather than on
        // the raw input: they ask whether there is enough evidence, and a
        // weighing the tables cannot score is not evidence. The old order gave
        // the right answer by accident, because the tables happen to cover the
        // whole age range the rest of the screen admits.
        let scored: [(date: Date, z: Double)] = measurements
            .sorted { $0.date < $1.date }
            .compactMap { m in
                let age = WHOGrowthStandard.correctedAgeDays(on: m.date,
                                                             correctedBirthDate: correctedBirthDate)
                guard let z = WHOGrowthStandard.zScore(weightKg: m.weightKg,
                                                       ageDays: age, isMale: isMale) else { return nil }
                return (m.date, z)
            }

        // EVIDENCE gates, on the whole scorable history. Whether this parent has
        // weighed enough to be told anything is a question about their whole
        // record, and it does not expire: a toddler weighed at 12, 15, 18 and 24
        // months has years of evidence and never two points inside six months.
        // Gating on the recent window instead left that child's card reading
        // "not enough data" permanently.
        guard scored.count >= minimumMeasurements,
              let oldest = scored.first,
              let newest = scored.last,
              days(from: oldest.date, to: newest.date) >= minimumSpanDays
        else { return .insufficientData }

        // REFERENCES, bounded to the recent window — see `peakLookbackDays`.
        // The gates decide whether to speak; this decides what the comparison is
        // measured against, and only the recent past can say where a baby is
        // heading now.
        //
        // Never fewer than the two most recent weighings, however far apart they
        // are: those two ARE the current trajectory, and a plain cutoff drops
        // one of them the moment a parent weighs twice more than six months
        // apart — a toddler seen at 18 and 24 months is 182 days, two over the
        // bound, and the card went dead. Reaching back for that one reading
        // cannot bring back the defect this window exists to remove, because
        // the reference then always sits among the two newest readings and the
        // next weighing replaces it; the I4 flag was unclearable precisely
        // because its peak was old and nothing newer could displace it.
        let cutoff = newest.date.addingTimeInterval(-Double(peakLookbackDays) * 86_400)
        let recent = scored.count >= 2 && scored[scored.count - 2].date < cutoff
            ? Array(scored.suffix(2))
            : scored.filter { $0.date >= cutoff }

        let scores = recent.map(\.z)
        let latest = newest.z
        let earlier = scores.dropLast()
        guard let peak = earlier.max(), let start = scores.first else {
            return .insufficientData
        }

        // A dip that has already recovered is not a downward trajectory, so the
        // latest reading has to be the lowest of the window for a fall to count.
        if latest <= (scores.min() ?? latest) {
            let spaces = (peak - latest) / zPerCentileSpace
            if spaces >= thresholdSpaces(birthPercentile: birthPercentile) {
                return .sustainedDrop(spaces: spaces)
            }
        } else {
            // The mirror, and the reason `.stable` can be trusted at all: this
            // detector used to return `.stable` for ANY non-fall, so a climb
            // from the 50th centile to the 99th was reported as "holding its
            // channel" with a green tick (build-11 review).
            //
            // Measured from where the baby STARTED in this window, not from its
            // lowest reading: a dip that has climbed back to its opening centile
            // has crossed nothing, and measuring from the trough would announce
            // a recovery as a rocket. The fall's peak-based rule is NICE's,
            // about position lost from the best the baby ever held, and does not
            // transfer to a direction nobody is worried about.
            //
            // No "latest is the highest" guard to match the fall's: the
            // from-start measurement already collapses a recovered dip to about
            // zero, and requiring the peak of the series handed the green tick
            // back to any baby whose last weighing wobbled a little below the
            // one before it — 50th to 97.5th, then a hundred grams light, and
            // the card said "holding its channel" again.
            let spaces = (latest - start) / zPerCentileSpace
            if spaces >= upwardCrossingSpaces {
                return .crossingUp(spaces: spaces)
            }
        }
        return .stable
    }

    private static func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

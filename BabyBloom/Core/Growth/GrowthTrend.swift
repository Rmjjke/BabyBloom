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
        let sorted = measurements.sorted { $0.date < $1.date }
        guard sorted.count >= minimumMeasurements,
              let first = sorted.first,
              let last = sorted.last,
              days(from: first.date, to: last.date) >= minimumSpanDays
        else { return .insufficientData }

        // Every weighing that the WHO tables can actually score.
        let scores: [Double] = sorted.compactMap { m in
            let age = max(0, days(from: correctedBirthDate, to: m.date))
            return WHOGrowthStandard.zScore(weightKg: m.weightKg, ageDays: age, isMale: isMale)
        }
        guard scores.count >= minimumMeasurements, let latest = scores.last else {
            return .insufficientData
        }

        let earlier = scores.dropLast()
        guard let peak = earlier.max(), let start = scores.first else {
            return .insufficientData
        }

        // A dip that has already recovered is not a downward trajectory, so the
        // latest reading has to be the lowest of the series for a fall to count.
        if latest <= (scores.min() ?? latest) {
            let spaces = (peak - latest) / zPerCentileSpace
            if spaces >= thresholdSpaces(birthPercentile: birthPercentile) {
                return .sustainedDrop(spaces: spaces)
            }
        } else if latest >= (scores.max() ?? latest) {
            // The mirror, and the reason `.stable` can be trusted at all: this
            // detector used to return `.stable` for ANY non-fall, so a climb
            // from the 50th centile to the 99th was reported as "holding its
            // channel" with a green tick (build-11 review).
            //
            // Measured from where the baby STARTED, not from the lowest reading
            // in between: a dip that has climbed back to its opening centile has
            // crossed nothing, and measuring it from the trough would announce a
            // recovery as a rocket. The fall's peak-based rule is NICE's, about
            // position lost from the best the baby ever held, and does not
            // transfer to a direction nobody is worried about.
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

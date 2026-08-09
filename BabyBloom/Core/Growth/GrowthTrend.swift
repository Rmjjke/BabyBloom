import Foundation

/// Whether the baby is sliding down the chart, as opposed to sitting low on it.
///
/// A single percentile is a snapshot and a poor alarm: a baby can sit at the 9th
/// centile for a year in perfect health, while a baby falling from the 75th to
/// the 25th over two months is the one worth a look. What matters clinically is
/// sustained movement *across* centile spaces.
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

    enum Assessment: Equatable {
        /// Fewer than three weighings, or less than four weeks of history.
        case insufficientData
        /// No sustained fall beyond this baby's threshold.
        case stable
        /// Sustained fall, in centile spaces, past the threshold for this baby.
        case sustainedDrop(spaces: Double)
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
        guard let peak = earlier.max() else { return .insufficientData }

        // A dip that has already recovered is not a downward trajectory, so the
        // latest reading has to be the lowest of the series for this to count.
        guard latest <= (scores.min() ?? latest) else { return .stable }

        let spaces = (peak - latest) / zPerCentileSpace
        guard spaces >= thresholdSpaces(birthPercentile: birthPercentile) else { return .stable }
        return .sustainedDrop(spaces: spaces)
    }

    private static func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

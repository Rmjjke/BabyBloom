import Foundation

/// The WHO weight-for-age corridor, sampled across an age window for drawing.
///
/// Every surface that draws the corridor — the Growth screen's weight chart and
/// onboarding's showcase sketch — samples it here, so the two cannot disagree
/// about where the 3rd centile runs. That matters more than it sounds: the
/// showcase page exists to show a parent what the Growth screen looks like, and
/// a preview drawn from a second sampler would be a picture of a product that
/// does not exist (DECISIONS 2026-09-21).
///
/// Pure, like everything else in `Core/Growth`: it takes ages in days and
/// returns weights in kg, and knows nothing about canvases or colours.
enum WHOCorridor {

    /// z for the 97th centile; the 3rd is its mirror. The band the app draws is
    /// the same 3–97 the percentile card's `beyond` tier is bounded by, so a
    /// point drawn outside the band and a reading labelled "< 3rd" always
    /// describe the same baby.
    static let tailZ = 1.8807936

    struct Sample: Equatable {
        let ageDays: Int
        /// 3rd centile.
        let low: Double
        /// 50th.
        let mid: Double
        /// 97th.
        let high: Double
    }

    /// Samples the corridor across an age window, or `[]` when the window lies
    /// entirely outside the tables.
    ///
    /// Two clamps, and both are the drawing face of rules the engine already
    /// holds:
    ///
    /// - **The band starts at age 0**, never before. A preterm baby weighed
    ///   before its corrected due date has no weight-for-age reference at all
    ///   (`WHOGrowthStandard.correctedAgeDaysIfBorn` returns nil for exactly
    ///   that case), so the chart must draw no band under those points rather
    ///   than extrapolate the term newborn curve backwards — which would put a
    ///   picture of "far below normal" under a baby in intensive care.
    /// - **The band stops at `maxAgeDays`.** Past two years the tables run out;
    ///   the chart stops shading rather than reusing the last row.
    ///
    /// - Parameter maxSamples: an upper bound on the returned count. The step
    ///   is derived from it, so a two-year window costs the same to draw as a
    ///   two-week one.
    static func samples(fromAgeDays: Int,
                        toAgeDays: Int,
                        isMale: Bool,
                        maxSamples: Int = 40) -> [Sample] {
        let lower = max(0, fromAgeDays)
        let upper = min(toAgeDays, WHOGrowthStandard.maxAgeDays)
        guard lower <= upper, maxSamples >= 2 else { return [] }

        let span = upper - lower
        let step = max(1, Int((Double(span) / Double(maxSamples - 1)).rounded(.up)))
        var ages = Array(stride(from: lower, through: upper, by: step))
        // The window's far edge is where the eye lands; a step that does not
        // divide the span evenly would otherwise leave the band short of it.
        if ages.last != upper { ages.append(upper) }

        return ages.compactMap { age in
            guard let low = WHOGrowthStandard.weight(atZ: -tailZ, ageDays: age, isMale: isMale),
                  let mid = WHOGrowthStandard.weight(atZ: 0, ageDays: age, isMale: isMale),
                  let high = WHOGrowthStandard.weight(atZ: tailZ, ageDays: age, isMale: isMale)
            else { return nil }
            return Sample(ageDays: age, low: low, mid: mid, high: high)
        }
    }
}

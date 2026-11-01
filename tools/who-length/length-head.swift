import Foundation

/// WHO Child Growth Standards 2006 — length-for-age, birth to 24 months.
///
/// Source: World Health Organization, "WHO Child Growth Standards:
/// length/height-for-age", expanded tables (LMS coefficients, one row per day):
/// https://www.who.int/tools/child-growth-standards/standards/length-height-for-age
/// (lhfa-boys- / lhfa-girls-percentiles-expanded-tables.xlsx). The rows were
/// generated from those files, not typed, and cross-checked row by row against
/// WHO's own anthro package (data-raw/growthstandards/lenanthro.txt): identical
/// for days 0–730, both sexes.
///
/// Every row up to 730 days is RECUMBENT length (anthro's `loh` = "L"); WHO
/// switches to standing height only after two years, which is past
/// `maxAgeDays`. The app's `GrowthEntry.heightCm` is therefore scored as
/// length with no lying/standing adjustment.
///
/// `l` is 1 on every row — length is normally distributed — so the z score is
/// simply (x / M − 1) / S. It still goes through the shared Box-Cox code path,
/// so weight and length can never disagree about the formula.
///
/// Stored on a denser grid than weight: every day for the first month, every
/// third day to six months, weekly to 24 months. The weight grid was tried
/// first and rejected — length's S is about a quarter of weight's, so the same
/// interpolation error in centimetres is a larger error in z, and at the median
/// (where one z moves the percentile most) it reached 0.31 of a percentile.
/// Measured against the full daily table this grid stays under 0.022 of a
/// percentile anywhere in −3…+3 z.
///
/// Ages are in days and, as for weight, the CORRECTED age for a preterm baby.
/// A caller scoring a measurement by its date takes the age from
/// `correctedAgeDaysIfBorn` (nil before term — never the clamped age, which
/// scores a preterm birth length against the term newborn curve), and a
/// surface that shows the number takes `PercentileReading`'s beyond-chart
/// honesty rather than a bare clamped "1" or "99".
extension WHOGrowthStandard {

    /// Interpolated length-for-age coefficients, or `nil` outside 0…730 days.
    static func lengthLMS(ageDays: Int, isMale: Bool) -> LMS? {
        lms(in: isMale ? lengthBoys : lengthGirls, ageDays: ageDays)
    }

    /// Standard deviations from the median length, or `nil` if the age is
    /// outside the table or the length is not a positive number.
    static func lengthZScore(lengthCm: Double, ageDays: Int, isMale: Bool) -> Double? {
        zScore(of: lengthCm, lms: lengthLMS(ageDays: ageDays, isMale: isMale))
    }

    /// The length sitting `z` standard deviations from the median at this age.
    static func length(atZ z: Double, ageDays: Int, isMale: Bool) -> Double? {
        value(atZ: z, lms: lengthLMS(ageDays: ageDays, isMale: isMale))
    }

    /// Length percentile, rounded and clamped to 1–99 like the weight one.
    static func lengthPercentile(lengthCm: Double, ageDays: Int, isMale: Bool) -> Double? {
        guard let z = lengthZScore(lengthCm: lengthCm, ageDays: ageDays, isMale: isMale) else {
            return nil
        }
        return percentile(fromZ: z)
    }

    // MARK: - WHO tables (generated, do not hand-edit)


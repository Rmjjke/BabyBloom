import XCTest
@testable import BabyBloom

/// Checks the LMS implementation against WHO's own published SD curves.
///
/// The reference weights below are transcribed from the same expanded z-score
/// tables the LMS coefficients come from, so this is a genuine external check:
/// if the formula, the transcription or the interpolation grid were wrong, the
/// published weight at −2 SD would not come back as −2.
final class WHOGrowthStandardTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LocalizationManager.shared.setLanguage("en")
    }

    /// (day, isMale, z, weight in kg) from WHO weight-for-age expanded tables.
    /// Days 0, 365 and 730 are exact rows of the stored grid; 45 and 180 fall
    /// between stored nodes and therefore exercise the interpolation.
    private static let reference: [(day: Int, male: Bool, z: Double, kg: Double)] = [
        (0,   true,  -3, 2.080), (0,   true,  -2, 2.459), (0,   true,  0, 3.346), (0,   true,  2, 4.419),
        (45,  true,  -3, 3.370), (45,  true,  -2, 3.869), (45,  true,  0, 5.040), (45,  true,  2, 6.475),
        (180, true,  -3, 5.646), (180, true,  -2, 6.325), (180, true,  0, 7.900), (180, true,  2, 9.808),
        (365, true,  -3, 6.926), (365, true,  -2, 7.741), (365, true,  0, 9.646), (365, true,  2, 11.983),
        (730, true,  -3, 8.630), (730, true,  -2, 9.670), (730, true,  0, 12.148), (730, true, 2, 15.272),
        (0,   false, -3, 2.033), (0,   false, -2, 2.395), (0,   false, 0, 3.232), (0,   false, 2, 4.230),
        (45,  false, -3, 3.100), (45,  false, -2, 3.564), (45,  false, 0, 4.674), (45,  false, 2, 6.072),
        (180, false, -3, 5.061), (180, false, -2, 5.703), (180, false, 0, 7.265), (180, false, 2, 9.295),
        (365, false, -3, 6.273), (365, false, -2, 7.041), (365, false, 0, 8.946), (365, false, 2, 11.506),
        (730, false, -3, 8.064), (730, false, -2, 9.033), (730, false, 0, 11.474), (730, false, 2, 14.841)
    ]

    func testZScoresMatchPublishedWHOCurves() {
        for point in Self.reference {
            guard let z = WHOGrowthStandard.zScore(
                weightKg: point.kg, ageDays: point.day, isMale: point.male
            ) else {
                return XCTFail("no z-score for day \(point.day), male=\(point.male)")
            }
            // Published weights are rounded to 3 decimals, and ages between grid
            // nodes carry up to 0.008 z of interpolation error by design.
            XCTAssertEqual(z, point.z, accuracy: 0.02,
                           "day \(point.day), male=\(point.male), expected z=\(point.z)")
        }
    }

    func testMedianWeightIsExactlyTheFiftiethPercentile() {
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: 3.346, ageDays: 0, isMale: true), 50)
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: 8.946, ageDays: 365, isMale: false), 50)
    }

    // MARK: - Range

    /// Past 24 months the answer is "no data", not the last row of the table.
    /// The old implementation clamped instead, quietly reporting a two-year-old
    /// reference for a five-year-old.
    func testAgesOutsideTheTablesReturnNil() {
        XCTAssertNil(WHOGrowthStandard.zScore(weightKg: 13, ageDays: 731, isMale: true))
        XCTAssertNil(WHOGrowthStandard.zScore(weightKg: 13, ageDays: -1, isMale: true))
        XCTAssertNotNil(WHOGrowthStandard.zScore(weightKg: 13, ageDays: 730, isMale: true))
        XCTAssertEqual(WHOGrowthStandard.maxAgeDays, 730)
    }

    func testNonPositiveWeightReturnsNil() {
        XCTAssertNil(WHOGrowthStandard.zScore(weightKg: 0, ageDays: 30, isMale: true))
        XCTAssertNil(WHOGrowthStandard.zScore(weightKg: -1, ageDays: 30, isMale: true))
    }

    // MARK: - Interpolation

    /// Between two stored nodes the median must move smoothly and monotonically;
    /// a flat or jumping stretch would mean the interpolation is not running.
    func testMedianGrowsMonotonicallyAcrossNodeBoundaries() {
        var previous = 0.0
        for day in 40...60 {
            guard let lms = WHOGrowthStandard.lms(ageDays: day, isMale: true) else {
                return XCTFail("no coefficients for day \(day)")
            }
            XCTAssertGreaterThan(lms.m, previous, "median should increase at day \(day)")
            previous = lms.m
        }
    }

    /// Day 2 is where L and M move fastest — the reason the grid stores every
    /// day for the first month instead of interpolating across a week.
    func testFirstDaysAreStoredNotInterpolated() {
        let day1 = WHOGrowthStandard.lms(ageDays: 1, isMale: false)
        let day2 = WHOGrowthStandard.lms(ageDays: 2, isMale: false)
        XCTAssertNotNil(day1)
        XCTAssertNotNil(day2)
        XCTAssertNotEqual(day1?.l, day2?.l)
    }

    // MARK: - Presentation

    func testPercentileIsClampedToTheDisplayRange() {
        // Absurd weights must not produce 0 or 100.
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: 0.5, ageDays: 365, isMale: true), 1)
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: 30, ageDays: 365, isMale: true), 99)
    }

    /// Labels and colors must switch at the same 3 / 15 / 50 / 85 / 97 boundaries,
    /// otherwise a reading can read "normal" while showing red.
    func testLabelAndColorBoundariesAgree() {
        let green = "#6BBF6B", orange = "#F5A45F", red = "#E05A5A"
        XCTAssertEqual(WHOGrowthStandard.percentileColor(2), red)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(3), orange)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(15), orange)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(16), green)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(85), green)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(86), orange)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(97), orange)
        XCTAssertEqual(WHOGrowthStandard.percentileColor(98), red)

        XCTAssertEqual(WHOGrowthStandard.percentileLabel(50), "percentile.15_50".l)
        XCTAssertEqual(WHOGrowthStandard.percentileLabel(51), "percentile.50_85".l)
    }

    // MARK: - Scored at the weighing, not at the calendar

    /// A day-30 weighing on the day-30 median is the 50th centile, and stays the
    /// 50th centile however long the app goes unopened afterwards. Scored against
    /// TODAY'S age instead, the same entry slid downward every morning — movement
    /// the parent did nothing to cause.
    func testAWeighingKeepsItsPercentileHoweverStaleItGets() throws {
        let medianDay30 = 4.452
        for daysSince in [0, 1, 30, 200] {
            let today = Date()
            let birth = Calendar.current.date(byAdding: .day, value: -(30 + daysSince), to: today)!
            let weighed = Calendar.current.date(byAdding: .day, value: 30, to: birth)!
            let p = try XCTUnwrap(WHOGrowthStandard.percentile(
                of: WeightMeasurement(date: weighed, weightKg: medianDay30),
                correctedBirthDate: birth,
                isMale: true
            ))
            XCTAssertEqual(p, 50, "opened \(daysSince) days after the weighing")
        }
    }

    /// Corrected age still selects the reference, now measured to the weighing
    /// date rather than to today — the prematurity rule survives the fix.
    func testTheAgeIsMeasuredFromTheCorrectedBirthDate() {
        let today = Date()
        let birth = Calendar.current.date(byAdding: .day, value: -100, to: today)!
        let corrected = Calendar.current.date(byAdding: .day, value: 56, to: birth)!
        let weighed = Calendar.current.date(byAdding: .day, value: 90, to: birth)!

        XCTAssertEqual(WHOGrowthStandard.correctedAgeDays(on: weighed, correctedBirthDate: birth), 90)
        XCTAssertEqual(WHOGrowthStandard.correctedAgeDays(on: weighed, correctedBirthDate: corrected), 34)
        // A weighing taken before the corrected birth date is age zero, never
        // negative — the same floor `Baby.correctedAgeDays` holds.
        XCTAssertEqual(WHOGrowthStandard.correctedAgeDays(on: birth, correctedBirthDate: corrected), 0)
    }

    // MARK: - The badge is honest at the edge of the chart

    /// The owner's repro: a weight so far above the chart that the percentile is
    /// 100 before the clamp. "99" beside the band label "> 97th" reads as a
    /// measured figure; it is the clamp talking.
    func testTheBadgeStopsPretendingToPrecisionPastTheClamp() throws {
        let birth = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let weighed = Calendar.current.date(byAdding: .day, value: 30, to: birth)!

        let offChart = try XCTUnwrap(WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: weighed, weightKg: 20.0),
            correctedBirthDate: birth, isMale: true))
        XCTAssertEqual(offChart.percentile, 99, "the ring still draws the clamped value")
        XCTAssertEqual(offChart.badge, "percentile.badge_above97".l)
        XCTAssertEqual(WHOGrowthStandard.percentileLabel(offChart.percentile),
                       "percentile.above97".l, "badge and band label must agree")

        // The bottom edge, symmetrically.
        let underChart = try XCTUnwrap(WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: weighed, weightKg: 1.5),
            correctedBirthDate: birth, isMale: true))
        XCTAssertEqual(underChart.badge, "percentile.badge_below3".l)
    }

    /// The sentence-shaped surfaces get the same honesty as the ring.
    ///
    /// The Dashboard renders "%d percentile" and kept printing "99-й перцентиль"
    /// at the clamp while the Growth screen beside it already said "> 97-го" —
    /// two surfaces, one weighing, two different claims about its precision.
    func testTheDashboardRowIsAsHonestAsTheRingBadge() throws {
        let birth = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let weighed = Calendar.current.date(byAdding: .day, value: 30, to: birth)!
        let format = "%d percentile"

        let offChart = try XCTUnwrap(WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: weighed, weightKg: 20.0),
            correctedBirthDate: birth, isMale: true))
        XCTAssertTrue(offChart.isBeyondChart)
        XCTAssertEqual(offChart.rowText(format: format), "percentile.above97".l,
                       "past the clamp the row borrows the band label, as the card does")

        let ordinary = try XCTUnwrap(WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: weighed, weightKg: 4.452),
            correctedBirthDate: birth, isMale: true))
        XCTAssertFalse(ordinary.isBeyondChart)
        XCTAssertEqual(ordinary.rowText(format: format), "50 percentile")
    }

    /// Everywhere the tables actually measure something, the badge is the
    /// number — the honest edge must not swallow ordinary readings.
    func testAnOrdinaryReadingKeepsItsNumber() throws {
        let birth = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let weighed = Calendar.current.date(byAdding: .day, value: 30, to: birth)!
        let reading = try XCTUnwrap(WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: weighed, weightKg: 4.452),
            correctedBirthDate: birth, isMale: true))
        XCTAssertEqual(reading.percentile, 50)
        XCTAssertEqual(reading.badge, "50")
    }

    // MARK: - The newest WEIGHING, not the newest entry

    /// A height-only entry recorded this morning is newer than every weighing and
    /// says nothing about weight. Reading the raw newest entry printed "0.00 kg"
    /// on the Dashboard and made the Growth screen's percentile card vanish.
    func testAHeightOnlyEntryDoesNotHideTheLastWeighing() throws {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            GrowthEntry(date: today, weightKg: nil, heightCm: 60.0),
            GrowthEntry(date: yesterday, weightKg: 5.2, heightCm: nil)
        ]
        let weighing = try XCTUnwrap(entries.latestWeighing)
        XCTAssertEqual(weighing.weightKg, 5.2)
        XCTAssertEqual(weighing.date, yesterday)
    }

    func testNoWeighingAtAllStaysNil() {
        XCTAssertNil([GrowthEntry(date: Date(), weightKg: nil, heightCm: 60.0)].latestWeighing)
        XCTAssertNil([GrowthEntry]().latestWeighing)
    }
}

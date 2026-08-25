import XCTest
@testable import BabyBloom

final class FeedingAdequacyTests: XCTestCase {

    // MARK: - Feeding frequency reference

    func testFeedingReferenceNarrowsWithAge() {
        let newborn = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .breast)
        let older   = FeedingAdequacy.feedingReference(correctedAgeDays: 150, style: .breast)
        XCTAssertEqual(newborn, 8...12)
        XCTAssertEqual(older, 5...7)
    }

    func testFormulaFedBabiesAreHeldToALowerFrequency() {
        // A formula-fed newborn genuinely feeds less often; one table for both
        // would flag healthy babies.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .formula), 6...8)
    }

    /// The rows change on an exact day, so both sides of every seam are pinned:
    /// a `<` where `<=` belongs would otherwise shift a whole band by a day and
    /// still leave the suite green.
    func testEachAgeBandStartsOnTheDayTheTableSays() {
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 27, style: .breast), 8...12)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 28, style: .breast), 7...9)

        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 119, style: .formula), 5...7)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 120, style: .formula), 4...6)
    }

    func testMixedFeedingUsesTheUnionOfBothBands() {
        // Neither table fully applies, so the stricter edge of each must not bite.
        let mixed = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .mixed)
        XCTAssertEqual(mixed, 6...12)
    }

    /// The union has to hold on every row, not just the newborn one — each row
    /// pairs different bands and so produces a different union.
    func testMixedFeedingUnionHoldsOnTheLaterRowsToo() {
        // 7...9 with 5...7.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 28, style: .mixed), 5...9)
        // 5...7 with 4...6.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 150, style: .mixed), 4...7)
    }

    func testFeedingReferenceIsNilPastSixMonths() {
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 200, style: .breast))
    }

    /// The feature is meant to cover the whole of 0–6 months and stop the day
    /// after. An off-by-one in the age guard would quietly cut it short.
    func testFeedingReferenceCoversTheLastCoveredDayAndStopsTheDayAfter() {
        XCTAssertEqual(FeedingAdequacy.maxAgeDays, 183)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 183, style: .breast), 5...7)
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 184, style: .breast))
    }

    // MARK: - Wet nappy reference

    /// The charted ramp is not simply "the day number": it flattens at 3, so
    /// day 4 expects 3, the same as day 3.
    func testWetNappyMinimumFollowsTheChartedRampInTheFirstDays() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 1), 1)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 2), 2)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 3), 3)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 4), 3)
    }

    func testWetNappyMinimumIsSixFromDayFive() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 5), 6)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 90), 6)
    }

    /// A reference of zero would read as "none expected", which is never true.
    func testWetNappyMinimumIsNeverZeroOnTheDayOfBirth() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 0), 1)
    }

    // MARK: - Window

    /// A fixed instant in a fixed calendar for the whole test case.
    ///
    /// `Date()` advances between calls, so a window anchored on one call sits
    /// microseconds before an entry anchored on a later one and silently drops
    /// it. The device calendar adds a second trap: a daylight-saving transition
    /// inside the window changes its duration by an hour, which moves every
    /// per-day figure the tests assert on — twice a year, on some devices only.
    /// A UTC calendar and a fixed date remove both.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let now = FeedingAdequacyTests.calendar.date(
        from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!

    private func day(_ offset: Int) -> Date {
        Self.calendar.date(byAdding: .day, value: offset, to: now)!
    }

    private func hours(_ offset: Int) -> Date {
        Self.calendar.date(byAdding: .hour, value: offset, to: now)!
    }

    func testWindowSpansTheTwoMostRecentWeighings() throws {
        let measurements = [
            WeightMeasurement(date: day(-30), weightKg: 3.4),
            WeightMeasurement(date: day(-9),  weightKg: 4.0),
            WeightMeasurement(date: day(0),   weightKg: 4.3),
        ]
        let window = FeedingAdequacy.window(for: measurements)
        // The older weighing is history; the assessment covers the latest gap.
        XCTAssertEqual(Self.calendar.dateComponents([.day],
                                                    from: try XCTUnwrap(window).start,
                                                    to: try XCTUnwrap(window).end).day, 9)
    }

    func testWindowIsNilWithFewerThanTwoWeighings() {
        XCTAssertNil(FeedingAdequacy.window(for: [WeightMeasurement(date: day(0), weightKg: 4.0)]))
        XCTAssertNil(FeedingAdequacy.window(for: []))
    }

    /// Two weighings recorded at the same instant leave no interval to count
    /// over; a zero-length window would divide every rate by a floor of one day
    /// and report a made-up figure rather than nothing.
    func testWindowIsNilWhenTheTwoLatestWeighingsShareAnInstant() {
        let sameMoment = day(0)
        XCTAssertNil(FeedingAdequacy.window(for: [
            WeightMeasurement(date: sameMoment, weightKg: 4.0),
            WeightMeasurement(date: sameMoment, weightKg: 4.1),
        ]))
    }

    /// Below a full day there is nothing "per day" can honestly mean: both
    /// counters floor their denominator at one day, so a part-day window would
    /// report a fraction of the real feeding rate and score full coverage off a
    /// single logged day. The boundary is pinned from both sides.
    func testWindowIsNilWhenTheWeighingsAreLessThanADayApart() {
        XCTAssertNil(FeedingAdequacy.window(for: [
            WeightMeasurement(date: hours(-23), weightKg: 4.00),
            WeightMeasurement(date: day(0),     weightKg: 4.05),
        ]))

        let exactlyOneDay = FeedingAdequacy.window(for: [
            WeightMeasurement(date: day(-1), weightKg: 4.00),
            WeightMeasurement(date: day(0),  weightKg: 4.05),
        ])
        XCTAssertEqual(exactlyOneDay?.duration, 86_400)
    }

    // MARK: - Feeding style from the logs

    func testStyleIsBreastWhenAlmostAllFeedsAreBreast() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 == 0 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .breast)
    }

    func testStyleIsFormulaWhenPumpedAndFormulaDominate() {
        // Pumped milk is given by bottle on a formula-like schedule, so it
        // counts with formula for frequency purposes.
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .formula : .pumped) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .formula)
    }

    func testStyleIsMixedWhenNeitherDominates() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .mixed)
    }

    func testStyleOfNothingIsMixed() {
        // With no evidence, take the widest reference rather than guessing.
        XCTAssertEqual(FeedingAdequacy.style(of: []), .mixed)
    }

    /// The dominance threshold decides which reference column a baby is judged
    /// against, so the exact share it turns on is pinned from both sides: a
    /// `>` where `>=` belongs would push a whole class of babies onto the wider
    /// mixed band and still leave the suite green.
    func testStyleTreatsTheDominanceShareAsInclusive() {
        let eightBreast = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 8 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: eightBreast), .breast)

        let sevenBreast = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 7 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: sevenBreast), .mixed)

        let eightBottle = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 8 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: eightBottle), .formula)

        let sevenBottle = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 7 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: sevenBottle), .mixed)
    }

    // MARK: - Rate and coverage

    func testRateIsPerDayOverTheWindow() {
        let window = DateInterval(start: day(-10), end: day(0))
        let dates = (0..<20).map { day(-$0 / 2) }
        XCTAssertEqual(FeedingAdequacy.rate(of: dates, in: window), 2.0, accuracy: 0.01)

        // Feeds from before the window belong to an earlier gap, and one logged
        // ahead of the last weighing belongs to no gap yet. Counting either
        // would put a feeding figure beside a gain measured over other days —
        // the one thing the shared window exists to prevent.
        let withEntriesOutsideTheWindow = dates + [day(-20), day(-11), day(20)]
        XCTAssertEqual(FeedingAdequacy.rate(of: withEntriesOutsideTheWindow, in: window),
                       2.0, accuracy: 0.01)
    }

    func testCoverageFailsWhenMostDaysHaveNoEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        // Ten entries, all on one day: plenty of records, almost no coverage.
        let clustered = Array(repeating: day(-1), count: 10)
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(clustered, in: window))
    }

    func testCoveragePassesWhenMostDaysHaveAnEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        let spread = (0...10).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(spread, in: window))
    }

    /// Coverage is the line between reporting a figure and reporting
    /// `notEnoughData`, so the exact fraction it turns on is pinned from both
    /// sides rather than only sampled well away from it.
    func testCoverageHoldsAtExactlyHalfTheDaysAndFailsJustBelow() {
        let window = DateInterval(start: day(-10), end: day(0))

        let halfTheDays = (0..<5).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(halfTheDays, in: window))

        let oneDayShort = (0..<4).map { day(-$0) }
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(oneDayShort, in: window))
    }

    /// The same exclusion, on the other counter: a parent who logged diligently
    /// a fortnight ago and barely since has no coverage of THIS gap.
    func testCoverageIgnoresDaysLoggedOutsideTheWindow() {
        let window = DateInterval(start: day(-10), end: day(0))
        let oneDayInsideAndSixBefore = [day(-1)] + (11...16).map { day(-$0) }
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(oneDayInsideAndSixBefore, in: window))
    }

    /// The pairing every caller depends on: an empty log rates as zero, and that
    /// zero is only ever safe to show because coverage refuses it first. An
    /// unlogged window is unknown, never "no feeds".
    func testAnEmptyLogRatesAsZeroAndHasNoCoverage() {
        let window = DateInterval(start: day(-10), end: day(0))
        XCTAssertEqual(FeedingAdequacy.rate(of: [], in: window), 0)
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage([], in: window))
    }
}

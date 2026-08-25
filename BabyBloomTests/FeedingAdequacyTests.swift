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
}

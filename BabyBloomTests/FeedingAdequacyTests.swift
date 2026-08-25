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

    func testMixedFeedingUsesTheUnionOfBothBands() {
        // Neither table fully applies, so the stricter edge of each must not bite.
        let mixed = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .mixed)
        XCTAssertEqual(mixed, 6...12)
    }

    func testFeedingReferenceIsNilPastSixMonths() {
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 200, style: .breast))
    }

    // MARK: - Wet nappy reference

    func testWetNappyMinimumRampsWithTheDayNumberInTheFirstDays() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 1), 1)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 3), 3)
    }

    func testWetNappyMinimumIsSixFromDayFive() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 5), 6)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 90), 6)
    }
}

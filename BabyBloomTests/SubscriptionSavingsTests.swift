import XCTest
@testable import BabyBloom

/// The savings badge is computed from the prices the App Store returns, never
/// from constants — a price changed in App Store Connect must move the badge
/// with it. These pin the arithmetic against the figures the pricing decision
/// was actually made on, so a regression shows up as a wrong percentage rather
/// than as a screen quietly advertising a discount it does not give.
final class SubscriptionSavingsTests: XCTestCase {

    private typealias Manager = SubscriptionManager

    // MARK: - The shipped ladder

    func testYearlyReadsAsFiftyTwoPercentOffMonthly() {
        // $39.99/year against $6.99/month ($83.88/year).
        XCTAssertEqual(
            Manager.savingsPercent(of: 39.99, per: .year, count: 1,
                                   comparedTo: 6.99, per: .month, count: 1),
            52
        )
    }

    func testYearlyReadsAsSeventyFourPercentOffWeekly() {
        // $39.99/year against $2.99/week ($155.48/year).
        XCTAssertEqual(
            Manager.savingsPercent(of: 39.99, per: .year, count: 1,
                                   comparedTo: 2.99, per: .week, count: 1),
            74
        )
    }

    /// The reason the monthly price moved. At $4.99 the yearly plan saved only
    /// a third, which is not enough to move anyone onto a year; this documents
    /// the number the decision was made against.
    func testTheOldMonthlyPriceOnlyGaveAThirdOff() {
        XCTAssertEqual(
            Manager.savingsPercent(of: 39.99, per: .year, count: 1,
                                   comparedTo: 4.99, per: .month, count: 1),
            33
        )
    }

    // MARK: - Refusals

    func testNoBadgeWhenThePlanIsNotCheaper() {
        // A badge is only ever a saving; a negative one would read as a surcharge.
        XCTAssertNil(Manager.savingsPercent(of: 6.99, per: .month, count: 1,
                                            comparedTo: 39.99, per: .year, count: 1))
    }

    func testNoBadgeWhenThePlansCostTheSame() {
        XCTAssertNil(Manager.savingsPercent(of: 12.00, per: .year, count: 1,
                                            comparedTo: 1.00, per: .month, count: 1))
    }

    func testNoBadgeForANonPositivePeriod() {
        XCTAssertNil(Manager.savingsPercent(of: 39.99, per: .year, count: 0,
                                            comparedTo: 6.99, per: .month, count: 1))
        XCTAssertNil(Manager.savingsPercent(of: 39.99, per: .year, count: 1,
                                            comparedTo: 6.99, per: .month, count: 0))
    }

    // MARK: - Multi-unit periods

    func testAMultiUnitPeriodIsNormalisedByItsCount() {
        // A hypothetical 6-month plan at $30 is $60/year, so a $39.99 year saves 33%.
        XCTAssertEqual(Manager.annualizedPrice(30.00, per: .month, count: 6), 60)
        XCTAssertEqual(
            Manager.savingsPercent(of: 39.99, per: .year, count: 1,
                                   comparedTo: 30.00, per: .month, count: 6),
            33
        )
    }
}

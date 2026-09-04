import XCTest
@testable import BabyBloom

final class GrowthTrendTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -200, to: Date())!

    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    private func assess(_ measurements: [WeightMeasurement], birthPercentile: Double? = 50) -> GrowthTrend.Assessment {
        GrowthTrend.assess(
            measurements: measurements,
            correctedBirthDate: birth,
            isMale: true,
            birthPercentile: birthPercentile
        )
    }

    // WHO weight-for-age reference weights for boys, from the published tables.
    private let medianDay30 = 4.452, medianDay60 = 5.541, medianDay90 = 6.346, medianDay120 = 6.970
    private let minus1SDDay120 = 6.217
    private let minus2SDDay90 = 4.992, minus2SDDay120 = 5.533
    private let plus2SDDay120 = 8.616

    // MARK: - Not enough to say anything

    func testTwoWeighingsAreNotATrend() {
        XCTAssertEqual(assess([at(30, medianDay30), at(120, medianDay120)]), .insufficientData)
    }

    /// Three weighings inside a fortnight describe noise, not a trajectory.
    func testShortSpanIsNotATrend() {
        let m = [at(90, 6.3), at(97, 6.2), at(110, 6.1)]
        XCTAssertEqual(assess(m), .insufficientData)
    }

    // MARK: - Stable

    /// A baby tracking along the median stays put, however many times it is weighed.
    func testTrackingTheMedianIsStable() {
        let m = [at(30, medianDay30), at(60, medianDay60), at(90, medianDay90), at(120, medianDay120)]
        XCTAssertEqual(assess(m), .stable)
    }

    /// Sitting low is not the same as falling: a baby steady at −2 SD never
    /// crosses anything and must not trigger.
    func testSteadyLowChannelIsStable() {
        let m = [at(90, minus2SDDay90), at(120, minus2SDDay120), at(150, 5.981)]
        XCTAssertEqual(assess(m), .stable)
    }

    /// A dip that has recovered is not a downward trajectory. Without this the
    /// app would alarm a parent about something already over.
    func testDipFollowedByRecoveryIsStable() {
        let m = [at(30, medianDay30), at(90, minus2SDDay90), at(120, medianDay120)]
        XCTAssertEqual(assess(m), .stable)
    }

    // MARK: - Upward crossing

    /// The build-11 report, in one fixture: a baby tracking the median climbs to
    /// the top of the chart, and the card said "Holding its centile channel"
    /// with a green tick. Downward-only is a defensible clinical scope; calling
    /// a rocket stability is not.
    func testARapidUpwardCrossingIsNotReportedAsHoldingTheChannel() throws {
        let m = [at(30, medianDay30), at(60, medianDay60), at(120, plus2SDDay120)]
        guard case let .crossingUp(spaces) = assess(m) else {
            return XCTFail("expected an upward crossing, got \(assess(m))")
        }
        XCTAssertGreaterThanOrEqual(spaces, GrowthTrend.upwardCrossingSpaces)
        XCTAssertEqual(spaces, 3, accuracy: 0.4)
    }

    /// An upward crossing is never a flag, whatever the birth centile: the NICE
    /// scaling is about how far a baby can afford to FALL and has no business
    /// deciding this. Same data, same verdict, both ends of the scale.
    func testTheUpwardThresholdDoesNotScaleWithBirthCentile() {
        let m = [at(30, medianDay30), at(60, medianDay60), at(120, plus2SDDay120)]
        XCTAssertEqual(assess(m, birthPercentile: 5), assess(m, birthPercentile: 95))
    }

    /// A rise inside the threshold is still stability — the new case must not
    /// turn every good week into an announcement.
    func testAModestRiseIsStillStable() {
        let m = [at(30, medianDay30), at(60, medianDay60), at(120, 7.3)]
        XCTAssertEqual(assess(m), .stable)
    }

    // MARK: - Sustained drop

    /// Median at day 30 down to −2 SD at day 120 is three centile spaces, past
    /// the two-space rule for a baby born mid-chart.
    func testFallOfThreeSpacesIsReported() throws {
        let m = [at(30, medianDay30), at(90, medianDay90), at(120, minus2SDDay120)]
        guard case let .sustainedDrop(spaces) = assess(m) else {
            return XCTFail("expected a sustained drop, got \(assess(m))")
        }
        XCTAssertEqual(spaces, 3, accuracy: 0.15)
    }

    // MARK: - NICE thresholds scale with birth centile

    func testThresholdDependsOnBirthCentile() {
        XCTAssertEqual(GrowthTrend.thresholdSpaces(birthPercentile: 5), 1)
        XCTAssertEqual(GrowthTrend.thresholdSpaces(birthPercentile: 50), 2)
        XCTAssertEqual(GrowthTrend.thresholdSpaces(birthPercentile: 95), 3)
    }

    /// Unknown birth weight — and every preterm baby, whose birth centile cannot
    /// be read off a term chart — falls back to the middle rule.
    func testUnknownBirthCentileUsesTheMiddleRule() {
        XCTAssertEqual(GrowthTrend.thresholdSpaces(birthPercentile: nil), 2)
    }

    /// The same 1.5-space fall is a signal for a baby born small and not yet one
    /// for a baby born mid-chart. Identical data, different verdict — that is the
    /// whole point of the NICE scaling.
    func testSameFallIsJudgedAgainstWhereTheBabyStarted() {
        let m = [at(30, medianDay30), at(90, medianDay90), at(120, minus1SDDay120)]

        guard case let .sustainedDrop(spaces) = assess(m, birthPercentile: 5) else {
            return XCTFail("a baby born below the 9th centile should trigger on one space")
        }
        XCTAssertEqual(spaces, 1.5, accuracy: 0.2)

        XCTAssertEqual(assess(m, birthPercentile: 50), .stable)
    }
}

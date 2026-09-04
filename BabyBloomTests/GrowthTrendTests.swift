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

    /// One wobbly last weighing must not hand the green tick back.
    ///
    /// The baby climbed from the median to the 97.5th centile and stayed there;
    /// the next weighing came in a hundred grams light. A "latest is the highest
    /// of the series" guard — the mirror of the fall's — read that dip as "no
    /// longer rising" and returned `.stable`, which claims the channel is being
    /// held by a baby two and a half spaces above where it started. The
    /// from-start measurement is the whole rule; nothing else is needed.
    func testAWobbleAtTheTopDoesNotRestoreTheGreenTick() throws {
        let m = [at(30, medianDay30), at(60, medianDay60), at(120, plus2SDDay120), at(150, 8.85)]

        // The fixture only means what it claims if the last reading really is
        // below the one before it and still far above the start.
        let z120 = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: plus2SDDay120, ageDays: 120, isMale: true))
        let z150 = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: 8.85, ageDays: 150, isMale: true))
        XCTAssertLessThan(z150, z120, "the last weighing must be a dip, or this tests nothing")
        XCTAssertGreaterThan(z150, 1.3, "and must still sit well above the median it started at")

        guard case let .crossingUp(spaces) = assess(m) else {
            return XCTFail("a wobble at the top is still a crossing, got \(assess(m))")
        }
        XCTAssertGreaterThanOrEqual(spaces, GrowthTrend.upwardCrossingSpaces)
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

    // MARK: - The peak is recent, or it is not a peak

    private func onOldTimeline(_ birth: Date, _ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    /// Regression to the mean must not raise a flag that can never clear.
    ///
    /// A baby high on the chart at one month, ordinary at ten and thirteen:
    /// measured against an all-time peak the fall from month one is measured
    /// forever, and no weighing the parent takes afterwards can lower it. The
    /// peak is bounded to the recent window, where this baby is simply tracking
    /// its channel — so the honest verdict is `.stable`, and the card keeps
    /// working. Not `.insufficientData`: there are years of evidence here, and
    /// the gates read all of it.
    func testAnAncientPeakDoesNotFlagAnOrdinaryEighteenMonthOld() {
        let old = Calendar.current.date(byAdding: .day, value: -420, to: Date())!
        let m = [onOldTimeline(old, 30, 5.7), onOldTimeline(old, 300, 9.2), onOldTimeline(old, 400, 10.4)]
        XCTAssertEqual(GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 50), .stable)
    }

    /// The toddler case the bound must not break: weighed at 12, 15, 18 and 24
    /// months, with the last gap 182 days — two days past the lookback. Gating
    /// the EVIDENCE on the recent window made this card read "not enough data"
    /// permanently for a parent with two years of records, and a plain cutoff
    /// left the comparison with nothing to measure against.
    func testATwiceYearlyToddlerStillGetsAVerdict() {
        let old = Calendar.current.date(byAdding: .day, value: -740, to: Date())!
        // WHO boys medians at roughly 12, 15, 18 and 24 months.
        let m = [onOldTimeline(old, 365, 9.65), onOldTimeline(old, 456, 10.6),
                 onOldTimeline(old, 548, 11.3), onOldTimeline(old, 730, 12.15)]
        XCTAssertNotEqual(GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                             isMale: true, birthPercentile: 50),
                          .insufficientData)
    }

    /// The bound's deliberate blind spot, pinned so it is a choice and not a
    /// surprise: a fall slow enough to stay under two centile spaces inside
    /// every 180-day window is never reported, however far it travels. NICE's
    /// thresholds describe a fall over weeks to months; catching this one would
    /// mean restoring the permanent flag the bound exists to remove.
    func testASlowFallSpreadOverYearsIsDeliberatelyNotReported() throws {
        let old = Calendar.current.date(byAdding: .day, value: -420, to: Date())!
        let m = [onOldTimeline(old, 60, 6.2), onOldTimeline(old, 250, 8.3),
                 onOldTimeline(old, 320, 8.7), onOldTimeline(old, 400, 9.3)]

        // Unbounded, this WOULD have flagged — which is what makes the verdict
        // below a consequence of the bound rather than of a gentle fixture.
        let zFirst = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: 6.2, ageDays: 60, isMale: true))
        let zLast = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: 9.3, ageDays: 400, isMale: true))
        XCTAssertGreaterThanOrEqual((zFirst - zLast) / GrowthTrend.zPerCentileSpace, 2,
                                    "the whole-history fall must exceed the threshold")

        XCTAssertEqual(GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 50), .stable)
    }

    /// The bound cuts references, not verdicts: a fall that happens INSIDE the
    /// window is still reported.
    func testAFallInsideTheLookbackWindowIsStillReported() throws {
        let old = Calendar.current.date(byAdding: .day, value: -420, to: Date())!
        func on(_ day: Int, _ kg: Double) -> WeightMeasurement {
            onOldTimeline(old, day, kg)
        }
        let m = [on(30, 5.7), on(300, 10.9), on(340, 9.6), on(400, 8.9)]
        let verdict = GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                         isMale: true, birthPercentile: 50)
        guard case .sustainedDrop = verdict else {
            return XCTFail("expected a sustained drop inside the window, got \(verdict)")
        }
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

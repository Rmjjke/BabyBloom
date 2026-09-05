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

    /// The fall's mirror of the wobble defect, and the last way a single
    /// weighing bought back the green tick.
    ///
    /// The baby fell from the median to three SD below and then came back
    /// thirty grams. That made it no longer the lowest reading of its series, so
    /// the old `latest <= scores.min()` guard sent it to `.stable` — a green
    /// "holding its channel" tick for a baby sitting about four centile spaces
    /// under its own peak.
    func testAWobbleAtTheBottomDoesNotRestoreTheGreenTick() throws {
        let m = [at(30, medianDay30), at(90, minus2SDDay90), at(120, 5.55)]

        let z90 = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: minus2SDDay90, ageDays: 90, isMale: true))
        let z120 = try XCTUnwrap(WHOGrowthStandard.zScore(weightKg: 5.55, ageDays: 120, isMale: true))
        XCTAssertGreaterThan(z120, z90, "the last weighing must be a recovery, or this tests nothing")
        XCTAssertLessThan(z120, -2 * GrowthTrend.zPerCentileSpace,
                          "and must still sit two full spaces below the median it started at")

        guard case let .sustainedDrop(spaces) = assess(m) else {
            return XCTFail("a wobble at the bottom is still a fall, got \(assess(m))")
        }
        XCTAssertGreaterThanOrEqual(spaces, 2)
    }

    /// The case the dropped guard was written for, which arithmetic already
    /// covers: a dip that has recovered all the way to its starting centile has
    /// `peak - latest ≈ 0` and needs no guard to stay calm. Kept beside its
    /// half-recovered sibling above so the difference between them is a fixture
    /// rather than an argument.
    func testAFullyRecoveredDipNeedsNoGuardToStayStable() {
        XCTAssertEqual(assess([at(30, medianDay30), at(90, minus2SDDay90), at(120, medianDay120)]),
                       .stable)
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
        // Two centile spaces above the median start, expressed in z: the
        // pre-assertion has to IMPLY the verdict below, not merely gesture at it.
        XCTAssertGreaterThan(z150, 2 * GrowthTrend.zPerCentileSpace,
                             "and must still sit two full spaces above the median it started at")

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
    /// surprise: a fall spread over several weighings, each step small enough
    /// that no eligible peak sits a full threshold above the latest reading, is
    /// never reported however far it travels in total. NICE's thresholds
    /// describe a fall over weeks to months; catching this one would mean
    /// restoring the permanent flag the bound exists to remove.
    ///
    /// Note what is NOT blind: a fall between two readings 200 days apart is
    /// reported, because the window always keeps the two most recent weighings.
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

    /// A verdict is never computed over a two-day pair.
    ///
    /// Weighed at birth, at a month, then twice in one week: the whole-record
    /// gates pass on four readings across 252 days, while the only readings
    /// inside the lookback are the last two, 2 days apart — where a full nappy
    /// outweighs a fortnight of growth. On that pair alone the baby appears to
    /// have climbed 2.97 spaces and the card would announce a crossing.
    ///
    /// The answer is that nothing can be said yet, NOT a verdict measured
    /// against the day-30 reading: reaching back past the lookback for a span is
    /// how an ancient peak gets back into the comparison.
    func testAVerdictIsNeverComputedOverATwoDayPair() {
        let old = Calendar.current.date(byAdding: .day, value: -300, to: Date())!
        // z ≈ 0 at day 30, a dip at day 250, back to about the start at day 252.
        let m = [onOldTimeline(old, 0, 3.346), onOldTimeline(old, 30, 4.452),
                 onOldTimeline(old, 250, 6.9), onOldTimeline(old, 252, 8.6)]
        XCTAssertEqual(GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 50), .insufficientData)
    }

    /// A tight recent cluster must not reach back through a year of history for
    /// something to be measured against.
    ///
    /// Three weighings around the 97th centile at two to three months, then two
    /// at the median at thirteen — ordinary catch-down, the textbook shape the
    /// lookback exists to stop flagging. Widening the window to reach a span
    /// walked it back 312 days, took the day-91 peak and reported a 2.8-space
    /// drop; worse, a follow-up weighing a week later still could not span four
    /// weeks within the cluster, so the flag was unclearable for another month.
    /// Both the cluster and its follow-up must stay silent.
    func testATightRecentClusterDoesNotReachBackForAnAncientPeak() {
        let old = Calendar.current.date(byAdding: .day, value: -430, to: Date())!
        // Day 30/63/91 at roughly +1.88 z; day 400/403 at about the median.
        let cluster = [onOldTimeline(old, 30, 5.55), onOldTimeline(old, 63, 6.7),
                       onOldTimeline(old, 91, 7.6),
                       onOldTimeline(old, 400, 10.4), onOldTimeline(old, 403, 10.45)]

        // Born below the 9th centile, where a single space is the threshold —
        // the setting that made this reachable for ordinary catch-up growth.
        for percentile in [5.0, 50.0] {
            XCTAssertEqual(GrowthTrend.assess(measurements: cluster, correctedBirthDate: old,
                                              isMale: true, birthPercentile: percentile),
                           .insufficientData, "birth percentile \(percentile)")
        }

        // And a week later, which is when the old behaviour was still flagging.
        let followUp = cluster + [onOldTimeline(old, 410, 10.5)]
        XCTAssertEqual(GrowthTrend.assess(measurements: followUp, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 5),
                       .insufficientData)

        // Once the recent cluster is itself four weeks wide the card speaks
        // again, measured entirely within the lookback — the flag was never
        // suppressed, only refused until there was something to compute it on.
        let settled = followUp + [onOldTimeline(old, 431, 10.6)]
        XCTAssertEqual(GrowthTrend.assess(measurements: settled, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 5), .stable)
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

    /// The other half of the same fixture, and a scope boundary worth stating:
    /// a transposed weight (9.7 kg then 7.9 kg two days later) is NOT reported
    /// by this detector.
    ///
    /// Round 2 flagged it, by widening the window back to the day-30 reading to
    /// find a span. That reach is what round 3 removed, because the same reach
    /// pulled an ancient peak into an ordinary catch-down. What is left is
    /// consistent rather than lucky: nothing in this app computes a trajectory
    /// from a two-day interval — `WeightVelocity.minimumIntervalDays` refuses
    /// the same pair for the same reason, that a full nappy outweighs the
    /// signal. A rapid loss is a velocity question, and this detector answers
    /// "is the baby sliding down the chart", which two days cannot support.
    ///
    /// Recorded as a fixture so the silence is a decision someone can revisit,
    /// not an accident nobody noticed.
    func testARapidLossIsOutsideThisDetectorsScope() {
        let old = Calendar.current.date(byAdding: .day, value: -300, to: Date())!
        let m = [onOldTimeline(old, 0, 3.346), onOldTimeline(old, 30, 4.452),
                 onOldTimeline(old, 250, 9.7), onOldTimeline(old, 252, 7.9)]
        XCTAssertEqual(GrowthTrend.assess(measurements: m, correctedBirthDate: old,
                                          isMale: true, birthPercentile: 50), .insufficientData)
    }
}

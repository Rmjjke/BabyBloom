import XCTest
@testable import BabyBloom

final class WeightVelocityTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -120, to: Date())!

    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    private func measure(_ a: WeightMeasurement, _ b: WeightMeasurement, male: Bool = true) -> WeightVelocity.Reading? {
        WeightVelocity.measure(from: a, to: b, correctedBirthDate: birth, isMale: male)
    }

    // MARK: - Guards

    /// Over a day or two a wet nappy outweighs the trend, so there is no honest
    /// answer to give.
    func testIntervalsShorterThanThreeDaysAreRefused() {
        XCTAssertNil(measure(at(10, 3.5), at(12, 3.6)))
        XCTAssertNotNil(measure(at(10, 3.5), at(13, 3.6)))
    }

    func testOutOfOrderOrEmptyInputIsRefused() {
        XCTAssertNil(measure(at(20, 4.0), at(10, 3.5)))
        XCTAssertNil(measure(at(10, 0), at(20, 4.0)))
        XCTAssertNil(WeightVelocity.latest(measurements: [at(10, 3.5)], correctedBirthDate: birth, isMale: true))
    }

    // MARK: - Rate

    func testRateIsNormalisedPerDayAndReportedPerWeek() throws {
        // +700 g over 14 days = 50 g/day = 350 g/week.
        let r = try XCTUnwrap(measure(at(14, 4.0), at(28, 4.7)))
        XCTAssertEqual(r.gramsPerDay, 50, accuracy: 0.01)
        XCTAssertEqual(r.gramsPerWeek, 350, accuracy: 0.1)
        XCTAssertEqual(r.intervalDays, 14)
    }

    func testWeightLossProducesANegativeRate() throws {
        let r = try XCTUnwrap(measure(at(30, 4.5), at(44, 4.3)))
        XCTAssertLessThan(r.gramsPerDay, 0)
        XCTAssertEqual(r.band, .below)
    }

    /// The truncation defect, pinned from the side it actually hurts.
    ///
    /// 3 d 22 h with +82 g is 20.9 g/day — below the P15 of 26.95 for a boy in
    /// the 4-week-to-2-month row, so the gain is `.below` and the app says so.
    /// Dividing by truncated whole days made it 27.3 g/day, inside the band:
    /// false reassurance, and the growthGainLow notification never fired. The
    /// interval LABEL still reads 3 days, which is what the calendar says.
    func testASubDayOffsetDoesNotInflateTheRate() throws {
        let earlier = WeightMeasurement(date: at(35, 4.6).date, weightKg: 4.6)
        let later = WeightMeasurement(
            date: earlier.date.addingTimeInterval(3 * 86_400 + 22 * 3_600),
            weightKg: 4.682
        )
        let r = try XCTUnwrap(measure(earlier, later))
        XCTAssertEqual(r.gramsPerDay, 20.94, accuracy: 0.05)
        XCTAssertEqual(r.intervalDays, 3)
        XCTAssertEqual(r.band, .below, "27.3 g/day — the truncated figure — would have read .within")
    }

    // MARK: - Bands against WHO references

    /// WHO 1-month increments for boys, 0–4 weeks: P15 = 24.3 g/day,
    /// P85 = 47.7 g/day. The band edges are checked from both sides.
    func testBandEdgesForTheFirstMonthMatchWHO() throws {
        let reference = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        XCTAssertEqual(reference.lowerBound, 24.32, accuracy: 0.01)
        XCTAssertEqual(reference.upperBound, 47.71, accuracy: 0.01)

        // 20 g/day sits below P15, 35 inside, 60 above.
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.020 * 14))?.band, .below)
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.035 * 14))?.band, .within)
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.060 * 14))?.band, .above)
    }

    /// Girls gain a little slower, and the tables say so: the same rate can be
    /// inside the band for a girl and below it for a boy.
    func testReferencesDifferBySex() throws {
        let boys = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        let girls = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: false))
        XCTAssertGreaterThan(boys.lowerBound, girls.lowerBound)
        XCTAssertGreaterThan(boys.upperBound, girls.upperBound)
    }

    /// Expected gain slows sharply over the first year — a rate that is normal at
    /// two weeks is well above the band at eleven months.
    func testExpectedGainFallsWithAge() throws {
        let early = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        let late = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 350, isMale: true))
        XCTAssertGreaterThan(early.lowerBound, late.lowerBound)
        XCTAssertGreaterThan(early.upperBound, late.upperBound)
    }

    // MARK: - Range limits

    /// Past 12 months there is no velocity reference. The measured rate is still
    /// reported — it is a fact — but without a band, rather than against a
    /// borrowed one.
    func testPastTwelveMonthsTheRateHasNoBand() throws {
        XCTAssertNil(WeightVelocity.expectedPerDay(correctedAgeDays: 366, isMale: true))

        let old = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        let a = WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: 380, to: old)!, weightKg: 10.0)
        let b = WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: 394, to: old)!, weightKg: 10.2)
        let r = try XCTUnwrap(WeightVelocity.measure(from: a, to: b, correctedBirthDate: old, isMale: true))
        XCTAssertNil(r.band)
        XCTAssertNil(r.expectedPerWeek)
        XCTAssertEqual(r.gramsPerDay, 200.0 / 14, accuracy: 0.01)
    }

    // MARK: - Prematurity

    /// A baby born at 32 weeks is compared against the reference for its
    /// corrected age, where expected gain is higher — so the same rate that is
    /// comfortably inside the band chronologically can be below it corrected.
    func testCorrectedAgeSelectsTheReference() throws {
        let baby = Baby(name: "Test", birthDate: birth, gender: .male, feedingType: .breast)
        baby.gestationalWeeks = 32

        let chronological = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 120, isMale: true))
        let corrected = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: baby.correctedAgeDays, isMale: true))
        XCTAssertEqual(baby.correctedAgeDays, 64)
        XCTAssertGreaterThan(corrected.lowerBound, chronological.lowerBound)
    }

    // MARK: - Consecutive low intervals

    /// One slow fortnight is noise. Only a run of them is worth a notification,
    /// so a single low interval must not trigger.
    func testOneLowIntervalIsNotAPattern() {
        // +150 g then +550 g over 14 days each: below, then comfortably inside.
        let m = [at(30, 4.0), at(44, 4.15), at(58, 4.70)]
        XCTAssertFalse(WeightVelocity.consecutiveBelowReference(
            measurements: m, correctedBirthDate: birth, isMale: true))
    }

    func testTwoLowIntervalsInARowArePattern() {
        // ~11 g/day twice running, well under the P15 for this age.
        let m = [at(30, 4.0), at(44, 4.15), at(58, 4.30)]
        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: m, correctedBirthDate: birth, isMale: true))
    }

    func testTooFewWeighingsCannotFormAPattern() {
        XCTAssertFalse(WeightVelocity.consecutiveBelowReference(
            measurements: [at(30, 4.0), at(44, 4.15)], correctedBirthDate: birth, isMale: true))
    }

    /// A weighing too close to the one before it never BECOMES an interval — it
    /// is absorbed into the longer one around it. So three weighings whose last
    /// two sit a day apart hold one measurable interval, not two, and one
    /// interval is never a pattern. This is what keeps two weighings a day apart
    /// from raising an alarm between them.
    func testANoiseWeighingCannotManufactureASecondInterval() {
        let m = [at(30, 4.0), at(44, 4.15), at(45, 4.16)]
        XCTAssertFalse(WeightVelocity.consecutiveBelowReference(
            measurements: m, correctedBirthDate: birth, isMale: true))
    }

    /// The notification half of "adding a weighing must never show less": two
    /// low intervals were a pattern, and a curious re-weigh the next morning
    /// used to make the newest raw pair unmeasurable and silence the run
    /// entirely. The short tail is absorbed into the interval around it instead.
    func testAShortTailDoesNotSuppressARunThatWasAlreadyThere() {
        let established = [at(30, 4.0), at(44, 4.15), at(58, 4.30)]
        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: established, correctedBirthDate: birth, isMale: true))

        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: established + [at(59, 4.31)], correctedBirthDate: birth, isMale: true),
            "one extra weighing cannot un-say a pattern the parent already had")
    }

    // MARK: - Pair fallback

    func testLatestUsesTheTwoMostRecentWeighings() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.3), at(30, 4.2), at(44, 4.9)],
            correctedBirthDate: birth,
            isMale: true
        ))
        XCTAssertEqual(r.intervalDays, 14)
        XCTAssertEqual(r.gramsPerDay, 50, accuracy: 0.01)
    }

    /// The defect this fallback exists for: weighed on day 0 and day 7, the
    /// parent had a verdict; weighing again on day 8 took it away, because the
    /// newest pair spanned one day. Three weighings must not say less than two.
    func testAShortTailWidensThePairInsteadOfSilencingTheReading() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.30), at(7, 3.55), at(8, 3.58)],
            correctedBirthDate: birth,
            isMale: true
        ))
        // 280 g over the widened 0→8 pair, and the label describes that pair.
        XCTAssertEqual(r.intervalDays, 8)
        XCTAssertEqual(r.gramsPerDay, 35, accuracy: 0.01)
    }

    /// The other direction of the same promise: removing the tail leaves the
    /// pair that was already being reported, not a hint.
    func testDeletingTheShortTailLeavesTheOriginalPairReading() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.30), at(7, 3.55)],
            correctedBirthDate: birth,
            isMale: true
        ))
        XCTAssertEqual(r.intervalDays, 7)
        XCTAssertEqual(r.gramsPerDay, 250.0 / 7, accuracy: 0.01)
    }

    /// The honest nil the "two measurements" hint is still for: every weighing
    /// inside three days of the newest, so no pair can be measured at all.
    func testWeighingsClusteredInsideTheFloorHaveNoPair() {
        let clustered = [at(0, 3.30), at(1, 3.32), at(2, 3.35)]
        XCTAssertNil(WeightVelocity.pair(in: clustered))
        XCTAssertNil(WeightVelocity.latest(measurements: clustered,
                                           correctedBirthDate: birth, isMale: true))
    }

    /// The fallback walks back from the NEWEST weighing, never to an older pair
    /// that happens to be measurable: the card claims to describe the current
    /// trajectory, and 20→40 would be a statement about last month.
    func testTheFallbackKeepsTheNewestWeighingInThePair() throws {
        let pair = try XCTUnwrap(WeightVelocity.pair(
            in: [at(0, 3.30), at(20, 4.00), at(40, 4.70), at(41, 4.72)]))
        XCTAssertEqual(pair.earlier.date, at(20, 4.00).date)
        XCTAssertEqual(pair.later.date, at(41, 4.72).date)

        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.30), at(20, 4.00), at(40, 4.70), at(41, 4.72)],
            correctedBirthDate: birth,
            isMale: true
        ))
        XCTAssertEqual(r.intervalDays, 21)
    }
}

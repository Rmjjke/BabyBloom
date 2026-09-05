import XCTest
@testable import BabyBloom

final class WeightVelocityTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -120, to: Date())!

    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    /// A pinned UTC calendar and a fixed birth date, for the fixtures that
    /// assert a RATE rather than a band.
    ///
    /// `gramsPerDay` divides by real elapsed seconds, so a daylight-saving
    /// transition inside the interval turns an exact 35 g/day into 35.18 —
    /// twice a year, on some devices only. `FeedingAdequacyTests` documents
    /// the same trap where it first bit. The band fixtures above keep the
    /// device calendar deliberately: they compare against WHO references with
    /// margins of whole g/day, which an hour cannot move, and one of them
    /// reads `Baby.correctedAgeDays`, which is measured from the real `now`.
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let fixedBirth = WeightVelocityTests.utc.date(
        from: DateComponents(year: 2026, month: 6, day: 1, hour: 12))!

    private func utcAt(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Self.utc.date(byAdding: .day, value: day, to: fixedBirth)!, weightKg: kg)
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

    /// Noise in the MIDDLE of a history is absorbed exactly as a tail is: the
    /// one-day 14→15 step joins the interval around it, leaving 0→15 and 15→29
    /// — two measurable intervals, and a pattern. On raw consecutive pairs the
    /// walk hit that step and reported nothing at all.
    func testNoiseInsideTheHistoryDoesNotBreakTheRun() {
        let m = [at(0, 3.30), at(14, 3.45), at(15, 3.46), at(29, 3.60)]
        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: m, correctedBirthDate: birth, isMale: true))
    }

    // MARK: - Pair fallback

    func testLatestUsesTheNewestMeasurablePair() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.3), at(30, 4.2), at(44, 4.9)],
            correctedBirthDate: birth,
            isMale: true
        ))
        // Nothing here sits inside the floor, so the newest measurable pair IS
        // the last two — the case the fallback must leave alone.
        XCTAssertEqual(r.intervalDays, 14)
        XCTAssertEqual(r.gramsPerDay, 50, accuracy: 0.01)
    }

    /// The defect this fallback exists for: weighed on day 0 and day 7, the
    /// parent had a verdict; weighing again on day 8 took it away, because the
    /// newest pair spanned one day. Three weighings must not say less than two.
    func testAShortTailWidensThePairInsteadOfSilencingTheReading() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [utcAt(0, 3.30), utcAt(7, 3.55), utcAt(8, 3.58)],
            correctedBirthDate: fixedBirth,
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
            measurements: [utcAt(0, 3.30), utcAt(7, 3.55)],
            correctedBirthDate: fixedBirth,
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

    /// Two weighings stamped the same instant contradict each other, and
    /// `sorted(by:)` is not stable — so without a tie-break the pair, and the
    /// gain printed from it, could differ between two renders of one history.
    /// Shuffled input is the only way to exercise that: the sort is free to
    /// return either order for equal keys.
    ///
    /// The answer is pinned as well as fixed. Between two arbitrary readings
    /// the lighter duplicate becomes the newest weighing — 3.90 over 3.30 in
    /// ten days is 60 g/day, not the 80 the heavier one would report — because
    /// overstating a gain is the direction `measure(from:to:)` documents as
    /// unsafe.
    func testTwoWeighingsAtOneInstantStillProduceOneAnswer() throws {
        let duplicates = [at(0, 3.30), at(10, 3.90), at(10, 4.10)]
        for _ in 0..<20 {
            let reading = try XCTUnwrap(WeightVelocity.latest(
                measurements: duplicates.shuffled(), correctedBirthDate: birth, isMale: true))
            XCTAssertEqual(reading.gramsPerDay, 60, accuracy: 0.5)
        }
    }

    // MARK: - A future-dated row is not evidence

    /// The reporter's own history: a weighing typed with a date twelve days
    /// out. It is dropped at the accessor, so the reading is the honest one
    /// over the two weighings that have actually happened.
    ///
    /// Without the filter the pair fallback makes this WORSE than the old rule
    /// did. The last two rows span 15 days, so a reading appears — 13 g/day
    /// where the baby is truly gaining 33 — because the gain is divided by nine
    /// days that have not elapsed yet. Understating is the direction
    /// `measure(from:to:...)` documents as unsafe: it can turn `.within` into
    /// `.below` and raise `growthGainLow` off arithmetic about the future.
    func testAFutureDatedRowIsDroppedAndTheHonestPairIsRead() throws {
        let entries = [
            GrowthEntry(date: daysFromNow(-12), weightKg: 4.00),
            GrowthEntry(date: daysFromNow(-3),  weightKg: 4.30),
            GrowthEntry(date: daysFromNow(12),  weightKg: 4.50),
        ]
        let measurements = entries.weightMeasurements
        XCTAssertEqual(measurements.count, 2, "the future row is not evidence")
        XCTAssertEqual(measurements.last?.weightKg, 4.30)

        let reading = try XCTUnwrap(WeightVelocity.latest(
            measurements: measurements,
            correctedBirthDate: daysFromNow(-60),
            isMale: true
        ))
        XCTAssertEqual(reading.intervalDays, 9, "the interval that has actually elapsed")
        XCTAssertEqual(reading.gramsPerDay, 300.0 / 9, accuracy: 0.5)
    }

    /// The tolerance, pinned from both sides. A row a few hours ahead of the
    /// clock is ordinary — the sheet stamps the chosen day with the time it was
    /// opened, and a phone whose clock runs fast syncs rows that arrive ahead —
    /// so only a date beyond a day out is treated as wrong.
    func testTheFutureToleranceIsADayAndIsPinnedFromBothSides() {
        XCTAssertEqual([GrowthEntry(date: Date().addingTimeInterval(3 * 3600), weightKg: 4.5)]
            .weightMeasurements.count, 1, "later today still counts")
        XCTAssertEqual([GrowthEntry(date: Date().addingTimeInterval(23 * 3600), weightKg: 4.5)]
            .weightMeasurements.count, 1)
        XCTAssertEqual([GrowthEntry(date: Date().addingTimeInterval(25 * 3600), weightKg: 4.5)]
            .weightMeasurements.count, 0)
    }

    private func daysFromNow(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
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

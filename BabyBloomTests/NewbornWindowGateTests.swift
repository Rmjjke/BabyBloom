import XCTest
@testable import BabyBloom

/// The newborn window gate: while `NewbornWeightLoss` is the instrument in
/// force, no surface may print a below-reference weight-GAIN verdict, and the
/// low-gain notification may not fire.
///
/// Every "during the window" test below is built on a fixture that WOULD read
/// `.below` without the gate, and each one asserts that first. A gate proven
/// only by a calm result is a gate that would also pass if the fixture were
/// simply healthy.
final class NewbornWindowGateTests: XCTestCase {

    private let now = Date()
    private let birthWeight = 3.5

    /// Whole calendar days, the way every day count in `Core/Growth` is
    /// measured — spacing entries by 86_400 seconds instead disagrees with the
    /// module across a DST transition.
    private func date(dayOfLife: Int, from birth: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: dayOfLife, to: birth)!
    }

    private func birth(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    /// A real newborn course: born 3.5 kg, down to 3.25 by day 4, barely up to
    /// 3.3 by day 10. Both measurable intervals come in below the WHO velocity
    /// reference — which is exactly what the first weeks look like, and exactly
    /// what must not be reported as a finding.
    private func newbornCourse(observedOnDay day: Int) -> (birth: Date, measurements: [WeightMeasurement]) {
        let birth = birth(daysAgo: day)
        return (birth, [
            WeightMeasurement(date: date(dayOfLife: 0, from: birth), weightKg: birthWeight),
            WeightMeasurement(date: date(dayOfLife: 4, from: birth), weightKg: 3.25),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.30),
        ])
    }

    private func assess(birth: Date,
                        birthWeightKg: Double?,
                        measurements: [WeightMeasurement]) -> FeedingAdequacy.Assessment? {
        FeedingAdequacy.assess(
            birthDate: birth,
            birthWeightKg: birthWeightKg,
            correctedBirthDate: birth,
            isMale: false,
            measurements: measurements,
            feeds: [],
            wetNappies: [],
            now: now
        )
    }

    // MARK: - The predicate itself

    func testWindowIsActiveOnlyWithABirthWeightAndOnlyToDay21() {
        let birth = birth(daysAgo: 0)
        XCTAssertTrue(NewbornWeightLoss.windowActive(birthWeightKg: birthWeight,
                                                     birthDate: birth, now: now))
        // No birth weight, nothing to measure the dip against — the module does
        // not apply, so neither does its gate.
        XCTAssertFalse(NewbornWeightLoss.windowActive(birthWeightKg: nil,
                                                      birthDate: birth, now: now))
        XCTAssertFalse(NewbornWeightLoss.windowActive(birthWeightKg: 0,
                                                      birthDate: birth, now: now))
    }

    /// Pinned from both sides so an off-by-one cannot quietly extend or cut the
    /// window the whole feature keys off.
    func testWindowClosesTheDayAfterTheObservationWindow() {
        XCTAssertEqual(NewbornWeightLoss.observationWindowDays, 21,
                       "the fixtures below are written against 21 days")
        XCTAssertTrue(NewbornWeightLoss.windowActive(
            birthWeightKg: birthWeight, birthDate: birth(daysAgo: 21), now: now))
        XCTAssertFalse(NewbornWeightLoss.windowActive(
            birthWeightKg: birthWeight, birthDate: birth(daysAgo: 22), now: now))
    }

    /// `analyse` and `windowActive` answer the same question, so the card and
    /// the gate can never disagree about whether these are the first weeks.
    func testTheCardAndTheGateAgreeOnApplicability() {
        for daysAgo in [0, 1, 14, 21, 22, 40] {
            let course = newbornCourse(observedOnDay: daysAgo)
            let analysed = NewbornWeightLoss.analyse(birthWeightKg: birthWeight,
                                                     birthDate: course.birth,
                                                     measurements: course.measurements,
                                                     now: now) != nil
            let active = NewbornWeightLoss.windowActive(birthWeightKg: birthWeight,
                                                        birthDate: course.birth, now: now)
            XCTAssertEqual(analysed, active, "day \(daysAgo)")
        }
    }

    // MARK: - During the window

    /// Fail-on-old: without the gate this fixture reads "below the reference".
    func testTheFixtureWouldReadBelowWithoutTheGate() {
        let course = newbornCourse(observedOnDay: 12)
        let reading = WeightVelocity.latest(measurements: course.measurements,
                                            correctedBirthDate: course.birth,
                                            isMale: false)
        XCTAssertEqual(reading?.band, .below,
                       "the fixture is only a test of the gate if the raw velocity is below")
    }

    func testGainIsDeferredAndNoBreakdownOpensDuringTheWindow() throws {
        let course = newbornCourse(observedOnDay: 12)
        let assessment = try XCTUnwrap(assess(birth: course.birth,
                                              birthWeightKg: birthWeight,
                                              measurements: course.measurements))
        XCTAssertEqual(assessment.gain, .deferredToNewbornWindow)
        XCTAssertNotEqual(assessment.gain, .below)
        XCTAssertFalse(assessment.warrantsBreakdown,
                       "the physiological dip must never open the feeding breakdown")
    }

    /// The deferral is its own statement. "Not enough data" would be a lie —
    /// there are three weighings — and "below" is the verdict being withheld.
    func testTheParentFacingWordIsTheFirstWeeksPointerWhateverTheBandSays() {
        XCTAssertEqual(StatusWord.of(.deferredToNewbornWindow, band: .below), .firstWeeks)
        XCTAssertEqual(StatusWord.of(.deferredToNewbornWindow, band: nil), .firstWeeks)
        XCTAssertNotEqual(StatusWord.firstWeeks, .notEnoughData)
        XCTAssertEqual(StatusWord.firstWeeks.localizationKey, "nutrition.status_first_weeks")
    }

    /// The Dashboard's free line reads the same assessment, so it defers too.
    func testTheDashboardFreeLineDefersDuringTheWindow() throws {
        let course = newbornCourse(observedOnDay: 12)
        let assessment = try XCTUnwrap(assess(birth: course.birth,
                                              birthWeightKg: birthWeight,
                                              measurements: course.measurements))
        let free = DashboardGrowthSummary.free(latestWeightKg: 3.30,
                                               assessment: assessment,
                                               band: .below,
                                               withinReferenceAge: true)
        XCTAssertEqual(free, .summary(weightKg: 3.30, gain: .word(.firstWeeks)))
    }

    /// A parent who never recorded a birth weight has no first-weeks card, so
    /// nothing is deferring on their behalf: the ordinary rules stand, or the
    /// gate would silence the gain verdict with nothing put in its place.
    func testWithoutABirthWeightTheOrdinaryRulesStillApply() throws {
        let course = newbornCourse(observedOnDay: 12)
        let assessment = try XCTUnwrap(assess(birth: course.birth,
                                              birthWeightKg: nil,
                                              measurements: course.measurements))
        XCTAssertEqual(assessment.gain, .below)
    }

    // MARK: - The notification

    func testGrowthGainLowCannotFireDuringTheWindow() {
        let course = newbornCourse(observedOnDay: 12)
        // Fail-on-old: two consecutive below-reference intervals, which is
        // exactly what the signal fires on.
        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: course.measurements,
            correctedBirthDate: course.birth,
            isMale: false,
            intervalsMustEndAfter: nil),
            "without the gate this parent gets a low-gain warning on day 12")

        XCTAssertFalse(NotificationManager.shared.shouldRaiseGainSignal(
            birthDate: course.birth,
            birthWeightKg: birthWeight,
            correctedBirthDate: course.birth,
            isMale: false,
            measurements: course.measurements,
            now: now))
    }

    /// The chained interval, which the newest-interval gate does not reach.
    ///
    /// Born 3.50, down to 3.30 by day 10, up to 3.60 by day 40, seen on day 41.
    /// The newest interval (day 10 → day 40) ends outside the window and IS
    /// honestly below the reference — one genuinely slow month, which is noise
    /// and must not interrupt anyone. The chain then walks back to day 0 → day
    /// 10, which is the dip: below every reference by construction. Two in a
    /// row, a "pattern", and a low-gain warning — assembled from one real
    /// interval and one piece of physiology.
    ///
    /// The count-2 rule exists to demand INDEPENDENT evidence, so an interval
    /// ending inside the window stops the chain rather than counting toward it.
    func testTheChainCannotBeCompletedByAnIntervalInsideTheDip() {
        let birth = birth(daysAgo: 41)
        let measurements = [
            WeightMeasurement(date: date(dayOfLife: 0, from: birth), weightKg: 3.50),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.30),
            WeightMeasurement(date: date(dayOfLife: 40, from: birth), weightKg: 3.60),
        ]
        // The newest interval is genuinely below and the window is long shut,
        // so nothing above this stops the signal.
        XCTAssertNil(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                    birthDate: birth,
                                                    measurements: measurements,
                                                    now: now))
        XCTAssertEqual(WeightVelocity.latest(measurements: measurements,
                                             correctedBirthDate: birth,
                                             isMale: false)?.band, .below)
        // Fail-on-current: with no boundary the dip completes the pattern.
        XCTAssertTrue(WeightVelocity.consecutiveBelowReference(
            measurements: measurements, correctedBirthDate: birth,
            isMale: false, intervalsMustEndAfter: nil),
            "the fixture only tests the boundary if the chain closes without it")

        XCTAssertFalse(NotificationManager.shared.shouldRaiseGainSignal(
            birthDate: birth,
            birthWeightKg: birthWeight,
            correctedBirthDate: birth,
            isMale: false,
            measurements: measurements,
            now: now),
            "one slow month plus the dip is not two slow months")
    }

    /// The control: both intervals after the window and both genuinely below.
    /// The boundary must not have turned the signal off in general — a
    /// notification that never fires says nothing at all.
    func testTwoPostWindowLowIntervalsStillFire() {
        let birth = birth(daysAgo: 47)
        let measurements = [
            WeightMeasurement(date: date(dayOfLife: 26, from: birth), weightKg: 4.00),
            WeightMeasurement(date: date(dayOfLife: 33, from: birth), weightKg: 4.02),
            WeightMeasurement(date: date(dayOfLife: 40, from: birth), weightKg: 4.04),
        ]
        XCTAssertTrue(NotificationManager.shared.shouldRaiseGainSignal(
            birthDate: birth,
            birthWeightKg: birthWeight,
            correctedBirthDate: birth,
            isMale: false,
            measurements: measurements,
            now: now))
    }

    /// The gate defers the signal, it does not delete it. The same shape of
    /// history past the window still raises it.
    func testGrowthGainLowFiresAgainOnceTheWindowHasClosed() {
        let birth = birth(daysAgo: 40)
        let measurements = [
            WeightMeasurement(date: date(dayOfLife: 26, from: birth), weightKg: 4.00),
            WeightMeasurement(date: date(dayOfLife: 33, from: birth), weightKg: 4.02),
            WeightMeasurement(date: date(dayOfLife: 40, from: birth), weightKg: 4.04),
        ]
        XCTAssertTrue(NotificationManager.shared.shouldRaiseGainSignal(
            birthDate: birth,
            birthWeightKg: birthWeight,
            correctedBirthDate: birth,
            isMale: false,
            measurements: measurements,
            now: now))
    }

    // MARK: - The day-22 cliff

    /// The defect the pair-endpoint condition exists to remove: with only the
    /// "is the baby inside the window now" test, this history is silent on day
    /// 21 and prints a below-reference verdict on day 22 — off data that has
    /// not changed, the morning after `NewbornProgressCard` disappeared.
    ///
    /// Fails on the now-only gate at every assertion below the first two.
    func testAStaleFirstWeeksPairStillDefersAfterTheWindowCloses() throws {
        let course = newbornCourse(observedOnDay: 22)

        // The two facts that made the cliff: the window is shut, and the
        // reading it would release is `.below`.
        XCTAssertFalse(NewbornWeightLoss.windowActive(birthWeightKg: birthWeight,
                                                      birthDate: course.birth, now: now),
                       "day 22 is past the window — the first-weeks card is gone")
        XCTAssertEqual(WeightVelocity.latest(measurements: course.measurements,
                                             correctedBirthDate: course.birth,
                                             isMale: false)?.band, .below)

        XCTAssertEqual(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                      birthDate: course.birth,
                                                      measurements: course.measurements,
                                                      now: now),
                       .measuredInFirstWeeks)

        let assessment = try XCTUnwrap(assess(birth: course.birth,
                                              birthWeightKg: birthWeight,
                                              measurements: course.measurements))
        XCTAssertEqual(assessment.gain, .deferredToNewbornWindow)
        XCTAssertFalse(assessment.warrantsBreakdown)

        XCTAssertFalse(NotificationManager.shared.shouldRaiseGainSignal(
            birthDate: course.birth,
            birthWeightKg: birthWeight,
            correctedBirthDate: course.birth,
            isMale: false,
            measurements: course.measurements,
            now: now), "the notification must not fire the day the card vanished")
    }

    /// The same cliff on a baby who has REGAINED — the textbook healthy course,
    /// and the fixture that shows the defect is not about sick babies. Birth
    /// weight back by day 10 is exactly what `NewbornWeightLoss` calls a good
    /// outcome, and the velocity reference still reads that 50 g over ten days
    /// as below P15.
    func testARegainedNewbornAlsoDefersAfterTheWindowCloses() throws {
        let birth = birth(daysAgo: 22)
        let measurements = [
            WeightMeasurement(date: birth, weightKg: birthWeight),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.55),
        ]
        // Regained, by the module's own reckoning.
        let status = try XCTUnwrap(NewbornWeightLoss.analyse(
            birthWeightKg: birthWeight, birthDate: birth, measurements: measurements,
            now: date(dayOfLife: 21, from: birth)))
        XCTAssertTrue(status.hasRegained)

        XCTAssertEqual(WeightVelocity.latest(measurements: measurements,
                                             correctedBirthDate: birth,
                                             isMale: false)?.band, .below,
                       "the fixture only tests the gate if the raw velocity is below")

        XCTAssertEqual(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                      birthDate: birth,
                                                      measurements: measurements,
                                                      now: now),
                       .measuredInFirstWeeks)
        let assessment = try XCTUnwrap(assess(birth: birth,
                                              birthWeightKg: birthWeight,
                                              measurements: measurements))
        XCTAssertEqual(assessment.gain, .deferredToNewbornWindow)
    }

    /// The property that makes the pair-endpoint rule safe, and the reason the
    /// EARLIER endpoint was rejected: the deferral always has an exit, and it is
    /// the exact thing the card asks for.
    func testANewWeighingEndsTheStaleDeferral() throws {
        let birth = birth(daysAgo: 25)
        let firstWeeksOnly = [
            WeightMeasurement(date: birth, weightKg: birthWeight),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.30),
        ]
        XCTAssertEqual(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                      birthDate: birth,
                                                      measurements: firstWeeksOnly,
                                                      now: now),
                       .measuredInFirstWeeks)

        let withTodaysWeighing = firstWeeksOnly + [
            WeightMeasurement(date: date(dayOfLife: 25, from: birth), weightKg: 4.2)
        ]
        XCTAssertNil(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                    birthDate: birth,
                                                    measurements: withTodaysWeighing,
                                                    now: now),
                     "one weighing outside the window moves the pair's later endpoint out")
        let assessment = try XCTUnwrap(assess(birth: birth,
                                              birthWeightKg: birthWeight,
                                              measurements: withTodaysWeighing))
        XCTAssertEqual(assessment.gain, .within)
    }

    /// The deferral names WHICH shape it is, because the card says different
    /// things and only one of them carries a button.
    func testTheTwoDeferralShapesAreDistinguished() {
        let inWindow = newbornCourse(observedOnDay: 12)
        XCTAssertEqual(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                      birthDate: inWindow.birth,
                                                      measurements: inWindow.measurements,
                                                      now: now),
                       .firstWeeksNow)
        // No weighings at all, still inside the window: the first-weeks card is
        // on screen asking for one, so the gain card must defer to it rather
        // than fall through to "two weighings needed".
        XCTAssertEqual(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                      birthDate: birth(daysAgo: 3),
                                                      measurements: [],
                                                      now: now),
                       .firstWeeksNow)
        // Past the window with nothing to pair: no deferral, and the card falls
        // back to its own "two weighings needed" hint.
        XCTAssertNil(NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeight,
                                                    birthDate: birth(daysAgo: 40),
                                                    measurements: [],
                                                    now: now))
    }

    // MARK: - After the window

    func testOrdinaryRulesResumeAfterTheWindow() throws {
        let birth = birth(daysAgo: 40)
        let measurements = [
            WeightMeasurement(date: date(dayOfLife: 30, from: birth), weightKg: 4.00),
            WeightMeasurement(date: date(dayOfLife: 40, from: birth), weightKg: 4.03),
        ]
        let assessment = try XCTUnwrap(assess(birth: birth,
                                              birthWeightKg: birthWeight,
                                              measurements: measurements))
        XCTAssertEqual(assessment.gain, .below)
        XCTAssertTrue(assessment.warrantsBreakdown)
    }

    /// The case the gate is deliberately NOT shaped around the measured pair:
    /// a day-30 baby whose only two weighings are the birth one and today's.
    /// The pair reaches back into the newborn window and is still measured
    /// honestly, because `WeightVelocity` compares it at the interval's
    /// midpoint age — the age the average actually describes.
    func testAPairSpanningBackToBirthIsMeasuredHonestlyAfterTheWindow() throws {
        let birth = birth(daysAgo: 30)
        let measurements = [
            WeightMeasurement(date: birth, weightKg: 3.5),
            WeightMeasurement(date: date(dayOfLife: 30, from: birth), weightKg: 4.4),
        ]
        XCTAssertFalse(NewbornWeightLoss.windowActive(birthWeightKg: birthWeight,
                                                      birthDate: birth, now: now))

        let reading = try XCTUnwrap(WeightVelocity.latest(measurements: measurements,
                                                          correctedBirthDate: birth,
                                                          isMale: false))
        XCTAssertEqual(reading.gramsPerDay, 30, accuracy: 0.5)
        XCTAssertEqual(reading.band, .within,
                       "900 g over the first month is a healthy month and must read as one")

        let assessment = try XCTUnwrap(assess(birth: birth,
                                              birthWeightKg: birthWeight,
                                              measurements: measurements))
        XCTAssertEqual(assessment.gain, .within)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }
}

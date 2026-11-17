import XCTest
import SwiftData
@testable import BabyBloom

/// The dose rules, pinned. Dates come from a fixed Europe/Berlin calendar so
/// the DST cases read the same on any machine.
@MainActor
final class MedicineScheduleTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    /// Wall-clock time in Berlin.
    private func t(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day,
                                      hour: hour, minute: minute, second: second))!
    }

    /// An ordinary June day, no clock change near it.
    private func d(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date { t(6, day, hour, minute) }

    private func schedule(hours: Double = 6, max: Int? = nil, _ doses: [Date], now: Date) -> MedicineSchedule {
        MedicineSchedule(intervalMinutes: Int(hours * 60), maxDosesPer24h: max, doseTimes: doses, now: now)
    }

    // MARK: Container helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        return ModelContext(container)
    }

    private func makeMedicine(_ context: ModelContext, name: String = "Paracetamol",
                              minutes: Int = 360, max: Int? = nil) -> Medicine {
        let baby = Baby(name: "Mia", birthDate: d(1, 8), gender: .female, feedingType: .breast)
        context.insert(baby)
        let medicine = Medicine(name: name, intervalMinutes: minutes, doseText: "2.5 ml")
        medicine.maxDosesPer24h = max
        medicine.baby = baby
        context.insert(medicine)
        return medicine
    }

    @discardableResult
    private func give(_ medicine: Medicine, _ time: Date, in context: ModelContext) -> CustomEvent {
        let dose = CustomEvent.dose(of: medicine, at: time)
        context.insert(dose)
        return dose
    }

    // MARK: Last dose and next allowed

    func testNoDoseMeansNoLastDoseAndNoNextAllowed() throws {
        let s = schedule([], now: d(10, 12))
        XCTAssertNil(s.lastDose)
        XCTAssertNil(s.nextAllowed)

        let context = try makeContext()
        let medicine = makeMedicine(context)
        try context.save()
        XCTAssertEqual(medicine.status(now: d(10, 12)), .noDose)
    }

    func testNextAllowedIsLastDosePlusIntervalAcrossMidnight() throws {
        let s = schedule([d(10, 20)], now: d(10, 21))
        XCTAssertEqual(s.nextAllowed, d(11, 2))

        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, d(10, 20), in: context)
        try context.save()
        XCTAssertEqual(medicine.status(now: d(10, 21)), .waiting(lastDose: d(10, 20), until: d(11, 2)))
        XCTAssertEqual(medicine.status(now: t(6, 11, 1, 59, 59)), .waiting(lastDose: d(10, 20), until: d(11, 2)))
    }

    func testStatusIsAllowedAtExactlyTheNextAllowedInstantAndAfter() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, d(10, 20), in: context)
        try context.save()
        XCTAssertEqual(medicine.status(now: d(11, 2)), .allowed(lastDose: d(10, 20)))
        XCTAssertEqual(medicine.status(now: d(11, 9)), .allowed(lastDose: d(10, 20)))
    }

    func testTheIntervalIsElapsedTimeWhenTheClocksGoBack() {
        // Berlin goes back on 2026-10-25 at 03:00: 01:00 + 6 h elapsed is 06:00 on the wall.
        let dose = t(10, 25, 1)
        let s = schedule([dose], now: t(10, 25, 2))
        let next = s.nextAllowed
        XCTAssertEqual(next?.timeIntervalSince(dose), 21600)
        XCTAssertEqual(next, t(10, 25, 6))
        XCTAssertEqual(cal.dateComponents([.hour, .minute], from: next!).hour, 6)
        XCTAssertEqual(t(10, 25, 6).timeIntervalSince(dose), 6 * 3600)
    }

    func testTheIntervalIsElapsedTimeWhenTheClocksGoForward() {
        // 2026-03-29 02:00 -> 03:00: 01:00 + 6 h elapsed reads 08:00.
        let dose = t(3, 29, 1)
        let next = schedule([dose], now: t(3, 29, 2)).nextAllowed
        XCTAssertEqual(next?.timeIntervalSince(dose), 21600)
        XCTAssertEqual(next, t(3, 29, 8))
    }

    func testAFutureDoseIsIgnoredByLastDoseNextAllowedAndCheck() {
        let now = d(10, 12)
        let s = schedule([d(10, 8), d(10, 13)], now: now)
        XCTAssertEqual(s.lastDose, d(10, 8))
        XCTAssertEqual(s.nextAllowed, d(10, 14))

        let onlyFuture = schedule([d(10, 13)], now: now)
        XCTAssertNil(onlyFuture.lastDose)
        XCTAssertNil(onlyFuture.nextAllowed)
        XCTAssertFalse(onlyFuture.check(d(10, 13, 30)).needsConfirmation)
    }

    func testDosesGivenUnsortedAreReadSorted() {
        let s = schedule([d(10, 14), d(10, 8), d(10, 20), d(10, 2)], now: d(10, 21))
        XCTAssertEqual(s.lastDose, d(10, 20))
        XCTAssertEqual(s.doses, [d(10, 2), d(10, 8), d(10, 14), d(10, 20)])
    }

    // MARK: Check against the interval

    func testADoseExactlyOneIntervalAfterTheLastNeedsNoConfirmation() {
        let s = schedule([d(10, 10)], now: d(10, 20))
        XCTAssertFalse(s.check(d(10, 16)).needsConfirmation)
    }

    func testADoseOneSecondTooSoonNamesTheLastDoseAndWhenItWasAllowed() {
        let s = schedule([d(10, 10)], now: d(10, 20))
        let result = s.check(t(6, 10, 15, 59, 59))
        XCTAssertEqual(result.neighbour, .earlier(dose: d(10, 10), intervalEnds: d(10, 16)))
        XCTAssertNil(result.daily)
        XCTAssertTrue(result.needsConfirmation)
    }

    func testABackDatedDoseBeforeALaterOneNamesTheLaterDose() {
        let s = schedule([d(10, 16)], now: d(10, 20))
        XCTAssertEqual(s.check(d(10, 14)).neighbour, .later(dose: d(10, 16)))
    }

    func testCheckNamesTheNearestCloseDose() {
        // 08:00 is 3 h from 11:00, 13:00 is 2 h: the nearer one is named.
        let s = schedule([d(10, 8), d(10, 13)], now: d(10, 20))
        XCTAssertEqual(s.check(d(10, 11)).neighbour, .later(dose: d(10, 13)))
    }

    func testADoseBetweenTwoLoggedOnesNamesTheLaterOneEvenWhenTheEarlierIsNearer() {
        // 11:00 is 3 h after 08:00 and 5 h before 16:00. The earlier dose's
        // interval ends at 14:00, which is inside the 16:00 dose's interval,
        // so no true «not before» exists: the later dose is named.
        let s = schedule([d(10, 8), d(10, 16)], now: d(10, 20))
        XCTAssertEqual(s.check(d(10, 11)).neighbour, .later(dose: d(10, 16)))
        XCTAssertEqual(s.check(d(10, 12)).neighbour, .later(dose: d(10, 16)), "an exact tie too")
    }

    func testWithOnlyEarlierCloseDosesTheLatestOfThemIsNamed() {
        let s = schedule([d(10, 7), d(10, 9)], now: d(10, 20))
        XCTAssertEqual(s.check(d(10, 10)).neighbour, .earlier(dose: d(10, 9), intervalEnds: d(10, 15)))
    }

    func testMovingADoseByTenMinutesDoesNotFlagItself() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let dose = give(medicine, d(10, 10), in: context)
        try context.save()
        let now = d(10, 20)

        XCTAssertTrue(medicine.check(d(10, 10, 10), now: now).needsConfirmation,
                      "without `editing`, the dose being moved counts as another dose")
        XCTAssertFalse(medicine.check(d(10, 10, 10), now: now, editing: dose).needsConfirmation)
        XCTAssertTrue(medicine.schedule(now: now, excluding: dose).doses.isEmpty)
        XCTAssertEqual(medicine.schedule(now: now).doses, [d(10, 10)])
    }

    // MARK: 24-hour maximum

    func testAFifthDoseInsideTwentyFourHoursNamesTheFullWindow() {
        let doses = [d(10, 2), d(10, 8), d(10, 14), d(10, 20)]
        let s = schedule(hours: 1, max: 4, doses, now: d(11, 5))
        let result = s.check(d(11, 1, 59))
        XCTAssertEqual(result.daily, DoseCheck.Daily(count: 5, max: 4, windowStart: d(10, 2)))
        XCTAssertNil(result.neighbour)
        XCTAssertTrue(result.showsDaily, "the only limit broken")
    }

    func testAFifthDoseExactlyTwentyFourHoursAfterTheFirstIsOutsideTheWindow() {
        let doses = [d(10, 2), d(10, 8), d(10, 14), d(10, 20)]
        let s = schedule(hours: 1, max: 4, doses, now: d(11, 5))
        XCTAssertNil(s.check(d(11, 2)).daily)
        XCTAssertFalse(s.check(d(11, 2)).needsConfirmation)
    }

    func testABackDatedDoseThatPushesALaterWindowOverTheMaximumIsFlagged() {
        // The new 14:00 dose sits between 08:00 and 20:00; the window that
        // starts at 08:00 then holds 08, 14, 20 against a maximum of 2.
        let s = schedule(hours: 0.5, max: 2, [d(10, 8), d(10, 20)], now: d(10, 22))
        XCTAssertEqual(s.check(d(10, 14)).daily, DoseCheck.Daily(count: 3, max: 2, windowStart: d(10, 8)))

        // Back-dated before two later doses: the window starting at the new dose.
        let later = schedule(hours: 0.5, max: 2, [d(10, 12), d(10, 13)], now: d(10, 22))
        XCTAssertEqual(later.check(d(10, 11)).daily, DoseCheck.Daily(count: 3, max: 2, windowStart: d(10, 11)))
    }

    func testNextAllowedWaitsForTheOldestOfTheLastFourToBeADayOldWhenFourFitInADay() {
        let doses = [d(10, 8), d(10, 9), d(10, 10), d(10, 11)]
        let s = schedule(hours: 1, max: 4, doses, now: d(10, 11, 30))
        XCTAssertEqual(s.nextAllowed, d(11, 8))
        XCTAssertGreaterThan(s.nextAllowed!, d(10, 12))
    }

    func testNextAllowedIsJustLastPlusIntervalUnderTheMaximum() {
        let doses = [d(10, 9), d(10, 10), d(10, 11)]
        let s = schedule(hours: 1, max: 4, doses, now: d(10, 11, 30))
        XCTAssertEqual(s.nextAllowed, d(10, 12))
    }

    func testTheCountInTheLast24HoursLeavesOutADoseExactlyADayOldAndAFutureOne() {
        let doses = [d(9, 12), d(9, 13), d(10, 2), d(10, 8), d(10, 14)]
        // At 12:00 the 9th's 12:00 is exactly a day old and 14:00 has not come.
        XCTAssertEqual(schedule(hours: 1, max: 4, doses, now: d(10, 12)).dosesInLast24Hours, 3)
        XCTAssertEqual(schedule(hours: 1, max: 4, doses, now: d(10, 13)).dosesInLast24Hours, 2)
    }

    // MARK: Which limit the one confirmation names

    func testTheMaximumIsNamedWhenItHoldsTheNextDoseBackPastTheIntervalsEnd() {
        // Every 4 h, at most 4 a day: after 06, 10, 14 and 18 the next is not
        // before 06:00 tomorrow, so a dose at 20:00 names the maximum.
        let s = schedule(hours: 4, max: 4, [d(10, 6), d(10, 10), d(10, 14), d(10, 18)], now: d(10, 20))
        XCTAssertEqual(s.nextAllowed, d(11, 6))
        let result = s.check(d(10, 20))
        XCTAssertEqual(result.neighbour, .earlier(dose: d(10, 18), intervalEnds: d(10, 22)))
        XCTAssertEqual(result.daily?.count, 5)
        XCTAssertTrue(result.showsDaily)
    }

    func testOnATieBetweenTheTwoLimitsOnceSavedTheIntervalIsNamed() {
        // Every 16 h, at most 2. With the 08:00 dose both limits end at
        // midnight: the interval from 08:00, the maximum from 00:00.
        let s = schedule(hours: 16, max: 2, [d(9, 20), d(10, 0)], now: d(10, 9))
        let result = s.check(d(10, 8))
        XCTAssertEqual(result.neighbour, .earlier(dose: d(10, 0), intervalEnds: d(10, 16)))
        XCTAssertEqual(result.daily?.count, 3)
        XCTAssertEqual(s.nextAllowed(adding: d(10, 8)), d(11, 0))
        XCTAssertFalse(result.showsDaily)
    }

    /// The limits are compared as they end once this dose is saved, the time
    /// the confirmation states. Before it both end at 02:00 tomorrow; with
    /// the 01:00 dose the interval ends at 07:00 and the maximum at 08:00.
    func testATieBeforeTheSaveNamesTheMaximumThatEndsLaterAfterIt() {
        let s = schedule(hours: 6, max: 4, [d(10, 2), d(10, 8), d(10, 14), d(10, 20)], now: d(11, 1))
        XCTAssertEqual(s.nextAllowed, d(11, 2))
        let result = s.check(d(11, 1))
        XCTAssertEqual(result.neighbour, .earlier(dose: d(10, 20), intervalEnds: d(11, 2)))
        XCTAssertNotNil(result.daily)
        XCTAssertEqual(s.nextAllowed(adding: d(11, 1)), d(11, 8))
        XCTAssertTrue(result.showsDaily)
    }

    /// A dose inside the interval that brings the count to the maximum, not
    /// over it, breaks the interval only; the maximum still sets the time.
    func testADoseThatReachesTheMaximumIsAnIntervalCheckWithTheMaximumsTime() {
        let s = schedule(hours: 6, max: 3, [d(10, 0), d(10, 7)], now: d(10, 9))
        let result = s.check(d(10, 8))
        XCTAssertEqual(result.neighbour, .earlier(dose: d(10, 7), intervalEnds: d(10, 13)))
        XCTAssertNil(result.daily)
        XCTAssertEqual(s.nextAllowed(adding: d(10, 8)), d(11, 0))
    }

    /// Every 6 h, at most 4: 02:02, 08:02, 14:06 and 21:06 logged, a dose
    /// put at 09:10. Once saved the interval ends at 03:06 tomorrow (after
    /// 21:06) and the maximum at 08:02 tomorrow, so the maximum is named,
    /// with the time the medication's screen shows after the save.
    func testADosePutBeforeALoggedOneNamesTheMaximumWhenItEndsLaterOnceSaved() {
        let doses = [d(10, 2, 2), d(10, 8, 2), d(10, 14, 6), d(10, 21, 6)]
        let s = schedule(hours: 6, max: 4, doses, now: d(10, 21, 11))
        let result = s.check(d(10, 9, 10))
        XCTAssertEqual(result.neighbour, .later(dose: d(10, 14, 6)))
        XCTAssertEqual(result.daily?.count, 5)
        XCTAssertTrue(result.showsDaily)
        XCTAssertEqual(s.nextAllowed(adding: d(10, 9, 10)), d(11, 8, 2))
    }

    /// Every 20 h, at most 2, a dose put before both logged ones. With 06:00
    /// and 10:00 logged and the dose at 05:00, both limits end at 06:00
    /// tomorrow once saved (10:00 + 20 h; 06:00 a day old): a tie. With
    /// 00:00 and 10:00 logged and the dose at 23:00 the day before, the
    /// interval ends at 06:00 tomorrow and the maximum at 00:00: later.
    func testADosePutBeforeALoggedOneNamesTheIntervalOnATieOrWhenItEndsLater() {
        let tie = schedule(hours: 20, max: 2, [d(10, 6), d(10, 10)], now: d(10, 12))
        let tied = tie.check(d(10, 5))
        XCTAssertEqual(tied.neighbour, .later(dose: d(10, 6)))
        XCTAssertEqual(tied.daily?.count, 3)
        XCTAssertEqual(tie.nextAllowed(adding: d(10, 5)), d(11, 6))
        XCTAssertFalse(tied.showsDaily, "a tie names the interval")

        let later = schedule(hours: 20, max: 2, [d(10, 0), d(10, 10)], now: d(10, 12))
        let result = later.check(d(9, 23))
        XCTAssertEqual(result.neighbour, .later(dose: d(10, 0)))
        XCTAssertEqual(result.daily?.count, 3)
        XCTAssertEqual(later.nextAllowed(adding: d(9, 23)), d(11, 6))
        XCTAssertFalse(result.showsDaily, "the interval ends later")
    }

    func testAMaximumOfZeroOrLessIsNoMaximum() {
        for max in [0, -3] {
            let doses = [d(10, 8), d(10, 9), d(10, 10), d(10, 11)]
            let s = schedule(hours: 1, max: max, doses, now: d(10, 11, 30))
            XCTAssertNil(s.maxPer24h)
            XCTAssertEqual(s.nextAllowed, d(10, 12))
            XCTAssertNil(s.check(d(10, 12)).daily)
        }
    }

    func testAnIntervalOfZeroOrLessNeverFlags() {
        for minutes in [0, -30] {
            let s = MedicineSchedule(intervalMinutes: minutes, maxDosesPer24h: nil,
                                     doseTimes: [d(10, 10)], now: d(10, 20))
            XCTAssertEqual(s.interval, 0)
            XCTAssertFalse(s.check(d(10, 10)).needsConfirmation)
            XCTAssertFalse(s.check(d(10, 10, 1)).needsConfirmation)
            XCTAssertEqual(s.nextAllowed, d(10, 10))
        }
    }

    // MARK: Medicine in a store

    func testTwoMedicinesAreIndependent() throws {
        let context = try makeContext()
        let a = makeMedicine(context, name: "Paracetamol")
        let b = Medicine(name: "Vitamin D", intervalMinutes: 1440, doseText: "1 drop")
        b.baby = a.baby
        context.insert(b)
        give(a, d(10, 10), in: context)
        try context.save()
        let now = d(10, 11)

        XCTAssertEqual(b.status(now: now), .noDose)
        XCTAssertFalse(b.check(d(10, 10, 30), now: now).needsConfirmation)
        XCTAssertEqual(a.status(now: now), .waiting(lastDose: d(10, 10), until: d(10, 16)))
    }

    func testALinkedEventOfAnotherTypeIsNotADose() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let event = give(medicine, d(10, 10), in: context)
        event.type = .bath
        try context.save()

        XCTAssertTrue(medicine.doseTimes().isEmpty)
        XCTAssertEqual(medicine.status(now: d(10, 11)), .noDose)
    }

    func testAFreeTextMedicationEventWithTheSameNameIsNotCounted() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let free = CustomEvent(time: d(10, 10), type: .medication)
        free.medicationName = medicine.name
        free.baby = medicine.baby
        context.insert(free)
        try context.save()

        XCTAssertEqual(medicine.status(now: d(10, 11)), .noDose)
        XCTAssertTrue(medicine.doseTimes().isEmpty)
    }

    func testAnEndedCourseReportsEndedAndKeepsItsDoses() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, d(10, 10), in: context)
        medicine.endedAt = d(12, 9)
        try context.save()

        XCTAssertEqual(medicine.status(now: d(13, 9)), .ended(d(12, 9)))
        XCTAssertEqual(medicine.doses?.count, 1)
    }

    func testDeletingTheLatestDoseFallsBackToTheOneBefore() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, d(10, 8), in: context)
        let latest = give(medicine, d(10, 14), in: context)
        try context.save()
        let now = d(10, 15)
        XCTAssertEqual(medicine.status(now: now), .waiting(lastDose: d(10, 14), until: d(10, 20)))

        context.delete(latest)
        try context.save()
        XCTAssertEqual(medicine.status(now: now), .allowed(lastDose: d(10, 8)))
    }

    func testEditingADosesTimeMovesTheWaitAccordingly() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let dose = give(medicine, d(10, 10), in: context)
        try context.save()
        let now = d(10, 12)
        XCTAssertEqual(medicine.status(now: now), .waiting(lastDose: d(10, 10), until: d(10, 16)))

        dose.time = d(10, 11)
        try context.save()
        XCTAssertEqual(medicine.status(now: now), .waiting(lastDose: d(10, 11), until: d(10, 17)))

        dose.time = d(10, 9)
        try context.save()
        XCTAssertEqual(medicine.status(now: now), .waiting(lastDose: d(10, 9), until: d(10, 15)))
    }
}

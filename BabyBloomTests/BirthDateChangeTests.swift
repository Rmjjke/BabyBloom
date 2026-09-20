import XCTest
@testable import BabyBloom

/// The rules that keep a corrected birth date and the growth history describing
/// the same baby.
///
/// The re-dating assertions fail on the previous behaviour by construction:
/// there was no re-dating at all, so a birth date moved forward left the
/// onboarding birth measurement stranded before the birth.
final class BirthDateChangeTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        let midnight = calendar.startOfDay(for: Date())
        let shifted = calendar.date(byAdding: .day, value: day, to: midnight)!
        return calendar.date(byAdding: .minute, value: hour * 60 + minute, to: shifted)!
    }

    private func entry(_ date: Date, weightKg: Double? = 3.5, heightCm: Double? = nil) -> GrowthEntry {
        GrowthEntry(date: date, weightKg: weightKg, heightCm: heightCm)
    }

    // MARK: - entriesToRedate

    /// Onboarding's own entry: dated at the birth INSTANT, so it must move.
    func testRedatesTheEntryDatedAtTheBirthInstant() {
        let birth = date(-10, hour: 9)
        let birthEntry = entry(birth)

        let moving = BirthDateChange.entriesToRedate(entries: [birthEntry],
                                                     oldBirthDate: birth,
                                                     calendar: calendar)

        XCTAssertEqual(moving.count, 1)
        XCTAssertIdentical(moving.first, birthEntry)
    }

    /// The hand-entered variant: same calendar day, whatever clock the sheet
    /// happened to stamp on it. A birth measurement is a birth measurement.
    func testRedatesABirthDayEntryRecordedAtAnotherTime() {
        let birth = date(-10, hour: 9)
        let sameDay = entry(date(-10, hour: 21))

        let moving = BirthDateChange.entriesToRedate(entries: [sameDay],
                                                     oldBirthDate: birth,
                                                     calendar: calendar)

        XCTAssertEqual(moving.count, 1)
    }

    /// Two on the birth day — onboarding's, plus a hand-entered correction —
    /// and BOTH are birth measurements, so both follow the date.
    func testRedatesEveryEntryOnTheBirthDay() {
        let birth = date(-10, hour: 9)
        let hospital = entry(birth)
        let correction = entry(date(-10, hour: 18), weightKg: 3.45)
        let dayOne = entry(date(-9, hour: 10))

        let moving = BirthDateChange.entriesToRedate(entries: [hospital, correction, dayOne],
                                                     oldBirthDate: birth,
                                                     calendar: calendar)

        XCTAssertEqual(moving.count, 2)
        XCTAssertTrue(moving.contains { $0 === hospital })
        XCTAssertTrue(moving.contains { $0 === correction })
    }

    /// Day one is a real weighing. It happened when it happened.
    func testLeavesADayOneEntryAlone() {
        let birth = date(-10, hour: 9)
        let dayOne = entry(date(-9, hour: 9))
        let birthEntry = entry(birth)

        let moving = BirthDateChange.entriesToRedate(entries: [birthEntry, dayOne],
                                                     oldBirthDate: birth,
                                                     calendar: calendar)

        XCTAssertEqual(moving.count, 1)
        XCTAssertIdentical(moving.first, birthEntry)
    }

    /// An entry dated hours BEFORE the birth instant but on the same day still
    /// belongs to the birth — a strict `>= birthDate` comparison would miss it.
    func testRedatesAnEntryEarlierOnTheBirthDay() {
        let birth = date(-10, hour: 14)
        let earlier = entry(date(-10, hour: 2))

        let moving = BirthDateChange.entriesToRedate(entries: [earlier],
                                                     oldBirthDate: birth,
                                                     calendar: calendar)

        XCTAssertEqual(moving.count, 1)
    }

    func testRedatesNothingWhenThereIsNoHistory() {
        XCTAssertTrue(BirthDateChange.entriesToRedate(entries: [],
                                                      oldBirthDate: date(-10),
                                                      calendar: calendar).isEmpty)
    }

    // MARK: - latestSelectableBirthDate

    /// No history but the birth entry: today is the only cap.
    func testBoundIsTodayWhenOnlyBirthDayEntriesExist() {
        let birth = date(-10, hour: 9)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(entries: [entry(birth)],
                                                              oldBirthDate: birth,
                                                              now: now,
                                                              calendar: calendar)

        XCTAssertEqual(bound, now)
    }

    func testBoundIsTodayWithNoEntriesAtAll() {
        let birth = date(-10, hour: 9)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(entries: [],
                                                              oldBirthDate: birth,
                                                              now: now,
                                                              calendar: calendar)

        XCTAssertEqual(bound, now)
    }

    /// The real bound: the day BEFORE the earliest non-birth-day weighing, not
    /// that weighing's own day — landing on its day would reclassify it as a
    /// birth measurement and let the next edit drag it.
    func testBoundIsTheDayBeforeTheEarliestNonBirthDayMeasurement() {
        let birth = date(-10, hour: 9)
        let dayThree = date(-7, hour: 11)
        let dayEight = date(-2, hour: 11)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(
            entries: [entry(birth), entry(dayEight), entry(dayThree)],
            oldBirthDate: birth,
            now: now,
            calendar: calendar
        )

        XCTAssertLessThan(bound, calendar.startOfDay(for: dayThree))
        XCTAssertTrue(calendar.isDate(bound, inSameDayAs: date(-8)),
                      "the bound should sit on the day before the first weighing")
    }

    /// A height-only entry is a measurement too: it bounds the birth date
    /// exactly like a weighing, because it is equally impossible before birth.
    func testAHeightOnlyEntrySetsTheBound() {
        let birth = date(-10, hour: 9)
        let heightOnly = entry(date(-6, hour: 11), weightKg: nil, heightCm: 54)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(entries: [entry(birth), heightOnly],
                                                              oldBirthDate: birth,
                                                              now: now,
                                                              calendar: calendar)

        XCTAssertTrue(calendar.isDate(bound, inSameDayAs: date(-7)))
    }

    /// A measurement recorded moments ago still takes its whole day out: `now`
    /// does not rescue today, because today holds a measurement.
    func testAMeasurementDatedNowTakesTodayOut() {
        let birth = date(-10, hour: 9)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(entries: [entry(birth), entry(now)],
                                                              oldBirthDate: birth,
                                                              now: now,
                                                              calendar: calendar)

        XCTAssertLessThan(bound, calendar.startOfDay(for: now))
        XCTAssertTrue(calendar.isDate(bound, inSameDayAs: date(-1)))
    }

    /// Bad data already in the store (a weighing on or before the birth day)
    /// must not produce a bound below the picker's own selection — it collapses
    /// to "you may not move it forward".
    func testBoundNeverFallsBelowTheCurrentBirthDate() {
        let birth = date(-10, hour: 9)
        let stranded = date(-12, hour: 11)
        let now = date(0, hour: 12)

        let bound = BirthDateChange.latestSelectableBirthDate(
            entries: [entry(birth), entry(stranded)],
            oldBirthDate: birth,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(bound, birth)
    }

    // MARK: - commit

    /// The ordinary case: a date well inside the range is stored as picked.
    func testCommitKeepsADateInsideTheBound() {
        let birth = date(-10, hour: 9)
        let picked = date(-8, hour: 9)
        let now = date(0, hour: 12)

        let committed = BirthDateChange.commit(selected: picked,
                                               oldBirthDate: birth,
                                               entries: [entry(birth), entry(date(-4, hour: 11))],
                                               now: now,
                                               calendar: calendar)

        XCTAssertEqual(committed, picked)
    }

    /// The day-vs-instant rule on the measurement side. The picker enforces its
    /// range in DAYS, so the commit — not the control — is what guarantees the
    /// stored instant stays off the first weighing's day.
    func testCommitClampsASelectionOnTheFirstWeighingsDay() {
        let birth = date(-10, hour: 23, minute: 30)
        let firstWeighing = date(-4, hour: 11)
        let now = date(0, hour: 12)
        let picked = date(-4, hour: 23, minute: 30)

        let committed = BirthDateChange.commit(selected: picked,
                                               oldBirthDate: birth,
                                               entries: [entry(birth), entry(firstWeighing)],
                                               now: now,
                                               calendar: calendar)

        XCTAssertLessThan(committed, calendar.startOfDay(for: firstWeighing))
        XCTAssertTrue(calendar.isDate(committed, inSameDayAs: date(-5)))
    }

    /// A store that already holds a weighing before the birth: the bound floors
    /// at the current birth date, and the commit holds the line there rather
    /// than storing a selection that would strand it further.
    func testCommitRefusesToMoveForwardWhenAWeighingPredatesTheBirth() {
        let birth = date(-10, hour: 9)
        let stranded = date(-12, hour: 11)
        let now = date(0, hour: 12)

        let committed = BirthDateChange.commit(selected: date(-3, hour: 9),
                                               oldBirthDate: birth,
                                               entries: [entry(birth), entry(stranded)],
                                               now: now,
                                               calendar: calendar)

        XCTAssertEqual(committed, birth)
    }

    /// Same rule at the other end: "today" picked at an hour that has not
    /// arrived yet cannot store a birth date in the future.
    func testCommitClampsTodayToNow() {
        let birth = date(-10, hour: 23)
        let now = date(0, hour: 9)
        let picked = date(0, hour: 23)

        let committed = BirthDateChange.commit(selected: picked,
                                               oldBirthDate: birth,
                                               entries: [entry(birth)],
                                               now: now,
                                               calendar: calendar)

        XCTAssertEqual(committed, now)
    }

    /// The whole point of excluding the first weighing's DAY: after a birth date
    /// is moved as far forward as it will go, a SECOND edit must still see that
    /// weighing as a weighing — not as a birth measurement to drag along.
    func testASecondEditCannotDragTheFirstWeighing() {
        let birth = date(-10, hour: 9)
        let firstWeighing = entry(date(-4, hour: 11), weightKg: 3.25)
        let birthEntry = entry(birth)
        let now = date(0, hour: 12)
        let entries = [birthEntry, firstWeighing]

        // Edit one: move the date as far forward as the picker allows.
        let movedTo = BirthDateChange.commit(selected: now,
                                             oldBirthDate: birth,
                                             entries: entries,
                                             now: now,
                                             calendar: calendar)
        for moving in BirthDateChange.entriesToRedate(entries: entries,
                                                      oldBirthDate: birth,
                                                      calendar: calendar) {
            moving.date = movedTo
        }
        XCTAssertEqual(birthEntry.date, movedTo)
        XCTAssertFalse(calendar.isDate(movedTo, inSameDayAs: firstWeighing.date),
                       "the new birth date must not land on the weighing's day")

        // Edit two: the weighing is still not a birth measurement…
        let movingNow = BirthDateChange.entriesToRedate(entries: entries,
                                                        oldBirthDate: movedTo,
                                                        calendar: calendar)
        XCTAssertEqual(movingNow.count, 1)
        XCTAssertIdentical(movingNow.first, birthEntry)

        // …and there is nowhere further forward to go.
        XCTAssertEqual(BirthDateChange.commit(selected: now,
                                              oldBirthDate: movedTo,
                                              entries: entries,
                                              now: now,
                                              calendar: calendar),
                       movedTo)
        XCTAssertEqual(firstWeighing.date, date(-4, hour: 11))
    }
}

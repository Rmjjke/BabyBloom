import XCTest
@testable import BabyBloom

/// The two rules that keep a corrected birth date and the growth history
/// describing the same baby.
///
/// The re-dating assertions fail on the previous behaviour by construction:
/// there was no re-dating at all, so a birth date moved forward left the
/// onboarding birth measurement stranded before the birth.
final class BirthDateChangeTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ day: Int, hour: Int = 0) -> Date {
        let midnight = calendar.startOfDay(for: Date())
        let shifted = calendar.date(byAdding: .day, value: day, to: midnight)!
        return calendar.date(byAdding: .hour, value: hour, to: shifted)!
    }

    private func entry(_ date: Date, weightKg: Double = 3.5) -> GrowthEntry {
        GrowthEntry(date: date, weightKg: weightKg)
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

    /// The real bound: a day-3 weighing fixes the birth at day 3 or earlier, so
    /// no measurement can end up dated before the birth.
    func testBoundIsTheEarliestNonBirthDayMeasurement() {
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

        XCTAssertEqual(bound, dayThree)
    }

    /// Bad data already in the store (a weighing dated before the birth) must
    /// not produce a bound below the picker's own selection — it collapses to
    /// "you may not move it forward".
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
}

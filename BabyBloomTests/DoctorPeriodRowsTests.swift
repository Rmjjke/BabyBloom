import XCTest
@testable import BabyBloom

/// Period length, visit-row order and the note preview. Plain objects, no store.
final class DoctorPeriodRowsTests: XCTestCase {

    private let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func visit(_ day: String, created: String) -> DoctorVisit {
        let v = DoctorVisit(date: date(day))
        v.createdAt = date(created)
        return v
    }

    func testPeriodDaysIsZeroOnTheVisitDay() {
        XCTAssertEqual(DoctorPeriod.periodDays(from: date("2026-11-01T00:00:00Z"),
                                               to: date("2026-11-01T23:59:00Z"),
                                               calendar: utc), 0)
    }

    func testPeriodDaysCountsCalendarDays() {
        XCTAssertEqual(DoctorPeriod.periodDays(from: date("2026-10-12T00:00:00Z"),
                                               to: date("2026-11-01T09:00:00Z"),
                                               calendar: utc), 20)
    }

    /// The 25 h day must not read as two days (or zero) because of the clock change.
    func testPeriodDaysAcrossTheDSTEndIsOneDay() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let start = ny.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 0))!
        let now = ny.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23, minute: 30))!
        XCTAssertEqual(DoctorPeriod.periodDays(from: start, to: now, calendar: ny), 1)
    }

    func testPeriodDaysNeverNegative() {
        XCTAssertEqual(DoctorPeriod.periodDays(from: date("2026-11-02T00:00:00Z"),
                                               to: date("2026-11-01T12:00:00Z"),
                                               calendar: utc), 0)
    }

    func testNewestFirstOrdersByDateThenLoggedLast() {
        let a = visit("2026-10-10T00:00:00Z", created: "2026-10-10T12:00:00Z")
        let b = visit("2026-10-10T00:00:00Z", created: "2026-10-10T20:00:00Z")
        let c = visit("2026-10-01T00:00:00Z", created: "2026-10-31T09:00:00Z")
        let sorted = DoctorPeriod.newestFirst([a, c, b])
        XCTAssertTrue(sorted[0] === b && sorted[1] === a && sorted[2] === c)
        XCTAssertTrue(sorted.first === DoctorPeriod.latestVisit([a, c, b]))
    }

    func testNoteFirstLineSkipsBlankLines() {
        XCTAssertEqual(DoctorPeriod.noteFirstLine("\n  \nVitamin D: 1 drop\nNext in a month"),
                       "Vitamin D: 1 drop")
        XCTAssertNil(DoctorPeriod.noteFirstLine("   "))
        XCTAssertNil(DoctorPeriod.noteFirstLine(nil))
    }
}

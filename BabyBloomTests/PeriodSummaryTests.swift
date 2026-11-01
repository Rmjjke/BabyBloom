import XCTest
@testable import BabyBloom

/// The day rules the weekly card and the pediatrician report share. The
/// weekly card's own behaviour stays pinned by `WeeklySummaryTests`.
final class PeriodSummaryTests: XCTestCase {

    /// Europe/Berlin: the clocks go back on 25 Oct 2026, so 25 Oct is 25 h long.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Since a visit on 12 Oct (00:00) to 1 Nov 09:00: 21 calendar days, the
    /// last one partial.
    func testSinceAVisitCountsEveryCalendarDayIncludingThePartialLastOne() {
        let p = PeriodSummary.make(start: at(12, 0), end: at(1, 9, month: 11),
                                   input: .init(feeds: [at(12, 7), at(31, 23), at(1, 8, month: 11)]),
                                   calendar: calendar)
        XCTAssertEqual(p.dayCount, 21)
        XCTAssertEqual(p.feedsByDay.first, 1)
        XCTAssertEqual(p.feedsByDay[19], 1, "31 Oct is day 19")
        XCTAssertEqual(p.feedsByDay.last, 1, "the partial last day is a day")
        XCTAssertEqual(p.daysWithEntries, 3)
    }

    /// The period crossing the DST change has no missing and no doubled day:
    /// an entry late on 25 Oct (a 25 h day) stays on 25 Oct.
    func testAPeriodAcrossTheDSTChangeKeepsEveryEntryOnItsDay() {
        let p = PeriodSummary.make(start: at(24, 0), end: at(27, 0),
                                   input: .init(feeds: [at(24, 12), at(25, 23, 30), at(26, 0, 30)]),
                                   calendar: calendar)
        XCTAssertEqual(p.dayCount, 3)
        XCTAssertEqual(p.feedsByDay, [1, 1, 1])
    }

    /// Since birth mid-morning: the birth day is day 0, and nothing before the
    /// start counts even on the same calendar day.
    func testSinceBirthStartsMidDay() {
        let p = PeriodSummary.make(start: at(1, 10), end: at(3, 12),
                                   input: .init(feeds: [at(1, 9), at(1, 11), at(3, 11)]),
                                   calendar: calendar)
        XCTAssertEqual(p.dayCount, 3)
        XCTAssertEqual(p.feedsByDay, [1, 0, 1])
    }

    func testAnEmptyPeriodHasNoDaysWithEntries() {
        let p = PeriodSummary.make(start: at(12, 0), end: at(20, 0), input: .init(), calendar: calendar)
        XCTAssertEqual(p.dayCount, 8)
        XCTAssertEqual(p.daysWithEntries, 0)
        XCTAssertNil(p.longestSleep)
        XCTAssertNil(p.longestSleepStart)
    }

    /// A period ending exactly at midnight does not gain an empty extra day.
    func testAnEndAtMidnightClosesOnTheDayBefore() {
        XCTAssertEqual(PeriodSummary.dayCount(start: at(12, 0), end: at(19, 0), calendar: calendar), 7)
        XCTAssertEqual(PeriodSummary.dayCount(start: at(12, 0), end: at(12, 0), calendar: calendar), 0)
    }

    /// A sleep is filed whole on its start day; the longest keeps its start.
    func testSleepsAreFiledOnTheirStartDayAndTheLongestKeepsItsDate() {
        let night = (start: at(13, 21), end: at(14, 5))   // 8 h
        let nap = (start: at(14, 13), end: at(14, 14))    // 1 h
        let p = PeriodSummary.make(start: at(12, 0), end: at(15, 0),
                                   input: .init(sleeps: [night, nap]), calendar: calendar)
        XCTAssertEqual(p.sleepByDay, [0, 8.0 * 3600, 3600])
        XCTAssertEqual(p.longestSleep, 8 * 3600)
        XCTAssertEqual(p.longestSleepStart, at(13, 21))
    }
}

import XCTest
@testable import BabyBloom

/// Recent activity mixes days: a row from an earlier day carries its date, as
/// the history rows do, and today's rows keep the time alone.
final class RecentActivityDayLabelTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 11, day: day, hour: hour, minute: minute).date!
    }

    override func tearDown() {
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// Just past midnight, last night's rows are dated; tonight's are not.
    func testJustPastMidnightYesterdaysRowsCarryTheirDate() {
        let now = date(8, 0, 2)
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let lateLastNight = date(7, 23, 42)
            XCTAssertEqual(RecentEvent.dayLabel(for: lateLastNight, now: now), lateLastNight.appDayMonth,
                           "\(language): yesterday 23:42 is dated")
            XCTAssertNil(RecentEvent.dayLabel(for: date(8, 0, 1), now: now),
                         "\(language): a row from this new day keeps the time alone")
        }
    }

    func testTheWholeOfTodayIsUndatedAndAnyEarlierDayIsDated() {
        let now = date(8, 23, 59)
        XCTAssertNil(RecentEvent.dayLabel(for: date(8, 0, 0), now: now))
        XCTAssertNil(RecentEvent.dayLabel(for: date(8, 23, 58), now: now))
        XCTAssertEqual(RecentEvent.dayLabel(for: date(7, 23, 59), now: now), date(7, 23, 59).appDayMonth)
        XCTAssertEqual(RecentEvent.dayLabel(for: date(1, 12), now: now), date(1, 12).appDayMonth)
    }

    /// The date is the history rows' own form, «Nov 7» / «7 нояб.» / «7 nov».
    func testTheDateIsTheHistoryRowsForm() {
        LocalizationManager.shared.setLanguage(.en)
        let label = RecentEvent.dayLabel(for: date(7, 23, 42), now: date(8, 0, 2))
        XCTAssertEqual(label, "Nov 7")
    }
}

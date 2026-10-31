import XCTest
@testable import BabyBloom

/// The Monday notification: 10:00 (D9), only for a week with entries (Q7),
/// never with the switch off (D26).
final class WeeklyNotificationPlanTests: XCTestCase {

    private let calendar = WeeklySummary.calendar

    private func date(_ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    func testFiresNextMondayAtTenForTheWeekNowRunning() {
        var asked: WeeklySummary.Week?
        let fire = WeeklyNotificationPlan.fireDate(now: date(10, 28, 15), enabled: true) {
            asked = $0; return true
        }
        XCTAssertEqual(fire, date(11, 2, 10))
        XCTAssertEqual(asked?.start, date(10, 26, 0), "it reports the week ending at that Monday")
    }

    /// Monday before 10:00: today, about the week that just ended.
    func testMondayMorningFiresTodayAboutLastWeek() {
        var asked: WeeklySummary.Week?
        let fire = WeeklyNotificationPlan.fireDate(now: date(10, 26, 9, 59), enabled: true) {
            asked = $0; return true
        }
        XCTAssertEqual(fire, date(10, 26, 10))
        XCTAssertEqual(asked?.start, date(10, 19, 0))
    }

    /// At 10:00 sharp it has fired already; the next one is a week away.
    func testAtTenTheNextIsAWeekAway() {
        XCTAssertEqual(WeeklyNotificationPlan.fireDate(now: date(10, 26, 10), enabled: true) { _ in true },
                       date(11, 2, 10))
    }

    func testAnEmptyWeekSendsNothing() {
        XCTAssertNil(WeeklyNotificationPlan.fireDate(now: date(10, 28, 15), enabled: true) { _ in false })
    }

    func testTheSwitchOffSendsNothing() {
        XCTAssertNil(WeeklyNotificationPlan.fireDate(now: date(10, 28, 15), enabled: false) { _ in true })
    }

    /// Outside 22:00–07:00 by construction (D9).
    func testTheHourIsDaytime() {
        XCTAssertTrue((7..<22).contains(WeeklyNotificationPlan.hour))
    }
}

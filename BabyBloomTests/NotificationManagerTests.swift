import XCTest
@testable import BabyBloom

final class NotificationManagerTests: XCTestCase {

    private let manager = NotificationManager.shared

    // MARK: - Feeding interval table

    func testFeedingIntervalNilAt12Months() {
        // 12+ months is parent-managed: no scheduled feeding reminder.
        XCTAssertNil(manager.feedingInterval(ageMonths: 12))
        XCTAssertNil(manager.feedingInterval(ageMonths: 18))
        // Sanity: younger ages still return a value.
        XCTAssertNotNil(manager.feedingInterval(ageMonths: 0))
        XCTAssertNotNil(manager.feedingInterval(ageMonths: 11))
    }

    // MARK: - Wake-window table

    func testWakeWindowTable() {
        XCTAssertEqual(manager.wakeWindow(ageMonths: 0),  1.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 1),  1.5 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 2),  1.5 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 3),  2.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 5),  2.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 6),  2.5 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 7),  2.5 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 8),  3.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 11), 3.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 12), 4.0 * 3600)
        XCTAssertEqual(manager.wakeWindow(ageMonths: 17), 4.0 * 3600)
        XCTAssertNil(manager.wakeWindow(ageMonths: 18))
    }

    // MARK: - Diaper interval table

    func testDiaperIntervalTable() {
        XCTAssertEqual(manager.diaperInterval(ageMonths: 0),  4 * 3600)
        XCTAssertEqual(manager.diaperInterval(ageMonths: 1),  6 * 3600)
        XCTAssertEqual(manager.diaperInterval(ageMonths: 5),  6 * 3600)
        XCTAssertEqual(manager.diaperInterval(ageMonths: 6),  8 * 3600)
        XCTAssertEqual(manager.diaperInterval(ageMonths: 11), 8 * 3600)
        XCTAssertNil(manager.diaperInterval(ageMonths: 12))
    }

    // MARK: - Smart feeding interval decision

    func testSmartIntervalPreferredOverTable() throws {
        // 3 feedings spaced 2h apart => average 120 min.
        let now = Date()
        let times = [
            now.addingTimeInterval(-3600 * 4),
            now.addingTimeInterval(-3600 * 2),
            now
        ]
        // Smart interval = 120 min * 60 + 10 min buffer = 7800 s.
        let expectedSmart: TimeInterval = 120 * 60 + 10 * 60
        let result = try XCTUnwrap(manager.feedingReminderInterval(ageMonths: 3, recentFeedingTimes: times))
        XCTAssertEqual(result, expectedSmart, accuracy: 1)
        // And it must differ from the age-3 table value (3.5 h).
        XCTAssertNotEqual(result, manager.feedingInterval(ageMonths: 3))
    }

    func testSmartIntervalFallbackUnder3Feedings() {
        // Fewer than 3 recent feedings => fall back to the age-based table.
        let now = Date()
        let times = [now.addingTimeInterval(-3600 * 2), now]
        let result = manager.feedingReminderInterval(ageMonths: 3, recentFeedingTimes: times)
        XCTAssertEqual(result, manager.feedingInterval(ageMonths: 3))
        // Zero recent feedings also falls back.
        let none = manager.feedingReminderInterval(ageMonths: 3, recentFeedingTimes: [])
        XCTAssertEqual(none, manager.feedingInterval(ageMonths: 3))
    }

    // MARK: - Weigh-in cadence

    /// Newborns change fast enough that a few days matter; a toddler does not.
    /// The cadence has to loosen with age or the app turns into a nag.
    func testWeighInCadenceLoosensWithAge() {
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 0), 3)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 13), 3)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 14), 7)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 89), 7)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 90), 14)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 364), 14)
        XCTAssertEqual(manager.weighInIntervalDays(ageDays: 365), 30)
    }

    func testWeighInCadenceIsMonotonic() {
        var previous = 0
        for day in stride(from: 0, through: 400, by: 1) {
            let interval = manager.weighInIntervalDays(ageDays: day)
            XCTAssertGreaterThanOrEqual(interval, previous, "cadence must never tighten with age")
            previous = interval
        }
    }
}

import XCTest
@testable import BabyBloom

final class HistoryMergeTests: XCTestCase {
    private struct R { let id: Int; let date: Date }

    private let cal = Calendar.current
    private var today: Date { cal.startOfDay(for: Date()) }

    private func daysAgo(_ n: Int) -> Date {
        cal.date(byAdding: .day, value: -n, to: today)!
    }

    // MARK: - Generic merge

    func testMergeInterleavesNewestFirst() {
        let windowed = [R(id: 5, date: daysAgo(0)), R(id: 3, date: daysAgo(2)), R(id: 1, date: daysAgo(4))]
        let exempt = [R(id: 4, date: daysAgo(1)), R(id: 2, date: daysAgo(3))]
        let merged = HistoryMerge.merge(windowed, exempt: exempt, date: \.date)
        XCTAssertEqual(merged.map(\.id), [5, 4, 3, 2, 1])
    }

    func testMergeOnATieKeepsTheWindowedRowFirst() {
        let event = CustomEvent(time: today, type: .bath)
        let visit = DoctorVisit(date: today)
        let history = EventsHistory(events: [event], visits: [visit], cutoff: nil)
        guard history.rows.count == 2,
              case .event = history.rows[0], case .visit = history.rows[1] else {
            return XCTFail("expected [event, visit]")
        }
    }

    // MARK: - EventsHistory

    func testAVisitBeyondTheCapStillShows() {
        let now = Date()
        let events = (0..<25).map { i in
            CustomEvent(time: now.addingTimeInterval(-Double(i) * 3600), type: .bath)
        }
        let visit = DoctorVisit(date: daysAgo(3))
        let history = EventsHistory(events: events, visits: [visit], cutoff: nil, cap: 20)
        XCTAssertEqual(history.rows.count, 21)
        XCTAssertEqual(history.events.visible.count, 20)
        guard case .visit = history.rows.last else { return XCTFail("last row should be the visit") }
    }

    func testAVisitOlderThanTheFreeWindowStillShows() {
        let cutoff = HistoryWindow.cutoff(now: Date())
        let recent = CustomEvent(time: daysAgo(1), type: .bath)
        let old = CustomEvent(time: daysAgo(20), type: .walk)
        let visit = DoctorVisit(date: daysAgo(40))
        let history = EventsHistory(events: [recent, old], visits: [visit], cutoff: cutoff)
        XCTAssertEqual(history.rows.count, 2)
        guard case .event(let first) = history.rows[0], first === recent,
              case .visit(let second) = history.rows[1], second === visit else {
            return XCTFail("expected [event(1), visit(40)]")
        }
        XCTAssertTrue(history.events.showsLockedFooter)
    }

    func testAVisitDoesNotRaiseTheLockedFooter() {
        let visit = DoctorVisit(date: daysAgo(40))
        let history = EventsHistory(events: [], visits: [visit], cutoff: HistoryWindow.cutoff(now: Date()))
        XCTAssertFalse(history.events.showsLockedFooter)
        XCTAssertEqual(history.rows.count, 1)
    }

    func testVisitsWithoutEventsAreListedAndNothingIsDeletable() {
        let visits = [DoctorVisit(date: daysAgo(2)), DoctorVisit(date: daysAgo(9))]
        let history = EventsHistory(events: [], visits: visits, cutoff: nil)
        XCTAssertFalse(history.showsEmptyState)
        XCTAssertFalse(history.showsDeleteAll)
        XCTAssertTrue(history.events.deletable.isEmpty)
    }

    func testTwoVisitsOnOneDateListTheLaterLoggedFirst() {
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 10))!
        let earlier = DoctorVisit(date: day)
        earlier.createdAt = cal.date(byAdding: .hour, value: 12, to: day)!
        let later = DoctorVisit(date: day)
        later.createdAt = cal.date(byAdding: .hour, value: 20, to: day)!
        let history = EventsHistory(events: [], visits: [earlier, later], cutoff: nil)
        guard case .visit(let first) = history.rows[0] else { return XCTFail("expected a visit") }
        XCTAssertTrue(first === later)
    }
}

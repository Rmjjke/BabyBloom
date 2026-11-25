import XCTest
@testable import BabyBloom

/// Home's Events section lists today's events, newest first, three at most.
final class HomeEventsTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: 2026, month: 11, day: day, hour: hour, minute: minute).date!
    }

    private struct Item: Equatable {
        let id: Int
        let time: Date
    }

    private func today(_ items: [Item], now: Date) -> [Int] {
        HomeEvents.today(items, time: \.time, now: now, calendar: calendar).map(\.id)
    }

    func testOnlyTheCalendarDayOfNowCounts() {
        let now = date(25, 12)
        let items = [Item(id: 1, time: date(24, 23, 59)),
                     Item(id: 2, time: date(25, 0, 0)),
                     Item(id: 3, time: date(25, 23, 59)),
                     Item(id: 4, time: date(26, 0, 0))]
        XCTAssertEqual(today(items, now: now), [3, 2])
    }

    func testNewestFirstWhateverTheInputOrder() {
        let now = date(25, 12)
        let items = [Item(id: 1, time: date(25, 8)), Item(id: 2, time: date(25, 10)), Item(id: 3, time: date(25, 9))]
        XCTAssertEqual(today(items, now: now), [2, 3, 1])
    }

    func testALaterTimeTodayComesFirst() {
        let now = date(25, 12)
        let items = [Item(id: 1, time: date(25, 11)), Item(id: 2, time: date(25, 18))]
        XCTAssertEqual(today(items, now: now), [2, 1])
    }

    func testTiesKeepTheirOrder() {
        let now = date(25, 12)
        let same = date(25, 9)
        let items = [Item(id: 1, time: same), Item(id: 2, time: same), Item(id: 3, time: same)]
        XCTAssertEqual(today(items, now: now), [1, 2, 3])
    }

    func testNoMoreThanThreeRows() {
        let now = date(25, 20)
        let items = (1...5).map { Item(id: $0, time: date(25, $0)) }
        XCTAssertEqual(today(items, now: now), [5, 4, 3])
        XCTAssertEqual(HomeEvents.limit, 3)
    }

    func testNothingTodayIsEmpty() {
        XCTAssertEqual(today([Item(id: 1, time: date(24, 10))], now: date(25, 12)), [])
    }

    // MARK: isOnHome

    private func onHome(_ id: Int, _ items: [Item], now: Date) -> Bool {
        HomeEvents.isOnHome(id, among: items, id: \.id, time: \.time, now: now, calendar: calendar)
    }

    func testTheNewestThreeOfTodayAreOnHome() {
        let now = date(25, 20)
        let items = (1...3).map { Item(id: $0, time: date(25, $0)) }
        for id in 1...3 { XCTAssertTrue(onHome(id, items, now: now)) }
    }

    func testAFourthEventTodayIsNotOnHome() {
        let now = date(25, 20)
        let items = (1...4).map { Item(id: $0, time: date(25, $0)) }
        XCTAssertFalse(onHome(1, items, now: now))
        XCTAssertTrue(onHome(4, items, now: now))
    }

    func testAnEarlierOrLaterDayIsNotOnHome() {
        let now = date(25, 12)
        let items = [Item(id: 1, time: date(24, 12)), Item(id: 2, time: date(26, 12))]
        XCTAssertFalse(onHome(1, items, now: now))
        XCTAssertFalse(onHome(2, items, now: now))
    }

    // MARK: isOnHome right after a save

    private func onHome(saved: Item, _ items: [Item], now: Date) -> Bool {
        HomeEvents.isOnHome(saved: saved, among: items, id: \.id, time: \.time, now: now, calendar: calendar)
    }

    func testASaveTheQueryHasNotCaughtUpWithStillCounts() {
        let now = date(25, 20)
        let older = (1...2).map { Item(id: $0, time: date(25, $0)) }
        XCTAssertTrue(onHome(saved: Item(id: 9, time: date(25, 10)), older, now: now))
        let full = (1...3).map { Item(id: $0, time: date(25, 10 + $0)) }
        XCTAssertFalse(onHome(saved: Item(id: 9, time: date(25, 10)), full, now: now))
    }

    func testASaveTyingTheThirdRowIsNotOnHome() {
        // A tie is decided against the save: a wrong push still shows it.
        let now = date(25, 20)
        let items = (1...3).map { Item(id: $0, time: date(25, 9)) }
        XCTAssertFalse(onHome(saved: Item(id: 9, time: date(25, 9)), items, now: now))
    }

    func testASaveAlreadyInTheQueryIsNotCountedTwice() {
        let now = date(25, 20)
        let saved = Item(id: 3, time: date(25, 3))
        let items = [Item(id: 1, time: date(25, 1)), Item(id: 2, time: date(25, 2)), saved]
        XCTAssertTrue(onHome(saved: saved, items, now: now))
    }
}

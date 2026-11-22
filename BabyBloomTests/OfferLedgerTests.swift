import XCTest
@testable import BabyBloom

/// The ledger is what keeps an offer from coming back: every event it records
/// and the merge of its two copies are pinned here.
final class OfferLedgerTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    private func at(_ day: Int, _ hour: Int = 12) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let date = calendar.date(byAdding: .day, value: day, to: start)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    func testShownStampsTheMomentTheLastOfferAndTheOpenCard() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstResultPoint, now: at(2))
        XCTAssertEqual(ledger.shownAt(.firstResult), at(2))
        XCTAssertEqual(ledger.lastShownAt, at(2))
        XCTAssertEqual(ledger.open, .init(content: .firstResultPoint, shownAt: at(2)))
        XCTAssertEqual(ledger.updatedAt, at(2))

        // The same card again (Home re-rendered) does not restart the stay.
        ledger.recordShown(.firstResultPoint, now: at(3))
        XCTAssertEqual(ledger.open?.shownAt, at(2))
        XCTAssertEqual(ledger.lastShownAt, at(2))
    }

    func testCloseCountsAndTapEndsTheStreak() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstResultDays, now: at(2))
        ledger.recordClosed(.firstResultDays, now: at(2))
        ledger.recordShown(.firstWeek, now: at(9))
        ledger.recordClosed(.firstWeek, now: at(10))
        XCTAssertEqual(ledger.closesInRow, 2)
        XCTAssertNil(ledger.open)
        XCTAssertEqual(ledger.lastShownAt, at(9), "a close does not move the last shown day")

        ledger.recordShown(.historyEdge, now: at(16))
        ledger.recordTapped(.historyEdge, now: at(16))
        XCTAssertEqual(ledger.closesInRow, 0)
        XCTAssertNil(ledger.open)
    }

    func testATapWithNoCardOnRecordStillCountsAsShown() {
        var ledger = OfferLedger.empty
        ledger.recordTapped(.firstWeek, now: at(4))
        XCTAssertEqual(ledger.shownAt(.firstWeek), at(4))
        XCTAssertEqual(ledger.lastShownAt, at(4))
    }

    func testACloseOnACardNoLongerOpenChangesNothing() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstResultDays, now: at(2))
        XCTAssertEqual(ledger.settle(now: at(5), calendar: calendar), .firstResultDays)
        let settled = ledger
        XCTAssertEqual(settled.closesInRow, 1, "the stay ran out: one close")
        XCTAssertFalse(ledger.recordClosed(.firstResultDays, now: at(5, 13)))
        XCTAssertEqual(ledger, settled, "a stale × is not a second close")
        XCTAssertFalse(ledger.recordClosed(.firstWeek, now: at(5, 14)))
        XCTAssertNil(ledger.shownAt(.firstWeek), "a × on a card never shown stamps nothing")
    }

    func testAMonthReportStampsItsOwnDateEveryTime() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.monthReport, now: at(28))
        ledger.recordTapped(.monthReport, now: at(28))
        ledger.recordShown(.monthReport, now: at(60))
        XCTAssertEqual(ledger.shownAt(.monthReport), at(28), "the moment keeps its first date")
        XCTAssertEqual(ledger.lastMonthReport, at(60))
    }

    func testSettleClosesTheCardOnTheThirdDayAfter() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstWeek, now: at(9, 23))
        XCTAssertNil(ledger.settle(now: at(11, 23), calendar: calendar))
        XCTAssertNotNil(ledger.open)
        XCTAssertEqual(ledger.settle(now: at(12, 0), calendar: calendar), .firstWeek)
        XCTAssertNil(ledger.open)
        XCTAssertEqual(ledger.closesInRow, 1)
        XCTAssertNil(ledger.settle(now: at(13), calendar: calendar), "settles once")
    }

    /// A card left open before a reinstall: the new diary's onboarding ended
    /// after it opened. It is dropped, still counting as shown.
    func testACardOpenedBeforeThisOnboardingEndedIsDroppedAndStillCountsAsShown() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstResultPoint, now: at(2, 9))
        let closes = ledger.closesInRow
        let stamp = ledger.updatedAt
        XCTAssertTrue(ledger.dropCardOpened(before: at(2, 15)))
        XCTAssertNil(ledger.open)
        XCTAssertEqual(ledger.shownAt(.firstResult), at(2, 9), "the moment stays spent")
        XCTAssertEqual(ledger.lastShownAt, at(2, 9), "the pace runs from its date")
        XCTAssertEqual(ledger.closesInRow, closes, "not a close by the person")
        XCTAssertEqual(ledger.updatedAt, stamp, "no newer stamp to win another device's merge")
        XCTAssertFalse(ledger.dropCardOpened(before: at(2, 15)), "once")
    }

    /// A card of this install opened after its onboarding: it stays open,
    /// also when it opened at the very moment onboarding ended.
    func testACardOfThisInstallIsKept() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstWeek, now: at(9))
        let before = ledger
        XCTAssertFalse(ledger.dropCardOpened(before: at(0, 10)))
        XCTAssertFalse(ledger.dropCardOpened(before: at(9)), "opened at the onboarding end")
        XCTAssertEqual(ledger, before)
    }

    /// Through iCloud Keychain a second device that onboarded after a card
    /// opened on the first drops it on its own Home only: the first device's
    /// merge keeps its card, and the second's keeps the drop.
    func testADropOnASecondDeviceLeavesTheFirstDevicesCard() {
        var phone = OfferLedger.empty
        phone.recordShown(.firstResultDays, now: at(3))
        var pad = phone
        XCTAssertTrue(pad.dropCardOpened(before: at(5)))
        XCTAssertEqual(OfferLedger.merge(phone, pad).open?.content, .firstResultDays)
        XCTAssertNil(OfferLedger.merge(pad, phone).open)
    }

    func testTheCohortSpendIsWrittenOnceAndNeverOverAShownMoment() {
        var ledger = OfferLedger.empty
        ledger.recordShown(.firstResultDays, now: at(1))
        ledger.spendAtCohortLaunch([.firstResult, .firstWeek], launchAt: at(5), now: at(6))
        XCTAssertNil(ledger.spentAt(.firstResult))
        XCTAssertEqual(ledger.spentAt(.firstWeek), at(5))
        XCTAssertTrue(ledger.cohortSpent)

        ledger.spendAtCohortLaunch([.historyEdge], launchAt: at(7), now: at(7))
        XCTAssertNil(ledger.spentAt(.historyEdge))
    }

    func testPremiumIsNotedOnceADay() {
        var ledger = OfferLedger.empty
        XCTAssertTrue(ledger.notePremium(now: at(3, 9), calendar: calendar))
        XCTAssertFalse(ledger.notePremium(now: at(3, 20), calendar: calendar))
        XCTAssertTrue(ledger.notePremium(now: at(4, 9), calendar: calendar))
        XCTAssertEqual(ledger.lastSeenPremiumAt, at(4, 9))
    }

    func testMergeKeepsEveryUsedMomentAndTheSlowerPace() {
        var phone = OfferLedger.empty
        phone.recordShown(.firstResultDays, now: at(2))
        phone.recordClosed(.firstResultDays, now: at(2))

        var keychain = OfferLedger.empty
        keychain.recordShown(.firstResultPoint, now: at(1))
        keychain.recordTapped(.firstResultPoint, now: at(1))
        keychain.notePremium(now: at(1), calendar: calendar)
        keychain.spendAtCohortLaunch([.historyEdge], launchAt: at(1), now: at(1))

        let merged = OfferLedger.merge(phone, keychain)
        XCTAssertEqual(merged.shownAt(.firstResult), at(1), "earliest moment date")
        XCTAssertEqual(merged.spentAt(.historyEdge), at(1))
        XCTAssertEqual(merged.lastShownAt, at(2), "latest pace date")
        XCTAssertEqual(merged.lastSeenPremiumAt, at(1))
        XCTAssertEqual(merged.closesInRow, 1, "the streak of the copy written last")
        XCTAssertTrue(merged.cohortSpent)
        XCTAssertEqual(OfferLedger.merge(keychain, phone), merged, "order does not matter")
    }

    func testRoundTripsAndReadsAnyPartialCopy() throws {
        var ledger = OfferLedger.empty
        ledger.recordShown(.historyEdge, now: at(16))
        ledger.notePremium(now: at(20), calendar: calendar)
        let data = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(OfferLedger.self, from: data), ledger)

        XCTAssertEqual(try JSONDecoder().decode(OfferLedger.self, from: Data("{}".utf8)), .empty)
        let unknownContent = Data(#"{"closesInRow":2,"open":{"content":"later_kind","shownAt":0}}"#.utf8)
        let decoded = try JSONDecoder().decode(OfferLedger.self, from: unknownContent)
        XCTAssertEqual(decoded.closesInRow, 2)
        XCTAssertNil(decoded.open, "a card this build cannot show is dropped, not fatal")
    }
}

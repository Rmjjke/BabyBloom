import XCTest
@testable import BabyBloom

/// The free history window is a calendar question — "the last 15 days" — asked
/// of a list sorted by instants, and then reconciled with the row caps two of
/// the five surfaces already had. Every trap in it (the inclusive edge, a DST
/// day that is not 24 hours, a cap that makes the window invisible, the
/// premium case that must not filter at all, and the promise that deleting
/// still reaches everything) is cheaper to pin here than on a simulator.
final class HistoryWindowTests: XCTestCase {

    /// A fixed calendar in a zone that actually observes DST, so the tests
    /// below are not quietly passing because the machine sits in UTC.
    private func calendar(_ zone: String = "America/New_York") -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: zone)!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    private func date(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int,
                      _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - cutoff

    func testCutoffIsStartOfTheFifteenthDayBack() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)

        // 15 calendar days INCLUDING today: 22 Sep back to 8 Sep, and the
        // boundary sits at 8 Sep 00:00 rather than at 14:37.
        XCTAssertEqual(HistoryWindow.cutoff(now: now, calendar: cal),
                       date(cal, 2026, 9, 8, 0, 0))
    }

    func testWindowSpansExactlyFifteenDays() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        let cutoff = try! XCTUnwrap(HistoryWindow.cutoff(now: now, calendar: cal))

        let days = cal.dateComponents([.day],
                                      from: cutoff,
                                      to: cal.startOfDay(for: now)).day
        XCTAssertEqual(days, HistoryWindow.freeDays - 1)
    }

    /// The constant and the arithmetic are wired to each other, not to a 14
    /// typed twice. The constant is also spelled out in six JSON strings —
    /// see the comment on `freeDays`.
    func testFreeDaysIsFifteen() {
        XCTAssertEqual(HistoryWindow.freeDays, 15)
    }

    /// Spring forward: 8 March 2026 is 23 hours long in New York. Counting
    /// 14 × 86400 seconds back from 22 March would land at 01:00 on the 8th
    /// and cut that whole day's first hour out of the window.
    func testCutoffIsDSTSafeAcrossASpringForward() {
        let cal = calendar()
        let now = date(cal, 2026, 3, 22, 9, 0)

        XCTAssertEqual(HistoryWindow.cutoff(now: now, calendar: cal),
                       date(cal, 2026, 3, 8, 0, 0))

        // And explicitly NOT the naive arithmetic.
        let naive = now.addingTimeInterval(-14 * 86_400)
        XCTAssertNotEqual(HistoryWindow.cutoff(now: now, calendar: cal), naive)
    }

    /// Fall back: 1 November 2026 is 25 hours long. The window must still be
    /// 15 whole days, not 14 days and 23 hours.
    func testCutoffIsDSTSafeAcrossAFallBack() {
        let cal = calendar()
        let now = date(cal, 2026, 11, 14, 9, 0)

        XCTAssertEqual(HistoryWindow.cutoff(now: now, calendar: cal),
                       date(cal, 2026, 10, 31, 0, 0))
    }

    func testCutoffIsNilForPremium() {
        XCTAssertNil(HistoryWindow.cutoff(isPremium: true))
        XCTAssertNotNil(HistoryWindow.cutoff(isPremium: false))
    }

    // MARK: - split

    func testEntryOnTheFifteenthDayIsVisibleAndTheSixteenthIsNot() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        let cutoff = HistoryWindow.cutoff(now: now, calendar: cal)

        // Day 15 counting back inclusively is 8 Sep — inside. Its own first
        // minute counts: the edge is the start of the day, not the clock time
        // of the request.
        let dayFifteenMidnight = date(cal, 2026, 9, 8, 0, 0)
        let dayFifteenEvening  = date(cal, 2026, 9, 8, 23, 59)
        // Day 16 is 7 Sep — outside, right down to its last minute.
        let daySixteenEvening  = date(cal, 2026, 9, 7, 23, 59)

        let items = [now, dayFifteenEvening, dayFifteenMidnight, daySixteenEvening]
        let result = HistoryWindow.split(items, date: { $0 }, cutoff: cutoff)

        XCTAssertEqual(result.visible, [now, dayFifteenEvening, dayFifteenMidnight])
        XCTAssertEqual(result.hiddenCount, 1)
    }

    func testPremiumSeesEverything() {
        let cal = calendar()
        let items = [date(cal, 2026, 9, 22), date(cal, 2024, 1, 1)]

        let result = HistoryWindow.split(items, date: { $0 }, cutoff: nil)

        XCTAssertEqual(result.visible, items)
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testEmptyListHidesNothing() {
        let result = HistoryWindow.split([Date](), date: { $0 },
                                         cutoff: HistoryWindow.cutoff())
        XCTAssertTrue(result.visible.isEmpty)
        XCTAssertEqual(result.hiddenCount, 0)
    }

    /// The fresh-install case, and the common one: nothing older than the
    /// window means no footer, so the hidden count must be exactly zero rather
    /// than merely small.
    func testAllRecentHidesNothing() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        let items = (0..<10).map { cal.date(byAdding: .day, value: -$0, to: now)! }

        let result = HistoryWindow.split(items, date: { $0 },
                                         cutoff: HistoryWindow.cutoff(now: now, calendar: cal))

        XCTAssertEqual(result.visible.count, 10)
        XCTAssertEqual(result.hiddenCount, 0)
    }

    func testEverythingOldHidesEverything() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        let items = [date(cal, 2026, 8, 1), date(cal, 2026, 7, 1)]

        let result = HistoryWindow.split(items, date: { $0 },
                                         cutoff: HistoryWindow.cutoff(now: now, calendar: cal))

        XCTAssertTrue(result.visible.isEmpty)
        XCTAssertEqual(result.hiddenCount, 2)
    }

    /// Lists reach `split` already sorted newest-first and are rendered in the
    /// order they come back.
    func testSplitPreservesOrder() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        let items = [date(cal, 2026, 9, 20), date(cal, 2026, 9, 21), date(cal, 2026, 9, 19)]

        let result = HistoryWindow.split(items, date: { $0 },
                                         cutoff: HistoryWindow.cutoff(now: now, calendar: cal))

        XCTAssertEqual(result.visible, items)
    }

    /// `split` is given a projection rather than a key path because the five
    /// call sites store their date under five different names.
    func testSplitUsesTheSuppliedDateProjection() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 14, 37)
        struct Row { let at: Date }
        let rows = [Row(at: now), Row(at: date(cal, 2026, 1, 1))]

        let result = HistoryWindow.split(rows, date: \.at,
                                         cutoff: HistoryWindow.cutoff(now: now, calendar: cal))

        XCTAssertEqual(result.visible.count, 1)
        XCTAssertEqual(result.hiddenCount, 1)
    }

    // MARK: - windowCostsRows
    //
    // The four combinations of "does the window bind" × "does the cap bind".
    // Only the first may show the lock: everywhere else the lock would be
    // claiming credit for rows the cap is taking, and offering to sell rows a
    // subscriber would not get either.

    func testFooterShowsWhenTheWINDOWIsWhatCostsRows() {
        // 12 inside the window, 63 in total, cap 20: a free account sees 12
        // rows where a subscriber would see 20. The window is the limiter.
        XCTAssertTrue(HistoryWindow.windowCostsRows(windowed: 12, total: 63, cap: 20))
    }

    func testFooterHidesWhenTheCAPIsWhatCostsRows() {
        // 45 inside the window, 63 in total, cap 20: both accounts see the
        // same twenty rows. Showing "the last 15 days" under a list that stops
        // seven days back would be false, and the sell would deliver nothing.
        XCTAssertFalse(HistoryWindow.windowCostsRows(windowed: 45, total: 63, cap: 20))
    }

    func testFooterHidesWhenNeitherLimitBinds() {
        XCTAssertFalse(HistoryWindow.windowCostsRows(windowed: 8, total: 8, cap: 20))
    }

    /// Exactly on the cap from both sides — the boundary the `min` exists for.
    func testFooterHidesWhenTheWindowedCountStillFillsTheCap() {
        XCTAssertFalse(HistoryWindow.windowCostsRows(windowed: 20, total: 21, cap: 20))
        XCTAssertTrue(HistoryWindow.windowCostsRows(windowed: 19, total: 21, cap: 20))
    }

    /// `BBHistorySection` is the uncapped case of the same formula.
    func testUncappedReducesToAnythingOutsideTheWindow() {
        XCTAssertTrue(HistoryWindow.windowCostsRows(windowed: 45, total: 63, cap: nil))
        XCTAssertFalse(HistoryWindow.windowCostsRows(windowed: 63, total: 63, cap: nil))
    }

    // MARK: - list

    func testListWindowsBeforeCapping() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 12, 0)
        // Five rows a day for six days: three days inside the window, three
        // well outside it.
        let inside  = (0..<3).flatMap { d in (0..<5).map { _ in cal.date(byAdding: .day, value: -d, to: now)! } }
        let outside = (0..<3).map { d in date(cal, 2026, 8, 20 + d) }

        let model = HistoryWindow.list(inside + outside, date: { $0 },
                                       cutoff: HistoryWindow.cutoff(now: now, calendar: cal),
                                       cap: 20)

        // Capping first would have filled all twenty rows from the 18 recent
        // ones and reported nothing hidden.
        XCTAssertEqual(model.visible.count, 15)
        XCTAssertTrue(model.showsLockedFooter)
    }

    /// The hostage guarantee, as a property of the type rather than a
    /// discipline at five call sites: whatever the window and the cap do to
    /// what is RENDERED, "delete all" is handed the whole input back.
    func testDeletableIsAlwaysTheFullInputRegardlessOfWindowOrCap() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 12, 0)
        let items = (0..<40).map { cal.date(byAdding: .day, value: -$0, to: now)! }

        for cap in [nil, 5, 20, 1_000] as [Int?] {
            for cutoff in [nil, HistoryWindow.cutoff(now: now, calendar: cal)] {
                let model = HistoryWindow.list(items, date: { $0 }, cutoff: cutoff, cap: cap)
                XCTAssertEqual(model.deletable, items,
                               "delete-all must receive the pre-window, pre-cap array (cap \(String(describing: cap)))")
                XCTAssertLessThanOrEqual(model.visible.count, model.deletable.count)
            }
        }
    }

    /// The confirmation's question is broader than the footer's: it must own
    /// up to rows held back by the CAP too, not only by the window.
    func testDeletesRowsNotShownCoversTheCapAsWellAsTheWindow() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 12, 0)
        let recent = (0..<40).map { cal.date(byAdding: .hour, value: -$0, to: now)! }

        // Premium, so the window takes nothing — but the cap takes 20.
        let capped = HistoryWindow.list(recent, date: { $0 }, cutoff: nil, cap: 20)
        XCTAssertFalse(capped.showsLockedFooter)
        XCTAssertTrue(capped.deletesRowsNotShown)

        // Nothing held back at all.
        let whole = HistoryWindow.list(recent, date: { $0 }, cutoff: nil, cap: nil)
        XCTAssertFalse(whole.deletesRowsNotShown)
    }

    func testListOnAFreshInstallShowsNothingAndSellsNothing() {
        let model = HistoryWindow.list([Date](), date: { $0 },
                                       cutoff: HistoryWindow.cutoff(), cap: 20)
        XCTAssertTrue(model.visible.isEmpty)
        XCTAssertTrue(model.deletable.isEmpty)
        XCTAssertFalse(model.showsLockedFooter)
        XCTAssertFalse(model.deletesRowsNotShown)
    }

    /// A subscriber is never shown the lock, whatever the data looks like.
    func testPremiumNeverShowsTheFooter() {
        let cal = calendar()
        let items = (0..<50).map { date(cal, 2026, 1, 1).addingTimeInterval(Double($0) * 86_400) }

        XCTAssertFalse(HistoryWindow.list(items, date: { $0 }, cutoff: nil).showsLockedFooter)
        XCTAssertFalse(HistoryWindow.list(items, date: { $0 }, cutoff: nil, cap: 20).showsLockedFooter)
    }

    /// Everything outside the window, uncapped: no rows, and the footer
    /// carries the whole list on its own rather than an empty state claiming
    /// there are no records.
    func testEverythingOutsideTheWindowLeavesTheFooterAlone() {
        let cal = calendar()
        let now = date(cal, 2026, 9, 22, 12, 0)
        let items = [date(cal, 2026, 8, 1), date(cal, 2026, 7, 1)]

        let model = HistoryWindow.list(items, date: { $0 },
                                       cutoff: HistoryWindow.cutoff(now: now, calendar: cal))

        XCTAssertTrue(model.visible.isEmpty)
        XCTAssertFalse(model.deletable.isEmpty)
        XCTAssertTrue(model.showsLockedFooter)
    }
}

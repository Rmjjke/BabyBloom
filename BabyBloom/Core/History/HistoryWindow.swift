import Foundation

/// How far back a free account can read its own activity history.
///
/// The paywall has always sold «Неограниченная история» / "Unlimited history"
/// and nothing in the app limited it, so the line was a promise about a
/// feature that did not exist. This type is what makes the promise true: the
/// last `freeDays` calendar days stay free forever, anything older is offered
/// for sale instead of being shown.
///
/// **Nothing here deletes, migrates or hides anything from the engine.** The
/// `@Query`s still read every row; only the arrays a *list view* renders pass
/// through `list(_:date:cutoff:cap:)`. Statistics, charts, exports,
/// notifications and the Growth screen's weighings all keep reading the whole
/// store — see DECISIONS 2026-09-22.
///
/// Pure Foundation on purpose: the boundary is a calendar question with DST
/// and time-zone traps in it, and those are worth a unit test rather than a
/// simulator.
enum HistoryWindow {

    /// The size of the free window in CALENDAR days, today included.
    ///
    /// **The number is spelled out in the copy**, in six places:
    /// `history.free_window` in `{en,ru,es}.json` and their byte-identical
    /// copies under `WidgetResources/Localization/`. Changing this constant
    /// means changing all six, and changing it to a number whose Russian
    /// plural form differs means rewriting that string rather than swapping a
    /// digit — 15 takes «дней», 21 would take «день» and 22 «дня». The copy
    /// carries no interpolated count precisely so that a future edit here is a
    /// deliberate translation change and not a silently ungrammatical one.
    static let freeDays = 15

    /// The oldest instant a free account can still see, or `nil` if the
    /// calendar cannot produce one.
    ///
    /// `startOfDay(now − 14 days)` rather than `now − 15 × 86400`: a parent
    /// counts days, not seconds. Anchoring to the start of the day means the
    /// window covers 15 whole calendar days including today, and the DST day
    /// that is 23 or 25 hours long still counts as exactly one day. It does
    /// NOT freeze the boundary — a list re-rendered after midnight is windowed
    /// against the new day, which is the behaviour a parent expects from "the
    /// last 15 days"; what the anchoring buys is that the boundary moves in
    /// whole days at midnight instead of drifting continuously.
    ///
    /// **`nil` on failure, which means unlimited.** `date(byAdding:)` does not
    /// fail for a Gregorian calendar, but if it ever did, falling back to
    /// `today` would narrow a paying-or-not parent's history to the current
    /// day — the harmful direction. Every failure in this file fails OPEN.
    static func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(freeDays - 1), to: today)
    }

    /// The cutoff to apply for a given entitlement — `nil` means unlimited.
    ///
    /// Call sites do not compute this themselves; they read
    /// `SubscriptionManager.historyCutoff`, which is the one place the
    /// entitlement, the unresolved-entitlement grace and this date meet.
    static func cutoff(isPremium: Bool, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        isPremium ? nil : cutoff(now: now, calendar: calendar)
    }

    /// Splits an already-filtered list into what is inside the window and how
    /// much is outside it. `cutoff == nil` is the premium case: everything is
    /// inside.
    ///
    /// Order is preserved, so a sorted input stays sorted.
    static func split<T>(_ items: [T],
                         date: (T) -> Date,
                         cutoff: Date?) -> (visible: [T], hiddenCount: Int) {
        guard let cutoff else { return (items, 0) }
        let visible = items.filter { date($0) >= cutoff }
        return (visible, items.count - visible.count)
    }

    /// Whether the free window actually costs this list any RENDERED rows.
    ///
    /// Not the same question as "is anything outside the window". Two of the
    /// five surfaces also cap their list (`EventsView` and `RecentActivityView`
    /// render at most twenty rows), and where the CAP is the binding limit the
    /// window changes nothing a reader can see: a free account and a
    /// subscriber are looking at the same twenty rows. Showing the lock there
    /// would state a falsehood — «Показаны последние 15 дней» under a list that
    /// stops seven days back — and would sell a subscription that delivers
    /// nothing on that screen.
    ///
    /// So compare what is drawn with the window against what would be drawn
    /// without it. `cap == nil` is the uncapped case (`BBHistorySection`),
    /// where this reduces to "is anything outside the window".
    static func windowCostsRows(windowed: Int, total: Int, cap: Int?) -> Bool {
        drawn(windowed, cap) < drawn(total, cap)
    }

    private static func drawn(_ count: Int, _ cap: Int?) -> Int {
        guard let cap else { return count }
        return min(count, cap)
    }

    /// Everything a history list needs, derived once.
    ///
    /// `deletable` exists to make the hostage guarantee a property of the type
    /// rather than a discipline at five call sites: it is the FULL input, so a
    /// view that wires "delete all" to this model cannot accidentally delete
    /// only what the reader can see. DECISIONS 2026-09-01 and 2026-09-22.
    struct List<T> {
        /// Every row in range — what "delete all" must act on.
        let deletable: [T]
        /// The rows actually rendered, after the window and after the cap.
        let visible: [T]
        /// Whether the locked footer belongs under the list.
        let showsLockedFooter: Bool

        /// Whether "delete all" would remove rows that are not on screen — for
        /// ANY reason, the cap included, not only the window. The confirmation
        /// has to own up to those too.
        var deletesRowsNotShown: Bool { deletable.count > visible.count }
    }

    /// The one derivation all five history surfaces use.
    ///
    /// - Parameters:
    ///   - items: the full in-range list, newest first.
    ///   - cutoff: `nil` for unlimited (premium, or entitlement not yet known).
    ///   - cap: a hard row limit applied AFTER the window, or `nil` for none.
    ///     Order matters: windowing first is what makes the footer mean "older
    ///     than 15 days" rather than "beyond twenty rows".
    static func list<T>(_ items: [T],
                        date: (T) -> Date,
                        cutoff: Date?,
                        cap: Int? = nil) -> List<T> {
        let window = split(items, date: date, cutoff: cutoff)
        let visible = cap.map { Array(window.visible.prefix($0)) } ?? window.visible
        return List(
            deletable: items,
            visible: visible,
            showsLockedFooter: windowCostsRows(windowed: window.visible.count,
                                               total: items.count,
                                               cap: cap)
        )
    }
}

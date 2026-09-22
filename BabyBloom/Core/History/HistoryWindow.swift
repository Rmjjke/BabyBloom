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
/// through `split`. Statistics, charts, exports, notifications and the Growth
/// screen's weighings all keep reading the whole store — see DECISIONS
/// 2026-09-22.
///
/// Pure Foundation on purpose: the boundary is a calendar question with DST
/// and time-zone traps in it, and those are worth a unit test rather than a
/// simulator.
enum HistoryWindow {

    /// The size of the free window in CALENDAR days, today included.
    static let freeDays = 15

    /// The oldest instant a free account can still see.
    ///
    /// `startOfDay(now − 14 days)` rather than `now − 15 × 86400`: a parent
    /// counts days, not seconds. Anchoring to the start of the day means the
    /// window covers 15 whole calendar days including today, it does not slide
    /// under a row while the screen is open, and the DST day that is 23 or 25
    /// hours long still counts as exactly one day.
    static func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(freeDays - 1), to: today) ?? today
    }

    /// The cutoff to apply for a given entitlement — `nil` means unlimited.
    ///
    /// Call sites pass the entitlement, never a date they computed themselves:
    /// five surfaces each deriving their own boundary is five chances to get
    /// it subtly different.
    static func cutoff(isPremium: Bool, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        isPremium ? nil : cutoff(now: now, calendar: calendar)
    }

    /// Splits an already-filtered list into what is shown and how much is held
    /// back. `cutoff == nil` is the premium case: everything is visible.
    ///
    /// Order is preserved, so a sorted input stays sorted.
    static func split<T>(_ items: [T],
                         date: (T) -> Date,
                         cutoff: Date?) -> (visible: [T], hiddenCount: Int) {
        guard let cutoff else { return (items, 0) }
        let visible = items.filter { date($0) >= cutoff }
        return (visible, items.count - visible.count)
    }
}

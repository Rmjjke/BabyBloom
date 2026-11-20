import Foundation

/// The three trackers whose screen carries a weekly chart.
enum WeeklyChartTracker: String, CaseIterable, Sendable {
    case feeding, sleep, diaper
}

/// What stands under a tracker's «weekly chart» header: the chart for a
/// subscriber, the locked card for everyone else, and nothing at all until
/// the entitlements are known. Pure, so every state is pinned by
/// `WeeklyChartLockTests`.
enum WeeklyChartLock {

    enum State: Equatable, Sendable {
        /// Entitlements not resolved yet: no chart, no lock, and no header —
        /// a subscriber must never see a lock flash before the chart, and a
        /// free user never a chart before the lock.
        case hidden
        case chart
        /// The localization keys of the locked card's lines.
        case locked(teaserKey: String, reasonKey: String?)
    }

    static let reasonKey = "premium.weekly_reason"
    static let emptyTeaserKey = "premium.teaser_weekly_empty"

    static func teaserKey(for tracker: WeeklyChartTracker) -> String {
        "premium.teaser_weekly_\(tracker.rawValue)"
    }

    static func state(tracker: WeeklyChartTracker,
                      entitlementsResolved: Bool,
                      isPremium: Bool,
                      weekHasRecords: Bool,
                      reasonOpen: Bool) -> State {
        guard entitlementsResolved else { return .hidden }
        guard !isPremium else { return .chart }
        // An empty week has no «each day» to promise; the neutral line says
        // what the chart is instead.
        return .locked(teaserKey: weekHasRecords ? teaserKey(for: tracker) : emptyTeaserKey,
                       reasonKey: reasonOpen ? reasonKey : nil)
    }

    /// The reason line is for someone who had the charts free and finds them
    /// locked: an install that finished onboarding before the first launch of
    /// the version that locked them. One window for the three screens; it
    /// closes on the first tap on any locked weekly card, or on the 14th
    /// calendar day after that first launch, whichever comes first. A former
    /// subscriber reads no reason: the charts did not go from under them.
    static func reasonOpen(cohort: OfferRule.Cohort,
                           closedAt: Date?,
                           formerSubscriber: Bool,
                           now: Date,
                           calendar: Calendar) -> Bool {
        guard case .beforeOffers(let launchAt) = cohort,
              closedAt == nil, !formerSubscriber else { return false }
        return OfferRule.days(from: launchAt, to: now, calendar: calendar) < reasonDays
    }

    /// The same 14 quiet days an older install gets before its first offer:
    /// one settling-in period for everything 1.4.0 changed.
    static let reasonDays = OfferRule.cohortQuietDays

    /// The Monday-to-Sunday week the chart opens on, in the app's calendar.
    static func currentWeek(now: Date, calendar: Calendar) -> [Date] {
        let monday = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
}

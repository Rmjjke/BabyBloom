import SwiftUI

/// A tracker's «weekly chart» section: its header and, under it, the chart
/// for a subscriber or the locked card for everyone else. The whole section,
/// header included, waits for the entitlements, so neither a lock nor a chart
/// flashes in front of the other on a cold start.
struct WeeklyChartSection<Chart: View>: View {
    let tracker: WeeklyChartTracker
    /// The chart's own per-day value: an empty week reads the neutral teaser.
    let valueFor: (Date) -> Double
    let onUnlock: () -> Void
    @ViewBuilder let chart: () -> Chart

    @Environment(SubscriptionManager.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var reason: WeeklyChartReasonWindow { .shared }

    private var state: WeeklyChartLock.State {
        let resolved = store.hasResolvedEntitlements
        let premium = store.isPremium
        // Only a locked card reads the week and the reason window.
        guard resolved, !premium else {
            return WeeklyChartLock.state(tracker: tracker, entitlementsResolved: resolved, isPremium: premium,
                                         weekHasRecords: false, reasonOpen: false)
        }
        return WeeklyChartLock.state(tracker: tracker, entitlementsResolved: true, isPremium: false,
                                     weekHasRecords: weekHasRecords,
                                     reasonOpen: reason.isOpen(now: AppClock.now))
    }

    /// The week the chart opens on, in its calendar and on its clock.
    private var weekHasRecords: Bool {
        WeeklyChartLock.currentWeek(now: AppClock.now, calendar: LocalizationManager.shared.language.calendar)
            .contains { valueFor($0) > 0 }
    }

    var body: some View {
        let state = state
        Group {
            if state != .hidden {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                    BBSectionHeader(title: "section.weekly_chart")
                    // In the stack the card and the chart would stand one
                    // under the other for the length of the crossfade and push
                    // everything below down; here they overlap.
                    ZStack(alignment: .topLeading) {
                        switch state {
                        case .hidden:
                            EmptyView()
                        case .chart:
                            chart().transition(.opacity)
                        case .locked(let teaserKey, let reasonKey):
                            BBLockedCard(reason: reasonKey?.l, teaser: teaserKey.l, onUnlock: unlock)
                                .transition(.opacity)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        // The inner modifier wins when both change: from hidden, whatever
        // comes fades in over 0.2 s; a purchase or a restore while the screen
        // is open crossfades the card into the chart over 0.25 s. The chart
        // arrives whole — its bars do not grow in.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state == .hidden)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state == .chart)
    }

    private func unlock() {
        reason.close(now: AppClock.now)
        onUnlock()
    }
}

/// The reason line's window, one for the three screens: a tap on any locked
/// weekly card closes it everywhere at once. The cohort and the day count are
/// read at every render (a UserDefaults read, and the cohort is written at the
/// app root's first appearance, which may come after this is made); the
/// former-subscriber mark is a Keychain read, taken once per launch.
@MainActor @Observable
final class WeeklyChartReasonWindow {

    static let shared = WeeklyChartReasonWindow()

    static let closedAtKey = "weeklyChart.reasonClosedAt"

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let readFormerSubscriber: @MainActor () -> Bool
    @ObservationIgnored private lazy var formerSubscriber = readFormerSubscriber()
    private(set) var closedAt: Date?

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .autoupdatingCurrent,
         formerSubscriber: @escaping @MainActor () -> Bool = { OfferService.shared.ledger.lastSeenPremiumAt != nil }) {
        #if targetEnvironment(simulator)
        // `-BBWeeklyReasonReset`: the window as an install meets it first.
        if defaults.bool(forKey: "BBWeeklyReasonReset") { defaults.removeObject(forKey: Self.closedAtKey) }
        #endif
        self.defaults = defaults
        self.calendar = calendar
        self.readFormerSubscriber = formerSubscriber
        self.closedAt = defaults.object(forKey: Self.closedAtKey) as? Date
    }

    func isOpen(now: Date) -> Bool {
        let cohort = OfferCohort.current(defaults: defaults, now: now)
        // Only an older install can have it open: the Keychain stays unread
        // for everyone else.
        guard case .beforeOffers = cohort, closedAt == nil else { return false }
        return WeeklyChartLock.reasonOpen(cohort: cohort, closedAt: closedAt, formerSubscriber: formerSubscriber,
                                          now: now, calendar: calendar)
    }

    /// The first tap closes it for good; a later tap keeps the first date.
    func close(now: Date) {
        guard closedAt == nil else { return }
        closedAt = now
        defaults.set(now, forKey: Self.closedAtKey)
    }
}

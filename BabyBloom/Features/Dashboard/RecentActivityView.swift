import SwiftUI
import SwiftData

/// The Dashboard's former "Recent Events" section, now a screen of its own
/// under More. The Dashboard gave the list six rows because it was a teaser
/// under everything else; a screen reached deliberately shows twenty, the same
/// window `EventsView`'s history uses — a dedicated screen that hides the
/// seventh row with no way to reach it reads as breakage.
///
/// Pushed inside `MoreView`'s `NavigationStack`, so it must NOT wrap one of its
/// own — the same rule `GrowthView` follows.
struct RecentActivityView: View {
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store
    @State private var showPaywall = false

    private var baby: Baby? { babies.first }

    /// The free history window, applied BEFORE the twenty-row cap — same
    /// ordering and same reason as `EventsView`: the footer must mean "older
    /// than 15 days", not "beyond twenty rows".
    private var recentEvents: (visible: [RecentEvent], hiddenCount: Int) {
        let all: [RecentEvent] =
            feedings.map(RecentEvent.feeding)
            + sleeps.map(RecentEvent.sleep)
            + diapers.map(RecentEvent.diaper)
        let sorted = all.sorted { $0.eventTime > $1.eventTime }
        let window = HistoryWindow.split(sorted,
                                         date: { $0.eventTime },
                                         cutoff: HistoryWindow.cutoff(isPremium: store.isPremium))
        return (Array(window.visible.prefix(20)), window.hiddenCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                let window = recentEvents
                let events = window.visible
                if events.isEmpty && window.hiddenCount == 0 {
                    Text("empty.today_no_records".l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(BBTheme.Spacing.xl)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.lg)
                        .bbShadow(BBTheme.Shadow.card)
                } else {
                    VStack(spacing: BBTheme.Spacing.sm) {
                        ForEach(events) { event in
                            SwipeToDeleteRow(onDelete: { delete(event) }) {
                                row(for: event)
                            }
                        }
                    }
                    if window.hiddenCount > 0 {
                        BBLockedHistoryFooter { showPaywall = true }
                    }
                }
            }
            .padding(.horizontal, BBTheme.Spacing.md)
            .padding(.bottom, BBTheme.Spacing.xl)
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("nav.recent_activity".l)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    @ViewBuilder
    private func row(for event: RecentEvent) -> some View {
        switch event {
        case .feeding(let entry):
            BBEventRow(
                icon: "heart.fill",
                iconColor: BBTheme.Colors.feeding,
                title: entry.displayTitle,
                subtitle: entry.isActive ? "status.feeding_active".l : entry.durationFormatted,
                time: entry.startTime.appTimeOfDay
            )
        case .sleep(let entry):
            BBEventRow(
                icon: "moon.fill",
                iconColor: BBTheme.Colors.sleep,
                title: entry.type.displayName.l,
                subtitle: entry.isActive ? "status.sleeping_now".l : entry.durationFormatted,
                time: entry.startTime.appTimeOfDay
            )
        case .diaper(let entry):
            BBEventRow(
                icon: "drop.fill",
                iconColor: BBTheme.Colors.diaper,
                title: entry.displayTitle,
                subtitle: entry.color?.displayName.l ?? "",
                time: entry.time.appTimeOfDay
            )
        }
    }

    // MARK: - Delete
    private func delete(_ event: RecentEvent) {
        switch event {
        case .feeding(let entry): deleteEntry(entry)
        case .sleep(let entry):   deleteEntry(entry)
        case .diaper(let entry):  deleteEntry(entry)
        }
    }

    private func deleteEntry(_ entry: FeedingEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        // @Query may not update synchronously; compute from the pre-delete array.
        let remaining = feedings.filter { $0 !== entry }
        NotificationManager.shared.onFeedingDeleted(
            ageMonths: baby?.ageInMonths ?? 0,
            remainingActive: remaining.contains { $0.isActive },
            remainingFeedingTimes: Array(remaining.prefix(7).map(\.startTime))
        )
    }

    private func deleteEntry(_ entry: SleepEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        let remaining = sleeps.filter { $0 !== entry }
        NotificationManager.shared.onSleepDeleted(
            ageMonths: baby?.ageInMonths ?? 0,
            remainingActive: remaining.contains { $0.isActive },
            lastRemainingSleepEnd: remaining.compactMap(\.endTime).max()
        )
    }

    private func deleteEntry(_ entry: DiaperEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        let remaining = diapers.filter { $0 !== entry }
        NotificationManager.shared.onDiaperDeleted(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            lastRemainingDiaperTime: remaining.map(\.time).max()
        )
    }
}

// MARK: - Recent Event
/// Lives with the screen that renders it — nothing else in the app referenced
/// this enum when it moved out of `DashboardView`.
enum RecentEvent: Identifiable {
    case feeding(FeedingEntry)
    case sleep(SleepEntry)
    case diaper(DiaperEntry)

    var id: PersistentIdentifier {
        switch self {
        case .feeding(let entry): return entry.persistentModelID
        case .sleep(let entry):   return entry.persistentModelID
        case .diaper(let entry):  return entry.persistentModelID
        }
    }

    var eventTime: Date {
        switch self {
        case .feeding(let entry): return entry.startTime
        case .sleep(let entry):   return entry.startTime
        case .diaper(let entry):  return entry.time
        }
    }
}

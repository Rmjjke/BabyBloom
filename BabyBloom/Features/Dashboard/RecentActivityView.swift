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

    @Query(sort: [SortDescriptor(\DoctorVisit.date, order: .reverse),
                  SortDescriptor(\DoctorVisit.createdAt, order: .reverse)])
    private var visits: [DoctorVisit]

    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store
    @State private var showPaywall = false
    @State private var detailVisit: DoctorVisit?

    private var baby: Baby? { babies.first }

    /// The free history window, applied BEFORE the twenty-row cap — same
    /// ordering and same reason as `EventsView`: the footer must mean "older
    /// than 15 days", not "beyond twenty rows", and it is suppressed entirely
    /// where the cap rather than the window is what costs rows.
    ///
    /// There is no delete-all here by design: this screen is a read-only view
    /// onto three lists that each have their own, and every row it CAN reach
    /// stays swipe-deletable.
    private var model: HistoryWindow.List<RecentEvent> {
        let all: [RecentEvent] =
            feedings.map(RecentEvent.feeding)
            + sleeps.map(RecentEvent.sleep)
            + diapers.map(RecentEvent.diaper)
        return HistoryWindow.list(all.sorted { $0.eventTime > $1.eventTime },
                                  date: { $0.eventTime },
                                  cutoff: store.historyCutoff,
                                  cap: 20)
    }

    /// `model` plus the visits, which bypass the window and the cap: the report
    /// starts from a visit, so one behind the lock would hide that record.
    private func rows(of model: HistoryWindow.List<RecentEvent>) -> [RecentEvent] {
        HistoryMerge.merge(model.visible,
                           exempt: DoctorPeriod.newestFirst(visits).map(RecentEvent.visit),
                           date: \.eventTime)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                let model = self.model
                let rows = self.rows(of: model)
                if model.deletable.isEmpty && visits.isEmpty {
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
                        ForEach(rows) { event in
                            if case .visit(let visit) = event {
                                // No swipe: a visit changes only in its detail.
                                Button { detailVisit = visit } label: {
                                    row(for: event)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("report.a11y_period_hint".l)
                                .accessibilityIdentifier("recent.visit_row.\(visitNumber(of: visit, in: rows))")
                            } else {
                                SwipeToDeleteRow(onDelete: { delete(event) }) {
                                    row(for: event)
                                }
                            }
                        }
                    }
                    if model.showsLockedFooter {
                        BBLockedHistoryFooter(surface: .recentActivity) { showPaywall = true }
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
            PaywallView(source: .historyLock)
        }
        .visitDetailSheet(item: $detailVisit)
    }

    /// 1-based position among the visit rows, for the UI-test identifier.
    private func visitNumber(of visit: DoctorVisit, in rows: [RecentEvent]) -> Int {
        let ids = rows.compactMap { row -> PersistentIdentifier? in
            if case .visit(let v) = row { return v.persistentModelID }
            return nil
        }
        return (ids.firstIndex(of: visit.persistentModelID) ?? 0) + 1
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
        case .visit(let visit):
            BBEventRow(
                icon: "stethoscope",
                iconColor: BBTheme.Colors.events,
                title: "visit.title".l,
                subtitle: DoctorPeriod.noteFirstLine(visit.note) ?? "",
                time: visit.date.appDayMonth
            )
        }
    }

    // MARK: - Delete
    private func delete(_ event: RecentEvent) {
        switch event {
        case .feeding(let entry): deleteEntry(entry)
        case .sleep(let entry):   deleteEntry(entry)
        case .diaper(let entry):  deleteEntry(entry)
        // Unreachable, no swipe exists on a visit row: a visit changes only
        // in its detail.
        case .visit:              break
        }
    }

    // Through TimerActions like every other screen: this list used to skip the
    // widget reload, and a deleted running timer must end its Live Activity.
    private func deleteEntry(_ entry: FeedingEntry) {
        TimerActions.delete(feedings: [entry], in: modelContext)
    }

    private func deleteEntry(_ entry: SleepEntry) {
        TimerActions.delete(sleeps: [entry], in: modelContext)
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
    case visit(DoctorVisit)

    var id: PersistentIdentifier {
        switch self {
        case .feeding(let entry): return entry.persistentModelID
        case .sleep(let entry):   return entry.persistentModelID
        case .diaper(let entry):  return entry.persistentModelID
        case .visit(let visit):   return visit.persistentModelID
        }
    }

    var eventTime: Date {
        switch self {
        case .feeding(let entry): return entry.startTime
        case .sleep(let entry):   return entry.startTime
        case .diaper(let entry):  return entry.time
        case .visit(let visit):   return visit.date
        }
    }
}

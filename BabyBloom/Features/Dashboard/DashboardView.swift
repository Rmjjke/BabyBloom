import SwiftUI
import SwiftData

struct DashboardView: View {
    /// The tab selection, owned by MainTabView. The active-timer cards use it
    /// to jump to the screen that owns the timer — a card that shows a running
    /// timer but cannot take you to it reads as broken (owner report, build 5).
    @Binding var selectedTab: MainTabView.Tab

    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]
    @Query(sort: \GrowthEntry.date, order: .reverse) private var growthEntries: [GrowthEntry]

    @State private var showQuickFeedingSheet = false
    @State private var showQuickSleepSheet = false
    @State private var showQuickDiaperSheet = false
    @State private var showQuickEventSheet = false
    @State private var showQuickGrowthSheet = false
    @State private var showProfileEdit = false

    private var baby: Baby? { babies.first }

    private var todayFeedings: [FeedingEntry] {
        feedings.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var todaySleeps: [SleepEntry] {
        sleeps.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var todayDiapers: [DiaperEntry] {
        diapers.filter { Calendar.current.isDateInToday($0.time) }
    }

    private var totalSleepToday: Double {
        todaySleeps.filter { !$0.isActive }.reduce(0) { $0 + $1.duration / 3600 }
    }

    private var activeFeeding: FeedingEntry? {
        feedings.first(where: { $0.isActive })
    }

    private var activeSleep: SleepEntry? {
        sleeps.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.xl) {
                    headerSection
                    if activeFeeding != nil || activeSleep != nil {
                        activeTimersSection
                    }
                    quickActionsSection
                    statsSection
                    progressSection
                }
                .padding(.horizontal, BBTheme.Spacing.md)
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showQuickFeedingSheet) { FeedingQuickSheet() }
        .sheet(isPresented: $showQuickSleepSheet)   { SleepQuickSheet() }
        .sheet(isPresented: $showQuickDiaperSheet)  { DiaperQuickSheet() }
        .sheet(isPresented: $showQuickEventSheet)   { AddEventSheet() }
        .sheet(isPresented: $showQuickGrowthSheet)  { AddGrowthSheet() }
        .sheet(isPresented: $showProfileEdit) {
            if let baby {
                BabyProfileEditSheet(baby: baby)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.welcome".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                if let baby {
                    BBTheme.Typography.title1(baby.name)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(baby.ageDescription)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.pill)
                } else {
                    BBTheme.Typography.title1("brand.name".l)
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
            Spacer()
            // Without a baby there is nothing to edit, so show no control at all
            // rather than an avatar that silently ignores taps.
            if let baby {
                Button {
                    showProfileEdit = true
                } label: {
                    BabyAvatarView(photoData: baby.photoData,
                                   gender: baby.gender,
                                   size: 52)
                        .overlay(Circle().stroke(BBTheme.Colors.primary.opacity(0.15), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("nav.profile".l))
            }
        }
        .padding(.top, BBTheme.Spacing.md)
    }

    // MARK: - Active Timers
    private var activeTimersSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            if let feeding = activeFeeding {
                ActiveTimerCard(
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    title: "status.feeding_going".l,
                    subtitle: feeding.displayTitle,
                    startTime: feeding.startTime
                ) { selectedTab = .feeding }
            }
            if let sleep = activeSleep {
                ActiveTimerCard(
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    title: "status.baby_sleeping".l,
                    subtitle: sleep.type.displayName.l,
                    startTime: sleep.startTime
                ) { selectedTab = .sleep }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_input")
            HStack(spacing: 0) {
                BBQuickActionButton(icon: "heart.fill",      title: "tab.feeding".l, color: BBTheme.Colors.feeding) { showQuickFeedingSheet = true }
                BBQuickActionButton(icon: "moon.fill",       title: "tab.sleep".l,   color: BBTheme.Colors.sleep)   { showQuickSleepSheet = true }
                BBQuickActionButton(icon: "drop.fill",       title: "nav.diapers".l, color: BBTheme.Colors.diaper)  { showQuickDiaperSheet = true }
                BBQuickActionButton(icon: "plus.circle.fill", title: "nav.events".l, color: BBTheme.Colors.events)  { showQuickEventSheet = true }
            }
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.card)
        }
    }

    // MARK: - Stats Grid
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.today")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "stat.feedings",
                    value: "\(todayFeedings.count)",
                    unit: "unit.times",
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    trend: lastFeedingText,
                    action: { showQuickFeedingSheet = true }
                )
                BBStatCard(
                    title: "stat.sleep",
                    value: String(format: "%.1f", totalSleepToday),
                    unit: "unit.hours",
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    action: { showQuickSleepSheet = true }
                )
                BBStatCard(
                    title: "stat.diapers",
                    value: "\(todayDiapers.count)",
                    unit: "unit.pcs",
                    icon: "drop.fill",
                    color: BBTheme.Colors.diaper,
                    action: { showQuickDiaperSheet = true }
                )
                if let latest = growthEntries.first {
                    BBStatCard(
                        title: "stat.weight",
                        value: String(format: "%.2f", latest.weightKg ?? 0),
                        unit: "unit.kg",
                        icon: "scalemass.fill",
                        color: BBTheme.Colors.growth,
                        action: { showQuickGrowthSheet = true }
                    )
                } else {
                    BBStatCard(
                        title: "tab.growth",
                        value: "—",
                        unit: "",
                        icon: "chart.line.uptrend.xyaxis",
                        color: BBTheme.Colors.growth,
                        action: { showQuickGrowthSheet = true }
                    )
                }
            }
        }
    }

    private var lastFeedingText: String? {
        guard let last = feedings.first else { return nil }
        let mins = Int(Date().timeIntervalSince(last.startTime) / 60)
        if mins < 60 { return String(format: "stats.min_ago".l, mins) }
        return String(format: "stats.h_ago".l, mins / 60)
    }

    // MARK: - Progress
    private var progressSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            let ageMonths = baby?.ageInMonths ?? 0
            let targetFeedings: Double = ageMonths < 1 ? 10 : (ageMonths < 3 ? 8 : 6)
            let targetSleep: Double = ageMonths < 1 ? 16 : (ageMonths < 3 ? 15 : 14)

            BBProgressCard(title: "tab.feeding", current: Double(todayFeedings.count), target: targetFeedings, unit: "unit.times", color: BBTheme.Colors.feeding, icon: "heart.fill")
            BBProgressCard(title: "tab.sleep",   current: totalSleepToday, target: targetSleep, unit: "unit.h", color: BBTheme.Colors.sleep, icon: "moon.fill")
            BBProgressCard(title: "nav.diapers", current: Double(todayDiapers.count), target: ageMonths < 1 ? 8 : 6, unit: "unit.pcs", color: BBTheme.Colors.diaper, icon: "drop.fill")
        }
    }
}

// MARK: - Active Timer Card
struct ActiveTimerCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let startTime: Date
    /// Where the card takes you — the screen that owns this timer.
    let onTap: () -> Void

    var body: some View {
        // Same shape as BBStatCard: whole card is the hit target, contentShape
        // guarantees the full frame is hittable, and the shared scale style
        // gives the press the same haptic-and-shrink every other card has.
        Button(action: onTap) {
            cardContent
        }
        .contentShape(Rectangle())
        .buttonStyle(BBScaleButtonStyle())
    }

    private var cardContent: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            Spacer()
            BBElapsedTimer(
                startTime: startTime,
                font: BBTheme.Typography.scaled(22, relativeTo: .title2, weight: .semibold, design: .rounded).monospacedDigit(),
                color: color
            )
        }
        .padding(BBTheme.Spacing.md)
        .background(color.opacity(0.08))
        .cornerRadius(BBTheme.Radius.md)
        .overlay(RoundedRectangle(cornerRadius: BBTheme.Radius.md).stroke(color.opacity(0.3), lineWidth: 1.5))
    }
}

// MARK: - Quick Sheets
struct FeedingQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            FeedingView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("button.close".l) { dismiss() } } }
        }
    }
}

struct SleepQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SleepView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("button.close".l) { dismiss() } } }
        }
    }
}

struct DiaperQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DiaperView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("button.close".l) { dismiss() } } }
        }
    }
}

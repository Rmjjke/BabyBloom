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
    @State private var showPaywall = false

    /// Honours `-BBForcePremium`, so the paid half of the Growth section is
    /// reachable in e2e without a purchase (see the platform-run skill).
    @Environment(SubscriptionManager.self) private var store

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    growthSection
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
        .sheet(isPresented: $showPaywall) { PaywallView() }
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

    // MARK: - Growth

    /// The free half is deliberately word-shaped. The Growth screen's rule
    /// holds here too: weight gain is the only signal that speaks, and it
    /// speaks in `FeedingAdequacy`'s vocabulary, never in a number that alarms
    /// (DECISIONS 2026-08-25). Which of the free states applies is decided by
    /// `DashboardGrowthSummary`, where the rule is unit-tested.
    private var growthSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            // The whole header is the link, so the chevron is not a separate
            // tap target that behaves differently from the words beside it.
            NavigationLink {
                GrowthView()
            } label: {
                HStack {
                    BBTheme.Typography.title3("dashboard.growth.title".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            growthCard

            // A permanent teaser, not a free-first-days window: a section that
            // vanished after two days would read as breakage, in the one domain
            // where the app must never frighten (owner decision 2026-09-01).
            if !store.isPremium {
                LockedInsightCard(
                    title: "dashboard.growth.locked_title".l,
                    teaser: "dashboard.growth.locked_teaser".l
                ) { showPaywall = true }
            }
        }
    }

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            switch growthSummary {
            case .invitation:
                // An invitation, not an empty state — the widget's rule. A
                // parent who has not weighed yet is doing nothing wrong.
                HintText(text: "dashboard.growth.empty".l)
            case let .summary(weightKg, gain):
                growthRow(label: "stat.weight".l,
                          value: String(format: "%.2f", weightKg) + " " + "unit.kg".l,
                          color: BBTheme.Colors.textPrimary)
                gainRow(gain)
                if store.isPremium, let percentile = latestPercentile {
                    growthRow(label: "percentile.weight".l,
                              value: String(format: "dashboard.growth.percentile_fmt".l,
                                            Int(percentile.rounded())),
                              color: BBTheme.Colors.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    @ViewBuilder
    private func gainRow(_ gain: DashboardGrowthSummary.Gain) -> some View {
        switch gain {
        case .word(let signal):
            growthRow(label: "nutrition.row_gain".l,
                      value: gainValue(signal),
                      color: gainColor(signal))
        case .needsAnotherWeighing:
            HintText(text: "nutrition.need_weighing".l)
        case .unavailable:
            // Past the age the gain reference covers the section says nothing
            // about gain. "Not enough data" would be untrue.
            EmptyView()
        }
    }

    /// Premium prepends the figure to the same word the free line already
    /// shows, rather than replacing it: one vocabulary across the app, and the
    /// paid half reads as an addition instead of a different verdict.
    private func gainValue(_ signal: FeedingAdequacy.Signal) -> String {
        let word = statusWord(signal)
        guard store.isPremium, let reading = gainReading else { return word }
        let grams = Int(reading.gramsPerWeek.rounded())
        let signed = grams > 0 ? "+\(grams)" : "\(grams)"
        return String(format: "velocity.per_week_fmt".l, signed) + " · " + word
    }

    private func statusWord(_ signal: FeedingAdequacy.Signal) -> String {
        switch signal {
        case .below:         return "nutrition.status_below".l
        case .within:        return "nutrition.status_within".l
        case .notEnoughData: return "nutrition.status_unknown".l
        }
    }

    /// `NutritionSection`'s mapping, unchanged: colour reinforces the word and
    /// never carries the message on its own, and nothing here is red.
    private func gainColor(_ signal: FeedingAdequacy.Signal) -> Color {
        switch signal {
        case .below:         return BBTheme.Colors.accent
        case .within:        return BBTheme.Colors.success
        case .notEnoughData: return BBTheme.Colors.textSecondary
        }
    }

    /// At an accessibility size the label and its value cannot share a line
    /// without one of them being proposed a width narrower than its own longest
    /// word, and SwiftUI answers that by breaking INSIDE the word — the defect
    /// `NutritionSection` documents. Same two layouts, same reason.
    @ViewBuilder
    private func growthRow(label: String, value: String, color: Color) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                growthLabel(label)
                growthValue(value, color: color)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                growthLabel(label)
                Spacer(minLength: BBTheme.Spacing.sm)
                growthValue(value, color: color)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func growthLabel(_ label: String) -> some View {
        Text(label)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func growthValue(_ value: String, color: Color) -> some View {
        Text(value)
            .font(BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Growth derivations

    private var growthSummary: DashboardGrowthSummary.Free {
        DashboardGrowthSummary.free(
            latestWeightKg: latestWeightKg,
            assessment: adequacy,
            withinReferenceAge: (baby?.correctedAgeDays ?? 0) <= FeedingAdequacy.maxAgeDays
        )
    }

    /// The newest entry that actually carries a weight — a height-only entry
    /// is more recent but says nothing about weight.
    private var latestWeightKg: Double? {
        growthEntries.compactMap(\.weightKg).first
    }

    /// Built exactly as `GrowthView` builds it, from the queries this screen
    /// already holds; the window is weeks, so filtering in memory is free.
    private var adequacy: FeedingAdequacy.Assessment? {
        guard let baby else { return nil }
        return FeedingAdequacy.assess(
            birthDate: baby.birthDate,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male,
            measurements: growthEntries.weightMeasurements,
            feeds: feedings.map { FeedingAdequacy.Feed(date: $0.startTime, type: $0.type) },
            wetNappies: diapers.filter { $0.type == .wet || $0.type == .both }.map(\.time)
        )
    }

    private var gainReading: WeightVelocity.Reading? {
        guard let baby else { return nil }
        return WeightVelocity.latest(
            measurements: growthEntries.weightMeasurements,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male
        )
    }

    /// Corrected age, not chronological — the same rule the Growth screen's
    /// percentile card follows.
    private var latestPercentile: Double? {
        guard let baby, let weight = latestWeightKg else { return nil }
        return WHOGrowthStandard.percentile(
            weightKg: weight,
            ageDays: baby.correctedAgeDays,
            isMale: baby.gender == .male
        )
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

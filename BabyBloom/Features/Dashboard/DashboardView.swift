import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]
    @Query(sort: \GrowthEntry.date, order: .reverse) private var growthEntries: [GrowthEntry]

    @Environment(\.modelContext) private var modelContext
    @State private var showQuickFeedingSheet = false
    @State private var showQuickSleepSheet = false
    @State private var showQuickDiaperSheet = false

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
        todaySleeps.reduce(0) { $0 + $1.duration / 3600 }
    }

    private var activeFeeding: FeedingEntry? {
        feedings.first(where: { $0.isActive })
    }

    private var activeSleep: SleepEntry? {
        sleeps.first(where: { $0.isActive })
    }

    private var recentEvents: [any TimeStampedEvent] {
        var events: [any TimeStampedEvent] = []
        events += feedings.prefix(3).map { AnyEvent($0) }
        events += sleeps.prefix(3).map { AnyEvent($0) }
        events += diapers.prefix(3).map { AnyEvent($0) }
        return events.sorted { $0.eventTime > $1.eventTime }.prefix(6).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    // Header
                    headerSection

                    // Active timers
                    if activeFeeding != nil || activeSleep != nil {
                        activeTimersSection
                    }

                    // Quick actions
                    quickActionsSection

                    // Stats grid
                    statsSection

                    // Progress
                    progressSection

                    // Recent events
                    recentEventsSection
                }
                .padding(.horizontal, BBTheme.Spacing.md)
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showQuickFeedingSheet) {
            FeedingQuickSheet()
        }
        .sheet(isPresented: $showQuickSleepSheet) {
            SleepQuickSheet()
        }
        .sheet(isPresented: $showQuickDiaperSheet) {
            DiaperQuickSheet()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                if let baby {
                    Text(baby.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(baby.ageDescription)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.pill)
                } else {
                    Text("BabyBloom")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }

            Spacer()

            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [BBTheme.Colors.accent.opacity(0.5), BBTheme.Colors.primary.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Text(baby?.gender == .male ? "👦" : "👶")
                    .font(.system(size: 28))
            }
        }
        .padding(.top, BBTheme.Spacing.md)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "Ночное дежурство 🌙"
        case 6..<12: return "Доброе утро ☀️"
        case 12..<18: return "Добрый день 🌤"
        default: return "Добрый вечер 🌙"
        }
    }

    // MARK: - Active Timers
    private var activeTimersSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            if let feeding = activeFeeding {
                ActiveTimerCard(
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    title: "Кормление идёт",
                    subtitle: feeding.displayTitle,
                    startTime: feeding.startTime
                )
            }
            if let sleep = activeSleep {
                ActiveTimerCard(
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    title: "Ребёнок спит",
                    subtitle: sleep.type.displayName,
                    startTime: sleep.startTime
                )
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "Быстрый ввод")

            HStack(spacing: 0) {
                BBQuickActionButton(icon: "heart.fill", title: "Кормление", color: BBTheme.Colors.feeding) {
                    showQuickFeedingSheet = true
                }
                BBQuickActionButton(icon: "moon.fill", title: "Сон", color: BBTheme.Colors.sleep) {
                    showQuickSleepSheet = true
                }
                BBQuickActionButton(icon: "drop.fill", title: "Подгузник", color: BBTheme.Colors.diaper) {
                    showQuickDiaperSheet = true
                }
                BBQuickActionButton(icon: "plus.circle.fill", title: "Событие", color: BBTheme.Colors.events) {
                    // TODO: events
                }
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
            BBSectionHeader(title: "Сегодня")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "Кормлений",
                    value: "\(todayFeedings.count)",
                    unit: "раз",
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    trend: lastFeedingText
                )
                BBStatCard(
                    title: "Сон",
                    value: String(format: "%.1f", totalSleepToday),
                    unit: "часов",
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep
                )
                BBStatCard(
                    title: "Подгузников",
                    value: "\(todayDiapers.count)",
                    unit: "шт",
                    icon: "drop.fill",
                    color: BBTheme.Colors.diaper
                )
                if let latest = growthEntries.first {
                    BBStatCard(
                        title: "Вес",
                        value: String(format: "%.2f", latest.weightKg ?? 0),
                        unit: "кг",
                        icon: "scalemass.fill",
                        color: BBTheme.Colors.growth
                    )
                } else {
                    BBStatCard(
                        title: "Рост",
                        value: "—",
                        unit: "",
                        icon: "chart.line.uptrend.xyaxis",
                        color: BBTheme.Colors.growth
                    )
                }
            }
        }
    }

    private var lastFeedingText: String? {
        guard let last = feedings.first else { return nil }
        let mins = Int(Date().timeIntervalSince(last.startTime) / 60)
        if mins < 60 { return "\(mins) мин назад" }
        return "\(mins / 60) ч назад"
    }

    // MARK: - Progress
    private var progressSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            let ageMonths = baby?.ageInMonths ?? 0
            let targetFeedings: Double = ageMonths < 1 ? 10 : (ageMonths < 3 ? 8 : 6)
            let targetSleep: Double = ageMonths < 1 ? 16 : (ageMonths < 3 ? 15 : 14)

            BBProgressCard(
                title: "Кормления",
                current: Double(todayFeedings.count),
                target: targetFeedings,
                unit: "раз",
                color: BBTheme.Colors.feeding,
                icon: "heart.fill"
            )
            BBProgressCard(
                title: "Сон",
                current: totalSleepToday,
                target: targetSleep,
                unit: "ч",
                color: BBTheme.Colors.sleep,
                icon: "moon.fill"
            )
            BBProgressCard(
                title: "Подгузники",
                current: Double(todayDiapers.count),
                target: ageMonths < 1 ? 8 : 6,
                unit: "шт",
                color: BBTheme.Colors.diaper,
                icon: "drop.fill"
            )
        }
    }

    // MARK: - Recent Events
    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "Последние события")

            if recentEvents.isEmpty {
                Text("Нет записей за сегодня. Нажмите кнопку выше, чтобы добавить первую запись.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(BBTheme.Spacing.xl)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(recentEvents.indices, id: \.self) { index in
                        recentEvents[index].rowView
                    }
                }
            }
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

    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            Spacer()

            Text(elapsedFormatted)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(BBTheme.Spacing.md)
        .background(color.opacity(0.08))
        .cornerRadius(BBTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(startTime)
        }
        .onAppear { elapsed = Date().timeIntervalSince(startTime) }
    }

    private var elapsedFormatted: String {
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Event Protocol for Dashboard
protocol TimeStampedEvent {
    var eventTime: Date { get }
    var rowView: AnyView { get }
}

struct AnyEvent: TimeStampedEvent {
    let eventTime: Date
    let rowView: AnyView

    init(_ feeding: FeedingEntry) {
        self.eventTime = feeding.startTime
        self.rowView = AnyView(
            BBEventRow(
                icon: "heart.fill",
                iconColor: BBTheme.Colors.feeding,
                title: feeding.displayTitle,
                subtitle: feeding.isActive ? "В процессе..." : feeding.durationFormatted,
                time: feeding.startTime.formatted(.dateTime.hour().minute())
            )
        )
    }

    init(_ sleep: SleepEntry) {
        self.eventTime = sleep.startTime
        self.rowView = AnyView(
            BBEventRow(
                icon: "moon.fill",
                iconColor: BBTheme.Colors.sleep,
                title: sleep.type.displayName,
                subtitle: sleep.isActive ? "Спит сейчас..." : sleep.durationFormatted,
                time: sleep.startTime.formatted(.dateTime.hour().minute())
            )
        )
    }

    init(_ diaper: DiaperEntry) {
        self.eventTime = diaper.time
        self.rowView = AnyView(
            BBEventRow(
                icon: "drop.fill",
                iconColor: BBTheme.Colors.diaper,
                title: diaper.displayTitle,
                subtitle: diaper.color?.displayName ?? "",
                time: diaper.time.formatted(.dateTime.hour().minute())
            )
        )
    }
}

// MARK: - Quick Sheets (minimal for dashboard)
struct FeedingQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            FeedingView()
                .navigationTitle("Кормление")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { dismiss() }
                    }
                }
        }
    }
}

struct SleepQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SleepView()
                .navigationTitle("Сон")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { dismiss() }
                    }
                }
        }
    }
}

struct DiaperQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DiaperView()
                .navigationTitle("Подгузник")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") { dismiss() }
                    }
                }
        }
    }
}

import SwiftUI
import SwiftData

struct SleepView: View {
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var entries: [SleepEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showAddSheet = false
    @State private var historyFilter: HistoryFilter = .day
    /// The history list's free window sells from here; nothing else on this
    /// screen is gated.
    @Environment(SubscriptionManager.self) private var store
    @State private var showPaywall = false

    private var baby: Baby? { babies.first }

    private var todayEntries: [SleepEntry] {
        entries.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var activeEntry: SleepEntry? {
        entries.first(where: { $0.isActive })
    }

    private var totalSleepToday: TimeInterval {
        todayEntries.filter { !$0.isActive }.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Active sleep
                    if let active = activeEntry {
                        SleepTimerCard(entry: active) {
                            stopSleep(active)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("timer.card.sleep")
                        .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // Start sleep button (if not active)
                    if activeEntry == nil {
                        startSleepSection
                            .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // Today stats
                    todaySection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // Weekly chart
                    weeklyChartSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // History list
                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                // Extra bottom clearance so the history period-selector / delete-all
                // button never tucks under the tab bar.
                .padding(.bottom, BBTheme.Spacing.xxl + BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                BBFab { showAddSheet = true }
                    .padding(.trailing, BBTheme.Spacing.md)
                    .padding(.bottom, BBTheme.Spacing.md)
            }
            .navigationTitle("tab.sleep".l)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BBTheme.Colors.primary)
                    }
                }
            }
        }
        .entrySheet(isPresented: $showAddSheet) {
            AddSleepSheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .historyLock)
        }
    }

    // MARK: - Start Sleep
    private var startSleepSection: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            // One column from xxxLarge: in half a 320-pt row «Дневной» keeps
            // 4.8 pt there (83.2 in 88), under the 8-pt spare.
            let tileColumns = BBTileColumns(large: 2, xLarge: 2, xxLarge: 2, xxxLarge: 1, accessibility: 1)
            if tileColumns.count(at: dynamicTypeSize) == 1 {
                VStack(spacing: BBTheme.Spacing.md) {
                    sleepTypeButton(.nap)
                    sleepTypeButton(.night)
                }
            } else {
                HStack(spacing: BBTheme.Spacing.md) {
                    sleepTypeButton(.nap)
                    sleepTypeButton(.night)
                }
            }
        }
    }

    private func sleepTypeButton(_ type: SleepEntry.SleepType) -> some View {
        Button {
            startSleep(type: type)
        } label: {
            VStack(spacing: BBTheme.Spacing.sm) {
                Image(systemName: type.icon)
                    .font(BBTheme.Typography.scaled(30, relativeTo: .body, weight: .regular, design: .default))
                    .foregroundStyle(BBTheme.Colors.sleep)
                Text(type.displayName.l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("button.start".l)
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(BBTheme.Spacing.lg)
            .background(BBTheme.Colors.sleep.opacity(0.1))
            .cornerRadius(BBTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                    .stroke(BBTheme.Colors.sleep.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(BBScaleButtonStyle())
    }

    // MARK: - Today
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.today")
            BBStatGrid {
                BBStatCard(
                    title: "stat.sleep_episodes",
                    value: "\(todayEntries.count)",
                    unit: "unit.times",
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep
                )
                BBStatCard(
                    title: "stat.total",
                    value: (totalSleepToday / 3600).appDecimal(1),
                    unit: "unit.hours",
                    icon: "clock.fill",
                    color: BBTheme.Colors.primary
                )
            }
        }
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weekly_chart")
            BBWeeklyBarChart(
                valueFor: { date in
                    let dayEntries = entries.filter {
                        Calendar.current.isDate($0.startTime, inSameDayAs: date) && !$0.isActive
                    }
                    return dayEntries.reduce(0) { $0 + $1.duration } / 3600
                },
                color: BBTheme.Colors.sleep,
                formatValue: { v in v == 0 ? "0" : v.appDecimal(1) }
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        BBHistorySection(
            entries: entries,
            filter: $historyFilter,
            dateKeyPath: \.startTime,
            emptyIcon: "moon.fill",
            emptyColor: BBTheme.Colors.sleep,
            emptyTitle: "empty.no_records",
            emptySubtitle: "empty.add_sleep",
            historyCutoff: store.historyCutoff,
            row: { entry in
                BBEventRow(
                    icon: entry.type.icon,
                    iconColor: BBTheme.Colors.sleep,
                    title: entry.type.displayName.l,
                    subtitle: entry.isActive ? "status.sleeping_now".l : entry.durationFormatted,
                    time: entry.startTime.appTimeOfDay,
                    trailing: entry.startTime.appDayMonth
                )
            },
            onDelete: { delete($0) },
            onDeleteAll: { deleteAll($0) },
            lockSurface: .sleep,
            onUnlock: { showPaywall = true }
        )
    }

    private func startSleep(type: SleepEntry.SleepType) {
        TimerActions.startSleep(type, in: modelContext)
    }

    private func stopSleep(_ entry: SleepEntry) {
        // A finished record, like a manual save; starting a sleep never asks.
        // Only a stop that actually happened asks (the Lock Screen may have won).
        if TimerActions.stop(entryID: entry.id, kind: .sleep, in: modelContext) {
            reviewPrompt.entrySaved(.sleep)
        }
    }

    private func delete(_ entry: SleepEntry) {
        TimerActions.delete(sleeps: [entry], in: modelContext)
    }

    private func deleteAll(_ items: [SleepEntry]) {
        TimerActions.delete(sleeps: items, in: modelContext)
    }
}

// MARK: - Sleep Timer Card
struct SleepTimerCard: View {
    let entry: SleepEntry
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("status.baby_sleeping".l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.sleep)
                    BBTheme.Typography.title3(entry.type.displayName.l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                Spacer()
                BBElapsedTimer(startTime: entry.startTime, color: BBTheme.Colors.sleep, showsHours: true)
            }

            BBPrimaryButton("button.woke_up".l, icon: "sun.max.fill") {
                onStop()
            }
        }
        .padding(BBTheme.Spacing.lg)
        .background(BBTheme.Colors.sleep.opacity(0.08))
        .cornerRadius(BBTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                .stroke(BBTheme.Colors.sleep.opacity(0.3), lineWidth: 1.5)
        )
    }
}

// MARK: - Add Sleep Sheet
struct AddSleepSheet: View {
    @State private var sheetDetent: PresentationDetent = .large
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var selectedType: SleepEntry.SleepType = .nap
    @State private var selectedLocation: SleepEntry.SleepLocation = .crib
    @State private var startTime = Date()
    @State private var endTime = Date()

    /// Two-word names («Sueño nocturno», «En brazos») can wrap at
    /// accessibility sizes and are centred there. Below them a centred line
    /// sits a fraction of a pixel off the leading one, so the default stays.
    private var wrapAlignment: TextAlignment {
        dynamicTypeSize.isAccessibilitySize ? .center : .leading
    }

    private var locationTiles: some View {
        ForEach(SleepEntry.SleepLocation.allCases, id: \.self) { loc in
            Button { selectedLocation = loc } label: {
                VStack(spacing: 4) {
                    Image(systemName: loc.icon).font(BBTheme.Typography.scaled(20, relativeTo: .body, weight: .regular, design: .default))
                        .foregroundStyle(BBTheme.Colors.primary)
                    Text(loc.displayName.l).font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
                        .multilineTextAlignment(wrapAlignment)
                        .foregroundStyle(selectedLocation == loc ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(selectedLocation == loc ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .strokeBorder(selectedLocation == loc ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                )
                .bbShadow(BBTheme.Shadow.card)
            }
            .buttonStyle(BBScaleButtonStyle())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    BBSheetHeading(title: "sheet.add_sleep".l)
                    // Type
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.sleep_type".l)
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                        HStack(spacing: BBTheme.Spacing.md) {
                            ForEach(SleepEntry.SleepType.allCases, id: \.self) { type in
                                Button { selectedType = type } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon).font(BBTheme.Typography.scaled(24, relativeTo: .body, weight: .regular, design: .default))
                                            .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.sleep)
                                        Text(type.displayName.l).font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
                                            .multilineTextAlignment(wrapAlignment)
                                            .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                    .background(selectedType == type ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                    .cornerRadius(BBTheme.Radius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                            .strokeBorder(selectedType == type ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                    )
                                    .bbShadow(BBTheme.Shadow.card)
                                }
                                .buttonStyle(BBScaleButtonStyle())
                            }
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.location".l)
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                        // Two columns at accessibility sizes: in a third of a
                        // 320-pt sheet es «Cochecito» breaks at AX2 (91.8 pt in
                        // 90.7). Below them the row stays an HStack: a grid
                        // sets it a third of a point lower.
                        let locationColumns = BBTileColumns(large: 3, xLarge: 3, xxLarge: 3, xxxLarge: 3, accessibility: 2)
                        let locationCount = locationColumns.count(at: dynamicTypeSize)
                        if locationCount == locationColumns.large {
                            HStack(spacing: BBTheme.Spacing.sm) {
                                locationTiles
                            }
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.sm),
                                                     count: locationCount),
                                      spacing: BBTheme.Spacing.sm) {
                                locationTiles
                            }
                        }
                    }

                    // Times
                    BBLabeledPicker("form.start_time".l) { label in
                        DatePicker(label, selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                    }
                    .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    BBLabeledPicker("form.end_time".l) { label in
                        DatePicker(label, selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                    }
                    .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
            .bbSheetTitle("sheet.add_sleep".l, movesIntoContentAtAX: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $sheetDetent)
    }

    private func save() {
        let entry = SleepEntry(startTime: startTime, type: selectedType, location: selectedLocation)
        entry.endTime = endTime
        entry.baby = babies.first
        modelContext.insert(entry)
        try? modelContext.save()
        WidgetRefresh.entriesChanged()
        NotificationManager.shared.onSleepEnded(
            ageMonths: babies.first?.ageInMonths ?? 0,
            endedAt: endTime
        )
        reviewPrompt.entrySaved(.sleep)
        dismiss()
    }
}

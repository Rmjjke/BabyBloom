import SwiftUI
import SwiftData

struct SleepView: View {
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var entries: [SleepEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var historyFilter: HistoryFilter = .day

    private var todayEntries: [SleepEntry] {
        entries.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var activeEntry: SleepEntry? {
        entries.first(where: { $0.isActive })
    }

    private var totalSleepToday: TimeInterval {
        todayEntries.reduce(0) { $0 + $1.duration }
    }

    private var filteredEntries: [SleepEntry] {
        let cutoff = historyFilter.startDate()
        return entries.filter { $0.startTime >= cutoff }
    }

    private var weeklyChartData: [BBWeeklyBarChart.Day] {
        BBWeeklyBarChart.lastSevenDays { date in
            let dayEntries = entries.filter {
                Calendar.current.isDate($0.startTime, inSameDayAs: date) && !$0.isActive
            }
            return dayEntries.reduce(0) { $0 + $1.duration } / 3600
        }
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
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
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
        .sheet(isPresented: $showAddSheet) {
            AddSleepSheet()
        }
    }

    // MARK: - Start Sleep
    private var startSleepSection: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            HStack(spacing: BBTheme.Spacing.md) {
                sleepTypeButton(.nap)
                sleepTypeButton(.night)
            }
        }
    }

    private func sleepTypeButton(_ type: SleepEntry.SleepType) -> some View {
        Button {
            startSleep(type: type)
        } label: {
            VStack(spacing: BBTheme.Spacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(BBTheme.Colors.sleep)
                Text(type.displayName.l)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("button.start".l)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
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
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "stat.sleep_episodes",
                    value: "\(todayEntries.count)",
                    unit: "unit.times",
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep
                )
                BBStatCard(
                    title: "stat.total",
                    value: String(format: "%.1f", totalSleepToday / 3600),
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
                days: weeklyChartData,
                color: BBTheme.Colors.sleep,
                formatValue: { v in
                    v == 0 ? "0" : String(format: "%.1f", v)
                }
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.history")
            BBHistoryFilterPicker(selected: $historyFilter)

            if filteredEntries.isEmpty {
                EmptyStateView(
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    title: "empty.no_records",
                    subtitle: "empty.add_sleep"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(filteredEntries) { entry in
                        SwipeToDeleteRow(onDelete: { delete(entry) }) {
                            BBEventRow(
                                icon: entry.type.icon,
                                iconColor: BBTheme.Colors.sleep,
                                title: entry.type.displayName.l,
                                subtitle: entry.isActive ? "status.sleeping_now".l : entry.durationFormatted,
                                time: entry.startTime.formatted(.dateTime.hour().minute()),
                                trailing: entry.startTime.formatted(.dateTime.day().month())
                            )
                        }
                    }
                }

                BBDeleteHistoryButton {
                    deleteFiltered()
                }
            }
        }
    }

    private func startSleep(type: SleepEntry.SleepType) {
        let entry = SleepEntry(startTime: Date(), type: type)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func stopSleep(_ entry: SleepEntry) {
        entry.endTime = Date()
        try? modelContext.save()
    }

    private func delete(_ entry: SleepEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func deleteFiltered() {
        filteredEntries.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Sleep Timer Card
struct SleepTimerCard: View {
    let entry: SleepEntry
    let onStop: () -> Void

    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("status.baby_sleeping".l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.sleep)
                    Text(entry.type.displayName.l)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                Spacer()
                Text(elapsedFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BBTheme.Colors.sleep)
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
        .onReceive(timer) { _ in elapsed = Date().timeIntervalSince(entry.startTime) }
        .onAppear { elapsed = Date().timeIntervalSince(entry.startTime) }
    }

    private var elapsedFormatted: String {
        let hours = Int(elapsed) / 3600
        let mins = Int(elapsed) % 3600 / 60
        let secs = Int(elapsed) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, mins, secs)
        }
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Add Sleep Sheet
struct AddSleepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: SleepEntry.SleepType = .nap
    @State private var selectedLocation: SleepEntry.SleepLocation = .crib
    @State private var startTime = Date()
    @State private var endTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    // Type
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.sleep_type".l)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        HStack(spacing: BBTheme.Spacing.md) {
                            ForEach(SleepEntry.SleepType.allCases, id: \.self) { type in
                                Button { selectedType = type } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon).font(.system(size: 24))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.sleep)
                                        Text(type.displayName.l).font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                    .background(selectedType == type ? BBTheme.Colors.sleep : BBTheme.Colors.surface)
                                    .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                                }
                                .buttonStyle(BBScaleButtonStyle())
                            }
                        }
                    }

                    // Location
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.location".l)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        HStack(spacing: BBTheme.Spacing.sm) {
                            ForEach(SleepEntry.SleepLocation.allCases, id: \.self) { loc in
                                Button { selectedLocation = loc } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: loc.icon).font(.system(size: 20))
                                            .foregroundStyle(selectedLocation == loc ? .white : BBTheme.Colors.primary)
                                        Text(loc.displayName.l).font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedLocation == loc ? .white : BBTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(selectedLocation == loc ? BBTheme.Colors.primary : BBTheme.Colors.surface)
                                    .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                                }
                                .buttonStyle(BBScaleButtonStyle())
                            }
                        }
                    }

                    // Times
                    DatePicker("form.start_time".l, selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    DatePicker("form.end_time".l, selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("sheet.add_sleep".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func save() {
        let entry = SleepEntry(startTime: startTime, type: selectedType, location: selectedLocation)
        entry.endTime = endTime
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

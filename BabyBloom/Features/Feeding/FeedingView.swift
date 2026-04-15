import SwiftUI
import SwiftData

struct FeedingView: View {
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var entries: [FeedingEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var quickAddType: FeedingEntry.FeedingType = .breast
    @State private var historyFilter: HistoryFilter = .day

    private var todayEntries: [FeedingEntry] {
        entries.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var activeTimer: FeedingEntry? {
        entries.first(where: { $0.isActive })
    }

    private var filteredEntries: [FeedingEntry] {
        let cutoff = historyFilter.startDate()
        return entries.filter { $0.startTime >= cutoff }
    }

    private var weeklyChartData: [BBWeeklyBarChart.Day] {
        BBWeeklyBarChart.lastSevenDays { date in
            Double(entries.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Active timer card
                    if let active = activeTimer {
                        FeedingTimerCard(entry: active) {
                            stopFeeding(active)
                        }
                        .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // Quick add (hidden while timer is running)
                    if activeTimer == nil {
                        quickAddSection
                            .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // Today stats
                    todayStatsSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // Weekly chart
                    weeklyChartSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // History
                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("tab.feeding".l)
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
            AddFeedingSheet(initialType: quickAddType)
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_add")

            HStack(spacing: BBTheme.Spacing.md) {
                ForEach(FeedingEntry.FeedingType.allCases, id: \.self) { type in
                    Button {
                        quickStart(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(BBTheme.Colors.feeding)
                            Text(type.displayName.l)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Text(type == .breast ? "button.start".l : "button.add_manually".l)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.feeding.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                .stroke(BBTheme.Colors.feeding.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(BBScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Today Stats
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.today")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "stat.feedings",
                    value: "\(todayEntries.count)",
                    unit: "unit.times",
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding
                )
                BBStatCard(
                    title: "stat.total",
                    value: totalMinutesToday,
                    unit: "unit.min",
                    icon: "clock.fill",
                    color: BBTheme.Colors.primary
                )
            }
        }
    }

    private var totalMinutesToday: String {
        let total = todayEntries.reduce(0.0) { $0 + $1.duration }
        return "\(Int(total / 60))"
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weekly_chart")
            BBWeeklyBarChart(
                days: weeklyChartData,
                color: BBTheme.Colors.feeding
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
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    title: "empty.no_records",
                    subtitle: "empty.add_first_feeding"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(filteredEntries) { entry in
                        SwipeToDeleteRow(onDelete: { delete(entry) }) {
                            FeedingEntryRow(entry: entry)
                        }
                    }
                }

                BBDeleteHistoryButton {
                    deleteFiltered()
                }
            }
        }
    }

    private func quickStart(_ type: FeedingEntry.FeedingType) {
        if type == .breast {
            let entry = FeedingEntry(startTime: Date(), type: .breast, side: .left, volumeML: nil)
            modelContext.insert(entry)
            try? modelContext.save()
        } else {
            quickAddType = type
            showAddSheet = true
        }
    }

    private func stopFeeding(_ entry: FeedingEntry) {
        entry.endTime = Date()
        try? modelContext.save()
    }

    private func delete(_ entry: FeedingEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func deleteFiltered() {
        filteredEntries.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Timer Card
struct FeedingTimerCard: View {
    let entry: FeedingEntry
    let onStop: () -> Void

    @State private var elapsed: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("tab.feeding".l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.feeding)
                    Text(entry.displayTitle)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                Spacer()
                Text(elapsedFormatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BBTheme.Colors.feeding)
            }

            // Breast side switcher (for breast feeding)
            if entry.type == .breast {
                HStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(FeedingEntry.BreastSide.allCases, id: \.self) { side in
                        Button {
                            entry.side = side
                        } label: {
                            Text(side.displayName.l)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(entry.side == side ? .white : BBTheme.Colors.feeding)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(entry.side == side ? BBTheme.Colors.feeding : BBTheme.Colors.feeding.opacity(0.1))
                                .cornerRadius(BBTheme.Radius.pill)
                        }
                        .buttonStyle(BBScaleButtonStyle())
                    }
                }
            }

            BBPrimaryButton("button.finish".l, icon: "stop.fill") {
                onStop()
            }
        }
        .padding(BBTheme.Spacing.lg)
        .background(BBTheme.Colors.feeding.opacity(0.08))
        .cornerRadius(BBTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                .stroke(BBTheme.Colors.feeding.opacity(0.3), lineWidth: 1.5)
        )
        .onReceive(timer) { _ in
            elapsed = Date().timeIntervalSince(entry.startTime)
        }
        .onAppear { elapsed = Date().timeIntervalSince(entry.startTime) }
    }

    private var elapsedFormatted: String {
        let mins = Int(elapsed) / 60
        let secs = Int(elapsed) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Entry Row
struct FeedingEntryRow: View {
    let entry: FeedingEntry

    var body: some View {
        BBEventRow(
            icon: entry.type.icon,
            iconColor: Color(hex: entry.type.color),
            title: entry.displayTitle,
            subtitle: entry.isActive ? "status.feeding_active".l : entry.durationFormatted,
            time: entry.startTime.formatted(.dateTime.hour().minute()),
            trailing: entry.startTime.formatted(.dateTime.day().month())
        )
    }
}

// MARK: - Add Feeding Sheet
struct AddFeedingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: FeedingEntry.FeedingType
    @State private var selectedSide: FeedingEntry.BreastSide = .left
    @State private var volumeML: Double = 0
    @State private var startTimer = false

    init(initialType: FeedingEntry.FeedingType = .breast) {
        _selectedType = State(initialValue: initialType)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Type selector
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.feeding_type".l)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)

                        HStack(spacing: BBTheme.Spacing.sm) {
                            ForEach(FeedingEntry.FeedingType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation { selectedType = type }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon)
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.primary)
                                        Text(type.displayName.l)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, BBTheme.Spacing.md)
                                    .background(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.surface)
                                    .cornerRadius(BBTheme.Radius.md)
                                    .bbShadow(BBTheme.Shadow.card)
                                }
                                .buttonStyle(BBScaleButtonStyle())
                            }
                        }
                    }

                    // Breast side (if breast)
                    if selectedType == .breast {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.breast".l)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)

                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(FeedingEntry.BreastSide.allCases, id: \.self) { side in
                                    Button {
                                        selectedSide = side
                                    } label: {
                                        HStack {
                                            Image(systemName: side.icon)
                                            Text(side.displayName.l)
                                        }
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundStyle(selectedSide == side ? .white : BBTheme.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(selectedSide == side ? BBTheme.Colors.feeding : BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md)
                                        .bbShadow(BBTheme.Shadow.card)
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                        }
                    }

                    // Volume (if formula/pumped)
                    if selectedType == .formula || selectedType == .pumped {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            HStack {
                                Text("form.volume_ml".l)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                                Spacer()
                                Text("\(Int(volumeML)) \("unit.ml".l)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.feeding)
                            }
                            Slider(value: $volumeML, in: 0...500, step: 10)
                                .tint(BBTheme.Colors.feeding)
                            HStack {
                                Text("0")
                                Spacer()
                                Text("500 \("unit.ml".l)")
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)
                    }

                    // Timer toggle
                    Toggle(isOn: $startTimer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("form.start_timer".l)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Text("form.timer_hint".l)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    }
                    .tint(BBTheme.Colors.primary)
                    .padding(BBTheme.Spacing.md)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.md)
                    .bbShadow(BBTheme.Shadow.card)

                    // Start button
                    BBPrimaryButton(startTimer ? "button.start_feeding".l : "button.save".l, icon: startTimer ? "play.fill" : "checkmark") {
                        save()
                    }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("sheet.new_feeding".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func save() {
        let ml: Double? = (selectedType == .formula || selectedType == .pumped) ? volumeML : nil
        let entry = FeedingEntry(
            startTime: Date(),
            type: selectedType,
            side: selectedType == .breast ? selectedSide : nil,
            volumeML: ml
        )
        if !startTimer {
            entry.endTime = Date()
        }
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(color.opacity(0.6))
            }
            Text(title.l)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(subtitle.l)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(BBTheme.Spacing.xl)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }
}

import SwiftUI
import SwiftData

struct FeedingView: View {
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var entries: [FeedingEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var activeEntry: FeedingEntry?

    private var todayEntries: [FeedingEntry] {
        entries.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var activeTimer: FeedingEntry? {
        entries.first(where: { $0.isActive })
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

                    // Today stats
                    todayStatsSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // History
                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Кормление")
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
            AddFeedingSheet()
        }
    }

    // MARK: - Today Stats
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "Сегодня")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "Кормлений",
                    value: "\(todayEntries.count)",
                    unit: "раз",
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding
                )
                BBStatCard(
                    title: "Суммарно",
                    value: totalMinutesToday,
                    unit: "мин",
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

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "История")

            if entries.isEmpty {
                EmptyStateView(
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    title: "Нет записей",
                    subtitle: "Нажмите + чтобы добавить первое кормление"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(entries.prefix(30)) { entry in
                        FeedingEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func stopFeeding(_ entry: FeedingEntry) {
        entry.endTime = Date()
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
                    Text("Кормление")
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
                            Text(side.displayName)
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

            BBPrimaryButton("Завершить", icon: "stop.fill") {
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
            subtitle: entry.isActive ? "В процессе..." : entry.durationFormatted,
            time: entry.startTime.formatted(.dateTime.hour().minute()),
            trailing: entry.startTime.formatted(.dateTime.day().month())
        )
    }
}

// MARK: - Add Feeding Sheet
struct AddFeedingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: FeedingEntry.FeedingType = .breast
    @State private var selectedSide: FeedingEntry.BreastSide = .left
    @State private var volumeML: Double = 0
    @State private var volumeText = ""
    @State private var startTimer = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Type selector
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("Тип кормления")
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
                                        Text(type.displayName)
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
                            Text("Грудь")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)

                            HStack(spacing: BBTheme.Spacing.sm) {
                                ForEach(FeedingEntry.BreastSide.allCases, id: \.self) { side in
                                    Button {
                                        selectedSide = side
                                    } label: {
                                        HStack {
                                            Image(systemName: side.icon)
                                            Text(side.displayName)
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
                            Text("Объём (мл)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)

                            TextField("Введите мл", text: $volumeText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .padding(BBTheme.Spacing.md)
                                .background(BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md)
                                .bbShadow(BBTheme.Shadow.card)
                        }
                    }

                    // Timer toggle
                    Toggle(isOn: $startTimer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Запустить таймер")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Text("Зафиксируйте длительность кормления")
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
                    BBPrimaryButton(startTimer ? "Начать кормление" : "Сохранить", icon: startTimer ? "play.fill" : "checkmark") {
                        save()
                    }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Новое кормление")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func save() {
        let ml = Double(volumeText)
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
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(subtitle)
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

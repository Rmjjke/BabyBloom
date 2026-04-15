import SwiftUI
import SwiftData

struct DiaperView: View {
    @Query(sort: \DiaperEntry.time, order: .reverse) private var entries: [DiaperEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false

    private var todayEntries: [DiaperEntry] {
        entries.filter { Calendar.current.isDateInToday($0.time) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Quick add
                    quickAddSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // Today stats
                    todaySection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // History
                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Подгузники")
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
            AddDiaperSheet()
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "Быстро добавить")

            HStack(spacing: BBTheme.Spacing.md) {
                ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
                    Button {
                        quickAdd(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(BBTheme.Colors.diaper)
                            Text(type.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.diaper.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                .stroke(BBTheme.Colors.diaper.opacity(0.4), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(BBScaleButtonStyle())
                }
            }
        }
    }

    // MARK: - Today
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "Сегодня")

            let wetCount = todayEntries.filter { $0.type == .wet || $0.type == .both }.count
            let dirtyCount = todayEntries.filter { $0.type == .dirty || $0.type == .both }.count

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "Мокрых",
                    value: "\(wetCount)",
                    unit: "шт",
                    icon: "drop.fill",
                    color: Color(hex: "#B0C4F5")
                )
                BBStatCard(
                    title: "Грязных",
                    value: "\(dirtyCount)",
                    unit: "шт",
                    icon: "circle.fill",
                    color: BBTheme.Colors.diaper
                )
            }

            // Daily norm progress
            BBProgressCard(
                title: "Норма в день",
                current: Double(todayEntries.count),
                target: 8,
                unit: "шт",
                color: BBTheme.Colors.diaper,
                icon: "checkmark.circle.fill"
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "История")

            if entries.isEmpty {
                EmptyStateView(
                    icon: "drop.fill",
                    color: BBTheme.Colors.diaper,
                    title: "Нет записей",
                    subtitle: "Нажмите кнопку выше, чтобы добавить запись"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(entries.prefix(20)) { entry in
                        DiaperEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private func quickAdd(_ type: DiaperEntry.DiaperType) {
        let entry = DiaperEntry(time: Date(), type: type)
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

// MARK: - Diaper Entry Row
struct DiaperEntryRow: View {
    let entry: DiaperEntry

    var body: some View {
        BBEventRow(
            icon: entry.type.icon,
            iconColor: BBTheme.Colors.diaper,
            title: entry.displayTitle,
            subtitle: colorSubtitle,
            time: entry.time.formatted(.dateTime.hour().minute()),
            trailing: entry.time.formatted(.dateTime.day().month())
        )
    }

    private var colorSubtitle: String {
        if let color = entry.color {
            return color.isWarning ? "⚠️ \(color.displayName)" : color.displayName
        }
        return entry.notes ?? ""
    }
}

// MARK: - Add Diaper Sheet
struct AddDiaperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: DiaperEntry.DiaperType = .wet
    @State private var selectedColor: DiaperEntry.StoolColor? = nil
    @State private var notes = ""
    @State private var time = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    // Type
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("Тип").font(.system(size: 16, weight: .semibold, design: .rounded))
                        HStack(spacing: BBTheme.Spacing.sm) {
                            ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
                                Button { selectedType = type } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon).font(.system(size: 22))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.diaper)
                                        Text(type.displayName).font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                    .background(selectedType == type ? BBTheme.Colors.diaper : BBTheme.Colors.surface)
                                    .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                                }
                                .buttonStyle(BBScaleButtonStyle())
                            }
                        }
                    }

                    // Stool color
                    if selectedType == .dirty || selectedType == .both {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("Цвет стула").font(.system(size: 16, weight: .semibold, design: .rounded))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: BBTheme.Spacing.sm) {
                                ForEach(DiaperEntry.StoolColor.allCases, id: \.self) { color in
                                    Button {
                                        selectedColor = selectedColor == color ? nil : color
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: color.hexColor))
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColor == color ? BBTheme.Colors.primary : .clear, lineWidth: 2.5)
                                                )
                                                .overlay(
                                                    selectedColor == color
                                                    ? Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                    : nil
                                                )
                                            Text(color.displayName)
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundStyle(BBTheme.Colors.textSecondary)
                                        }
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                            if let c = selectedColor, c.isWarning {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text("Этот цвет стула требует внимания врача")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.orange)
                                }
                                .padding(BBTheme.Spacing.sm)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(BBTheme.Radius.sm)
                            }
                        }
                    }

                    // Notes
                    TextField("Заметки (необязательно)", text: $notes, axis: .vertical)
                        .lineLimit(3)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)

                    // Time
                    DatePicker("Время", selection: $time, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("Сохранить", icon: "checkmark") { save() }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Подгузник")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    private func save() {
        let entry = DiaperEntry(time: time, type: selectedType, color: selectedColor, notes: notes.isEmpty ? nil : notes)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

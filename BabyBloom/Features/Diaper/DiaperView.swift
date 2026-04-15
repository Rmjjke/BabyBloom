import SwiftUI
import SwiftData

struct DiaperView: View {
    @Query(sort: \DiaperEntry.time, order: .reverse) private var entries: [DiaperEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var showNormEditor = false
    @State private var historyFilter: HistoryFilter = .day
    @AppStorage("diaperDailyNorm") private var dailyNorm = 8

    private var todayEntries: [DiaperEntry] {
        entries.filter { Calendar.current.isDateInToday($0.time) }
    }

    private var isOverNorm: Bool { todayEntries.count > dailyNorm }

    private var filteredEntries: [DiaperEntry] {
        let cutoff = historyFilter.startDate()
        return entries.filter { $0.time >= cutoff }
    }

    private var weeklyChartData: [BBWeeklyBarChart.Day] {
        BBWeeklyBarChart.lastSevenDays { date in
            Double(entries.filter { Calendar.current.isDate($0.time, inSameDayAs: date) }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    quickAddSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    todaySection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    weeklyChartSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("nav.diapers".l)
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
            BBSectionHeader(title: "section.quick_add")

            HStack(spacing: BBTheme.Spacing.md) {
                ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
                    Button {
                        quickAdd(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            Image(systemName: type.icon)
                                .font(.system(size: 28))
                                .foregroundStyle(BBTheme.Colors.diaper)
                            Text(type.displayName.l)
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
            HStack {
                Text("section.today".l)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Button {
                    showNormEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 13))
                        Text(String(format: "diaper.norm.fmt".l, dailyNorm))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(BBTheme.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(BBTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(BBTheme.Radius.pill)
                }
                .sheet(isPresented: $showNormEditor) {
                    DiaperNormEditorSheet(dailyNorm: $dailyNorm)
                }
            }

            let wetCount = todayEntries.filter { $0.type == .wet || $0.type == .both }.count
            let dirtyCount = todayEntries.filter { $0.type == .dirty || $0.type == .both }.count

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                BBStatCard(
                    title: "stat.wet",
                    value: "\(wetCount)",
                    unit: "unit.pcs",
                    icon: "drop.fill",
                    color: Color(hex: "#B0C4F5"),
                    overLimit: false
                )
                BBStatCard(
                    title: "stat.dirty",
                    value: "\(dirtyCount)",
                    unit: "unit.pcs",
                    icon: "circle.fill",
                    color: BBTheme.Colors.diaper,
                    overLimit: false
                )
            }

            BBProgressCard(
                title: "stat.daily_norm",
                current: Double(todayEntries.count),
                target: Double(dailyNorm),
                unit: "unit.pcs",
                color: BBTheme.Colors.diaper,
                icon: "checkmark.circle.fill",
                overLimit: isOverNorm
            )
        }
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weekly_chart")
            BBWeeklyBarChart(
                days: weeklyChartData,
                color: BBTheme.Colors.diaper
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
                    icon: "drop.fill",
                    color: BBTheme.Colors.diaper,
                    title: "empty.no_records",
                    subtitle: "empty.add_above"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(filteredEntries) { entry in
                        SwipeToDeleteRow(onDelete: { delete(entry) }) {
                            DiaperEntryRow(entry: entry)
                        }
                    }
                }

                BBDeleteHistoryButton {
                    deleteFiltered()
                }
            }
        }
    }

    private func quickAdd(_ type: DiaperEntry.DiaperType) {
        let entry = DiaperEntry(time: Date(), type: type)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func delete(_ entry: DiaperEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private func deleteFiltered() {
        filteredEntries.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Norm Editor Sheet
struct DiaperNormEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var dailyNorm: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: BBTheme.Spacing.xl) {
                Text("💧")
                    .font(.system(size: 56))
                    .padding(.top, BBTheme.Spacing.xl)

                VStack(spacing: BBTheme.Spacing.sm) {
                    Text("diaper.norm.label".l)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text("diaper.norm.hint".l)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: BBTheme.Spacing.xl) {
                    Button {
                        if dailyNorm > 1 { dailyNorm -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(BBTheme.Colors.primary.opacity(dailyNorm > 1 ? 1 : 0.3))
                    }
                    .disabled(dailyNorm <= 1)

                    Text("\(dailyNorm)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .frame(minWidth: 80)

                    Button {
                        if dailyNorm < 20 { dailyNorm += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(BBTheme.Colors.primary.opacity(dailyNorm < 20 ? 1 : 0.3))
                    }
                    .disabled(dailyNorm >= 20)
                }
                .padding(.vertical, BBTheme.Spacing.lg)
                .padding(.horizontal, BBTheme.Spacing.xl)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.lg)
                .bbShadow(BBTheme.Shadow.card)
                .padding(.horizontal, BBTheme.Spacing.xl)

                BBPrimaryButton("button.save".l, icon: "checkmark") { dismiss() }
                    .padding(.horizontal, BBTheme.Spacing.xl)

                Spacer()
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("diaper.norm.edit".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
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
            return color.isWarning ? "⚠️ \(color.displayName.l)" : color.displayName.l
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
                        Text("form.type".l).font(.system(size: 16, weight: .semibold, design: .rounded))
                        HStack(spacing: BBTheme.Spacing.sm) {
                            ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
                                Button { selectedType = type } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: type.icon).font(.system(size: 22))
                                            .foregroundStyle(selectedType == type ? .white : BBTheme.Colors.diaper)
                                        Text(type.displayName.l).font(.system(size: 13, weight: .medium, design: .rounded))
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
                            Text("form.stool_color".l).font(.system(size: 16, weight: .semibold, design: .rounded))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: BBTheme.Spacing.sm) {
                                ForEach(DiaperEntry.StoolColor.allCases, id: \.self) { color in
                                    Button {
                                        selectedColor = selectedColor == color ? nil : color
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: color.hexColor))
                                                .frame(width: 36, height: 36)
                                                .overlay(Circle().stroke(selectedColor == color ? BBTheme.Colors.primary : .clear, lineWidth: 2.5))
                                                .overlay(
                                                    selectedColor == color
                                                    ? Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                                    : nil
                                                )
                                            Text(color.displayName.l)
                                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                                .foregroundStyle(BBTheme.Colors.textSecondary)
                                        }
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                            if let c = selectedColor, c.isWarning {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                    Text("diaper.color.warning".l)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.orange)
                                }
                                .padding(BBTheme.Spacing.sm)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(BBTheme.Radius.sm)
                            }
                        }
                    }

                    TextField("form.notes_optional".l, text: $notes, axis: .vertical)
                        .lineLimit(3).padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    DatePicker("form.time".l, selection: $time, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("sheet.diaper".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
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

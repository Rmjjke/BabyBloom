import SwiftUI
import SwiftData

struct DiaperView: View {
    @Query(sort: \DiaperEntry.time, order: .reverse) private var entries: [DiaperEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showAddSheet = false
    @State private var showNormEditor = false
    @State private var historyFilter: HistoryFilter = .day
    @AppStorage("diaperDailyNorm") private var dailyNorm = 8
    /// The history list's free window sells from here; nothing else on this
    /// screen is gated.
    @Environment(SubscriptionManager.self) private var store
    @State private var showPaywall = false

    private var baby: Baby? { babies.first }

    private var todayEntries: [DiaperEntry] {
        entries.filter { Calendar.current.isDateInToday($0.time) }
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
        .entrySheet(isPresented: $showAddSheet) {
            AddDiaperSheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .historyLock)
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_add")

            // Two columns from xLarge: in a third of a 320-pt row «Грязный»
            // keeps 5.9 pt there (63.4 in 69.3), under the 8-pt spare. One at
            // accessibility sizes, as every quick row there, so the tiles keep
            // one shape; two would still hold the word (102.3 in 120).
            let tileColumns = BBTileColumns(large: 3, xLarge: 2, xxLarge: 2, xxxLarge: 2, accessibility: 1)
            let count = tileColumns.count(at: dynamicTypeSize)
            if count == tileColumns.large {
                HStack(spacing: BBTheme.Spacing.md) {
                    quickAddTiles
                }
            } else if count == 1 {
                VStack(spacing: BBTheme.Spacing.md) {
                    quickAddTiles
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.md),
                                         count: count),
                          spacing: BBTheme.Spacing.md) {
                    quickAddTiles
                }
            }
        }
    }

    private var quickAddTiles: some View {
        ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
            Button {
                quickAdd(type)
            } label: {
                VStack(spacing: BBTheme.Spacing.sm) {
                    Image(systemName: type.icon)
                        .font(BBTheme.Typography.scaled(28, relativeTo: .body, weight: .regular, design: .default))
                        .foregroundStyle(BBTheme.Colors.diaper)
                    Text(type.displayName.l)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                // sm at the sides: with md, «Грязный» broke in a third of a
                // 320-pt row at Large (58.5 pt in 53.3). The word is centred
                // inside the fill, so a wider screen draws it as before.
                .padding(.horizontal, BBTheme.Spacing.sm)
                .padding(.vertical, BBTheme.Spacing.md)
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

    // MARK: - Today
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            // The norm chip under the title at accessibility sizes: beside it
            // the ru row is 19.5 pt wider than a 320-pt screen at AX2. Below
            // them it holds at 320 pt at every size (56.8 pt to spare at
            // xxxLarge), so the text size decides, not the fit.
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.title3("section.today".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    normChip
                }
            } else {
                HStack {
                    BBTheme.Typography.title3("section.today".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Spacer()
                    normChip
                }
            }

            let wetCount = todayEntries.filter { $0.type == .wet || $0.type == .both }.count
            let dirtyCount = todayEntries.filter { $0.type == .dirty || $0.type == .both }.count

            BBStatGrid {
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

            // Never `overLimit`. A nappy count is a MINIMUM — the reference
            // tables this app cites give a floor and no ceiling — so more
            // nappies than the norm is reassurance, and the card used to turn
            // red with a warning triangle for it. Under the norm stays neutral
            // too: a quiet morning is not a finding, and only weight gain
            // raises anything in this app (DECISIONS 2026-08-25).
            BBProgressCard(
                title: "stat.daily_norm",
                current: Double(todayEntries.count),
                target: Double(dailyNorm),
                unit: "unit.pcs",
                color: BBTheme.Colors.diaper,
                icon: "checkmark.circle.fill"
            )
        }
        // On the section, not the chip: the chip sits in either shape of the
        // Today row, and a text-size change would close the open editor.
        .sheet(isPresented: $showNormEditor) {
            DiaperNormEditorSheet(dailyNorm: $dailyNorm)
        }
    }

    /// The glyph grows with its word, as a tile's glyph does.
    private var normChip: some View {
        Button {
            showNormEditor = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "target")
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .default))
                Text(String(format: "diaper.norm.fmt".l, dailyNorm))
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(BBTheme.Colors.primary.opacity(0.1))
            .cornerRadius(BBTheme.Radius.pill)
        }
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weekly_chart")
            BBWeeklyBarChart(
                valueFor: { date in
                    Double(entries.filter { Calendar.current.isDate($0.time, inSameDayAs: date) }.count)
                },
                color: BBTheme.Colors.diaper
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        BBHistorySection(
            entries: entries,
            filter: $historyFilter,
            dateKeyPath: \.time,
            emptyIcon: "drop.fill",
            emptyColor: BBTheme.Colors.diaper,
            emptyTitle: "empty.no_records",
            emptySubtitle: "empty.add_above",
            historyCutoff: store.historyCutoff,
            row: { DiaperEntryRow(entry: $0) },
            onDelete: { delete($0) },
            onDeleteAll: { deleteAll($0) },
            lockSurface: .diaper,
            onUnlock: { showPaywall = true }
        )
    }

    private func quickAdd(_ type: DiaperEntry.DiaperType) {
        let entry = DiaperEntry(time: Date(), type: type)
        entry.baby = baby
        modelContext.insert(entry)
        try? modelContext.save()
        NotificationManager.shared.onDiaperSaved(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l
        )
        reviewPrompt.entrySaved(.diaper)
    }

    private func delete(_ entry: DiaperEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        // @Query may not update synchronously; compute from the pre-delete array.
        let remaining = entries.filter { $0 !== entry }
        NotificationManager.shared.onDiaperDeleted(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            lastRemainingDiaperTime: remaining.map(\.time).max()
        )
    }

    private func deleteAll(_ items: [DiaperEntry]) {
        items.forEach { modelContext.delete($0) }
        try? modelContext.save()
        let remaining = entries.filter { entry in !items.contains { $0 === entry } }
        NotificationManager.shared.onDiaperDeleted(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            lastRemainingDiaperTime: remaining.map(\.time).max()
        )
    }
}

// MARK: - Norm Editor Sheet
struct DiaperNormEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var dailyNorm: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: BBTheme.Spacing.xl) {
                // A decoration; VoiceOver would read the symbol's name.
                Image(systemName: "drop.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BBTheme.Colors.diaper)
                    .padding(.top, BBTheme.Spacing.xl)
                    .accessibilityHidden(true)

                VStack(spacing: BBTheme.Spacing.sm) {
                    // Above Large it names the sheet: the bar has no title.
                    BBTheme.Typography.title2("diaper.norm.label".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .accessibilityAddTraits(dynamicTypeSize > .large ? .isHeader : [])
                    Text("diaper.norm.hint".l)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
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
                        .font(BBTheme.Typography.scaled(64, relativeTo: .largeTitle, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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
            // Above Large the heading in the content names the sheet, as on
            // every other sheet: the system title right of Cancel grows with
            // the text and at AX2 on a 320-pt screen reaches the screen's edge.
            .navigationTitle(dynamicTypeSize > .large ? "" : "diaper.norm.edit".l)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BBBarButton(.cancel) { dismiss() }
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
            time: entry.time.appTimeOfDay,
            trailing: entry.time.appDayMonth
        )
    }

    private var colorSubtitle: String {
        if let color = entry.color {
            return color.displayName.l
        }
        return entry.notes ?? ""
    }
}

// MARK: - Add Diaper Sheet
struct AddDiaperSheet: View {
    @State private var sheetDetent: PresentationDetent = .large
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var selectedType: DiaperEntry.DiaperType = .wet
    @State private var selectedColor: DiaperEntry.StoolColor? = nil
    @State private var notes = ""
    @State private var time = Date()

    private var typeTiles: some View {
        ForEach(DiaperEntry.DiaperType.allCases, id: \.self) { type in
            Button { selectedType = type } label: {
                VStack(spacing: 6) {
                    Image(systemName: type.icon).font(BBTheme.Typography.scaled(22, relativeTo: .body, weight: .regular, design: .default))
                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.diaper)
                    Text(type.displayName.l).font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    BBSheetHeading(title: "sheet.diaper".l)
                    // Type
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.type".l).font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                        // Two columns at accessibility sizes: in a third of a
                        // 320-pt sheet «Грязный» breaks at AX2 (92.9 pt in
                        // 90.7). Below them the row stays an HStack: a grid
                        // sets it a third of a point lower.
                        let typeColumns = BBTileColumns(large: 3, xLarge: 3, xxLarge: 3, xxxLarge: 3, accessibility: 2)
                        let typeCount = typeColumns.count(at: dynamicTypeSize)
                        if typeCount == typeColumns.large {
                            HStack(spacing: BBTheme.Spacing.sm) {
                                typeTiles
                            }
                        } else {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.sm),
                                                     count: typeCount),
                                      spacing: BBTheme.Spacing.sm) {
                                typeTiles
                            }
                        }
                    }

                    // Stool color
                    if selectedType == .dirty || selectedType == .both {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.stool_color".l).font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                            // The disc stays 36 pt; the name grows. «Коричневый»
                            // misses a quarter of a 320-pt sheet from xLarge
                            // (68.0 pt in 66.0) and a third at AX2 (107.6 in 90.7).
                            // At Large four hold it by 3.6, under the 8-pt spare
                            // but measured with and without Bold Text; three
                            // would set the seven swatches 3 + 3 + 1 on every phone.
                            let stoolColumns = BBTileColumns(large: 4, xLarge: 3, xxLarge: 3, xxxLarge: 3, accessibility: 2)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                                     count: stoolColumns.count(at: dynamicTypeSize)),
                                      spacing: BBTheme.Spacing.sm) {
                                ForEach(DiaperEntry.StoolColor.allCases, id: \.self) { color in
                                    Button {
                                        selectedColor = selectedColor == color ? nil : color
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: color.hexColor))
                                                .frame(width: 36, height: 36)
                                                // Inside the disc, under the selected ring.
                                                .overlay(Circle().strokeBorder(color.needsEdge ? BBTheme.Colors.textSecondary : .clear, lineWidth: 1))
                                                .overlay(Circle().stroke(selectedColor == color ? BBTheme.Colors.primary : .clear, lineWidth: 2.5))
                                                .overlay(
                                                    selectedColor == color
                                                    ? Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: color.checkHex))
                                                    : nil
                                                )
                                            Text(color.displayName.l)
                                                .font(BBTheme.Typography.scaled(10, relativeTo: .body, weight: .medium, design: .rounded))
                                                .foregroundStyle(BBTheme.Colors.textSecondary)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 44)   // ≥44pt tap zone
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                            if let c = selectedColor, c.isWarning {
                                // The warning wraps on narrow screens (ru at Large on a
                                // 320-pt one, es at xxxLarge on a 402-pt phone), and the
                                // first baseline keeps the triangle on its first line at
                                // every size, so each size has one shape.
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                    Text("diaper.color.warning".l)
                                        .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                                        .foregroundStyle(.orange)
                                }
                                .padding(BBTheme.Spacing.sm)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(BBTheme.Radius.sm)
                            }
                        }
                    }

                    TextField("form.notes_optional".l, text: $notes, axis: .vertical)
                        .bbPlaceholderLabel(design: .default)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    BBLabeledPicker("form.time".l) { label in
                        DatePicker(label, selection: $time, displayedComponents: [.date, .hourAndMinute])
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
            .bbSheetTitle("sheet.diaper".l)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BBBarButton(.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BBBarButton(.save) { save() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $sheetDetent)
    }

    private func save() {
        let entry = DiaperEntry(time: time, type: selectedType, color: selectedColor, notes: notes.isEmpty ? nil : notes)
        entry.baby = babies.first
        modelContext.insert(entry)
        try? modelContext.save()
        let baby = babies.first
        NotificationManager.shared.onDiaperSaved(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l
        )
        reviewPrompt.entrySaved(.diaper)
        dismiss()
    }
}

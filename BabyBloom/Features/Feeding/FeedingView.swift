import SwiftUI
import SwiftData

struct FeedingView: View {
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var entries: [FeedingEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // Identifiable request drives `.entrySheet(item:)` so the sheet is rebuilt with the
    // tapped type on every present. The previous `.sheet(isPresented:)` read a
    // separate @State (`quickAddType`) whose value was captured stale — the sheet
    // opened showing the default (breast) instead of the just-tapped type.
    @State private var addSheetRequest: FeedingSheetRequest?
    @State private var historyFilter: HistoryFilter = .day
    /// The history list's free window sells from here; nothing else on this
    /// screen is gated.
    @Environment(SubscriptionManager.self) private var store
    @State private var showPaywall = false

    private var baby: Baby? { babies.first }

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
                        FeedingTimerCard(entry: active, onSideChange: { side in
                            TimerActions.setSide(side, of: active, in: modelContext)
                        }) {
                            stopFeeding(active)
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("timer.card.feeding")
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
                // Extra bottom clearance so the history period-selector / delete-all
                // button never tucks under the tab bar.
                .padding(.bottom, BBTheme.Spacing.xxl + BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .overlay(alignment: .bottomTrailing) {
                BBFab { addSheetRequest = FeedingSheetRequest(type: .breast) }
                    .padding(.trailing, BBTheme.Spacing.md)
                    .padding(.bottom, BBTheme.Spacing.md)
            }
            .navigationTitle("tab.feeding".l)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addSheetRequest = FeedingSheetRequest(type: .breast)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BBTheme.Colors.primary)
                    }
                    // Icon only: unnamed, VoiceOver reads the symbol in the
                    // device's language, not the app's.
                    .accessibilityLabel(Text("sheet.new_feeding".l))
                }
            }
        }
        .entrySheet(item: $addSheetRequest) { request in
            AddFeedingSheet(initialType: request.type)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .historyLock)
        }
    }

    // MARK: - Quick Add
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_add")

            // Two columns from xLarge: in a third of a 320-pt row «Сцеженное»
            // keeps 3.4 pt there (81.9 in 85.3), under the 8-pt spare. One at
            // accessibility sizes, where half a row keeps 4.5 pt (131.5 in
            // 136) and Bold Text breaks the word.
            let tileColumns = BBTileColumns(large: 3, xLarge: 2, xxLarge: 2, xxxLarge: 2, accessibility: 1)
            let count = tileColumns.count(at: dynamicTypeSize)
            if count == tileColumns.large {
                HStack(spacing: BBTheme.Spacing.md) {
                    quickAddTiles(captionBox: true)
                }
            } else if count == 1 {
                VStack(spacing: BBTheme.Spacing.md) {
                    quickAddTiles(captionBox: false)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.md),
                                         count: count),
                          spacing: BBTheme.Spacing.md) {
                    quickAddTiles(captionBox: true)
                }
            }
        }
    }

    /// `captionBox`: the caption keeps a two-line box, so every tile of a row
    /// or grid is one height; in one column a tile takes its caption's height.
    private func quickAddTiles(captionBox: Bool) -> some View {
        ForEach(FeedingEntry.FeedingType.allCases, id: \.self) { type in
            Button {
                quickStart(type)
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(BBTheme.Colors.feeding)
                        .frame(width: 44, height: 44)
                        .background(BBTheme.Colors.feeding.opacity(0.22))
                        .cornerRadius(12)
                    Text(type.displayName.l)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(type == .breast ? "button.start".l : "button.add_manually".l)
                        .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        // Its own 4 pt a side: with the tile's none a one-line
                        // caption ran onto the border (es on 402 pt); 8 would
                        // break «manualmente» on 320 pt with Bold Text.
                        .padding(.horizontal, BBTheme.Spacing.xs)
                        .frame(height: captionBox ? BBTheme.Typography.scaledPointSize(30, relativeTo: .body) : nil,
                               alignment: .top)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                // No side padding: with sm, «Сцеженное» broke in a third of a
                // 320-pt row at Large (75.1 pt in 69.3). The words are centred,
                // so a wider screen draws them where they were.
                .background(BBTheme.Colors.feeding.opacity(0.07))
                .cornerRadius(BBTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .stroke(BBTheme.Colors.feeding.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(BBScaleButtonStyle())
        }
    }

    // MARK: - Today Stats
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.today")

            BBStatGrid {
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
        let total = todayEntries.filter { !$0.isActive }.reduce(0.0) { $0 + $1.duration }
        return "\(Int(total / 60))"
    }

    // MARK: - Weekly Chart
    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weekly_chart")
            BBWeeklyBarChart(
                valueFor: { date in
                    Double(entries.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) && !$0.isActive }.count)
                },
                color: BBTheme.Colors.feeding
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        BBHistorySection(
            entries: entries,
            filter: $historyFilter,
            dateKeyPath: \.startTime,
            emptyIcon: "heart.fill",
            emptyColor: BBTheme.Colors.feeding,
            emptyTitle: "empty.no_records",
            emptySubtitle: "empty.add_first_feeding",
            historyCutoff: store.historyCutoff,
            row: { FeedingEntryRow(entry: $0) },
            onDelete: { delete($0) },
            onDeleteAll: { deleteAll($0) },
            lockSurface: .feeding,
            onUnlock: { showPaywall = true }
        )
    }

    private func quickStart(_ type: FeedingEntry.FeedingType) {
        if type == .breast {
            TimerActions.startBreastfeed(in: modelContext)
        } else {
            addSheetRequest = FeedingSheetRequest(type: type)
        }
    }

    private func stopFeeding(_ entry: FeedingEntry) {
        // Stopping is what turns a running feed into a finished record — the
        // same moment of success as a manual save. Starting never asks. Only a
        // stop that actually happened asks (the Lock Screen may have won).
        if TimerActions.stop(entryID: entry.id, kind: .feeding, in: modelContext) {
            reviewPrompt.entrySaved(.feeding)
        }
    }

    private func delete(_ entry: FeedingEntry) {
        TimerActions.delete(feedings: [entry], in: modelContext)
    }

    private func deleteAll(_ items: [FeedingEntry]) {
        TimerActions.delete(feedings: items, in: modelContext)
    }
}

// MARK: - Timer Card
struct FeedingTimerCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entry: FeedingEntry
    /// Through TimerActions, so the side is saved and the Lock Screen title follows.
    let onSideChange: (FeedingEntry.BreastSide) -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            BBTimerCardHeader(label: "tab.feeding".l,
                              title: entry.displayTitle,
                              color: BBTheme.Colors.feeding,
                              startTime: entry.startTime)

            // Breast side switcher (for breast feeding)
            if entry.type == .breast {
                // Three in a row while they fit the card, else one per row,
                // flush left: in es the row is wider than a 320-pt screen's
                // card from Medium up (264 pt in 240 at Large). The pills size
                // to their words, so the row's own width decides, not a count
                // per size. One per row at accessibility sizes on any width,
                // under the header, which stacks there too.
                let stacked = VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) { sidePills }
                    .frame(maxWidth: .infinity, alignment: .leading)
                if dynamicTypeSize.isAccessibilitySize {
                    stacked
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: BBTheme.Spacing.sm) { sidePills }
                            .frame(maxWidth: .infinity)
                        stacked
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
    }

    private var sidePills: some View {
        ForEach(FeedingEntry.BreastSide.allCases, id: \.self) { side in
            Button {
                onSideChange(side)
            } label: {
                Text(side.displayName.l)
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.side == side ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(entry.side == side ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.pill)
                    .overlay(
                        Capsule()
                            .strokeBorder(entry.side == side ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(BBScaleButtonStyle())
        }
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
            time: entry.startTime.appTimeOfDay,
            trailing: entry.startTime.appDayMonth
        )
    }
}

// MARK: - Add Feeding Sheet

/// Identifiable payload for `.entrySheet(item:)`. A fresh `id` per tap gives the sheet a
/// new identity, so `AddFeedingSheet`'s `@State selectedType` is re-seeded from
/// `type` every present — the tapped type is always the one shown.
private struct FeedingSheetRequest: Identifiable {
    let id = UUID()
    let type: FeedingEntry.FeedingType
}

struct AddFeedingSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @State private var selectedType: FeedingEntry.FeedingType
    @State private var selectedSide: FeedingEntry.BreastSide = .left
    @State private var volumeML: Double = 100
    /// Set once the user drags the volume slider by hand. After that a type-switch
    /// must not overwrite their chosen volume.
    @State private var userTouchedVolume = false
    @State private var startTimer = false
    /// Drives the initial sheet height. Starts at `.large` so the timer toggle /
    /// primary action are on-screen without a manual drag.
    @State private var selectedDetent: PresentationDetent = .large

    init(initialType: FeedingEntry.FeedingType = .breast) {
        _selectedType = State(initialValue: initialType)
    }

    /// Volume of the most recent saved feeding of `type`, or nil if none.
    /// `feedings` is sorted startTime-descending, so `.first` is the latest.
    private func lastVolume(for type: FeedingEntry.FeedingType) -> Double? {
        feedings.first { $0.type == type && ($0.volumeML ?? 0) > 0 }?.volumeML
    }

    /// Seed the slider with the last-used volume for the current type (100ml
    /// fallback), unless the user has already touched the slider by hand.
    private func applyDefaultVolume() {
        guard !userTouchedVolume,
              selectedType == .formula || selectedType == .pumped else { return }
        volumeML = lastVolume(for: selectedType) ?? 100
    }

    private var typeTiles: some View {
        ForEach(FeedingEntry.FeedingType.allCases, id: \.self) { type in
            Button {
                withAnimation { selectedType = type }
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: type.icon)
                        .font(BBTheme.Typography.scaled(22, relativeTo: .body, weight: .regular, design: .default))
                        .foregroundStyle(BBTheme.Colors.primary)
                    Text(type.displayName.l)
                        .font(BBTheme.Typography.scaled(12, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, BBTheme.Spacing.md)
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

    private var sideChips: some View {
        ForEach(FeedingEntry.BreastSide.allCases, id: \.self) { side in
            Button {
                selectedSide = side
            } label: {
                // xs between glyph and word: with the default 8, «Izquierdo»
                // broke in a third of a 320-pt sheet at Large with Bold Text
                // (67.6 pt in 64.3).
                HStack(spacing: BBTheme.Spacing.xs) {
                    Image(systemName: side.icon)
                    Text(side.displayName.l)
                }
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(selectedSide == side ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedSide == side ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .strokeBorder(selectedSide == side ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
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
                    BBSheetHeading(title: "sheet.new_feeding".l)

                    // Type selector
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        Text("form.feeding_type".l)
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)

                        // Two columns from xxxLarge: in a third of a 320-pt
                        // sheet «Сцеженное» keeps 3.8 pt there (86.9 in 90.7),
                        // under the 8-pt spare. Up to there the row stays an
                        // HStack: a grid sets it a third of a point lower.
                        let typeColumns = BBTileColumns(large: 3, xLarge: 3, xxLarge: 3, xxxLarge: 2, accessibility: 2)
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

                    // Breast side (if breast)
                    if selectedType == .breast {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.breast".l)
                                .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)

                            // Two columns from xLarge: in a third of a 320-pt
                            // sheet «Izquierdo» misses there by 1.3 pt. One at
                            // accessibility sizes, where half a sheet misses
                            // by 8.6.
                            let chipColumns = BBTileColumns(large: 3, xLarge: 2, xxLarge: 2, xxxLarge: 2, accessibility: 1)
                            let chipCount = chipColumns.count(at: dynamicTypeSize)
                            if chipCount == chipColumns.large {
                                HStack(spacing: BBTheme.Spacing.sm) {
                                    sideChips
                                }
                            } else if chipCount == 1 {
                                VStack(spacing: BBTheme.Spacing.sm) {
                                    sideChips
                                }
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.sm),
                                                         count: chipCount),
                                          spacing: BBTheme.Spacing.sm) {
                                    sideChips
                                }
                            }
                        }
                    }

                    // Volume (if formula/pumped)
                    if selectedType == .formula || selectedType == .pumped {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            HStack {
                                Text("form.volume_ml".l)
                                    .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                                Spacer()
                                Text("\(Int(volumeML))\u{00A0}\("unit.ml".l)")
                                    .font(BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(BBTheme.Colors.feeding)
                            }
                            Slider(value: $volumeML, in: 0...500, step: 10) { editing in
                                if editing { userTouchedVolume = true }
                            }
                            .tint(BBTheme.Colors.feeding)
                            HStack {
                                Text("0")
                                Spacer()
                                Text("500\u{00A0}\("unit.ml".l)")
                            }
                            .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
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
                                .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Text("form.timer_hint".l)
                                .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    }
                    .tint(BBTheme.Colors.primary)
                    .padding(BBTheme.Spacing.md)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.md)
                    .bbShadow(BBTheme.Shadow.card)
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            // Big primary action pinned to the safe area for one-handed / night use;
            // mirrors the bar's confirm: both call save(), and both show ▶ and
            // Start Feeding while the timer is on.
            .safeAreaInset(edge: .bottom) {
                BBPrimaryButton(startTimer ? "button.start_feeding".l : "button.save".l,
                                icon: startTimer ? "play.fill" : "checkmark") {
                    save()
                }
                .padding(.horizontal, BBTheme.Spacing.md)
                .padding(.top, BBTheme.Spacing.sm)
                .padding(.bottom, BBTheme.Spacing.xs)
                .background(BBTheme.Colors.background)
            }
            .bbSheetTitle("sheet.new_feeding".l)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BBBarButton(.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BBBarButton(startTimer ? .startFeeding : .save) { save() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .onAppear { applyDefaultVolume() }
        .onChange(of: selectedType) { applyDefaultVolume() }
    }

    private func save() {
        let ml: Double? = (selectedType == .formula || selectedType == .pumped) ? volumeML : nil
        let entry = FeedingEntry(
            startTime: Date(),
            type: selectedType,
            side: selectedType == .breast ? selectedSide : nil,
            volumeML: ml
        )
        if !startTimer { entry.endTime = Date() }
        entry.baby = babies.first
        modelContext.insert(entry)
        try? modelContext.save()
        WidgetRefresh.entriesChanged()
        let baby = babies.first
        NotificationManager.shared.onFeedingSaved(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            isActiveBF: selectedType == .breast && startTimer,
            recentFeedingTimes: Array(feedings.prefix(7).map(\.startTime))
        )
        // This sheet can start a timer of any type, so the Lock Screen
        // must hear about it like any other mutation.
        TimerActions.afterChange()
        // A running timer is a feed that has only begun, not a finished
        // record — no moment of success to ask on. Timer starts never ask.
        if !startTimer { reviewPrompt.entrySaved(.feeding) }
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
                .font(BBTheme.Typography.scaled(18, relativeTo: .body, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(subtitle.l)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
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

import SwiftUI
import SwiftData

struct EventsView: View {
    @Query(sort: \CustomEvent.time, order: .reverse) private var events: [CustomEvent]
    @Query(sort: [SortDescriptor(\DoctorVisit.date, order: .reverse),
                  SortDescriptor(\DoctorVisit.createdAt, order: .reverse)])
    private var visits: [DoctorVisit]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query private var medicines: [Medicine]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(SubscriptionManager.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showAddSheet = false
    @State private var showDoseSheet = false
    /// The create gate and the history footer both sell; the source says which.
    @State private var paywallSource: AnalyticsEvent.PaywallSource?
    @State private var detailVisit: DoctorVisit?

    // No NavigationStack of its own: the screen is pushed from More's, and a
    // second stack would hold the medication detail's push.
    var body: some View {
        ScrollView {
            VStack(spacing: BBTheme.Spacing.lg) {
                BBScreenHeading(title: "nav.events".l, horizontalPadding: BBTheme.Spacing.md)
                VStack(spacing: BBTheme.Spacing.md) {
                    if !activeMedicines.isEmpty {
                        medicationLines
                    }
                    quickAddSection
                }
                .padding(.horizontal, BBTheme.Spacing.md)

                historySection
                    .padding(.horizontal, BBTheme.Spacing.md)
            }
            .padding(.bottom, BBTheme.Spacing.xl)
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .bbScreenTitle("nav.events".l)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addEvent() } label: {
                    // A badge, not a substitution: replacing the plus with
                    // a padlock loses the "this adds something" affordance,
                    // and the gate reads just as clearly beside it.
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(BBTheme.Colors.primary)
                        if !store.isPremium {
                            // Offset outwards: the disc is nearly as wide as
                            // the 22pt plus, so a flush badge would hide it.
                            LockBadge().offset(x: 8, y: 6)
                        }
                    }
                }
                // The plus is an icon-only control, so it needs its label
                // spelled out before the gate can be appended to it.
                .accessibilityLabel(Text("sheet.new_event".l))
                .bbLockedAccessibility(!store.isPremium)
            }
        }
        .entrySheet(isPresented: $showAddSheet) {
            AddEventSheet()
        }
        // A plain sheet: no rating prompt after a dose.
        .sheet(isPresented: $showDoseSheet) {
            DoseSheet(choosingFrom: activeMedicines)
        }
        .sheet(item: $paywallSource) { source in
            PaywallView(source: source)
        }
        .visitDetailSheet(item: $detailVisit)
    }

    /// The single gate for creating an event on this screen. Both creation
    /// paths — the toolbar sheet and the quick-add tiles — go through it, so
    /// the padlock cannot promise a gate that a tile below it walks around.
    private func addEvent(_ type: CustomEvent.EventType? = nil) {
        // A dose of a running medication logs free from the tile, as from its
        // own screen: a one-tap dose with no name could not be linked, so it
        // would walk around the medication's interval.
        if type == .medication, !activeMedicines.isEmpty {
            showDoseSheet = true
            return
        }
        guard store.isPremium else {
            paywallSource = .events
            return
        }
        if let type {
            quickAdd(type)
        } else {
            showAddSheet = true
        }
    }

    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_input")
            // One column from xxLarge: in half a 320-pt row es «Medicamento»
            // keeps 2.5 pt there (105.5 in 108), under the 8-pt spare.
            let tileColumns = BBTileColumns(large: 2, xLarge: 2, xxLarge: 1, xxxLarge: 1, accessibility: 1)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                     count: tileColumns.count(at: dynamicTypeSize)),
                      spacing: BBTheme.Spacing.md) {
                ForEach([CustomEvent.EventType.bath, .walk, .medication, .mood], id: \.self) { type in
                    let locked = isLocked(type)
                    Button {
                        addEvent(type)
                    } label: {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(systemName: type.icon)
                                    .font(BBTheme.Typography.scaled(26, relativeTo: .body, weight: .regular, design: .default))
                                    .foregroundStyle(Color(hex: type.colorHex))
                                if locked {
                                    LockBadge().offset(x: 8, y: 4)
                                }
                            }
                            Text(type.displayName.l)
                                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .bbCardTonal(Color(hex: type.colorHex))
                    }
                    .buttonStyle(BBScaleButtonStyle())
                    .bbLockedAccessibility(locked)
                    .accessibilityIdentifier("events.quick.\(type.rawValue)")
                }
            }
        }
    }

    /// The running medications, by name; ended ones never show here.
    private var activeMedicines: [Medicine] {
        MedicationFormat.byName(medicines.filter { !$0.isEnded })
    }

    private func isLocked(_ type: CustomEvent.EventType) -> Bool {
        !store.isPremium && !(type == .medication && !activeMedicines.isEmpty)
    }

    /// One line per running medication, to its detail. Redrawn each minute,
    /// so "Next dose not before" turns into "has passed" on its own.
    private var medicationLines: some View {
        TimelineView(.everyMinute) { _ in
            VStack(spacing: BBTheme.Spacing.sm) {
                ForEach(activeMedicines) { medicine in
                    MedicationStatusLine(medicine: medicine, now: AppClock.now)
                }
            }
        }
    }

    /// A medication shows its name and dose as typed; every other type its
    /// note, or its mood.
    private func rowText(_ event: CustomEvent) -> (title: String, subtitle: String) {
        let typeWord = event.type.displayName.l
        guard event.type == .medication else {
            return (typeWord, event.notes ?? (event.mood?.displayName.l ?? ""))
        }
        return MedicationFormat.eventRow(typeWord: typeWord, isDose: event.isDose,
                                         name: event.medicationName,
                                         dose: event.medicationDose, note: event.notes)
    }

    /// The free history window, applied BEFORE the twenty-row cap.
    ///
    /// Order matters for what the footer means. Windowing first makes the
    /// footer "events older than 15 days" — the thing it offers to sell.
    /// Capping first would fold "beyond twenty rows" into it, and the footer
    /// would promise a subscription unlocks rows a subscriber does not get
    /// either. `HistoryWindow` then suppresses the footer entirely whenever
    /// the CAP, not the window, is what is costing rows.
    ///
    /// Visits are merged in after both, so they bypass the window and the cap
    /// (see `EventsHistory`).
    private var model: EventsHistory {
        EventsHistory(events: events, visits: visits, cutoff: store.historyCutoff)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.history")
            let model = self.model
            if model.showsEmptyState {
                EmptyStateView(
                    icon: "star.fill",
                    color: BBTheme.Colors.events,
                    title: "empty.no_records",
                    subtitle: "empty.events_hint"
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(model.rows) { row in
                        switch row {
                        case .event(let event):
                            let text = rowText(event)
                            SwipeToDeleteRow(onDelete: { delete(event) }) {
                                BBEventRow(
                                    icon: event.type.icon,
                                    iconColor: Color(hex: event.type.colorHex),
                                    title: text.title,
                                    subtitle: text.subtitle,
                                    time: event.time.appTimeOfDay,
                                    trailing: event.time.appDayMonth
                                )
                            }
                        case .visit(let visit):
                            // No swipe: a visit changes only in its detail,
                            // never from a list.
                            Button { detailVisit = visit } label: {
                                BBEventRow(
                                    icon: "stethoscope",
                                    iconColor: BBTheme.Colors.events,
                                    title: "visit.title".l,
                                    subtitle: DoctorPeriod.noteFirstLine(visit.note) ?? "",
                                    time: visit.date.appDayMonth
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("report.a11y_period_hint".l)
                            .accessibilityIdentifier("events.visit_row.\(visitNumber(of: visit, in: model.rows))")
                        }
                    }
                }
                if model.events.showsLockedFooter {
                    BBLockedHistoryFooter(surface: .events) { paywallSource = .historyLock }
                }
                // This screen is the one windowed surface with no swipe reach
                // to its unrendered rows: an event older than the free window
                // has no row to swipe and export is itself paid, so without a
                // delete-all over the FULL array those records would be
                // unreachable for a free or lapsed account — held hostage in
                // exactly the sense DECISIONS 2026-09-01 forbids. Creating an
                // event is gated; erasing one never is.
                // `.everything`: this screen has no range picker, so its
                // confirmation must not borrow the other screens' "in the
                // selected period" — there is no period, and the phrase would
                // understate an irreversible wipe of the whole event history.
                //
                // Events only: the visits listed above are kept, so the
                // confirm uses the events-only texts, and the button is
                // absent when no event exists.
                if model.showsDeleteAll {
                    BBDeleteHistoryButton(scope: .everything,
                                          deletesHiddenRows: model.events.deletesRowsNotShown,
                                          messageKey: "confirm.delete_message_events",
                                          hiddenMessageKey: "confirm.delete_message_events_hidden") {
                        deleteAll(model.events.deletable)
                    }
                }
            }
        }
    }

    /// 1-based position among the visit rows, for the UI-test identifier.
    private func visitNumber(of visit: DoctorVisit, in rows: [EventsHistoryRow]) -> Int {
        let visitIDs = rows.compactMap { row -> PersistentIdentifier? in
            if case .visit(let v) = row { return v.persistentModelID }
            return nil
        }
        return (visitIDs.firstIndex(of: visit.persistentModelID) ?? 0) + 1
    }

    private func quickAdd(_ type: CustomEvent.EventType) {
        let event = CustomEvent(time: Date(), type: type)
        event.baby = babies.first
        modelContext.insert(event)
        try? modelContext.save()
        // No rating prompt after a medication, from any path; the first-entry
        // count still hears it.
        if type != .medication { reviewPrompt.entrySaved(.event) } else { reviewPrompt.logged(.event) }
    }

    private func delete(_ event: CustomEvent) {
        modelContext.delete(event)
        try? modelContext.save()
    }

    /// Receives the full `events` array, never the rendered slice — see the
    /// comment on the button that calls it.
    private func deleteAll(_ items: [CustomEvent]) {
        items.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}

// MARK: - Add Event Sheet
struct AddEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var selectedType: CustomEvent.EventType = .bath
    @State private var notes = ""
    // The app's clock, as in the dose sheet, so a pinned clock opens both on
    // the same time.
    @State private var time = AppClock.now
    @State private var selectedMood: CustomEvent.MoodLevel = .calm
    @State private var medicationName = ""
    @State private var medicationDose = ""
    @Query private var medicines: [Medicine]
    @State private var medicationChoice: MedicationChoice = .unchosen
    /// Start at `.large` so all fields are visible without a manual drag.
    @State private var selectedDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    BBSheetHeading(title: "sheet.new_event".l)
                    // Type grid: glyph and word grow with the text size, and
                    // from xxLarge two columns: in a third of a 320-pt sheet
                    // es «Medicamento» keeps 7.8 pt there (82.8 in 90.7),
                    // under the 8-pt spare.
                    let typeColumns = BBTileColumns(large: 3, xLarge: 3, xxLarge: 2, xxxLarge: 2, accessibility: 2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                             count: typeColumns.count(at: dynamicTypeSize)),
                              spacing: BBTheme.Spacing.sm) {
                        ForEach(CustomEvent.EventType.allCases, id: \.self) { type in
                            Button { selectedType = type } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(BBTheme.Typography.scaled(22, relativeTo: .body, weight: .regular, design: .default))
                                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : Color(hex: type.colorHex))
                                    Text(type.displayName.l)
                                        .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
                                        .foregroundStyle(selectedType == type ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, BBTheme.Spacing.md)
                                .background(selectedType == type ? BBTheme.Colors.primary.opacity(0.12) : Color.clear).background(BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md)
                                .bbShadow(BBTheme.Shadow.card)
                                .bbSelectedBorder(selectedType == type)
                            }
                            .buttonStyle(BBScaleButtonStyle())
                            .accessibilityIdentifier("event.type.\(type.rawValue)")
                        }
                    }

                    // Mood selector
                    if selectedType == .mood {
                        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                            Text("form.mood".l).font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                            // Glyph and word grow with the text size, as on the type
                            // tiles, and from xxLarge two columns: in a third of a
                            // 320-pt sheet «Беспокойный» keeps 4.5 pt there (86.2
                            // in 90.7), under the 8-pt spare.
                            let moodColumns = BBTileColumns(large: 3, xLarge: 3, xxLarge: 2, xxxLarge: 2, accessibility: 2)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BBTheme.Spacing.sm),
                                                     count: moodColumns.count(at: dynamicTypeSize)),
                                      spacing: BBTheme.Spacing.sm) {
                                ForEach(CustomEvent.MoodLevel.allCases, id: \.self) { mood in
                                    Button { selectedMood = mood } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: mood.icon)
                                                .font(BBTheme.Typography.scaled(24, relativeTo: .body, weight: .regular, design: .default))
                                                .foregroundStyle(selectedMood == mood ? BBTheme.Colors.primary : BBTheme.Colors.accent)
                                            Text(mood.displayName.l)
                                                .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
                                                .foregroundStyle(selectedMood == mood ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                        }
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                        .background(selectedMood == mood ? BBTheme.Colors.primary.opacity(0.12) : Color.clear).background(BBTheme.Colors.surface)
                                        .cornerRadius(BBTheme.Radius.md)
                                        .bbShadow(BBTheme.Shadow.card)
                                        .bbSelectedBorder(selectedMood == mood)
                                    }
                                    .buttonStyle(BBScaleButtonStyle())
                                }
                            }
                        }
                    }

                    // Medication fields: a running medication from the menu
                    // logs a linked dose; "Not in the list", or no running
                    // medication, keeps the two free-text fields.
                    if selectedType == .medication {
                        VStack(spacing: BBTheme.Spacing.sm) {
                            if !activeMedicines.isEmpty {
                                MedicationMenuField(value: choiceLabel) {
                                    ForEach(activeMedicines) { medicine in
                                        Button(medicine.name) { medicationChoice = .medicine(medicine) }
                                    }
                                    Button("medication.picker_not_listed".l) { medicationChoice = .notListed }
                                }
                            }
                            switch effectiveChoice {
                            case .medicine(let medicine):
                                MedicationStatusBox(lines: medicine.lines(now: AppClock.now))
                            case .notListed:
                                freeTextMedicationFields
                            case .unchosen:
                                EmptyView()
                            }
                        }
                    }

                    // Notes
                    TextField("form.notes".l, text: $notes, axis: .vertical)
                        .lineLimit(3).padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)

                    // Time
                    timeRow
                        .datePickerStyle(.compact).tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md).background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md).bbShadow(BBTheme.Shadow.card)
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                BBSheetFooter {
                    // BBPrimaryButton has no disabled look of its own.
                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                        .accessibilityIdentifier("event.save")
                }
            }
            .bbSheetTitle("sheet.new_event".l)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BBBarButton(.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BBBarButton(.save) { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("event.bar_save")
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .doseConfirmation(confirmation, isPresented: $confirming) { saveConfirmed() }
    }

    enum MedicationChoice: Equatable {
        case unchosen
        case medicine(Medicine)
        case notListed
    }

    private var activeMedicines: [Medicine] {
        MedicationFormat.byName(medicines.filter { !$0.isEnded })
    }

    /// One running medication is preselected; with two or more nothing is,
    /// and Save waits: a wrong preselection would file the dose under another
    /// medication and time the wrong interval. With none, the free text.
    private var effectiveChoice: MedicationChoice {
        if activeMedicines.isEmpty { return .notListed }
        // A pick that has since ended or gone (another device) no longer
        // counts; reading it would touch a deleted model.
        if case .medicine(let picked) = medicationChoice,
           !activeMedicines.contains(where: { $0.persistentModelID == picked.persistentModelID }) {
            return activeMedicines.count == 1 ? .medicine(activeMedicines[0]) : .unchosen
        }
        if medicationChoice == .unchosen, activeMedicines.count == 1, let only = activeMedicines.first {
            return .medicine(only)
        }
        return medicationChoice
    }

    private var choiceLabel: String {
        switch effectiveChoice {
        case .medicine(let medicine): return medicine.name
        case .notListed: return "medication.picker_not_listed".l
        case .unchosen: return "medication.picker_choose".l
        }
    }

    private var canSave: Bool {
        selectedType != .medication || effectiveChoice != .unchosen
    }

    /// A medication ends at now, as in the dose sheet: a dose given, linked
    /// or typed, has happened. Other events keep any time. The bound follows
    /// the type, never the medication choice: a compact picker whose bound
    /// moves under its selection redraws its date in the short style
    /// («11/3/26»), and with the time starting at now a choice never does.
    private var timeRow: some View {
        BBLabeledDateTimePicker("form.time".l) { label, components in
            DatePicker(label, selection: $time,
                       in: Date.distantPast...(selectedType == .medication ? AppClock.now : Date.distantFuture),
                       displayedComponents: components)
        }
    }

    private var freeTextMedicationFields: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            // Vertical, so a long name wraps at large text instead of shrinking.
            TextField("form.medication_name".l, text: $medicationName, axis: .vertical)
                .bbPlaceholderLabel(design: .default)
                .oneParagraph($medicationName)
                .medicationField()
            // The name field's face; the placeholder is one word and needs no
            // reserved line.
            TextField("form.dose".l, text: $medicationDose, axis: .vertical)
                .lineLimit(1...3)
                .oneParagraph($medicationDose)
                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular, design: .default))
                .medicationField()
        }
    }

    /// Kept after the alert closes, so its title does not blank as it goes.
    @State private var confirmation: DoseConfirmation?
    @State private var confirmed: ConfirmedDose?
    @State private var confirming = false

    /// A dose of a chosen medication inside its interval or over its maximum
    /// asks first, as in the dose sheet; a free-text one never does, since a
    /// typed name is not matched to a medication.
    private func save() {
        guard canSave else { return }
        if selectedType == .medication, case .medicine(let medicine) = effectiveChoice {
            // The picker clamps only its display, so the save clamps to now as
            // well, once: the time checked is the time stored.
            let at = min(time, AppClock.now)
            if let asked = medicine.confirmation(for: at, now: AppClock.now) {
                confirmation = asked
                confirmed = ConfirmedDose(medicineID: medicine.persistentModelID, time: at)
                confirming = true
                return
            }
            logDose(of: medicine, at: at)
            return
        }
        saveEvent()
    }

    /// The alert's Save: the medication and time it asked about, or nothing
    /// when the choice moved on while it was up, and the form stays open.
    private func saveConfirmed() {
        guard let confirmed, selectedType == .medication, case .medicine(let medicine) = effectiveChoice,
              medicine.persistentModelID == confirmed.medicineID else { return }
        logDose(of: medicine, at: confirmed.time)
    }

    /// Linked, with the name and dose copied.
    private func logDose(of medicine: Medicine, at: Date) {
        let event = CustomEvent.dose(of: medicine, at: at)
        event.notes = MedicationFormInput.optional(notes)
        if event.baby == nil { event.baby = babies.first }
        modelContext.insert(event)
        try? modelContext.save()
        dismiss()
    }

    private func saveEvent() {
        // The picker clamps only its display.
        let event = CustomEvent(time: selectedType == .medication ? min(time, AppClock.now) : time,
                                type: selectedType)
        if selectedType == .mood { event.mood = selectedMood }
        if selectedType == .medication {
            event.medicationName = medicationName.isEmpty ? nil : medicationName
            event.medicationDose = medicationDose.isEmpty ? nil : medicationDose
        }
        event.notes = notes.isEmpty ? nil : notes
        event.baby = babies.first
        modelContext.insert(event)
        try? modelContext.save()
        // No rating prompt after a medication, from any path; the first-entry
        // count still hears a free-text one, as before.
        if selectedType != .medication { reviewPrompt.entrySaved(.event) } else { reviewPrompt.logged(.event) }
        dismiss()
    }
}

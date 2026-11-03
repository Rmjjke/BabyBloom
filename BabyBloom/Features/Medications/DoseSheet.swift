import SwiftUI
import SwiftData

/// Log a dose, or change one. A plain `.sheet` with no rating prompt: none
/// ever follows a dose given to a sick baby.
struct DoseSheet: View {
    /// nil logs a new dose; otherwise the dose being edited.
    let dose: CustomEvent?
    /// The running medications, when the sheet opened from the Medication
    /// tile. The host passes its live list on every render, so the choice is
    /// reconciled with it. Empty otherwise.
    let choices: [Medicine]
    private let choosing: Bool
    /// Edit mode: Delete Dose hands the dose back, and the host deletes it once
    /// this sheet has gone, so no view still holding it reads a deleted model.
    var onDelete: ((CustomEvent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var medicine: Medicine?
    @State private var time: Date
    @State private var doseText: String
    @State private var note: String
    @State private var selectedDetent: PresentationDetent = .large
    /// The edited dose's time as logged: a save that leaves the time alone
    /// keeps it, even one later than now from a device whose clock ran ahead.
    private let loggedTime: Date?

    init(medicine: Medicine, dose: CustomEvent?, onDelete: ((CustomEvent) -> Void)? = nil) {
        self.init(medicine: medicine, choices: [], choosing: false, dose: dose, onDelete: onDelete)
    }

    /// A new dose of one of `medicines`: with one it opens on it; with more,
    /// nothing is chosen and Save waits. A wrong preselection would file the
    /// dose under another medication and time the wrong interval.
    init(choosingFrom medicines: [Medicine]) {
        let only = medicines.count == 1 ? medicines.first : nil
        self.init(medicine: only, choices: medicines, choosing: true, dose: nil, onDelete: nil)
    }

    private init(medicine: Medicine?, choices: [Medicine], choosing: Bool, dose: CustomEvent?,
                 onDelete: ((CustomEvent) -> Void)?) {
        self.dose = dose
        self.choices = choices
        self.choosing = choosing
        self.onDelete = onDelete
        _medicine = State(initialValue: medicine)
        // Copied once, so the fields never read the dose again.
        _time = State(initialValue: dose?.time ?? AppClock.now)
        _doseText = State(initialValue: dose.map { $0.medicationDose ?? "" } ?? (medicine?.doseText ?? ""))
        _note = State(initialValue: dose?.notes ?? "")
        loggedTime = dose?.time
    }

    private var title: String {
        if !modelsGone, let name = medicine.flatMap({ MedicationFormInput.optional($0.name) }) { return name }
        return dose == nil ? "medication.log_dose".l : "medication.dose_edit_title".l
    }

    /// A model deleted elsewhere (another device, or a save that already ran)
    /// has no context left; reading its fields would trap.
    private var modelsGone: Bool {
        func gone(_ model: some PersistentModel) -> Bool { model.modelContext == nil || model.isDeleted }
        return (medicine.map { gone($0) } ?? false) || (dose.map { gone($0) } ?? false)
    }

    private var canSave: Bool { medicine != nil && !modelsGone }

    /// The menu shows while there is a choice to make: two or more running,
    /// or the one that was chosen has since ended or gone.
    private var showsMenu: Bool {
        choosing && (choices.count > 1 || (medicine == nil && !choices.isEmpty))
    }

    /// A chosen medication that ended or went (another device) is dropped;
    /// when one alone is left, the sheet opens on it as it would have.
    private func reconcileChoice() {
        guard choosing else { return }
        if let chosen = medicine,
           !choices.contains(where: { $0.persistentModelID == chosen.persistentModelID }) {
            medicine = nil
        }
        if medicine == nil, choices.count == 1, let only = choices.first {
            medicine = only
            doseText = only.doseText ?? ""
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    if modelsGone {
                        EmptyView()
                    } else {
                        fields
                    }
                }
                // BBPrimaryButton has no disabled look of its own.
                BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                    .accessibilityIdentifier("dose.save")
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .bbSheetTitle(title, movesIntoContentAtAX: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .onChange(of: choices.map(\.persistentModelID)) { reconcileChoice() }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
            BBSheetHeading(title: title)
            if showsMenu {
                MedicationMenuField(value: medicine?.name ?? "medication.picker_choose".l) {
                    ForEach(choices) { choice in
                        Button(choice.name) {
                            medicine = choice
                            doseText = choice.doseText ?? ""
                        }
                    }
                }
            }
            timeField
                .medicationField()
            // Vertical, so a long dose wraps at large text instead of shrinking.
            TextField("form.dose".l, text: $doseText, axis: .vertical)
                .lineLimit(1...3)
                .medicationField()
                .accessibilityIdentifier("dose.dose")
            TextField("medication.detail_note".l, text: $note, axis: .vertical)
                .lineLimit(3)
                .medicationField()
            if let medicine, !medicine.isEnded {
                // The state before this entry, so an edited dose does not
                // measure against itself.
                MedicationStatusBox(lines: medicine.lines(now: AppClock.now, excluding: dose))
            }
            if dose != nil, onDelete != nil {
                // Beside the swipe on the list, which VoiceOver and Switch
                // Control reach only with effort.
                Button(role: .destructive) { deleteDose() } label: {
                    Text("medication.dose_delete".l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("dose.delete")
            }
        }
        .padding(BBTheme.Spacing.md)
    }

    /// At accessibility sizes the label goes above the picker: beside the
    /// date and time buttons it had room for a few letters and broke mid-word.
    @ViewBuilder
    private var timeField: some View {
        // The range ends at now: a dose that has not happened cannot be
        // picked. Save clamps too, since the picker clamps only its display.
        let picker = DatePicker("form.time".l, selection: $time, in: ...AppClock.now,
                                displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .tint(BBTheme.Colors.primary)
            .accessibilityIdentifier("dose.time")
        if dynamicTypeSize.isAccessibilitySize {
            // The label stays readable by VoiceOver: the picker's own label
            // is hidden here.
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                Text("form.time".l)
                picker.labelsHidden()
            }
        } else {
            picker
        }
    }

    private func save() {
        guard canSave, let medicine else { return }
        let at: Date
        if let loggedTime, time == loggedTime {
            at = loggedTime
        } else {
            at = min(time, AppClock.now)
        }
        if let dose {
            // The name stays as logged; only the time, the dose and the note change.
            dose.time = at
            dose.medicationDose = MedicationFormInput.optional(doseText)
            dose.notes = MedicationFormInput.optional(note)
        } else {
            let event = CustomEvent.dose(of: medicine, at: at)
            event.medicationDose = MedicationFormInput.optional(doseText)
            event.notes = MedicationFormInput.optional(note)
            modelContext.insert(event)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteDose() {
        guard let dose else { return }
        onDelete?(dose)
        dismiss()
    }
}

/// The «Medication» field of the dose sheet and the Add Event form: a label
/// and a menu that shows the choice, or «Choose».
struct MedicationMenuField<Items: View>: View {
    let value: String
    @ViewBuilder let items: () -> Items
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Stacked at accessibility sizes, so a long name never squeezes the label.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: BBTheme.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: BBTheme.Spacing.sm))
        layout {
            // The menu carries the label for VoiceOver, so it is read once.
            Text("medication.picker_label".l)
                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .accessibilityHidden(true)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: BBTheme.Spacing.sm) }
            Menu {
                items()
            } label: {
                HStack(spacing: BBTheme.Spacing.xs) {
                    Text(verbatim: value)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .accessibilityHidden(true)
                }
                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("medication.picker_label".l))
            .accessibilityValue(Text(verbatim: value))
            .accessibilityIdentifier("medication.picker")
        }
        .medicationField()
    }
}

/// Lines A and B of a medication's status, in a field box: the dose sheet and
/// the Add Event form, before the dose is saved.
struct MedicationStatusBox: View {
    let lines: MedicationLines

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            if let primary = lines.primary {
                BBTheme.Typography.bodyEmphasized(primary)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }
            BBTheme.Typography.callout(lines.secondary)
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .medicationField()
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// A field box of the medication sheets, as in the Add Event sheet.
    func medicationField() -> some View {
        padding(BBTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .bbShadow(BBTheme.Shadow.card)
    }
}

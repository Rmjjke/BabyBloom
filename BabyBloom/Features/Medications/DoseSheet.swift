import SwiftUI
import SwiftData

/// Log a dose, or change one. A plain `.sheet` with no rating prompt: none
/// ever follows a dose given to a sick baby.
struct DoseSheet: View {
    let medicine: Medicine
    /// nil logs a new dose; otherwise the dose being edited.
    let dose: CustomEvent?
    /// Edit mode: Delete Dose hands the dose back, and the host deletes it once
    /// this sheet has gone, so no view still holding it reads a deleted model.
    var onDelete: ((CustomEvent) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var time: Date
    @State private var doseText: String
    @State private var note: String
    @State private var selectedDetent: PresentationDetent = .large
    /// The edited dose's time as logged: a save that leaves the time alone
    /// keeps it, even one later than now from a device whose clock ran ahead.
    private let loggedTime: Date?

    init(medicine: Medicine, dose: CustomEvent?, onDelete: ((CustomEvent) -> Void)? = nil) {
        self.medicine = medicine
        self.dose = dose
        self.onDelete = onDelete
        // Copied once, so the fields never read the dose again.
        _time = State(initialValue: dose?.time ?? AppClock.now)
        _doseText = State(initialValue: dose.map { $0.medicationDose ?? "" } ?? (medicine.doseText ?? ""))
        _note = State(initialValue: dose?.notes ?? "")
        loggedTime = dose?.time
    }

    private var title: String {
        let name = medicine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return medicine.name }
        return dose == nil ? "medication.log_dose".l : "medication.dose_edit_title".l
    }

    /// A model deleted elsewhere (another device, or a save that already ran)
    /// has no context left; reading its fields would trap.
    private var modelsGone: Bool {
        func gone(_ model: some PersistentModel) -> Bool { model.modelContext == nil || model.isDeleted }
        return gone(medicine) || (dose.map { gone($0) } ?? false)
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
                BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
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
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
            BBSheetHeading(title: title)
            timeField
                .medicationField()
            TextField("form.dose".l, text: $doseText)
                .medicationField()
                .accessibilityIdentifier("dose.dose")
            TextField("medication.detail_note".l, text: $note, axis: .vertical)
                .lineLimit(3)
                .medicationField()
            if !medicine.isEnded {
                // The state before this entry, so an edited dose does not
                // measure against itself.
                let lines = medicine.lines(now: AppClock.now, excluding: dose)
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

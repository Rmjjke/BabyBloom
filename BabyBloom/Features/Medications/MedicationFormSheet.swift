import SwiftUI
import SwiftData

/// Add or edit a medication. The safety line comes first, so it is read
/// before anything is typed; no field starts with a value.
struct MedicationFormSheet: View {
    /// nil adds a new medication.
    let medicine: Medicine?
    /// Edit mode: called after the parent confirmed the delete. The caller
    /// deletes once this sheet has gone.
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var input: MedicationFormInput
    @State private var confirmDelete = false
    @State private var selectedDetent: PresentationDetent = .large
    /// This device's reminder switch, stored on Save with the rest.
    @State private var reminderOn: Bool

    init(medicine: Medicine?, onDelete: (() -> Void)? = nil) {
        self.medicine = medicine
        self.onDelete = onDelete
        _input = State(initialValue: medicine.map(MedicationFormInput.init) ?? MedicationFormInput())
        _reminderOn = State(initialValue: medicine.map {
            UserDefaults.standard.bool(forKey: MedicationReminderPlan.switchKey(for: $0.id))
        } ?? false)
    }

    private var title: String {
        medicine == nil ? "medication.form_new_title".l : "medication.form_edit_title".l
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
                        BBSheetHeading(title: title)
                        mainGroup
                        detailsGroup
                        if medicine?.isEnded != true {
                            MedicationReminderCard(isOn: $reminderOn, fireDate: reminderFireDate,
                                                   now: AppClock.now)
                                .medicationField()
                        }
                        if medicine != nil, onDelete != nil {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Text("medication.delete".l)
                                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                                    .frame(minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .accessibilityIdentifier("medication.delete")
                        }
                    }
                    .padding(BBTheme.Spacing.md)
                }
                BBSheetFooter {
                    // BBPrimaryButton has no disabled look of its own.
                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                        .disabled(!input.canSave)
                        .opacity(input.canSave ? 1 : 0.4)
                        .accessibilityIdentifier("medication.save")
                }
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .bbSheetTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BBBarButton(.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    BBBarButton(.save) { save() }
                        .disabled(!input.canSave)
                        .accessibilityIdentifier("medication.bar_save")
                }
            }
            .alert("medication.delete".l, isPresented: $confirmDelete) {
                Button("button.delete".l, role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button("button.cancel".l, role: .cancel) {}
            } message: {
                Text("medication.delete_message".l)
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
    }

    // MARK: Groups

    private var mainGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A statement, not a warning: no icon, no box, no red.
            Text("medication.safety_line".l)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            divider
            // Vertical, so a long name wraps at large text instead of shrinking.
            TextField("medication.field_name_placeholder".l, text: $input.name, axis: .vertical)
                .bbPlaceholderLabel("medication.field_name_placeholder".l, text: input.name)
                .oneParagraph($input.name)
                .accessibilityLabel(Text("medication.field_name".l))
                .accessibilityIdentifier("medication.name")
            divider
            fieldLabel("medication.field_interval")
                .padding(.bottom, BBTheme.Spacing.sm)
            ChipFlow(spacing: BBTheme.Spacing.sm) {
                ForEach(MedicationFormInput.chipHours, id: \.self) { hours in
                    chip(String(format: "duration.h_only".l, hours),
                         selected: input.interval == .chip(hours: hours),
                         id: "medication.chip.\(hours)") {
                        input.interval = .chip(hours: hours)
                    }
                }
                chip("medication.chip_other".l, selected: isOther, id: "medication.chip.other") {
                    guard !isOther else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        input.interval = .other(hours: 0, minutes: 0)
                    }
                }
            }
            if case .other(let hours, let minutes) = input.interval {
                otherWheels(hours: hours, minutes: minutes)
                    .padding(.top, BBTheme.Spacing.sm)
            }
        }
        .medicationField()
    }

    private var detailsGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The placeholders are long: single-line, they shrank at large text.
            TextField("medication.field_dose_placeholder".l, text: $input.doseText, axis: .vertical)
                .bbPlaceholderLabel("medication.field_dose_placeholder".l, text: input.doseText)
                .oneParagraph($input.doseText)
                .accessibilityLabel(Text("medication.field_dose".l))
                .accessibilityIdentifier("medication.dose")
            divider
            fieldLabel("medication.field_max")
            // Labelled above, but the placeholder is the example of what to
            // type, and in es it needs a second line at accessibility sizes.
            TextField("medication.field_max_placeholder".l, text: $input.maximumText, axis: .vertical)
                .bbPlaceholderLabel("medication.field_max_placeholder".l, text: input.maximumText)
                .keyboardType(.numberPad)
                .padding(.top, BBTheme.Spacing.xs)
                .accessibilityLabel(Text("medication.field_max".l))
                .accessibilityIdentifier("medication.max")
                .onChange(of: input.maximumText) { _, text in
                    let digits = MedicationFormInput.maximumDigits(text)
                    if digits != text { input.maximumText = digits }
                }
            if input.maximum == .invalid {
                // Why Save is off, in the field's own grey: a range to type,
                // not an error to fix.
                fieldLabel("medication.field_max_range_hint")
                    .padding(.top, BBTheme.Spacing.xs)
                    .accessibilityIdentifier("medication.max_hint")
            }
            divider
            TextField("form.notes_optional".l, text: $input.note, axis: .vertical)
                .bbPlaceholderLabel("form.notes_optional".l, text: input.note)
        }
        .medicationField()
    }

    // MARK: Parts

    /// The pending time as it will be after Save: the form's interval and
    /// maximum over the doses already logged. None for a new medication.
    private var reminderFireDate: Date? {
        guard let medicine, let minutes = input.intervalMinutes else { return nil }
        let maximum: Int? = if case .value(let value) = input.maximum { value } else { nil }
        let schedule = MedicineSchedule(intervalMinutes: minutes, maxDosesPer24h: maximum,
                                        doseTimes: medicine.doseTimes(), now: AppClock.now)
        return MedicationReminderPlan.fireDate(isOn: reminderOn, isEnded: medicine.isEnded, schedule: schedule)
    }

    private var isOther: Bool {
        if case .other = input.interval { return true }
        return false
    }

    private var divider: some View {
        Divider().padding(.vertical, BBTheme.Spacing.sm)
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(key.l)
            .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(_ label: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? BBTheme.Colors.onPrimary : BBTheme.Colors.primary)
                .padding(.horizontal, BBTheme.Spacing.md)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? BBTheme.Colors.primary : BBTheme.Colors.primary.opacity(0.10)))
                .background(Capsule().fill(BBTheme.Colors.surface))
                .overlay(Capsule().strokeBorder(selected ? Color.clear : BBTheme.Colors.primary.opacity(0.30),
                                                lineWidth: 1.5))
                .contentShape(Capsule())
        }
        .buttonStyle(BBScaleButtonStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    /// Hours 0–48 and minutes in quarters, starting at 0 h 0 min, which is not
    /// an interval: Save stays off until the wheels move.
    private func otherWheels(hours: Int, minutes: Int) -> some View {
        HStack(spacing: 0) {
            Picker("medication.other_hours".l, selection: Binding(
                get: { hours },
                set: { input.setOther(hours: $0, minutes: minutes) })) {
                ForEach(MedicationFormInput.otherHours, id: \.self) { value in
                    Text(String(format: "duration.h_only".l, value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier("medication.other_hours")
            Picker("medication.other_minutes".l, selection: Binding(
                get: { minutes },
                set: { input.setOther(hours: hours, minutes: $0) })) {
                ForEach(input.otherMinuteChoices(hours: hours), id: \.self) { value in
                    Text(String(format: "duration.min_only".l, value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityIdentifier("medication.other_minutes")
        }
        .frame(height: 150)
        .transition(.opacity)
    }

    private func save() {
        guard input.canSave else { return }
        let target: Medicine
        if let medicine {
            target = medicine
        } else {
            target = Medicine(name: input.trimmedName, intervalMinutes: input.intervalMinutes ?? 0)
            modelContext.insert(target)
            target.baby = babies.first
        }
        input.apply(to: target)
        UserDefaults.standard.set(reminderOn, forKey: MedicationReminderPlan.switchKey(for: target.id))
        try? modelContext.save()
        // A change to the switch alone saves no model, so the pass is asked
        // for here rather than left to the save.
        MedicationReminderSync.shared.reconcile()
        dismiss()
    }
}

/// Chips in rows that wrap, left to right; a row's height is its tallest chip.
struct ChipFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

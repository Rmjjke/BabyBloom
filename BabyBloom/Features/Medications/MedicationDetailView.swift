import SwiftUI
import SwiftData

/// One medication: where it stands, what was set, every dose, and Log Dose
/// pinned under the scroll. Pushed from the list (later also from Home and
/// the Events lines).
struct MedicationDetailView: View {
    let medicine: Medicine
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var store
    @State private var showForm = false
    @State private var doseSheet: DoseSheetTarget?
    @State private var showPaywall = false
    /// Set by the form's delete; acted on once the form has gone, so no view
    /// above it reads a deleted model.
    @State private var deleteRequested = false

    var body: some View {
        // A deleted medicine can still be drawn once while the screen pops;
        // reading its fields then would trap.
        if medicine.isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                TimelineView(.everyMinute) { _ in
                    sections(now: AppClock.now)
                }
                .padding(BBTheme.Spacing.md)
                .frame(maxWidth: MedicationLayout.maxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // An ended course takes no new dose; its old ones stay editable.
            if !medicine.isEnded {
                BBPrimaryButton("medication.log_dose".l, icon: "plus") { doseSheet = .new }
                    .accessibilityIdentifier("medication.log_dose")
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        // Inline and empty: a large title cuts a long name to one line, so
        // the name is the first line of the content instead.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("button.edit".l) { showForm = true }
                    .foregroundStyle(BBTheme.Colors.primary)
                    .accessibilityIdentifier("medication.edit")
            }
        }
        .sheet(isPresented: $showForm, onDismiss: deleteIfRequested) {
            MedicationFormSheet(medicine: medicine) { deleteRequested = true }
        }
        .sheet(item: $doseSheet) { target in
            DoseSheet(medicine: medicine, dose: target.dose)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .historyLock)
        }
    }

    private func sections(now: Date) -> some View {
        let lines = medicine.lines(now: now)
        return VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBTheme.Typography.title2(medicine.name)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                if let primary = lines.primary {
                    BBTheme.Typography.bodyEmphasized(primary)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                BBTheme.Typography.callout(lines.secondary)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                if let count = lines.count {
                    BBTheme.Typography.callout(count)
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bbCard()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("medication.status")

            aboutCard

            doseList(now: now)
                .padding(.top, BBTheme.Spacing.sm)

            Button {
                medicine.endedAt = medicine.isEnded ? nil : AppClock.now
                try? modelContext.save()
            } label: {
                Text(medicine.isEnded ? "medication.resume_course".l : "medication.end_course".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("medication.course")
        }
    }

    /// Label over value, always stacked, so the largest text needs no second
    /// layout. Values verbatim as typed.
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            if let dose = MedicationFormInput.optional(medicine.doseText ?? "") {
                aboutPair("form.dose", dose)
            }
            aboutPair("medication.field_interval", MedicationFormat.duration(minutes: medicine.intervalMinutes))
            if let max = medicine.maxDosesPer24h {
                aboutPair("medication.detail_max", String(max))
            }
            if let note = MedicationFormInput.optional(medicine.note ?? "") {
                aboutPair("medication.detail_note", note)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
    }

    private func aboutPair(_ labelKey: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(labelKey.l)
                .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
            BBTheme.Typography.callout(value)
                .foregroundStyle(BBTheme.Colors.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// The app's history window applies here as on every list; the status
    /// above reads every dose whatever the window shows.
    @ViewBuilder
    private func doseList(now: Date) -> some View {
        let list = HistoryWindow.list(medicine.doseEvents, date: \.time, cutoff: store.historyCutoff)
        if !list.deletable.isEmpty {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                BBSectionHeader(title: "medication.detail_doses")
                ForEach(Array(list.visible.enumerated()), id: \.element.persistentModelID) { index, dose in
                    SwipeToDeleteRow(onDelete: { delete(dose) }) {
                        Button { doseSheet = .edit(dose) } label: {
                            DoseRow(dose: dose, now: now)
                        }
                        .buttonStyle(BBScaleButtonStyle())
                        .accessibilityLabel(Text(DoseRow.spoken(dose, now: now)))
                        .accessibilityHint(Text("medication.a11y_dose_hint".l))
                        .accessibilityIdentifier("medication.dose.\(index + 1)")
                    }
                }
                if list.showsLockedFooter {
                    BBLockedHistoryFooter(surface: nil) { showPaywall = true }
                }
            }
        }
    }

    private func delete(_ dose: CustomEvent) {
        modelContext.delete(dose)
        try? modelContext.save()
    }

    private func deleteIfRequested() {
        guard deleteRequested else { return }
        deleteRequested = false
        let context = modelContext
        // Pop first, then delete: the doses stay, their link goes (nullify).
        dismiss()
        context.delete(medicine)
        try? context.save()
    }
}

/// What the dose sheet opens on.
enum DoseSheetTarget: Identifiable {
    case new
    case edit(CustomEvent)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let dose): return "\(dose.persistentModelID.hashValue)"
        }
    }

    var dose: CustomEvent? {
        if case .edit(let dose) = self { return dose }
        return nil
    }
}

/// A dose on the medication's list: its time with the day, the dose text as
/// typed when it was logged.
struct DoseRow: View {
    let dose: CustomEvent
    let now: Date

    var body: some View {
        let time = dose.time.appTimeOfDay
        let day = MedicationFormat.doseDay(dose.time, now: now)
        let doseText = MedicationFormInput.optional(dose.medicationDose ?? "")
        HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                // One Text with a no-break space, so the day never leaves
                // its time at a large text size.
                (Text(time)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                 + Text("\u{00A0}\u{00A0}")
                 + Text(day)
                    .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary))
                if let doseText {
                    Text(doseText)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            MedicationChevron()
        }
        .padding(BBTheme.Spacing.md)
        .frame(minHeight: 76, alignment: .top)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
        .contentShape(Rectangle())
    }

    /// The row read aloud; set on the button that holds the row.
    static func spoken(_ dose: CustomEvent, now: Date) -> String {
        MedicationFormat.spoken([dose.time.appTimeOfDay + " " + MedicationFormat.doseDay(dose.time, now: now),
                                 MedicationFormInput.optional(dose.medicationDose ?? "")])
    }
}

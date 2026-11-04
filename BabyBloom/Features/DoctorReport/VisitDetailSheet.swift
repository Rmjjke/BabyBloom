import SwiftUI
import SwiftData

/// One visit: date, note and the questions asked at it; edit and delete.
/// Questions are not editable here — "Back to the list" lives on the report.
struct VisitDetailSheet: View {
    let visit: DoctorVisit
    let onDelete: (DoctorVisit) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DoctorQuestion.createdAt) private var allQuestions: [DoctorQuestion]
    @State private var isEditing = false
    @State private var editDate = Date()
    @State private var editNote = ""
    @State private var showDeleteAlert = false
    @ScaledMetric(relativeTo: .callout) private var checkGlyph: CGFloat = 13

    private let visitID: PersistentIdentifier

    init(visit: DoctorVisit, onDelete: @escaping (DoctorVisit) -> Void) {
        self.visit = visit
        self.onDelete = onDelete
        self.visitID = visit.persistentModelID
    }

    /// From the query rather than `visit.questions`: the query is what
    /// reliably re-renders after a question is reopened elsewhere.
    private var askedQuestions: [DoctorQuestion] {
        allQuestions.filter { $0.visit?.persistentModelID == visitID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                    BBSheetHeading(title: "visit.title".l)
                    if isEditing {
                        VisitFields(date: $editDate, note: $editNote,
                                    range: VisitFields.dateRange(birthDate: visit.baby?.birthDate,
                                                                 now: AppClock.now))
                    } else {
                        readContent
                        deleteButton
                    }
                }
                .padding(BBTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .bbSheetTitle("visit.title".l, movesIntoContentAboveLarge: true)
            .toolbar { toolbar }
            .alert("visit.delete_title".l, isPresented: $showDeleteAlert) {
                Button("button.delete".l, role: .destructive) {
                    dismiss()
                    onDelete(visit)
                }
                Button("button.cancel".l, role: .cancel) {}
            } message: {
                // With nothing to return, the message would be false.
                if !askedQuestions.isEmpty {
                    Text("visit.delete_message".l)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.cancel".l) { isEditing = false }
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("button.save".l) { saveEdit() }
                    .fontWeight(.semibold)
                    .foregroundStyle(BBTheme.Colors.primary)
                    .accessibilityIdentifier("doctor.visit_sheet.save")
            }
        } else {
            ToolbarItem(placement: .cancellationAction) {
                Button("button.close".l) { dismiss() }
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("button.edit".l) {
                    editDate = visit.date
                    editNote = visit.note ?? ""
                    isEditing = true
                }
                .foregroundStyle(BBTheme.Colors.primary)
                .accessibilityIdentifier("doctor.visit_detail.edit")
            }
        }
    }

    @ViewBuilder private var readContent: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            BBTheme.Typography.caption("visit.date".l)
                .foregroundStyle(BBTheme.Colors.textSecondary)
            BBTheme.Typography.body(visit.date.appDayMonthYear)
                .foregroundStyle(BBTheme.Colors.textPrimary)
        }
        .accessibilityElement(children: .combine)

        if let note = visit.note {
            BBTheme.Typography.body(note)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        let asked = askedQuestions
        if !asked.isEmpty {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                BBTheme.Typography.caption("visit.asked_here".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(asked.enumerated()), id: \.element.persistentModelID) { index, question in
                    HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: checkGlyph))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .accessibilityHidden(true)
                        BBTheme.Typography.callout(question.text)
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("doctor.visit_detail.question.\(index + 1)")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            BBTheme.Typography.callout("visit.delete".l)
                .foregroundStyle(BBTheme.Colors.alert)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.top, BBTheme.Spacing.md)
        .accessibilityIdentifier("doctor.visit_detail.delete")
    }

    private func saveEdit() {
        do {
            try DoctorVisitActions.update(visit, date: editDate, note: editNote, in: modelContext)
            isEditing = false
        } catch {
            // Stay in edit mode so the change is not lost.
        }
    }
}

// MARK: - Presenting

/// The one way the report, Events and Recent present a visit's detail. The
/// delete runs in `onDismiss`, after the sheet is gone: deleting while the
/// sheet or the host's `item` still holds the model makes a body read a
/// deleted model ("backing data could no longer be found").
private struct VisitDetailSheetModifier: ViewModifier {
    @Binding var item: DoctorVisit?
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDeletion: DoctorVisit?

    func body(content: Content) -> some View {
        content.sheet(item: $item, onDismiss: performPendingDeletion) { visit in
            VisitDetailSheet(visit: visit) { pendingDeletion = $0 }
        }
    }

    private func performPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        try? DoctorVisitActions.delete(pending, in: modelContext)
    }
}

extension View {
    func visitDetailSheet(item: Binding<DoctorVisit?>) -> some View {
        modifier(VisitDetailSheetModifier(item: item))
    }
}

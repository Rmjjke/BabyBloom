import SwiftUI
import SwiftData

/// Adds a question for the pediatrician, or edits / deletes an open one.
/// Plain `.sheet` content, never `.entrySheet`: a question is often a worry,
/// and the rating prompt is not asked over one (DECISIONS 2026-09-22).
struct QuestionSheet: View {
    let question: DoctorQuestion?
    let baby: Baby?
    let onDelete: (DoctorQuestion) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(question: DoctorQuestion?, baby: Baby?, onDelete: @escaping (DoctorQuestion) -> Void) {
        self.question = question
        self.baby = baby
        self.onDelete = onDelete
        _text = State(initialValue: question?.text ?? "")
    }

    private var canSave: Bool { !DoctorVisitActions.clampedQuestion(text).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                    TextField("question.placeholder".l, text: $text, axis: .vertical)
                        .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .focused($focused)
                        .accessibilityIdentifier("doctor.question_sheet.field")
                        .bbCard()
                        // Cut here so the parent sees the limit instead of
                        // losing the tail silently at save.
                        .onChange(of: text) { _, new in
                            if new.count > DoctorVisitActions.questionMaxLength {
                                text = String(new.prefix(DoctorVisitActions.questionMaxLength))
                            }
                        }

                    if let question {
                        Button(role: .destructive) {
                            // The host deletes once the sheet is gone: a
                            // deleted model read by a sheet still on screen traps.
                            dismiss()
                            onDelete(question)
                        } label: {
                            BBTheme.Typography.callout("question.delete".l)
                                .foregroundStyle(BBTheme.Colors.alert)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .accessibilityIdentifier("doctor.question_sheet.delete")
                    }
                }
                .padding(BBTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .bbSheetTitle(question == nil ? "question.new_title".l : "question.title".l)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(BBTheme.Colors.primary)
                        .disabled(!canSave)
                        .accessibilityIdentifier("doctor.question_sheet.save")
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        // A sheet is not yet focusable in the same pass it appears on iOS 17,
        // so the focus hops one task later.
        .task { focused = true }
    }

    private func save() {
        do {
            if let question {
                try DoctorVisitActions.edit(question, text: text, in: modelContext)
            } else {
                try DoctorVisitActions.addQuestion(text, for: baby, in: modelContext)
            }
            dismiss()
        } catch {
            // Stay open: the text is still here to retry.
        }
    }
}

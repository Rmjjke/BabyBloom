import SwiftUI
import SwiftData

/// Logs a pediatrician visit and stamps the checked questions as asked, in
/// one save. Plain `.sheet` content, never `.entrySheet` (see QuestionSheet).
struct VisitSheet: View {
    let baby: Baby?
    /// Oldest first; the host passes them already ordered.
    let openQuestions: [DoctorQuestion]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var note = ""
    @State private var checked: Set<PersistentIdentifier>
    @State private var detent: PresentationDetent = .large
    // The check glyphs grow with the question text at AX sizes.
    @ScaledMetric(relativeTo: .body) private var checkGlyph: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var circleGlyph: CGFloat = 22
    // Read once: the range's upper bound and the default date must agree.
    private let now: Date

    init(baby: Baby?, openQuestions: [DoctorQuestion]) {
        self.baby = baby
        self.openQuestions = openQuestions
        // AppClock, not Date(): -BBNow seeds must match this screen.
        let now = AppClock.now
        self.now = now
        _date = State(initialValue: now)
        // Everything is checked by default: the parent unticks what was not asked.
        _checked = State(initialValue: Set(openQuestions.map(\.persistentModelID)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                    BBSheetHeading(title: "visit.title".l)
                    VisitFields(date: $date, note: $note,
                                range: VisitFields.dateRange(birthDate: baby?.birthDate, now: now))

                    if !openQuestions.isEmpty {
                        questionsSection
                    }
                }
                .padding(BBTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .bbSheetTitle("visit.title".l, movesIntoContentAtAX: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.save".l) { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(BBTheme.Colors.primary)
                        .accessibilityIdentifier("doctor.visit_sheet.save")
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large], selection: $detent)
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            BBTheme.Typography.caption("visit.questions_header".l)
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(openQuestions.enumerated()), id: \.element.persistentModelID) { index, question in
                    questionRow(question, number: index + 1)
                }
            }
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)

            BBTheme.Typography.caption("visit.carry_over".l)
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
    }

    private func questionRow(_ question: DoctorQuestion, number: Int) -> some View {
        let isChecked = checked.contains(question.persistentModelID)
        return Button {
            if isChecked { checked.remove(question.persistentModelID) }
            else { checked.insert(question.persistentModelID) }
        } label: {
            HStack(spacing: BBTheme.Spacing.md) {
                // Fixed-width slot so the text does not shift between the two glyphs.
                Group {
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: checkGlyph, weight: .semibold))
                            .foregroundStyle(BBTheme.Colors.primary)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: circleGlyph))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                    }
                }
                .frame(width: circleGlyph + 2)
                .accessibilityHidden(true)

                BBTheme.Typography.body(question.text)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, BBTheme.Spacing.md)
            .padding(.vertical, BBTheme.Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .accessibilityValue(isChecked ? "question.asked".l : "question.not_asked".l)
        .accessibilityIdentifier("doctor.visit_sheet.question.\(number)")
    }

    private func save() {
        let asked = openQuestions.filter { checked.contains($0.persistentModelID) }
        do {
            try DoctorVisitActions.logVisit(date: date, note: note, asking: asked,
                                            for: baby, in: modelContext)
            dismiss()
        } catch {
            // Stay open: nothing was saved, the parent can retry.
        }
    }
}

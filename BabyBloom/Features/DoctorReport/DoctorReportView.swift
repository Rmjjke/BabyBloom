import SwiftUI
import SwiftData

/// «For the pediatrician» — the report screen under More.
///
/// Today it carries the period line (②) and the questions card (④⑤⑥). The data
/// cards and the share button (m2-report-screen) slot in under the questions,
/// fed by the same `periodStart`, so this view is the layout they extend.
///
/// Pushed inside More's `NavigationStack`, so it has none of its own (the
/// `RecentActivityView` rule).
struct DoctorReportView: View {
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: [SortDescriptor(\DoctorVisit.date, order: .reverse),
                  SortDescriptor(\DoctorVisit.createdAt, order: .reverse)])
    private var visits: [DoctorVisit]
    @Query(sort: \DoctorQuestion.createdAt) private var questions: [DoctorQuestion]

    @Environment(\.modelContext) private var modelContext
    @State private var sheet: DoctorReportSheet?
    @State private var pendingQuestionDeletion: DoctorQuestion?
    @State private var detailVisit: DoctorVisit?

    private var baby: Baby? { babies.first }

    var body: some View {
        let latest = DoctorPeriod.latestVisit(visits)
        // Named now, though only ② reads it: the data cards must use the same start.
        let periodStart = DoctorPeriod.start(visits: visits, birthDate: baby?.birthDate ?? AppClock.now)
        let open = DoctorPeriod.openQuestions(questions)
        let askedAtLatest = latest.map { visit in
            questions.filter { $0.visit?.persistentModelID == visit.persistentModelID }
        } ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                periodHeader(latest: latest, periodStart: periodStart)

                QuestionsCard(
                    open: open,
                    latestVisit: latest,
                    askedAtLatest: askedAtLatest,
                    onAdd: { sheet = .newQuestion },
                    onEdit: { sheet = .editQuestion($0) },
                    // A swiped row is gone with the delete and no sheet holds it,
                    // so this one can delete at once.
                    onDelete: { try? DoctorVisitActions.delete($0, in: modelContext) },
                    onReopen: { try? DoctorVisitActions.reopen($0, in: modelContext) },
                    onLogVisit: { sheet = .logVisit }
                )
                // ⑦ data cards and ⑧ footnote land here (m2-report-screen).
            }
            .padding(BBTheme.Spacing.md)
            // iPad: one readable column, leading (design § 4).
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("doctor.report")
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("report.title".l)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $sheet, onDismiss: deletePendingQuestion) { which in
            switch which {
            case .newQuestion:
                QuestionSheet(question: nil, baby: baby, onDelete: { _ in })
            case .editQuestion(let question):
                QuestionSheet(question: question, baby: baby) { pendingQuestionDeletion = $0 }
            case .logVisit:
                VisitSheet(baby: baby, openQuestions: open)
            }
        }
        .visitDetailSheet(item: $detailVisit)
    }

    // MARK: ② Period line

    @ViewBuilder
    private func periodHeader(latest: DoctorVisit?, periodStart: Date) -> some View {
        if let latest {
            let days = DoctorPeriod.periodDays(from: periodStart, to: AppClock.now)
            let length = days == 0 ? "report.period_today".l : "\(days) \(days.dayWord)"
            Button { detailVisit = latest } label: {
                HStack(spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.callout(String(format: "report.since_visit_fmt".l,
                                                      latest.date.appDayMonth, length))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("report.a11y_period_hint".l)
            .accessibilityIdentifier("doctor.period_line")
        } else if let baby {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                BBTheme.Typography.callout(String(format: "report.since_birth_fmt".l,
                                                  Baby.describeAge(from: baby.birthDate, to: AppClock.now)))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .accessibilityIdentifier("doctor.period_line")
                BBTheme.Typography.caption("report.no_visit_hint".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
    }

    // MARK: Sheets

    /// A question deleted from its own sheet is deleted once that sheet is gone:
    /// a deleted model read by a sheet still on screen traps.
    private func deletePendingQuestion() {
        guard let pending = pendingQuestionDeletion else { return }
        pendingQuestionDeletion = nil
        try? DoctorVisitActions.delete(pending, in: modelContext)
    }
}

/// The sheets the report presents (the visit detail has its own modifier).
enum DoctorReportSheet: Identifiable {
    case newQuestion
    case editQuestion(DoctorQuestion)
    case logVisit

    enum ID: Hashable {
        case newQuestion, logVisit
        case editQuestion(PersistentIdentifier)
    }

    var id: ID {
        switch self {
        case .newQuestion: return .newQuestion
        case .logVisit: return .logVisit
        case .editQuestion(let question): return .editQuestion(question.persistentModelID)
        }
    }
}

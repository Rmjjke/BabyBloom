import SwiftUI
import SwiftData

/// «For the pediatrician» — the report screen under More.
///
/// Top to bottom: the name ①, the period line ②, the age ③, the questions
/// card (④⑤⑥), then the data cards ⑦ and the footnote ⑧, all fed by one
/// `periodStart`. The share button ⑩ sends the same period as a PDF (Premium).
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
    @Environment(SubscriptionManager.self) private var store
    @State private var sheet: DoctorReportSheet?
    @State private var shareRequest: ShareRequest?
    @State private var showPaywall = false
    @State private var showWriteError = false
    @State private var pendingQuestionDeletion: DoctorQuestion?
    @State private var detailVisit: DoctorVisit?
    @State private var showAddGrowth = false

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
                // The stack's own padding stands between the bar and the heading.
                BBScreenHeading(title: "report.title".l, topPadding: 0)
                if let baby { ReportNameLine(baby: baby) }
                periodHeader(latest: latest, periodStart: periodStart)
                if let baby { ReportAgeLine(baby: baby) }

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

                if let baby {
                    ReportDataSection(periodStart: periodStart, startsAtVisit: latest != nil,
                                      baby: baby, onAddWeighing: { showAddGrowth = true })
                }
            }
            .padding(BBTheme.Spacing.md)
            // iPad: one readable column, leading.
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("doctor.report")
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .bbScreenTitle("report.title".l)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { share(periodStart: periodStart, openQuestions: open) } label: {
                    // The badge beside the icon, as on Events' plus: the
                    // affordance stays readable and the gate shows.
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(BBTheme.Colors.primary)
                        if !store.isPremium { LockBadge().offset(x: 8, y: 6) }
                    }
                }
                .disabled(baby == nil)
                .accessibilityLabel(Text("report.a11y_share".l))
                .bbLockedAccessibility(!store.isPremium)
                .accessibilityIdentifier("doctor.share")
            }
        }
        .sheet(item: $shareRequest) { ShareSheet(items: $0.items) }
        .sheet(isPresented: $showPaywall) { PaywallView(source: .doctorReport) }
        // The export screen's wording: the same failure, a full disk.
        .alert("export.error_title".l, isPresented: $showWriteError) {
            Button("button.close".l, role: .cancel) {}
        } message: {
            Text("export.error_body".l)
        }
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
        // Plain .sheet, not .entrySheet: no rating prompt on this screen
        // (DECISIONS 2026-11-01), a weighing added here included.
        .sheet(isPresented: $showAddGrowth) { AddGrowthSheet() }
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

    // MARK: ⑩ Share

    /// Free: the paywall. Premium: the PDF of the period on screen, built from
    /// a fresh fetch with the same window `ReportDataSection` queries — the
    /// button has no @Query of its own, and one rule feeds both (DECISIONS
    /// 2026-11-02).
    private func share(periodStart: Date, openQuestions: [DoctorQuestion]) {
        guard store.isPremium else { showPaywall = true; return }
        guard let baby else { return }
        let now = AppClock.now
        let summary = DoctorReportSummary.make(
            input: .load(baby: baby, periodStart: periodStart, in: modelContext),
            periodStart: periodStart, now: now,
            startsAtVisit: DoctorPeriod.latestVisit(visits) != nil, calendar: .current)
        let data = DoctorReportPDF.data(summary: summary, baby: baby,
                                        openQuestions: openQuestions.map(\.text),
                                        periodStart: periodStart, now: now)
        // As the export screen does: never leave a health record lying in tmp.
        ExportGenerator.cleanupExports()
        guard let url = ExportGenerator.writeTempFile(
            name: DoctorReportPDF.fileName(babyName: baby.name, date: now), data: data)
        else { showWriteError = true; return }
        shareRequest = ShareRequest(items: [url])
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

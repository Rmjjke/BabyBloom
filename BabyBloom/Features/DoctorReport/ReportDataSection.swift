import SwiftUI
import SwiftData

/// ⑦ the four data cards and ⑧ the footnote, for one period.
///
/// A child view so its queries can be filtered by the period: the parent's
/// body re-runs on every sheet and every store change (a CloudKit import
/// included), and summarising the whole history since birth on each of those
/// was the cost the final review flagged. Growth stays unfiltered — the latest
/// weighing the doctor needs may be older than the period.
struct ReportDataSection: View {
    let periodStart: Date
    let startsAtVisit: Bool
    let baby: Baby
    let onAddWeighing: () -> Void

    @Query private var feeds: [FeedingEntry]
    @Query private var sleeps: [SleepEntry]
    @Query private var diapers: [DiaperEntry]
    @Query private var growthEntries: [GrowthEntry]

    init(periodStart: Date, startsAtVisit: Bool, baby: Baby, onAddWeighing: @escaping () -> Void) {
        self.periodStart = periodStart
        self.startsAtVisit = startsAtVisit
        self.baby = baby
        self.onAddWeighing = onAddWeighing
        // The same window the share button's fetch uses.
        let (start, sleepsFrom) = DoctorReportSummary.Input.window(periodStart: periodStart)
        _feeds = Query(filter: #Predicate<FeedingEntry> { $0.startTime >= start })
        _sleeps = Query(filter: #Predicate<SleepEntry> { $0.startTime >= sleepsFrom })
        _diapers = Query(filter: #Predicate<DiaperEntry> { $0.time >= start })
    }

    var body: some View {
        let summary = DoctorReportSummary.make(
            input: DoctorReportSummary.Input(baby: baby, feeds: feeds, sleeps: sleeps,
                                             diapers: diapers, growth: growthEntries),
            periodStart: periodStart,
            now: AppClock.now,
            startsAtVisit: startsAtVisit,
            calendar: .current)

        GrowthReportCard(growth: summary.growth, periodStart: periodStart,
                         hidesPeriodRows: summary.showsNewPeriodCard,
                         onAddWeighing: onAddWeighing)
        if summary.showsNewPeriodCard {
            ReportNewPeriodCard(periodStart: periodStart)
        } else {
            FeedingReportCard(feeding: summary.feeding, periodStart: periodStart, isShort: summary.isShort)
            SleepReportCard(sleep: summary.sleep, periodStart: periodStart, isShort: summary.isShort)
            DiapersReportCard(diapers: summary.diapers, periodStart: periodStart, isShort: summary.isShort)
        }
        BBTheme.Typography.caption("report.footnote".l)
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

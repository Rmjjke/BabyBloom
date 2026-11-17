import SwiftUI

/// Sleep facts for the report period.
struct SleepReportCard: View {
    /// nil = no finished sleep in the period.
    let sleep: DoctorReportSummary.Sleep?
    let periodStart: Date

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            ReportCardHeader(icon: "moon.fill", tint: BBTheme.Colors.sleep, title: "export.cat.sleep".l)
            if let sleep {
                rows(sleep)
            } else {
                ReportEmptyLine(format: "report.empty_sleep_fmt", periodStart: periodStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doctor.section.sleep")
    }

    @ViewBuilder
    private func rows(_ sleep: DoctorReportSummary.Sleep) -> some View {
        if let perDay = sleep.perDay {
            ReportRow(format: "weekly.sleep_fmt".l, value: ReportFormat.duration(perDay))
        } else {
            ReportRow(format: "report.sleep_total_fmt".l, value: ReportFormat.duration(sleep.total))
        }
        if let longest = sleep.longest {
            ReportRow(format: "weekly.longest_sleep_fmt".l, value: ReportFormat.duration(longest),
                      suffix: sleep.longestStart.map { ReportFormat.date($0) })
        }
        ReportDaysLine(days: sleep.days, averaged: sleep.averaged)
    }
}

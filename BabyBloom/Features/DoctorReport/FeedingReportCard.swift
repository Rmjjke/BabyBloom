import SwiftUI

/// Feeding facts for the report period.
struct FeedingReportCard: View {
    /// nil = nothing finished in the period.
    let feeding: DoctorReportSummary.Feeding?
    let periodStart: Date
    let isShort: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            ReportCardHeader(icon: "heart.fill", tint: BBTheme.Colors.feeding, title: "export.cat.feeding".l)
            if let feeding {
                rows(feeding)
            } else {
                ReportEmptyLine(format: "report.empty_feeding_fmt", periodStart: periodStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doctor.section.feeding")
    }

    @ViewBuilder
    private func rows(_ feeding: DoctorReportSummary.Feeding) -> some View {
        if isShort {
            ReportRow(format: "report.feeds_count_fmt".l, value: "\(feeding.totalFeeds)")
        } else if let perDay = feeding.feedsPerDay {
            ReportRow(format: "weekly.feeds_fmt".l, value: WeeklyFormat.perDay(perDay))
        }
        if !feeding.byType.isEmpty {
            ReportRow(format: "report.feeds_by_type_fmt".l,
                      value: ReportFormat.countList(feeding.byType.map {
                          ReportFormat.countItem(name: $0.type.displayName.l, count: $0.count)
                      }))
        }
        if let ml = feeding.bottleMLPerDay {
            ReportRow(format: "report.bottle_a_day_fmt".l, value: ReportFormat.ml(ml))
        }
        if let typical = feeding.breastfeedMedian {
            ReportRow(format: "report.breastfeed_avg_fmt".l, value: ReportFormat.duration(typical))
        }
        ReportDaysLine(days: feeding.days, isShort: isShort)
    }
}

import SwiftUI

/// Diaper facts for the report period.
struct DiapersReportCard: View {
    /// nil = no diaper in the period.
    let diapers: DoctorReportSummary.Diapers?
    let periodStart: Date

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            ReportCardHeader(icon: "drop.fill", tint: BBTheme.Colors.diaper, title: "export.cat.diapers".l)
            if let diapers {
                rows(diapers)
            } else {
                ReportEmptyLine(format: "report.empty_diapers_fmt", periodStart: periodStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doctor.section.diapers")
    }

    @ViewBuilder
    private func rows(_ diapers: DoctorReportSummary.Diapers) -> some View {
        if let wet = diapers.wetPerDay, let dirty = diapers.dirtyPerDay {
            ReportRow(format: "report.wet_a_day_fmt".l, value: WeeklyFormat.perDay(wet))
            ReportRow(format: "report.dirty_a_day_fmt".l, value: WeeklyFormat.perDay(dirty))
        } else {
            ReportRow(format: "report.wet_count_fmt".l, value: "\(diapers.wetCount)")
            ReportRow(format: "report.dirty_count_fmt".l, value: "\(diapers.dirtyCount)")
        }
        // Names and counts only: no swatch and no warning.
        if !diapers.colors.isEmpty {
            ReportRow(format: "report.stool_colors_fmt".l,
                      value: ReportFormat.countList(diapers.colors.map {
                          ReportFormat.countItem(name: $0.color.displayName.l, count: $0.count)
                      }))
        }
        ReportDaysLine(days: diapers.days, averaged: diapers.averaged)
    }
}

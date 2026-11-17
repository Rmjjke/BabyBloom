import SwiftUI

/// ① the baby's name, above the period line ②.
struct ReportNameLine: View {
    let baby: Baby

    var body: some View {
        if !baby.name.isEmpty {
            BBTheme.Typography.title2(baby.name)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("doctor.header")
        }
    }
}

/// ③ today's age (plus the corrected age for a preterm baby), under ②: ②
/// counts the period, ③ describes the child.
struct ReportAgeLine: View {
    let baby: Baby

    private var ageLine: String {
        let age = Baby.describeAge(from: baby.birthDate, to: AppClock.now)
        guard baby.isPreterm else { return age }
        // `correctedAgeDescription` reads the wall clock; the report follows -BBNow.
        return String(format: "report.age_corrected_fmt".l, age,
                      Baby.describeAge(from: baby.correctedBirthDate, to: AppClock.now))
    }

    var body: some View {
        ReportCaption(ageLine)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("doctor.age_line")
    }
}

/// «A new period started on <date>»: one card in place of three empty ones.
struct ReportNewPeriodCard: View {
    let periodStart: Date

    var body: some View {
        BBTheme.Typography.callout(ReportFormat.sentence("report.new_period_fmt".l, date: ReportFormat.dayMonth(periodStart)))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bbCard()
            .accessibilityIdentifier("doctor.new_period")
    }
}

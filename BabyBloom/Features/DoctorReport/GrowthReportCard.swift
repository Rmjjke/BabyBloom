import SwiftUI

/// Growth facts for the report. Most of it does not depend on
/// the period: the doctor wants the latest weighing even when it is older.
struct GrowthReportCard: View {
    let growth: DoctorReportSummary.Growth
    let periodStart: Date
    /// A new period just began: the period rows (change, weighings) go, the
    /// standing facts stay.
    let hidesPeriodRows: Bool
    let onAddWeighing: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showsAll = false

    /// More than this and «Show all N» takes over.
    private static let collapsedCount = 6

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            ReportCardHeader(icon: "scalemass.fill", tint: BBTheme.Colors.growth, title: "export.cat.growth".l)
            // The empty state is about weighings: a height-only history still offers one.
            if growth.latestWeight == nil { empty }
            if !growth.isEmpty {
                facts
                if !hidesPeriodRows { periodRows }
            }
            if let birth = atBirth { ReportCaption(birth) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doctor.section.growth")
    }

    // MARK: Empty

    private var empty: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            BBTheme.Typography.callout("report.empty_growth".l)
                .foregroundStyle(BBTheme.Colors.textSecondary)
            Button(action: onAddWeighing) {
                BBTheme.Typography.callout("growth.add_weighing".l)
                    .fontWeight(.semibold)
                    .foregroundStyle(BBTheme.Colors.primary)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("doctor.growth.add_weighing")
        }
    }

    // MARK: Standing facts

    @ViewBuilder
    private var facts: some View {
        if let weight = growth.latestWeight {
            ReportRow(format: "report.weight_fmt".l, value: ReportFormat.kg(weight.value))
            ReportCaption(String(format: "percentile.as_of_fmt".l, ReportFormat.date(weight.date)))
            percentile(growth.weightPercentile, format: "report.percentile_weight_fmt")
        }
        if let height = growth.latestHeight {
            ReportRow(format: "report.height_fmt".l, value: ReportFormat.cm(height.value),
                      suffix: ReportFormat.date(height.date))
            // One sentence per card: before the due date (or past the table)
            // weight and height share it, and printing it twice read as two facts.
            if !growth.repeatsWeightNote {
                percentile(growth.heightPercentile, format: "report.percentile_height_fmt")
            }
        }
        if let head = growth.latestHead {
            ReportRow(format: "growth.head_fmt".l, value: head.value.appDecimal(1),
                      suffix: ReportFormat.date(head.date))
        }
    }

    @ViewBuilder
    private func percentile(_ row: DoctorReportSummary.PercentileRow, format: String) -> some View {
        switch row {
        case .reading(let reading):
            // The badge, not the clamped number: past the chart it reads «> 97».
            ReportRow(format: format.l, value: ReportFormat.glued(reading.badge))
        case .beforeDueDate:
            ReportCaption("percentile.before_due_date".l)
        case .outOfRange:
            ReportCaption("percentile.out_of_range".l)
        case .none:
            EmptyView()
        }
    }

    // MARK: Period rows

    @ViewBuilder
    private var periodRows: some View {
        if let change = growth.change {
            let since = String(format: "report.change_since_fmt".l, ReportFormat.date(change.baseDate), "%@")
            ReportRow(format: since, value: ReportFormat.grams(change.grams))
        }
        if !growth.weighings.isEmpty { weighings }
    }

    private var weighings: some View {
        let all = growth.weighings
        let shown = showsAll ? all : Array(all.prefix(Self.collapsedCount))
        return VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            BBTheme.Typography.callout("report.weighings".l)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(shown.enumerated()), id: \.offset) { _, weighing in
                weighingLine(weighing)
            }
            if all.count > Self.collapsedCount && !showsAll {
                Button { showsAll = true } label: {
                    BBTheme.Typography.callout(String(format: "report.show_all_fmt".l, all.count))
                        .fontWeight(.semibold)
                        .foregroundStyle(BBTheme.Colors.primary)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("doctor.growth.show_all")
            }
        }
    }

    /// «28 Oct · 5.42 kg · 58 cm»; at accessibility sizes the date goes over the
    /// value. A head value takes a line of its own under them, as the PDF's
    /// table gives it a column: a third part on the first line wraps at 320 pt.
    @ViewBuilder
    private func weighingLine(_ weighing: DoctorReportSummary.Weighing) -> some View {
        let value = ([ReportFormat.kg(weighing.weightKg)]
                     + [weighing.heightCm.map(ReportFormat.cm)].compactMap { $0 })
            .joined(separator: ReportFormat.joiner)
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                    ReportCaption(ReportFormat.date(weighing.date))
                    BBTheme.Typography.metricSmall(value)
                    if let head = weighing.headCm { headLine(head) }
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    BBTheme.Typography.callout(ReportFormat.date(weighing.date) + ReportFormat.joiner)
                        + BBTheme.Typography.metricSmall(value)
                    if let head = weighing.headCm { headLine(head) }
                }
            }
        }
        .foregroundStyle(BBTheme.Colors.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// «Head: 38.5 cm», split at `%@` as `ReportRow` splits it, so the word
    /// order stays the translator's.
    private func headLine(_ cm: Double) -> Text {
        let parts = "growth.head_fmt".l.components(separatedBy: "%@")
        return BBTheme.Typography.callout(parts.first ?? "")
            + BBTheme.Typography.metricSmall(cm.appDecimal(1))
            + BBTheme.Typography.callout(parts.dropFirst().joined())
    }

    // MARK: At birth

    private var atBirth: String? {
        let parts = [growth.atBirthWeightKg.map(ReportFormat.kg),
                     growth.atBirthHeightCm.map(ReportFormat.cm)].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return String(format: "report.at_birth_fmt".l, parts.joined(separator: ReportFormat.joiner))
    }
}

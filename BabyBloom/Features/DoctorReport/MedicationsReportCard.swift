import SwiftUI

/// Medications given in the report period: per medication its name as
/// written, the doses counted with the first and last day, and the dose text
/// under it. No interval, no maximum and no mark on an early dose: in a
/// document for the doctor that mark would be a verdict on the parent.
struct MedicationsReportCard: View {
    /// Not empty: the card is absent when no dose falls in the period.
    let medications: [DoctorReportSummary.Medication]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            ReportCardHeader(icon: "pills.fill", tint: BBTheme.Colors.accent, title: "medication.report_title".l)
            ForEach(Array(medications.enumerated()), id: \.offset) { _, medication in
                VStack(alignment: .leading, spacing: 2) {
                    ReportRow(label: (medication.name ?? "medication.report_without_name".l) + ": ",
                              value: MedicationFormat.doseCount(medication.count),
                              suffix: ReportFormat.dayRange(medication.first, medication.last, now: now))
                    if let dose = medication.doseText {
                        ReportCaption(dose)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("doctor.section.medications")
    }
}

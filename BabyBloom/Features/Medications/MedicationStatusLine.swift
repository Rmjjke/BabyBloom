import SwiftUI

/// One running medication on the Events screen, above Quick input: its name
/// and its status line, the whole line opening its detail.
struct MedicationStatusLine: View {
    let medicine: Medicine
    let now: Date

    var body: some View {
        let status = medicine.lines(now: now).primary
        NavigationLink {
            MedicationDetailView(medicine: medicine)
        } label: {
            HStack(alignment: .center, spacing: BBTheme.Spacing.md) {
                Image(systemName: "pills.fill")
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: medicine.name)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    if let status {
                        Text(verbatim: status)
                            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                MedicationChevron()
            }
            .padding(.horizontal, BBTheme.Spacing.md)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .bbShadow(BBTheme.Shadow.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(BBScaleButtonStyle())
        .accessibilityLabel(Text(MedicationFormat.spoken([medicine.name, status])))
        .accessibilityHint(Text("medication.a11y_open_one".l))
    }
}

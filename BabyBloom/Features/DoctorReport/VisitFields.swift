import SwiftUI

/// Date and note of a pediatrician visit — shared by the log sheet and the
/// detail's edit mode so the two cannot drift apart.
struct VisitFields: View {
    @Binding var date: Date
    @Binding var note: String
    let range: ClosedRange<Date>

    /// Birth date (start of day) to now. `min` keeps the range valid for a
    /// birth date that drifted into the future: an inverted range traps.
    static func dateRange(birthDate: Date?, now: Date, calendar: Calendar = .current) -> ClosedRange<Date> {
        let lower = birthDate.map { min(calendar.startOfDay(for: $0), now) } ?? .distantPast
        return lower...now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            datePicker
                .padding(BBTheme.Spacing.md)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)

            TextField("form.notes_optional".l, text: $note, axis: .vertical)
                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular))
                // Room to wrap: at AX2 a one-line field cut the placeholder
                // («Заметки (необязатель…»).
                .lineLimit(2...6)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .padding(BBTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .accessibilityIdentifier("doctor.visit_sheet.note")
                .onChange(of: note) { _, new in
                    if new.count > DoctorVisitActions.noteMaxLength {
                        note = String(new.prefix(DoctorVisitActions.noteMaxLength))
                    }
                }
        }
    }

    private var datePicker: some View {
        BBLabeledPicker("visit.date".l) { label in
            DatePicker(label, selection: $date, in: range, displayedComponents: .date)
                .tint(BBTheme.Colors.primary)
                .accessibilityIdentifier("doctor.visit_sheet.date")
        }
    }
}

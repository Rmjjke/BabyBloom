import SwiftData
import SwiftUI

extension Medicine {
    /// The medications Home shows: running, with a dose under a day old, by
    /// name. A course nobody ends leaves Home a day after its last dose, and
    /// one with no dose yet has nothing to state.
    static func onHome(_ medicines: [Medicine], now: Date) -> [Medicine] {
        MedicationFormat.byName(medicines.filter { medicine in
            guard !medicine.isEnded, let last = medicine.schedule(now: now).lastDose else { return false }
            return now.timeIntervalSince(last) < MedicineSchedule.day
        })
    }
}

/// Home's medication card, or nothing. Not a `TimelineView`: an empty one
/// still takes a place in the Dashboard's stack, and its spacing with it.
struct MedicationHomeSection: View {
    @Query private var medicines: [Medicine]
    /// Read so a dose logged or deleted anywhere draws the card again: a
    /// change on the event's side of the link does not always reach observers
    /// of `medicine.doses`.
    @Query private var events: [CustomEvent]
    /// Bumped on each minute while the card shows: its lines move, and a
    /// course leaves Home a day after its last dose.
    @State private var minute = 0

    var body: some View {
        let _ = (events.count, minute)
        let now = AppClock.now
        let shown = Medicine.onHome(medicines, now: now)
        if !shown.isEmpty {
            MedicationHomeCard(medicines: shown, now: now)
                .task {
                    while !Task.isCancelled {
                        let intoMinute = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                        try? await Task.sleep(for: .seconds(60 - intoMinute))
                        minute += 1
                    }
                }
        }
    }
}

/// Home's card while a course runs: a line per medication, name and status,
/// the whole card one target. One medication opens its detail, two or more
/// the list. A standing fact, so the plain card, not the running timer's
/// tinted one, and the same look inside the interval and after it.
struct MedicationHomeCard: View {
    /// From `Medicine.onHome`: not empty, sorted.
    let medicines: [Medicine]
    let now: Date

    var body: some View {
        let rows = medicines.map { (name: $0.name, status: $0.lines(now: now).primary) }
        NavigationLink {
            if medicines.count == 1, let medicine = medicines.first {
                MedicationDetailView(medicine: medicine)
            } else {
                MedicationsListView()
            }
        } label: {
            HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
                MedicationDisc()
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: row.name)
                                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            if let status = row.status {
                                Text(verbatim: status)
                                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                            }
                        }
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                MedicationChevron()
            }
            .frame(minHeight: 76 - 2 * BBTheme.Spacing.md, alignment: .top)
            .bbCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(BBScaleButtonStyle())
        // One element; the label starts with the card's subject, since the
        // card itself has no title.
        .accessibilityLabel(Text(MedicationFormat.spoken(
            ["medication.title".l] + rows.flatMap { [$0.name, $0.status] })))
        .accessibilityHint(Text(medicines.count == 1 ? "medication.a11y_open_one".l : "medication.a11y_open_list".l))
        .accessibilityIdentifier("home.medications")
    }
}

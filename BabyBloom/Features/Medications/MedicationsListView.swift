import SwiftUI
import SwiftData

/// More › Medications: the running courses by name, the ended ones under a
/// collapsed header. Medicines are free, so nothing here carries a padlock.
struct MedicationsListView: View {
    @Query private var medicines: [Medicine]
    /// Read so a dose logged or deleted on the detail draws the rows again: a
    /// change on the event's side of the link does not always reach observers
    /// of `medicine.doses`.
    @Query private var events: [CustomEvent]
    @State private var showForm = false
    @State private var showsEnded = false

    var body: some View {
        let _ = events.count
        ScrollView {
            // Once a minute: the status lines move from "next dose not before"
            // to "has passed" with no transition.
            TimelineView(.everyMinute) { _ in
                content(now: AppClock.now)
            }
            .padding(.horizontal, BBTheme.Spacing.md)
            .padding(.bottom, BBTheme.Spacing.xl)
            .frame(maxWidth: MedicationLayout.maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("medication.title".l)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
                .accessibilityLabel(Text("medication.add".l))
                .accessibilityIdentifier("medication.add")
            }
        }
        .sheet(isPresented: $showForm) {
            MedicationFormSheet(medicine: nil)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let active = MedicationFormat.byName(medicines.filter { !$0.isEnded })
        let ended = MedicationFormat.byEnd(medicines.filter(\.isEnded))
        VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
            if medicines.isEmpty {
                VStack(spacing: BBTheme.Spacing.lg) {
                    // The view draws its own surface, so its secondary
                    // subtitle sits on a card and keeps its contrast.
                    EmptyStateView(icon: "pills.fill",
                                   color: BBTheme.Colors.accent,
                                   title: "medication.empty_title",
                                   subtitle: "medication.empty_body")
                    BBPrimaryButton("medication.add".l, icon: "plus") { showForm = true }
                        .accessibilityIdentifier("medication.empty_add")
                }
            }
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    BBSectionHeader(title: "medication.section_active")
                        .accessibilityAddTraits(.isHeader)
                    ForEach(active) { medicine in
                        MedicationRowLink(medicine: medicine, now: now)
                    }
                }
            }
            if !ended.isEmpty {
                // A DisclosureGroup, so VoiceOver says expanded or collapsed.
                DisclosureGroup(isExpanded: $showsEnded) {
                    VStack(spacing: BBTheme.Spacing.sm) {
                        ForEach(ended) { medicine in
                            MedicationRowLink(medicine: medicine, now: now)
                        }
                    }
                    .padding(.top, BBTheme.Spacing.sm)
                } label: {
                    BBTheme.Typography.title3(String(format: "medication.section_ended_fmt".l, ended.count))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityAddTraits(.isHeader)
                }
                .tint(BBTheme.Colors.textSecondary)
                .accessibilityIdentifier("medication.ended")
            }
        }
    }
}

/// The feature's sizes that are not theme tokens.
enum MedicationLayout {
    /// iPad: one column, leading, never wider than this.
    static let maxWidth: CGFloat = 600
}

/// The medication glyph in its disc. Decoration only: the name carries the
/// meaning.
struct MedicationDisc: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(BBTheme.Colors.accent.opacity(0.22))
                .frame(width: 44, height: 44)
            Image(systemName: "pills.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(BBTheme.Colors.accent)
        }
        .accessibilityHidden(true)
    }
}

/// One medication on the list: the whole row opens its detail.
struct MedicationRowLink: View {
    let medicine: Medicine
    let now: Date

    var body: some View {
        let lines = medicine.lines(now: now)
        let meta = medicine.isEnded ? lines.secondary : medicine.metaLine
        NavigationLink {
            MedicationDetailView(medicine: medicine)
        } label: {
            HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
                MedicationDisc()
                VStack(alignment: .leading, spacing: 2) {
                    Text(medicine.name)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    if let status = lines.primary {
                        Text(status)
                            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    }
                    Text(meta)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                MedicationChevron()
            }
            .padding(BBTheme.Spacing.md)
            .frame(minHeight: 76, alignment: .top)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.md)
            .bbShadow(BBTheme.Shadow.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(BBScaleButtonStyle())
        // A label on the link replaces the composed one and keeps the button
        // trait; `children: .ignore` on a button can drop its activation.
        .accessibilityLabel(Text(MedicationFormat.spoken([medicine.name, lines.primary, meta])))
        .accessibilityHint(Text("medication.a11y_open_one".l))
    }
}

struct MedicationChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
            .accessibilityHidden(true)
    }
}

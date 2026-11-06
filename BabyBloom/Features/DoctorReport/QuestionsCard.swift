import SwiftUI

// MARK: - Questions card (④ open, ⑤ log, ⑥ asked)

/// The questions for the pediatrician and the visit button. It only calls its
/// closures: every write belongs to `DoctorVisitActions`, so the host decides
/// when a model may be deleted (a sheet may still be reading it).
struct QuestionsCard: View {
    let open: [DoctorQuestion]            // oldest first
    let latestVisit: DoctorVisit?
    let askedAtLatest: [DoctorQuestion]   // oldest first
    let onAdd: () -> Void
    let onEdit: (DoctorQuestion) -> Void
    let onDelete: (DoctorQuestion) -> Void
    let onReopen: (DoctorQuestion) -> Void
    let onLogVisit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var askedExpanded = false

    // Glyphs grow with the text so they never look lost beside AX sizes.
    @ScaledMetric(relativeTo: .body) private var addGlyph: CGFloat = 17
    @ScaledMetric(relativeTo: .callout) private var checkGlyph: CGFloat = 13
    @ScaledMetric(relativeTo: .footnote) private var chevron: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            BBTheme.Typography.title3("question.section".l)
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if open.isEmpty {
                BBTheme.Typography.callout("question.empty".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                openRows
            }

            addButton

            BBSecondaryButton("visit.log".l, icon: "stethoscope", action: onLogVisit)
                .accessibilityIdentifier("doctor.visit.log")

            if let latestVisit, !askedAtLatest.isEmpty {
                askedSection(visit: latestVisit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
    }

    // MARK: Open questions

    private var openRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(open.enumerated()), id: \.element.persistentModelID) { index, q in
                if index > 0 { Divider() }
                SwipeToDeleteRow(onDelete: { onDelete(q) }) {
                    Button { onEdit(q) } label: {
                        HStack(alignment: .center, spacing: BBTheme.Spacing.sm) {
                            // No line limit: the question is the content, and
                            // a truncated worry is worse than a tall row.
                            BBTheme.Typography.body(q.text)
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.system(size: chevron, weight: .semibold))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, BBTheme.Spacing.sm)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("button.edit".l)
                    .accessibilityAction(named: Text("button.delete".l)) { onDelete(q) }
                    .accessibilityIdentifier("doctor.question.open.\(index + 1)")
                    // Opaque, or the revealed swipe button shows through the text.
                    .background(BBTheme.Colors.surface)
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            HStack(spacing: BBTheme.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: addGlyph))
                    .accessibilityHidden(true)
                BBTheme.Typography.callout("question.add".l)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(BBTheme.Colors.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("doctor.question.add")
    }

    // MARK: Asked at the latest visit

    private func askedSection(visit: DoctorVisit) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                // Reduce Motion: a short cross-fade instead of the height reveal.
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.25)) {
                    askedExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.caption(
                        String(format: "question.asked_at_fmt".l, visit.date.appDayMonth, askedAtLatest.count)
                    )
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: chevron, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        // Under Reduce Motion the glyph flips with the fade,
                        // not as a separate spin.
                        .rotationEffect(.degrees(askedExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(askedExpanded ? "weekly.a11y_expanded".l : "weekly.a11y_collapsed".l)
            .accessibilityIdentifier("doctor.asked.toggle")

            if askedExpanded {
                askedRows
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipped()
    }

    private var askedRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(askedAtLatest.enumerated()), id: \.element.persistentModelID) { index, q in
                if index > 0 { Divider() }
                SwipeToDeleteRow(
                    onDelete: { onReopen(q) },
                    title: "question.back_to_list",
                    systemImage: "arrow.uturn.backward",
                    tint: BBTheme.Colors.primary
                ) {
                    HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: checkGlyph, weight: .semibold))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            // Aligns the glyph with the first text line.
                            .padding(.top, 3)
                        BBTheme.Typography.callout(q.text)
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, BBTheme.Spacing.sm)
                    .frame(minHeight: 44)
                    .background(BBTheme.Colors.surface)
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: Text("question.back_to_list".l)) { onReopen(q) }
                    .accessibilityIdentifier("doctor.question.asked.\(index + 1)")
                }
            }
        }
    }
}

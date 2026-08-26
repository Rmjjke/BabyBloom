import SwiftUI

/// The free half of the feeding–weight feature: three signals, plainly stated.
///
/// Most of the time all three read "within the reference" and this section's
/// job is reassurance. Status is carried by a WORD, with colour as
/// reinforcement only, so the row survives greyscale and VoiceOver.
struct NutritionSection: View {
    let assessment: FeedingAdequacy.Assessment?

    /// Drives the row layout only — never a font size. At an accessibility size
    /// the label and its status cannot share a line without one of them being
    /// proposed a width narrower than its own longest word, and SwiftUI answers
    /// that by breaking INSIDE the word. See `row(icon:tint:label:value:signal:)`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        InsightCard(title: "section.nutrition".l) {
            if let assessment {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    Text(String(format: "nutrition.window_fmt".l,
                                assessment.windowDays, assessment.windowDays.dayWord))
                        .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                                        weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)

                    // The gain row shows STATUS ONLY. Grams per week stay in the
                    // Premium WeightGainCard, where they already are.
                    row(icon: "chart.line.uptrend.xyaxis", tint: BBTheme.Colors.growth,
                        label: "nutrition.row_gain".l, value: nil, signal: assessment.gain)
                    row(icon: "heart.fill", tint: BBTheme.Colors.feeding,
                        label: "nutrition.row_feeds".l,
                        value: assessment.feedingsPerDay, signal: assessment.feeding)
                    row(icon: "drop.fill", tint: BBTheme.Colors.diaper,
                        label: "nutrition.row_nappies".l,
                        value: assessment.wetNappiesPerDay, signal: assessment.nappies)
                }
            } else {
                HintText(text: "nutrition.need_weighing".l)
            }
        }
    }

    /// The icon scales off `.body` exactly as the label beside it does, and its
    /// column follows — a fixed 14pt glyph in a fixed 20pt slot sits beside a
    /// label that roughly doubles at the AX2 cap, and the row falls apart.
    /// `UIFontMetrics` rather than `@ScaledMetric` so the width obeys the same
    /// rule as `BBTheme.Typography.scaled`, which is what sizes the text: two
    /// mechanisms would disagree wherever the environment overrides the size.
    ///
    /// **Two layouts, and the second one is not decoration.** Side by side, the
    /// label and its status divide one card's width between them; at an
    /// accessibility size that leaves each of them a column narrower than its
    /// own longest word, and SwiftUI's only answer to a word wider than the
    /// space proposed to it is to break inside the word. A render at AX2 in
    /// Russian showed exactly that — "Прибавк / а", "Кормлен / ия" — orphaned
    /// letters with no hyphen. So above the accessibility threshold the status
    /// moves onto its own line under the label, where each gets the full width
    /// of the card and breaks between words like prose. Below it, nothing
    /// changes: the side-by-side row is the design, and it holds at every
    /// non-accessibility size in all three languages.
    @ViewBuilder
    private func row(icon: String, tint: Color, label: String,
                     value: Double?, signal: FeedingAdequacy.Signal) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    iconView(icon, tint: tint)
                    labelView(label)
                }
                statusView(value: value, signal: signal)
                    .multilineTextAlignment(.leading)
                    // Hangs under the label rather than under the icon, so the
                    // pair still reads as one row and not as two entries.
                    .padding(.leading, iconColumnWidth + BBTheme.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                iconView(icon, tint: tint)
                labelView(label)
                Spacer(minLength: BBTheme.Spacing.sm)
                statusView(value: value, signal: signal)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    /// Shared by both layouts so the two can never drift apart in anything but
    /// their arrangement.
    private var iconColumnWidth: CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: 20)
    }

    private func iconView(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                            weight: .regular, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: iconColumnWidth)
    }

    private func labelView(_ label: String) -> some View {
        Text(label)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body,
                                            weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusView(value: Double?, signal: FeedingAdequacy.Signal) -> some View {
        Text(statusText(value: value, signal: signal))
            .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                            weight: .semibold, design: .rounded))
            .foregroundStyle(color(for: signal))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A value is shown only when there IS one. `notEnoughData` must never
    /// render as "0 a day" — that would tell a parent their baby fed zero times
    /// when in truth they simply did not log.
    private func statusText(value: Double?, signal: FeedingAdequacy.Signal) -> String {
        let status: String
        switch signal {
        case .below:         status = "nutrition.status_below".l
        case .within:        status = "nutrition.status_within".l
        case .notEnoughData: return "nutrition.status_unknown".l
        }
        guard let value else { return status }
        return String(format: "nutrition.per_day_fmt".l, value.appRate) + " · " + status
    }

    private func color(for signal: FeedingAdequacy.Signal) -> Color {
        switch signal {
        case .below:         return BBTheme.Colors.accent
        case .within:        return BBTheme.Colors.success
        case .notEnoughData: return BBTheme.Colors.textSecondary
        }
    }
}

import SwiftUI

/// The free half of the feeding–weight feature: three signals, plainly stated.
///
/// Most of the time all three read "within the reference" and this section's
/// job is reassurance. Status is carried by a WORD, with colour as
/// reinforcement only, so the row survives greyscale and VoiceOver.
struct NutritionSection: View {
    let assessment: FeedingAdequacy.Assessment?

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
    @ViewBuilder
    private func row(icon: String, tint: Color, label: String,
                     value: Double?, signal: FeedingAdequacy.Signal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                                weight: .regular, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: UIFontMetrics(forTextStyle: .body).scaledValue(for: 20))
            Text(label)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body,
                                                weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: BBTheme.Spacing.sm)
            Text(statusText(value: value, signal: signal))
                .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                                weight: .semibold, design: .rounded))
                .foregroundStyle(color(for: signal))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
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

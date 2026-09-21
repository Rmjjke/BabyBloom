import SwiftUI

/// The WHO percentile card: the band label, the ring with its badge, and the
/// lines saying what the figure describes.
///
/// Lifted out of `GrowthView` so onboarding's showcase page can render the REAL
/// card instead of a lookalike — the same reason `WidgetShowcasePage` renders
/// the real widget view. Two hand-kept copies of a card that states a clinical
/// figure is exactly the drift this project has paid for before.
///
/// It carries no explainer and no tap of its own. `GrowthView` wraps it in an
/// `ExplainerCard`, which is what injects the "?" badge (`InfoBadge` draws only
/// inside that wrapper); the showcase page renders it bare, so the same view
/// cannot advertise an explanation that nothing there would open.
struct PercentileCard: View {
    /// Clamped 1–99, as `PercentileReading.percentile` gives it — the ring's
    /// fill and the band label both read this.
    let percentile: Double
    /// `PercentileReading.badge`: "> 97", "< 3", or the number.
    let badge: String
    /// What the figure describes, one line per entry. The Growth screen names
    /// the age it was scored at and the weighing's date; onboarding names the
    /// weight at birth. A list rather than two fields because these lines are
    /// one tight stack with its own spacing, and the count differs per caller.
    let captionLines: [String]
    var tone: Tone = .standard

    /// How far the card may go in colour.
    enum Tone {
        /// The Growth screen's own tinting, tails included.
        case standard
        /// Onboarding. A percentile below the 3rd or above the 97th takes the
        /// neutral tint instead of `BBAlert`.
        ///
        /// **Why the tails lose their red here and keep it on the Growth
        /// screen.** Nothing is hidden: the band LABEL still reads "< 3rd" in
        /// full, and the badge still says which side of the chart. What changes
        /// is the alarm. On the Growth screen a red reading sits beside its
        /// explainer, the chart, the history and the "raise this with someone
        /// qualified" copy that make it actionable. Three minutes into
        /// onboarding there is none of that — no history, no context, nobody to
        /// ask — and a parent who has just typed their newborn's discharge
        /// weight is the last person who should meet a red number. The tint is
        /// the same neutral `WeightVelocity.Band.above` already takes for the
        /// other "true, and not a worry" reading in this card family.
        case neutralOnly
    }

    private var color: Color {
        let tint = WHOGrowthStandard.percentileTint(percentile)
        if tone == .neutralOnly, tint == .beyond { return BBTheme.Colors.textPrimary }
        return tint.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            HStack {
                // The same title view every `InsightCard` header uses, so
                // this hand-built header carries the explainer to VoiceOver
                // exactly as the others do.
                InsightCardTitle("section.who_percentiles".l)
                Spacer()
                InfoBadge()
            }

            VStack(spacing: BBTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("percentile.weight".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                        BBTheme.Typography.metric(WHOGrowthStandard.percentileLabel(percentile))
                            .foregroundStyle(color)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 6)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: percentile / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                        Text(badge)
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(color)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(captionLines.indices, id: \.self) { index in
                        Text(captionLines[index])
                    }
                }
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.card)
        }
    }
}

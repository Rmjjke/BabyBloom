import SwiftUI

/// The WHO percentile card: the percentile as its figure, the ring that shows
/// where it sits, and the lines saying what the figure describes.
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
    /// fill and its tint read this.
    let percentile: Double
    /// `PercentileReading.badge`: "> 97", "< 3", or the number — the card's
    /// figure.
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
        /// screen.** Nothing is hidden: the figure still states the percentile
        /// («2», or «< 3» past the chart's edge). What changes is the alarm on
        /// the ring. On the Growth screen a red reading sits beside its
        /// explainer, the chart, the history and the "raise this with someone
        /// qualified" copy that make it actionable. Three minutes into
        /// onboarding there is none of that — no history, no context, nobody
        /// to ask — and a parent who has just typed their newborn's discharge
        /// weight is the last person who should meet a red mark. The tint is
        /// the same neutral `WeightVelocity.Band.above` already takes for the
        /// other "true, and not a worry" reading in this card family.
        case neutralOnly
    }

    private var ringColor: Color {
        let tint = WHOGrowthStandard.percentileTint(percentile)
        if tone == .neutralOnly, tint == .beyond { return BBTheme.Colors.textPrimary }
        return tint.color
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            // The header every `InsightCard` uses, so this hand-built card
            // carries the explainer to VoiceOver and sets its badge as the
            // others do.
            InsightCardHeader(title: "section.who_percentiles".l)

            VStack(spacing: BBTheme.Spacing.md) {
                // The label's column is everything the ring leaves, a fixed
                // width the label's size steps are chosen against.
                HStack(spacing: BBTheme.Spacing.sm) {
                    // The percentile itself, as the report prints it: a
                    // position on the chart, in the text colour, with no band
                    // word. One VoiceOver stop: «Weight Percentile, 61».
                    VStack(alignment: .leading, spacing: 4) {
                        PercentileLabel(text: "percentile.weight".l)
                        BBTheme.Typography.metric(badge)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The tier tint pictures where the reading sits; the figure
                    // beside it states it, so the ring is silent and needs no
                    // number of its own.
                    ZStack {
                        Circle()
                            .stroke(ringColor.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: percentile / 100)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
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

/// The label over the card's figure. It wraps between words at the reader's
/// size; only a word wider than its column beside the ring (de
/// «Gewichtsperzentile», fi «Painopersentiili» on a 320-pt screen at the
/// accessibility sizes) sets it a size smaller, from AX1's down to Large's,
/// the way `FeedingHint` steps. The column is narrow enough that one or two
/// steps would leave such a word broken.
struct PercentileLabel: View {
    let text: String
    /// The text size the label is set for; nil follows the device.
    var category: UIContentSizeCategory? = nil

    /// The sizes tried after the reader's own, largest first.
    static let steps: [UIContentSizeCategory] = [
        .accessibilityMedium, .extraExtraExtraLarge, .extraExtraLarge, .extraLarge, .large,
    ]

    var body: some View {
        // Each try's ideal width is its widest word's: a size is passed over
        // only when a word misses the column.
        ViewThatFits(in: .horizontal) {
            label(size: naturalSize)
            label(size: steppedSize(Self.steps[0]))
            label(size: steppedSize(Self.steps[1]))
            label(size: steppedSize(Self.steps[2]))
            label(size: steppedSize(Self.steps[3]))
            label(size: steppedSize(Self.steps[4]))
        }
    }

    private var naturalSize: CGFloat {
        BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: category)
    }

    private func steppedSize(_ step: UIContentSizeCategory) -> CGFloat {
        min(naturalSize, BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: step))
    }

    private func label(size: CGFloat) -> some View {
        WordWrappingText(text: text)
            .font(.system(size: size, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

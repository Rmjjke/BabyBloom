import SwiftUI

/// The free half of the feeding–weight feature: three signals, plainly stated.
///
/// Most of the time all three read "within the reference" and this section's
/// job is reassurance. Status is carried by a WORD, with colour as
/// reinforcement only, so the row survives greyscale and VoiceOver.
struct NutritionSection: View {
    let assessment: FeedingAdequacy.Assessment?
    /// The gain band over the same two weighings the assessment covers. Passed
    /// in rather than derived here so this stays a pure render, and required
    /// rather than defaulted so a new call site cannot silently reintroduce the
    /// contradiction it exists to fix — see `StatusWord`.
    let band: WeightVelocity.Band?
    /// Whether anything has been weighed at all — the same flag `WeightGainCard`
    /// takes, so the two empty states a screen apart give the same instruction
    /// ("one more weighing") rather than one asking for two and the other for
    /// one more. Required for the reason `band` is: a call site that got it
    /// wrong would state a requirement the parent has already met.
    let hasWeighing: Bool

    /// Drives the row layout only — never a font size. At an accessibility size
    /// the label and its status cannot share a line without one of them being
    /// proposed a width narrower than its own longest word, and SwiftUI answers
    /// that by breaking INSIDE the word. See `row(icon:tint:label:value:word:beside:)`.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        InsightCard(title: "section.nutrition".l) {
            if let assessment {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    Text(String(format: "nutrition.window_fmt".l,
                                assessment.windowDays, assessment.windowDays.dayWord).gluingNumbersToUnits)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                                        weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)

                    // One decision for the card: three rows of one shape read
                    // as a table, and a mix of the two would not.
                    if dynamicTypeSize.isAccessibilitySize {
                        rows(assessment, beside: false)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            rows(assessment, beside: true)
                            rows(assessment, beside: false)
                        }
                    }
                }
            } else {
                // The long form of the requirement, not the Dashboard's short
                // `nutrition.need_weighing`: this is the card seen to stay
                // empty while feedings and nappies were logged, so here — where
                // there is room and a button to press — it also says what those
                // two logs are counted over.
                //
                // "One more weighing" is phrased against the PREVIOUS one rather
                // than "a second, after the first", so it stays true for the
                // parent whose two weighings fall on the same day — also this
                // state, and the reason the count word cannot simply be
                // decremented.
                HintWithAddWeighing(text: hasWeighing ? "nutrition.need_next_weighing".l
                                                      : "nutrition.need_weighing_detail".l)
            }
        }
    }

    private func rows(_ assessment: FeedingAdequacy.Assessment, beside: Bool) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            // The gain row shows STATUS ONLY. Grams per week stay in the
            // Premium WeightGainCard, where they already are.
            row(icon: "chart.line.uptrend.xyaxis", tint: BBTheme.Colors.growth,
                label: "nutrition.row_gain".l, value: nil,
                word: StatusWord.of(assessment.gain, band: band), beside: beside)
            row(icon: "heart.fill", tint: BBTheme.Colors.feeding,
                label: "nutrition.row_feeds".l,
                value: assessment.feedingsPerDay,
                word: StatusWord.of(assessment.feeding, band: nil), beside: beside)
            row(icon: "drop.fill", tint: BBTheme.Colors.diaper,
                label: "nutrition.row_nappies".l,
                value: assessment.wetNappiesPerDay,
                word: StatusWord.of(assessment.nappies, band: nil), beside: beside)
        }
    }

    /// The icon scales off `.body` exactly as the label beside it does, and its
    /// column follows — a fixed 14pt glyph in a fixed 20pt slot sits beside a
    /// label that roughly doubles at the AX2 cap, and the row falls apart.
    /// Sized through `BBTheme.Typography.scaledPointSize` rather than
    /// `@ScaledMetric` or a bare `UIFontMetrics` so the width obeys the same
    /// rule as `BBTheme.Typography.scaled`, which is what sizes the text: two
    /// mechanisms would disagree wherever the environment overrides the size.
    /// A bare `UIFontMetrics.scaledValue(for:)` here is not a smaller version
    /// of that — it is the same defect: it reads the DEVICE content size and
    /// walks straight past the app's AX2 ceiling, so above AX2 the column kept
    /// growing while the label it is sized for had stopped.
    ///
    /// **Two layouts, and the second one is not decoration.** Side by side, the
    /// label and its status divide one row's width between them; where that
    /// leaves either a column narrower than its own longest word, SwiftUI's
    /// only answer is to break inside the word. Renders showed exactly that —
    /// "Прибавк / а", "Кормлен / ия" at AX2, «в предел / ах» and «сутк / и» on
    /// a 320-pt screen at xxxLarge, and at xxLarge with Bold Text. So the
    /// status moves onto its own line under the label, where each gets the
    /// full width of the card and breaks between words like prose: at every
    /// accessibility size, and below them wherever a word of any row would
    /// miss its column beside (`SideBySideIdeal`).
    ///
    /// **One VoiceOver stop per row, in both layouts.** A label and its status
    /// are one statement — "Weight gain, below the reference" — and swiping
    /// through them separately breaks it in half, with the icon announcing a
    /// third, meaningless stop in between (`iconView` hides itself for that
    /// reason). `.combine` also keeps the two layouts identical to a VoiceOver
    /// user, who cannot see that the status has moved onto its own line.
    @ViewBuilder
    private func row(icon: String, tint: Color, label: String,
                     value: Double?, word: StatusWord, beside: Bool) -> some View {
        let status = Self.statusText(value: value, word: word)
        if beside {
            // The hidden copies measure the two texts in their own fonts: whole,
            // and one word a line. The status copy takes the drawn alignment
            // too: wrapped flush right, a text reports a space wider.
            SideBySideIdeal(chrome: iconColumnWidth + 4 * BBTheme.Spacing.sm) {
                Group {
                    labelView(label)
                    labelView(label.oneWordALine)
                    statusView(status, word: word)
                        .multilineTextAlignment(.trailing)
                    statusView(status.oneWordALine, word: word)
                }
                .hidden()
                .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    iconView(icon, tint: tint)
                    labelView(label)
                    Spacer(minLength: BBTheme.Spacing.sm)
                    statusView(status, word: word)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    iconView(icon, tint: tint)
                    labelView(label)
                }
                statusView(status, word: word)
                    .multilineTextAlignment(.leading)
                    // Hangs under the label rather than under the icon, so the
                    // pair still reads as one row and not as two entries.
                    .padding(.leading, iconColumnWidth + BBTheme.Spacing.sm)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    /// Shared by both layouts so the two can never drift apart in anything but
    /// their arrangement.
    private var iconColumnWidth: CGFloat {
        BBTheme.Typography.scaledPointSize(20, relativeTo: .body)
    }

    /// Hidden from VoiceOver: the glyph carries no information the label does
    /// not, and without this the combined row opens by reading out the SF
    /// Symbol name ("chart line uptrend xyaxis") before the words that matter.
    private func iconView(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                            weight: .regular, design: .rounded))
            .foregroundStyle(tint)
            .frame(width: iconColumnWidth)
            .accessibilityHidden(true)
    }

    private func labelView(_ label: String) -> some View {
        Text(label)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body,
                                            weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func statusView(_ text: String, word: StatusWord) -> some View {
        BBTierValue(text: text, dot: word.dot, ink: word.ink, size: 13, style: .caption1)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A value is shown only when there IS one. `notEnoughData` must never
    /// render as "0 a day" — that would tell a parent their baby fed zero times
    /// when in truth they simply did not log.
    static func statusText(value: Double?, word: StatusWord) -> String {
        let status = word.localizationKey.l
        // `notEnoughData` carries no figure by construction, so the guard below
        // covers it; spelling it out again would be a second rule to keep.
        guard let value else { return status }
        return String(format: "nutrition.per_day_fmt".l, value.appRate).gluingNumbersToUnits + " · " + status
    }
}

/// A verdict's colours, here and on Home's growth card: the words in the text
/// colour, the tier on the dot before them (`BBTierValue`). Colour reinforces
/// the word and never carries it, and none of it is red.
extension StatusWord {
    var ink: Color {
        switch self {
        case .below, .within, .above: return BBTheme.Colors.textPrimary
        // A deferral is not a verdict, so it takes the same quiet ink the
        // "we cannot say yet" state does.
        case .notEnoughData, .firstWeeks: return BBTheme.Colors.textSecondary
        }
    }

    /// `.above` has none, matching `WeightGainCard`: gaining faster than the
    /// reference is neither a worry nor a tick.
    var dot: Color? {
        switch self {
        case .below:  return BBTheme.Colors.accent
        case .within: return BBTheme.Colors.success
        case .above, .notEnoughData, .firstWeeks: return nil
        }
    }
}

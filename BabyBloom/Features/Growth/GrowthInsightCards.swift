import SwiftUI

// MARK: - Shared chrome

/// The card shell every insight block sits in, so they read as one family.
struct InsightCard<Content: View>: View {
    let title: String
    /// Whether the header's "?" is a control of its own — see `InfoBadgeRole`.
    /// The default covers both cards with no explainer at all and cards an
    /// `ExplainerCard` wraps, which is why it needs no argument at either kind
    /// of call site: the badge decides for itself whether it exists.
    var info: InfoBadgeRole = .none
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    private var header: some View {
        HStack {
            BBTheme.Typography.title3(title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            badge
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch info {
        case .none:
            // Draws itself only when an `ExplainerCard` is wrapping this card,
            // so a card can never advertise an explanation that is not there.
            InfoBadge()
        case let .control(explainer, action):
            Button(action: action) {
                InfoBadge.glyph
                    .frame(width: InfoBadge.hitTarget, height: InfoBadge.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The negative padding takes the oversized target back out of the
            // LAYOUT, so the header row keeps the height a 20pt glyph gives it.
            // Hit-testing is unaffected: it reads the button's own 44pt frame,
            // and no ancestor here clips, so the target that overhangs the row
            // still answers taps — which is the whole point, since a miss lands
            // on the sell button underneath.
            .padding(-InfoBadge.hitOverhang)
            // Dead to VoiceOver — the enclosing Button flattens its label into
            // one element — but XCUITest still matches it, which is how the
            // free-state run-and-look taps the badge. The reachable way in is
            // the named accessibility action on the card itself.
            .accessibilityLabel(Text("explainer.action".l))
        }
    }
}

/// Whether a card's "?" is a control of its own.
enum InfoBadgeRole {
    /// The card has no explainer of its own, or the card AS A WHOLE is the way
    /// into one (`ExplainerCard`), in which case the badge is only the
    /// affordance that says so and draws itself from the environment.
    case none
    /// Its own control. The card's tap is already spoken for — a locked card
    /// sells Premium — so the badge is the only way into the explainer, and it
    /// must not eat the sell tap.
    case control(GrowthExplainer, action: () -> Void)
}

/// The "?" affordance, drawn ONLY inside an `ExplainerCard`.
///
/// The badge is injected rather than drawn on request: a card that renders one
/// unconditionally advertises an explainer whether or not anything opens it,
/// which is what the render dumps showed — a dead "?" on every card dumped
/// outside `GrowthView`.
struct InfoBadge: View {
    @Environment(\.hasExplainer) private var hasExplainer

    /// Apple's minimum touch target. The glyph stays 20pt.
    static let glyphSize: CGFloat = 20
    static let hitTarget: CGFloat = 44
    static var hitOverhang: CGFloat { (hitTarget - glyphSize) / 2 }

    static var glyph: some View {
        Image(systemName: "questionmark.circle.fill")
            .font(.system(size: glyphSize))
            .foregroundStyle(BBTheme.Colors.primary.opacity(0.7))
    }

    var body: some View {
        if hasExplainer {
            // Decoration: the card around it is the control, and announcing an
            // unlabelled image before the card's own words helps nobody.
            Self.glyph.accessibilityHidden(true)
        }
    }
}

private struct HasExplainerKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by `ExplainerCard` for everything inside it.
    var hasExplainer: Bool {
        get { self[HasExplainerKey.self] }
        set { self[HasExplainerKey.self] = newValue }
    }
}

// MARK: - Explainers

/// A subject a "?" badge can explain. One sheet, five subjects.
///
/// The percentile card had the only explainer on this screen and its own sheet
/// type; build-12 feedback was that the other verdict cards say a couple of
/// words a parent cannot decode either. Five sheet types would be five things
/// to keep looking alike, so the subject became data and the sheet is one view.
enum GrowthExplainer {
    case newborn
    case percentile
    case gain
    case trend
    case nutrition

    /// Copy keys follow each card's OWN key family — the gain card's strings
    /// are `velocity.*`, so its explainer is `velocity.info_*`. A separate
    /// `growth.info.*` family would scatter one card's copy over two places in
    /// six JSON files.
    private var keyPrefix: String {
        switch self {
        case .newborn:    "newborn"
        case .percentile: "percentile"
        case .gain:       "velocity"
        case .trend:      "trend"
        case .nutrition:  "nutrition"
        }
    }

    var titleKey: String { "\(keyPrefix).info_title" }
    var bodyKey: String { "\(keyPrefix).info_body" }

    var icon: String {
        switch self {
        case .newborn:    "heart.text.square.fill"
        case .percentile: "chart.bar.xaxis"
        case .gain:       "scalemass.fill"
        case .trend:      "chart.line.uptrend.xyaxis"
        case .nutrition:  "heart.fill"
        }
    }

    /// The tint of the card the explainer belongs to, so the sheet reads as
    /// that card opening up rather than as a generic help screen.
    var tint: Color {
        switch self {
        case .newborn:           BBTheme.Colors.success
        case .percentile, .gain: BBTheme.Colors.growth
        case .trend:             BBTheme.Colors.primary
        case .nutrition:         BBTheme.Colors.feeding
        }
    }
}

/// The explainer sheet: icon, title, copy, «Закрыть» — the shape the percentile
/// explainer shipped with, now shared by every subject.
struct ExplainerSheet: View {
    let explainer: GrowthExplainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
                    Image(systemName: explainer.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(explainer.tint)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, BBTheme.Spacing.lg)

                    BBTheme.Typography.title2(explainer.titleKey.l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)

                    // One string, whatever shape the copy is: blank lines
                    // between paragraphs everywhere, plus "• " bullets typed
                    // into the middle of `percentile.info_body`. The layout
                    // assumes neither, so a translator can re-shape a body
                    // without a view change.
                    Text(explainer.bodyKey.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .lineSpacing(4)

                    Spacer()
                }
                .padding(BBTheme.Spacing.lg)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.close".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }
}

/// Makes a whole card open its explainer, and injects the "?" that says so.
///
/// The WHOLE card is the control, not just the "?" glyph. A 20pt badge in the
/// corner was the only way in, and the owner reported tapping the percentile
/// card and getting nothing (build-11 review). The badge stays as the
/// AFFORDANCE, not a control of its own: a button inside a button gives two hit
/// targets that do the same thing. Cards whose tap already sells Premium use
/// `InfoBadgeRole.control` instead.
///
/// **A tap gesture, not a Button, and that is the whole design.** A Button
/// flattens its label into ONE accessibility element, which would silently
/// destroy the per-row VoiceOver structure `NutritionSection` builds on purpose
/// — three rows, one stop each, the label and its status read as one statement.
/// A `contentShape` plus `onTapGesture` leaves the children exactly as the card
/// built them, and the explainer stays reachable without sight through the
/// named accessibility action, which propagates to those same children. The
/// cost is the press bounce a `BBScaleButtonStyle` gave: a press animation here
/// would need a `DragGesture(minimumDistance: 0)`, and that gesture inside a
/// `ScrollView` fights the scroll. A card is not a button-shaped control, so
/// the plain tap is the honest trade.
struct ExplainerCard<Content: View>: View {
    let explainer: GrowthExplainer
    @ViewBuilder var content: Content
    @State private var isPresented = false

    var body: some View {
        content
            .environment(\.hasExplainer, true)
            // A card header's Spacer is empty space, and empty space does not
            // answer taps without this.
            .contentShape(Rectangle())
            .onTapGesture { isPresented = true }
            .accessibilityAction(named: Text("explainer.action".l)) {
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                ExplainerSheet(explainer: explainer)
            }
    }
}

/// Neutral note for "not enough data yet" states. These are not failures and
/// must not look like them — a parent who has weighed once is doing fine.
struct HintText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The tint for a percentile, from the tier `WHOGrowthStandard` puts it in.
///
/// The mapping lives here rather than in Core because these are `BBTheme`
/// tokens and Core imports no SwiftUI. It replaced three hex literals that had
/// no dark variant and sat on the same screen as the tokenized greens below.
extension WHOGrowthStandard.PercentileTint {
    var color: Color {
        switch self {
        case .typical: return BBTheme.Colors.success
        case .edge:    return BBTheme.Colors.accent
        case .beyond:  return BBTheme.Colors.alert
        }
    }
}

/// A thing worth raising with a doctor. Never a diagnosis, always an invitation
/// to ask someone qualified.
private struct FlagRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(BBTheme.Colors.alert)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BBTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BBTheme.Colors.alert.opacity(0.10))
        .cornerRadius(BBTheme.Radius.md)
    }
}

// MARK: - First weeks

/// Birth-weight recovery, shown only while it is the question that matters.
///
/// Free for everyone, including the flags. Putting a "your baby may be losing
/// too much weight" warning behind a paywall would be indefensible.
struct NewbornProgressCard: View {
    let status: NewbornWeightLoss.Status

    var body: some View {
        InsightCard(title: "section.first_weeks".l) {
            Text(String(format: "newborn.day_fmt".l, status.dayOfLife))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)

            if let percent = status.percentOfBirthWeight {
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.metric(String(format: "newborn.percent_fmt".l, Int(percent.rounded())))
                        .foregroundStyle(status.hasRegained ? BBTheme.Colors.success : BBTheme.Colors.textPrimary)
                    Spacer()
                    if status.hasRegained {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(BBTheme.Colors.success)
                    }
                }

                Text(status.hasRegained ? "newborn.regained".l : "newborn.not_regained".l)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            } else {
                HintText(text: "newborn.needs_weighing".l)
            }

            ForEach(status.flags, id: \.self) { flag in
                FlagRow(text: flag == .lossExceeds10Percent
                        ? "newborn.flag_loss".l
                        : "newborn.flag_not_regained".l)
            }
        }
    }
}

extension NewbornWeightLoss.Flag: Hashable {}

// MARK: - Weight gain

struct WeightGainCard: View {
    let reading: WeightVelocity.Reading?

    var body: some View {
        InsightCard(title: "section.weight_gain".l) {
            guardedContent
        }
    }

    @ViewBuilder
    private var guardedContent: some View {
        if let reading {
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                BBTheme.Typography.metric(
                    String(format: "velocity.per_week_fmt".l, formatted(reading.gramsPerWeek))
                )
                .foregroundStyle(color(for: reading.band))
                Spacer()
                Text(String(format: "velocity.interval_fmt".l, reading.intervalDays))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            if let band = reading.band, let expected = reading.expectedPerWeek {
                Text(label(for: band))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(color(for: band))
                Text(String(format: "velocity.expected_fmt".l,
                            Int(expected.lowerBound.rounded()), Int(expected.upperBound.rounded())))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            } else {
                HintText(text: "velocity.no_reference".l)
            }
        } else {
            HintText(text: "velocity.needs_two".l)
        }
    }

    /// Signed, so a week of loss reads unmistakably as loss.
    private func formatted(_ gramsPerWeek: Double) -> String {
        let rounded = Int(gramsPerWeek.rounded())
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func label(for band: WeightVelocity.Band?) -> String {
        switch band {
        case .below:  return "velocity.below".l
        case .within: return "velocity.within".l
        case .above:  return "velocity.above".l
        case nil:     return ""
        }
    }

    /// Only "below" is tinted as something to look at. A baby gaining fast is
    /// not a problem to flag in an app.
    ///
    /// Both tints are TOKENS, not the `#F5A45F` and `#6BBF6B` literals this card
    /// shipped with. `NutritionSection` says the same words a couple of hundred
    /// points further down the same screen, and a render of the two stacked
    /// showed them as two different designs rather than one — the literals have
    /// no dark variant, so dark mode widened the gap instead of closing it.
    /// "Below" moved first; "within" followed once the stacked render made the
    /// remaining mint-versus-green mismatch impossible to argue for.
    private func color(for band: WeightVelocity.Band?) -> Color {
        switch band {
        case .below:  return BBTheme.Colors.accent
        case .within: return BBTheme.Colors.success
        case .above:  return BBTheme.Colors.textPrimary
        case nil:     return BBTheme.Colors.textPrimary
        }
    }
}

// MARK: - Centile trend

struct CentileTrendCard: View {
    let assessment: GrowthTrend.Assessment

    var body: some View {
        InsightCard(title: "section.trend".l) {
            switch assessment {
            case .insufficientData:
                HintText(text: "trend.insufficient".l)
            case .stable:
                HStack(spacing: BBTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BBTheme.Colors.success)
                    Text("trend.stable".l)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
            case let .sustainedDrop(spaces):
                FlagRow(text: String(format: "trend.drop_fmt".l, String(format: "%.1f", spaces)))
            case .crossingUp:
                // Neutral by design: an upward crossing is a fact, not a
                // finding. No tick — that belongs to `.stable` — and none of
                // `FlagRow`'s alarm chrome either.
                HStack(spacing: BBTheme.Spacing.sm) {
                    Image(systemName: "arrow.up.right")
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                    Text("trend.crossing_up".l)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Percentile out of range

/// Past 24 months the WHO weight-for-age tables run out. Saying so is the honest
/// alternative to the old behaviour, which read an older child off the 24-month
/// row and presented the result as fact.
struct PercentileOutOfRangeCard: View {
    var body: some View {
        InsightCard(title: "section.who_percentiles".l) {
            HintText(text: "percentile.out_of_range".l)
        }
    }
}

// MARK: - Premium gate

/// Stands in for a Premium-only card. Says what the block would tell them
/// without showing the number itself.
struct LockedInsightCard: View {
    let title: String
    let teaser: String
    /// The explainer behind the "?" badge, for sections that have one. Left nil
    /// where the card has nothing to explain beyond its own teaser.
    var explainer: GrowthExplainer? = nil
    let onUnlock: () -> Void

    @State private var showExplainer = false

    /// The card's tap SELLS, and that must survive: an explainer that ate the
    /// sell tap would trade the paywall for a help sheet. So the badge is its
    /// own button inside the card rather than the card itself being the way in
    /// — the opposite of `ExplainerCard`, for the opposite reason.
    private var badge: InfoBadgeRole {
        guard let explainer else { return .none }
        return .control(explainer) { showExplainer = true }
    }

    var body: some View {
        Button(action: sell) {
            InsightCard(title: title, info: badge) {
                HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(BBTheme.Colors.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(teaser)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        Text("premium.locked_hint".l)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.primary)
                    }
                }
            }
        }
        .buttonStyle(BBScaleButtonStyle())
        // VoiceOver reads this card as ONE button whose activation sells —
        // which is right, that is what the card is for — and the badge inside
        // the label is not an element of its own there. So the explainer gets
        // a named action on the card itself; without it the copy behind the "?"
        // is reachable by sighted taps only.
        .accessibilityActions {
            if explainer != nil {
                Button("explainer.action".l) { showExplainer = true }
            }
        }
        .sheet(isPresented: $showExplainer) {
            if let explainer {
                ExplainerSheet(explainer: explainer)
            }
        }
    }

    /// A tap on the badge is answered by the badge: a child's gesture wins over
    /// its ancestor's, so this action does not run at all. The guard is for the
    /// case that arrangement stops holding — selling on top of a sheet that is
    /// already on its way up is the double activation, and it is worth one
    /// line to make it impossible rather than merely unobserved. `showExplainer`
    /// is the flag AND the sheet's binding, so it cannot go stale: dismissing
    /// the sheet clears it.
    private func sell() {
        guard !showExplainer else { return }
        onUnlock()
    }
}

// MARK: - Corrected age

/// Shown only for a baby born preterm, next to anything compared against a
/// reference — otherwise the numbers look wrong to a parent who knows their
/// child's actual age.
struct CorrectedAgeChip: View {
    let description: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
            Text(String(format: "growth.corrected_age_fmt".l, description))
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(BBTheme.Colors.primary)
        .padding(.horizontal, BBTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background(BBTheme.Colors.primary.opacity(0.12))
        .cornerRadius(BBTheme.Radius.sm)
    }
}

/// The line that keeps every number on this screen in its place.
struct WHOFootnote: View {
    var body: some View {
        Text("growth.who_footnote".l)
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

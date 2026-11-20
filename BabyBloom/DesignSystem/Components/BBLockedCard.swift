import SwiftUI

/// Stands in for a Premium-only block: a lock, what the block would tell, and
/// that Premium has it — never the figures, and never a sketch of them (no
/// grey bars, no empty frame, no spinner), so nothing reads as broken or
/// loading. The calm tint is the card itself; nothing in it is red.
///
/// With a `title` it carries the insight-card header (Growth, Home); without
/// one it is the lock row alone in the same shell, for a place whose section
/// header above already names the block (the trackers' weekly charts).
struct BBLockedCard: View {
    var title: String? = nil
    /// The explainer behind the "?" badge, for sections that have one. Left nil
    /// where the card has nothing to explain beyond its own teaser.
    var explainer: GrowthExplainer? = nil
    /// Why the block is locked now when it was not before; above the teaser.
    var reason: String? = nil
    let teaser: String
    let onUnlock: () -> Void

    @State private var showExplainer = false

    /// The card's tap SELLS, and that must survive: an explainer that ate the
    /// sell tap would trade the paywall for a help sheet. So the badge is its
    /// own button inside the card rather than the card itself being the way in
    /// — the opposite of `ExplainerCard`, for the opposite reason.
    private var badge: InfoBadgeRole {
        guard explainer != nil else { return .none }
        return .control { showExplainer = true }
    }

    var body: some View {
        Button(action: sell) {
            if let title {
                InsightCard(title: title, info: badge) { lockRow }
            } else {
                lockRow.insightCardShell()
            }
        }
        .buttonStyle(BBScaleButtonStyle())
        // VoiceOver reads this card as ONE button whose activation sells, and
        // the badge inside it is not an element of its own there. The label is
        // set rather than gathered so it holds the words only — the title is
        // read by the header before the card, or by the card's own header row.
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("premium.opens_a11y_hint".l)
        // Without this the copy behind the "?" is reachable by sighted taps only.
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

    private var lockRow: some View {
        HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: BBTheme.Typography.scaledPointSize(15, relativeTo: .footnote)))
                .foregroundStyle(BBTheme.Colors.primary)
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                if let reason {
                    line(reason, weight: .regular, color: BBTheme.Colors.textPrimary)
                }
                line(teaser, weight: .regular, color: BBTheme.Colors.textSecondary)
                line("premium.locked_hint".l, weight: .semibold, color: BBTheme.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ text: String, weight: Font.Weight, color: Color) -> some View {
        Text(text)
            .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: weight))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if let title { parts.append(title) }
        if let reason { parts.append(reason) }
        parts += [teaser, "premium.locked_hint".l]
        return Self.sentences(parts)
    }

    /// Each part closed as a sentence, so VoiceOver pauses between them; a
    /// part that already ends in a stop (the reason does) gets no second one.
    static func sentences(_ parts: [String]) -> String {
        let stops: Set<Character> = [".", "!", "?", "…", "。", "！", "？"]
        return parts.map { part in
            guard let last = part.last, !stops.contains(last) else { return part }
            return part + "."
        }.joined(separator: " ")
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

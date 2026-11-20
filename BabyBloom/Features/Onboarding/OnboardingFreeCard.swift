import SwiftUI

/// What is free and what Premium adds, said once on onboarding's last page.
///
/// Fixed strings on purpose: the card reads none of the quiz answers, so every
/// branch through the quiz (weight unknown, notifications declined, formula)
/// ends on the same card. No icons, checks, lock or price: it informs, it does
/// not sell, and the paid half is set quieter than the free half.
struct OnboardingFreeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            block(label: "onboarding.widget.free_label".l,
                  list: "onboarding.widget.free_list".l,
                  listColor: BBTheme.Colors.textPrimary)
            block(label: "onboarding.widget.premium_label".l,
                  list: "onboarding.widget.premium_list".l,
                  listColor: BBTheme.Colors.textSecondary)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: BBTheme.Radius.lg, style: .continuous))
        .bbShadow(BBTheme.Shadow.card)
    }

    /// One VoiceOver element per block, read as "Free. Feeds, sleep…"; the card
    /// itself is not an element.
    private func block(label: String, list: String, listColor: Color) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
            Text(label)
                .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
            Text(list)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                .foregroundStyle(listColor)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

// MARK: - Typed step

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case name
    case birth
    case feeding
    case growth
    case fact
    case growthShowcase
    case notifications
    case widgets
    case generating
    case premium

    /// Quiz pages show the progress bar and bottom nav. The five info pages
    /// that follow Growth — fact, growthShowcase, notifications, widgets,
    /// generating, and NOT the paywall, which is a sell rather than an info
    /// page — are not quiz pages, so neither the bar nor `quizProgress`'s
    /// denominator moves when the flow grows or is reordered.
    var isQuiz: Bool {
        switch self {
        case .name, .birth, .feeding, .growth: return true
        default: return false
        }
    }

    /// Goal Gradient Effect: front-loaded progress across the quiz pages.
    var quizProgress: Double {
        switch self {
        case .name:    return 0.22
        case .birth:   return 0.50
        case .feeding: return 0.78
        case .growth:  return 1.0
        default:       return 0
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

// MARK: - Helpers

/// Onboarding page hero: a themed SF Symbol inside a soft category-colored
/// circle. Replaces the previous emoji heroes, which rendered as tofu "?"
/// squares on the simulator.
func onboardingHeroIcon(_ systemName: String, color: Color) -> some View {
    Image(systemName: systemName)
        .font(.system(size: 56, weight: .medium))
        .foregroundStyle(color)
        .frame(width: 120, height: 120)
        .background(color.opacity(0.22), in: Circle())
}

/// The bullet card of the info pages: one shape for all its rows, each text
/// beside its icon while every word fits there, else each text under its
/// icon, so a long word (ru «бодрствования», de «Gewichtszunahme») on a
/// 320-pt screen at the accessibility sizes is never broken.
struct OnboardingBulletList: View {
    let bullets: [(icon: String, text: String)]
    let tint: Color
    let badgeOpacity: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rows(stacked: false)
            rows(stacked: true)
        }
        .padding(BBTheme.Spacing.lg)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    /// Beside, each text's ideal width is its widest word's, so the stack's
    /// is its widest word's beside the icon: the width the ViewThatFits compares.
    private func rows(stacked: Bool) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                let icon = Image(systemName: bullet.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(badgeOpacity), in: Circle())
                if stacked {
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        icon
                        styled(Text(bullet.text))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
                        icon
                        styled(WordWrappingText(text: bullet.text))
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func styled(_ text: some View) -> some View {
        text
            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Vertically centred content that falls back to scrolling. Pages built on
/// bare Spacers squeeze their texts at large type sizes and truncate the
/// question; a scroll view lets the title take the height it needs.
func onboardingCenteredScroll<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
    GeometryReader { geo in
        ScrollView(showsIndicators: false) {
            content()
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

func backButton(action: @escaping () -> Void) -> some View {
    HStack {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("button.back".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(.leading, BBTheme.Spacing.lg)
        .padding(.top, 12)
        Spacer()
    }
}

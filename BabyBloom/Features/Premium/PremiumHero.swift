import SwiftUI

// MARK: - Premium Hero

/// The gradient masthead both paywalls wear.
///
/// Extracted for the same reason `PlanPickerSection` was: two hand-written
/// copies of the same header had already drifted (different heights, different
/// headline sizes), and the owner's build-9 review asked for one visual
/// language across both entry points.
///
/// It sizes itself from its content instead of carrying a fixed height. The
/// old fixed 220–240pt box was mostly empty gradient, and on a Pro Max it
/// pushed the subscribe button below the fold. A content-sized band is also
/// the only version that survives Dynamic Type and a wrapping ru/es headline
/// without clipping against `cornerRadius`.
struct PremiumHero: View {
    /// Onboarding's paywall owns the whole screen, so its gradient bleeds up
    /// behind the status bar. The settings paywall sits under a navigation
    /// bar, where bleeding would slide the band under the title.
    var bleedsIntoStatusBar: Bool = false
    /// Onboarding pops the badge in with the rest of the page; the settings
    /// paywall has no entrance animation and leaves this at 1.
    var badgeScale: CGFloat = 1

    var body: some View {
        ZStack {
            gradient

            VStack(spacing: BBTheme.Spacing.sm) {
                BrandMark(diameter: 52, onGradient: true)
                    .scaleEffect(badgeScale)

                BBTheme.Typography.title1("onboarding.premium.title".l)
                    .foregroundStyle(.white)

                Text("onboarding.premium.headline".l)
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.vertical, BBTheme.Spacing.md)
        }
        .cornerRadius(BBTheme.Radius.xl, corners: [.bottomLeft, .bottomRight])
    }

    // The bleed cannot be a modifier applied conditionally to the ZStack: it
    // must stay on the gradient alone, or the text would ride up under the
    // status bar with it.
    @ViewBuilder
    private var gradient: some View {
        if bleedsIntoStatusBar {
            BBTheme.Colors.premiumGradient.ignoresSafeArea(edges: .top)
        } else {
            BBTheme.Colors.premiumGradient
        }
    }
}

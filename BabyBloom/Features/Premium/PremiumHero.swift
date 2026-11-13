import SwiftUI

// MARK: - Premium Hero

/// The gradient masthead both paywalls wear.
///
/// Extracted for the same reason `PlanPickerSection` was: two hand-written
/// copies of the same header had already drifted (different heights, different
/// headline sizes), and the build-9 review asked for one visual
/// language across both entry points.
///
/// It sizes itself from its content instead of carrying a fixed height. The
/// old fixed 220–240pt box was mostly empty gradient, and on a Pro Max it
/// pushed the subscribe button below the fold. A content-sized band is also
/// the only version that survives Dynamic Type and a wrapping ru/es headline
/// without clipping against `cornerRadius`.
struct PremiumHero: View {
    /// Onboarding pops the badge in with the rest of the page; the settings
    /// paywall has no entrance animation and leaves this at 1.
    var badgeScale: CGFloat = 1

    var body: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            BrandMark(diameter: 52, onGradient: true)
                .scaleEffect(badgeScale)

            title

            Text("onboarding.premium.headline".l)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
        .padding(.vertical, BBTheme.Spacing.md)
        .frame(maxWidth: .infinity)
        // A background, not a ZStack layer: beside the greedy gradient the
        // stack was proposed less than its ideal height, and the title, the
        // one text that gives way, fell to a single cut line at AX2. The
        // closure form keeps the gradient inside the band; the style form
        // runs it under the status and navigation bars.
        .background { BBTheme.Colors.premiumGradient }
        .cornerRadius(BBTheme.Radius.xl, corners: [.bottomLeft, .bottomRight])
    }

    /// Breaks between words, never inside one: steps from title1 to title2
    /// and title3 while its widest word misses the line, as `BBScreenHeading`
    /// does, and keeps every line it needs.
    private var title: some View {
        BBSteppedTitle("onboarding.premium.title".l)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

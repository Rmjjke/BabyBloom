import SwiftUI

// MARK: - Welcome (page 1 of 11)

struct WelcomePage: View {
    let onStart: () -> Void
    @State private var appear = false

    private var features: [(icon: String, color: Color, key: String, delay: Double)] {
        [
            ("heart.fill", BBTheme.Colors.feeding, "onboarding.feature.feeding", 0.15),
            ("moon.fill", BBTheme.Colors.sleep, "onboarding.feature.sleep", 0.25),
            ("chart.line.uptrend.xyaxis", BBTheme.Colors.growth, "onboarding.feature.growth", 0.35),
            ("drop.fill", BBTheme.Colors.diaper, "nav.diapers", 0.45),
        ]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero — the blobs behind it belong to OnboardingBackground now,
                // shared by every page instead of stopping at this one.
                ZStack {
                    VStack(spacing: BBTheme.Spacing.md) {
                        BrandMark(diameter: 96)
                            .scaleEffect(appear ? 1 : 0.6)
                            .opacity(appear ? 1 : 0)

                        VStack(spacing: 6) {
                            Text("brand.name".l)
                                .font(.system(size: 40, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.primary)
                                .offset(y: appear ? 0 : 20)
                                .opacity(appear ? 1 : 0)

                            Text("onboarding.tagline".l)
                                .font(BBTheme.Typography.scaled(18, relativeTo: .body, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .offset(y: appear ? 0 : 20)
                                .opacity(appear ? 1 : 0)
                        }
                    }
                }
                .frame(height: 320)

                // Feature cards: one shape for all four, beside while every
                // title's words fit beside the icon.
                ViewThatFits(in: .horizontal) {
                    featureCards(.beside)
                    featureCards(.stacked)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, BBTheme.Spacing.xl)

                // CTA
                BBPrimaryButton("button.start".l, icon: "arrow.right") {
                    onStart()
                }
                .accessibilityIdentifier("onboarding.next")
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 40)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                appear = true
            }
        }
    }

    /// A stack's ideal width is its widest card's, so the beside form fits
    /// only where every card's does.
    private func featureCards(_ shape: WelcomeFeatureCard.Shape) -> some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            ForEach(features, id: \.key) { feature in
                WelcomeFeatureCard(icon: feature.icon,
                                   color: feature.color,
                                   title: feature.key.l,
                                   delay: feature.delay,
                                   shape: shape)
            }
        }
    }
}

/// A Text breaks inside a word only when the word alone is wider than its
/// column. Beside the 42-pt icon and the check, a Russian title's word
/// («кормлений») was that on a 320-pt screen at the accessibility sizes, so
/// there the page sets every title under its icon instead.
private struct WelcomeFeatureCard: View {
    enum Shape { case beside, stacked }

    let icon: String
    let color: Color
    let title: String
    let delay: Double
    let shape: Shape
    @State private var appear = false

    private var badge: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 42, height: 42)
            .background(color.opacity(0.12))
            .cornerRadius(12)
    }

    private var check: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(color.opacity(0.7))
            .font(.system(size: 18))
    }

    private func styled(_ label: some View) -> some View {
        label
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        Group {
            switch shape {
            case .beside:
                // The title's ideal width is its widest word's: the width the
                // page's ViewThatFits compares.
                HStack(spacing: BBTheme.Spacing.md) {
                    badge
                    styled(WordWrappingText(text: title))
                    Spacer()
                    check
                }
            case .stacked:
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    HStack {
                        badge
                        Spacer()
                        check
                    }
                    styled(Text(title))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
        .offset(x: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                appear = true
            }
        }
    }
}

import SwiftUI

// MARK: - Page 0: Welcome

struct WelcomePage: View {
    let onStart: () -> Void
    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero
                ZStack {
                    // Background blobs
                    Circle()
                        .fill(BBTheme.Colors.primary.opacity(0.12))
                        .frame(width: 340, height: 340)
                        .offset(x: 40, y: -20)
                        .blur(radius: 30)
                    Circle()
                        .fill(Color(hex: "#E8A0BF").opacity(0.18))
                        .frame(width: 220, height: 220)
                        .offset(x: -60, y: 60)
                        .blur(radius: 20)

                    VStack(spacing: BBTheme.Spacing.md) {
                        // Logo mark
                        ZStack {
                            Circle()
                                .fill(BBTheme.Colors.primary.opacity(0.08))
                                .frame(width: 96, height: 96)
                            Image("BBLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                        }
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

                // Feature cards
                VStack(spacing: BBTheme.Spacing.sm) {
                    WelcomeFeatureCard(icon: "heart.fill",
                                       color: BBTheme.Colors.feeding,
                                       title: "onboarding.feature.feeding".l,
                                       delay: 0.15)
                    WelcomeFeatureCard(icon: "moon.fill",
                                       color: BBTheme.Colors.sleep,
                                       title: "onboarding.feature.sleep".l,
                                       delay: 0.25)
                    WelcomeFeatureCard(icon: "chart.line.uptrend.xyaxis",
                                       color: BBTheme.Colors.growth,
                                       title: "onboarding.feature.growth".l,
                                       delay: 0.35)
                    WelcomeFeatureCard(icon: "drop.fill",
                                       color: BBTheme.Colors.diaper,
                                       title: "nav.diapers".l,
                                       delay: 0.45)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, BBTheme.Spacing.xl)

                // CTA
                BBPrimaryButton("button.start".l, icon: "arrow.right") {
                    onStart()
                }
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
}

private struct WelcomeFeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let delay: Double
    @State private var appear = false

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .cornerRadius(12)
            Text(title)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color.opacity(0.7))
                .font(.system(size: 18))
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

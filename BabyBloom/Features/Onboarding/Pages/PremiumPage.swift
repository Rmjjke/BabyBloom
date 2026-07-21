import SwiftUI

// MARK: - Page 7: Premium

struct PremiumPage: View {
    let babyName: String
    let onTrial: () -> Void
    let onSkip: () -> Void
    @State private var appear = false

    private let features: [(icon: String, text: String)] = [
        ("infinity", "onboarding.premium.f1"),
        ("bell.badge.fill", "onboarding.premium.f2"),
        ("square.and.arrow.up.fill", "onboarding.premium.f3"),
        ("person.2.fill", "onboarding.premium.f4"),
        ("chart.bar.fill", "onboarding.premium.f5"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero gradient header
                ZStack {
                    LinearGradient(
                        colors: [Color("BBGradientStart"), Color("BBGradientEnd")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea(edges: .top)

                    VStack(spacing: BBTheme.Spacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 36)
                            .scaleEffect(appear ? 1 : 0.7)

                        Text("onboarding.premium.title".l)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("onboarding.premium.headline".l)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BBTheme.Spacing.xl)
                            .padding(.bottom, 32)
                    }
                    .offset(y: appear ? 0 : 20)
                }
                .frame(height: 240)
                .cornerRadius(BBTheme.Radius.xl, corners: [.bottomLeft, .bottomRight])
                .opacity(appear ? 1 : 0)

                // Features list
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, feat in
                        HStack(spacing: BBTheme.Spacing.md) {
                            Image(systemName: feat.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(BBTheme.Colors.primary)
                                .frame(width: 36, height: 36)
                                .background(BBTheme.Colors.primary.opacity(0.1))
                                .cornerRadius(10)
                            Text(feat.text.l)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BBTheme.Colors.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, BBTheme.Spacing.md)

                        if i < features.count - 1 {
                            Divider().padding(.horizontal, BBTheme.Spacing.md)
                        }
                    }
                }
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.lg)
                .bbShadow(BBTheme.Shadow.card)
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.top, BBTheme.Spacing.xl)
                .offset(y: appear ? 0 : 30)
                .opacity(appear ? 1 : 0)

                // Trial badge
                Text("onboarding.premium.badge".l)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, BBTheme.Spacing.md)
                    .opacity(appear ? 1 : 0)

                // CTAs
                VStack(spacing: BBTheme.Spacing.sm) {
                    BBPrimaryButton("onboarding.premium.trial".l, icon: "sparkles") {
                        onTrial()
                    }

                    Button("onboarding.premium.skip".l) {
                        onSkip()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.vertical, BBTheme.Spacing.xl)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}

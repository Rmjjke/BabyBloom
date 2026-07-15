import SwiftUI

// MARK: - Page 5: Fact / Delight

struct FactPage: View {
    let onContinue: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                // Illustration card
                ZStack {
                    RoundedRectangle(cornerRadius: BBTheme.Radius.xl)
                        .fill(
                            LinearGradient(
                                colors: [BBTheme.Colors.primary.opacity(0.15), BBTheme.Colors.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                    VStack(spacing: BBTheme.Spacing.md) {
                        Text("🍼")
                            .font(.system(size: 72))
                            .rotationEffect(.degrees(appear ? 0 : -15))
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Circle()
                                    .fill(BBTheme.Colors.primary.opacity(0.3 + Double(i) * 0.14))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(appear ? 1 : 0.3)
                                    .animation(.spring(response: 0.4).delay(Double(i) * 0.07), value: appear)
                            }
                        }
                    }
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .scaleEffect(appear ? 1 : 0.9)
                .opacity(appear ? 1 : 0)

                VStack(spacing: BBTheme.Spacing.md) {
                    Text("onboarding.fact.title".l)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.pill)

                    Text("onboarding.fact.body".l)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
            }

            Spacer()

            BBPrimaryButton("onboarding.fact.cta".l, icon: "wand.and.stars") {
                onContinue()
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.bottom, 40)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}

import SwiftUI

// MARK: - Page 5: Fact / Delight

struct FactPage: View {
    let babyName: String
    let birthDate: Date
    let feedingType: Baby.FeedingType
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    @State private var shownNumber = 0
    @State private var drift = false
    /// Picked ONCE in onAppear and held as state. A computed property here was
    /// a real bug: its time-based seed changed between body evaluations, so
    /// the counter animated one fact's number while the text showed another's.
    @State private var fact: OnboardingFacts.Fact = OnboardingFacts.pool[0]
    @State private var countTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                illustration
                    .padding(.horizontal, BBTheme.Spacing.lg)
                    .scaleEffect(appear ? 1 : 0.9)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: BBTheme.Spacing.md) {
                    Text("onboarding.fact.title".l)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.pill)

                    Text(OnboardingFacts.body(for: fact, name: babyName))
                        .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
            }

            Spacer()

            // A plain "Next": the commitment CTA now lives on the widget page,
            // the last page before the loader it kicks off.
            BBPrimaryButton("button.next".l, icon: "arrow.right") {
                onContinue()
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.bottom, 40)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            // Seed from seconds-of-day: varied across launches, fixed within one.
            fact = OnboardingFacts.pick(
                ageMonths: Baby.months(from: birthDate),
                feedingType: feedingType,
                seed: Calendar.current.component(.second, from: Date())
                    + 60 * Calendar.current.component(.minute, from: Date())
            )
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
            startCounting(to: fact.number)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
        .onDisappear { countTask?.cancel() }
    }

    // MARK: - Illustration

    /// The card stays alive after the entrance: the fact's number counts up
    /// and the brand symbols drift slowly — both stop under Reduce Motion
    /// (the number then just appears).
    private var illustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BBTheme.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [BBTheme.Colors.primary.opacity(drift ? 0.20 : 0.14),
                                 BBTheme.Colors.accent.opacity(drift ? 0.16 : 0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 200)

            driftingSymbol("heart.fill",  tint: BBTheme.Colors.feeding, x: -110, size: 16, phase: 0)
            driftingSymbol("moon.fill",   tint: BBTheme.Colors.sleep,   x: 116,  size: 18, phase: 1)
            driftingSymbol("drop.fill",   tint: BBTheme.Colors.diaper,  x: -60,  size: 13, phase: 2)
            driftingSymbol("sparkles",    tint: BBTheme.Colors.accent,  x: 70,   size: 14, phase: 3)

            VStack(spacing: BBTheme.Spacing.sm) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(BBTheme.Colors.primary)
                Text("\(shownNumber)")
                    .font(BBTheme.Typography.scaled(44, relativeTo: .largeTitle, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BBTheme.Colors.primary)
                    .contentTransition(.numericText())
            }
        }
    }

    private func driftingSymbol(_ name: String, tint: Color, x: CGFloat, size: CGFloat, phase: Double) -> some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(tint.opacity(0.55))
            .offset(x: x, y: drift ? -18 - phase * 4 : 14 + phase * 3)
            .animation(reduceMotion ? nil
                       : .easeInOut(duration: 5 + phase).repeatForever(autoreverses: true).delay(phase * 0.4),
                       value: drift)
    }

    /// Steps the number up roughly within a second, whatever its size.
    private func startCounting(to target: Int) {
        guard !reduceMotion else { shownNumber = target; return }
        shownNumber = 0
        countTask = Task { @MainActor in
            for value in 1...max(1, target) {
                try? await Task.sleep(nanoseconds: UInt64(900_000_000 / UInt64(max(1, target))))
                withAnimation(.snappy) { shownNumber = value }
            }
        }
    }
}

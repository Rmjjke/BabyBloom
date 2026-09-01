import SwiftUI

// MARK: - Page 6: Generating

struct GeneratingPage: View {
    let babyName: String
    let birthDate: Date
    let onDone: () -> Void

    @State private var completedSteps: Set<Int> = []
    @State private var showDone = false

    /// The second step names the baby and their age — the one line that makes
    /// "personalizing" read as true rather than staged.
    private var steps: [(text: String, icon: String)] {
        let name = babyName.trimmingCharacters(in: .whitespaces)
        let calibrating = String(format: "onboarding.gen.step_named".l,
                                 name.isEmpty ? "baby.default_name".l : name,
                                 Baby.describeAge(from: birthDate))
        return [
            ("onboarding.gen.step1".l, "heart.fill"),
            (calibrating, "person.crop.circle.badge.checkmark"),
            ("onboarding.gen.step2".l, "chart.line.uptrend.xyaxis"),
            ("onboarding.gen.step3".l, "moon.fill"),
            ("onboarding.gen.step4".l, "bell.fill"),
        ]
    }

    /// Uneven on purpose: uniform ticks read as an animation, uneven ones as
    /// work. Sums with the trailing pauses to ~4.6 s (owner: +40% over the
    /// old 3.2 s).
    private let stepDelays: [UInt64] = [450, 1_000, 650, 1_200, 550].map { $0 * 1_000_000 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(BBTheme.Colors.primary.opacity(0.12), lineWidth: 6)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: showDone ? 1 : CGFloat(completedSteps.count) / CGFloat(steps.count))
                        .stroke(
                            LinearGradient(colors: [BBTheme.Colors.primary, BBTheme.Colors.accent],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: completedSteps.count)
                    Image("BBLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }

                VStack(spacing: BBTheme.Spacing.sm) {
                    let name = babyName.trimmingCharacters(in: .whitespaces)
                    BBTheme.Typography.title3(name.isEmpty ? "onboarding.gen.title".l : String(format: "onboarding.gen.title_named".l, name))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(completedSteps.contains(i) ? BBTheme.Colors.primary : BBTheme.Colors.primary.opacity(0.1))
                                        .frame(width: 28, height: 28)
                                    if completedSteps.contains(i) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: step.icon)
                                            .font(.system(size: 11))
                                            .foregroundStyle(BBTheme.Colors.primary.opacity(0.5))
                                    }
                                }
                                .animation(.spring(response: 0.4), value: completedSteps.contains(i))

                                Text(step.text)
                                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                                    .foregroundStyle(completedSteps.contains(i) ? BBTheme.Colors.textPrimary : BBTheme.Colors.textSecondary)
                                    .animation(.easeIn, value: completedSteps.contains(i))
                            }
                            .opacity(i <= completedSteps.count ? 1 : 0.3)
                        }
                    }
                    .padding(BBTheme.Spacing.lg)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)
                }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()
            Spacer()
        }
        .task {
            for (i, delay) in stepDelays.enumerated() {
                try? await Task.sleep(nanoseconds: delay)
                withAnimation { completedSteps.insert(i) }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation { showDone = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            onDone()
        }
    }
}

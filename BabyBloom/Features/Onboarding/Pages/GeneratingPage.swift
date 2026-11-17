import SwiftUI

// MARK: - Generating (page 10 of 11)

/// Runs after the notifications and widget pages: its last step ("configuring
/// smart reminders") is only honest once permission has been answered, and its
/// finish lands straight on the paywall.

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
    /// work. Sums with the trailing pauses to ~4.6 s (+40% over the old
    /// 3.2 s).
    private let stepDelays: [UInt64] = [450, 1_000, 650, 1_200, 550].map { $0 * 1_000_000 }

    private var stepFont: Font {
        BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded)
    }

    var body: some View {
        // The five rows while the column fits the page's height with every word
        // whole beside its disc, else the step in progress alone, at any text
        // size, language or Bold Text: where it flips differs by each (es needs
        // 549 pt of a 548-pt page at xxLarge), so no size threshold could hold
        // it. The page moves on by itself, so it is not meant to scroll; the
        // scroll is only the net for a landscape phone, where even one step
        // may miss.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                column { WholeWordsOnly { stepRows } }
                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            onboardingCenteredScroll { column { stepInProgress } }
        }
        // A stable anchor for driving the flow by hand. The e2e walks do NOT
        // wait on it — the page can be gone before Maestro's tap returns;
        // they assert `onboarding.premium.afterGenerating` (OnboardingView).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.generating")
        .task {
            for (i, delay) in stepDelays.enumerated() {
                try? await Task.sleep(nanoseconds: delay)
                withAnimation { completedSteps.insert(i) }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation { showDone = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            // `try?` swallows cancellation: without this a torn-down loader still "finishes".
            guard !Task.isCancelled else { return }
            onDone()
        }
    }

    private func column<Steps: View>(@ViewBuilder _ steps: () -> Steps) -> some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            ring

            VStack(spacing: BBTheme.Spacing.sm) {
                let name = babyName.trimmingCharacters(in: .whitespaces)
                BBSteppedText(name.isEmpty ? "onboarding.gen.title".l : String(format: "onboarding.gen.title_named".l, name))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                steps()
            }
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }

    private var ring: some View {
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
            // Shadowless: the card shadow would blur across the
            // progress track only 22pt away.
            BrandMark(diameter: 44, shadowed: false)
        }
    }

    private var stepRows: some View {
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
                                .foregroundStyle(BBTheme.Colors.onPrimary)
                        } else {
                            Image(systemName: step.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(BBTheme.Colors.primary.opacity(0.5))
                        }
                    }
                    .animation(.spring(response: 0.4), value: completedSteps.contains(i))

                    WordWrappingText(text: step.text)
                        .font(stepFont)
                        .foregroundStyle(completedSteps.contains(i) ? BBTheme.Colors.textPrimary : BBTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// The one in progress, the last after the fifth. All five are set in one
    /// place, so the box is the tallest one's height and the ring and the title
    /// stand still as the steps change. The ring's trim carries the count, so
    /// no disc; the change is by opacity alone, which Reduce Motion keeps.
    private var stepInProgress: some View {
        let current = min(completedSteps.count, steps.count - 1)
        return ZStack {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                Text(step.text)
                    .font(stepFont)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(i == current ? 1 : 0)
                    .accessibilityHidden(i != current)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.25), value: current)
    }
}

/// Its content as it is while the content's ideal width fits the width it is
/// offered; else taller than any page, so the `ViewThatFits(in: .vertical)`
/// above passes the rows over. The rows' ideal width is their widest word
/// beside its disc (`WordWrappingText`), so they stay only while no word
/// breaks. The height alone would keep them in a narrow, tall window (iPad
/// Slide Over at 320 pt), where ru «Персонализируем» at AX2 is 236 pt in a
/// 186-pt row.
private struct WholeWordsOnly: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(proposal)
        guard let width = proposal.width, subviews[0].sizeThatFits(.unspecified).width > width else { return size }
        return CGSize(width: size.width, height: .infinity)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

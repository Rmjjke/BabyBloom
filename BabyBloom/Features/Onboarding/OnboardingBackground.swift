import SwiftUI

// MARK: - OnboardingBackground

/// The single ground the whole onboarding flow sits on.
///
/// Rendered once by `OnboardingView` behind the page switcher, so the pages
/// slide over a backdrop that never moves — the flow reads as one place rather
/// than eight screens. It was `WelcomePage`'s private hero decoration before;
/// every other page landed on flat `BBBackground` and the drop was visible.
struct OnboardingBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    /// Deliberately asymmetric: three blobs on a grid would read as a pattern.
    /// Radius and blur are large relative to the screen so no blob shows an
    /// edge — only its tint reaches the page above.
    private struct Blob {
        let color: Color
        let size: CGFloat
        let center: CGSize
        let opacity: Double
        let blur: CGFloat
        /// Where the blob travels to at the far end of its drift.
        let travel: CGSize
    }

    private var blobs: [Blob] {
        [
            Blob(color: BBTheme.Colors.primary, size: 380, center: CGSize(width: 120, height: -280),
                 opacity: 0.16, blur: 70, travel: CGSize(width: -18, height: 22)),
            Blob(color: BBTheme.Colors.accent, size: 300, center: CGSize(width: -130, height: -40),
                 opacity: 0.18, blur: 60, travel: CGSize(width: 20, height: -16)),
            Blob(color: BBTheme.Colors.primary, size: 340, center: CGSize(width: 90, height: 320),
                 opacity: 0.12, blur: 80, travel: CGSize(width: -14, height: -20)),
        ]
    }

    var body: some View {
        ZStack {
            BBTheme.Colors.background

            ForEach(Array(blobs.enumerated()), id: \.offset) { index, blob in
                Circle()
                    .fill(blob.color.opacity(blob.opacity))
                    .frame(width: blob.size, height: blob.size)
                    .blur(radius: blob.blur)
                    .offset(x: blob.center.width + (drifting ? blob.travel.width : 0),
                            y: blob.center.height + (drifting ? blob.travel.height : 0))
                    // Staggered so the three never reach their turning points
                    // together, which is what would give the drift a pulse.
                    .animation(motion(delay: Double(index) * 2.5), value: drifting)
            }
        }
        .ignoresSafeArea()
        // Decoration only — VoiceOver must not stop on three blurred circles.
        .accessibilityHidden(true)
        .onAppear { drifting = true }
    }

    /// ~20 s each way: slow enough that the movement is felt rather than seen.
    private func motion(delay: Double) -> Animation? {
        guard !reduceMotion else { return nil }
        return .easeInOut(duration: 20).repeatForever(autoreverses: true).delay(delay)
    }
}

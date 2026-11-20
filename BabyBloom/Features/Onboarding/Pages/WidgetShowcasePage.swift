import SwiftUI

// MARK: - Widget showcase (page 9 of 9)

/// Onboarding's last page: the widget the parent can put on the Home Screen,
/// and what is free and what Premium adds. Its button creates the profile and
/// opens the app; there is no page after it.
///
/// The real widget views, not a screenshot: `BabyBloomMediumWidgetView` is the
/// same type the extension renders, so this page cannot drift away from what
/// the parent will actually put on their home screen. Medium only: the small
/// view beside it would squeeze the medium or float alone in half a row.
struct WidgetShowcasePage: View {
    let babyName: String
    /// True from the button's first tap until Home replaces onboarding.
    let isFinishing: Bool
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    private var name: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "baby.default_name".l : trimmed
    }

    /// A plausible mid-day snapshot, built inline from fixed offsets: nothing is
    /// seeded, saved or read back. Computed per body evaluation so the countdown
    /// stays a round "40 min" rather than decaying while the page is open.
    private var sampleEntry: BabyBloomEntry {
        let now = Date()
        return BabyBloomEntry(
            date: now,
            babyName: name,
            lastFeedingTime: now.addingTimeInterval(-3600),
            sleepStartTime: nil,
            lastSleepDuration: WidgetCopy.minutesText(65 * 60),
            todayFeedingCount: 6,
            isAsleep: false,
            nextFeedingTime: now.addingTimeInterval(40 * 60)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Centred while it fits; at the accessibility sizes on a small
            // phone the content scrolls and the button under it stays put.
            onboardingCenteredScroll {
            VStack(spacing: BBTheme.Spacing.xl) {
                BBSteppedText("onboarding.widget.free_title".l)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .opacity(appear ? 1 : 0)

                // The caption sits under the specimen it describes; that saves
                // a block gap, which is what lets ru fit an SE at Large.
                VStack(spacing: BBTheme.Spacing.sm) {
                    widgetSpecimen
                        .scaleEffect(appear ? 1 : 0.94)

                    Text(String(format: "onboarding.widget.howto".l, "brand.name".l))
                        .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appear ? 1 : 0)

                OnboardingFreeCard()
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.vertical, BBTheme.Spacing.lg)
            }

            // Disabled from the first tap: a second tap must not create a
            // second profile while the 0.4 s hand-over to Home runs.
            BBPrimaryButton("onboarding.widget.cta".l, icon: "arrow.right", action: onFinish)
                .disabled(isFinishing)
                .accessibilityIdentifier("onboarding.next")
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 40)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { appear = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
        }
    }

    /// WidgetKit gives the view a container background and its own margins;
    /// neither exists in-app, so both are reproduced here — otherwise the
    /// gradient would stop at the content's edge, the exact fault the widget
    /// redesign fixed.
    private var widgetSpecimen: some View {
        ZStack {
            WidgetBackground()
            // Not interactive: the button would start a real feed mid-onboarding.
            BabyBloomMediumWidgetView(entry: sampleEntry, isInteractive: false)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .bbShadow(BBTheme.Shadow.card)
    }
}

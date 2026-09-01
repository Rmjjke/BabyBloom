import SwiftUI

// MARK: - Page 7: Widget showcase

/// The real widget views, not a screenshot: `BabyBloomMediumWidgetView` is the
/// same type the extension renders, so this page cannot drift away from what
/// the parent will actually put on their home screen.
///
/// Medium only. The small view beside it would either squeeze the medium below
/// its natural proportions or float alone in half a row, and the copy here
/// describes exactly what the medium answers — the countdown plus the stats.
struct WidgetShowcasePage: View {
    let babyName: String
    let onContinue: () -> Void

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
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                BBTheme.Typography.title3("onboarding.widget.title".l)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appear ? 1 : 0)

                widgetSpecimen
                    .scaleEffect(appear ? 1 : 0.94)
                    .opacity(appear ? 1 : 0)

                VStack(spacing: BBTheme.Spacing.md) {
                    Text("onboarding.widget.subtitle".l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)

                    Text(String(format: "onboarding.widget.howto".l, "brand.name".l))
                        .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()

            // The commitment CTA sits here, on the last page before Generating:
            // "Build my tracker" is what the loader then visibly does.
            BBPrimaryButton("onboarding.widget.cta".l, icon: "arrow.right", action: onContinue)
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
            BabyBloomMediumWidgetView(entry: sampleEntry)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .bbShadow(BBTheme.Shadow.card)
    }
}

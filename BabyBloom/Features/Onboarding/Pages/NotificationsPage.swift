import SwiftUI

// MARK: - Page 8: Notifications

/// The permission ask, placed right after Generating — whose last step just
/// said we were setting up smart reminders, so the system dialog arrives as
/// the answer to a promise instead of landing on the Dashboard uninvited.
///
/// Both buttons advance. A parent who declines has still finished onboarding,
/// and the bullets are the only pitch they get — there is no second ask.
struct NotificationsPage: View {
    let babyName: String
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false
    /// The dialog is modal but the button is not; a double tap would queue a
    /// second request whose callback advances the flow twice.
    @State private var asking = false

    /// Every line is a real rule from NOTIFICATIONS.md: the smart feeding
    /// interval (§3), the age-based wake window (§2.2), and cancel-before-post
    /// per ID plus time-sensitive only for the two long-session alerts (§1).
    private let bullets: [(icon: String, key: String)] = [
        ("waveform.path.ecg", "onboarding.notify.b1"),
        ("moon.zzz.fill", "onboarding.notify.b2"),
        ("bell.slash.fill", "onboarding.notify.b3"),
    ]

    private var name: String {
        let trimmed = babyName.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "baby.default_name".l : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            // The pitch scrolls, the buttons do not. At the app's declared AX2
            // ceiling the bullets alone outgrow an SE-class screen, and an
            // overflowing VStack centres its children — which pushed BOTH
            // buttons off a page that has no back button, dead-ending
            // onboarding. Same arrangement as PremiumPage.
            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.xl) {
                    onboardingHeroIcon("bell.badge.fill", color: BBTheme.Colors.primary)
                        .scaleEffect(appear ? 1 : 0.9)
                        .opacity(appear ? 1 : 0)

                    BBTheme.Typography.title3(String(format: "onboarding.notify.title".l, name))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .opacity(appear ? 1 : 0)

                    VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                        ForEach(bullets, id: \.key) { bullet in
                            HStack(alignment: .top, spacing: BBTheme.Spacing.md) {
                                Image(systemName: bullet.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BBTheme.Colors.primary)
                                    .frame(width: 32, height: 32)
                                    .background(BBTheme.Colors.primary.opacity(0.1), in: Circle())
                                Text(bullet.key.l)
                                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(BBTheme.Spacing.lg)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)
                    .offset(y: appear ? 0 : 30)
                    .opacity(appear ? 1 : 0)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.vertical, BBTheme.Spacing.xl)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: BBTheme.Spacing.sm) {
                BBPrimaryButton("onboarding.notify.cta".l, icon: "bell.fill") { ask() }
                Button(action: skip) {
                    Text("onboarding.notify.later".l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.bottom, 36)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else { appear = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
        }
    }

    private func ask() {
        guard !asking else { return }
        asking = true
        // A parent who already answered on a previous install gets no dialog at
        // all — the system resolves instantly and the callback still advances.
        NotificationManager.shared.requestPermission { _ in onContinue() }
    }

    /// Guarded like the CTA: SpringBoard takes ~20 ms to cover the app, and in
    /// that window a CTA-then-"Not now" pair would call `onContinue()` twice.
    /// `next()` is relative, so the second call would skip the widget page.
    private func skip() {
        guard !asking else { return }
        asking = true
        onContinue()
    }
}

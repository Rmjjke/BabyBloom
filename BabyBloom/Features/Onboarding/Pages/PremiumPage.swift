import SwiftUI

// MARK: - Page 7: Premium

struct PremiumPage: View {
    let onPurchased: () -> Void
    let onSkip: () -> Void
    @State private var appear = false
    @State private var showClose = false
    @State private var closeTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // PlanPickerSection's restore button works from any host, but the
    // success/nothing-found feedback lives here — PaywallView owns its own
    // copy too, since restoreState is process-wide state, not page state.
    @Environment(SubscriptionManager.self) private var store
    @State private var showRestoreAlert = false

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
                        BrandMark(diameter: 64, onGradient: true)
                            .padding(.top, 36)
                            .scaleEffect(appear ? 1 : 0.7)

                        BBTheme.Typography.title1("onboarding.premium.title".l)
                            .foregroundStyle(.white)

                        Text("onboarding.premium.headline".l)
                            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
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
                                .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BBTheme.Colors.success)
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

                PlanPickerSection(onPurchased: onPurchased)
                    .padding(.horizontal, BBTheme.Spacing.lg)
                    .padding(.vertical, BBTheme.Spacing.xl)
                    .offset(y: appear ? 0 : 30)
                    .opacity(appear ? 1 : 0)
            }
        }
        .overlay(alignment: .topLeading) {
            if showClose {
                Button(action: onSkip) {
                    // Material background (not a hardcoded white/opacity pair) so the
                    // X stays legible over both the purple hero and the near-white
                    // body it scrolls onto; the tappable frame is 44pt per HIG even
                    // though the visual circle stays a modest 34pt.
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .padding(.top, 8)
                .padding(.leading, BBTheme.Spacing.md)
                .accessibilityLabel("button.close".l)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
            // Five seconds, not three (owner ruling, 2026-09-01). The delay is
            // review-safe ONLY because the button reliably appears: the task is
            // tied to the page, not to any subview, and nothing cancels it.
            closeTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                withAnimation(.easeIn(duration: 0.3)) { showClose = true }
            }
        }
        .onDisappear { closeTask?.cancel() }
        .alert("premium.restore_title".l, isPresented: $showRestoreAlert) {
            // The user sees the confirmation first; advancing onboarding is a
            // consequence of dismissing it, not a side effect of restoreState
            // changing underneath the alert.
            Button("button.close".l, role: .cancel) {
                let wasSuccess = store.restoreState == .success
                store.clearRestoreState()
                if wasSuccess { onPurchased() }
            }
        } message: {
            Text(store.restoreState == .success
                 ? "premium.restore_success".l
                 : "premium.restore_nothing".l)
        }
        .onChange(of: store.restoreState) { _, new in
            showRestoreAlert = new != nil
        }
    }
}

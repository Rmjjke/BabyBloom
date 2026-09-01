import SwiftUI

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showRestoreAlert = false

    private let features: [(icon: String, key: String)] = [
        ("infinity",                  "onboarding.premium.f1"),
        ("bell.badge.fill",           "onboarding.premium.f2"),
        ("square.and.arrow.up.fill",  "onboarding.premium.f3"),
        ("person.2.fill",             "onboarding.premium.f4"),
        ("chart.bar.fill",            "onboarding.premium.f5"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Hero ────────────────────────────────────────────────
                // Shared with onboarding's paywall.
                PremiumHero()

                VStack(spacing: BBTheme.Spacing.lg) {

                    // Active badge (shown if already premium)
                    if store.isPremium {
                        activeBadge
                    }

                    // Plans + CTA + restore + legal (or load-error retry state)
                    if !store.isPremium {
                        PlanPickerSection()
                    }

                    // Features
                    featuresCard

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.top, BBTheme.Spacing.lg)
            }
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .topTrailing) { closeButton }
        .navigationTitle("settings.premium".l)
        .navigationBarTitleDisplayMode(.inline)
        .alert("premium.restore_title".l, isPresented: $showRestoreAlert) {
            Button("button.close".l, role: .cancel) { store.clearRestoreState() }
        } message: {
            Text(store.restoreState == .success
                 ? "premium.restore_success".l
                 : "premium.restore_nothing".l)
        }
        .onChange(of: store.restoreState) { _, new in
            showRestoreAlert = new != nil
        }
        .task {
            await store.refreshEntitlements()
        }
    }

    // MARK: - Close Button (modal dismissal)

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)          // ≥44pt tap zone
                .contentShape(Rectangle())
        }
        .padding(.trailing, BBTheme.Spacing.sm)
        .padding(.top, BBTheme.Spacing.sm)
    }

    // MARK: - Active Badge

    private var activeBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(BBTheme.Colors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("premium.active_status".l)
                    .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("premium.active_desc".l)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            Spacer()
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.primary.opacity(0.08))
        .cornerRadius(BBTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                .stroke(BBTheme.Colors.primary.opacity(0.25), lineWidth: 1.5)
        )
    }

    // MARK: - Features

    private var featuresCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { i, feat in
                HStack(spacing: BBTheme.Spacing.md) {
                    Image(systemName: feat.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .frame(width: 34, height: 34)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(9)
                    Text(feat.key.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BBTheme.Colors.success)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, BBTheme.Spacing.md)

                if i < features.count - 1 {
                    Divider().padding(.horizontal, BBTheme.Spacing.md)
                }
            }
        }
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }
}

import SwiftUI
import StoreKit

// MARK: - Paywall View

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = SubscriptionManager.yearlyID
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
                heroHeader

                VStack(spacing: BBTheme.Spacing.lg) {

                    // Active badge (shown if already premium)
                    if store.isPremium {
                        activeBadge
                    }

                    // Plan selector
                    if !store.isPremium {
                        planSelector
                    }

                    // Features
                    featuresCard

                    // CTA
                    if !store.isPremium {
                        ctaSection
                    }

                    // Footer
                    footerLinks

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.top, BBTheme.Spacing.lg)
            }
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
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
            await store.loadProducts()
            await store.refreshEntitlements()
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#6B5EA8"), Color(hex: "#9B8FD8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: BBTheme.Spacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 36)

                Text("onboarding.premium.title".l)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("onboarding.premium.headline".l)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BBTheme.Spacing.xl)
                    .padding(.bottom, 32)
            }
        }
        .frame(height: 220)
        .cornerRadius(BBTheme.Radius.xl, corners: [.bottomLeft, .bottomRight])
    }

    // MARK: - Active Badge

    private var activeBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26))
                .foregroundStyle(BBTheme.Colors.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("premium.active_status".l)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
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

    // MARK: - Plan Selector

    private var planSelector: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            planCard(
                id: SubscriptionManager.monthlyID,
                product: store.monthlyProduct,
                titleKey: "premium.plan.monthly",
                badge: nil
            )
            planCard(
                id: SubscriptionManager.yearlyID,
                product: store.yearlyProduct,
                titleKey: "premium.plan.yearly",
                badge: "premium.plan.best_value".l
            )
        }
    }

    private func planCard(
        id: String,
        product: Product?,
        titleKey: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedID == id

        return Button {
            withAnimation(.spring(response: 0.3)) { selectedID = id }
        } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BBTheme.Colors.accent)
                        .cornerRadius(BBTheme.Radius.pill)
                }

                Text(titleKey.l)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)

                if let product {
                    Text(product.displayPrice)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                    Text(id == SubscriptionManager.monthlyID
                         ? "premium.per_month".l
                         : "premium.per_year".l)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                } else {
                    Text("premium.loading".l)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(isSelected
                        ? BBTheme.Colors.primary.opacity(0.08)
                        : BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                    .stroke(isSelected
                            ? BBTheme.Colors.primary
                            : BBTheme.Colors.textSecondary.opacity(0.15),
                            lineWidth: isSelected ? 2 : 1)
            )
            .bbShadow(BBTheme.Shadow.card)
        }
        .buttonStyle(BBScaleButtonStyle())
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
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BBTheme.Colors.primary)
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
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            // Trial note
            Text("onboarding.premium.badge".l)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // Subscribe button
            BBPrimaryButton(
                store.isLoading ? "premium.loading".l : "onboarding.premium.trial".l,
                icon: "sparkles"
            ) {
                Task {
                    let product = selectedID == SubscriptionManager.yearlyID
                        ? store.yearlyProduct
                        : store.monthlyProduct
                    if let product { await store.purchase(product) }
                }
            }
            .disabled(store.isLoading || selectedProduct == nil)
            .opacity(selectedProduct == nil ? 0.5 : 1)

            // Error
            if let err = store.purchaseError {
                Text(err)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Restore button
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("premium.restore".l)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .underline()
            }
            .disabled(store.isLoading)
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: BBTheme.Spacing.lg) {
            Link("premium.terms".l,
                 destination: URL(string: "https://babybloom.app/terms")!)
            Link("premium.privacy".l,
                 destination: URL(string: "https://babybloom.app/privacy")!)
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundStyle(BBTheme.Colors.textSecondary)
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        selectedID == SubscriptionManager.yearlyID
            ? store.yearlyProduct
            : store.monthlyProduct
    }
}

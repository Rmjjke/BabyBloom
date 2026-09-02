import SwiftUI
import StoreKit

// MARK: - Plan Picker Section

/// The half of a paywall the two paywalls must never disagree on: plans,
/// prices, the trial promise, the purchase button, restore, and the legal
/// footer. The onboarding paywall rotted precisely because it was a separate
/// implementation; composing this section is what prevents a recurrence.
struct PlanPickerSection: View {
    @Environment(SubscriptionManager.self) private var store
    @State private var selectedID = SubscriptionManager.yearlyID
    // Load state, not purchase state: set once the initial reloadProducts()
    // await returns, regardless of outcome. Gating retry on this (rather than
    // on purchaseError) keeps a later purchase failure from unmounting the
    // picker, and still catches an empty-but-error-free product list.
    @State private var loadAttempted = false

    // This section deliberately has NO "purchased" callback. Advancing on
    // entitlement is the HOST's job, because the purchase button is not the
    // only way entitlement arrives (restore, `Transaction.updates`, and an
    // Apple ID that was already subscribed before the paywall ever appeared),
    // and a callback wired to the button covers exactly one of those. The
    // onboarding host observes `store.isPremium`; the settings paywall swaps
    // this section for its active badge and navigates nowhere.

    var body: some View {
        VStack(spacing: BBTheme.Spacing.lg) {
            if loadAttempted && store.yearlyProduct == nil && store.monthlyProduct == nil
                && store.weeklyProduct == nil {
                loadErrorView
            } else {
                planSelector
                ctaSection
            }
            footerLinks
        }
        .task { await reloadProducts() }
    }

    // MARK: - Load Error

    private var loadErrorView: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(BBTheme.Colors.textSecondary)
            Text("premium.error_load".l)
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await reloadProducts() }
            } label: {
                Text("premium.retry".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .padding(.horizontal, BBTheme.Spacing.lg)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule().stroke(BBTheme.Colors.primary, lineWidth: 1.5)
                    )
            }
            .disabled(store.isLoading)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BBTheme.Spacing.lg)
        .padding(.horizontal, BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    // MARK: - Plan Selector

    /// Year first and preselected: it matches how long people actually use a
    /// newborn tracker. Weekly is last but present — it exists for the first
    /// weeks after birth, when anxiety is high and nobody is planning a year
    /// ahead. Stacked rather than side by side: three columns crush the price
    /// at large text sizes.
    private var planSelector: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            planRow(
                id: SubscriptionManager.yearlyID,
                product: store.yearlyProduct,
                titleKey: "premium.plan.yearly",
                periodKey: "premium.per_year",
                badge: yearlySavingsPercent.map { String(format: "premium.save_fmt".l, $0) }
                    ?? "premium.plan.best_value".l
            )
            planRow(
                id: SubscriptionManager.monthlyID,
                product: store.monthlyProduct,
                titleKey: "premium.plan.monthly",
                periodKey: "premium.per_month",
                badge: nil
            )
            planRow(
                id: SubscriptionManager.weeklyID,
                product: store.weeklyProduct,
                titleKey: "premium.plan.weekly",
                periodKey: "premium.per_week",
                badge: nil
            )
        }
    }

    private func planRow(
        id: String,
        product: Product?,
        titleKey: String,
        periodKey: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedID == id

        return Button {
            withAnimation(.spring(response: 0.3)) { selectedID = id }
        } label: {
            HStack(alignment: .center, spacing: BBTheme.Spacing.sm) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(BBTheme.Typography.scaled(18, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(isSelected ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let product {
                        Text(product.displayPrice + " " + periodKey.l)
                            .font(BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded).monospacedDigit())
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("premium.loading".l)
                            .font(BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                    }
                }

                Spacer(minLength: BBTheme.Spacing.sm)

                if let badge {
                    Text(badge)
                        .font(BBTheme.Typography.scaled(11, relativeTo: .caption2, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BBTheme.Colors.accent)
                        .cornerRadius(BBTheme.Radius.pill)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, BBTheme.Spacing.md)
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
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(BBScaleButtonStyle())
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: BBTheme.Spacing.md) {
            // Trial note — per plan, from StoreKit, not one hardcoded sentence
            Text(trialLine ?? "premium.loading".l)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            // Subscribe button
            BBPrimaryButton(ctaTitle, icon: "arrow.right") {
                Task {
                    if let product = selectedProduct {
                        await store.purchase(product)
                    }
                }
            }
            .disabled(store.isLoading || selectedProduct == nil)
            .opacity(selectedProduct == nil ? 0.5 : 1)

            // Pending approval (Ask to Buy / SCA)
            if store.purchasePending {
                Text("premium.pending_message".l)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Purchase error (load errors are handled by loadErrorView above)
            if let err = store.purchaseError, selectedProduct != nil {
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
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .underline()
            }
            .disabled(store.isLoading)
        }
    }

    /// "Try 7 days free" only when this plan HAS a trial this Apple ID can
    /// still take; otherwise plain "Subscribe". The old label promised a free
    /// trial on every plan, which trial-only-on-yearly turned into a lie on
    /// two of the three.
    private var ctaTitle: String {
        guard !store.isLoading else { return "premium.loading".l }
        guard let product = selectedProduct,
              store.isEligibleForIntroOffer,
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return "premium.cta_subscribe".l }
        return String(format: "premium.cta_trial_fmt".l, Self.days(in: offer.period))
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: BBTheme.Spacing.xs) {
            Text("premium.auto_renew".l)
                .multilineTextAlignment(.center)

            HStack(spacing: BBTheme.Spacing.lg) {
                Link("premium.terms".l,
                     destination: URL(string: "https://babybloom.app/terms")!)
                Link("premium.privacy".l,
                     destination: URL(string: "https://babybloom.app/privacy")!)
            }
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundStyle(BBTheme.Colors.textSecondary)
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        switch selectedID {
        case SubscriptionManager.yearlyID:  return store.yearlyProduct
        case SubscriptionManager.monthlyID: return store.monthlyProduct
        case SubscriptionManager.weeklyID:  return store.weeklyProduct
        default:                            return nil
        }
    }

    /// The saving the yearly plan gives against the monthly one, as a whole
    /// percent, computed from the prices the App Store returned. A price
    /// changed in App Store Connect moves this badge with it; a constant
    /// would leave the screen advertising a discount it no longer gives.
    private var yearlySavingsPercent: Int? {
        guard let yearly = store.yearlyProduct, let monthly = store.monthlyProduct,
              let yearPeriod = yearly.subscription?.subscriptionPeriod,
              let monthPeriod = monthly.subscription?.subscriptionPeriod,
              let yearUnit = SubscriptionManager.PlanPeriod(yearPeriod.unit),
              let monthUnit = SubscriptionManager.PlanPeriod(monthPeriod.unit) else { return nil }
        return SubscriptionManager.savingsPercent(
            of: yearly.price, per: yearUnit, count: yearPeriod.value,
            comparedTo: monthly.price, per: monthUnit, count: monthPeriod.value
        )
    }

    /// The line above the button. Reads the trial from the SELECTED product
    /// rather than stating one length for every plan — the three differ
    /// (3/7/7 days) — and says nothing about a free trial to someone who has
    /// already used the group's one.
    private var trialLine: String? {
        guard let product = selectedProduct else { return nil }
        guard store.isEligibleForIntroOffer,
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else {
            // No trial to promise: either this plan has none, or this Apple ID
            // already spent the group's single one.
            return String(format: "premium.price_only_fmt".l, product.displayPrice)
        }
        let days = Self.days(in: offer.period)
        return String(format: "premium.trial_fmt".l, days, days.dayWord, product.displayPrice)
    }

    /// An introductory period expressed in days, so the copy can decline the
    /// word. StoreKit gives 3 days as `.day × 3` and 7 as `.week × 1`.
    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day:   return period.value
        case .week:  return period.value * 7
        case .month: return period.value * 30
        case .year:  return period.value * 365
        @unknown default: return period.value
        }
    }

    /// Loads products and, if the yearly plan is unavailable while monthly
    /// loaded, falls back the selection so the CTA stays enabled.
    private func reloadProducts() async {
        await store.loadProducts()
        loadAttempted = true
        if store.yearlyProduct == nil && store.monthlyProduct != nil {
            selectedID = SubscriptionManager.monthlyID
        }
    }
}

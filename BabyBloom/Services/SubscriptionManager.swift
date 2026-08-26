import Foundation
import StoreKit

// MARK: - Product IDs
// Must exactly match the identifiers created in App Store Connect.
extension SubscriptionManager {
    static let weeklyID  = "com.nenita.app.premium.weekly"
    static let monthlyID = "com.nenita.app.premium.monthly"
    static let yearlyID  = "com.nenita.app.premium.yearly"
}

// MARK: - Plan comparison
//
// Savings are computed from the prices the App Store actually returns, never
// from constants: a price changed in App Store Connect must move the badge
// with it, or the screen ends up advertising a discount it does not give.
//
// The maths is separated from `Product` so it can be tested without StoreKit.
extension SubscriptionManager {

    /// A subscription's renewal period, reduced to what price comparison needs.
    enum PlanPeriod {
        case day, week, month, year

        /// How many of this period fit in a year. Approximate for days and
        /// weeks by exactly the amount the calendar is untidy — which is fine
        /// here, because the result is rounded to a whole percent.
        nonisolated var perYear: Decimal {
            switch self {
            case .day:   return 365
            case .week:  return 52
            case .month: return 12
            case .year:  return 1
            }
        }

        /// StoreKit's unit, reduced to ours. nil for a unit Apple adds later —
        /// better no badge than a wrong one.
        nonisolated init?(_ unit: Product.SubscriptionPeriod.Unit) {
            switch unit {
            case .day:   self = .day
            case .week:  self = .week
            case .month: self = .month
            case .year:  self = .year
            @unknown default: return nil
            }
        }
    }

    /// What a year of this plan costs, so plans of different lengths compare.
    /// nil for a non-positive period, which no real product has.
    nonisolated static func annualizedPrice(_ price: Decimal, per period: PlanPeriod, count: Int) -> Decimal? {
        guard count > 0 else { return nil }
        return price * period.perYear / Decimal(count)
    }

    /// How much cheaper one plan is than another over a year, as a whole
    /// percent. nil when it is not cheaper — a badge is only ever a saving,
    /// and a negative one would read as a surcharge.
    nonisolated static func savingsPercent(
        of price: Decimal, per period: PlanPeriod, count: Int,
        comparedTo basePrice: Decimal, per basePeriod: PlanPeriod, count baseCount: Int
    ) -> Int? {
        guard let annual = annualizedPrice(price, per: period, count: count),
              let baseAnnual = annualizedPrice(basePrice, per: basePeriod, count: baseCount),
              baseAnnual > 0, annual < baseAnnual else { return nil }
        let fraction = (baseAnnual - annual) / baseAnnual
        return Int(NSDecimalNumber(decimal: fraction * 100).doubleValue.rounded())
    }
}

// MARK: - Subscription Manager

@MainActor
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    // Products fetched from App Store
    private(set) var weeklyProduct: Product?
    private(set) var monthlyProduct: Product?
    private(set) var yearlyProduct: Product?

    // State

    /// What StoreKit says: a verified, unrevoked auto-renewable entitlement.
    /// The single source of truth for a real purchase — `refreshEntitlements()`
    /// is the only writer.
    private(set) var isEntitled   = false

    /// Whether this Apple ID can still take the group's free trial. The trial
    /// is granted once per GROUP, not per product, so someone who started a
    /// weekly trial and cancelled gets no second one on the yearly plan —
    /// promising them "7 days free" would be a lie the App Store then refuses
    /// to honour. Refreshed alongside entitlements because the check is async
    /// and a view cannot await one.
    private(set) var isEligibleForIntroOffer = true

    /// What the UI gates on. In every shipped build this is exactly
    /// `isEntitled`; on the simulator it also honours the `-BBForcePremium`
    /// launch argument (see `forcePremiumOverride`).
    ///
    /// Computed rather than stored, and that is the whole point: an override
    /// applied once at init would be silently clobbered, because
    /// `refreshEntitlements()` assigns unconditionally and `MainTabView` calls
    /// it from a `.task` on every appearance — long before Growth is reached.
    var isPremium: Bool {
        #if targetEnvironment(simulator)
        return isEntitled || Self.forcePremiumOverride
        #else
        return isEntitled
        #endif
    }

    #if targetEnvironment(simulator)
    /// Simulator-only Premium override for e2e flows, in the same class of
    /// scaffolding as `SeedScenario`.
    ///
    /// Delivered as a LAUNCH ARGUMENT (`-BBForcePremium true`) rather than a
    /// stored default, so it survives Maestro's `clearState` exactly as
    /// `-BBSkipSplash` and `-BBSeedScenario` do.
    ///
    /// Gated on `targetEnvironment(simulator)`, deliberately NOT on `DEBUG`:
    /// `DEBUG` is false in a release-optimized QA build, which is still a real
    /// build on a real device, and no shipped binary may carry a path that
    /// hands out a paid entitlement for free. On device this property, its key
    /// and the branch above do not exist at all.
    ///
    /// Why the override is needed: `GrowthView` picks between
    /// `FeedingBreakdownCard` and a `LockedInsightCard` that carries the SAME
    /// title string, so without a way to force the paid branch an e2e
    /// assertion on that title passes whether the paid card works or not.
    ///
    /// **Its blast radius is the whole app, not one card.** Everything gated on
    /// `isPremium` opens at once: the gain and trend cards, Export, the paywall
    /// badge — and growth NOTIFICATIONS, because `GrowthView` passes
    /// `store.isPremium` into `NotificationManager.onGrowthDataChanged`, whose
    /// `guard isPremium else { return }` then lets scheduling through. So a
    /// seeded run with this argument schedules notifications a free run would
    /// not. All simulator-only and intended, but do not be surprised by a
    /// notification arriving mid-flow.
    private static let forcePremiumOverride = UserDefaults.standard.bool(forKey: "BBForcePremium")
    #endif

    private(set) var isLoading    = false
    private(set) var purchaseError: String?
    private(set) var purchasePending = false
    private(set) var restoreState: RestoreState?

    enum RestoreState {
        case success, nothingFound
    }

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
    }

    // MARK: - Public API

    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [
                SubscriptionManager.weeklyID,
                SubscriptionManager.monthlyID,
                SubscriptionManager.yearlyID
            ])
            weeklyProduct  = products.first { $0.id == SubscriptionManager.weeklyID }
            monthlyProduct = products.first { $0.id == SubscriptionManager.monthlyID }
            yearlyProduct  = products.first { $0.id == SubscriptionManager.yearlyID }
            await refreshIntroOfferEligibility()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        purchasePending = false
        restoreState = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checked(verification)
                await refreshEntitlements()
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // Ask to Buy / Strong Customer Authentication: the purchase is
                // awaiting external approval. Surface this so the user gets feedback.
                purchasePending = true
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        restoreState = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            // `isEntitled`, not `isPremium`: restoring reports what StoreKit
            // actually returned. Identical in every shipped build; on the
            // simulator it keeps the e2e override from faking a restore.
            restoreState = isEntitled ? .success : .nothingFound
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func clearRestoreState() {
        restoreState = nil
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productType == .autoRenewable,
               tx.revocationDate == nil {
                active = true
                break
            }
        }
        isEntitled = active
        await refreshIntroOfferEligibility()
    }

    /// Asks the App Store whether the group's introductory offer is still
    /// available to this Apple ID. Any of the three products answers for the
    /// whole group, so the first one loaded is enough; with no products loaded
    /// yet the optimistic default stands and the copy corrects itself once
    /// `loadProducts()` returns.
    private func refreshIntroOfferEligibility() async {
        guard let subscription = (yearlyProduct ?? monthlyProduct ?? weeklyProduct)?.subscription else { return }
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await self?.refreshEntitlements()
                await tx.finish()
            }
        }
    }

    private func checked<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.verificationFailed
        case .verified(let value): return value
        }
    }
}

enum SubscriptionError: LocalizedError {
    case verificationFailed
    var errorDescription: String? { "premium.error_verification".l }
}

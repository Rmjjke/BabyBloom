import Foundation
import StoreKit

// MARK: - Product IDs
// Must exactly match the identifiers created in App Store Connect.
extension SubscriptionManager {
    static let monthlyID = "com.nenita.app.premium.monthly"
    static let yearlyID  = "com.nenita.app.premium.yearly"
}

// MARK: - Subscription Manager

@MainActor
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    // Products fetched from App Store
    private(set) var monthlyProduct: Product?
    private(set) var yearlyProduct: Product?

    // State

    /// What StoreKit says: a verified, unrevoked auto-renewable entitlement.
    /// The single source of truth for a real purchase — `refreshEntitlements()`
    /// is the only writer.
    private(set) var isEntitled   = false

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
                SubscriptionManager.monthlyID,
                SubscriptionManager.yearlyID
            ])
            monthlyProduct = products.first { $0.id == SubscriptionManager.monthlyID }
            yearlyProduct  = products.first { $0.id == SubscriptionManager.yearlyID }
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

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
    private(set) var isPremium    = false
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
            restoreState = isPremium ? .success : .nothingFound
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
        isPremium = active
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

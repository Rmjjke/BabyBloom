import XCTest
import StoreKit
import StoreKitTest
@testable import BabyBloom

/// The money path, driven against the real `Nenita.storekit` configuration.
///
/// `SKTestSession` replaces the App Store for this process, so these exercise
/// `SubscriptionManager` through actual StoreKit 2 calls — `Product.purchase()`,
/// `Transaction.currentEntitlements`, `AppStore.sync()` — rather than through a
/// stub that can agree with a wrong assumption. They need the test HOST app
/// (`TEST_HOST` is set on `BabyBloomTests`); without it StoreKit has no
/// application context to attach the session to.
///
/// **What they cannot see.** They cover the manager's state, not the paywall's
/// SwiftUI. The rule "an entitled user is never shown the selling paywall" is
/// enforced in `PremiumPage` by branching on `hasResolvedEntitlements` and
/// `isPremium`; what is testable here is that those two properties tell the
/// truth, which `testEntitlementIsUnresolvedUntilItIsAsked` and the purchase
/// cases pin. The view branch itself is covered by the simulator pass.
final class SubscriptionPurchaseTests: XCTestCase {

    /// A session over the shipped local config, reset to a clean slate. Built
    /// per test rather than in `setUp`: a session is process-wide while it
    /// lives, and one per case is the only arrangement that keeps a purchase
    /// in one test out of the next one's entitlements.
    @MainActor
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Nenita")
        session.resetToDefaultState()
        session.clearTransactions()
        // No purchase-confirmation sheet: nothing can tap it from a test.
        session.disableDialogs = true
        return session
    }

    /// A manager that has never seen a transaction. `SubscriptionManager.shared`
    /// is deliberately not used — it is alive inside the host app and carries
    /// whatever the previous case left behind.
    @MainActor
    private func makeLoadedManager() async -> SubscriptionManager {
        let manager = SubscriptionManager()
        await manager.loadProducts()
        return manager
    }

    // MARK: - Fresh purchase

    @MainActor
    func testBuyingTheYearlyPlanEntitlesTheUser() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct, "Nenita.storekit must serve the yearly plan")
        XCTAssertFalse(manager.isEntitled, "a fresh session owns nothing")

        await manager.purchase(yearly)

        XCTAssertTrue(manager.isEntitled, "a completed purchase must entitle")
        XCTAssertTrue(manager.isPremium)
        XCTAssertNil(manager.purchaseError)
        XCTAssertFalse(manager.purchasePending)
    }

    /// The gate `PremiumPage` branches on. Before anything asks StoreKit,
    /// `isEntitled == false` means "not asked", not "not subscribed" — selling
    /// on that unresolved `false` is the build-9 defect.
    @MainActor
    func testEntitlementIsUnresolvedUntilItIsAsked() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = SubscriptionManager()
        XCTAssertFalse(manager.hasResolvedEntitlements)
        XCTAssertFalse(manager.isEntitled)

        await manager.refreshEntitlements()

        XCTAssertTrue(manager.hasResolvedEntitlements, "the answer is in, whatever it was")
        XCTAssertFalse(manager.isEntitled, "and for a fresh session it is 'free'")
    }

    /// An Apple ID that bought outside this process — the case that reached the
    /// paywall as a full "Try 7 days free" on build 9.
    @MainActor
    func testAnOutOfBandPurchaseResolvesAsEntitled() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: SubscriptionManager.yearlyID)

        let manager = SubscriptionManager()
        await manager.refreshEntitlements()

        XCTAssertTrue(manager.hasResolvedEntitlements)
        XCTAssertTrue(manager.isEntitled, "an entitlement bought elsewhere is still an entitlement")
    }

    // MARK: - Failure and cancellation

    @MainActor
    func testAFailedTransactionLeavesTheUserFree() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.failTransactionsEnabled = true

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct)

        await manager.purchase(yearly)

        XCTAssertFalse(manager.isEntitled, "a failed transaction must not entitle")
        XCTAssertFalse(manager.isPremium)
        XCTAssertNotNil(manager.purchaseError, "and the failure must be shown, not swallowed")
        XCTAssertFalse(manager.isLoading, "the CTA must never be left spinning")
    }

    /// `.paymentCancelled` is what the system raises when the user backs out of
    /// the confirmation sheet. Nothing is bought and — the part that stranded
    /// the owner — the manager must come back out of its loading state.
    @MainActor
    func testACancelledPurchaseLeavesTheUserFreeAndTheCTAUsable() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.failTransactionsEnabled = true
        session.failureError = .paymentCancelled

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct)

        await manager.purchase(yearly)

        XCTAssertFalse(manager.isEntitled)
        XCTAssertFalse(manager.isLoading)
        XCTAssertFalse(manager.purchasePending)
    }

    // MARK: - Buying something already owned

    /// StoreKit answers "You are currently subscribed" and changes nothing.
    /// The requirement is negative: no crash, no lost entitlement, and — since
    /// `purchase()` now re-reads entitlements on every non-success outcome —
    /// the manager still reports the subscription the user actually has.
    @MainActor
    func testBuyingAnOwnedProductKeepsTheEntitlement() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct)
        await manager.purchase(yearly)
        XCTAssertTrue(manager.isEntitled)

        await manager.purchase(yearly)

        XCTAssertTrue(manager.isEntitled, "buying again must not drop what is owned")
        XCTAssertTrue(manager.isPremium)
        XCTAssertFalse(manager.isLoading)
    }

    // MARK: - Restore

    @MainActor
    func testRestoreReportsSuccessForAPurchaseMadeOutOfBand() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        _ = try await session.buyProduct(identifier: SubscriptionManager.yearlyID)

        let manager = await makeLoadedManager()

        await manager.restorePurchases()

        XCTAssertEqual(manager.restoreState, .success)
        XCTAssertTrue(manager.isEntitled)
        XCTAssertFalse(manager.isLoading)
    }

    @MainActor
    func testRestoreReportsNothingFoundWhenThereIsNothingToRestore() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = await makeLoadedManager()

        await manager.restorePurchases()

        XCTAssertEqual(manager.restoreState, .nothingFound)
        XCTAssertFalse(manager.isEntitled)
    }

    // MARK: - Introductory offer

    /// The trial is granted once per GROUP, and both the CTA title and the line
    /// above it read this flag. Promising "7 days free" to someone who already
    /// spent the group's offer is a lie the App Store then refuses to honour.
    @MainActor
    func testIntroOfferEligibilityFlipsOnceTheGroupsOfferIsUsed() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }

        let manager = await makeLoadedManager()
        XCTAssertTrue(manager.isEligibleForIntroOffer, "a fresh Apple ID may take the trial")

        let yearly = try XCTUnwrap(manager.yearlyProduct)
        XCTAssertNotNil(yearly.subscription?.introductoryOffer,
                        "the yearly plan is the one that carries the group's offer")
        await manager.purchase(yearly)

        XCTAssertTrue(manager.isEntitled)
        XCTAssertFalse(manager.isEligibleForIntroOffer,
                       "the group's single offer is spent — the paywall must stop promising it")
    }
}

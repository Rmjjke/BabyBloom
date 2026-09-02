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

    /// Skips, rather than hangs, when the simulator is not actually serving the
    /// local store.
    ///
    /// `Nenita.storekit` is bound to the app **on the device**, by the scheme's
    /// run action. `simctl erase` drops that binding and nothing on the command
    /// line can restore it: `simctl` has no StoreKit subcommand, and XcodeGen
    /// emits `storeKitConfiguration` into LaunchAction only. On a device in that
    /// state StoreKit reaches for the real App Store, and every purchasing call
    /// — `Product.purchase()`, `AppStore.sync()` — blocks forever on a "Sign in
    /// to Apple Account" sheet no test can tap, wedging the whole suite.
    ///
    /// An out-of-band buy is the cheap probe for it: it comes back
    /// `StoreKitError.notEntitled` in a fraction of a second on a device with no
    /// local store, and succeeds instantly on a healthy one. The transaction it
    /// leaves behind is cleared immediately, so the probe is invisible to the
    /// test that follows.
    ///
    /// It buys the MONTHLY plan on purpose. The yearly one carries the group's
    /// single introductory offer, and probing with it would spend that offer —
    /// leaving `testIntroOfferEligibilityFlipsOnceTheGroupsOfferIsUsed` betting
    /// that `clearTransactions()` hands eligibility back. The monthly plan has
    /// no offer, so there is no bet to lose.
    @MainActor
    private func requireLocalStore(_ session: SKTestSession) async throws {
        do {
            try await session.buyProduct(identifier: SubscriptionManager.monthlyID)
        } catch {
            throw XCTSkip("""
                This simulator is not serving Nenita.storekit (\(error)). Restore \
                the binding by launching the app once from Xcode on the BabyBloom \
                scheme — its run action carries the configuration — then re-run.
                """)
        }
        session.clearTransactions()
    }

    // MARK: - The store itself

    /// The paywall's whole contract with StoreKit: three products in one group,
    /// each with a price the App Store returned, and the group's single
    /// introductory offer sitting on the yearly plan. The 2026-08-27 rule —
    /// prices, savings and trial lengths are never written in source — only
    /// holds if these actually arrive.
    @MainActor
    func testProductsAndPricesComeFromTheShippedConfiguration() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        try await requireLocalStore(session)

        let manager = await makeLoadedManager()

        let yearly = try XCTUnwrap(manager.yearlyProduct)
        let monthly = try XCTUnwrap(manager.monthlyProduct)
        let weekly = try XCTUnwrap(manager.weeklyProduct)
        XCTAssertNil(manager.purchaseError)

        for product in [yearly, monthly, weekly] {
            XCTAssertFalse(product.displayPrice.isEmpty, "\(product.id) must carry a price")
            XCTAssertNotNil(product.subscription, "\(product.id) must be auto-renewable")
        }

        XCTAssertEqual(yearly.subscription?.introductoryOffer?.paymentMode, .freeTrial,
                       "the yearly plan is the one the CTA promises a trial on")
        XCTAssertNil(monthly.subscription?.introductoryOffer,
                     "and the monthly plan has none, which is why the CTA reads per plan")

        // The badge is arithmetic over two fetched prices, never a constant.
        XCTAssertNotNil(
            SubscriptionManager.savingsPercent(of: yearly.price, per: .year, count: 1,
                                               comparedTo: monthly.price, per: .month, count: 1),
            "yearly must annualize cheaper than monthly or the badge is a lie"
        )
    }

    // MARK: - Fresh purchase

    @MainActor
    func testBuyingTheYearlyPlanEntitlesTheUser() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        try await requireLocalStore(session)

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
        try await requireLocalStore(session)
        try await session.buyProduct(identifier: SubscriptionManager.yearlyID)

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
        try await requireLocalStore(session)
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
        try await requireLocalStore(session)
        session.failTransactionsEnabled = true
        session.failureError = .paymentCancelled

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct)

        await manager.purchase(yearly)

        XCTAssertFalse(manager.isEntitled)
        XCTAssertFalse(manager.isLoading)
        XCTAssertFalse(manager.purchasePending)
        XCTAssertTrue(manager.hasResolvedEntitlements,
                      "a purchase that did not happen still leaves StoreKit's answer read")
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
        try await requireLocalStore(session)

        let manager = await makeLoadedManager()
        let yearly = try XCTUnwrap(manager.yearlyProduct)
        await manager.purchase(yearly)
        XCTAssertTrue(manager.isEntitled)

        await manager.purchase(yearly)

        XCTAssertTrue(manager.isEntitled, "buying again must not drop what is owned")
        XCTAssertTrue(manager.isPremium)
        XCTAssertFalse(manager.isLoading)
    }

    /// **Build 9's exact shape.** The Apple ID already owns the subscription,
    /// nothing in onboarding has asked StoreKit yet, and the user taps
    /// Subscribe. StoreKit raises "You are currently subscribed" and completes
    /// no purchase — so nothing about the outcome carries the entitlement, and
    /// the only thing that can surface it is `purchase()` re-reading
    /// entitlements on a non-success result.
    ///
    /// The abandonment is forced rather than left to SKTestSession's choice
    /// about re-buying an owned subscription: this has to land on the
    /// `.userCancelled`/error path deterministically, or it pins nothing.
    /// The forced `.paymentCancelled` lands on exactly ONE of the two re-reads
    /// per OS — whichever path this OS routes it through has its re-read
    /// pinned by this test; the sibling path is exercised only on OSes that
    /// route the failure the other way.
    @MainActor
    func testAnAbandonedPurchaseStillResolvesAnEntitlementTheAppleIDAlreadyHas() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        try await requireLocalStore(session)
        try await session.buyProduct(identifier: SubscriptionManager.yearlyID)

        // Fresh manager: `isEntitled` is false because nobody has asked, which
        // is precisely the state onboarding reached the paywall in.
        let manager = SubscriptionManager()
        await manager.loadProducts()
        XCTAssertFalse(manager.hasResolvedEntitlements, "nothing has asked StoreKit yet")
        XCTAssertFalse(manager.isEntitled)

        session.failTransactionsEnabled = true
        session.failureError = .paymentCancelled
        let yearly = try XCTUnwrap(manager.yearlyProduct)

        await manager.purchase(yearly)

        XCTAssertTrue(manager.hasResolvedEntitlements)
        XCTAssertTrue(manager.isEntitled,
                      "an abandoned purchase must still surface the subscription this ID owns")
        XCTAssertTrue(manager.isPremium, "and the host must therefore be able to advance")
    }

    // MARK: - Restore

    @MainActor
    func testRestoreReportsSuccessForAPurchaseMadeOutOfBand() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        try await requireLocalStore(session)
        try await session.buyProduct(identifier: SubscriptionManager.yearlyID)

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
        try await requireLocalStore(session)

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
        try await requireLocalStore(session)

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

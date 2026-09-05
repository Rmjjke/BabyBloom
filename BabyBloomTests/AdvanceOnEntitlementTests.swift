import XCTest
@testable import BabyBloom

/// The rule the onboarding paywall exits on.
///
/// The guard tests need no simulator and no StoreKit, which is the entire
/// point (the cancellation test at the bottom touches a real manager, but
/// still needs no StoreKit configuration): what
/// `mayAdvanceOnEntitlement` encodes is a RACE inside `restorePurchases()`, and
/// a race is the one thing a run-and-look pass cannot pin. The window is real —
/// `refreshEntitlements()` publishes `isEntitled` and then AWAITS the networked
/// intro-offer lookup before `restoreState` is assigned, and an `@Observable`
/// host is free to run in that gap.
final class AdvanceOnEntitlementTests: XCTestCase {

    private typealias Manager = SubscriptionManager

    // MARK: - The two ordinary answers

    func testAnEntitledUserWithNoRestoreInFlightAdvances() {
        XCTAssertTrue(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: true, isPremium: true,
            isRestoring: false, hasUnreadRestoreOutcome: false
        ))
    }

    func testAFreeUserNeverAdvances() {
        XCTAssertFalse(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: true, isPremium: false,
            isRestoring: false, hasUnreadRestoreOutcome: false
        ))
    }

    // MARK: - Unresolved is not "free"

    /// The build-9 defect in one assertion: before anything asks StoreKit,
    /// `isPremium` is false because nobody looked. Advancing is wrong here, but
    /// so is SELLING — which is what the page did.
    func testNothingIsDecidedBeforeStoreKitHasAnswered() {
        XCTAssertFalse(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: false, isPremium: false,
            isRestoring: false, hasUnreadRestoreOutcome: false
        ))
        XCTAssertFalse(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: false, isPremium: true,
            isRestoring: false, hasUnreadRestoreOutcome: false
        ))
    }

    // MARK: - The restore window, both halves

    /// **The race.** `isEntitled` is already true and `restoreState` has not
    /// been assigned yet, because `refreshEntitlements()` is still awaiting the
    /// intro-offer lookup. Advancing here ends onboarding before "Purchases
    /// restored" is ever drawn. Drop `isRestoring` from the guard and this is
    /// the test that fails.
    func testARestoreStillInFlightHoldsTheAdvanceEvenWithNoOutcomeYet() {
        XCTAssertFalse(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: true, isPremium: true,
            isRestoring: true, hasUnreadRestoreOutcome: false
        ))
    }

    /// The other half of the window: the restore has finished, the alert is up,
    /// and the user has not dismissed it yet.
    func testAnUnreadRestoreOutcomeHoldsTheAdvance() {
        XCTAssertFalse(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: true, isPremium: true,
            isRestoring: false, hasUnreadRestoreOutcome: true
        ))
    }

    /// And once it is dismissed — `clearRestoreState()` — the page advances.
    /// This is the restore path's actual exit.
    func testDismissingTheRestoreConfirmationReleasesTheAdvance() {
        XCTAssertTrue(Manager.mayAdvanceOnEntitlement(
            hasResolvedEntitlements: true, isPremium: true,
            isRestoring: false, hasUnreadRestoreOutcome: false
        ))
    }

    // MARK: - A cancelled resolution publishes nothing

    /// `Transaction.currentEntitlements` terminates EARLY when its task is
    /// cancelled — a paywall dismissed mid-scan does exactly that — and the
    /// loop then falls through with `active == false`. Publishing that would
    /// assert "resolved: not subscribed" about a user nobody finished
    /// checking, and `hasResolvedEntitlements` is precisely the flag the
    /// paywalls trust not to lie. Environment-proof: the guard sits AFTER the
    /// loop, so nothing is published regardless of what the sequence yields
    /// under cancellation.
    @MainActor
    func testACancelledRefreshLeavesEntitlementsUnresolved() async {
        let manager = SubscriptionManager()
        let task = Task { @MainActor in
            // Model a `.task` whose view died mid-flight, deterministically:
            // cancelled before the scan, not racing it.
            withUnsafeCurrentTask { $0?.cancel() }
            await manager.refreshEntitlements()
        }
        await task.value
        XCTAssertFalse(manager.hasResolvedEntitlements,
                       "a cancelled scan must not claim StoreKit answered")
        XCTAssertFalse(manager.isEntitled)
    }
}

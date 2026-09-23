import XCTest
import StoreKit
@testable import BabyBloom

/// `transactionFailedThisSession` feeds the review prompt's calm rule. A
/// cancel is the parent's choice and must not count; a genuine failure must.
/// Driven through the error seam because the StoreKit session tests that raise
/// these for real skip on a simulator without the local store binding.
@MainActor
final class TransactionFailureFlagTests: XCTestCase {

    func testCancellationShapesAreRecognised() {
        XCTAssertTrue(SubscriptionManager.isUserCancellation(SKError(.paymentCancelled)))
        XCTAssertTrue(SubscriptionManager.isUserCancellation(StoreKitError.userCancelled))
    }

    func testGenuineFailuresAreNotCancellations() {
        XCTAssertFalse(SubscriptionManager.isUserCancellation(SKError(.paymentInvalid)))
        XCTAssertFalse(SubscriptionManager.isUserCancellation(
            StoreKitError.networkError(URLError(.notConnectedToInternet))))
        XCTAssertFalse(SubscriptionManager.isUserCancellation(SubscriptionError.verificationFailed))
    }

    func testACancelDoesNotSetTheFlag() {
        let manager = SubscriptionManager()
        manager.recordTransactionError(SKError(.paymentCancelled))
        manager.recordTransactionError(StoreKitError.userCancelled)

        XCTAssertFalse(manager.transactionFailedThisSession)
        XCTAssertNotNil(manager.purchaseError, "the paywall's own handling is unchanged")
    }

    func testAGenuineFailureSetsTheFlagAndItStays() {
        let manager = SubscriptionManager()
        manager.recordTransactionError(SubscriptionError.verificationFailed)
        XCTAssertTrue(manager.transactionFailedThisSession)

        // A later cancel does not wash it out: sticky for the session.
        manager.recordTransactionError(SKError(.paymentCancelled))
        XCTAssertTrue(manager.transactionFailedThisSession)
    }
}

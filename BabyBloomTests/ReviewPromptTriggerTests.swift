import XCTest
import SwiftData
import SwiftUI
@testable import BabyBloom

/// The routing between a save and the one `requestReview` call. What the
/// simulator shows is one path at a time; these pin the rule behind all of
/// them — a sheet notes, only the outermost dismissal (or a save on a tab)
/// asks, and it asks once.
@MainActor
final class ReviewPromptTriggerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var service: ReviewPromptService!
    private var context: ModelContext!
    private var requests = 0

    override func setUp() async throws {
        suiteName = "ReviewPromptTriggerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        // A fixed noon: quiet hours would otherwise fail this suite at night.
        service = ReviewPromptService(defaults: defaults,
                                      calendar: ReviewPromptTestClock.calendar,
                                      clock: { ReviewPromptTestClock.noon })
        // Every threshold met, so any refusal below is the routing's doing.
        service.recordFirstLaunchIfNeeded(
            now: ReviewPromptTestClock.noon.addingTimeInterval(-10 * 86_400))
        let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                             DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        context = ModelContext(container)
        for _ in 0..<ReviewPromptPolicy.minimumEntries {
            context.insert(DiaperEntry(time: Date(), type: .wet))
        }
        try context.save()
        requests = 0
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func root() -> ReviewPromptTrigger {
        .live(service: service,
              context: context,
              transactionFailedThisSession: { false },
              request: { [unowned self] in self.requests += 1 })
    }

    func testASaveOnATabAsksImmediately() {
        root().entrySaved()
        XCTAssertEqual(requests, 1)
    }

    func testADeferredTriggerNotesTheSaveButNeverAsks() {
        let inSheet = root().deferred
        inSheet.entrySaved()
        inSheet.sheetDismissed()

        XCTAssertEqual(requests, 0)
        XCTAssertTrue(service.hasPendingSave, "the save waits for the outer dismissal")
    }

    /// The Dashboard's quick sheet hosts a tab screen, which presents its own
    /// add sheet: the inner dismissal must not ask, the outer one asks once.
    func testNestedSheetsAskOnlyOnTheOutermostDismissalAndOnlyOnce() {
        let tab = root()
        let quickSheet = tab.deferred
        let addSheet = quickSheet.deferred

        addSheet.entrySaved()
        quickSheet.sheetDismissed()   // the add sheet closes, inside the quick sheet
        XCTAssertEqual(requests, 0)

        tab.sheetDismissed()          // the quick sheet closes
        XCTAssertEqual(requests, 1)

        tab.sheetDismissed()          // nothing pending any more
        XCTAssertEqual(requests, 1)
    }

    /// Cancel dismisses a sheet too; with no save behind it nothing is asked.
    func testADismissalWithoutASaveNeverAsks() {
        root().sheetDismissed()
        XCTAssertEqual(requests, 0)
    }

    /// A paywall seen inside the quick sheet cancels the save before it.
    func testAPaywallInBetweenCancelsThePendingSave() {
        let tab = root()
        tab.deferred.entrySaved()
        service.discardPendingSave()
        tab.sheetDismissed()
        XCTAssertEqual(requests, 0)
    }

    /// Onboarding and previews see the environment's default, which must not
    /// reach any service at all.
    func testTheInertDefaultNeverRecordsASave() {
        let inert = EnvironmentValues().reviewPrompt
        XCTAssertTrue(inert.isDeferred)
        inert.entrySaved()
        inert.sheetDismissed()
        XCTAssertFalse(ReviewPromptService.shared.hasPendingSave)
        XCTAssertFalse(service.hasPendingSave)
        XCTAssertEqual(requests, 0)
    }
}

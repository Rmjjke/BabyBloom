import XCTest
import SwiftData
@testable import BabyBloom

/// Persistence and the pending-save handshake, against a private defaults
/// suite and an in-memory store.
@MainActor
final class ReviewPromptServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    /// The service's clock; tests move it to cross quiet hours or a day.
    private var clockNow = ReviewPromptTestClock.noon
    private let tenDaysAgo = ReviewPromptTestClock.noon.addingTimeInterval(-10 * 86_400)

    private func makeService() -> ReviewPromptService {
        ReviewPromptService(defaults: defaults,
                            calendar: ReviewPromptTestClock.calendar,
                            clock: { [unowned self] in self.clockNow })
    }

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeContext(entries: Int) throws -> ModelContext {
        let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                             DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        // Spread across all five kinds: the count is over every kind, and a
        // kind left out of it would show here as a threshold missed by four.
        for i in 0..<entries {
            switch i % 5 {
            case 0: context.insert(DiaperEntry(time: Date(), type: .wet))
            case 1: context.insert(FeedingEntry(startTime: Date(), type: .formula, side: nil, volumeML: 90))
            case 2: context.insert(SleepEntry(startTime: Date(), type: .nap))
            case 3: context.insert(GrowthEntry(date: Date(), weightKg: nil, heightCm: 55, headCircumferenceCm: nil))
            default: context.insert(CustomEvent(time: Date(), type: .bath))
            }
        }
        try context.save()
        return context
    }

    func testFirstLaunchIsWrittenOnceAndNeverMoved() {
        let service = makeService()
        let first = Date(timeIntervalSinceReferenceDate: 1_000)
        service.recordFirstLaunchIfNeeded(now: first)
        service.recordFirstLaunchIfNeeded(now: first.addingTimeInterval(86_400))
        XCTAssertEqual(service.firstLaunchDate, first)
    }

    /// Nothing but a save arms the request — a launch or a tab switch that
    /// reaches `consumePendingSave` finds nothing to answer.
    func testWithoutAPendingSaveNothingIsRequested() throws {
        let service = makeService()
        service.recordFirstLaunchIfNeeded(now: tenDaysAgo)
        let context = try makeContext(entries: 25)

        XCTAssertFalse(service.consumePendingSave(in: context, transactionFailedThisSession: false))
        XCTAssertNil(service.lastRequestDate)
    }

    func testEligibleSaveRequestsOnceAndRecordsIt() throws {
        let service = makeService()
        service.recordFirstLaunchIfNeeded(now: tenDaysAgo)
        let context = try makeContext(entries: 20)
        let now = clockNow

        service.noteEntrySaved()
        XCTAssertTrue(service.consumePendingSave(in: context, transactionFailedThisSession: false, now: now))
        XCTAssertFalse(service.hasPendingSave)
        XCTAssertEqual(service.lastRequestVersion, ReviewPromptService.currentVersion)
        XCTAssertEqual(service.lastRequestDate, now)

        // The next save in the same version is refused.
        service.noteEntrySaved()
        XCTAssertFalse(service.consumePendingSave(in: context, transactionFailedThisSession: false))
    }

    func testTooFewEntriesInTheStoreRefuses() throws {
        let service = makeService()
        service.recordFirstLaunchIfNeeded(now: tenDaysAgo)
        let context = try makeContext(entries: 19)

        service.noteEntrySaved()
        XCTAssertFalse(service.consumePendingSave(in: context, transactionFailedThisSession: false))
        XCTAssertFalse(service.hasPendingSave, "a refused save is consumed, not left armed")
    }

    func testFailedTransactionThisSessionRefuses() throws {
        let service = makeService()
        service.recordFirstLaunchIfNeeded(now: tenDaysAgo)
        let context = try makeContext(entries: 25)

        service.noteEntrySaved()
        XCTAssertFalse(service.consumePendingSave(in: context, transactionFailedThisSession: true))
        XCTAssertNil(service.lastRequestDate)
    }

    /// A save at night is refused and records NOTHING, so the version's one
    /// attempt is still there for the next daytime save.
    func testANightRefusalLeavesTheAttemptForTheNextDay() throws {
        let service = makeService()
        service.recordFirstLaunchIfNeeded(now: tenDaysAgo)
        let context = try makeContext(entries: 25)

        clockNow = ReviewPromptTestClock.date(2026, 9, 23, 23, 30)
        service.noteEntrySaved()
        XCTAssertFalse(service.consumePendingSave(in: context, transactionFailedThisSession: false))
        XCTAssertNil(service.lastRequestVersion, "nothing recorded at night")
        XCTAssertNil(service.lastRequestDate)

        clockNow = ReviewPromptTestClock.date(2026, 9, 24, 10, 0)
        service.noteEntrySaved()
        XCTAssertTrue(service.consumePendingSave(in: context, transactionFailedThisSession: false))
        XCTAssertEqual(service.lastRequestDate, clockNow)
    }
}

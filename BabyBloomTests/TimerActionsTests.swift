import XCTest
import SwiftData
@testable import BabyBloom

/// The timer mutation layer every screen and the Lock Screen's Stop share.
/// The point of the "exactly once" cases: a Stop tapped twice, or after the
/// app already stopped the timer, must not move the saved end time (R2.3).
@MainActor
final class TimerActionsTests: XCTestCase {

    private var afterChangeCalls = 0
    private var savedAfterChange: (@MainActor () -> Void)!

    override func setUp() async throws {
        afterChangeCalls = 0
        savedAfterChange = TimerActions.afterChange
        // Never reconcile real activities against the real store from a test.
        TimerActions.afterChange = { [unowned self] in self.afterChangeCalls += 1 }
    }

    override func tearDown() async throws {
        TimerActions.afterChange = savedAfterChange
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                             DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        context.insert(Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast))
        try context.save()
        return context
    }

    func testStartBreastfeedCreatesARunningLeftFeed() throws {
        let context = try makeContext()
        let entry = TimerActions.startBreastfeed(in: context)
        XCTAssertNil(entry.endTime)
        XCTAssertEqual(entry.type, .breast)
        XCTAssertEqual(entry.side, .left)
        XCTAssertNotNil(entry.baby, "a timer is owned by the baby, as the screens set it")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedingEntry>()), 1)
    }

    /// D16: the widget starts a left breastfeed, and never a second feed while
    /// one of any kind (a bottle included) runs.
    func testWidgetStartsOneFeedOnly() throws {
        let context = try makeContext()
        XCTAssertTrue(TimerActions.startFeedingFromWidget(in: context))
        XCTAssertFalse(TimerActions.startFeedingFromWidget(in: context))
        let feeds = try context.fetch(FetchDescriptor<FeedingEntry>())
        XCTAssertEqual(feeds.count, 1)
        XCTAssertEqual(feeds.first?.side, .left)

        let other = try makeContext()
        other.insert(FeedingEntry(startTime: Date(), type: .formula, side: nil, volumeML: 90))
        try other.save()
        afterChangeCalls = 0
        XCTAssertFalse(TimerActions.startFeedingFromWidget(in: other), "a running bottle counts")
        XCTAssertEqual(afterChangeCalls, 0)
    }

    /// The widget can sit on the Home Screen before onboarding: no Baby, no feed.
    func testWidgetStartsNothingBeforeOnboarding() throws {
        let context = try makeContext()
        try context.delete(model: Baby.self)
        try context.save()
        XCTAssertFalse(TimerActions.startFeedingFromWidget(in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedingEntry>()), 0)
        XCTAssertEqual(afterChangeCalls, 0)
    }

    func testStopSetsEndTimeAndReturnsTrue() throws {
        let context = try makeContext()
        let entry = TimerActions.startSleep(.nap, in: context)
        let end = Date().addingTimeInterval(60)
        XCTAssertTrue(TimerActions.stop(entryID: entry.id, kind: .sleep, at: end, in: context))
        XCTAssertEqual(entry.endTime, end)
    }

    func testStopTwiceWritesOnce() throws {
        let context = try makeContext()
        let entry = TimerActions.startBreastfeed(in: context)
        let first = Date().addingTimeInterval(60)
        XCTAssertTrue(TimerActions.stop(entryID: entry.id, kind: .feeding, at: first, in: context))
        XCTAssertFalse(TimerActions.stop(entryID: entry.id, kind: .feeding,
                                         at: first.addingTimeInterval(300), in: context))
        XCTAssertEqual(entry.endTime, first, "the second stop must not move the end time")
    }

    func testStopOfDeletedEntryIsANoOp() throws {
        let context = try makeContext()
        let entry = TimerActions.startBreastfeed(in: context)
        let id = entry.id
        TimerActions.delete(feedings: [entry], in: context)
        afterChangeCalls = 0
        XCTAssertFalse(TimerActions.stop(entryID: id, kind: .feeding, in: context))
        XCTAssertEqual(afterChangeCalls, 0, "a no-op stop changes nothing, so nothing reconciles")
    }

    func testStopIgnoresTheWrongKind() throws {
        let context = try makeContext()
        let entry = TimerActions.startBreastfeed(in: context)
        XCTAssertFalse(TimerActions.stop(entryID: entry.id, kind: .sleep, in: context))
        XCTAssertNil(entry.endTime)
    }

    func testSetSideSaves() throws {
        let context = try makeContext()
        let entry = TimerActions.startBreastfeed(in: context)
        TimerActions.setSide(.right, of: entry, in: context)
        XCTAssertEqual(entry.side, .right)
        XCTAssertFalse(context.hasChanges, "the side is saved, not left to autosave")
    }

    func testDeleteRemovesEntries() throws {
        let context = try makeContext()
        let feed = TimerActions.startBreastfeed(in: context)
        let nap = TimerActions.startSleep(.nap, in: context)
        TimerActions.delete(feedings: [feed], in: context)
        TimerActions.delete(sleeps: [nap], in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<FeedingEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SleepEntry>()), 0)
    }

    func testAfterChangeRunsOncePerMutation() throws {
        let context = try makeContext()
        let feed = TimerActions.startBreastfeed(in: context)
        TimerActions.setSide(.both, of: feed, in: context)
        TimerActions.stop(entryID: feed.id, kind: .feeding, in: context)
        TimerActions.delete(feedings: [feed], in: context)
        XCTAssertEqual(afterChangeCalls, 4)
    }
}

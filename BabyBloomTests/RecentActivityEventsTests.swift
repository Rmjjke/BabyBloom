import XCTest
import SwiftData
@testable import BabyBloom

/// Events join Recent activity's list: one merged order, the same window and
/// cap, and a delete that saves.
@MainActor
final class RecentActivityEventsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        return ModelContext(container)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

    /// The screen's own composition: merge, window, cap.
    private func windowed(feeds: [FeedingEntry] = [], diapers: [DiaperEntry] = [],
                          events: [CustomEvent] = [], cutoff: Date? = nil) -> HistoryWindow.List<RecentEvent> {
        RecentEvent.windowed(feeds: feeds, sleeps: [], diapers: diapers, events: events, cutoff: cutoff)
    }

    func testFeedEventAndDiaperMergeByTime() {
        let feed = FeedingEntry(startTime: ago(3), type: .formula)
        let event = CustomEvent(time: ago(2), type: .bath)
        let diaper = DiaperEntry(time: ago(1), type: .wet)
        let list = windowed(feeds: [feed], diapers: [diaper], events: [event]).visible
        XCTAssertEqual(list.map { $0.eventTime }, [ago(1), ago(2), ago(3)])
        if case .event = list[1] {} else { XCTFail("the event sits between the diaper and the feed") }
    }

    func testTheWindowDropsAnOldEventAndRaisesTheFooter() {
        let fresh = CustomEvent(time: ago(1), type: .walk)
        let old = CustomEvent(time: ago(24 * 20), type: .bath)
        let list = windowed(events: [fresh, old], cutoff: ago(24 * 5))
        XCTAssertEqual(list.visible.count, 1)
        XCTAssertTrue(list.showsLockedFooter)
    }

    func testTheWindowComesBeforeTheCap() {
        // 25 events inside the window and one older: the cap, not the
        // window, hides rows, so the footer stays down.
        let recent = (0..<25).map { CustomEvent(time: ago(Double($0)), type: .bath) }
        let list = windowed(events: recent, cutoff: ago(24 * 5))
        XCTAssertEqual(list.visible.count, 20)
        XCTAssertFalse(list.showsLockedFooter)
    }

    func testTheCapCountsEvents() {
        let events = (0..<25).map { CustomEvent(time: ago(Double($0)), type: .bath) }
        let list = windowed(events: events)
        XCTAssertEqual(list.visible.count, 20)
        XCTAssertEqual(list.deletable.count, 25)
    }

    func testAnEventAloneIsNotTheEmptyState() {
        let list = windowed(events: [CustomEvent(time: ago(1), type: .mood)])
        XCTAssertFalse(list.deletable.isEmpty)
    }

    func testDeletingADoseRemovesItAndSaves() throws {
        let context = try makeContext()
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        context.insert(medicine)
        let dose = CustomEvent.dose(of: medicine, at: ago(1))
        context.insert(dose)
        try context.save()

        let saved = expectation(forNotification: ModelContext.didSave, object: nil)
        RecentEvent.delete(dose, in: context)
        wait(for: [saved], timeout: 2)

        XCTAssertTrue(try context.fetch(FetchDescriptor<CustomEvent>()).isEmpty)
    }
}

import XCTest
@testable import BabyBloom

/// The Live Activity's decisions, without ActivityKit. Every rule the app and
/// the Lock Screen must agree on lives in `LiveActivityPlanner.plan`, so this
/// file is the contract: the ActivityKit glue only executes what it returns.
final class LiveActivityPlannerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let open = LiveActivityGate(switchOn: true, systemEnabled: true, isPad: false)

    private func timer(_ kind: TimerKind, _ title: TimerTitle, minutesAgo: Double,
                       id: UUID = UUID()) -> RunningTimer {
        RunningTimer(entryID: id, kind: kind, title: title,
                     startTime: now.addingTimeInterval(-minutesAgo * 60))
    }

    private func activity(for t: RunningTimer, id: String = "A", title: TimerTitle? = nil,
                          isLive: Bool = true) -> ActivitySnapshot {
        ActivitySnapshot(activityID: id, entryID: t.entryID, kind: t.kind,
                         title: title ?? t.title, isLive: isLive)
    }

    private func plan(running: [RunningTimer] = [], stoppedAt: [UUID: Date] = [:],
                      activities: [ActivitySnapshot] = [], alreadyStarted: Set<UUID> = [],
                      gate: LiveActivityGate? = nil) -> [LiveActivityAction] {
        LiveActivityPlanner.plan(running: running, stoppedAt: stoppedAt, activities: activities,
                                 alreadyStarted: alreadyStarted, gate: gate ?? open, now: now)
    }

    func testStartsOneActivityPerKindForAFreshTimer() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 1)
        let nap = timer(.sleep, .nap, minutesAgo: 5)
        let actions = plan(running: [feed, nap])
        XCTAssertEqual(Set(actions.map(String.init(describing:))),
                       Set([LiveActivityAction.start(feed), .start(nap)].map(String.init(describing:))))
    }

    func testOnlyTheNewestRunningEntryPerKindGetsAnActivity() {
        let older = timer(.feeding, .breastLeft, minutesAgo: 30)
        let newer = timer(.feeding, .bottle, minutesAgo: 2)
        XCTAssertEqual(plan(running: [older, newer]), [.start(newer)])
        // An activity already shown for the older one gives way.
        XCTAssertEqual(plan(running: [older, newer], activities: [activity(for: older)]),
                       [.endImmediately(activityID: "A"), .start(newer)])
    }

    func testUpdatesTitleWhenSideChanges() {
        let feed = timer(.feeding, .breastRight, minutesAgo: 3)
        XCTAssertEqual(plan(running: [feed], activities: [activity(for: feed, title: .breastLeft)],
                            alreadyStarted: [feed.entryID]),
                       [.update(activityID: "A", title: .breastRight)])
        XCTAssertEqual(plan(running: [feed], activities: [activity(for: feed)],
                            alreadyStarted: [feed.entryID]), [])
    }

    func testStoppedEntryEndsSavedWithItsEndTime() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 14)
        let endedAt = now.addingTimeInterval(-10)
        XCTAssertEqual(plan(stoppedAt: [feed.entryID: endedAt], activities: [activity(for: feed)]),
                       [.endSaved(activityID: "A", endedAt: endedAt)])
    }

    func testDeletedEntryEndsImmediately() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 14)
        XCTAssertEqual(plan(activities: [activity(for: feed)]), [.endImmediately(activityID: "A")])
    }

    /// A user who swiped the activity away must not see it come back on the
    /// next foreground: an entry gets one start.
    func testDoesNotRestartAnEntryAlreadyStarted() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 20)
        XCTAssertEqual(plan(running: [feed], alreadyStarted: [feed.entryID]), [])
    }

    func testNoStartAtOrAfterEightHours() {
        let atLimit = timer(.sleep, .night, minutesAgo: 8 * 60)
        XCTAssertEqual(plan(running: [atLimit]), [])
        let justUnder = RunningTimer(entryID: UUID(), kind: .sleep, title: .night,
                                     startTime: now.addingTimeInterval(-8 * 3600 + 1))
        XCTAssertEqual(plan(running: [justUnder]), [.start(justUnder)])
    }

    func testGateClosedEndsEverythingImmediately() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 5)
        let nap = timer(.sleep, .nap, minutesAgo: 5)
        let live = [activity(for: feed, id: "F"), activity(for: nap, id: "S")]
        for gate in [LiveActivityGate(switchOn: false, systemEnabled: true, isPad: false),
                     LiveActivityGate(switchOn: true, systemEnabled: false, isPad: false),
                     LiveActivityGate(switchOn: true, systemEnabled: true, isPad: true)] {
            XCTAssertEqual(plan(running: [feed, nap], activities: live, gate: gate),
                           [.endImmediately(activityID: "F"), .endImmediately(activityID: "S")],
                           "\(gate)")
        }
    }

    func testEndedActivitiesAreIgnored() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 14)
        XCTAssertEqual(plan(stoppedAt: [feed.entryID: now], activities: [activity(for: feed, isLive: false)]), [])
    }

    func testTitleMapping() {
        func feed(_ type: FeedingEntry.FeedingType, _ side: FeedingEntry.BreastSide?) -> FeedingEntry {
            FeedingEntry(startTime: now, type: type, side: side, volumeML: nil)
        }
        XCTAssertEqual(TimerTitle.of(feed(.breast, nil)), .breast)
        XCTAssertEqual(TimerTitle.of(feed(.breast, .left)), .breastLeft)
        XCTAssertEqual(TimerTitle.of(feed(.breast, .right)), .breastRight)
        XCTAssertEqual(TimerTitle.of(feed(.breast, .both)), .breastBoth)
        XCTAssertEqual(TimerTitle.of(feed(.formula, nil)), .bottle)
        XCTAssertEqual(TimerTitle.of(feed(.pumped, .left)), .bottle)
        XCTAssertEqual(TimerTitle.of(SleepEntry(startTime: now, type: .nap)), .nap)
        XCTAssertEqual(TimerTitle.of(SleepEntry(startTime: now, type: .night)), .night)
        XCTAssertEqual(TimerTitle.breastLeft.key, "live_activity.title.bf_left")
        XCTAssertEqual(TimerTitle.bottle.key, "live_activity.title.bottle")
    }
}

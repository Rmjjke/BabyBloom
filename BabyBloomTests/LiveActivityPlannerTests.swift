import XCTest
@testable import BabyBloom

/// The Live Activity's decisions, without ActivityKit. Every rule the app and
/// the Lock Screen must agree on lives in `LiveActivityPlanner`, so this file
/// is the contract: the ActivityKit glue only executes what it returns.
final class LiveActivityPlannerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let open = LiveActivityGate(switchOn: true, systemEnabled: true, isPad: false)
    private let closedGates = [LiveActivityGate(switchOn: false, systemEnabled: true, isPad: false),
                               LiveActivityGate(switchOn: true, systemEnabled: false, isPad: false),
                               LiveActivityGate(switchOn: true, systemEnabled: true, isPad: true)]

    private func timer(_ kind: TimerKind, _ title: TimerTitle, minutesAgo: Double,
                       id: UUID = UUID()) -> RunningTimer {
        RunningTimer(entryID: id, kind: kind, title: title,
                     startTime: now.addingTimeInterval(-minutesAgo * 60))
    }

    private func activity(for t: RunningTimer, id: String = "A", title: TimerTitle? = nil,
                          phase: ActivitySnapshot.Phase = .live,
                          showsSaved: Bool = false) -> ActivitySnapshot {
        ActivitySnapshot(activityID: id, entryID: t.entryID, kind: t.kind,
                         title: title ?? t.title, phase: phase, showsSaved: showsSaved)
    }

    private func plan(running: [RunningTimer] = [], stopped: [UUID: StoppedTimer] = [:],
                      activities: [ActivitySnapshot] = [], alreadyStarted: Set<UUID> = [],
                      gate: LiveActivityGate? = nil) -> [LiveActivityAction] {
        LiveActivityPlanner.plan(running: running, stopped: stopped, activities: activities,
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

    /// "Saved" shows the store's title: a side changed just before the stop
    /// is in the final state even if the activity never got the update.
    func testStoppedEntryEndsSavedWithItsEndTimeAndStoreTitle() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 14)
        let endedAt = now.addingTimeInterval(-10)
        XCTAssertEqual(plan(stopped: [feed.entryID: StoppedTimer(endedAt: endedAt, title: .breastRight)],
                            activities: [activity(for: feed)]),
                       [.endSaved(activityID: "A", endedAt: endedAt, title: .breastRight)])
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

    /// After a re-arm the started set is empty, yet an activity still shown
    /// (or still being ended) must not get a twin.
    func testALiveActivityCoversItsEntryWithoutAStartRecord() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 20)
        XCTAssertEqual(plan(running: [feed], activities: [activity(for: feed)]), [])
    }

    func testNoStartAtOrAfterEightHours() {
        let atLimit = timer(.sleep, .night, minutesAgo: 8 * 60)
        XCTAssertEqual(plan(running: [atLimit]), [])
        let justUnder = RunningTimer(entryID: UUID(), kind: .sleep, title: .night,
                                     startTime: now.addingTimeInterval(-8 * 3600 + 1))
        XCTAssertEqual(plan(running: [justUnder]), [.start(justUnder)])
    }

    /// Past 8 h the app leaves a still-live activity alone, and still ends it
    /// "Saved" when the timer stops.
    func testAnActivityPastEightHoursIsKeptThenEndsSaved() {
        let night = timer(.sleep, .night, minutesAgo: 9 * 60)
        XCTAssertEqual(plan(running: [night], activities: [activity(for: night)],
                            alreadyStarted: [night.entryID]), [])
        let saved = StoppedTimer(endedAt: now, title: .night)
        XCTAssertEqual(plan(stopped: [night.entryID: saved], activities: [activity(for: night)]),
                       [.endSaved(activityID: "A", endedAt: now, title: .night)])
    }

    func testGateClosedEndsEverythingImmediatelyAndStartsNothing() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 5)
        let nap = timer(.sleep, .nap, minutesAgo: 5)
        let shown = [activity(for: feed, id: "F"), activity(for: nap, id: "S", phase: .ended)]
        for gate in closedGates {
            XCTAssertEqual(plan(running: [feed, nap], activities: shown, gate: gate),
                           [.endImmediately(activityID: "F"), .endImmediately(activityID: "S")],
                           "\(gate)")
            XCTAssertEqual(plan(running: [feed, nap], gate: gate), [], "\(gate)")
        }
    }

    /// iOS ends an activity at ~8 h but keeps it on the Lock Screen with its
    /// Stop button. When that timer stops, the card must not keep saying
    /// "the timer goes on".
    func testEndedByTheSystemGetsFinalContentOnceItsTimerStops() {
        let night = timer(.sleep, .night, minutesAgo: 9 * 60)
        let ended = activity(for: night, phase: .ended)
        XCTAssertEqual(plan(running: [night], activities: [ended], alreadyStarted: [night.entryID]), [],
                       "still running: left as iOS ended it")
        XCTAssertEqual(plan(stopped: [night.entryID: StoppedTimer(endedAt: now, title: .night)],
                            activities: [ended]),
                       [.endSaved(activityID: "A", endedAt: now, title: .night)])
        XCTAssertEqual(plan(activities: [ended]), [.endImmediately(activityID: "A")], "deleted")
        XCTAssertEqual(plan(stopped: [night.entryID: StoppedTimer(endedAt: now, title: .night)],
                            activities: [activity(for: night, phase: .ended, showsSaved: true)]),
                       [], "already shows Saved")
    }

    func testDismissedActivitiesAreIgnored() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 14)
        XCTAssertEqual(plan(stopped: [feed.entryID: StoppedTimer(endedAt: now, title: .breastLeft)],
                            activities: [activity(for: feed, phase: .gone)]), [])
        XCTAssertEqual(plan(activities: [activity(for: feed, phase: .gone)], gate: closedGates[0]), [])
    }

    /// Switching off (in the app or in iOS) and on again shows the
    /// running timer again; with the gate open, starts are kept per running entry.
    func testAClosedGateForgetsStartsSoReopeningRearms() {
        let feed = timer(.feeding, .breastLeft, minutesAgo: 20)
        let gone = UUID()
        for gate in closedGates {
            XCTAssertEqual(remembered([feed.entryID], running: [feed], gate: gate), [], "\(gate)")
        }
        XCTAssertEqual(remembered([feed.entryID, gone], running: [feed]), [feed.entryID])
        XCTAssertEqual(plan(running: [feed], alreadyStarted: []), [.start(feed)])
    }

    private func remembered(_ started: Set<UUID>, running: [RunningTimer],
                            activities: [ActivitySnapshot] = [], gate: LiveActivityGate? = nil,
                            startedBuild: String? = "1.4.0 (31)",
                            currentBuild: String = "1.4.0 (31)") -> Set<UUID> {
        LiveActivityPlanner.remembered(started, running: running, activities: activities,
                                       gate: gate ?? open, startedBuild: startedBuild,
                                       currentBuild: currentBuild)
    }

    /// An update ends the activity the way a swipe does: a start recorded
    /// under another build, or with no build (1.3.0 and earlier), earns the
    /// running timer one fresh start with its own start time.
    func testAnUpdateGivesARunningTimerOneFreshStart() {
        let nap = timer(.sleep, .nap, minutesAgo: 3)
        for startedBuild in [nil, "1.3.0 (30)", "1.4.0 (30)"] as [String?] {
            let started = remembered([nap.entryID], running: [nap], startedBuild: startedBuild)
            XCTAssertEqual(started, [], "\(String(describing: startedBuild))")
            let actions = plan(running: [nap], alreadyStarted: started)
            XCTAssertEqual(actions, [.start(nap)], "\(String(describing: startedBuild))")
            if case .start(let t) = actions.first {
                XCTAssertEqual(t.startTime, nap.startTime)
            }
        }
    }

    /// Inside one build an activity the user swiped away stays away.
    func testInsideOneBuildASwipedActivityStaysAway() {
        let nap = timer(.sleep, .nap, minutesAgo: 3)
        let swiped = activity(for: nap, phase: .gone)
        let started = remembered([nap.entryID], running: [nap], activities: [swiped])
        XCTAssertEqual(started, [nap.entryID])
        XCTAssertEqual(plan(running: [nap], activities: [swiped], alreadyStarted: started), [])
        XCTAssertEqual(plan(running: [nap], alreadyStarted: remembered([nap.entryID], running: [nap])), [])
    }

    /// An activity that survived the update is not started twice, and stays
    /// remembered, so a swipe after the update keeps it away.
    func testAnActivityThatSurvivedTheUpdateIsNotStartedTwice() {
        let feed = timer(.feeding, .breastRight, minutesAgo: 10)
        let live = activity(for: feed)
        let started = remembered([feed.entryID], running: [feed], activities: [live], startedBuild: nil)
        XCTAssertEqual(started, [feed.entryID])
        XCTAssertEqual(plan(running: [feed], activities: [live], alreadyStarted: started), [])
        XCTAssertEqual(plan(running: [feed], activities: [activity(for: feed, phase: .gone)],
                            alreadyStarted: started), [])
    }

    /// An update that leaves the old build's activity ended but on the Lock
    /// Screen: the fresh start replaces it, so the timer has one card.
    func testAnEndedCardLeftByTheUpdateIsReplacedNotDoubled() {
        let nap = timer(.sleep, .nap, minutesAgo: 30)
        let ended = activity(for: nap, id: "old", phase: .ended)
        let started = remembered([nap.entryID], running: [nap], activities: [ended], startedBuild: "1.3.0 (30)")
        XCTAssertEqual(started, [])
        XCTAssertEqual(plan(running: [nap], activities: [ended], alreadyStarted: started),
                       [.endImmediately(activityID: "old"), .start(nap)])
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

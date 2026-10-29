import ActivityKit
import CoreData
import Foundation
import os
import SwiftData
import UIKit

/// Keeps the Live Activities in step with the store: it reads what is running,
/// asks `LiveActivityPlanner` what should change, and does it.
///
/// Called after every timer mutation (`TimerActions`), on launch, on every
/// foregrounding, on store changes synced from another device, and when the
/// Settings switch or the iOS permission changes. Nothing pushes; a stop made
/// on another phone reaches this Lock Screen when the app next runs here
/// (R3.4, accepted by the owner for M1).
@MainActor @Observable
final class LiveActivitySync {
    static let shared = LiveActivitySync()

    /// Whether iOS allows Live Activities for the app. Observed by Settings.
    private(set) var systemEnabled: Bool

    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var remoteChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var pendingRemoteReconcile: Task<Void, Never>?
    /// The last ActivityKit call in flight; each new one waits for it.
    @ObservationIgnored private var tail: Task<Void, Never>?

    private static let log = Logger(subsystem: "com.nenita.app", category: "LiveActivity")

    private init() {
        systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Subscribes once. The root `.onAppear` re-fires on every language change
    /// (`.id(appLanguage)`), so this must be safe to call again.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        Task { [weak self] in
            for await enabled in ActivityAuthorizationInfo().activityEnablementUpdates {
                guard let self else { return }
                // iOS off removed every activity. Forget the starts here too, not
                // only in a reconcile: by the time one runs, the fresh read may
                // already say "on" again (QA Q4).
                if !enabled { LiveActivitySettings.startedEntryIDs = [] }
                self.systemEnabled = enabled
                self.reconcile()
            }
        }

        // The block-based observer, not `notifications(named:)`: `Notification`
        // is not Sendable and cannot cross onto the main actor under Swift 6.
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { LiveActivitySync.shared.remoteStoreChanged() }
        }
        reconcile()
    }

    /// The Settings switch. Waits for any end in flight: switched off and on
    /// quickly, the activity being ended would still count as shown, and the
    /// running timer would get no new one until the next foreground.
    func switchChanged() {
        Task {
            await settle()
            reconcile()
        }
    }

    /// Returns once every ActivityKit call queued so far has finished. The Stop
    /// intent awaits it: iOS may suspend the app as soon as the intent returns,
    /// and the Lock Screen must not keep ticking until the next launch.
    func settle() async {
        await tail?.value
    }

    /// CloudKit imports arrive in bursts; one reconcile per burst is enough.
    private func remoteStoreChanged() {
        Self.log.debug("Store changed remotely; reconciling")
        pendingRemoteReconcile?.cancel()
        pendingRemoteReconcile = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    func reconcile() {
        // Read fresh every time: the Stop intent can launch the app in the
        // background with no scene, where `start()` never ran.
        systemEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

        let context = SharedStore.container.mainContext
        let feeds = (try? context.fetch(FetchDescriptor<FeedingEntry>(
            predicate: #Predicate { $0.endTime == nil }))) ?? []
        let sleeps = (try? context.fetch(FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.endTime == nil }))) ?? []
        let running = feeds.map { RunningTimer(entryID: $0.id, kind: .feeding,
                                               title: .of($0), startTime: $0.startTime) }
                    + sleeps.map { RunningTimer(entryID: $0.id, kind: .sleep,
                                                title: .of($0), startTime: $0.startTime) }

        let snapshots = Activity<TimerActivityAttributes>.activities.map {
            ActivitySnapshot(activityID: $0.id, entryID: $0.attributes.entryID,
                             kind: $0.attributes.kind, title: $0.content.state.title,
                             phase: Self.phase($0.activityState),
                             showsSaved: $0.content.state.endedAt != nil)
        }
        let runningIDs = Set(running.map(\.entryID))
        var stopped: [UUID: StoppedTimer] = [:]
        for snapshot in snapshots where !runningIDs.contains(snapshot.entryID) {
            stopped[snapshot.entryID] = stoppedTimer(snapshot.entryID, kind: snapshot.kind, in: context)
        }

        let gate = LiveActivityGate(switchOn: LiveActivitySettings.isEnabled,
                                    systemEnabled: systemEnabled,
                                    isPad: UIDevice.current.userInterfaceIdiom == .pad)
        var started = LiveActivityPlanner.remembered(LiveActivitySettings.startedEntryIDs,
                                                     running: running, gate: gate)
        let actions = LiveActivityPlanner.plan(running: running, stopped: stopped,
                                               activities: snapshots, alreadyStarted: started,
                                               gate: gate, now: Date())
        for action in actions {
            switch action {
            case .start(let timer):
                if request(timer) { started.insert(timer.entryID) }
            case .update(let id, let title):
                Self.log.debug("Live Activity action: \(String(describing: action), privacy: .public)")
                enqueue { await Self.update(id, title: title) }
            case .endSaved(let id, let endedAt, let title):
                Self.log.info("Live Activity action: \(String(describing: action), privacy: .public)")
                enqueue { await Self.endSaved(id, endedAt: endedAt, title: title) }
            case .endImmediately(let id):
                Self.log.info("Live Activity action: \(String(describing: action), privacy: .public)")
                enqueue { await Self.endImmediately(id) }
            }
        }
        LiveActivitySettings.startedEntryIDs = started
    }

    /// One call at a time, in the order reconcile decided them: a quick
    /// left-right-left must end on left, and a side change made just before a
    /// stop must land before the "Saved" state.
    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = tail
        tail = Task {
            await previous?.value
            await work()
        }
    }

    private static func phase(_ state: ActivityState) -> ActivitySnapshot.Phase {
        switch state {
        case .ended: .ended
        case .dismissed: .gone
        // `.active`, `.stale`, and states newer than this code: counting them
        // as shown can cost an extra end call, never a duplicate activity.
        default: .live
        }
    }

    /// Records a start only when iOS accepted it: a request made from a
    /// background launch throws, and must not use up the entry's one start.
    private func request(_ timer: RunningTimer) -> Bool {
        let attributes = TimerActivityAttributes(entryID: timer.entryID, kind: timer.kind,
                                                 startTime: timer.startTime)
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(title: timer.title, endedAt: nil),
            staleDate: timer.startTime.addingTimeInterval(LiveActivityPlanner.maxAge),
            relevanceScore: Self.runningRelevance)
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            _ = Analytics.shared.track(.liveActivityStarted)
            Self.log.info("Live Activity started: \(timer.kind.rawValue, privacy: .public)")
            return true
        } catch {
            Self.log.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The entry's end time and title, or nil when it is still running or gone.
    private func stoppedTimer(_ id: UUID, kind: TimerKind, in context: ModelContext) -> StoppedTimer? {
        switch kind {
        case .feeding:
            var descriptor = FetchDescriptor<FeedingEntry>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let entry = (try? context.fetch(descriptor))?.first,
                  let endedAt = entry.endTime else { return nil }
            return StoppedTimer(endedAt: endedAt, title: .of(entry))
        case .sleep:
            var descriptor = FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            guard let entry = (try? context.fetch(descriptor))?.first,
                  let endedAt = entry.endTime else { return nil }
            return StoppedTimer(endedAt: endedAt, title: .of(entry))
        }
    }

    // `Activity` is not Sendable, so it is looked up by id INSIDE these
    // nonisolated functions and never crosses from the main actor.

    nonisolated private static func activity(_ id: String) -> Activity<TimerActivityAttributes>? {
        Activity<TimerActivityAttributes>.activities.first { $0.id == id }
    }

    /// Stack order (design note § 2): iOS puts the higher score first, so a
    /// running timer stays above a newer "Saved" card on the Lock Screen and
    /// in the Island.
    nonisolated static let runningRelevance: Double = 100
    nonisolated static let savedRelevance: Double = 0

    nonisolated private static func update(_ id: String, title: TimerTitle) async {
        guard let activity = activity(id) else { return }
        let staleDate = activity.attributes.startTime.addingTimeInterval(LiveActivityPlanner.maxAge)
        await activity.update(ActivityContent(state: .init(title: title, endedAt: nil),
                                              staleDate: staleDate,
                                              relevanceScore: runningRelevance))
    }

    /// The final "Saved · N min" state stays 15 minutes: long enough to see it
    /// after settling the baby, gone by morning (design note § 2). The title
    /// comes from the store, not the activity, so a last side change shows.
    nonisolated private static func endSaved(_ id: String, endedAt: Date, title: TimerTitle) async {
        await activity(id)?.end(ActivityContent(state: .init(title: title, endedAt: endedAt),
                                                staleDate: nil, relevanceScore: savedRelevance),
                                dismissalPolicy: .after(endedAt.addingTimeInterval(15 * 60)))
    }

    nonisolated private static func endImmediately(_ id: String) async {
        await activity(id)?.end(nil, dismissalPolicy: .immediate)
    }
}

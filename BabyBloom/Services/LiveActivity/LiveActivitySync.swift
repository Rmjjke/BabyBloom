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
                // iOS turning them back on re-arms every running timer (QA Q4):
                // the activities iOS removed must not count as already shown.
                if enabled && !self.systemEnabled {
                    LiveActivitySettings.startedEntryIDs = []
                }
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

    func switchChanged(isOn: Bool) {
        if isOn { LiveActivitySettings.startedEntryIDs = [] }
        reconcile()
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

        let activities = Activity<TimerActivityAttributes>.activities
        let snapshots = activities.map {
            ActivitySnapshot(activityID: $0.id, entryID: $0.attributes.entryID,
                             kind: $0.attributes.kind, title: $0.content.state.title,
                             isLive: $0.activityState == .active || $0.activityState == .stale)
        }
        let runningIDs = Set(running.map(\.entryID))
        var stoppedAt: [UUID: Date] = [:]
        for snapshot in snapshots where !runningIDs.contains(snapshot.entryID) {
            stoppedAt[snapshot.entryID] = endTime(of: snapshot.entryID, kind: snapshot.kind, in: context)
        }

        var started = LiveActivitySettings.startedEntryIDs.intersection(runningIDs)
        let gate = LiveActivityGate(switchOn: LiveActivitySettings.isEnabled,
                                    systemEnabled: systemEnabled,
                                    isPad: UIDevice.current.userInterfaceIdiom == .pad)
        let actions = LiveActivityPlanner.plan(running: running, stoppedAt: stoppedAt,
                                               activities: snapshots, alreadyStarted: started,
                                               gate: gate, now: Date())
        for action in actions {
            if case .start = action {} else {
                Self.log.info("Live Activity action: \(String(describing: action), privacy: .public)")
            }
            switch action {
            case .start(let timer):
                if request(timer) { started.insert(timer.entryID) }
            case .update(let id, let title):
                Task { await Self.update(id, title: title) }
            case .endSaved(let id, let endedAt):
                Task { await Self.endSaved(id, endedAt: endedAt) }
            case .endImmediately(let id):
                Task { await Self.endImmediately(id) }
            }
        }
        LiveActivitySettings.startedEntryIDs = started
    }

    /// Records a start only when iOS accepted it: a request made from a
    /// background launch throws, and must not use up the entry's one start.
    private func request(_ timer: RunningTimer) -> Bool {
        let attributes = TimerActivityAttributes(entryID: timer.entryID, kind: timer.kind,
                                                 startTime: timer.startTime)
        let content = ActivityContent(
            state: TimerActivityAttributes.ContentState(title: timer.title, endedAt: nil),
            staleDate: timer.startTime.addingTimeInterval(LiveActivityPlanner.maxAge))
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

    private func endTime(of id: UUID, kind: TimerKind, in context: ModelContext) -> Date? {
        switch kind {
        case .feeding:
            var descriptor = FetchDescriptor<FeedingEntry>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor))?.first?.endTime
        case .sleep:
            var descriptor = FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor))?.first?.endTime
        }
    }

    // `Activity` is not Sendable, so it is looked up by id INSIDE these
    // nonisolated functions and never crosses from the main actor.

    nonisolated private static func live(_ id: String) -> Activity<TimerActivityAttributes>? {
        Activity<TimerActivityAttributes>.activities.first { $0.id == id }
    }

    nonisolated private static func update(_ id: String, title: TimerTitle) async {
        guard let activity = live(id) else { return }
        let staleDate = activity.attributes.startTime.addingTimeInterval(LiveActivityPlanner.maxAge)
        await activity.update(ActivityContent(state: .init(title: title, endedAt: nil),
                                              staleDate: staleDate))
    }

    /// The final "Saved · N min" state stays 15 minutes: long enough to see it
    /// after settling the baby, gone by morning (design note § 2).
    nonisolated private static func endSaved(_ id: String, endedAt: Date) async {
        guard let activity = live(id) else { return }
        let title = activity.content.state.title
        await activity.end(ActivityContent(state: .init(title: title, endedAt: endedAt), staleDate: nil),
                           dismissalPolicy: .after(endedAt.addingTimeInterval(15 * 60)))
    }

    nonisolated private static func endImmediately(_ id: String) async {
        await live(id)?.end(nil, dismissalPolicy: .immediate)
    }
}

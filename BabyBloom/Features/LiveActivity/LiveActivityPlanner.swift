import Foundation

/// A timer the store says is running, reduced to what the activity needs.
struct RunningTimer: Equatable, Sendable {
    let entryID: UUID
    let kind: TimerKind
    let title: TimerTitle
    let startTime: Date
}

/// A timer the store says has stopped: what its final "Saved" state shows.
struct StoppedTimer: Equatable, Sendable {
    let endedAt: Date
    let title: TimerTitle
}

/// An activity as ActivityKit reports it.
struct ActivitySnapshot: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// `.active` or `.stale` (and any state newer than this code).
        case live
        /// Ended — by the app, or by iOS at ~8 h — yet possibly still on the
        /// Lock Screen for up to four more hours.
        case ended
        /// Dismissed: off the screen, nothing left to correct.
        case gone
    }

    let activityID: String
    let entryID: UUID
    let kind: TimerKind
    let title: TimerTitle
    let phase: Phase
    /// The content already shows "Saved" (`endedAt` set): nothing to add.
    let showsSaved: Bool
}

struct LiveActivityGate: Equatable, Sendable {
    var switchOn: Bool
    var systemEnabled: Bool
    var isPad: Bool

    var isOpen: Bool { switchOn && systemEnabled && !isPad }
}

enum LiveActivityAction: Equatable, Sendable {
    case start(RunningTimer)
    case update(activityID: String, title: TimerTitle)
    case endSaved(activityID: String, endedAt: Date, title: TimerTitle)
    case endImmediately(activityID: String)
}

/// Every rule the app and the Lock Screen must agree on, as a pure function —
/// `LiveActivitySync` only executes what this returns. Being idempotent is the
/// point: any caller may reconcile at any time, and a missed call site is
/// repaired by the next one instead of leaving a lie on the Lock Screen.
enum LiveActivityPlanner {

    /// The system ends an activity after about eight hours; starting one for an
    /// older timer would only show the "continues in the app" state at once.
    static let maxAge: TimeInterval = 8 * 3600

    /// Which entries have used up their one start. A closed gate ends every
    /// activity, so it also forgets them all: the switch or iOS turning Live
    /// Activities back on shows the running timer again (QA Q4), while an
    /// activity the user swiped away stays away.
    static func remembered(_ started: Set<UUID>, running: [RunningTimer],
                           gate: LiveActivityGate) -> Set<UUID> {
        gate.isOpen ? started.intersection(running.map(\.entryID)) : []
    }

    static func plan(running: [RunningTimer],
                     stopped: [UUID: StoppedTimer],
                     activities: [ActivitySnapshot],
                     alreadyStarted: Set<UUID>,
                     gate: LiveActivityGate,
                     now: Date) -> [LiveActivityAction] {
        guard gate.isOpen else {
            return activities.filter { $0.phase != .gone }
                .map { .endImmediately(activityID: $0.activityID) }
        }

        // The app shows the newest running entry per kind (startTime-descending
        // queries, `first(where: isActive)`); the activity mirrors that one.
        var shown: [TimerKind: RunningTimer] = [:]
        for timer in running where (shown[timer.kind]?.startTime ?? .distantPast) < timer.startTime {
            shown[timer.kind] = timer
        }
        let runningIDs = Set(running.map(\.entryID))

        var actions: [LiveActivityAction] = []
        for activity in activities {
            switch activity.phase {
            case .gone:
                continue
            case .live:
                if let timer = shown[activity.kind], timer.entryID == activity.entryID {
                    if timer.title != activity.title {
                        actions.append(.update(activityID: activity.activityID, title: timer.title))
                    }
                } else {
                    // Stopped, deleted, or still running but no longer the one shown.
                    actions.append(finish(activity, stopped: stopped))
                }
            case .ended:
                // iOS ends a timer's activity at ~8 h but leaves it on the Lock
                // Screen, Stop button and all. Once that timer stops, the stale
                // card gets the same final content as any other.
                if !activity.showsSaved, !runningIDs.contains(activity.entryID) {
                    actions.append(finish(activity, stopped: stopped))
                }
            }
        }

        let covered = Set(activities.filter { $0.phase == .live }.map(\.entryID))
        for kind in [TimerKind.feeding, .sleep] {
            guard let timer = shown[kind],
                  !covered.contains(timer.entryID),
                  !alreadyStarted.contains(timer.entryID),
                  now.timeIntervalSince(timer.startTime) < maxAge else { continue }
            actions.append(.start(timer))
        }
        return actions
    }

    private static func finish(_ activity: ActivitySnapshot,
                               stopped: [UUID: StoppedTimer]) -> LiveActivityAction {
        if let entry = stopped[activity.entryID] {
            return .endSaved(activityID: activity.activityID, endedAt: entry.endedAt, title: entry.title)
        }
        return .endImmediately(activityID: activity.activityID)
    }
}

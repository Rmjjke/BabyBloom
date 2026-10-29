import Foundation

/// A timer the store says is running, reduced to what the activity needs.
struct RunningTimer: Equatable, Sendable {
    let entryID: UUID
    let kind: TimerKind
    let title: TimerTitle
    let startTime: Date
}

/// An activity as ActivityKit reports it. `isLive` is `.active` or `.stale`;
/// ended and dismissed ones are already off the user's mind and left alone.
struct ActivitySnapshot: Equatable, Sendable {
    let activityID: String
    let entryID: UUID
    let kind: TimerKind
    let title: TimerTitle
    let isLive: Bool
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
    case endSaved(activityID: String, endedAt: Date)
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

    static func plan(running: [RunningTimer],
                     stoppedAt: [UUID: Date],
                     activities: [ActivitySnapshot],
                     alreadyStarted: Set<UUID>,
                     gate: LiveActivityGate,
                     now: Date) -> [LiveActivityAction] {
        let live = activities.filter(\.isLive)
        guard gate.isOpen else {
            return live.map { .endImmediately(activityID: $0.activityID) }
        }

        // The app shows the newest running entry per kind (startTime-descending
        // queries, `first(where: isActive)`); the activity mirrors that one.
        var shown: [TimerKind: RunningTimer] = [:]
        for timer in running where (shown[timer.kind]?.startTime ?? .distantPast) < timer.startTime {
            shown[timer.kind] = timer
        }

        var actions: [LiveActivityAction] = []
        for activity in live {
            if let timer = shown[activity.kind], timer.entryID == activity.entryID {
                if timer.title != activity.title {
                    actions.append(.update(activityID: activity.activityID, title: timer.title))
                }
            } else if let endedAt = stoppedAt[activity.entryID] {
                actions.append(.endSaved(activityID: activity.activityID, endedAt: endedAt))
            } else {
                // Deleted, or still running but no longer the one the app shows.
                actions.append(.endImmediately(activityID: activity.activityID))
            }
        }

        let covered = Set(live.map(\.entryID))
        for kind in [TimerKind.feeding, .sleep] {
            guard let timer = shown[kind],
                  !covered.contains(timer.entryID),
                  !alreadyStarted.contains(timer.entryID),
                  now.timeIntervalSince(timer.startTime) < maxAge else { continue }
            actions.append(.start(timer))
        }
        return actions
    }
}

import ActivityKit
import Foundation

// Compiled into the app AND the widget extension (project.yml), like
// Features/Widget: the extension renders the activity, the app requests and
// ends it, and both must agree on this exact Codable shape.

enum TimerKind: String, Codable, Hashable, Sendable {
    case feeding, sleep
}

/// What the activity's title says. Formula and pumped share one bottle title
/// (D28): on a Lock Screen the side is what a parent needs, not the milk.
enum TimerTitle: String, Codable, Hashable, Sendable {
    case breast, breastLeft, breastRight, breastBoth, bottle, nap, night

    var key: String {
        switch self {
        case .breast:      return "live_activity.title.breast"
        case .breastLeft:  return "live_activity.title.bf_left"
        case .breastRight: return "live_activity.title.bf_right"
        case .breastBoth:  return "live_activity.title.bf_both"
        case .bottle:      return "live_activity.title.bottle"
        case .nap:         return "live_activity.title.nap"
        case .night:       return "live_activity.title.night"
        }
    }

    static func of(_ entry: FeedingEntry) -> TimerTitle {
        guard entry.type == .breast else { return .bottle }
        switch entry.side {
        case .left:  return .breastLeft
        case .right: return .breastRight
        case .both:  return .breastBoth
        case nil:    return .breast
        }
    }

    static func of(_ entry: SleepEntry) -> TimerTitle {
        entry.type == .night ? .night : .nap
    }
}

struct TimerActivityAttributes: ActivityAttributes {
    /// The entry's own `id` UUID: a plain Codable key the activity can carry,
    /// and the one the rest of the code already uses to identify entries.
    let entryID: UUID
    let kind: TimerKind
    let startTime: Date

    struct ContentState: Codable, Hashable, Sendable {
        var title: TimerTitle
        /// Set once the timer is saved; the view then shows "Saved · N min".
        var endedAt: Date?
    }
}

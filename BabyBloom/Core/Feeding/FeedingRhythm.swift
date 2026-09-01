import Foundation

/// When the next feed is due — the one calculation the feeding reminder and
/// the widget must agree on.
///
/// Pure by design, like `Core/Growth` beside it: no SwiftData, no model
/// context, no UserNotifications. That is what lets the widget extension
/// compile it; it previously lived on `NotificationManager`, which the widget
/// target cannot import.
enum FeedingRhythm {

    /// A gap longer than this is a night's sleep rather than a feeding rhythm.
    private static let maxCredibleGapMinutes: Double = 480
    /// Added to a learned rhythm so the reminder lands just after the parent's
    /// own usual moment rather than exactly on it.
    private static let graceMinutes: Double = 10
    private static let fallbackAverageMinutes: Double = 120
    /// Only the last few feedings describe today's rhythm.
    private static let rhythmWindow = 7

    /// `nil` means reminders are off for this age group — from a year old the
    /// app deliberately stops telling parents when to feed.
    static func interval(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:      return 2.5 * 3600   // 0–4 weeks: every ~2–3 h
        case 1...2:  return 3.0 * 3600
        case 3...5:  return 3.5 * 3600
        case 6...8:  return 4.0 * 3600
        case 9...11: return 4.5 * 3600
        default:     return nil          // 12+ months: parent-managed
        }
    }

    /// The age table until the parent has logged enough to describe their own
    /// rhythm, then their rhythm.
    static func interval(ageMonths: Int, recentFeedings: [Date]) -> TimeInterval? {
        guard interval(ageMonths: ageMonths) != nil else { return nil }
        guard recentFeedings.count >= 3 else { return interval(ageMonths: ageMonths) }
        return (averageGapMinutes(recentFeedings) + graceMinutes) * 60
    }

    /// The moment the widget counts down to. `nil` for two different reasons —
    /// nothing logged yet, and the 12+ month case above — and the widget shows
    /// something different for each.
    static func nextFeed(afterLastFeedingAt last: Date?,
                         ageMonths: Int,
                         recentFeedings: [Date]) -> Date? {
        guard let last,
              let interval = interval(ageMonths: ageMonths, recentFeedings: recentFeedings)
        else { return nil }
        return last.addingTimeInterval(interval)
    }

    static func averageGapMinutes(_ times: [Date]) -> Double {
        guard times.count >= 2 else { return fallbackAverageMinutes }
        let recent = times.sorted().suffix(rhythmWindow)
        let gaps = zip(recent, recent.dropFirst()).map {
            $1.timeIntervalSince($0) / 60
        }.filter { $0 > 0 && $0 < maxCredibleGapMinutes }
        guard !gaps.isEmpty else { return fallbackAverageMinutes }
        return gaps.reduce(0, +) / Double(gaps.count)
    }
}

import Foundation

/// When the Monday notification fires, and whether it fires at all (D9, D26,
/// content Q7). Pure, so the rules are pinned by tests with a fixed clock.
///
/// A ONE-SHOT trigger, re-planned on every foreground and background, rather
/// than the old repeating Sunday 20:00 one: a repeating trigger cannot skip a
/// week with nothing in it. Entries are only created while the app runs, so
/// the pass at backgrounding sees every new one.
enum WeeklyNotificationPlan {
    /// Settings → Notifications → "Weekly summary" (D26). Default ON. It mutes
    /// the notification only; the card stays.
    static let enabledKey = "notify.weeklySummary"
    /// Monday 10:00: daytime, outside the 22:00–07:00 quiet window (D9).
    static let hour = 10

    /// The next Monday 10:00 after `now`, or nil when the switch is off or the
    /// week that notification would describe has no entries (S7). That week is
    /// the one ending at the Monday in question, so on a Monday morning before
    /// 10:00 it is last week, and from 10:00 on it is the week now running.
    static func fireDate(now: Date, enabled: Bool,
                         hasEntries: (WeeklySummary.Week) -> Bool) -> Date? {
        guard enabled else { return nil }
        let calendar = WeeklySummary.calendar
        let thisMonday = WeeklySummary.week(containing: now).start
        var fire = calendar.date(byAdding: .hour, value: hour, to: thisMonday)!
        if fire <= now {
            fire = calendar.date(byAdding: .day, value: 7, to: fire)!
        }
        let reported = WeeklySummary.week(containing: fire).shifted(byWeeks: -1)
        return hasEntries(reported) ? fire : nil
    }
}

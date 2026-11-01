import Foundation

/// Entries bucketed into the calendar days of any half-open period
/// `[start, end)`: the core the weekly card (a 7-day period) and the
/// pediatrician report (since the last visit) share.
///
/// It applies no policy of its own. Which entries count — a running feed, a
/// sleep that began before the period — is decided by each caller before it
/// builds the `Input`, because the two answer differently (the weekly card
/// counts a running feed; the report never does). Pure, so the day rules are
/// pinned by `PeriodSummaryTests`.
struct PeriodSummary: Equatable, Sendable {

    struct Input: Sendable {
        var feeds: [Date] = []
        /// Each sleep is filed whole on the day it starts, as the Sleep tab does.
        var sleeps: [(start: Date, end: Date)] = []
        /// Entries that only mark a day as logged.
        var otherEntries: [Date] = []
    }

    let start: Date
    let end: Date
    /// Calendar days the period touches; a partial last day counts as one.
    let dayCount: Int
    let feedsByDay: [Int]
    let sleepByDay: [TimeInterval]
    let dayHasEntries: [Bool]
    let longestSleep: TimeInterval?
    /// Start of the longest sleep, for the report's «· 24 Oct».
    let longestSleepStart: Date?

    var daysWithEntries: Int { dayHasEntries.filter { $0 }.count }
    var totalFeeds: Int { feedsByDay.reduce(0, +) }
    var totalSleep: TimeInterval { sleepByDay.reduce(0, +) }

    static func make(start: Date, end: Date, input: Input, calendar: Calendar) -> PeriodSummary {
        let count = dayCount(start: start, end: end, calendar: calendar)
        var feeds = Array(repeating: 0, count: count)
        var sleep = Array(repeating: TimeInterval(0), count: count)
        var hasEntries = Array(repeating: false, count: count)
        var longest: (length: TimeInterval, start: Date)?

        let index = { (date: Date) in dayIndex(of: date, start: start, end: end, dayCount: count, calendar: calendar) }
        for date in input.feeds {
            guard let day = index(date) else { continue }
            feeds[day] += 1
            hasEntries[day] = true
        }
        for entry in input.sleeps {
            guard let day = index(entry.start) else { continue }
            let length = max(0, entry.end.timeIntervalSince(entry.start))
            sleep[day] += length
            hasEntries[day] = true
            if length > (longest?.length ?? -1) { longest = (length, entry.start) }
        }
        for date in input.otherEntries {
            guard let day = index(date) else { continue }
            hasEntries[day] = true
        }
        return PeriodSummary(start: start, end: end, dayCount: count,
                             feedsByDay: feeds, sleepByDay: sleep, dayHasEntries: hasEntries,
                             longestSleep: longest?.length, longestSleepStart: longest?.start)
    }

    /// Midnight to midnight through the calendar, never `/ 86_400`: a week that
    /// crosses the autumn DST change is 7 days of 24, 24, 25, … hours, and a
    /// division would make it 7.04 or fold two dates into one.
    static func dayCount(start: Date, end: Date, calendar: Calendar) -> Int {
        guard end > start else { return 0 }
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        let whole = calendar.dateComponents([.day], from: first, to: last).day ?? 0
        // `end` exactly at a midnight closes the period on the day before.
        return max(1, whole + (end > last ? 1 : 0))
    }

    /// 0 for the first day, or nil outside `[start, end)`.
    static func dayIndex(of date: Date, start: Date, end: Date, dayCount: Int,
                         calendar: Calendar) -> Int? {
        guard date >= start, date < end, dayCount > 0 else { return nil }
        let day = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                          to: calendar.startOfDay(for: date)).day ?? 0
        return min(max(day, 0), dayCount - 1)
    }

    static func == (lhs: PeriodSummary, rhs: PeriodSummary) -> Bool {
        lhs.start == rhs.start && lhs.end == rhs.end && lhs.dayCount == rhs.dayCount
            && lhs.feedsByDay == rhs.feedsByDay && lhs.sleepByDay == rhs.sleepByDay
            && lhs.dayHasEntries == rhs.dayHasEntries && lhs.longestSleep == rhs.longestSleep
            && lhs.longestSleepStart == rhs.longestSleepStart
    }
}

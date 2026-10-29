import Foundation

/// Last calendar week, Monday to Sunday (D8), as the Dashboard card and the
/// Monday notification describe it. Pure: dates and weighings in, numbers out,
/// so every rule below is pinned by `WeeklySummaryTests` with a fixed clock.
struct WeeklySummary: Equatable, Sendable {

    /// What the summary is built from, stripped of SwiftData.
    struct Input: Sendable {
        /// Start of every feed, a running one included: it happened that day.
        var feeds: [Date] = []
        /// Finished sleeps only; a running one has no length yet.
        var sleeps: [(start: Date, end: Date)] = []
        /// Diapers, growth entries and events: they count towards "days with
        /// entries" and nothing else.
        var otherEntries: [Date] = []
        var measurements: [WeightMeasurement] = []
        var birthDate: Date
        var correctedBirthDate: Date
        var birthWeightKg: Double?
        var isMale: Bool
    }

    /// A half-open week `[start, end)`.
    struct Week: Equatable, Sendable {
        let start: Date
        let end: Date

        func contains(_ date: Date) -> Bool { date >= start && date < end }

        func shifted(byWeeks weeks: Int) -> Week {
            let calendar = WeeklySummary.calendar
            return Week(start: calendar.date(byAdding: .day, value: 7 * weeks, to: start)!,
                        end: calendar.date(byAdding: .day, value: 7 * weeks, to: end)!)
        }

        /// 0 for Monday … 6 for Sunday, or nil outside the week.
        func dayIndex(of date: Date) -> Int? {
            guard contains(date) else { return nil }
            let calendar = WeeklySummary.calendar
            let day = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day
            return day.map { min(max($0, 0), 6) }
        }
    }

    /// One week's figures. Averages divide by the days that have any entry at
    /// all (D19), so a week with three blank days is not read as a week of
    /// small feeds.
    struct Totals: Equatable, Sendable {
        let daysWithEntries: Int
        /// Per day, Monday first: the expanded card's bars.
        let feedsByDay: [Int]
        let sleepByDay: [TimeInterval]
        let dayHasEntries: [Bool]
        let longestSleep: TimeInterval?

        /// nil when the week has no feed at all: the row is left out rather
        /// than printing a zero that reads as a verdict (DECISIONS 2026-09-05).
        var feedsPerDay: Double? {
            let total = feedsByDay.reduce(0, +)
            guard total > 0, daysWithEntries > 0 else { return nil }
            return Double(total) / Double(daysWithEntries)
        }

        var sleepPerDay: TimeInterval? {
            let total = sleepByDay.reduce(0, +)
            guard total > 0, daysWithEntries > 0 else { return nil }
            return total / Double(daysWithEntries)
        }
    }

    enum Gain: Equatable, Sendable {
        /// Grams per week, rounded to 10 g (D27).
        case perWeek(Int)
        /// The newborn window: no number (D17).
        case newborn
        /// No two weighings ≥ 3 days apart with the later one in the week.
        case needsWeighing
    }

    let week: Week
    let current: Totals
    /// nil for the first week in the log (S2): nothing to compare with.
    let previous: Totals?
    let gain: Gain
    /// The week before's gain, for its "Week before" line; nil when it had none.
    let previousGain: Int?

    // MARK: Calendar

    /// Weeks start on Monday whatever the locale (D8): a US phone's Sunday
    /// week would make "last week" a different seven days than the copy says.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = .current
        return calendar
    }()

    /// The week `date` falls in.
    static func week(containing date: Date) -> Week {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        return Week(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    /// The finished week before the one `now` is in: shown from Monday 00:00
    /// to Sunday 23:59 of the following week.
    static func lastWeek(now: Date) -> Week {
        week(containing: now).shifted(byWeeks: -1)
    }

    // MARK: Building

    /// nil when last week has no entries at all (S7): no card, no notification.
    static func make(now: Date, input: Input) -> WeeklySummary? {
        let week = lastWeek(now: now)
        let current = totals(for: week, input: input)
        guard current.daysWithEntries > 0 else { return nil }

        let before = week.shifted(byWeeks: -1)
        let previous = totals(for: before, input: input)
        return WeeklySummary(
            week: week,
            current: current,
            previous: previous.daysWithEntries > 0 ? previous : nil,
            gain: gain(for: week, input: input, now: now),
            previousGain: gramsPerWeek(for: before, input: input)
        )
    }

    /// Whether the week has any entry; the notification's whole question.
    static func hasEntries(in week: Week, input: Input) -> Bool {
        totals(for: week, input: input).daysWithEntries > 0
    }

    static func totals(for week: Week, input: Input) -> Totals {
        var feeds = Array(repeating: 0, count: 7)
        var sleep = Array(repeating: TimeInterval(0), count: 7)
        var hasEntries = Array(repeating: false, count: 7)
        var longest: TimeInterval?

        for date in input.feeds {
            guard let day = week.dayIndex(of: date) else { continue }
            feeds[day] += 1
            hasEntries[day] = true
        }
        // A sleep belongs to the day it started, whole: a night that begins
        // on Sunday is Sunday's, as the Sleep tab files it.
        for sleepEntry in input.sleeps {
            guard let day = week.dayIndex(of: sleepEntry.start) else { continue }
            let length = max(0, sleepEntry.end.timeIntervalSince(sleepEntry.start))
            sleep[day] += length
            hasEntries[day] = true
            longest = max(longest ?? 0, length)
        }
        for date in input.otherEntries {
            guard let day = week.dayIndex(of: date) else { continue }
            hasEntries[day] = true
        }
        return Totals(daysWithEntries: hasEntries.filter { $0 }.count,
                      feedsByDay: feeds,
                      sleepByDay: sleep,
                      dayHasEntries: hasEntries,
                      longestSleep: longest)
    }

    /// D27 with the D17 gate in front: the newborn window never shows a number,
    /// whatever the weighings say.
    static func gain(for week: Week, input: Input, now: Date) -> Gain {
        let known = input.measurements.filter { $0.date < week.end }
        if NewbornWeightLoss.gainDeferral(birthWeightKg: input.birthWeightKg,
                                          birthDate: input.birthDate,
                                          measurements: known,
                                          now: now) != nil {
            return .newborn
        }
        return gramsPerWeek(for: week, input: input).map(Gain.perWeek) ?? .needsWeighing
    }

    /// The `WeightVelocity` pair over the weighings up to the week's end,
    /// counted only when its LATER weighing falls inside the week (D27), so a
    /// week without a weighing does not repeat an older gain as its own.
    static func gramsPerWeek(for week: Week, input: Input) -> Int? {
        let known = input.measurements.filter { $0.date < week.end }
        guard let pair = WeightVelocity.pair(in: known), week.contains(pair.later.date),
              let reading = WeightVelocity.measure(from: pair.earlier, to: pair.later,
                                                   correctedBirthDate: input.correctedBirthDate,
                                                   isMale: input.isMale)
        else { return nil }
        return Int((reading.gramsPerWeek / 10).rounded()) * 10
    }

    /// "+210", "0", "-30": the number only, for `weekly.gain_fmt` and
    /// `velocity.per_week_fmt`.
    static func signed(_ grams: Int) -> String {
        grams > 0 ? "+\(grams)" : "\(grams)"
    }
}

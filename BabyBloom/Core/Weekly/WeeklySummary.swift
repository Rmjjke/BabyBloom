import Foundation

/// Last calendar week, Monday to Sunday, as the Dashboard card and the
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
    /// all, so a week with three blank days is not read as a week of
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
        /// Grams per week, rounded to 10 g.
        case perWeek(Int)
        /// The newborn window: no number.
        case newborn
        // No pair ends in the week. The rest say what is missing, judged on
        // every weighing up to now and taken in this order (`missingPair`).
        /// A pair ends after the week: next Monday's card shows its gain.
        case nextMonday
        /// A pair ended before the week, or ends after it inside the newborn
        /// window: one weighing now completes a pair that shows.
        case needsWeighing
        /// Weighings, but no two of them ≥ 3 days apart.
        case needsSecond
        /// No weighing at all.
        case needsTwo
    }

    let week: Week
    let current: Totals
    /// nil for the first week in the log: nothing to compare with.
    let previous: Totals?
    let gain: Gain
    /// The week before's gain, for its "Week before" line; nil when it had none.
    let previousGain: Int?
    /// Days of the week (from Monday) before the birth date: 0 for a whole
    /// week, so the bars draw no "no entries" stub for days not lived.
    let daysBeforeBirth: Int

    // MARK: Calendar

    /// Weeks start on Monday whatever the locale: a US phone's Sunday
    /// week would make "last week" a different seven days than the copy says.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        // Autoupdating, not `.current`: this lives for the whole run, and a
        // family that travels must get its midnights from the zone it is in.
        calendar.timeZone = .autoupdatingCurrent
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

    /// nil when last week has no entries at all: no card, no notification.
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
            previousGain: previousGain(for: before, input: input),
            daysBeforeBirth: week.contains(input.birthDate)
                ? week.dayIndex(of: input.birthDate) ?? 0
                : (input.birthDate >= week.end ? 7 : 0)
        )
    }

    /// The week before's line passes the same newborn gate, judged as of that
    /// week's end: a pair that ended in the newborn dip stays without a number
    /// even once this week's pair has left the window.
    static func previousGain(for week: Week, input: Input) -> Int? {
        if case .perWeek(let grams) = gain(for: week, input: input, now: week.end) { return grams }
        return nil
    }

    /// Whether the week has any entry; the notification's whole question.
    static func hasEntries(in week: Week, input: Input) -> Bool {
        totals(for: week, input: input).daysWithEntries > 0
    }

    /// A 7-day `PeriodSummary`. The weekly rules live in what goes IN: a running
    /// feed counts (it happened that day) and a sleep is filed whole on its
    /// start day, as the Sleep tab does — the report decides differently.
    static func totals(for week: Week, input: Input) -> Totals {
        let period = PeriodSummary.make(
            start: week.start, end: week.end,
            input: PeriodSummary.Input(feeds: input.feeds, sleeps: input.sleeps,
                                       otherEntries: input.otherEntries),
            calendar: calendar)
        // Weeks are midnight to midnight, so this is always 7; the bars index on it.
        assert(period.dayCount == 7, "a week must bucket into 7 days")
        return Totals(daysWithEntries: period.daysWithEntries,
                      feedsByDay: period.feedsByDay,
                      sleepByDay: period.sleepByDay,
                      dayHasEntries: period.dayHasEntries,
                      longestSleep: period.longestSleep)
    }

    /// The weekly gain with the newborn gate in front: the newborn window never shows a number,
    /// whatever the weighings say.
    static func gain(for week: Week, input: Input, now: Date) -> Gain {
        let known = input.measurements.filter { $0.date < week.end }
        if NewbornWeightLoss.gainDeferral(birthWeightKg: input.birthWeightKg,
                                          birthDate: input.birthDate,
                                          measurements: known,
                                          now: now) != nil {
            return .newborn
        }
        return gramsPerWeek(for: week, input: input).map(Gain.perWeek)
            ?? missingPair(for: week, input: input, now: now)
    }

    /// What the gain line asks for when no pair ends in the week. Judged on
    /// every weighing up to now, not up to the week's end: a parent who
    /// weighed this week has already done the next step, and asking for a
    /// weighing again would send them to repeat it.
    static func missingPair(for week: Week, input: Input, now: Date) -> Gain {
        // Up to now, without the store's day of tolerance: a weighing dated
        // ahead may fall past the week next Monday's card covers.
        let logged = input.measurements.filter { $0.date <= now }
        // `pair` keeps the newest weighing, so a pair ending after the week
        // exists exactly when this one ends after it.
        if let pair = WeightVelocity.pair(in: logged), pair.later.date >= week.end {
            // The window is closed here (the gate above), but a pair ending
            // inside it shows no number next Monday either: the weighing that
            // ends it is the next step, as after an older pair.
            let deferred = NewbornWeightLoss.gainDeferral(birthWeightKg: input.birthWeightKg,
                                                          birthDate: input.birthDate,
                                                          measurements: logged, now: now) != nil
            return deferred ? .needsWeighing : .nextMonday
        }
        if WeightVelocity.pair(in: logged.filter { $0.date < week.start }) != nil { return .needsWeighing }
        return logged.isEmpty ? .needsTwo : .needsSecond
    }

    /// The `WeightVelocity` pair over the weighings up to the week's end,
    /// counted only when its LATER weighing falls inside the week, so a
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
    /// `velocity.per_week_fmt`, with the language's own signs.
    static func signed(_ grams: Int) -> String { grams.appSigned }
}

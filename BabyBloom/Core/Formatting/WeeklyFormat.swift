import Foundation

/// The card's number formats, all in the app's language.
enum WeeklyFormat {
    private static var locale: Locale { LocalizationManager.shared.language.locale }

    /// "Oct 19 – 25", «10月19日～25日»: the month once when both ends share
    /// it, in the language's own order.
    static func range(_ week: WeeklySummary.Week, locale: Locale = LocalizationManager.shared.language.locale) -> String {
        let last = WeeklySummary.calendar.date(byAdding: .day, value: -1, to: week.end)!
        return LocaleDates.dayRange(week.start, last, locale: locale)
    }

    static func perDay(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    /// Floored, as the history rows and the timers floor: a 1 min 50 s feed
    /// is «1 min» on every surface, never «2 min» in a summary. Rounded to the
    /// millisecond first, so an average or a sum of doubles that lands a hair
    /// under a whole minute keeps that minute.
    static func wholeMinutes(_ seconds: TimeInterval) -> Int {
        Int((seconds * 1000).rounded()) / 60_000
    }

    static func duration(_ seconds: TimeInterval) -> String {
        DurationText.minutes(wholeMinutes(seconds))
    }

    /// nil when there is nothing to compare or the shown values are equal.
    static func feedsDelta(_ current: Double?, _ previous: Double?) -> (up: Bool, text: String)? {
        guard let current, let previous else { return nil }
        let difference = (current * 10).rounded() / 10 - (previous * 10).rounded() / 10
        guard abs(difference) >= 0.05 else { return nil }
        return (difference > 0, perDay(abs(difference)))
    }

    static func sleepDelta(_ current: TimeInterval?, _ previous: TimeInterval?) -> (up: Bool, text: String)? {
        guard let current, let previous else { return nil }
        // The difference of the two shown values, so the arrow never disagrees with them.
        let difference = wholeMinutes(current) - wholeMinutes(previous)
        guard difference != 0 else { return nil }
        return (difference > 0, duration(TimeInterval(abs(difference) * 60)))
    }

    /// M T W T F S S in the app's language, Monday first.
    static var weekdayLetters: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols   // Sunday first
        return Array(symbols[1...]) + [symbols[0]]
    }
}

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

    static func duration(_ seconds: TimeInterval) -> String {
        DurationText.minutes(Int((seconds / 60).rounded()))
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
        let difference = (current / 60).rounded() - (previous / 60).rounded()
        guard difference != 0 else { return nil }
        return (difference > 0, duration(abs(difference) * 60))
    }

    /// M T W T F S S in the app's language, Monday first.
    static var weekdayLetters: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols   // Sunday first
        return Array(symbols[1...]) + [symbols[0]]
    }
}

import Foundation

/// The card's number formats, all in the app's language.
enum WeeklyFormat {
    private static var locale: Locale { LocalizationManager.shared.language.locale }

    /// "20 – 26 Oct": the month once when both ends share it.
    static func range(_ week: WeeklySummary.Week) -> String {
        let calendar = WeeklySummary.calendar
        let last = calendar.date(byAdding: .day, value: -1, to: week.end)!
        let sameMonth = calendar.component(.month, from: week.start) == calendar.component(.month, from: last)
        guard sameMonth else {
            return String(format: "weekly.range_fmt".l, week.start.appDayMonth, last.appDayMonth)
        }
        // The month is written once, on the side the language puts it:
        // "Oct 19 – 25" in English, "19 – 25 окт." in Russian.
        let dayOnly = { (date: Date) in date.formatted(.dateTime.day().locale(locale)) }
        let monthFirst = !(last.appDayMonth.first?.isNumber ?? true)
        return monthFirst
            ? String(format: "weekly.range_fmt".l, week.start.appDayMonth, dayOnly(last))
            : String(format: "weekly.range_fmt".l, dayOnly(week.start), last.appDayMonth)
    }

    static func perDay(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let text: String
        if minutes < 60 {
            text = String(format: "duration.min_only".l, minutes)
        } else {
            // "1h", not "1h 0min".
            text = minutes % 60 == 0
                ? String(format: "duration.h_only".l, minutes / 60)
                : String(format: "duration.h_min".l, minutes / 60, minutes % 60)
        }
        // The break between the parts stays: the value may still wrap there at
        // AX sizes (design m1-weekly-summary § AX2).
        return text.gluingNumbersToUnits
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

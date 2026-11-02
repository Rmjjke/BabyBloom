import Foundation

/// Number + unit formats. Every unit is glued to its number with a
/// no-break space (DECISIONS 2026-10-30), so a line never starts with «kg».
enum ReportFormat {
    static let nbsp = "\u{00A0}"
    /// «·» glued to the item before it: a wrapped list breaks AFTER the dot,
    /// never inside «Breast 120 · Formula».
    static let listSeparator = "\u{00A0}· "
    static var joiner: String { listSeparator }

    /// A date for the report: the year only when it is not this year's — the
    /// latest weighing of a 15-month-old may be last year's, and «28 Oct» would
    /// read as last week. Spaces made unbreakable, so «24 / Oct» never splits.
    static func date(_ date: Date, now: Date = AppClock.now) -> String {
        let calendar = Calendar.current
        let text = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? date.appDayMonth : date.appDayMonthYear
        return text.replacingOccurrences(of: " ", with: nbsp)
    }

    /// «> 97» held together.
    static func glued(_ text: String) -> String { text.replacingOccurrences(of: " ", with: nbsp) }

    static func kg(_ value: Double) -> String { "\(value.appDecimal(2))\(nbsp)\("unit.kg".l)" }
    static func cm(_ value: Double) -> String { "\(value.appDecimal(1))\(nbsp)\("unit.cm".l)" }
    static func ml(_ value: Double) -> String { "\(value.appDecimal(0))\(nbsp)\("unit.ml".l)" }

    /// «+640 g», signed, with the unit attached.
    static func grams(_ grams: Int) -> String {
        "\(WeeklySummary.signed(grams))\(nbsp)\("unit.g".l)"
    }

    /// `WeeklyFormat.duration` with its internal spaces made unbreakable:
    /// «5h 10min» must not split across lines.
    static func duration(_ seconds: TimeInterval) -> String {
        WeeklyFormat.duration(seconds).replacingOccurrences(of: " ", with: nbsp)
    }

    /// «Breast 120», the name and its count held together.
    static func countItem(name: String, count: Int) -> String {
        String(format: "report.type_count_fmt".l, name, count)
            .replacingOccurrences(of: " ", with: nbsp)
    }

    static func countList(_ items: [String]) -> String { items.joined(separator: listSeparator) }

    /// «12 min ago», «5 h ago», then whole days from 48 h: «131 h ago» read as
    /// a number to work out, not an answer. Days are floored (2 d 23 h is «2
    /// days»), the word from the age plurals, glued to its number.
    static func ago(from date: Date, to now: Date) -> String {
        let minutes = max(0, Int(now.timeIntervalSince(date) / 60))
        if minutes < 60 { return String(format: "stats.min_ago".l, minutes).gluingNumbersToUnits }
        let hours = minutes / 60
        if hours < 48 { return String(format: "stats.h_ago".l, hours).gluingNumbersToUnits }
        let days = hours / 24
        return String(format: "stats.days_ago_fmt".l, "\(days)\(nbsp)\(days.dayWord)")
    }
}

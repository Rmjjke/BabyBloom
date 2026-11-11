import Foundation

/// Date texts whose word order belongs to the language: a range, a month
/// with its year, a weekday. Each comes from the locale's own template, never
/// from a pattern written here, so Japanese reads «10月19日～25日» and
/// «2026年10月», German «19.–25. Okt.», and nothing is cut or recased by code.
/// The locale is passed in so each form is testable in every language.
enum LocaleDates {
    /// "Oct 19 – 25", «19—25 окт.», «10月19日～25日»: the month once when both
    /// days share it, wherever the language puts it. `last` is the last day
    /// shown, inclusive.
    static func dayRange(_ first: Date, _ last: Date, locale: Locale) -> String {
        interval(first, last, template: "MMMd", locale: locale)
    }

    /// The month and its year as a title: «Октябрь 2026 г.», «2026年10月».
    /// Across two months, both months and the year once: «Окт. — нояб. 2026 г.».
    static func monthTitle(_ first: Date, _ last: Date, locale: Locale) -> String {
        let calendar = SupportedLanguage.gregorian(locale: locale)
        guard calendar.isDate(first, equalTo: last, toGranularity: .month) else {
            return sentenceCase(interval(first, last, template: "MMMy", locale: locale), locale: locale)
        }
        let formatter = formatter(locale: locale)
        // The locale's own start-of-sentence form: «Октябрь», where
        // `.capitalized` would also have made «г.» into «Г.».
        formatter.formattingContext = .beginningOfSentence
        formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        return formatter.string(from: first)
    }

    /// A short month and its year for a chart axis: "Oct 2026", «2026年10月».
    /// The word some languages write after the year (Russian «г.», Ukrainian
    /// «р.») is left out: four of them in a row collide on a phone's axis,
    /// and the four digits already say it is a year.
    static func axisMonthYear(_ date: Date, locale: Locale) -> String {
        let formatter = formatter(locale: locale)
        formatter.setLocalizedDateFormatFromTemplate("MMMy")
        let pattern = formatter.dateFormat ?? "MMM y"
        if let suffix = pattern.range(of: #"(?<=y)\s*'[^']+'\.?$"#, options: .regularExpression) {
            formatter.dateFormat = String(pattern[..<suffix.lowerBound])
        }
        return formatter.string(from: date)
    }

    /// The language's short weekday name, whole and as the locale cases it at
    /// the start of a label: "Mo", «Пн», «Lu», Spanish «LU», «月», «Må».
    /// Never a prefix of a longer name: two letters of «週一» or «lun.» are
    /// not how either language abbreviates.
    static func shortWeekday(_ date: Date, locale: Locale) -> String {
        let formatter = formatter(locale: locale)
        formatter.formattingContext = .beginningOfSentence
        formatter.dateFormat = "cccccc"
        return formatter.string(from: date)
    }

    // MARK: -

    private static func formatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = SupportedLanguage.gregorian(locale: locale)
        formatter.timeZone = .current
        return formatter
    }

    private static func interval(_ first: Date, _ last: Date, template: String, locale: Locale) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = SupportedLanguage.gregorian(locale: locale)
        formatter.timeZone = .current
        formatter.dateTemplate = template
        return formatter.string(from: first, to: last)
    }

    /// The first letter in the language's capital, the rest as the locale
    /// wrote it. An interval formatter has no sentence context of its own.
    private static func sentenceCase(_ text: String, locale: Locale) -> String {
        guard let head = text.first else { return text }
        return String(head).uppercased(with: locale) + text.dropFirst()
    }
}

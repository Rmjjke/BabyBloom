import XCTest
@testable import BabyBloom

/// Dates, weekdays, signs and sort order in the language's own forms: the
/// order comes from the locale's templates, never from a pattern in code.
final class LocaleDatesTests: XCTestCase {

    private func day(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// Foundation spaces ranges with thin and narrow no-break spaces; the
    /// order and the words are what is checked.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "[\u{2009}\u{202F}\u{00A0}]", with: " ", options: .regularExpression)
    }

    private func locale(_ id: String) -> Locale { Locale(identifier: id) }

    // MARK: Ranges

    func testAWeekRangeInEachLanguagesOrder() {
        let expected = [
            "ja_JP": "10月19日～25日",
            "ko_KR": "10월 19일~25일",
            "zh_Hant_TW": "10月19日至25日",
            "de_DE": "19.–25. Okt.",
            "fr_FR": "19–25 oct.",
            "en_US": "Oct 19 – 25",
            "ru_RU": "19—25 окт.",
        ]
        for (id, text) in expected {
            XCTAssertEqual(plain(LocaleDates.dayRange(day(10, 19), day(10, 25), locale: locale(id))), text, id)
        }
    }

    func testAWeekAcrossTwoMonthsNamesBoth() {
        XCTAssertEqual(plain(LocaleDates.dayRange(day(10, 26), day(11, 1), locale: locale("ja_JP"))), "10月26日～11月1日")
        XCTAssertEqual(plain(LocaleDates.dayRange(day(10, 26), day(11, 1), locale: locale("de_DE"))), "26. Okt. – 1. Nov.")
    }

    /// The week across New Year carries both years, as the locale writes it.
    func testAWeekAcrossNewYearNamesBothYears() {
        let first = day(12, 28), last = day(1, 3, year: 2027)
        XCTAssertEqual(plain(LocaleDates.dayRange(first, last, locale: locale("en_US"))), "Dec 28, 2026 – Jan 3, 2027")
        XCTAssertEqual(plain(LocaleDates.dayRange(first, last, locale: locale("ru_RU"))), "28 дек. 2026 — 3 янв. 2027 г.")
        XCTAssertEqual(plain(LocaleDates.dayRange(first, last, locale: locale("ja_JP"))), "2026年12月28日～2027年1月3日")
    }

    func testTheWeeklyCardRangeIsTheLocalesInterval() {
        let week = WeeklySummary.Week(start: WeeklySummary.calendar.startOfDay(for: day(10, 19)),
                                      end: WeeklySummary.calendar.startOfDay(for: day(10, 26)))
        XCTAssertEqual(plain(WeeklyFormat.range(week, locale: locale("ja_JP"))), "10月19日～25日")
        XCTAssertEqual(plain(WeeklyFormat.range(week, locale: locale("es_419"))), "19 – 25 de oct")
    }

    // MARK: Month and year

    func testTheChartTitleTakesTheLocalesMonthYear() {
        XCTAssertEqual(LocaleDates.monthTitle(day(10, 19), day(10, 25), locale: locale("ja_JP")), "2026年10月")
        XCTAssertEqual(LocaleDates.monthTitle(day(10, 19), day(10, 25), locale: locale("ko_KR")), "2026년 10월")
        XCTAssertEqual(plain(LocaleDates.monthTitle(day(10, 19), day(10, 25), locale: locale("ru_RU"))), "Октябрь 2026 г.")
        XCTAssertEqual(LocaleDates.monthTitle(day(10, 19), day(10, 25), locale: locale("en_US")), "October 2026")
        XCTAssertEqual(LocaleDates.monthTitle(day(10, 19), day(10, 25), locale: locale("es_419")), "Octubre de 2026")
    }

    func testTheChartTitleAcrossTwoMonths() {
        XCTAssertEqual(plain(LocaleDates.monthTitle(day(10, 26), day(11, 1), locale: locale("ja_JP"))), "2026年10月～11月")
        XCTAssertEqual(plain(LocaleDates.monthTitle(day(10, 26), day(11, 1), locale: locale("ru_RU"))), "Окт. — нояб. 2026 г.")
        XCTAssertEqual(plain(LocaleDates.monthTitle(day(10, 26), day(11, 1), locale: locale("en_US"))), "Oct – Nov 2026")
    }

    /// The year word some languages add is left off the axis; the order stays.
    func testTheAxisMonthYear() {
        let expected = [
            "ja_JP": "2026年10月",
            "ko_KR": "2026년 10월",
            "zh_Hant_TW": "2026年10月",
            "ru_RU": "окт. 2026",
            "uk_UA": "жовт. 2026",
            "en_US": "Oct 2026",
            "pt_BR": "out. de 2026",
        ]
        for (id, text) in expected {
            XCTAssertEqual(plain(LocaleDates.axisMonthYear(day(10, 19), locale: locale(id))), text, id)
        }
    }

    // MARK: Weekdays

    func testTheShortWeekdayIsTheLanguagesOwnNotACut() {
        let monday = day(10, 19)
        let expected = ["en_US": "Mo", "ru_RU": "Пн", "fr_FR": "Lu", "de_DE": "Mo.", "ja_JP": "月",
                        "zh_Hant_TW": "一", "sv_SE": "Må", "pt_BR": "Seg."]
        for (id, text) in expected {
            XCTAssertEqual(LocaleDates.shortWeekday(monday, locale: locale(id)), text, id)
        }
    }

    /// Every app language names its seven days apart, each no longer than the
    /// day's full name (German's short form «Mo.» is longer than its
    /// abbreviated «Mo», so that is no bound).
    func testEveryLanguageNamesItsSevenDaysApart() {
        for language in SupportedLanguage.allCases {
            let formatter = DateFormatter()
            formatter.locale = language.locale
            formatter.calendar = language.calendar
            formatter.dateFormat = "cccc"
            let days = (0..<7).map { language.calendar.date(byAdding: .day, value: $0, to: day(10, 19))! }
            let names = days.map { LocaleDates.shortWeekday($0, locale: language.locale) }
            XCTAssertEqual(Set(names).count, 7, "\(language) \(names)")
            for (date, name) in zip(days, names) {
                XCTAssertFalse(name.isEmpty, "\(language)")
                XCTAssertLessThanOrEqual(name.count, formatter.string(from: date).count, "\(language) \(name)")
            }
        }
    }

    func testEveryLanguagesWeekStartsOnMonday() {
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(language.calendar.firstWeekday, 2, "\(language)")
            XCTAssertEqual(language.environmentCalendar.firstWeekday, 2, "\(language) environment")
            let week = language.calendar.dateInterval(of: .weekOfYear, for: day(10, 25))!
            XCTAssertEqual(week.start, Calendar(identifier: .gregorian).startOfDay(for: day(10, 19)), "\(language)")
        }
    }

    // MARK: Signs

    func testASignedNumberTakesTheLanguagesMinus() {
        for id in ["sv_SE", "nb_NO", "fi_FI"] {
            XCTAssertEqual((-30).appSigned(locale: locale(id)), "\u{2212}30", id)
            XCTAssertEqual(210.appSigned(locale: locale(id)), "+210", id)
        }
        for id in ["en_US", "ru_RU", "es_419"] {
            XCTAssertEqual((-30).appSigned(locale: locale(id)), "-30", id)
            XCTAssertEqual(1200.appSigned(locale: locale(id)), "+1200", id)
            XCTAssertEqual(0.appSigned(locale: locale(id)), "0", id)
        }
    }
}

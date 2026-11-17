import XCTest
@testable import BabyBloom

/// The shared formatters in Core/Formatting: a number never leaves its unit,
/// and the Today tile counts days once hours stop being an answer.
final class FormattingTests: XCTestCase {

    private let nbsp = "\u{00A0}"
    private var previous: SupportedLanguage = .en

    override func setUp() {
        super.setUp()
        previous = LocalizationManager.shared.language
    }

    override func tearDown() {
        LocalizationManager.shared.setLanguage(previous)
        super.tearDown()
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

    func testAgoCountsMinutesThenHoursThenWholeDaysFrom48Hours() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(0.5), to: now), String(format: "stats.min_ago".l, 30).gluingNumbersToUnits)
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(47.9), to: now), String(format: "stats.h_ago".l, 47).gluingNumbersToUnits)
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(48), to: now),
                       String(format: "stats.days_ago_fmt".l, PluralFamily.durationDays.text(2)))
        // Floored: 2 days 23 hours is still «2 days», never rounded up to 3.
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(71), to: now),
                       String(format: "stats.days_ago_fmt".l, PluralFamily.durationDays.text(2)))
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(131), to: now),
                       String(format: "stats.days_ago_fmt".l, PluralFamily.durationDays.text(5)))
    }

    func testAgoUsesTheRussianDayPlurals() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertTrue(ReportFormat.ago(from: hoursAgo(50), to: now).contains("2\(nbsp)дня"))
        XCTAssertTrue(ReportFormat.ago(from: hoursAgo(130), to: now).contains("5\(nbsp)дней"))
    }

    func testAFutureStartReadsAsZeroMinutesNotNegative() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(ReportFormat.ago(from: now.addingTimeInterval(120), to: now),
                       String(format: "stats.min_ago".l, 0).gluingNumbersToUnits)
    }

    func testEveryAgoKeepsItsNumberOnItsUnit() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            for hours in [0.5, 5.0, 100.0] {
                let text = ReportFormat.ago(from: hoursAgo(hours), to: now)
                XCTAssertNil(text.range(of: #"\d "#, options: .regularExpression), "\(language): «\(text)»")
            }
        }
    }

    func testTheQuestionCountTakesTheRussianPlurals() {
        LocalizationManager.shared.setLanguage(.ru)
        func count(_ n: Int) -> String {
            PluralFamily.questionCount.text(n)
                .replacingOccurrences(of: nbsp, with: " ")
        }
        XCTAssertEqual(count(1), "1 вопрос")
        XCTAssertEqual(count(2), "2 вопроса")
        XCTAssertEqual(count(5), "5 вопросов")
        XCTAssertEqual(count(11), "11 вопросов")
        XCTAssertEqual(count(21), "21 вопрос")
    }

    func testDurationGluesEachNumberToItsUnitButKeepsTheBreakBetweenParts() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let text = WeeklyFormat.duration(7 * 3600 + 42 * 60)
            XCTAssertFalse(text.range(of: #"\d "#, options: .regularExpression) != nil,
                           "\(language): «\(text)» splits a number from its unit")
            XCTAssertFalse(WeeklyFormat.duration(15 * 60).range(of: #"\d "#, options: .regularExpression) != nil)
        }
    }

    /// One feed reads the same minutes in its history row and in a summary:
    /// both floor, so 90–119 s is «1 min» everywhere.
    func testASummaryFloorsMinutesAsTheHistoryRowDoes() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for language in [SupportedLanguage.en, .ru, .fr] {
            LocalizationManager.shared.setLanguage(language)
            for seconds in [60.0, 90, 100, 119, 119.6, 179.9, 3599.5] {
                let feed = FeedingEntry(startTime: start, type: .breast, side: .left)
                feed.endTime = start.addingTimeInterval(seconds)
                XCTAssertEqual(WeeklyFormat.duration(seconds), feed.durationFormatted, "\(language) \(seconds) s")
                XCTAssertEqual(ReportFormat.duration(seconds).replacingOccurrences(of: nbsp, with: " "),
                               feed.durationFormatted.replacingOccurrences(of: nbsp, with: " "),
                               "\(language) \(seconds) s")
            }
            XCTAssertEqual(WeeklyFormat.duration(100), DurationText.minutes(1), "\(language)")
        }
        // An average of doubles a hair under a whole minute keeps that minute.
        XCTAssertEqual(WeeklyFormat.wholeMinutes(26_999.9999), 450)
        XCTAssertEqual(WeeklyFormat.wholeMinutes(59.4), 0)
    }

    /// The weekly card's arrow compares the two shown values, not the raw seconds.
    func testTheSleepDeltaIsTheDifferenceOfTheFlooredMinutes() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertNil(WeeklyFormat.sleepDelta(8 * 3600 + 59, 8 * 3600), "both read 8 h 0 min")
        let delta = WeeklyFormat.sleepDelta(8 * 3600 + 60, 8 * 3600 + 59)
        XCTAssertEqual(delta?.up, true)
        XCTAssertEqual(delta?.text, WeeklyFormat.duration(60))
        XCTAssertEqual(WeeklyFormat.sleepDelta(7 * 3600, 7 * 3600 + 150)?.up, false)
        XCTAssertEqual(WeeklyFormat.sleepDelta(7 * 3600, 7 * 3600 + 150)?.text, WeeklyFormat.duration(120))
    }

    /// The report screen's period line: «20 days» and «13 окт.» never split,
    /// and a visit today reads the word, not «0 days».
    func testTheReportPeriodAndDateHoldTogether() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(ReportFormat.periodLength(days: 20), PluralFamily.durationDays.text(20), "\(language)")
            XCTAssertEqual(ReportFormat.periodLength(days: 0), "report.period_today".l, "\(language)")
            let date = ReportFormat.dayMonth(now)
            XCTAssertFalse(date.contains(" "), "\(language): «\(date)»")
            XCTAssertEqual(date.replacingOccurrences(of: nbsp, with: " "), now.appDayMonth, "\(language)")
        }
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(ReportFormat.periodLength(days: 21), "21\(nbsp)день")
    }

    /// A report range is the language's own interval, its year only when an
    /// end is not this year's, and it breaks only after its dash.
    func testAReportRangeIsTheLanguagesIntervalWithTheYearOnlyWhenOld() throws {
        let thin = "\u{2009}"
        LocalizationManager.shared.setLanguage(.en)
        let calendar = LocalizationManager.shared.language.calendar
        func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
        }
        // `now` is 15 January 2027.
        XCTAssertEqual(ReportFormat.dayRange(try day(2027, 1, 3), try day(2027, 1, 9), now: now),
                       "Jan\(nbsp)3\(thin)–\(thin)9")
        XCTAssertEqual(ReportFormat.dayRange(try day(2027, 1, 3), try day(2027, 1, 3), now: now), "Jan\(nbsp)3")
        XCTAssertEqual(ReportFormat.dayRange(try day(2026, 12, 28), try day(2027, 1, 3), now: now),
                       "Dec\(nbsp)28,\(nbsp)2026\(thin)–\(thin)Jan\(nbsp)3,\(nbsp)2027")
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(ReportFormat.dayRange(try day(2026, 11, 2), try day(2026, 11, 20), now: now),
                       "2—20\(nbsp)нояб.\(nbsp)2026\u{202F}г.")
    }
}

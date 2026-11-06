import XCTest
@testable import BabyBloom

/// `Baby.describeAge(from:to:)` is the one phrase for an age everywhere — the
/// app header, the Dashboard, onboarding's loader, the weight chart's readout
/// and the percentile caption — so its unit boundaries are pinned here.
///
/// The trap these guard: the switch from weeks to months used to happen at
/// day 30 regardless of the calendar, and day 30 of a 31-day month is not yet
/// a month, so the phrase read "0 months" (DECISIONS 2026-09-23).
final class AgeDescriptionTests: XCTestCase {

    /// The number and its word are joined by a no-break space, so a wrapped
    /// line never starts with the word alone (DECISIONS 2026-11-06).
    private let nbsp = "\u{00A0}"

    override func setUp() {
        super.setUp()
        // Russian has the three-way plural, the strictest of the three
        // languages. Restored, because other suites assert on English output.
        let original = LocalizationManager.shared.language
        addTeardownBlock { LocalizationManager.shared.setLanguage(original) }
        LocalizationManager.shared.setLanguage("ru")
    }

    /// Noon, so no DST transition can move a date across midnight.
    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func age(_ from: Date, _ to: Date) -> String {
        Baby.describeAge(from: from, to: to)
    }

    // MARK: - The weeks → months boundary

    func testDay30OfA31DayMonthIsWeeksNotZeroMonths() {
        // 23 Jul → 22 Aug: 30 days, and no calendar month has elapsed yet.
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 8, 22)), "4\(nbsp)\(4.weekWord)")
    }

    func testMonthsStartOnceACalendarMonthHasElapsed() {
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 8, 23)), "1\(nbsp)\(1.monthWord)")
    }

    func testAFebruaryBirthStaysInWeeksUntilDay30() {
        // A whole calendar month that is shorter than 30 days is still weeks:
        // the day-30 floor applies even once a month has passed. 28 days, and
        // 29 in a leap year — the case that pins the floor at exactly 30.
        XCTAssertEqual(age(day(2026, 2, 1), day(2026, 3, 1)), "4\(nbsp)\(4.weekWord)")
        XCTAssertEqual(age(day(2028, 2, 1), day(2028, 3, 1)), "4\(nbsp)\(4.weekWord)")
    }

    func testAnEndOfMonthBirthReachesAMonthByDay30() {
        // 31 Jan → 2 Mar is 30 days, and the calendar counts it a month
        // (31 Jan + 1 month clamps to 28 Feb), so both conditions hold.
        XCTAssertEqual(age(day(2026, 1, 31), day(2026, 3, 2)), "1\(nbsp)\(1.monthWord)")
    }

    // MARK: - Days and weeks

    func testTheFirstWeekCountsDays() {
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 7, 23)), "0\(nbsp)\(0.dayWord)")
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 7, 26)), "3\(nbsp)\(3.dayWord)")
        // Day 6 is the last in days: switching a day earlier would print "0 weeks".
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 7, 29)), "6\(nbsp)\(6.dayWord)")
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 7, 30)), "1\(nbsp)\(1.weekWord)")
    }

    func testAnEndBeforeTheStartClampsToZeroDays() {
        XCTAssertEqual(age(day(2026, 7, 23), day(2026, 7, 20)), "0\(nbsp)\(0.dayWord)")
    }

    // MARK: - The `to:` parameter

    func testTheEndDefaultsToNow() {
        let birth = Calendar.current.date(byAdding: .day, value: -45, to: Date())!
        XCTAssertEqual(Baby.describeAge(from: birth), Baby.describeAge(from: birth, to: Date()))
    }

    // MARK: - What a parent reads

    /// Spelled out once, so a broken plural rule cannot hide behind the same
    /// helper producing both sides of every assertion above.
    func testRussianWording() {
        let birth = day(2026, 7, 23)
        XCTAssertEqual(age(birth, birth), "0\u{00A0}дней")
        XCTAssertEqual(age(birth, day(2026, 8, 22)), "4\u{00A0}недели")
        XCTAssertEqual(age(birth, day(2026, 9, 23)), "2\u{00A0}месяца")
        XCTAssertEqual(age(birth, day(2026, 12, 23)), "5\u{00A0}месяцев")
    }

    func testEnglishAndSpanishWording() {
        let birth = day(2026, 7, 23)
        LocalizationManager.shared.setLanguage("en")
        XCTAssertEqual(age(birth, day(2026, 7, 30)), "1\u{00A0}week")
        XCTAssertEqual(age(birth, day(2026, 9, 23)), "2\u{00A0}months")
        LocalizationManager.shared.setLanguage("es")
        XCTAssertEqual(age(birth, day(2026, 7, 26)), "3\u{00A0}días")
        XCTAssertEqual(age(birth, day(2026, 9, 23)), "2\u{00A0}meses")
    }

    /// No plain space survives in any language or unit, from the birth day to
    /// past two years: a plain one lets a narrow line start with the word.
    func testNoAgeHasAPlainSpace() {
        let birth = day(2026, 1, 31)
        for language in SupportedLanguage.allCases {
            LocalizationManager.shared.setLanguage(language)
            for offset in stride(from: 0, through: 800, by: 3) {
                let end = Calendar.current.date(byAdding: .day, value: offset, to: birth)!
                let phrase = age(birth, end)
                XCTAssertFalse(phrase.contains(" "), "\(language) day \(offset): «\(phrase)»")
                XCTAssertTrue(phrase.contains(nbsp), "\(language) day \(offset): «\(phrase)»")
            }
        }
    }
}

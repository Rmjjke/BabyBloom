import XCTest
@testable import BabyBloom

/// Guards the defect these helpers exist to close: on-screen dates used to
/// follow the DEVICE language, so an English UI on a Russian phone showed
/// English labels beside Russian dates.
final class DateAppLocaleTests: XCTestCase {

    private let reference = DateComponents(calendar: Calendar(identifier: .gregorian),
                                           timeZone: .current,
                                           year: 2026, month: 8, day: 25,
                                           hour: 14, minute: 30).date!

    private let cyrillic = CharacterSet(charactersIn: "\u{0410}"..."\u{044F}")
    private let latin = CharacterSet(charactersIn: "A"..."z")

    /// Asserted by SCRIPT rather than by exact wording: the month's spelling
    /// belongs to CLDR and shifts between iOS releases, but "Russian renders
    /// in Cyrillic, English does not" is the property under test.
    func testDayMonthFollowsTheAppLanguageNotTheDevice() {
        LocalizationManager.shared.setLanguage("ru")
        let ru = reference.appDayMonth
        XCTAssertNotNil(ru.rangeOfCharacter(from: cyrillic), "ru rendered without Cyrillic: \(ru)")

        LocalizationManager.shared.setLanguage("en")
        let en = reference.appDayMonth
        XCTAssertNil(en.rangeOfCharacter(from: cyrillic), "en leaked Cyrillic: \(en)")
        XCTAssertNotNil(en.rangeOfCharacter(from: latin), "en rendered without letters: \(en)")

        LocalizationManager.shared.setLanguage("es")
        let es = reference.appDayMonth
        XCTAssertNil(es.rangeOfCharacter(from: cyrillic), "es leaked Cyrillic: \(es)")

        XCTAssertNotEqual(en, ru, "en and ru rendered identically — the locale never took")
    }

    /// The clock is the device's and the words are the language's: on a
    /// 12-hour phone English says PM where Spanish says p. m.; on a 24-hour
    /// phone every language reads 14:30 (Danish and Finnish 14.30, their own
    /// separator). Pinned to each cycle so the test does
    /// not depend on the simulator's own setting.
    func testTimeOfDayTakesTheLanguagesWordsOnTheDevicesClock() {
        let en = reference.appTimeOfDay(in: SupportedLanguage.en.environmentLocale(hourCycle: .oneToTwelve))
        let es = reference.appTimeOfDay(in: SupportedLanguage.es.environmentLocale(hourCycle: .oneToTwelve))
        XCTAssertTrue(en.contains("2:30") && en.contains("PM"), "en on a 12-hour clock: \(en)")
        XCTAssertTrue(es.contains("2:30") && es.contains("p."), "es on a 12-hour clock: \(es)")

        for language in SupportedLanguage.allCases {
            let text = reference.appTimeOfDay(in: language.environmentLocale(hourCycle: .zeroToTwentyThree))
            XCTAssertNotNil(text.range(of: "14[:.]30", options: .regularExpression), "\(language) on a 24-hour clock: \(text)")
        }
    }

    /// Switching the language must change what the SAME date renders as —
    /// otherwise a helper could be caching the first locale it saw.
    func testRenderingTracksLanguageChanges() {
        LocalizationManager.shared.setLanguage("en")
        let first = reference.appDayMonth
        LocalizationManager.shared.setLanguage("ru")
        let second = reference.appDayMonth
        LocalizationManager.shared.setLanguage("en")
        let third = reference.appDayMonth

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, third, "switching back did not restore the English rendering")
    }
}

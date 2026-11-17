import XCTest
@testable import BabyBloom

/// One clock on screen: the times the app formats and the date pickers take
/// the device's 12/24-hour cycle, in the app's language.
final class TimeHourCycleTests: XCTestCase {

    override func tearDown() {
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// 14:30 on a fixed day, in the simulator's own time zone.
    private var halfPastTwo: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 14, minute: 30))!
    }

    func testEveryLanguageFollowsA24HourDevice() {
        for language in SupportedLanguage.allCases {
            let text = halfPastTwo.appTimeOfDay(in: language.environmentLocale(hourCycle: .zeroToTwentyThree))
            XCTAssertTrue(text.contains("14"), "\(language): «\(text)»")
            XCTAssertFalse(text.contains("2:30"), "\(language): «\(text)»")
        }
    }

    func testEveryLanguageFollowsA12HourDevice() {
        for language in SupportedLanguage.allCases {
            let text = halfPastTwo.appTimeOfDay(in: language.environmentLocale(hourCycle: .oneToTwelve))
            // Danish and Finnish separate with a dot: 2.30 PM.
            XCTAssertNotNil(text.range(of: "2[:.]30", options: .regularExpression), "\(language): «\(text)»")
            XCTAssertFalse(text.contains("14"), "\(language): «\(text)»")
        }
    }

    /// Russian keeps its words on a 12-hour phone; only the clock changes.
    func testTheLanguageStaysWhenTheClockChanges() {
        let locale = SupportedLanguage.ru.environmentLocale(hourCycle: .oneToTwelve)
        XCTAssertEqual(locale.language.languageCode?.identifier, "ru")
        XCTAssertEqual(locale.region?.identifier, "RU")
        XCTAssertEqual(locale.hourCycle, .oneToTwelve)
    }

    /// The export PDF prints the screen's time on either clock in every
    /// language, Russian on a 12-hour phone included, and its dates and times
    /// take the screen's locale.
    func testTheExportPDFPrintsTheScreensClock() {
        for language in SupportedLanguage.allCases {
            for cycle in [Locale.HourCycle.oneToTwelve, .zeroToTwentyThree] {
                let locale = language.environmentLocale(hourCycle: cycle)
                XCTAssertEqual(ExportGenerator.documentTimeFormatter(in: locale).string(from: halfPastTwo),
                               halfPastTwo.appTimeOfDay(in: locale), "\(language) \(cycle)")
            }
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(ExportGenerator.documentFormatter { _ in }.locale, language.environmentLocale, "\(language)")
        }
    }

    /// The export document's text: a feed at 14:30 prints the screen's time
    /// on a 12-hour and on a 24-hour phone, in every language, and on the
    /// device's own clock when no cycle is given, as the app exports it.
    func testTheExportDocumentPrintsTheFeedOnEitherClock() {
        let feed = FeedingEntry(startTime: halfPastTwo, type: .formula, side: nil, volumeML: 120)
        feed.endTime = halfPastTwo.addingTimeInterval(15 * 60)
        for language in SupportedLanguage.allCases {
            LocalizationManager.shared.setLanguage(language)
            for cycle in [Locale.HourCycle.oneToTwelve, .zeroToTwentyThree] {
                let page = ExportGenerator.buildHTML(
                    baby: nil, feedings: [feed], sleeps: [], diapers: [], growths: [], events: [],
                    categories: [.feeding], range: .all, hourCycle: cycle)
                let time = halfPastTwo.appTimeOfDay(in: language.environmentLocale(hourCycle: cycle))
                XCTAssertNotNil(time.range(of: cycle == .oneToTwelve ? "2[:.]30" : "14[:.]30", options: .regularExpression),
                                "\(language) \(cycle): \(time)")
                XCTAssertTrue(page.contains(ExportGenerator.htmlEscape(time)), "\(language) \(cycle): \(time)")
            }
            let devicePage = ExportGenerator.buildHTML(
                baby: nil, feedings: [feed], sleeps: [], diapers: [], growths: [], events: [],
                categories: [.feeding], range: .all)
            XCTAssertTrue(devicePage.contains(ExportGenerator.htmlEscape(halfPastTwo.appTimeOfDay)),
                          "\(language) on the device's clock: \(halfPastTwo.appTimeOfDay)")
        }
    }

    /// The pickers get the environment locale (BabyBloomApp); the formatted
    /// times use the very same one, so the two cannot show different clocks.
    func testFormattedTimesAndPickersShareOneLocale() {
        for language in SupportedLanguage.allCases {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(Date.appTimeLocale, language.environmentLocale, "\(language)")
            XCTAssertEqual(Date.appTimeLocale.hourCycle, Locale.current.hourCycle, "\(language)")
            XCTAssertEqual(halfPastTwo.appTimeOfDay, halfPastTwo.appTimeOfDay(in: language.environmentLocale))
        }
    }
}

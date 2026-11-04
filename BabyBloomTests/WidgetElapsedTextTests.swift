import XCTest
@testable import BabyBloom

/// The widget's time since an event: hours and minutes below 48 hours, whole
/// days from there, rounded down, in each language's forms. Durations that are
/// not time since an event keep their hours.
final class WidgetElapsedTextTests: XCTestCase {

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

    private func hours(_ hours: Double) -> TimeInterval { hours * 3600 }

    /// The hours-and-minutes form, whatever spaces the copy glues inside it.
    private func hoursAndMinutes(_ h: Int, _ m: Int) -> String {
        String(format: "duration.h_min".l, h, m).gluingNumbersToUnits
    }

    func testBelowFortyEightHoursReadsHoursAndMinutes() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let text = WidgetCopy.elapsedText(hours(47) + 59 * 60)
            XCTAssertEqual(text, hoursAndMinutes(47, 59), "\(language)")
            XCTAssertTrue(text.hasPrefix("47\(nbsp)"), "\(language): \(text)")
        }
    }

    func testFromFortyEightHoursReadsWholeDays() {
        let expected: [SupportedLanguage: (two: String, five: String, thirteen: String, twentyOne: String)] = [
            .en: ("2\(nbsp)days", "5\(nbsp)days", "13\(nbsp)days", "21\(nbsp)days"),
            // ru: few, many, many (11–19), one.
            .ru: ("2\(nbsp)дня", "5\(nbsp)дней", "13\(nbsp)дней", "21\(nbsp)день"),
            .es: ("2\(nbsp)días", "5\(nbsp)días", "13\(nbsp)días", "21\(nbsp)días"),
        ]
        for (language, text) in expected {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(WidgetCopy.elapsedText(hours(48)), text.two, "\(language)")
            // Rounded down: 2 days 23 h 59 min is still 2 days.
            XCTAssertEqual(WidgetCopy.elapsedText(hours(71) + 59 * 60), text.two, "\(language)")
            XCTAssertEqual(WidgetCopy.elapsedText(hours(5 * 24 + 11)), text.five, "\(language)")
            XCTAssertEqual(WidgetCopy.elapsedText(hours(13 * 24)), text.thirteen, "\(language)")
            XCTAssertEqual(WidgetCopy.elapsedText(hours(21 * 24)), text.twentyOne, "\(language)")
        }
    }

    /// The Live Activity's ended timer and the onboarding showcase's sleep
    /// length are durations, not time since an event: they keep their hours.
    func testDurationsKeepTheirHours() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(WidgetCopy.minutesText(hours(50) + 5 * 60), hoursAndMinutes(50, 5))
    }
}

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
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(0.5), to: now), String(format: "stats.min_ago".l, 30))
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(47.9), to: now), String(format: "stats.h_ago".l, 47))
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(48), to: now),
                       String(format: "stats.days_ago_fmt".l, "2\(nbsp)\(2.dayWord)"))
        // Floored: 2 days 23 hours is still «2 days», never rounded up to 3.
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(71), to: now),
                       String(format: "stats.days_ago_fmt".l, "2\(nbsp)\(2.dayWord)"))
        XCTAssertEqual(ReportFormat.ago(from: hoursAgo(131), to: now),
                       String(format: "stats.days_ago_fmt".l, "5\(nbsp)\(5.dayWord)"))
    }

    func testAgoUsesTheRussianDayPlurals() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertTrue(ReportFormat.ago(from: hoursAgo(50), to: now).contains("2\(nbsp)дня"))
        XCTAssertTrue(ReportFormat.ago(from: hoursAgo(130), to: now).contains("5\(nbsp)дней"))
    }

    func testAFutureStartReadsAsZeroMinutesNotNegative() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(ReportFormat.ago(from: now.addingTimeInterval(120), to: now),
                       String(format: "stats.min_ago".l, 0))
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
}

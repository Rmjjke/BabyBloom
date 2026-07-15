import XCTest
@testable import BabyBloom

final class ExportGeneratorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Deterministic language for assertions on localized output.
        LocalizationManager.shared.setLanguage("en")
    }

    // MARK: - CSV escaping

    func testCSVEscapesQuotesAndCommas() {
        // Notes contain a comma, double-quotes and a newline — all of which must
        // trigger RFC-4180 escaping (wrap in quotes, double the inner quotes).
        let diaper = DiaperEntry(
            time: Date(),
            type: .wet,
            color: .yellow,
            notes: "a,b \"c\"\nd"
        )
        let files = ExportGenerator.csvString(
            feedings: [], sleeps: [], diapers: [diaper], growths: [], events: [],
            categories: [.diapers]
        )
        let content = files.first { $0.name == "diapers.csv" }!.content

        XCTAssertTrue(content.contains("\"a,b \"\"c\"\"\nd\""),
                      "Notes field must be quoted with inner quotes doubled")
        // A field without special characters must NOT be wrapped in quotes.
        XCTAssertEqual(ExportGenerator.csvField("plain"), "plain")
    }

    // MARK: - CSV localization

    func testCSVUsesLocalizedValues() {
        LocalizationManager.shared.setLanguage("en")
        let feeding = FeedingEntry(startTime: Date(), type: .formula, side: nil, volumeML: 120)
        let files = ExportGenerator.csvString(
            feedings: [feeding], sleeps: [], diapers: [], growths: [], events: [],
            categories: [.feeding]
        )
        let content = files.first!.content

        // Type column must use the localized display name, not the raw enum value.
        let localizedType = FeedingEntry.FeedingType.formula.displayName.l
        XCTAssertEqual(localizedType, "Formula")
        XCTAssertTrue(content.contains("Formula"), "CSV must contain localized value")

        // Header row must be localized too.
        XCTAssertTrue(content.contains("export.csv.date".l))
        XCTAssertTrue(content.contains("export.csv.type".l))
    }

    // MARK: - Average per day (all-time range)

    func testAvgPerDayForAllRangeUsesEarliestEntry() {
        let now = Date()
        let earliest = Calendar.current.date(byAdding: .day, value: -10, to: now)!

        let avg = ExportGenerator.averagePerDay(count: 20, range: .all, earliest: earliest, now: now)

        // 20 entries over 10 days = 2.0/day.
        XCTAssertEqual(avg, 2.0, accuracy: 0.0001)
        // The old implementation assumed a 30-day window for `.all` (20/30 ≈ 0.667).
        XCTAssertNotEqual(avg, 20.0 / 30.0, accuracy: 0.0001)
    }

    func testAvgPerDayZeroWhenNoEntries() {
        let avg = ExportGenerator.averagePerDay(count: 0, range: .all, earliest: nil)
        XCTAssertEqual(avg, 0)
    }
}

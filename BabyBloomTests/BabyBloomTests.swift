import XCTest
import SwiftData
@testable import BabyBloom

final class BabyBloomTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Pin the language so localized formatters (units, percentile tails) are
        // deterministic regardless of the host's saved preference.
        LocalizationManager.shared.setLanguage("ru")
    }

    // MARK: - Baby Model Tests
    func testBabyAgeCalculation() {
        let birthDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let baby = Baby(name: "Тест", birthDate: birthDate, gender: .female, feedingType: .breast)
        XCTAssertEqual(baby.ageInDays, 10)
        XCTAssertEqual(baby.ageInWeeks, 1)
        XCTAssertEqual(baby.ageInMonths, 0)
    }

    func testBabyAgeDescription() {
        let birthDate3Days = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let baby3Days = Baby(name: "Тест", birthDate: birthDate3Days, gender: .male, feedingType: .formula)
        XCTAssertTrue(baby3Days.ageDescription.contains("дня") || baby3Days.ageDescription.contains("дней") || baby3Days.ageDescription.contains("день"))

        let birthDate2Months = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let baby2Months = Baby(name: "Тест", birthDate: birthDate2Months, gender: .female, feedingType: .mixed)
        XCTAssertTrue(baby2Months.ageDescription.contains("месяц") || baby2Months.ageDescription.contains("месяца"))
    }

    // MARK: - Russian Pluralization Tests
    func testIntDayWord() {
        XCTAssertEqual(1.dayWord, "день")
        XCTAssertEqual(2.dayWord, "дня")
        XCTAssertEqual(5.dayWord, "дней")
        XCTAssertEqual(11.dayWord, "дней")
        XCTAssertEqual(21.dayWord, "день")
    }

    func testIntMonthWord() {
        XCTAssertEqual(1.monthWord, "месяц")
        XCTAssertEqual(3.monthWord, "месяца")
        XCTAssertEqual(12.monthWord, "месяцев")
    }

    // MARK: - Notification Manager Tests
    func testAverageIntervalCalculation() {
        let manager = NotificationManager.shared
        let now = Date()
        let times = [
            now.addingTimeInterval(-3600 * 4),
            now.addingTimeInterval(-3600 * 2),
            now
        ]
        let avg = manager.calculateAverageIntervalMinutes(times: times)
        XCTAssertEqual(avg, 120, accuracy: 1)
    }

    func testAverageIntervalWithSingleEntry() {
        let manager = NotificationManager.shared
        let avg = manager.calculateAverageIntervalMinutes(times: [Date()])
        XCTAssertEqual(avg, 120) // default
    }

    // MARK: - Growth Entry Tests
    func testGrowthEntryFormatting() {
        let entry = GrowthEntry(weightKg: 4.25, heightCm: 56.5, headCircumferenceCm: 38.0)
        // The test host runs in Russian: the comma is the fix, the
        // dot this test used to pin was the bug. A no-break space glues the
        // unit to its number.
        XCTAssertEqual(entry.weightFormatted, "4,25\u{00A0}кг")
        XCTAssertEqual(entry.heightFormatted, "56,5\u{00A0}см")
        XCTAssertEqual(entry.headFormatted, "38,0\u{00A0}см")
    }

    func testGrowthEntrySmallWeight() {
        let entry = GrowthEntry(weightKg: 0.8)
        XCTAssertEqual(entry.weightFormatted, "800\u{00A0}г")
    }

    // MARK: - Feeding Entry Tests
    func testFeedingEntryDuration() {
        let start = Date().addingTimeInterval(-300) // 5 min ago
        let entry = FeedingEntry(startTime: start, type: .breast)
        entry.endTime = Date()
        XCTAssertEqual(Int(entry.duration), 300, accuracy: 2)
    }

    func testFeedingEntryIsActive() {
        let entry = FeedingEntry(startTime: Date(), type: .formula, volumeML: 80)
        XCTAssertTrue(entry.isActive)
        entry.endTime = Date()
        XCTAssertFalse(entry.isActive)
    }

    // MARK: - WHO Percentile Tests
    // Ages are days now, not months: the tables are day-resolved so that the
    // first weeks, where the curve moves fastest, are not smeared into "month 0".
    func testWHOPercentileNormal() throws {
        // 6.4 kg is the WHO median weight for a 3-month-old boy → should land near the
        // 50th percentile (a median weight falls comfortably inside the 40–70 range).
        let percentile = try XCTUnwrap(WHOGrowthStandard.percentile(weightKg: 6.4, ageDays: 91, isMale: true))
        XCTAssertGreaterThan(percentile, 40)
        XCTAssertLessThan(percentile, 70)
    }

    func testWHOPercentileAt18Months() throws {
        // Regression: before the z-score fix the table stopped at 12 months, so an
        // 18-month-old was scored against the 12-month median and read far too high.
        // A median-weight 18-month boy (10.9 kg) must sit near the 50th percentile.
        let percentile = try XCTUnwrap(WHOGrowthStandard.percentile(weightKg: 10.9, ageDays: 548, isMale: true))
        XCTAssertGreaterThan(percentile, 30)
        XCTAssertLessThan(percentile, 70)
    }

    func testWHOPercentileMedianGirlIs50() throws {
        // Sanity check: a median-weight 3-month-old girl (5.8 kg) is the 50th percentile.
        let percentile = try XCTUnwrap(WHOGrowthStandard.percentile(weightKg: 5.8, ageDays: 91, isMale: false))
        XCTAssertEqual(percentile, 50, accuracy: 2)
    }

    /// The card's figure is the number inside the chart, its tails included,
    /// and the side past its edge; a sentence names that side in words.
    func testWHOPercentileFigureAndTailWords() {
        let inside = WHOGrowthStandard.PercentileReading(percentile: 50, isBeyondChart: false)
        XCTAssertEqual(inside.badge, "50")
        // The ordinal's hyphen is U+2011, so a narrow row never breaks «50-й» apart.
        XCTAssertEqual(inside.rowText(format: "dashboard.growth.percentile_fmt".l), "50\u{2011}й перцентиль")
        XCTAssertEqual(WHOGrowthStandard.PercentileReading(percentile: 2, isBeyondChart: false).badge, "2")
        let below = WHOGrowthStandard.PercentileReading(percentile: 1, isBeyondChart: true)
        XCTAssertEqual(below.badge, "< 3")
        XCTAssertEqual(below.rowText(format: "%d"), "< 3\u{2011}й")
        let above = WHOGrowthStandard.PercentileReading(percentile: 99, isBeyondChart: true)
        XCTAssertEqual(above.badge, "> 97")
        XCTAssertEqual(above.rowText(format: "%d"), "> 97\u{2011}го")
    }

    // MARK: - Schema Validity
    // The whole schema builds a container and takes a save. The CloudKit
    // rules (defaults on stored properties, optional inverses) are pinned in
    // `AppSchemaTests`: with the store local only, nothing checks them at launch.
    func testModelContainerSchemaIsValid() throws {
        let schema = AppSchema.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let baby = Baby(name: "Тест", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Baby>()), 1)
    }
}

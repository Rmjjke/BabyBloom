import XCTest
@testable import BabyBloom

final class BabyBloomTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Pin the language so localized formatters (units, percentile bands) are
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
        XCTAssertEqual(entry.weightFormatted, "4.25 кг")
        XCTAssertEqual(entry.heightFormatted, "56.5 см")
        XCTAssertEqual(entry.headFormatted, "38.0 см")
    }

    func testGrowthEntrySmallWeight() {
        let entry = GrowthEntry(weightKg: 0.8)
        XCTAssertEqual(entry.weightFormatted, "800 г")
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
    func testWHOPercentileNormal() {
        // 6.4 kg is the WHO median weight for a 3-month-old boy → should land near the
        // 50th percentile (a median weight falls comfortably inside the 40–70 range).
        let percentile = WHOPercentile.weightPercentile(ageMonths: 3, weightKg: 6.4, isMale: true)
        XCTAssertGreaterThan(percentile, 40)
        XCTAssertLessThan(percentile, 70)
    }

    func testWHOPercentileAt18Months() {
        // Regression: before the z-score fix the table stopped at 12 months, so an
        // 18-month-old was scored against the 12-month median and read far too high.
        // A median-weight 18-month boy (10.9 kg) must sit near the 50th percentile.
        let percentile = WHOPercentile.weightPercentile(ageMonths: 18, weightKg: 10.9, isMale: true)
        XCTAssertGreaterThan(percentile, 30)
        XCTAssertLessThan(percentile, 70)
    }

    func testWHOPercentileMedianGirlIs50() {
        // Sanity check: a median-weight 3-month-old girl (5.8 kg) is the 50th percentile.
        let percentile = WHOPercentile.weightPercentile(ageMonths: 3, weightKg: 5.8, isMale: false)
        XCTAssertEqual(percentile, 50, accuracy: 1)
    }

    func testWHOPercentileLabel() {
        XCTAssertEqual(WHOPercentile.percentileLabel(50), "15–50")
        XCTAssertEqual(WHOPercentile.percentileLabel(1), "< 3-й")
        XCTAssertEqual(WHOPercentile.percentileLabel(98), "> 97-го")
    }
}

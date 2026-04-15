import XCTest
@testable import BabyBloom

final class BabyBloomTests: XCTestCase {

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

    // MARK: - Notification Service Tests
    func testAverageIntervalCalculation() async {
        let service = NotificationService.shared
        let now = Date()
        let times = [
            now.addingTimeInterval(-3600 * 4),
            now.addingTimeInterval(-3600 * 2),
            now
        ]
        let avg = await service.calculateAverageIntervalMinutes(times: times)
        XCTAssertEqual(avg, 120, accuracy: 1)
    }

    func testAverageIntervalWithSingleEntry() async {
        let service = NotificationService.shared
        let avg = await service.calculateAverageIntervalMinutes(times: [Date()])
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
        let percentile = WHOPercentile.weightPercentile(ageMonths: 3, weightKg: 6.4, isMale: false)
        XCTAssertGreaterThan(percentile, 40)
        XCTAssertLessThan(percentile, 70)
    }

    func testWHOPercentileLabel() {
        XCTAssertEqual(WHOPercentile.percentileLabel(50), "15–50")
        XCTAssertEqual(WHOPercentile.percentileLabel(1), "< 3-й")
        XCTAssertEqual(WHOPercentile.percentileLabel(98), "> 97-го")
    }
}

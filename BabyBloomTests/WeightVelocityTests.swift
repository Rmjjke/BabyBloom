import XCTest
@testable import BabyBloom

final class WeightVelocityTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -120, to: Date())!

    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    private func measure(_ a: WeightMeasurement, _ b: WeightMeasurement, male: Bool = true) -> WeightVelocity.Reading? {
        WeightVelocity.measure(from: a, to: b, correctedBirthDate: birth, isMale: male)
    }

    // MARK: - Guards

    /// Over a day or two a wet nappy outweighs the trend, so there is no honest
    /// answer to give.
    func testIntervalsShorterThanThreeDaysAreRefused() {
        XCTAssertNil(measure(at(10, 3.5), at(12, 3.6)))
        XCTAssertNotNil(measure(at(10, 3.5), at(13, 3.6)))
    }

    func testOutOfOrderOrEmptyInputIsRefused() {
        XCTAssertNil(measure(at(20, 4.0), at(10, 3.5)))
        XCTAssertNil(measure(at(10, 0), at(20, 4.0)))
        XCTAssertNil(WeightVelocity.latest(measurements: [at(10, 3.5)], correctedBirthDate: birth, isMale: true))
    }

    // MARK: - Rate

    func testRateIsNormalisedPerDayAndReportedPerWeek() throws {
        // +700 g over 14 days = 50 g/day = 350 g/week.
        let r = try XCTUnwrap(measure(at(14, 4.0), at(28, 4.7)))
        XCTAssertEqual(r.gramsPerDay, 50, accuracy: 0.01)
        XCTAssertEqual(r.gramsPerWeek, 350, accuracy: 0.1)
        XCTAssertEqual(r.intervalDays, 14)
    }

    func testWeightLossProducesANegativeRate() throws {
        let r = try XCTUnwrap(measure(at(30, 4.5), at(44, 4.3)))
        XCTAssertLessThan(r.gramsPerDay, 0)
        XCTAssertEqual(r.band, .below)
    }

    // MARK: - Bands against WHO references

    /// WHO 1-month increments for boys, 0–4 weeks: P15 = 24.3 g/day,
    /// P85 = 47.7 g/day. The band edges are checked from both sides.
    func testBandEdgesForTheFirstMonthMatchWHO() throws {
        let reference = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        XCTAssertEqual(reference.lowerBound, 24.32, accuracy: 0.01)
        XCTAssertEqual(reference.upperBound, 47.71, accuracy: 0.01)

        // 20 g/day sits below P15, 35 inside, 60 above.
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.020 * 14))?.band, .below)
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.035 * 14))?.band, .within)
        XCTAssertEqual(measure(at(7, 3.5), at(21, 3.5 + 0.060 * 14))?.band, .above)
    }

    /// Girls gain a little slower, and the tables say so: the same rate can be
    /// inside the band for a girl and below it for a boy.
    func testReferencesDifferBySex() throws {
        let boys = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        let girls = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: false))
        XCTAssertGreaterThan(boys.lowerBound, girls.lowerBound)
        XCTAssertGreaterThan(boys.upperBound, girls.upperBound)
    }

    /// Expected gain slows sharply over the first year — a rate that is normal at
    /// two weeks is well above the band at eleven months.
    func testExpectedGainFallsWithAge() throws {
        let early = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 14, isMale: true))
        let late = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 350, isMale: true))
        XCTAssertGreaterThan(early.lowerBound, late.lowerBound)
        XCTAssertGreaterThan(early.upperBound, late.upperBound)
    }

    // MARK: - Range limits

    /// Past 12 months there is no velocity reference. The measured rate is still
    /// reported — it is a fact — but without a band, rather than against a
    /// borrowed one.
    func testPastTwelveMonthsTheRateHasNoBand() throws {
        XCTAssertNil(WeightVelocity.expectedPerDay(correctedAgeDays: 366, isMale: true))

        let old = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
        let a = WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: 380, to: old)!, weightKg: 10.0)
        let b = WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: 394, to: old)!, weightKg: 10.2)
        let r = try XCTUnwrap(WeightVelocity.measure(from: a, to: b, correctedBirthDate: old, isMale: true))
        XCTAssertNil(r.band)
        XCTAssertNil(r.expectedPerWeek)
        XCTAssertEqual(r.gramsPerDay, 200.0 / 14, accuracy: 0.01)
    }

    // MARK: - Prematurity

    /// A baby born at 32 weeks is compared against the reference for its
    /// corrected age, where expected gain is higher — so the same rate that is
    /// comfortably inside the band chronologically can be below it corrected.
    func testCorrectedAgeSelectsTheReference() throws {
        let baby = Baby(name: "Test", birthDate: birth, gender: .male, feedingType: .breast)
        baby.gestationalWeeks = 32

        let chronological = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: 120, isMale: true))
        let corrected = try XCTUnwrap(WeightVelocity.expectedPerDay(correctedAgeDays: baby.correctedAgeDays, isMale: true))
        XCTAssertEqual(baby.correctedAgeDays, 64)
        XCTAssertGreaterThan(corrected.lowerBound, chronological.lowerBound)
    }

    func testLatestUsesTheTwoMostRecentWeighings() throws {
        let r = try XCTUnwrap(WeightVelocity.latest(
            measurements: [at(0, 3.3), at(30, 4.2), at(44, 4.9)],
            correctedBirthDate: birth,
            isMale: true
        ))
        XCTAssertEqual(r.intervalDays, 14)
        XCTAssertEqual(r.gramsPerDay, 50, accuracy: 0.01)
    }
}

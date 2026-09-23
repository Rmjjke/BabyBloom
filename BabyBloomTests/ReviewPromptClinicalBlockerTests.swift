import XCTest
@testable import BabyBloom

/// The two clinical blockers are read off the growth engine, never re-derived.
/// Every GAIN fixture asserts the engine's band first, so a pass cannot come
/// from a fixture that was simply calm; the newborn-flag fixtures are sized
/// against `NewbornWeightLoss`'s own thresholds (10% loss, day 14).
final class ReviewPromptClinicalBlockerTests: XCTestCase {

    private let now = Date()

    private func date(dayOfLife: Int, from birth: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: dayOfLife, to: birth)!
    }

    private func birth(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    private func blockers(birth: Date, birthWeightKg: Double?,
                          _ measurements: [WeightMeasurement]) -> ReviewPromptPolicy.Blockers {
        ReviewPromptPolicy.clinicalBlockers(birthDate: birth, birthWeightKg: birthWeightKg,
                                            correctedBirthDate: birth, isMale: false,
                                            measurements: measurements, now: now)
    }

    /// A three-month-old who has barely gained over four weeks.
    func testBelowReferenceGainBlocks() {
        let birth = birth(daysAgo: 90)
        let weighings = [
            WeightMeasurement(date: date(dayOfLife: 60, from: birth), weightKg: 5.00),
            WeightMeasurement(date: date(dayOfLife: 88, from: birth), weightKg: 5.05),
        ]
        XCTAssertEqual(WeightVelocity.latest(measurements: weighings, correctedBirthDate: birth,
                                             isMale: false)?.band, .below)

        let result = blockers(birth: birth, birthWeightKg: 3.4, weighings)
        XCTAssertTrue(result.belowReferenceGain)
        XCTAssertFalse(result.newbornFlag)
    }

    /// Past six months, where `FeedingAdequacy` has stopped answering but the
    /// gain card still speaks — the reason the blocker reads the card's source.
    func testBelowReferenceGainBlocksPastSixMonths() {
        let birth = birth(daysAgo: 240)
        let weighings = [
            WeightMeasurement(date: date(dayOfLife: 200, from: birth), weightKg: 7.50),
            WeightMeasurement(date: date(dayOfLife: 235, from: birth), weightKg: 7.50),
        ]
        XCTAssertEqual(WeightVelocity.latest(measurements: weighings, correctedBirthDate: birth,
                                             isMale: false)?.band, .below)
        XCTAssertTrue(blockers(birth: birth, birthWeightKg: nil, weighings).belowReferenceGain)
    }

    func testHealthyGainDoesNotBlock() {
        let birth = birth(daysAgo: 90)
        let weighings = [
            WeightMeasurement(date: date(dayOfLife: 60, from: birth), weightKg: 5.00),
            WeightMeasurement(date: date(dayOfLife: 88, from: birth), weightKg: 5.75),
        ]
        XCTAssertEqual(WeightVelocity.latest(measurements: weighings, correctedBirthDate: birth,
                                             isMale: false)?.band, .within)
        XCTAssertEqual(blockers(birth: birth, birthWeightKg: 3.4, weighings), .none)
    }

    /// The newborn dip reads below every velocity reference, and the app does
    /// not call it a finding — so neither does this. A parent in the ordinary
    /// first fortnight is not an anxious-parent case by the app's own words.
    func testNewbornDipIsDeferredNotBlocking() {
        let birth = birth(daysAgo: 12)
        let course = [
            WeightMeasurement(date: date(dayOfLife: 0, from: birth), weightKg: 3.50),
            WeightMeasurement(date: date(dayOfLife: 4, from: birth), weightKg: 3.25),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.30),
        ]
        XCTAssertEqual(WeightVelocity.latest(measurements: course, correctedBirthDate: birth,
                                             isMale: false)?.band, .below)
        XCTAssertEqual(blockers(birth: birth, birthWeightKg: 3.5, course), .none)
    }

    func testLossOverTenPercentBlocks() {
        let birth = birth(daysAgo: 5)
        let course = [
            WeightMeasurement(date: date(dayOfLife: 0, from: birth), weightKg: 3.50),
            WeightMeasurement(date: date(dayOfLife: 4, from: birth), weightKg: 3.10),
        ]
        XCTAssertTrue(blockers(birth: birth, birthWeightKg: 3.5, course).newbornFlag)
    }

    func testNotRegainedByDayFourteenBlocks() {
        let birth = birth(daysAgo: 16)
        let course = [
            WeightMeasurement(date: date(dayOfLife: 0, from: birth), weightKg: 3.50),
            WeightMeasurement(date: date(dayOfLife: 4, from: birth), weightKg: 3.25),
            WeightMeasurement(date: date(dayOfLife: 10, from: birth), weightKg: 3.30),
        ]
        let result = blockers(birth: birth, birthWeightKg: 3.5, course)
        XCTAssertTrue(result.newbornFlag)
        XCTAssertFalse(result.belowReferenceGain, "still deferred inside the window")
    }

    func testNoWeighingsNoBlockers() {
        XCTAssertEqual(blockers(birth: birth(daysAgo: 30), birthWeightKg: 3.5, []), .none)
    }
}

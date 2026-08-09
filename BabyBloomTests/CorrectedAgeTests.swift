import XCTest
@testable import BabyBloom

/// Corrected age is the input every WHO growth reference expects, so getting it
/// wrong quietly poisons every percentile and velocity band downstream.
final class CorrectedAgeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Pin the language so `correctedAgeDescription` is deterministic.
        LocalizationManager.shared.setLanguage("ru")
    }

    private func baby(ageDays: Int, gestationalWeeks: Int?) -> Baby {
        let birthDate = Calendar.current.date(byAdding: .day, value: -ageDays, to: Date())!
        let baby = Baby(name: "Test", birthDate: birthDate, gender: .male, feedingType: .breast)
        baby.gestationalWeeks = gestationalWeeks
        return baby
    }

    // MARK: - No correction for term babies

    func testTermBabyIsNotCorrected() {
        let b = baby(ageDays: 100, gestationalWeeks: 40)
        XCTAssertFalse(b.isPreterm)
        XCTAssertEqual(b.correctedAgeDays, b.ageInDays)
        XCTAssertEqual(b.correctedAgeDays, 100)
    }

    func testUnstatedGestationIsTreatedAsTerm() {
        let b = baby(ageDays: 100, gestationalWeeks: nil)
        XCTAssertFalse(b.isPreterm)
        XCTAssertEqual(b.correctedAgeDays, 100)
    }

    /// 37 completed weeks is term, 36 is not — the boundary is worth pinning
    /// because it decides whether a whole screen shows a second age.
    func testPretermBoundary() {
        XCTAssertFalse(baby(ageDays: 30, gestationalWeeks: 37).isPreterm)
        XCTAssertTrue(baby(ageDays: 30, gestationalWeeks: 36).isPreterm)
    }

    // MARK: - Correction for preterm babies

    func testPretermBabyIsCorrectedByWeeksShortOfTerm() {
        // Born 8 weeks early (32 weeks): at 100 days of life the corrected age is 100 - 56.
        let b = baby(ageDays: 100, gestationalWeeks: 32)
        XCTAssertTrue(b.isPreterm)
        XCTAssertEqual(b.ageInDays, 100)
        XCTAssertEqual(b.correctedAgeDays, 44)
    }

    /// A very preterm baby in its first weeks has not yet reached term. Corrected
    /// age floors at 0 rather than going negative and producing a table lookup
    /// nobody has a reference for.
    func testCorrectedAgeNeverGoesNegative() {
        let b = baby(ageDays: 5, gestationalWeeks: 32)
        XCTAssertEqual(b.correctedAgeDays, 0)
    }

    func testCorrectionStopsAtTwoYears() {
        let b = baby(ageDays: 800, gestationalWeeks: 32)
        XCTAssertTrue(b.isPreterm)
        XCTAssertEqual(b.correctedAgeDays, b.ageInDays, "past two years prematurity is no longer corrected for")
    }

    /// Corrupt or absurd stored data must not translate into a wild correction.
    func testAbsurdGestationalAgeIsClamped() {
        let b = baby(ageDays: 200, gestationalWeeks: 4)
        // Clamped to 22 weeks → 18 weeks short of term → 126 days.
        XCTAssertEqual(b.correctedAgeDays, 200 - 126)
    }

    // MARK: - Display

    func testCorrectedDescriptionOnlyExistsForPretermBabies() {
        XCTAssertNil(baby(ageDays: 100, gestationalWeeks: 40).correctedAgeDescription)
        XCTAssertNil(baby(ageDays: 100, gestationalWeeks: nil).correctedAgeDescription)
        XCTAssertNotNil(baby(ageDays: 100, gestationalWeeks: 32).correctedAgeDescription)
    }

    /// The corrected description must describe the corrected age, not the
    /// chronological one — including landing in a different unit when the
    /// correction pushes the baby back across the 30-day weeks/months boundary.
    func testCorrectedDescriptionDescribesCorrectedAge() {
        // 70 days old, born 8 weeks early → corrected 14 days: weeks, not months.
        let young = baby(ageDays: 70, gestationalWeeks: 32)
        XCTAssertEqual(young.correctedAgeDescription, "2 \(2.weekWord)")
        XCTAssertEqual(young.ageDescription, "2 \(2.monthWord)")

        // 100 days old, born 8 weeks early → corrected 44 days: months, like the
        // chronological description, but a different number of them.
        let older = baby(ageDays: 100, gestationalWeeks: 32)
        XCTAssertEqual(older.correctedAgeDescription, "1 \(1.monthWord)")
        XCTAssertEqual(older.ageDescription, "3 \(3.monthWord)")
    }

    // MARK: - Birth weight

    func testBirthWeightIsOptionalAndDefaultsToUnset() {
        let b = baby(ageDays: 10, gestationalWeeks: nil)
        XCTAssertNil(b.birthWeightKg, "a parent may not know it — never hard-require it")
        b.birthWeightKg = 3.4
        XCTAssertEqual(b.birthWeightKg, 3.4)
    }
}

import XCTest
@testable import BabyBloom

/// What onboarding writes into the store. Both assertions fail on the previous
/// behaviour: the first entry used to be dated `Date()`, and `birthWeightKg`
/// used to be nil unless the parent had also flipped an optional toggle on the
/// page before.
final class OnboardingBabyBuilderTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    private func build(weightKg: Double = 3.5,
                       heightCm: Double = 50,
                       headCm: Double? = nil,
                       gestationalWeeks: Int? = nil,
                       name: String = "Mia") -> (baby: Baby, firstEntry: GrowthEntry) {
        OnboardingBabyBuilder.build(
            name: name,
            birthDate: birth,
            gender: .female,
            feedingType: .breast,
            birthWeightKg: weightKg,
            birthHeightCm: heightCm,
            birthHeadCm: headCm,
            gestationalWeeks: gestationalWeeks
        )
    }

    /// The whole point of the page rename: the answers describe the birth, so
    /// the row carrying them is dated there.
    func testTheFirstEntryIsDatedAtTheBirthAndNotAtOnboarding() {
        let created = build()
        XCTAssertEqual(created.firstEntry.date, birth)
        XCTAssertNotEqual(Calendar.current.dateComponents([.day], from: created.firstEntry.date, to: Date()).day, 0,
                          "a five-day-old's first entry must not land on today")
    }

    /// Nil birth weight silently switches off `NewbornProgressCard` AND the
    /// window gate that keeps the newborn dip out of the gain verdicts, so the
    /// growth page's answer always fills it.
    func testBirthWeightIsAlwaysFilledFromTheGrowthPageAnswer() {
        XCTAssertEqual(build(weightKg: 3.2).baby.birthWeightKg, 3.2)
        XCTAssertEqual(build(weightKg: 4.1).baby.birthWeightKg, 4.1)
    }

    /// The profile field and the history row are the same number by
    /// construction — there is only one answer behind them.
    func testTheProfileBirthWeightAndTheFirstWeighingAgree() {
        let created = build(weightKg: 3.75)
        XCTAssertEqual(created.baby.birthWeightKg, created.firstEntry.weightKg)
    }

    /// Prematurity keeps its optionality; only the birth weight lost its
    /// toggle.
    func testGestationalWeeksStayOptional() {
        XCTAssertNil(build().baby.gestationalWeeks)
        XCTAssertEqual(build(gestationalWeeks: 34).baby.gestationalWeeks, 34)
        XCTAssertNil(build().firstEntry.headCircumferenceCm)
    }

    /// A parent who skipped the name field still gets a named baby, not a blank
    /// one — the behaviour `createAndFinish` had before the extraction.
    func testABlankNameFallsBackRatherThanStoringEmpty() {
        XCTAssertFalse(build(name: "   ").baby.name.isEmpty)
    }
}

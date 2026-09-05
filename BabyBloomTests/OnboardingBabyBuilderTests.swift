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
                       name: String = "Mia") -> (baby: Baby, firstEntry: GrowthEntry?) {
        OnboardingBabyBuilder.build(
            name: name,
            birthDate: birth,
            gender: .female,
            feedingType: .breast,
            measurements: .init(weightKg: weightKg, heightCm: heightCm,
                                headCircumferenceCm: headCm),
            gestationalWeeks: gestationalWeeks
        )
    }

    /// The "I don't remember" answer.
    private func buildUnknown() -> (baby: Baby, firstEntry: GrowthEntry?) {
        OnboardingBabyBuilder.build(
            name: "Mia",
            birthDate: birth,
            gender: .female,
            feedingType: .breast,
            measurements: nil,
            gestationalWeeks: nil
        )
    }

    /// The whole point of the page rename: the answers describe the birth, so
    /// the row carrying them is dated there.
    func testTheFirstEntryIsDatedAtTheBirthAndNotAtOnboarding() throws {
        let entry = try XCTUnwrap(build().firstEntry)
        XCTAssertEqual(entry.date, birth)
        XCTAssertNotEqual(Calendar.current.dateComponents([.day], from: entry.date, to: Date()).day, 0,
                          "a five-day-old's first entry must not land on today")
    }

    /// The page's answer fills the profile field — no second toggle, no
    /// silence by default.
    func testBirthWeightIsFilledFromTheGrowthPageAnswer() {
        XCTAssertEqual(build(weightKg: 3.2).baby.birthWeightKg, 3.2)
        XCTAssertEqual(build(weightKg: 4.1).baby.birthWeightKg, 4.1)
    }

    /// The profile field and the history row are the same number by
    /// construction — there is only one answer behind them.
    func testTheProfileBirthWeightAndTheFirstWeighingAgree() throws {
        let created = build(weightKg: 3.75)
        XCTAssertEqual(created.baby.birthWeightKg, try XCTUnwrap(created.firstEntry).weightKg)
    }

    // MARK: - "I don't remember"

    /// The opt-out stores NOTHING, and the second half of that is the one a
    /// mandatory slider would get wrong most expensively: no invented point on
    /// the chart for every later verdict to be measured against.
    func testTheUnknownAnswerStoresNeitherABirthWeightNorAnEntry() {
        let created = buildUnknown()
        XCTAssertNil(created.baby.birthWeightKg,
                     "a slider default is not an answer — 3.5 kg would become the 10%-loss baseline")
        XCTAssertNil(created.firstEntry,
                     "an unknown birth weight must not become a point on the chart either")
    }

    /// Nil is the state that turns the newborn instrument off — the same state
    /// as an install from before this feature, and as a profile whose birth
    /// weight was cleared. All three go through this one path.
    func testTheUnknownAnswerLeavesTheNewbornInstrumentOff() {
        let created = buildUnknown()
        XCTAssertNil(NewbornWeightLoss.analyse(birthWeightKg: created.baby.birthWeightKg,
                                               birthDate: birth,
                                               measurements: []))
        XCTAssertNil(NewbornWeightLoss.gainDeferral(birthWeightKg: created.baby.birthWeightKg,
                                                    birthDate: birth,
                                                    measurements: []))
    }

    /// The rest of the profile still comes through — the opt-out is about the
    /// measurements alone.
    func testTheUnknownAnswerStillBuildsTheProfile() {
        let created = buildUnknown()
        XCTAssertEqual(created.baby.name, "Mia")
        XCTAssertEqual(created.baby.birthDate, birth)
    }

    /// Prematurity keeps its optionality; only the birth weight lost its
    /// toggle.
    func testGestationalWeeksStayOptional() {
        XCTAssertNil(build().baby.gestationalWeeks)
        XCTAssertEqual(build(gestationalWeeks: 34).baby.gestationalWeeks, 34)
        XCTAssertNil(build().firstEntry?.headCircumferenceCm)
    }

    /// A parent who skipped the name field still gets a named baby, not a blank
    /// one — the behaviour `createAndFinish` had before the extraction.
    func testABlankNameFallsBackRatherThanStoringEmpty() {
        XCTAssertFalse(build(name: "   ").baby.name.isEmpty)
    }
}

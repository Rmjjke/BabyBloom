import XCTest
@testable import BabyBloom

/// Pins the fact-selection rules so a pool edit cannot silently strand an age
/// bracket or leak a breastfeeding fact onto a formula-fed onboarding.
final class OnboardingFactsTests: XCTestCase {

    func testEveryAgeBracketHasFactsForEveryFeedingType() {
        for age in [0, 1, 2, 4, 5, 11, 12, 35] {
            for feeding in Baby.FeedingType.allCases {
                XCTAssertFalse(OnboardingFacts.eligible(ageMonths: age, feedingType: feeding).isEmpty,
                               "no fact for age \(age), feeding \(feeding)")
            }
        }
    }

    func testFeedingTypedFactsRequireAMatch() {
        let formulaFacts = OnboardingFacts.eligible(ageMonths: 1, feedingType: .formula)
        XCTAssertFalse(formulaFacts.contains { $0.key == "onboarding.fact.breast1" })
        let breastFacts = OnboardingFacts.eligible(ageMonths: 1, feedingType: .breast)
        XCTAssertFalse(breastFacts.contains { $0.key == "onboarding.fact.formula1" })
        // Mixed feeding lives both rhythms, so it gets both facts.
        let mixed = OnboardingFacts.eligible(ageMonths: 1, feedingType: .mixed)
        XCTAssertTrue(mixed.contains { $0.key == "onboarding.fact.breast1" })
        XCTAssertTrue(mixed.contains { $0.key == "onboarding.fact.formula1" })
    }

    func testPickIsDeterministicUnderASeedAndVariesAcrossSeeds() {
        let a = OnboardingFacts.pick(ageMonths: 0, feedingType: .breast, seed: 7)
        let b = OnboardingFacts.pick(ageMonths: 0, feedingType: .breast, seed: 7)
        XCTAssertEqual(a, b)
        let picks = Set((0..<10).map { OnboardingFacts.pick(ageMonths: 0, feedingType: .breast, seed: $0).key })
        XCTAssertGreaterThan(picks.count, 1, "ten seeds never varied the fact")
    }

    func testEveryPoolKeyResolvesInEveryLanguage() {
        // A key missing from a JSON renders as the raw key — the exact defect
        // class the widget shipped once. Same guard, this screen.
        let original = LocalizationManager.shared.language
        defer { LocalizationManager.shared.setLanguage(original) }
        for lang in SupportedLanguage.allCases {
            LocalizationManager.shared.setLanguage(lang)
            for fact in OnboardingFacts.pool {
                XCTAssertNotEqual(fact.key.l, fact.key, "\(fact.key) unresolved in \(lang)")
            }
        }
    }

    func testBodySubstitutesTheNameAndFallsBackWhenEmpty() {
        let named = OnboardingFacts.body(for: OnboardingFacts.pool[0], name: "Vlad")
        XCTAssertTrue(named.contains("Vlad"))
        let anonymous = OnboardingFacts.body(for: OnboardingFacts.pool[0], name: "  ")
        XCTAssertFalse(anonymous.contains("%@"))
    }
}

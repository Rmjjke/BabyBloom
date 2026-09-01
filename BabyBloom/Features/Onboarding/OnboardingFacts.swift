import Foundation

/// The "did you know" pool for onboarding page 6.
///
/// Selection is pure and seeded so it is testable and so repeat onboardings
/// vary; the FACT is chosen from what we already know by page 6 — the baby's
/// age and feeding type — which is what makes the screen read as written for
/// this child rather than for everyone.
enum OnboardingFacts {

    struct Fact: Equatable {
        /// Localization key of the body; `%@` is the baby's name where present.
        let key: String
        /// The number the view animates counting up.
        let number: Int
        /// Age gate in months, inclusive lower / exclusive upper.
        let ageRange: Range<Int>
        /// nil = any feeding type.
        let feeding: Baby.FeedingType?
    }

    /// Order is stable on purpose: the seed indexes into the eligible subset,
    /// so a new fact appended at the end never reshuffles existing picks.
    static let pool: [Fact] = [
        Fact(key: "onboarding.fact.newborn1", number: 12, ageRange: 0..<2,   feeding: nil),
        Fact(key: "onboarding.fact.newborn2", number: 18, ageRange: 0..<2,   feeding: nil),
        Fact(key: "onboarding.fact.infant1",  number: 6,  ageRange: 2..<5,   feeding: nil),
        Fact(key: "onboarding.fact.infant2",  number: 8,  ageRange: 2..<5,   feeding: nil),
        Fact(key: "onboarding.fact.older1",   number: 6,  ageRange: 5..<36,  feeding: nil),
        Fact(key: "onboarding.fact.older2",   number: 5,  ageRange: 5..<36,  feeding: nil),
        Fact(key: "onboarding.fact.breast1",  number: 3,  ageRange: 0..<12,  feeding: .breast),
        Fact(key: "onboarding.fact.formula1", number: 4,  ageRange: 0..<12,  feeding: .formula),
    ]

    /// Age-eligible facts for this baby; feeding-typed facts require a match
    /// (mixed feeding matches both, since both rhythms apply to that parent).
    static func eligible(ageMonths: Int, feedingType: Baby.FeedingType) -> [Fact] {
        pool.filter { fact in
            guard fact.ageRange.contains(max(0, ageMonths)) else { return false }
            guard let needed = fact.feeding else { return true }
            return feedingType == needed || feedingType == .mixed
        }
    }

    /// The fact for this launch. Deterministic under a seed; the caller passes
    /// something launch-varying (we use seconds-of-day) for variety.
    static func pick(ageMonths: Int, feedingType: Baby.FeedingType, seed: Int) -> Fact {
        let candidates = eligible(ageMonths: ageMonths, feedingType: feedingType)
        // The 0..<2 bracket always has entries; a defensive fallback keeps a
        // future pool edit from ever leaving the page blank.
        guard !candidates.isEmpty else { return pool[0] }
        return candidates[abs(seed) % candidates.count]
    }

    /// Body text with the name substituted. Keys without `%@` ignore the
    /// argument — `String(format:)` handles both shapes.
    static func body(for fact: Fact, name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return String(format: fact.key.l, trimmed.isEmpty ? "baby.default_name".l : trimmed)
    }
}

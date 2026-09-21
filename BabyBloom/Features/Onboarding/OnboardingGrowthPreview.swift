import Foundation

/// What the growth showcase page may honestly say, derived from the answers
/// onboarding has collected by the time it runs.
///
/// Pure, and outside the page for the reason `OnboardingBabyBuilder` is outside
/// `OnboardingView`: this decides whether a parent is shown a clinical figure
/// about their newborn or an invitation to weigh, and a rule reachable only by
/// walking eleven pages in a simulator is a rule nobody checks.
///
/// It answers the question at ONE moment — the birth — because that is the only
/// moment onboarding has a real measurement for. Everything else the page draws
/// is labelled as illustration.
enum OnboardingGrowthPreview {

    enum State: Equatable {
        /// The birth weight, scored against the WHO tables at the age the baby
        /// was on its birth day (day 0 for a term baby).
        case reading(WHOGrowthStandard.PercentileReading, birthWeightKg: Double)
        /// Nothing honest to say yet, from either of two causes that the page
        /// answers identically: «не помню точно», and a baby whose birth
        /// predates its corrected due date.
        case invitation
    }

    /// - Parameters:
    ///   - birthWeightKg: nil is a real ANSWER — the «не помню точно» opt-out —
    ///     not a missing value, exactly as `OnboardingBabyBuilder` treats it.
    ///   - gestationalWeeks: nil unless the parent said the baby was born early.
    static func state(birthWeightKg: Double?,
                      birthDate: Date,
                      gestationalWeeks: Int?,
                      isMale: Bool,
                      now: Date = Date()) -> State {
        guard let birthWeightKg else { return .invitation }
        let corrected = Baby.correctedBirthDate(birthDate: birthDate,
                                                gestationalWeeks: gestationalWeeks,
                                                now: now)
        let measurement = WeightMeasurement(date: birthDate, weightKg: birthWeightKg)
        // nil here is the preterm case `correctedAgeDaysIfBorn` exists for: WHO
        // weight-for-age starts at term, so a birth weight recorded ten weeks
        // before the due date has no percentile — scoring it against the term
        // newborn curve would put "0.4th" in front of a parent whose baby is in
        // intensive care. The Growth screen refuses the same figure; here the
        // refusal reads as the invitation rather than as a card of its own.
        guard let reading = WHOGrowthStandard.percentileReading(
            of: measurement,
            correctedBirthDate: corrected,
            isMale: isMale
        ) else { return .invitation }
        return .reading(reading, birthWeightKg: birthWeightKg)
    }
}

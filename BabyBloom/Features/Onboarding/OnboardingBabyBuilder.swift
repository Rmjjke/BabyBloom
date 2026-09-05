import Foundation

/// Turns onboarding's answers into the profile and the one history row the app
/// starts life with.
///
/// A builder rather than code inside `createAndFinish` for the reason
/// `NotificationManager` keeps its primitive-taking `onGrowthDataChanged`: the
/// two rules below decide what every growth surface reads for the first three
/// weeks of a baby's life, and a rule that can only be exercised by walking ten
/// onboarding pages in a simulator is a rule nobody checks. Insertion and
/// saving stay with the view — this touches no model context.
enum OnboardingBabyBuilder {

    /// - Parameters:
    ///   - birthWeightKg: the growth page's weight answer. The page asks for the
    ///     measurements AT BIRTH, so this one number is both the profile's
    ///     birth weight and the first weighing.
    ///   - gestationalWeeks: nil unless the parent said the baby was born early.
    ///     Still optional, unlike the birth weight: prematurity is a fact some
    ///     parents genuinely do not have, and nil means "unknown" downstream.
    static func build(
        name: String,
        birthDate: Date,
        gender: Baby.Gender,
        feedingType: Baby.FeedingType,
        birthWeightKg: Double,
        birthHeightCm: Double,
        birthHeadCm: Double?,
        gestationalWeeks: Int?
    ) -> (baby: Baby, firstEntry: GrowthEntry) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let baby = Baby(
            name: trimmed.isEmpty ? "baby.default_name".l : trimmed,
            birthDate: birthDate,
            gender: gender,
            feedingType: feedingType
        )
        // ALWAYS filled, never nil. It used to come from an optional toggle on
        // the birth page — a second way to say the same thing, which most
        // parents left off, and a nil birth weight silently switches off both
        // `NewbornProgressCard` and the window gate that keeps the newborn dip
        // from reading as a below-reference gain. One question, one answer.
        //
        // One way, and only at onboarding: `BabyProfileEditSheet` writes this
        // same field later WITHOUT touching history, because a correction to
        // the profile is not a new weighing and must not rewrite what was
        // recorded.
        baby.birthWeightKg = birthWeightKg
        baby.gestationalWeeks = gestationalWeeks

        // Dated at the BIRTH, not at the moment onboarding finished. These are
        // the numbers off the discharge record: dating them today would stamp a
        // birth weight onto day 5 and turn the physiological dip into a week of
        // apparent no gain, measured from a point the baby had already left. It
        // also gives every baby a real first point on the chart.
        let entry = GrowthEntry(
            date: birthDate,
            weightKg: birthWeightKg,
            heightCm: birthHeightCm,
            headCircumferenceCm: birthHeadCm
        )
        entry.baby = baby
        return (baby, entry)
    }
}

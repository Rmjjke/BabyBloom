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

    /// What the measurements page collected, or nil when the parent answered
    /// "I don't remember".
    ///
    /// A struct rather than three optionals because they stand or fall
    /// together: the page's weight is both the profile's birth weight and the
    /// first weighing, so there is no state where one is known and the other
    /// is not.
    struct BirthMeasurements {
        let weightKg: Double
        let heightCm: Double
        let headCircumferenceCm: Double?
    }

    /// - Parameters:
    ///   - measurements: nil is a real answer, not a missing one — see the
    ///     `birthWeightKg` assignment below.
    ///   - gestationalWeeks: nil unless the parent said the baby was born early.
    ///     Prematurity is a fact some parents genuinely do not have, and nil
    ///     means "unknown" downstream.
    static func build(
        name: String,
        birthDate: Date,
        gender: Baby.Gender,
        feedingType: Baby.FeedingType,
        measurements: BirthMeasurements?,
        gestationalWeeks: Int?
    ) -> (baby: Baby, firstEntry: GrowthEntry?) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let baby = Baby(
            name: trimmed.isEmpty ? "baby.default_name".l : trimmed,
            birthDate: birthDate,
            gender: gender,
            feedingType: feedingType
        )
        // Filled whenever the parent knows it — which is now the common case,
        // because the page asks for the birth weight outright instead of hiding
        // it behind an optional toggle on the page before, where most parents
        // walked past it.
        //
        // Nil is still a legitimate ANSWER, and it has to stay one: a slider
        // cannot express "I don't know", so without the opt-out every parent
        // who cannot find the discharge record would store an invented 3.5 kg
        // as the baseline the 10%-loss flag is measured against. Nil turns the
        // newborn instrument off — no first-weeks card, no gain deferral — and
        // that is the correct behaviour, identical to an install from before
        // this feature and to a parent who later clears the field in their
        // profile.
        //
        // One way, and only at onboarding: `BabyProfileEditSheet` writes this
        // same field later WITHOUT touching history, because a correction to
        // the profile is not a new weighing and must not rewrite what was
        // recorded.
        baby.birthWeightKg = measurements?.weightKg
        baby.gestationalWeeks = gestationalWeeks

        // No measurements, no entry: an unknown birth weight must not become a
        // point on the chart either. A fabricated first point is worse there
        // than on the profile, because every verdict measured over a pair that
        // reaches back to it inherits the fiction.
        guard let measurements else { return (baby, nil) }

        // Dated at the BIRTH, not at the moment onboarding finished. These are
        // the numbers off the discharge record: dating them today would stamp a
        // birth weight onto day 5 and turn the physiological dip into a week of
        // apparent no gain, measured from a point the baby had already left. It
        // also gives every baby a real first point on the chart.
        let entry = GrowthEntry(
            date: birthDate,
            weightKg: measurements.weightKg,
            heightCm: measurements.heightCm,
            headCircumferenceCm: measurements.headCircumferenceCm
        )
        entry.baby = baby
        return (baby, entry)
    }
}

import Foundation

/// What a correction to the birth date is allowed to do, and what has to move
/// with it.
///
/// The birth date is not just a display field: `OnboardingBabyBuilder` dates the
/// first growth entry AT the birth, and every newborn reading is computed
/// relative to that date — `NewbornWeightLoss` drops anything dated before it,
/// `Baby.correctedBirthDate` shifts the whole reference forward for a preterm
/// baby. So editing it in the profile is a history-affecting change, and the two
/// rules below are what keep the history and the date describing the same baby.
///
/// Pure on purpose, like the rest of `Core/Growth`: the caller owns the model
/// context, this owns the rule.
enum BirthDateChange {

    /// The entries that ARE birth measurements, and must therefore follow the
    /// birth date wherever it moves.
    ///
    /// Membership is by calendar DAY, not by instant. A measurement recorded on
    /// the birth day is a birth measurement whatever its time — onboarding's
    /// entry matches the birth instant exactly, but a parent who added the
    /// discharge numbers by hand picked the day and got the sheet's clock.
    ///
    /// Leaving these behind is exactly the orphaning this exists to prevent:
    /// move the birth date forward and the birth weighing lands *before* the
    /// birth, where `NewbornWeightLoss.analyse` filters it out as bad data and
    /// the chart's first real point silently stops counting.
    static func entriesToRedate(entries: [GrowthEntry],
                                oldBirthDate: Date,
                                calendar: Calendar = .current) -> [GrowthEntry] {
        entries.filter { calendar.isDate($0.date, inSameDayAs: oldBirthDate) }
    }

    /// The latest date the birth-date picker may offer.
    ///
    /// Today, or the baby's earliest NON-birth-day measurement if that is
    /// earlier: a real weighing on day 3 fixes the birth at day 3 or before,
    /// because a birth date past it would date that weighing before the birth —
    /// the same bad-data state `entriesToRedate` protects the birth measurement
    /// from, and one no re-dating can repair, since a day-3 weighing is not a
    /// birth measurement and must not be moved.
    ///
    /// Floored at the CURRENT birth date so the bound can never exclude the
    /// value the picker already holds. A store that already contains a weighing
    /// dated before the birth (rows from before `AddGrowthSheet` was bounded, or
    /// from this very defect) would otherwise hand SwiftUI a selection outside
    /// its own range; the floor turns that into "you may not move it forward",
    /// which is the right answer anyway. Same defensive shape as
    /// `AddGrowthSheet`'s `min(birthDate, now)` lower bound — see DECISIONS,
    /// 2026-09-05.
    static func latestSelectableBirthDate(entries: [GrowthEntry],
                                          oldBirthDate: Date,
                                          now: Date = Date(),
                                          calendar: Calendar = .current) -> Date {
        let earliestOther = entries
            .filter { !calendar.isDate($0.date, inSameDayAs: oldBirthDate) }
            .map(\.date)
            .min()
        return max(oldBirthDate, min(now, earliestOther ?? now))
    }
}

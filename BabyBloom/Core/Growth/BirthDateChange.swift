import Foundation

/// What a correction to the birth date is allowed to do, and what has to move
/// with it.
///
/// The birth date is not just a display field: `OnboardingBabyBuilder` dates the
/// first growth entry AT the birth, and every newborn reading is computed
/// relative to that date — `NewbornWeightLoss` drops anything dated before it,
/// `Baby.correctedBirthDate` shifts the whole reference forward for a preterm
/// baby. So editing it in the profile is a history-affecting change, and the
/// rules below are what keep the history and the date describing the same baby.
///
/// **Membership is by calendar DAY, and the day is this device's.**
/// `Calendar.isDate(_:inSameDayAs:)` reads the current time zone, so a parent
/// who records a birth-day measurement in Vladivostok and later edits the
/// profile in Lisbon can find that entry now falls on the day before the birth.
/// It then stops being a birth measurement here: it is not re-dated, and it
/// FLOORS the picker instead. Accepted rather than fixed — storing a day key
/// alongside the date is a schema change and a second source of truth, and this
/// failure mode is the conservative one: the sheet refuses to move the date
/// rather than moving data the parent did not mean to move.
///
/// Pure on purpose, like the rest of `Core/Growth`: the caller owns the model
/// context, this owns the rule.
enum BirthDateChange {

    /// The entries that ARE birth measurements, and must therefore follow the
    /// birth date wherever it moves.
    ///
    /// By calendar day, not by instant: onboarding's entry matches the birth
    /// instant exactly, but a parent who typed the discharge numbers in by hand
    /// picked the day and got the sheet's clock.
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

    /// The latest date the birth-date picker may offer: today, or the last
    /// instant of the day BEFORE the baby's earliest non-birth-day measurement.
    ///
    /// **Why the whole day is excluded and not just the measurement's instant.**
    /// A birth date landing on that day would reclassify a real weighing as a
    /// birth measurement — that is what `entriesToRedate` means by birth-day —
    /// so the NEXT edit of the birth date would silently drag a weighing the
    /// parent never touched. Refusing the day closes that class instead of
    /// leaving it one edit away. It costs the "born the same day as the first
    /// weighing" case, which a parent can still reach by re-dating or deleting
    /// that weighing explicitly — an edit they can see, on the row they mean.
    ///
    /// A birth date later than a real weighing would date that weighing before
    /// the birth in any case, and re-dating cannot repair it: a day-3 weighing
    /// is not a birth measurement and must not be moved.
    ///
    /// Floored at the CURRENT birth date so the bound can never exclude the
    /// value the picker already holds. A store already holding a weighing dated
    /// BEFORE the birth — a legacy row from before `AddGrowthSheet` was bounded,
    /// or an entry pushed off the birth day by the time-zone shift above — would
    /// otherwise hand SwiftUI a selection outside its own range; the floor
    /// turns that into "you may not move it forward",
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
        guard let earliestOther else { return max(oldBirthDate, now) }
        // One second before that day starts: the last instant a birth date may
        // occupy without swallowing the measurement's day.
        let dayBeforeEnds = calendar.startOfDay(for: earliestOther).addingTimeInterval(-1)
        return max(oldBirthDate, min(now, dayBeforeEnds))
    }

    /// The birth date to actually store for a picked `selected`.
    ///
    /// The picker's range is enforced in DAYS while the value it hands back is
    /// an INSTANT: choosing the bound's own day keeps the old time of day, which
    /// can sit later than the bound itself — today at 23:00 when `now` is noon.
    /// Clamping here, rather than trusting the control, is the second guard on
    /// the same rule, in the shape this project already uses for a future-dated
    /// weighing (picker AND read — see DECISIONS, 2026-09-05).
    static func commit(selected: Date,
                       oldBirthDate: Date,
                       entries: [GrowthEntry],
                       now: Date = Date(),
                       calendar: Calendar = .current) -> Date {
        min(selected, latestSelectableBirthDate(entries: entries,
                                                oldBirthDate: oldBirthDate,
                                                now: now,
                                                calendar: calendar))
    }
}

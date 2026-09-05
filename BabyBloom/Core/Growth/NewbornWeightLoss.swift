import Foundation

/// The first two weeks, measured against birth weight rather than against a
/// growth curve.
///
/// A newborn physiologically loses 5–10% of its birth weight over the first
/// 3–5 days and is expected back to it by day 10–14. A weight-for-age percentile
/// is the wrong instrument here and an actively alarming one: the dip reads as a
/// collapsing chart at exactly the moment parents are most frightened.
///
/// Deliberately **not** corrected for prematurity. The physiological drop follows
/// delivery, so it is counted from the actual birth — this is the one place in
/// `Core/Growth` where chronological age is the correct input. Please do not
/// "fix" it to use `Baby.correctedAgeDays`.
enum NewbornWeightLoss {

    /// How long this view of the data stays relevant. After three weeks a baby
    /// that is on track has long since regained, and one that has not is under a
    /// doctor's eye rather than an app's.
    static let observationWindowDays = 21

    /// Birth weight is expected back by day 14 at the latest.
    static let regainDeadlineDay = 14

    /// Loss beyond this share of birth weight is a recognised reason to be seen.
    static let concerningLossPercent = 10.0

    /// Something worth telling a parent about. Both are widely recognised
    /// triggers for a review — not diagnoses, and deliberately only two: extra
    /// homegrown thresholds would manufacture anxiety without adding safety.
    enum Flag: Equatable {
        /// The latest weighing is more than 10% below birth weight.
        case lossExceeds10Percent
        /// Day 14 has passed and no weighing has reached birth weight yet.
        case notRegainedByDay14
    }

    struct Status: Equatable {
        let dayOfLife: Int
        let birthWeightKg: Double
        /// Most recent weighing, or nil if the parent has not weighed yet.
        let latest: WeightMeasurement?
        /// Latest weight as a share of birth weight, e.g. 93.5 for a 6.5% loss.
        let percentOfBirthWeight: Double?
        /// Lowest weighing so far — the bottom of the dip.
        let nadir: WeightMeasurement?
        /// When birth weight was first reached again, if it has been.
        let regainedOn: Date?
        let flags: [Flag]

        var hasRegained: Bool { regainedOn != nil }
    }

    /// Whether this module — rather than a growth reference — is the instrument
    /// in force right now: a birth weight to measure against, and a baby still
    /// inside the observation window.
    ///
    /// **The single gate for the physiological dip, and the only copy of that
    /// rule.** While it is true, every surface that would otherwise print a
    /// weight-GAIN verdict defers to the first-weeks card instead: a baby that
    /// is 6% down on day 4 is doing exactly what a newborn does, and a gain
    /// measured across that dip lands below any velocity reference. Four
    /// surfaces consult this — `FeedingAdequacy.assess`, `WeightGainCard` via
    /// `GrowthView`, the Dashboard's free line through the assessment, and
    /// `NotificationManager`'s `growthGainLow` — and none of them re-derives
    /// it, because a second copy is how one of them starts alarming again.
    ///
    /// Asked of NOW, not of the pair being measured. After day 21 a pair that
    /// reaches back to the birth weighing is measured honestly: the dip is
    /// months of gain ago in relative terms, the average across it is a real
    /// average, and `WeightVelocity` compares it at the interval's MIDPOINT
    /// age, which is the age that average describes. Gating on "the pair starts
    /// inside the window" instead would silence the gain card for a baby whose
    /// only two weighings are birth and month one — permanently, since that
    /// pair never stops reaching back.
    static func windowActive(birthWeightKg: Double?,
                             birthDate: Date,
                             now: Date = Date()) -> Bool {
        guard let birthWeight = birthWeightKg, birthWeight > 0 else { return false }
        let dayOfLife = days(from: birthDate, to: now)
        return dayOfLife >= 0 && dayOfLife <= observationWindowDays
    }

    /// Analyses the newborn window, or returns nil when it does not apply:
    /// no birth weight recorded, or the baby is past the observation window.
    ///
    /// `flags` describe the situation as of `latest`. A stale last weighing
    /// therefore yields a stale flag — callers that surface flags should show
    /// `latest.date` alongside so a parent can see how current it is.
    static func analyse(
        birthWeightKg: Double?,
        birthDate: Date,
        measurements: [WeightMeasurement],
        now: Date = Date()
    ) -> Status? {
        // Applicability is `windowActive`'s to decide, so the card and the gate
        // can never disagree about whether these are the first weeks.
        guard windowActive(birthWeightKg: birthWeightKg, birthDate: birthDate, now: now),
              let birthWeight = birthWeightKg
        else { return nil }

        let dayOfLife = days(from: birthDate, to: now)

        // Anything dated before the birth is bad data, not a measurement.
        let relevant = measurements
            .filter { $0.date >= birthDate && $0.weightKg > 0 }
            .sorted { $0.date < $1.date }

        let latest = relevant.last
        let percent = latest.map { $0.weightKg / birthWeight * 100 }
        // Lowest weighing; ties go to the earlier one, which is where the dip
        // actually bottomed out.
        let nadir = relevant.min { a, b in
            a.weightKg != b.weightKg ? a.weightKg < b.weightKg : a.date < b.date
        }

        // Regain means reaching birth weight again *after* the birth itself, so a
        // day-0 weighing equal to birth weight is not a regain.
        let regainedOn = relevant.first {
            $0.weightKg >= birthWeight && days(from: birthDate, to: $0.date) >= 1
        }?.date

        var flags: [Flag] = []
        if let percent, percent < 100 - concerningLossPercent {
            flags.append(.lossExceeds10Percent)
        }
        if dayOfLife >= regainDeadlineDay, regainedOn == nil, !relevant.isEmpty {
            flags.append(.notRegainedByDay14)
        }

        return Status(
            dayOfLife: dayOfLife,
            birthWeightKg: birthWeight,
            latest: latest,
            percentOfBirthWeight: percent,
            nadir: nadir,
            regainedOn: regainedOn,
            flags: flags
        )
    }

    private static func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}

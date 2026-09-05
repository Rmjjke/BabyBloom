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
    /// This is what decides whether `NewbornProgressCard` is on screen. It is
    /// half of the gain gate; `gainDeferral` below is the whole of it.
    static func windowActive(birthWeightKg: Double?,
                             birthDate: Date,
                             now: Date = Date()) -> Bool {
        guard let birthWeight = birthWeightKg, birthWeight > 0 else { return false }
        let dayOfLife = days(from: birthDate, to: now)
        return dayOfLife >= 0 && dayOfLife <= observationWindowDays
    }

    /// Why a weight-GAIN verdict is being withheld, or nil when the ordinary
    /// rules apply.
    ///
    /// **The single gate for the physiological dip, and the only copy of that
    /// rule.** A newborn loses 5–10% of its birth weight over the first days,
    /// and every WHO velocity reference starts well above zero, so a gain
    /// measured across that dip is below the reference by construction. Three
    /// call sites consult this — `FeedingAdequacy.assess` (which carries it to
    /// the nutrition row, the Dashboard's free line and the breakdown gate),
    /// `GrowthView`'s gain card, and `NotificationManager.shouldRaiseGainSignal`
    /// — and none re-derives it, because a second copy is how one of them
    /// starts alarming again.
    ///
    /// **Two conditions, and the second one is the day-22 cliff.** Asking only
    /// "is the baby inside the window NOW" left the verdict switching on the
    /// morning after `NewbornProgressCard` vanished, computed over exactly the
    /// weighings the card had been holding: a baby weighed at birth and on day
    /// 10 and not since is silent on day 21 and reads "below the reference" on
    /// day 22, off data that has not changed. So the pair's LATER endpoint is
    /// checked too — if the newest weighing in the measured pair still lies
    /// inside the window, the reading is a reading about the dip whatever the
    /// calendar says today.
    ///
    /// **Rejected: gating on the pair's EARLIER endpoint.** That reads more
    /// natural — the dip is at the start of the interval — and it is the one
    /// shape that can silence the card forever: a baby whose only two weighings
    /// are birth and month one has a pair that reaches back into the window and
    /// never stops. The later endpoint cannot do that. Any new weighing becomes
    /// the newest one and moves the endpoint out of the window, so the deferral
    /// always has an exit the parent can reach — which is why the post-window
    /// card asks for exactly that.
    ///
    /// A pair that spans the window and ENDS outside it is measured honestly:
    /// `WeightVelocity` compares it at the interval's MIDPOINT age, which is the
    /// age the average actually describes (birth 3.5 kg → 4.4 kg on day 30 is a
    /// healthy month and reads as one).
    ///
    /// With no birth weight there is no deferral at all: `NewbornProgressCard`
    /// is not on screen either, so nothing would be holding the verdict in its
    /// place — see DECISIONS, "the newborn instrument stays off".
    static func gainDeferral(birthWeightKg: Double?,
                             birthDate: Date,
                             measurements: [WeightMeasurement],
                             now: Date = Date()) -> GainDeferral? {
        guard let birthWeight = birthWeightKg, birthWeight > 0 else { return nil }
        if windowActive(birthWeightKg: birthWeight, birthDate: birthDate, now: now) {
            return .firstWeeksNow
        }
        // `WeightVelocity.pair(in:)` and not a fresh "newest weighing" lookup:
        // that function is the one place the pairing rule lives, and the pair it
        // returns is the one every gain verdict is actually measured over.
        // `consecutiveBelowReference` chains the same walk, so its newest
        // interval ends on this same weighing and the notification is covered by
        // the same check.
        guard let pair = WeightVelocity.pair(in: measurements) else { return nil }
        let dayOfLatest = days(from: birthDate, to: pair.later.date)
        guard dayOfLatest >= 0, dayOfLatest <= observationWindowDays else { return nil }
        return .measuredInFirstWeeks
    }

    /// The two shapes a deferral takes. They differ in what the parent can DO
    /// about it, which is why the gain card says something different for each.
    enum GainDeferral: Equatable {
        /// The baby is inside the window: the first-weeks card is on screen and
        /// holds the verdict. Nothing to ask for — that card asks for its own
        /// weighings.
        case firstWeeksNow
        /// The window has closed, but the newest weighing is still inside it.
        /// The first-weeks card is gone, so this state has to say so itself AND
        /// ask for the weighing that ends it.
        case measuredInFirstWeeks
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

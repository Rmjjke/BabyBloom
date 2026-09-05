import Foundation

/// How fast the baby is gaining, against the WHO weight-velocity standards.
///
/// This is the question a parent actually asks. A weight-for-age percentile
/// answers "how big is my baby"; it can sit calmly at the 50th while the baby
/// gains nothing for a fortnight. Velocity answers "is enough going on".
///
/// Source: World Health Organization, "WHO Child Growth Standards: weight
/// velocity", 1-month increment tables (percentiles, grams):
/// https://www.who.int/tools/child-growth-standards/standards/weight-velocity
///
/// WHO publishes increments over whole months. Parents weigh whenever they like,
/// so the published grams are divided by each interval's length and compared as
/// grams per day. Over the one-to-three-week gaps parents actually use, treating
/// growth as locally linear is a fair approximation; over a single day it is not,
/// which is what `minimumIntervalDays` guards.
///
/// The band edges are the 15th and 85th increment percentiles, matching the
/// 15–85 "normal range" the app already explains for weight-for-age. Ages take
/// the **corrected** age for a baby born preterm.
enum WeightVelocity {

    /// Below this, day-to-day noise — a full nappy, the time of the last feed —
    /// swamps the trend, and the answer would be invented rather than measured.
    static let minimumIntervalDays = 3

    /// Oldest age the velocity tables cover (12 months).
    static let maxAgeDays = 365

    /// Where the measured gain sits against the reference. Deliberately neutral
    /// names: the words a parent reads live in the localization files, and none
    /// of them is a diagnosis.
    enum Band: Equatable {
        case below
        case within
        case above
    }

    struct Reading: Equatable {
        let gramsPerDay: Double
        /// Whole calendar days between the two weighings this reading was
        /// measured over — which is `pair(in:)`'s pair, not necessarily the
        /// last two on file. A LABEL, and the gate for `minimumIntervalDays`:
        /// a widened pair describes itself honestly, and every surface printing
        /// a day count reads this one. Nothing divides by it: `gramsPerDay`
        /// uses the real elapsed duration, so a part-day gap cannot inflate the
        /// rate. Counted the same way `FeedingAdequacy.Assessment.windowDays`
        /// is, and that identity is the point — the two numbers are printed
        /// within a screen of each other.
        let intervalDays: Int
        /// Reference band for this age, in grams per week, or nil past 12 months.
        let expectedPerWeek: ClosedRange<Double>?
        /// nil when there is no reference to compare against.
        let band: Band?

        var gramsPerWeek: Double { gramsPerDay * 7 }
    }

    private struct Interval {
        let startDay: Double
        let endDay: Double
        let p15PerDay: Double
        let p85PerDay: Double
    }

    // MARK: - API

    /// Gain between two weighings, or nil if they are too close together, out of
    /// order, or not both positive.
    ///
    /// `correctedBirthDate` is `Baby.correctedBirthDate` — the reference the age
    /// lookup is measured from, which for a term baby is simply the birth date.
    static func measure(
        from earlier: WeightMeasurement,
        to later: WeightMeasurement,
        correctedBirthDate: Date,
        isMale: Bool
    ) -> Reading? {
        guard isMeasurable(from: earlier, to: later) else { return nil }
        let intervalDays = days(from: earlier.date, to: later.date)

        // Divided by the REAL elapsed time, not by `intervalDays`. Whole-day
        // truncation only ever rounds the denominator DOWN, so it only ever
        // overstates the gain — a 6 d 20 h gap divided by 6 inflates the rate by
        // 13.9%, and the app's date-only picker inherits the time of day, so
        // part-days are the norm rather than the exception. Overstating is the
        // one direction that matters: it can lift a genuinely below-P15 gain
        // into `.within`, which both reassures falsely and suppresses the
        // growthGainLow notification this module exists to raise.
        // `intervalDays` stays as the LABEL — see its doc comment and
        // `FeedingAdequacy.Assessment.windowDays`, which must agree with it.
        let elapsedDays = later.date.timeIntervalSince(earlier.date) / 86_400
        let gramsPerDay = (later.weightKg - earlier.weightKg) * 1000 / elapsedDays

        // Compare at the middle of the interval: that is the age the average
        // rate actually describes.
        let midpoint = earlier.date.addingTimeInterval(later.date.timeIntervalSince(earlier.date) / 2)
        let ageAtMidpoint = max(0, days(from: correctedBirthDate, to: midpoint))

        guard let reference = expectedPerDay(correctedAgeDays: ageAtMidpoint, isMale: isMale) else {
            return Reading(gramsPerDay: gramsPerDay, intervalDays: intervalDays, expectedPerWeek: nil, band: nil)
        }

        let band: Band
        if gramsPerDay < reference.lowerBound {
            band = .below
        } else if gramsPerDay > reference.upperBound {
            band = .above
        } else {
            band = .within
        }

        return Reading(
            gramsPerDay: gramsPerDay,
            intervalDays: intervalDays,
            expectedPerWeek: (reference.lowerBound * 7)...(reference.upperBound * 7),
            band: band
        )
    }

    /// Whether these two weighings can produce a reading at all: both positive,
    /// in order, and far enough apart for the trend to outweigh the noise.
    ///
    /// Split out of `measure` so the pair SEARCH below asks the same question
    /// the measurement answers. A second copy of these guards is how the card
    /// and the window it is reported against start describing different pairs.
    private static func isMeasurable(from earlier: WeightMeasurement,
                                     to later: WeightMeasurement) -> Bool {
        guard earlier.weightKg > 0, later.weightKg > 0, later.date > earlier.date else { return false }
        return days(from: earlier.date, to: later.date) >= minimumIntervalDays
    }

    /// The newest weighing paired with the most recent earlier one it can
    /// actually be measured against, or nil when no such partner exists.
    ///
    /// **Adding a weighing must never make the app show less.** The strict
    /// last-two rule this replaced did exactly that: a parent who weighed on
    /// day 0 and day 7, saw their gain, then weighed again on day 8 out of
    /// curiosity, lost the verdict entirely — the newest pair spanned one day,
    /// below `minimumIntervalDays`, and the card fell back to "two measurements
    /// needed" while holding three. More data showed less, which reads as the
    /// app breaking.
    ///
    /// So the short noisy tail is ABSORBED into a longer interval rather than
    /// silencing the verdict: walking backwards, the first partner that clears
    /// the floor wins, and everything between it and the newest weighing is
    /// inside the interval instead of defining one. The reading's
    /// `intervalDays` then describes the widened pair, which is what the cards
    /// print — no separate bookkeeping.
    ///
    /// The newest weighing always stays in the pair. The reading claims to be
    /// the CURRENT trajectory, and a pair that stops at day 7 while day 8 is on
    /// file is a statement about the past dressed as one about now.
    static func pair(in measurements: [WeightMeasurement]) -> (earlier: WeightMeasurement,
                                                              later: WeightMeasurement)? {
        let sorted = measurements.sorted { $0.date < $1.date }
        guard sorted.count >= 2,
              let earlier = measurableEarlierIndex(in: sorted, before: sorted.count - 1)
        else { return nil }
        return (sorted[earlier], sorted[sorted.count - 1])
    }

    /// Gain over `pair(in:)`, or nil when no two weighings can be measured
    /// against each other — the honest "weigh again in a few days" case.
    static func latest(
        measurements: [WeightMeasurement],
        correctedBirthDate: Date,
        isMale: Bool
    ) -> Reading? {
        guard let pair = pair(in: measurements) else { return nil }
        return measure(
            from: pair.earlier,
            to: pair.later,
            correctedBirthDate: correctedBirthDate,
            isMale: isMale
        )
    }

    /// The nearest weighing before `index` that `index` can be measured
    /// against. Indices, not values, so a caller can keep walking from it.
    private static func measurableEarlierIndex(in sorted: [WeightMeasurement],
                                               before index: Int) -> Int? {
        var candidate = index - 1
        while candidate >= 0 {
            if isMeasurable(from: sorted[candidate], to: sorted[index]) { return candidate }
            candidate -= 1
        }
        return nil
    }

    /// Whether the last `count` consecutive intervals all came in below the
    /// reference.
    ///
    /// One slow fortnight is noise — a mistimed weighing, a cold, a growth
    /// pause. Two in a row is a pattern, and only a pattern is worth interrupting
    /// a parent's day over.
    ///
    /// The intervals are the MEASURABLE ones, chained by the same backwards walk
    /// `pair(in:)` uses: each interval ends where the next begins, and weighings
    /// too close together to measure are absorbed into the interval around them
    /// rather than ending the run. Stepping over raw consecutive pairs instead
    /// let one curious re-weigh suppress the signal — a baby weighed on days 0,
    /// 14 and 28, both intervals below the reference, stopped being a pattern
    /// the moment a day-29 weighing was added. That is the same "more data
    /// shows less" defect `pair(in:)` exists to remove, in the surface where it
    /// costs the most: a notification that never fires says nothing at all.
    ///
    /// What has NOT changed: a short pair can never BE an interval. Every
    /// interval below still clears `minimumIntervalDays` on its own, so two
    /// weighings a day apart cannot raise an alarm between them.
    static func consecutiveBelowReference(
        measurements: [WeightMeasurement],
        correctedBirthDate: Date,
        isMale: Bool,
        count: Int = 2
    ) -> Bool {
        let sorted = measurements.sorted { $0.date < $1.date }
        // A necessary condition, not a sufficient one: `count` intervals need
        // at least `count + 1` weighings, and the walk below decides the rest.
        guard sorted.count >= count + 1 else { return false }

        var checked = 0
        var index = sorted.count - 1
        while index >= 1 && checked < count {
            guard let earlier = measurableEarlierIndex(in: sorted, before: index),
                  let reading = measure(
                    from: sorted[earlier],
                    to: sorted[index],
                    correctedBirthDate: correctedBirthDate,
                    isMale: isMale
                  ) else { return false }
            // No reference (past 12 months) means nothing to be below.
            guard reading.band == .below else { return false }
            checked += 1
            index = earlier
        }
        return checked == count
    }

    /// Expected daily gain in grams for an age, or nil past the tables.
    static func expectedPerDay(correctedAgeDays: Int, isMale: Bool) -> ClosedRange<Double>? {
        guard correctedAgeDays >= 0, correctedAgeDays <= maxAgeDays else { return nil }
        let table = isMale ? boys : girls
        let day = Double(correctedAgeDays)
        // Intervals are contiguous; the last one owns its upper bound.
        let match = table.first { day >= $0.startDay && day < $0.endDay } ?? table.last
        guard let interval = match else { return nil }
        return interval.p15PerDay...interval.p85PerDay
    }

    private static func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }

    // MARK: - WHO tables (transcribed, do not hand-edit)
    // Published grams per interval, divided by the interval length in days.

    private static let boys: [Interval] = [
        Interval(startDay: 0.0000, endDay: 28.0000, p15PerDay: 24.3214, p85PerDay: 47.7143),  // 0 – 4 wks
        Interval(startDay: 28.0000, endDay: 60.8750, p15PerDay: 26.9506, p85PerDay: 46.3574),  // 4 wks – 2 mo
        Interval(startDay: 60.8750, endDay: 91.3125, p15PerDay: 18.9569, p85PerDay: 35.1869),  // 2 – 3 mo
        Interval(startDay: 91.3125, endDay: 121.7500, p15PerDay: 13.2402, p85PerDay: 27.7618),  // 3 – 4 mo
        Interval(startDay: 121.7500, endDay: 152.1875, p15PerDay: 10.2177, p85PerDay: 24.5092),  // 4 – 5 mo
        Interval(startDay: 152.1875, endDay: 182.6250, p15PerDay: 7.1294, p85PerDay: 21.0267),  // 5 – 6 mo
        Interval(startDay: 182.6250, endDay: 213.0625, p15PerDay: 5.0595, p85PerDay: 18.8255),  // 6 – 7 mo
        Interval(startDay: 213.0625, endDay: 243.5000, p15PerDay: 3.6468, p85PerDay: 17.5770),  // 7 – 8 mo
        Interval(startDay: 243.5000, endDay: 273.9375, p15PerDay: 2.5298, p85PerDay: 16.6899),  // 8 – 9 mo
        Interval(startDay: 273.9375, endDay: 304.3750, p15PerDay: 1.5770, p85PerDay: 15.9671),  // 9 – 10 mo
        Interval(startDay: 304.3750, endDay: 334.8125, p15PerDay: 0.8871, p85PerDay: 15.7043),  // 10 – 11 mo
        Interval(startDay: 334.8125, endDay: 365.2500, p15PerDay: 0.4928, p85PerDay: 15.9014),  // 11 – 12 mo
    ]

    private static let girls: [Interval] = [
        Interval(startDay: 0.0000, endDay: 28.0000, p15PerDay: 21.5000, p85PerDay: 41.8214),  // 0 – 4 wks
        Interval(startDay: 28.0000, endDay: 60.8750, p15PerDay: 22.3270, p85PerDay: 39.5741),  // 4 wks – 2 mo
        Interval(startDay: 60.8750, endDay: 91.3125, p15PerDay: 16.2300, p85PerDay: 31.2772),  // 2 – 3 mo
        Interval(startDay: 91.3125, endDay: 121.7500, p15PerDay: 12.3532, p85PerDay: 26.4148),  // 3 – 4 mo
        Interval(startDay: 121.7500, endDay: 152.1875, p15PerDay: 9.3963, p85PerDay: 23.0965),  // 4 – 5 mo
        Interval(startDay: 152.1875, endDay: 182.6250, p15PerDay: 6.6694, p85PerDay: 20.0739),  // 5 – 6 mo
        Interval(startDay: 182.6250, endDay: 213.0625, p15PerDay: 4.7967, p85PerDay: 18.2341),  // 6 – 7 mo
        Interval(startDay: 213.0625, endDay: 243.5000, p15PerDay: 3.5811, p85PerDay: 17.2813),  // 7 – 8 mo
        Interval(startDay: 243.5000, endDay: 273.9375, p15PerDay: 2.2998, p85PerDay: 16.0657),  // 8 – 9 mo
        Interval(startDay: 273.9375, endDay: 304.3750, p15PerDay: 1.3470, p85PerDay: 15.2444),  // 9 – 10 mo
        Interval(startDay: 304.3750, endDay: 334.8125, p15PerDay: 0.7885, p85PerDay: 15.0801),  // 10 – 11 mo
        Interval(startDay: 334.8125, endDay: 365.2500, p15PerDay: 0.4928, p85PerDay: 15.3429),  // 11 – 12 mo
    ]
}

import Foundation

/// Reads "is my baby getting enough food?" from the three signals a clinician
/// uses: weight gain, feeding frequency and wet nappies.
///
/// Pure by design — no SwiftData, no model context — like `WeightVelocity` and
/// `NewbornWeightLoss` beside it.
///
/// The medical spine of this module: **weight gain is the only trigger.**
/// Feeding and nappy counts are context. If gain sits within the reference
/// while feeds are few, the baby is getting enough and the app says nothing.
/// Never invent a problem out of secondary signs.
enum FeedingAdequacy {

    /// Where one signal sits against its reference.
    ///
    /// `notEnoughData` is a first-class outcome, not a failure: it is what an
    /// honest app reports when the parent has not logged enough to support a
    /// conclusion. It must never render as zero.
    enum Signal: Equatable {
        case below
        case within
        case notEnoughData
    }

    /// How the baby was actually fed over the window. Derived from the logged
    /// entries, NOT from `Baby.feedingType` — that profile answer is given once
    /// during onboarding and goes stale, and its `mixed` case maps to no
    /// reference column at all.
    enum FeedingStyle: Equatable {
        case breast
        case formula
        case mixed
    }

    /// One logged feed: the moment and the kind, and nothing else. No SwiftData
    /// object, no identity, no relationship back to the baby — the callers in
    /// later tasks map persisted rows onto this before any maths runs.
    ///
    /// `type` does reach into the model layer for `FeedingEntry.FeedingType`,
    /// which is deliberate: that enum is a plain `String`/`Codable`/
    /// `CaseIterable` with no persistence machinery of its own, and restating it
    /// here would create a second vocabulary for the same three cases plus a
    /// mapping layer to keep in step.
    struct Feed: Equatable {
        let date: Date
        let type: FeedingEntry.FeedingType

        init(date: Date, type: FeedingEntry.FeedingType) {
            self.date = date
            self.type = type
        }
    }

    /// The feature covers 0–6 months. Past it, milk stops being the only source
    /// of nutrition and feed frequency says little about intake, so the whole
    /// assessment is withheld rather than weakened.
    static let maxAgeDays = 183

    /// Feeds per 24h expected at this corrected age.
    ///
    /// Sources (verified 2026-08-25):
    ///
    /// - Breast, 0–4 weeks: American Academy of Pediatrics, *New Mother's Guide
    ///   to Breastfeeding*, 2nd ed., which puts the reference at eight to twelve
    ///   feedings in every twenty-four-hour period, and describes the usual gaps
    ///   as no more than about two to three hours by day and four at night.
    ///   https://www.healthychildren.org/English/ages-stages/baby/breastfeeding/Pages/How-Often-to-Breastfeed.aspx
    /// - Formula: AAP, *Caring for Your Baby and Young Child: Birth to Age 5*,
    ///   7th ed. — newborns "feed on a more regular schedule, such as every 3 or
    ///   4 hours" (6–8 a day); by the end of the first month "about every 3 to 4
    ///   hours"; between 2 and 4 months they "may go longer between daytime
    ///   feedings — occasionally up to 4 or 5 hours"; by 6 months "4 or 5
    ///   feedings in 24 hours".
    ///   https://www.healthychildren.org/English/ages-stages/baby/formula-feeding/Pages/amount-and-schedule-of-formula-feedings.aspx
    /// - **AAP contradicts itself on the newborn formula floor, and the
    ///   permissive end is taken.** A second AAP page states that "most newborns
    ///   eat every 2 to 3 hours; 8 times is generally recommended as the minimum
    ///   every 24 hours" — a floor of 8, not the 6 that "every 3 or 4 hours"
    ///   gives. 6 is used. Feeding frequency is context and can never reach a
    ///   conclusion by itself, so the two errors are not symmetric: too strict
    ///   spends a false "below the reference" on a thriving baby, while too
    ///   permissive costs one supporting line inside a breakdown that the weight
    ///   signal had already opened.
    ///   https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/how-often-and-how-much-should-your-baby-eat.aspx
    /// - Breast past the newborn month: CDC, *How Much and How Often to
    ///   Breastfeed* — "most exclusively breastfed babies will feed every 2 to 4
    ///   hours" (6–12 a day). The published sources stop giving per-month
    ///   numbers here, so the two later breast rows interpolate between the
    ///   verified newborn band and the verified 6-month one. Both lower bounds
    ///   are set at or below what any source states, which is the permissive
    ///   direction: this signal is context and must not flag a thriving baby.
    ///
    /// Returns nil past `maxAgeDays`, where no reference applies.
    static func feedingReference(correctedAgeDays: Int,
                                 style: FeedingStyle) -> ClosedRange<Double>? {
        guard correctedAgeDays <= maxAgeDays else { return nil }

        // A baby born preterm can be at a negative corrected age; the newborn
        // row is the right reference for them, and `..<28` already covers it.
        let breast: ClosedRange<Double>
        let formula: ClosedRange<Double>
        switch correctedAgeDays {
        case ..<28:      breast = 8...12; formula = 6...8
        case 28..<120:   breast = 7...9;  formula = 5...7
        default:         breast = 5...7;  formula = 4...6
        }

        switch style {
        case .breast:  return breast
        case .formula: return formula
        case .mixed:
            // Neither column fully applies to a mixed-fed baby, so take the
            // union and let the stricter edge of each table go.
            let fewest = min(breast.lowerBound, formula.lowerBound)
            let most = max(breast.upperBound, formula.upperBound)
            return fewest...most
        }
    }

    /// Wet nappies per 24h expected from a baby this many days after birth.
    ///
    /// Measured in POSTNATAL days, not corrected age: the first-week ramp is
    /// about the transition after birth, not about developmental maturity.
    ///
    /// Sources (verified 2026-08-25):
    ///
    /// - NHS, *Breastfeeding: is my baby getting enough milk?* — "In the first
    ///   48 hours, your baby is likely to have only 2 or 3 wet nappies"; "From
    ///   day 5 onwards, wet nappies should start to become more frequent, with
    ///   at least 6 heavy, wet nappies every 24 hours."
    ///   https://www.nhs.uk/baby/breastfeeding-and-bottle-feeding/breastfeeding-problems/enough-milk/
    /// - The ramp over days 1–4 follows the UNICEF UK Baby Friendly nappy chart
    ///   as published by Cambridge University Hospitals NHS FT, which gives days
    ///   1–2 as "1–2 or more per day" and days 3–4 as "3 or more per day". Note
    ///   the chart flattens at 3 rather than continuing to track the day number:
    ///   day 4 is 3, not 4.
    ///   https://www.cuh.nhs.uk/rosie-hospital/maternity/infant-feeding/signs-your-baby-is-getting-enough-milk/
    /// - AAP puts the settled figure slightly lower, giving at least 5 to 6 wet
    ///   nappies a day after the first four to five days, so 6 is the strict end
    ///   of the published range. It is used because the NHS states it outright,
    ///   and because this signal never raises a concern on its own; only weight
    ///   gain does.
    static func wetNappyMinimum(postnatalDays: Int) -> Double {
        switch postnatalDays {
        // Also the floor for a zero or negative day: the reference is never 0,
        // because "none expected" is not something this function can mean.
        case ..<2:  return 1
        case 2:     return 2
        case 3, 4:  return 3
        default:    return 6
        }
    }

    // MARK: - Window

    /// The interval the assessment covers: between the two most recent
    /// weighings. Feeds and nappies are counted over this same window, so a
    /// "few feeds" figure can never sit beside a gain measured across a
    /// different week.
    ///
    /// **A window shorter than one full day is withheld.** Two weighings within
    /// a day are realistic — daily weighing in the first week, a clinic
    /// re-weigh — and everything downstream is expressed per day, which a
    /// part-day cannot support: both `rate` and `hasEnoughCoverage` floor their
    /// denominator at one day, so a six-hour gap with six feeds would report
    /// 6 a day from a parent who actually fed about 24 times, and a single
    /// covered day would score full coverage and wave that figure through.
    /// Returning nil states there is nothing to measure yet.
    ///
    /// One day, deliberately not the three of `WeightVelocity
    /// .minimumIntervalDays`: that floor answers a different question — when
    /// weight noise stops swamping a gain — while this one is only about "per
    /// day" meaning something, and later tasks need a two-day window to still
    /// produce an assessment.
    static func window(for measurements: [WeightMeasurement]) -> DateInterval? {
        let sorted = measurements.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        let start = sorted[sorted.count - 2].date
        let end = sorted[sorted.count - 1].date
        let oneDay: TimeInterval = 86_400
        guard end.timeIntervalSince(start) >= oneDay else { return nil }
        return DateInterval(start: start, end: end)
    }

    // MARK: - Feeding style

    /// The dominant feeding style over the window, from what was logged.
    ///
    /// Pumped milk is bottle-fed on a formula-like schedule, so it counts with
    /// formula for FREQUENCY purposes — this says nothing about what is in the
    /// bottle. Below the dominance threshold the baby is genuinely mixed-fed
    /// and gets the union reference; with no feeds at all, the same, because
    /// the widest band is the honest choice when there is no evidence.
    ///
    /// Both shares are counted from the kinds they name rather than one being
    /// derived as "not the other", so a feeding kind added to
    /// `FeedingEntry.FeedingType` later belongs to neither column and pushes
    /// the baby towards `.mixed` — the widest band — instead of silently
    /// joining the formula count.
    static func style(of feeds: [Feed]) -> FeedingStyle {
        guard !feeds.isEmpty else { return .mixed }
        let dominanceThreshold = 0.8
        let total = Double(feeds.count)
        let breastShare = Double(feeds.filter { $0.type == .breast }.count) / total
        let bottleShare = Double(feeds.filter { $0.type == .formula || $0.type == .pumped }.count) / total
        if breastShare >= dominanceThreshold { return .breast }
        if bottleShare >= dominanceThreshold { return .formula }
        return .mixed
    }

    // MARK: - Counting

    /// Events per day over the window.
    ///
    /// The one-day floor is a guard of last resort: `window(for:)` already
    /// refuses anything shorter than a day, and the floor only keeps a
    /// hand-built shorter interval from multiplying a handful of entries into
    /// an implausible daily figure. Erring low is the safe direction here,
    /// since a low count is only ever context.
    ///
    /// Entries outside the window are dropped, not merely uncounted: this
    /// figure has to describe the same stretch of days as the weight gain
    /// beside it, or the two together say something neither one supports.
    ///
    /// Returns 0 for an empty log, which is why no caller may show this figure
    /// without `hasEnoughCoverage` first: an unlogged day is unknown, not zero.
    static func rate(of dates: [Date], in window: DateInterval) -> Double {
        let days = max(1.0, window.duration / 86_400)
        let inside = dates.filter { window.contains($0) }.count
        return Double(inside) / days
    }

    /// Whether the logs cover enough of the window to support a conclusion.
    ///
    /// Counts DAYS WITH AT LEAST ONE ENTRY, not entries: ten records on a single
    /// day are a busy Tuesday, not a fortnight of evidence. Below half the days,
    /// the signal reports `notEnoughData`. Days logged outside the window do not
    /// count either — a well-logged fortnight ago is no evidence about this gap.
    ///
    /// The denominator is WHOLE CALENDAR DAYS, the one day-count convention this
    /// module has — see `Assessment.windowDays`. It used to ROUND the window's
    /// real duration instead, and rounding disagrees with truncation on about
    /// half of all part-day windows, not on some exotic edge: 10 d 15 h rounds
    /// to 11 while the calendar says 10, and the numerator has always counted
    /// calendar days. Weighings are taken whenever a parent gets to the scales,
    /// so part-day windows are the normal case and the disagreement is a
    /// routine off-by-one in the gate that decides whether a figure is shown at
    /// all — 5 covered days over a 10.6-day window is 0.50 and passes, or 0.45
    /// and is withheld, depending only on which count ran.
    static func hasEnoughCoverage(_ dates: [Date], in window: DateInterval) -> Bool {
        let calendar = Calendar.current
        let days = max(1, calendar.dateComponents([.day],
                                                  from: window.start,
                                                  to: window.end).day ?? 1)
        let covered = Set(dates.filter { window.contains($0) }.map { calendar.startOfDay(for: $0) })
        return Double(covered.count) / Double(days) >= 0.5
    }

    // MARK: - Assessment

    /// One verdict, assembled from the three signals over a single shared window.
    struct Assessment: Equatable {
        /// Whole days between the two weighings the assessment covers — a
        /// 9.6-day gap is 9, not 10.
        ///
        /// Label only: nothing computes from this. The per-day rates divide by
        /// the window's real duration, so their arithmetic is unaffected by the
        /// whole-day count.
        ///
        /// **Counted the same way `WeightVelocity.intervalDays` is** —
        /// `Calendar.current.dateComponents([.day], from:to:)`, whole days on
        /// the wall clock — and that identity is the point, not an incidental
        /// detail. One pair of weighings is described by three sentences down a
        /// single Growth screen: the gain card, this section's header and the
        /// breakdown card. An earlier version divided the window's real
        /// duration by 86_400 instead, which agrees with the calendar on every
        /// ordinary window and disagrees across a daylight-saving transition,
        /// where a 9-calendar-day window lasts 8 d 23 h: the header would read
        /// "Over 8 days" directly above "over 9 days". Two counts that agree
        /// almost always are worse than one count, because the render that
        /// would catch them is the one nobody takes in March.
        ///
        /// The `max(1, …)` floor matters for the same reason `window(for:)`
        /// admits a pair only 86_400 real seconds apart: an autumn fall-back
        /// makes that span 23 wall-clock hours, i.e. zero calendar days. A pair
        /// that close is below `WeightVelocity.minimumIntervalDays`, so no card
        /// states a rival count — the floor only keeps the header from saying
        /// "Over 0 days".
        let windowDays: Int
        let gain: Signal
        /// nil when the signal is `notEnoughData` — never 0, which would read
        /// as "your baby fed zero times".
        let feedingsPerDay: Double?
        /// The age band's reference, offered whether or not feeds were logged:
        /// unlike a count, it says nothing about this baby, so there is nothing
        /// to invent. `wetNappyMinimum` beside it is withheld with its count
        /// instead, because a lone minimum is the number a reader completes.
        let feedingReference: ClosedRange<Double>?
        let feeding: Signal
        let wetNappiesPerDay: Double?
        let wetNappyMinimum: Double?
        let nappies: Signal

        /// The single gate for the breakdown card. Weight is the only trigger:
        /// see the module comment.
        var warrantsBreakdown: Bool { gain == .below }
    }

    /// nil when the feature does not apply at all: no second weighing to define
    /// a window, or a baby past six months.
    static func assess(
        birthDate: Date,
        correctedBirthDate: Date,
        isMale: Bool,
        measurements: [WeightMeasurement],
        feeds: [Feed],
        wetNappies: [Date],
        now: Date = Date()
    ) -> Assessment? {
        let calendar = Calendar.current
        let correctedAgeDays = calendar.dateComponents([.day], from: correctedBirthDate, to: now).day ?? 0
        guard correctedAgeDays <= maxAgeDays else { return nil }
        guard let window = window(for: measurements) else { return nil }

        // `WeightVelocity.latest` pairs the same two weighings `window(for:)`
        // does. Repeating that sort-and-take-last-two here would be a third copy
        // of the pairing, and the day one of them drifted the gain would be
        // measured over a different pair than the window it is reported
        // against — the one thing this module promises cannot happen.
        let reading = WeightVelocity.latest(
            measurements: measurements,
            correctedBirthDate: correctedBirthDate,
            isMale: isMale
        )
        // Gaining faster than the reference is not a concern, so `.above` joins
        // `.within`: the two Signal cases this module publishes are "below its
        // reference" and "not below it".
        let gain: Signal
        switch reading?.band {
        case .below:            gain = .below
        case .within, .above:   gain = .within
        case nil:               gain = .notEnoughData
        }

        let windowFeeds = feeds.filter { window.contains($0.date) }
        let reference = feedingReference(correctedAgeDays: correctedAgeDays,
                                         style: style(of: windowFeeds))
        let feedingsPerDay: Double?
        let feedingSignal: Signal
        // `rate` is not self-gating — it returns 0 for an empty log — so it is
        // only ever reached behind `hasEnoughCoverage`.
        if hasEnoughCoverage(windowFeeds.map(\.date), in: window), let reference {
            let perDay = rate(of: windowFeeds.map(\.date), in: window)
            feedingsPerDay = perDay
            feedingSignal = perDay < reference.lowerBound ? .below : .within
        } else {
            feedingsPerDay = nil
            feedingSignal = .notEnoughData
        }

        // POSTNATAL days, not corrected: the first-week ramp is about the
        // transition after birth.
        let postnatalDays = calendar.dateComponents([.day], from: birthDate, to: now).day ?? 0
        let minimum = wetNappyMinimum(postnatalDays: postnatalDays)
        let nappiesPerDay: Double?
        let nappySignal: Signal
        if hasEnoughCoverage(wetNappies, in: window) {
            let perDay = rate(of: wetNappies, in: window)
            nappiesPerDay = perDay
            nappySignal = perDay < minimum ? .below : .within
        } else {
            nappiesPerDay = nil
            nappySignal = .notEnoughData
        }

        return Assessment(
            windowDays: max(1, calendar.dateComponents([.day],
                                                       from: window.start,
                                                       to: window.end).day ?? 1),
            gain: gain,
            feedingsPerDay: feedingsPerDay,
            feedingReference: reference,
            feeding: feedingSignal,
            wetNappiesPerDay: nappiesPerDay,
            wetNappyMinimum: nappiesPerDay == nil ? nil : minimum,
            nappies: nappySignal
        )
    }
}

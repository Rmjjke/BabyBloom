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

    /// One logged feed, stripped of storage concerns.
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
    ///   feedings in every twenty-four-hour period, with gaps of no more than
    ///   about two to three hours by day and four at night.
    ///   https://www.healthychildren.org/English/ages-stages/baby/breastfeeding/Pages/How-Often-to-Breastfeed.aspx
    /// - Formula: AAP, *Caring for Your Baby and Young Child: Birth to Age 5*,
    ///   7th ed. — newborns "feed on a more regular schedule, such as every 3 or
    ///   4 hours" (6–8 a day); by the end of the first month "about every 3 to 4
    ///   hours"; between 2 and 4 months they "may go longer between daytime
    ///   feedings — occasionally up to 4 or 5 hours"; by 6 months "4 or 5
    ///   feedings in 24 hours".
    ///   https://www.healthychildren.org/English/ages-stages/baby/formula-feeding/Pages/amount-and-schedule-of-formula-feedings.aspx
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
    /// - The day-by-day ramp over days 1–4 follows the UNICEF UK Baby Friendly
    ///   nappy chart as published by Cambridge University Hospitals NHS FT:
    ///   days 1–2 "1–2 or more per day", days 3–4 "3 or more per day".
    ///   https://www.cuh.nhs.uk/rosie-hospital/maternity/infant-feeding/signs-your-baby-is-getting-enough-milk/
    /// - AAP puts the settled figure slightly lower — "after the first 4 to 5
    ///   days, a baby should have at least 5 to 6 wet diapers a day" — so 6 is
    ///   the strict end of the published range. It is used because the NHS
    ///   states it outright, and because this signal never raises a concern on
    ///   its own; only weight gain does.
    static func wetNappyMinimum(postnatalDays: Int) -> Double {
        guard postnatalDays >= 5 else { return Double(max(1, postnatalDays)) }
        return 6
    }
}

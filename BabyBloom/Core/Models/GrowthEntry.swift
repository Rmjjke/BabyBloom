import Foundation
import SwiftData

// MARK: - Growth Entry
@Model
final class GrowthEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double?
    var heightCm: Double?
    var headCircumferenceCm: Double?
    var notes: String?
    var createdAt: Date = Date()
    var baby: Baby?

    init(
        date: Date = Date(),
        weightKg: Double? = nil,
        heightCm: Double? = nil,
        headCircumferenceCm: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.headCircumferenceCm = headCircumferenceCm
        self.createdAt = Date()
    }

    var weightFormatted: String {
        guard let w = weightKg else { return "—" }
        if w >= 1 {
            return String(format: "%.2f %@", w, "unit.kg".l)
        } else {
            return "\(Int(w * 1000)) \("unit.g".l)"
        }
    }

    var heightFormatted: String {
        guard let h = heightCm else { return "—" }
        return String(format: "%.1f %@", h, "unit.cm".l)
    }

    var headFormatted: String {
        guard let h = headCircumferenceCm else { return "—" }
        return String(format: "%.1f %@", h, "unit.cm".l)
    }
}

// MARK: - WHO Percentile Calculator
enum WHOPercentile {
    /// Weight-for-age reference: (median P50, effective SD) in kg for one age in months.
    private struct Ref {
        let maleMedian: Double
        let maleSD: Double
        let femaleMedian: Double
        let femaleSD: Double
    }

    /// WHO Child Growth Standards 2006 — weight-for-age, boys & girls, months 0–24.
    /// Source: World Health Organization, "WHO Child Growth Standards: weight-for-age"
    /// (https://www.who.int/tools/child-growth-standards/standards/weight-for-age).
    /// Median values are the published P50. The effective SD is the WHO median × S
    /// (the LMS coefficient of variation), which is equivalent to the field-table
    /// approximation SD ≈ (P97 − P3) / 3.88. We treat the distribution as normal
    /// around the median (L ≈ 1 in this age range), which is accurate near the centre
    /// and slightly conservative in the tails — good enough for a parental-guidance band.
    private static let table: [Int: Ref] = [
        0:  Ref(maleMedian: 3.3,  maleSD: 0.48, femaleMedian: 3.2,  femaleSD: 0.47),
        1:  Ref(maleMedian: 4.5,  maleSD: 0.61, femaleMedian: 4.2,  femaleSD: 0.57),
        2:  Ref(maleMedian: 5.6,  maleSD: 0.71, femaleMedian: 5.1,  femaleSD: 0.65),
        3:  Ref(maleMedian: 6.4,  maleSD: 0.79, femaleMedian: 5.8,  femaleSD: 0.71),
        4:  Ref(maleMedian: 7.0,  maleSD: 0.84, femaleMedian: 6.4,  femaleSD: 0.77),
        5:  Ref(maleMedian: 7.5,  maleSD: 0.89, femaleMedian: 6.9,  femaleSD: 0.81),
        6:  Ref(maleMedian: 7.9,  maleSD: 0.92, femaleMedian: 7.3,  femaleSD: 0.85),
        7:  Ref(maleMedian: 8.3,  maleSD: 0.96, femaleMedian: 7.6,  femaleSD: 0.88),
        8:  Ref(maleMedian: 8.6,  maleSD: 0.99, femaleMedian: 7.9,  femaleSD: 0.91),
        9:  Ref(maleMedian: 8.9,  maleSD: 1.01, femaleMedian: 8.2,  femaleSD: 0.93),
        10: Ref(maleMedian: 9.2,  maleSD: 1.05, femaleMedian: 8.5,  femaleSD: 0.97),
        11: Ref(maleMedian: 9.4,  maleSD: 1.06, femaleMedian: 8.7,  femaleSD: 0.98),
        12: Ref(maleMedian: 9.6,  maleSD: 1.08, femaleMedian: 8.9,  femaleSD: 1.00),
        13: Ref(maleMedian: 9.9,  maleSD: 1.11, femaleMedian: 9.2,  femaleSD: 1.03),
        14: Ref(maleMedian: 10.1, maleSD: 1.13, femaleMedian: 9.4,  femaleSD: 1.05),
        15: Ref(maleMedian: 10.3, maleSD: 1.14, femaleMedian: 9.6,  femaleSD: 1.07),
        16: Ref(maleMedian: 10.5, maleSD: 1.17, femaleMedian: 9.8,  femaleSD: 1.09),
        17: Ref(maleMedian: 10.7, maleSD: 1.19, femaleMedian: 10.0, femaleSD: 1.11),
        18: Ref(maleMedian: 10.9, maleSD: 1.21, femaleMedian: 10.2, femaleSD: 1.13),
        19: Ref(maleMedian: 11.1, maleSD: 1.23, femaleMedian: 10.4, femaleSD: 1.15),
        20: Ref(maleMedian: 11.3, maleSD: 1.25, femaleMedian: 10.6, femaleSD: 1.18),
        21: Ref(maleMedian: 11.5, maleSD: 1.28, femaleMedian: 10.9, femaleSD: 1.21),
        22: Ref(maleMedian: 11.8, maleSD: 1.31, femaleMedian: 11.1, femaleSD: 1.23),
        23: Ref(maleMedian: 12.0, maleSD: 1.33, femaleMedian: 11.3, femaleSD: 1.25),
        24: Ref(maleMedian: 12.2, maleSD: 1.35, femaleMedian: 11.5, femaleSD: 1.28)
    ]

    /// Highest age (months) covered by the table. Ages beyond this are clamped to it.
    static let maxAgeMonths = 24

    /// Returns the weight percentile (1–99) for the given age, weight and sex.
    ///
    /// Ages are clamped to the 0…`maxAgeMonths` range the WHO table covers. For a baby
    /// older than `maxAgeMonths` the 24-month reference is used deliberately (an explicit
    /// clamp, not a silent lookup miss) — callers should treat 24-month results for older
    /// children as an approximation rather than an exact percentile.
    static func weightPercentile(ageMonths: Int, weightKg: Double, isMale: Bool) -> Double {
        let clampedAge = min(max(ageMonths, 0), maxAgeMonths)
        // clampedAge is always within [0, maxAgeMonths]; the table has every month.
        guard let ref = table[clampedAge] else { return 50 }
        let median = isMale ? ref.maleMedian : ref.femaleMedian
        let sd = isMale ? ref.maleSD : ref.femaleSD
        return percentile(value: weightKg, median: median, sd: sd)
    }

    /// Converts a value to a percentile via a z-score and the normal CDF (erf-based),
    /// clamped to the 1–99 range shown to users.
    static func percentile(value: Double, median: Double, sd: Double) -> Double {
        guard sd > 0 else { return 50 }
        let z = (value - median) / sd
        let p = 0.5 * (1 + erf(z / 2.0.squareRoot()))
        return max(1, min(99, (p * 100).rounded()))
    }

    /// Localized percentile band label. Bands share identical boundaries with
    /// `percentileColor`: 3 / 15 / 50 / 85 / 97 (upper-inclusive within a band).
    static func percentileLabel(_ percentile: Double) -> String {
        switch percentile {
        case ..<3:  return "percentile.below3".l
        case ...15: return "percentile.3_15".l
        case ...50: return "percentile.15_50".l
        case ...85: return "percentile.50_85".l
        case ...97: return "percentile.85_97".l
        default:    return "percentile.above97".l
        }
    }

    /// Band color. Boundaries are identical to `percentileLabel` (3 / 15 / 50 / 85 / 97):
    /// green in the healthy 15–85 range, orange at the edges, red beyond 3 / 97.
    static func percentileColor(_ percentile: Double) -> String {
        switch percentile {
        case ..<3:  return "#E05A5A"
        case ...15: return "#F5A45F"
        case ...50: return "#6BBF6B"
        case ...85: return "#6BBF6B"
        case ...97: return "#F5A45F"
        default:    return "#E05A5A"
        }
    }
}

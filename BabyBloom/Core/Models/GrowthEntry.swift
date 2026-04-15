import Foundation
import SwiftData

// MARK: - Growth Entry
@Model
final class GrowthEntry {
    var id: UUID
    var date: Date
    var weightKg: Double?
    var heightCm: Double?
    var headCircumferenceCm: Double?
    var notes: String?
    var createdAt: Date

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
            return String(format: "%.2f кг", w)
        } else {
            return "\(Int(w * 1000)) г"
        }
    }

    var heightFormatted: String {
        guard let h = heightCm else { return "—" }
        return String(format: "%.1f см", h)
    }

    var headFormatted: String {
        guard let h = headCircumferenceCm else { return "—" }
        return String(format: "%.1f см", h)
    }
}

// MARK: - WHO Percentile Calculator
enum WHOPercentile {
    /// Returns percentile band (0-100) for weight given age in months and gender
    /// Simplified approximation based on WHO Child Growth Standards
    static func weightPercentile(ageMonths: Int, weightKg: Double, isMale: Bool) -> Double {
        // WHO median weight references (simplified)
        let medians: [Int: (male: Double, female: Double)] = [
            0: (3.3, 3.2), 1: (4.5, 4.2), 2: (5.6, 5.1),
            3: (6.4, 5.8), 4: (7.0, 6.4), 5: (7.5, 6.9),
            6: (7.9, 7.3), 7: (8.3, 7.6), 8: (8.6, 7.9),
            9: (8.9, 8.2), 10: (9.2, 8.5), 11: (9.4, 8.7),
            12: (9.6, 8.9)
        ]
        guard let ref = medians[min(ageMonths, 12)] else { return 50 }
        let median = isMale ? ref.male : ref.female
        let ratio = weightKg / median
        // Very simplified conversion — for accurate percentiles use full WHO LMS tables
        let percentile = (ratio - 0.7) / 0.6 * 100
        return max(1, min(99, percentile))
    }

    static func percentileLabel(_ percentile: Double) -> String {
        switch percentile {
        case ..<3: return "< 3-й"
        case ..<15: return "3–15"
        case ..<50: return "15–50"
        case ..<85: return "50–85"
        case ..<97: return "85–97"
        default: return "> 97-го"
        }
    }

    static func percentileColor(_ percentile: Double) -> String {
        switch percentile {
        case ..<3: return "#E05A5A"
        case ..<15: return "#F5A45F"
        case ..<85: return "#6BBF6B"
        case ..<97: return "#F5A45F"
        default: return "#E05A5A"
        }
    }
}

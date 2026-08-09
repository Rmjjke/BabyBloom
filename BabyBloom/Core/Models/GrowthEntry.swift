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

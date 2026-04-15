import Foundation
import SwiftData

// MARK: - Baby Profile
@Model
final class Baby {
    var id: UUID
    var name: String
    var birthDate: Date
    var gender: Gender
    var feedingType: FeedingType
    var photoData: Data?
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade) var feedingEntries: [FeedingEntry] = []
    @Relationship(deleteRule: .cascade) var sleepEntries: [SleepEntry] = []
    @Relationship(deleteRule: .cascade) var diaperEntries: [DiaperEntry] = []
    @Relationship(deleteRule: .cascade) var growthEntries: [GrowthEntry] = []
    @Relationship(deleteRule: .cascade) var customEvents: [CustomEvent] = []

    init(name: String, birthDate: Date, gender: Gender, feedingType: FeedingType) {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.feedingType = feedingType
        self.createdAt = Date()
    }

    // MARK: Computed
    var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: birthDate, to: Date()).day ?? 0
    }

    var ageInWeeks: Int { ageInDays / 7 }

    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
    }

    var ageDescription: String {
        let months = ageInMonths
        let days = ageInDays
        if days < 7 {
            return "\(days) \(days.dayWord)"
        } else if days < 30 {
            let weeks = ageInWeeks
            return "\(weeks) \(weeks.weekWord)"
        } else {
            return "\(months) \(months.monthWord)"
        }
    }

    enum Gender: String, Codable, CaseIterable {
        case male = "male"
        case female = "female"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .male: return "baby.gender.male"
            case .female: return "baby.gender.female"
            }
        }

        var icon: String {
            switch self {
            case .male: return "person.fill"
            case .female: return "person.fill"
            }
        }
    }

    enum FeedingType: String, Codable, CaseIterable {
        case breast = "breast"
        case formula = "formula"
        case mixed = "mixed"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .breast: return "baby.feeding.breast"
            case .formula: return "baby.feeding.formula"
            case .mixed: return "baby.feeding.mixed"
            }
        }

        var icon: String {
            switch self {
            case .breast: return "heart.fill"
            case .formula: return "drop.fill"
            case .mixed: return "heart.circle.fill"
            }
        }
    }
}

// MARK: - Int word forms (language-aware)
extension Int {
    var dayWord: String   { ageWord(one: "age.day.one",   few: "age.day.few",   many: "age.day.many") }
    var weekWord: String  { ageWord(one: "age.week.one",  few: "age.week.few",  many: "age.week.many") }
    var monthWord: String { ageWord(one: "age.month.one", few: "age.month.few", many: "age.month.many") }

    private func ageWord(one: String, few: String, many: String) -> String {
        let lang = LocalizationManager.shared.currentLanguage
        if lang == "en" {
            return self == 1 ? one.l : few.l
        }
        return pluralize(one: one.l, few: few.l, many: many.l)
    }

    private func pluralize(one: String, few: String, many: String) -> String {
        let n = abs(self) % 100
        let n1 = n % 10
        if n >= 11 && n <= 19 { return many }
        if n1 == 1 { return one }
        if n1 >= 2 && n1 <= 4 { return few }
        return many
    }
}

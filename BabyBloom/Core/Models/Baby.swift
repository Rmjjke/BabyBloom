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

        var displayName: String {
            switch self {
            case .male: return "Мальчик"
            case .female: return "Девочка"
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

        var displayName: String {
            switch self {
            case .breast: return "Грудное"
            case .formula: return "Смесь"
            case .mixed: return "Смешанное"
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

// MARK: - Int word forms (Russian)
extension Int {
    var dayWord: String { pluralize(one: "день", few: "дня", many: "дней") }
    var weekWord: String { pluralize(one: "неделя", few: "недели", many: "недель") }
    var monthWord: String { pluralize(one: "месяц", few: "месяца", many: "месяцев") }

    private func pluralize(one: String, few: String, many: String) -> String {
        let n = abs(self) % 100
        let n1 = n % 10
        if n >= 11 && n <= 19 { return many }
        if n1 == 1 { return one }
        if n1 >= 2 && n1 <= 4 { return few }
        return many
    }
}

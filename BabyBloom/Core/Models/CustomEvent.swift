import Foundation
import SwiftData

// MARK: - Custom / Misc Event
@Model
final class CustomEvent {
    var id: UUID
    var time: Date
    var type: EventType
    var mood: MoodLevel?
    var medicationName: String?
    var medicationDose: String?
    var weatherNote: String?
    var durationMinutes: Int?
    var notes: String?
    var createdAt: Date

    init(time: Date = Date(), type: EventType) {
        self.id = UUID()
        self.time = time
        self.type = type
        self.createdAt = Date()
    }

    enum EventType: String, Codable, CaseIterable {
        case bath = "bath"
        case walk = "walk"
        case medication = "medication"
        case mood = "mood"
        case custom = "custom"

        var displayName: String {
            switch self {
            case .bath: return "Купание"
            case .walk: return "Прогулка"
            case .medication: return "Лекарство"
            case .mood: return "Настроение"
            case .custom: return "Событие"
            }
        }

        var icon: String {
            switch self {
            case .bath: return "drop.fill"
            case .walk: return "figure.walk"
            case .medication: return "pills.fill"
            case .mood: return "face.smiling.fill"
            case .custom: return "star.fill"
            }
        }

        var colorHex: String {
            switch self {
            case .bath: return "#B0C4F5"
            case .walk: return "#A8D5C2"
            case .medication: return "#F5D6A0"
            case .mood: return "#E8A0BF"
            case .custom: return "#D4A8D5"
            }
        }
    }

    enum MoodLevel: Int, Codable, CaseIterable {
        case calm = 1
        case fussy = 2
        case crying = 3

        var displayName: String {
            switch self {
            case .calm: return "Спокойный"
            case .fussy: return "Беспокойный"
            case .crying: return "Плачет"
            }
        }

        var icon: String {
            switch self {
            case .calm: return "face.smiling.fill"
            case .fussy: return "face.dashed"
            case .crying: return "drop.fill"
            }
        }
    }
}

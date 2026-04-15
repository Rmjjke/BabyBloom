import Foundation
import SwiftData

// MARK: - Diaper Entry
@Model
final class DiaperEntry {
    var id: UUID
    var time: Date
    var type: DiaperType
    var color: StoolColor?
    var notes: String?
    var createdAt: Date

    init(time: Date = Date(), type: DiaperType, color: StoolColor? = nil, notes: String? = nil) {
        self.id = UUID()
        self.time = time
        self.type = type
        self.color = color
        self.notes = notes
        self.createdAt = Date()
    }

    var displayTitle: String {
        switch type {
        case .wet: return "Мокрый"
        case .dirty: return "Грязный"
        case .both: return "Мокрый и грязный"
        }
    }

    enum DiaperType: String, Codable, CaseIterable {
        case wet = "wet"
        case dirty = "dirty"
        case both = "both"

        var displayName: String {
            switch self {
            case .wet: return "Мокрый"
            case .dirty: return "Грязный"
            case .both: return "Оба"
            }
        }

        var icon: String {
            switch self {
            case .wet: return "drop.fill"
            case .dirty: return "circle.fill"
            case .both: return "circle.lefthalf.filled"
            }
        }
    }

    enum StoolColor: String, Codable, CaseIterable {
        case yellow = "yellow"
        case green = "green"
        case black = "black"
        case brown = "brown"
        case orange = "orange"
        case red = "red"
        case white = "white"

        var displayName: String {
            switch self {
            case .yellow: return "Жёлтый"
            case .green: return "Зелёный"
            case .black: return "Чёрный"
            case .brown: return "Коричневый"
            case .orange: return "Оранжевый"
            case .red: return "Красный"
            case .white: return "Белый"
            }
        }

        var hexColor: String {
            switch self {
            case .yellow: return "#F5D55F"
            case .green: return "#6BBF6B"
            case .black: return "#2C2C2C"
            case .brown: return "#8B5E3C"
            case .orange: return "#F5A45F"
            case .red: return "#E05A5A"
            case .white: return "#F0F0F0"
            }
        }

        var isWarning: Bool {
            switch self {
            case .red, .black, .white: return true
            default: return false
            }
        }
    }
}

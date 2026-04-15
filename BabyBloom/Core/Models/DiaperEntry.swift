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

    /// Localized display title
    var displayTitle: String {
        switch type {
        case .wet:   return "diaper.title.wet".l
        case .dirty: return "diaper.title.dirty".l
        case .both:  return "diaper.title.both".l
        }
    }

    enum DiaperType: String, Codable, CaseIterable {
        case wet = "wet"
        case dirty = "dirty"
        case both = "both"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .wet:   return "diaper.type.wet"
            case .dirty: return "diaper.type.dirty"
            case .both:  return "diaper.type.both"
            }
        }

        var icon: String {
            switch self {
            case .wet:   return "drop.fill"
            case .dirty: return "circle.fill"
            case .both:  return "circle.lefthalf.filled"
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

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .yellow: return "diaper.color.yellow"
            case .green:  return "diaper.color.green"
            case .black:  return "diaper.color.black"
            case .brown:  return "diaper.color.brown"
            case .orange: return "diaper.color.orange"
            case .red:    return "diaper.color.red"
            case .white:  return "diaper.color.white"
            }
        }

        var hexColor: String {
            switch self {
            case .yellow: return "#F5D55F"
            case .green:  return "#6BBF6B"
            case .black:  return "#2C2C2C"
            case .brown:  return "#8B5E3C"
            case .orange: return "#F5A45F"
            case .red:    return "#E05A5A"
            case .white:  return "#F0F0F0"
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

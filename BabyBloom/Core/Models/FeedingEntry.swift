import Foundation
import SwiftData

// MARK: - Feeding Entry
@Model
final class FeedingEntry {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var type: FeedingType
    var side: BreastSide?
    var volumeML: Double?
    var durationSeconds: Int?
    var notes: String?
    var createdAt: Date

    init(
        startTime: Date = Date(),
        type: FeedingType,
        side: BreastSide? = nil,
        volumeML: Double? = nil
    ) {
        self.id = UUID()
        self.startTime = startTime
        self.type = type
        self.side = side
        self.volumeML = volumeML
        self.createdAt = Date()
    }

    // MARK: Computed
    var duration: TimeInterval {
        guard let end = endTime else { return Date().timeIntervalSince(startTime) }
        return end.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return String(format: "duration.min_sec".l, mins, secs)
        }
        return String(format: "duration.sec".l, secs)
    }

    var isActive: Bool { endTime == nil }

    /// Localized display title
    var displayTitle: String {
        switch type {
        case .breast:
            if let side {
                switch side {
                case .left:  return "feeding.title.bf_left".l
                case .right: return "feeding.title.bf_right".l
                case .both:  return "feeding.title.bf_both".l
                }
            }
            return "feeding.title.breast".l
        case .formula:
            if let ml = volumeML {
                return String(format: "feeding.title.formula_ml".l, Int(ml))
            }
            return "feeding.title.formula".l
        case .pumped:
            if let ml = volumeML {
                return String(format: "feeding.title.pumped_ml".l, Int(ml))
            }
            return "feeding.title.pumped".l
        }
    }

    enum FeedingType: String, Codable, CaseIterable {
        case breast = "breast"
        case formula = "formula"
        case pumped = "pumped"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .breast:  return "feeding.type.breast"
            case .formula: return "feeding.type.formula"
            case .pumped:  return "feeding.type.pumped"
            }
        }

        var icon: String {
            switch self {
            case .breast:  return "heart.fill"
            case .formula: return "drop.fill"
            case .pumped:  return "arrow.up.heart.fill"
            }
        }

        var color: String {
            switch self {
            case .breast:  return "#E8A0BF"
            case .formula: return "#B0C4F5"
            case .pumped:  return "#D4A8D5"
            }
        }
    }

    enum BreastSide: String, Codable, CaseIterable {
        case left = "left"
        case right = "right"
        case both = "both"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .left:  return "feeding.side.left"
            case .right: return "feeding.side.right"
            case .both:  return "feeding.side.both"
            }
        }

        var icon: String {
            switch self {
            case .left:  return "arrow.left.circle.fill"
            case .right: return "arrow.right.circle.fill"
            case .both:  return "arrow.left.arrow.right.circle.fill"
            }
        }
    }
}

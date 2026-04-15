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
            return "\(mins) мин \(secs) сек"
        }
        return "\(secs) сек"
    }

    var isActive: Bool { endTime == nil }

    var displayTitle: String {
        switch type {
        case .breast:
            if let side {
                return "ГВ — \(side.displayName)"
            }
            return "Грудное вскармливание"
        case .formula:
            if let ml = volumeML {
                return "Смесь — \(Int(ml)) мл"
            }
            return "Смесь"
        case .pumped:
            if let ml = volumeML {
                return "Сцеженное — \(Int(ml)) мл"
            }
            return "Сцеженное молоко"
        }
    }

    enum FeedingType: String, Codable, CaseIterable {
        case breast = "breast"
        case formula = "formula"
        case pumped = "pumped"

        var displayName: String {
            switch self {
            case .breast: return "Грудное"
            case .formula: return "Смесь"
            case .pumped: return "Сцеженное"
            }
        }

        var icon: String {
            switch self {
            case .breast: return "heart.fill"
            case .formula: return "drop.fill"
            case .pumped: return "arrow.up.heart.fill"
            }
        }

        var color: String {
            switch self {
            case .breast: return "#E8A0BF"
            case .formula: return "#B0C4F5"
            case .pumped: return "#D4A8D5"
            }
        }
    }

    enum BreastSide: String, Codable, CaseIterable {
        case left = "left"
        case right = "right"
        case both = "both"

        var displayName: String {
            switch self {
            case .left: return "Левая"
            case .right: return "Правая"
            case .both: return "Обе"
            }
        }

        var icon: String {
            switch self {
            case .left: return "arrow.left.circle.fill"
            case .right: return "arrow.right.circle.fill"
            case .both: return "arrow.left.arrow.right.circle.fill"
            }
        }
    }
}

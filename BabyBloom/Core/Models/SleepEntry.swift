import Foundation
import SwiftData

// MARK: - Sleep Entry
@Model
final class SleepEntry {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var type: SleepType
    var location: SleepLocation?
    var notes: String?
    var createdAt: Date

    init(startTime: Date = Date(), type: SleepType, location: SleepLocation? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.type = type
        self.location = location
        self.createdAt = Date()
    }

    // MARK: Computed
    var duration: TimeInterval {
        guard let end = endTime else { return Date().timeIntervalSince(startTime) }
        return end.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let totalMins = Int(duration) / 60
        let hours = totalMins / 60
        let mins = totalMins % 60
        if hours > 0 {
            return "\(hours) ч \(mins) мин"
        }
        return "\(mins) мин"
    }

    var isActive: Bool { endTime == nil }

    enum SleepType: String, Codable, CaseIterable {
        case nap = "nap"
        case night = "night"

        var displayName: String {
            switch self {
            case .nap: return "Дневной сон"
            case .night: return "Ночной сон"
            }
        }

        var icon: String {
            switch self {
            case .nap: return "sun.max.fill"
            case .night: return "moon.fill"
            }
        }
    }

    enum SleepLocation: String, Codable, CaseIterable {
        case crib = "crib"
        case stroller = "stroller"
        case arms = "arms"

        var displayName: String {
            switch self {
            case .crib: return "Кроватка"
            case .stroller: return "Коляска"
            case .arms: return "На руках"
            }
        }

        var icon: String {
            switch self {
            case .crib: return "bed.double.fill"
            case .stroller: return "figure.walk.motion"
            case .arms: return "hands.and.sparkles.fill"
            }
        }
    }
}

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
            return String(format: "duration.h_min".l, hours, mins)
        }
        return String(format: "duration.min_only".l, mins)
    }

    var isActive: Bool { endTime == nil }

    enum SleepType: String, Codable, CaseIterable {
        case nap = "nap"
        case night = "night"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .nap:   return "sleep.type.nap"
            case .night: return "sleep.type.night"
            }
        }

        var icon: String {
            switch self {
            case .nap:   return "sun.max.fill"
            case .night: return "moon.fill"
            }
        }
    }

    enum SleepLocation: String, Codable, CaseIterable {
        case crib = "crib"
        case stroller = "stroller"
        case arms = "arms"

        /// Localization key — use `.l` in views
        var displayName: String {
            switch self {
            case .crib:     return "sleep.location.crib"
            case .stroller: return "sleep.location.stroller"
            case .arms:     return "sleep.location.arms"
            }
        }

        var icon: String {
            switch self {
            case .crib:     return "bed.double.fill"
            case .stroller: return "figure.walk.motion"
            case .arms:     return "hands.and.sparkles.fill"
            }
        }
    }
}

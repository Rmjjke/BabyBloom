import Foundation
import SwiftData

// MARK: - Sleep Entry
@Model
final class SleepEntry {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var type: SleepType = SleepType.nap
    var location: SleepLocation?
    var notes: String?
    var createdAt: Date = Date()
    var baby: Baby?

    init(startTime: Date = Date(), type: SleepType, location: SleepLocation? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.type = type
        self.location = location
        self.createdAt = Date()
    }

    /// The Add Sleep form's entry. Its End picker only displays times from
    /// Start on, so the end is held at the start here too: what is saved is
    /// what the form showed.
    static func manual(start: Date, end: Date, type: SleepType, location: SleepLocation?) -> SleepEntry {
        let entry = SleepEntry(startTime: start, type: type, location: location)
        entry.endTime = max(start, end)
        return entry
    }

    // MARK: Computed
    /// Never below 0. Earlier versions of the Add Sleep form could store an
    /// end before the start, and a timer stopped on a phone whose clock runs
    /// behind still can; such a row reads as no sleep and is left as stored.
    var duration: TimeInterval {
        max(0, (endTime ?? Date()).timeIntervalSince(startTime))
    }

    var durationFormatted: String {
        let totalMins = Int(duration) / 60
        let hours = totalMins / 60
        let mins = totalMins % 60
        // Whole hours drop the minutes, as in the widget and the weekly card.
        if hours > 0 {
            return (mins == 0
                ? String(format: "duration.h_only".l, hours)
                : String(format: "duration.h_min".l, hours, mins)).gluingNumbersToUnits
        }
        return String(format: "duration.min_only".l, mins).gluingNumbersToUnits
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

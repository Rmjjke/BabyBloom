import Foundation

/// Which medication reminders this device wants pending. Pure, so the rules
/// are pinned by tests with a fixed clock; `MedicationReminderSync` makes the
/// notification centre match it.
///
/// One request per medication, at its next allowed time (the 24-hour maximum
/// included), only while that time is ahead. The switch is this device's
/// alone, a defaults key per medication that never syncs: a synced switch
/// would ring the partner's phone at night unasked, counting from doses that
/// phone may not have yet.
enum MedicationReminderPlan {
    static let identifierPrefix = "bb.med."

    static func identifier(for id: UUID) -> String { identifierPrefix + id.uuidString }

    /// Absent means off: the reminder is opt-in.
    static func switchKey(for id: UUID) -> String { "notify.medication.\(id.uuidString)" }

    struct Course {
        let id: UUID
        let name: String
        let isOn: Bool
        let isEnded: Bool
        let schedule: MedicineSchedule
    }

    struct Reminder: Equatable {
        let identifier: String
        let name: String
        /// The dose the body counts from and names.
        let lastDose: Date
        let fireDate: Date
    }

    /// When a course's reminder fires, or nil when none should be pending:
    /// the switch is off, the course ended, no dose is logged, or the time has
    /// passed, where the screen already says the interval is over.
    static func fireDate(isOn: Bool, isEnded: Bool, schedule: MedicineSchedule) -> Date? {
        guard isOn, !isEnded, let next = schedule.nextAllowed, next > schedule.now else { return nil }
        return next
    }

    static func reminders(for courses: [Course]) -> [Reminder] {
        courses.compactMap { course in
            guard let fire = fireDate(isOn: course.isOn, isEnded: course.isEnded, schedule: course.schedule),
                  let last = course.schedule.lastDose else { return nil }
            return Reminder(identifier: identifier(for: course.id), name: course.name,
                            lastDose: last, fireDate: fire)
        }
    }

    /// The pending ids to remove: every medication id the plan does not want.
    /// That covers a switch turned off, a course ended or past its time, and a
    /// medication deleted here or on another device, which is no longer among
    /// the courses at all. Ids without the prefix are not the plan's.
    static func stale(pending: [String], wanted: [Reminder]) -> [String] {
        let keep = Set(wanted.map(\.identifier))
        return pending.filter { $0.hasPrefix(identifierPrefix) && !keep.contains($0) }
    }
}

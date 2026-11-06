import Foundation
import SwiftData

// MARK: - Medicine

/// A medicine the parent names once, with the minimum time between doses that
/// the doctor or the leaflet gave. The app counts time between doses; it never
/// suggests, calculates or checks a dose.
///
/// A dose is not a model of its own. It is a `.medication` `CustomEvent`
/// linked here, carrying the name and dose text as they were when it was
/// logged (`CustomEvent.dose(of:at:)`). A device on an older version reads a
/// dose as the medication event it always was, and a renamed or deleted
/// medicine leaves the record of each dose as it was logged (DECISIONS
/// 2026-11-03, «A medicine is its own model»).
///
/// Every attribute is optional or defaulted, as CloudKit requires. An older
/// build does not import a record type it does not know, so a medicine is
/// simply absent there.
@Model
final class Medicine {
    var id: UUID = UUID()
    var name: String = ""
    /// The minimum time between two doses. Counted as elapsed time, so a night
    /// the clocks change on neither stretches nor shrinks it. The default is
    /// there only because CloudKit needs one, and no form may preselect it:
    /// the interval is what the doctor or the leaflet said, never a value the
    /// app suggests.
    var intervalMinutes: Int = 360
    /// As written on the prescription. Copied onto each dose, never parsed.
    var doseText: String?
    var note: String?
    /// The most doses in any 24 hours, when the leaflet gives one.
    var maxDosesPer24h: Int?
    /// When the course was ended; nil while it runs. Ending keeps every dose.
    var endedAt: Date?
    var createdAt: Date = Date()
    var baby: Baby?

    /// `.nullify`: a deleted medicine leaves its doses behind as medication
    /// events that still hold the name and dose text, so no record goes with
    /// it.
    @Relationship(deleteRule: .nullify, inverse: \CustomEvent.medicine)
    var doses: [CustomEvent]? = []

    init(name: String, intervalMinutes: Int, doseText: String? = nil) {
        self.id = UUID()
        self.name = name
        self.intervalMinutes = intervalMinutes
        self.doseText = doseText
        self.createdAt = Date()
    }

    /// What the medicine form accepts: above zero in its 15-minute steps, and
    /// at most 48 hours, the last value of its wheels. Zero is not an
    /// interval: every dose would be on time and the status line meaningless.
    static let intervalMinutesRange = 15...(48 * 60)
    /// What a medicine form accepts for the 24-hour maximum.
    static let maxDosesPer24hRange = 1...24

    var isEnded: Bool { endedAt != nil }
}

extension CustomEvent {
    /// A medicine's dose: a medication event linked to one. Older and
    /// free-text medication events are not doses and count for no medicine.
    var isDose: Bool { type == .medication && medicine != nil }

    /// A dose of `medicine` at `time`: a `.medication` event linked to it,
    /// carrying the medicine's name and dose text as they are now.
    static func dose(of medicine: Medicine, at time: Date) -> CustomEvent {
        let event = CustomEvent(time: time, type: .medication)
        event.medicationName = medicine.name
        event.medicationDose = medicine.doseText
        event.medicine = medicine
        event.baby = medicine.baby
        return event
    }
}

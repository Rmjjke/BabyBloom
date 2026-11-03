import Foundation

/// What the medication form holds while it is edited, and its rule for Save.
/// Nothing starts filled in: no chip, no maximum, no sample text. At night a
/// preset reads as a prescription.
struct MedicationFormInput: Equatable {
    enum Interval: Equatable {
        case none
        case chip(hours: Int)
        case other(hours: Int, minutes: Int)
    }

    /// The maximum field: empty is "not set", which differs from a value the
    /// form cannot take.
    enum Maximum: Equatable {
        case notSet
        case value(Int)
        case invalid
    }

    static let chipHours = [4, 6, 8, 12, 24]
    static let otherHours = Array(0...48)
    static let otherMinutes = [0, 15, 30, 45]

    var name = ""
    var interval: Interval = .none
    var doseText = ""
    var maximumText = ""
    var note = ""

    init() {}

    /// Editing: the interval selects its chip, any other value opens Other
    /// with that value.
    init(_ medicine: Medicine) {
        name = medicine.name
        let minutes = medicine.intervalMinutes
        if minutes % 60 == 0, Self.chipHours.contains(minutes / 60) {
            interval = .chip(hours: minutes / 60)
        } else {
            interval = .other(hours: minutes / 60, minutes: minutes % 60)
        }
        doseText = medicine.doseText ?? ""
        maximumText = medicine.maxDosesPer24h.map(String.init) ?? ""
        note = medicine.note ?? ""
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The interval in minutes, when it is one the form accepts: 0 h 0 min is
    /// not an interval, and 48 h is the wheels' last value.
    var intervalMinutes: Int? {
        let minutes: Int
        switch interval {
        case .none: return nil
        case .chip(let hours): minutes = hours * 60
        case .other(let hours, let rest): minutes = hours * 60 + rest
        }
        return Medicine.intervalMinutesRange.contains(minutes) ? minutes : nil
    }

    var maximum: Maximum {
        let text = maximumText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .notSet }
        guard let value = Int(text), Medicine.maxDosesPer24hRange.contains(value) else { return .invalid }
        return .value(value)
    }

    var canSave: Bool { !trimmedName.isEmpty && intervalMinutes != nil && maximum != .invalid }

    /// Writes the form into `medicine`. Doses already logged keep the name and
    /// dose text they were logged with.
    func apply(to medicine: Medicine) {
        guard let intervalMinutes else { return }
        medicine.name = trimmedName
        medicine.intervalMinutes = intervalMinutes
        medicine.doseText = Self.optional(doseText)
        if case .value(let value) = maximum {
            medicine.maxDosesPer24h = value
        } else {
            medicine.maxDosesPer24h = nil
        }
        medicine.note = Self.optional(note)
    }

    static func optional(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

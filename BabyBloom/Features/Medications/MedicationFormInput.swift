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
    /// A stored minutes value off the quarters (set on another device), kept
    /// on the wheel for the whole edit so opening the form never changes it.
    private(set) var keptMinutes: Int?

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
            if !Self.otherMinutes.contains(minutes % 60) { keptMinutes = minutes % 60 }
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

    /// The Other minutes wheel: the quarters and a kept value; at 48 h, the
    /// wheels' last value, only 0.
    func otherMinuteChoices(hours: Int) -> [Int] {
        if hours == Self.otherHours.last { return [0] }
        guard let keptMinutes else { return Self.otherMinutes }
        return (Self.otherMinutes + [keptMinutes]).sorted()
    }

    /// Moves the Other wheels. At 48 h the minutes go to 0, so the wheels
    /// never stand on a value Save refuses.
    mutating func setOther(hours: Int, minutes: Int) {
        interval = .other(hours: hours, minutes: hours == Self.otherHours.last ? 0 : minutes)
    }

    /// What the maximum field keeps: digits, two at most. A paste of «4 doses»
    /// reads 4, and on iPad the number pad is a full keyboard.
    static func maximumDigits(_ text: String) -> String {
        String(text.filter { $0.isASCII && $0.isNumber }.prefix(2))
    }

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

    /// A name or dose kept to one paragraph: each run of line breaks becomes
    /// one space, and a trailing one (a typed Return) goes.
    static func oneParagraph(_ text: String) -> String {
        guard text.contains(where: \.isNewline) else { return text }
        return text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}

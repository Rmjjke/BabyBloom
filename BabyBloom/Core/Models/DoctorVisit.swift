import Foundation
import SwiftData

// MARK: - Pediatrician visit

/// A visit to the pediatrician, marked by the parent. Its date starts the
/// report's period (`DoctorPeriod`).
///
/// A model of its own rather than a new `CustomEvent.EventType` case: a stored
/// enum value an older build does not know crashes that build when the record
/// arrives through CloudKit, while an unknown record TYPE is simply not
/// imported (spike 0a, DECISIONS 2026-11-01). Every attribute is optional or
/// defaulted, as CloudKit requires.
///
/// Change it only through `DoctorVisitActions`: a visit and the questions it
/// stamped must never part.
@Model
final class DoctorVisit {
    var id: UUID = UUID()
    /// The day of the visit; stored at its start of day, the time means nothing.
    var date: Date = Date()
    var note: String?
    var createdAt: Date = Date()
    var baby: Baby?

    /// `.nullify` clears the link but not `askedAt`; `DoctorVisitActions.delete`
    /// clears both, so a deleted visit's questions read as open again.
    @Relationship(deleteRule: .nullify, inverse: \DoctorQuestion.visit)
    var questions: [DoctorQuestion]? = []

    init(date: Date, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.note = note
        self.createdAt = Date()
    }
}

// MARK: - Question for the pediatrician

/// A question the parent wants to ask. Two states only: open (`askedAt` nil),
/// or asked at a visit (`askedAt` and `visit` set). There is no answer field —
/// an answer goes in the visit's note (plan v2 decision 5).
@Model
final class DoctorQuestion {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var askedAt: Date?
    var visit: DoctorVisit?
    var baby: Baby?

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = Date()
    }

    var isOpen: Bool { askedAt == nil }
}

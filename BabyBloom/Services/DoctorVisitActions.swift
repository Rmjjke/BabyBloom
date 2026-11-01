import Foundation
import SwiftData

/// The one place a pediatrician visit or a question is created, changed or
/// deleted — the `TimerActions` idea (DECISIONS 2026-10-29) for M2.
///
/// The rule this exists to hold: a visit and the questions it stamped never
/// part. Logging writes the visit and the stamps in ONE save; deleting clears
/// the stamps and the visit in one save. A view that called `context.delete`
/// on a visit directly would leave its questions "asked" at a visit that no
/// longer exists, invisible both in the open list and in any visit's list.
@MainActor
enum DoctorVisitActions {

    /// Long enough for any real question, short enough to stay a question
    /// (Manager's decision; the field grows, no counter).
    static let questionMaxLength = 500
    /// The design note leaves the note unbounded on screen; this is a storage
    /// guard, not a limit a parent is expected to meet.
    static let noteMaxLength = 2000

    // MARK: Text

    /// Trimmed, then cut by Character so an emoji or a combined letter is
    /// never split.
    static func clampedQuestion(_ text: String) -> String {
        clamp(text, to: questionMaxLength)
    }

    /// nil for a note that is empty once trimmed — "no note", not "".
    static func clampedNote(_ text: String?) -> String? {
        guard let text else { return nil }
        let clamped = clamp(text, to: noteMaxLength)
        return clamped.isEmpty ? nil : clamped
    }

    private static func clamp(_ text: String, to limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    // MARK: Visits

    /// Writes the visit and stamps every question in `asking` as asked at it,
    /// in one save (R2.1). Questions that are not passed stay as they are:
    /// logging never deletes or re-parents an unchecked question (R2.4).
    /// Already-asked questions in `asking` are ignored — a question belongs to
    /// the visit it was first asked at.
    @discardableResult
    static func logVisit(date: Date,
                         note: String?,
                         asking questions: [DoctorQuestion],
                         for baby: Baby?,
                         calendar: Calendar = .current,
                         in context: ModelContext) throws -> DoctorVisit {
        let day = calendar.startOfDay(for: date)
        let visit = DoctorVisit(date: day, note: clampedNote(note))
        visit.baby = baby
        context.insert(visit)
        for question in questions where question.isOpen {
            question.askedAt = day
            question.visit = visit
        }
        try context.save()
        return visit
    }

    /// Date and note only (R2.6). The questions keep their stamps; their
    /// `askedAt` follows the new date so "asked at the visit on …" stays true.
    static func update(_ visit: DoctorVisit,
                       date: Date,
                       note: String?,
                       calendar: Calendar = .current,
                       in context: ModelContext) throws {
        let day = calendar.startOfDay(for: date)
        visit.date = day
        visit.note = clampedNote(note)
        for question in visit.questions ?? [] {
            question.askedAt = day
        }
        try context.save()
    }

    /// Returns the visit's questions to open, then deletes it (R2.7). Returns
    /// how many questions went back, for the analytics payload.
    @discardableResult
    static func delete(_ visit: DoctorVisit, in context: ModelContext) throws -> Int {
        let returned = visit.questions ?? []
        for question in returned {
            question.askedAt = nil
            question.visit = nil
        }
        context.delete(visit)
        try context.save()
        return returned.count
    }

    // MARK: Questions

    /// nil when the text is empty once trimmed — the sheet disables Save then,
    /// so this is a second guard, not the UI's rule.
    @discardableResult
    static func addQuestion(_ text: String,
                            for baby: Baby?,
                            in context: ModelContext) throws -> DoctorQuestion? {
        let clamped = clampedQuestion(text)
        guard !clamped.isEmpty else { return nil }
        let question = DoctorQuestion(text: clamped)
        question.baby = baby
        context.insert(question)
        try context.save()
        return question
    }

    /// An edit that empties the text is ignored: deleting is its own action.
    static func edit(_ question: DoctorQuestion, text: String, in context: ModelContext) throws {
        let clamped = clampedQuestion(text)
        guard !clamped.isEmpty else { return }
        question.text = clamped
        try context.save()
    }

    static func delete(_ question: DoctorQuestion, in context: ModelContext) throws {
        context.delete(question)
        try context.save()
    }

    /// "Back to open" (R3.4).
    static func reopen(_ question: DoctorQuestion, in context: ModelContext) throws {
        question.askedAt = nil
        question.visit = nil
        try context.save()
    }
}

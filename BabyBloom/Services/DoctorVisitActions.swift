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

    /// A visit is a DAY, stored at noon of it. Midnight would move it to the
    /// day before on a device a few time zones west — the second parent's
    /// iPad abroad — and with it the report's period start. Noon survives any
    /// offset up to ±11 h; readers take `startOfDay` of it.
    nonisolated static func visitDay(_ date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    /// Saves, or throws with the context put back as it was: a failed
    /// `logVisit` would otherwise leave the visit inserted and the questions
    /// stamped, so a retry writes a second, empty visit and autosave later
    /// persists the first one anyway.
    private static func commit(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
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
        let day = visitDay(date, calendar: calendar)
        let visit = DoctorVisit(date: day, note: clampedNote(note))
        visit.baby = baby
        context.insert(visit)
        for question in questions where question.isOpen {
            question.askedAt = day
            question.visit = visit
        }
        try commit(context)
        return visit
    }

    /// Date and note only (R2.6). The questions are not touched: "asked at
    /// the visit on …" reads the visit's date, and rewriting their `askedAt`
    /// here could race a delete of the same visit on another device into a
    /// question stamped "asked" at no visit.
    static func update(_ visit: DoctorVisit,
                       date: Date,
                       note: String?,
                       calendar: Calendar = .current,
                       in context: ModelContext) throws {
        visit.date = visitDay(date, calendar: calendar)
        visit.note = clampedNote(note)
        try commit(context)
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
        try commit(context)
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
        try commit(context)
        return question
    }

    /// An edit that empties the text is ignored: deleting is its own action.
    static func edit(_ question: DoctorQuestion, text: String, in context: ModelContext) throws {
        let clamped = clampedQuestion(text)
        guard !clamped.isEmpty else { return }
        question.text = clamped
        try commit(context)
    }

    static func delete(_ question: DoctorQuestion, in context: ModelContext) throws {
        context.delete(question)
        try commit(context)
    }

    /// "Back to open" (R3.4).
    static func reopen(_ question: DoctorQuestion, in context: ModelContext) throws {
        question.askedAt = nil
        question.visit = nil
        try commit(context)
    }
}

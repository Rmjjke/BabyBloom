import XCTest
import SwiftData
@testable import BabyBloom

/// The visit/question write path. The invariant under every case: a visit and
/// the questions it stamped never part (R2.1, R2.7).
@MainActor
final class DoctorVisitActionsTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func makeContext() throws -> (ModelContext, Baby) {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        let baby = Baby(name: "Mia", birthDate: date("2026-09-01T00:00:00Z"), gender: .female, feedingType: .breast)
        context.insert(baby)
        try context.save()
        return (context, baby)
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func questions(_ context: ModelContext) throws -> [DoctorQuestion] {
        try context.fetch(FetchDescriptor<DoctorQuestion>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    // MARK: Logging a visit

    func testLoggingStampsOnlyTheCheckedQuestionsInOneSave() throws {
        let (context, baby) = try makeContext()
        let a = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let b = try XCTUnwrap(DoctorVisitActions.addQuestion("Daily bath?", for: baby, in: context))
        let c = try XCTUnwrap(DoctorVisitActions.addQuestion("Vitamin D?", for: baby, in: context))

        let visit = try DoctorVisitActions.logVisit(date: date("2026-10-12T15:30:00Z"), note: "  All fine  ",
                                                    asking: [a, c], for: baby, calendar: calendar, in: context)

        XCTAssertFalse(context.hasChanges, "visit and stamps go out in the same save")
        XCTAssertEqual(visit.date, date("2026-10-12T12:00:00Z"), "a visit is a day, held at its noon")
        XCTAssertEqual(visit.note, "All fine")
        XCTAssertIdentical(visit.baby, baby)
        XCTAssertEqual(a.askedAt, visit.date)
        XCTAssertIdentical(a.visit, visit)
        XCTAssertIdentical(c.visit, visit)
        XCTAssertTrue(b.isOpen, "an unchecked question stays open (R2.4)")
        XCTAssertNil(b.visit)
        XCTAssertEqual(try questions(context).count, 3, "logging never deletes a question")
    }

    /// A question belongs to the visit it was first asked at.
    func testAnAlreadyAskedQuestionIsNotReParented() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let first = try DoctorVisitActions.logVisit(date: date("2026-10-01T09:00:00Z"), note: nil,
                                                    asking: [q], for: baby, calendar: calendar, in: context)
        _ = try DoctorVisitActions.logVisit(date: date("2026-10-20T09:00:00Z"), note: nil,
                                            asking: [q], for: baby, calendar: calendar, in: context)
        XCTAssertIdentical(q.visit, first)
        XCTAssertEqual(q.askedAt, date("2026-10-01T12:00:00Z"))
    }

    func testAnEmptyNoteIsNoNote() throws {
        let (context, baby) = try makeContext()
        let visit = try DoctorVisitActions.logVisit(date: Date(), note: " \n ", asking: [], for: baby,
                                                    calendar: calendar, in: context)
        XCTAssertNil(visit.note)
    }

    func testTheNoteIsCappedAt2000Characters() throws {
        let (context, baby) = try makeContext()
        let visit = try DoctorVisitActions.logVisit(date: Date(), note: String(repeating: "é", count: 2500),
                                                    asking: [], for: baby, calendar: calendar, in: context)
        XCTAssertEqual(visit.note?.count, 2000)
    }

    // MARK: Editing and deleting a visit

    func testEditingChangesDateAndNoteAndKeepsTheQuestionsAsked() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let visit = try DoctorVisitActions.logVisit(date: date("2026-10-12T09:00:00Z"), note: "x",
                                                    asking: [q], for: baby, calendar: calendar, in: context)
        try DoctorVisitActions.update(visit, date: date("2026-10-11T18:00:00Z"), note: "y",
                                      calendar: calendar, in: context)
        XCTAssertEqual(visit.date, date("2026-10-11T12:00:00Z"))
        XCTAssertEqual(visit.note, "y")
        XCTAssertIdentical(q.visit, visit, "R2.6: the asked questions stay asked at this visit")
        XCTAssertEqual(q.askedAt, date("2026-10-12T12:00:00Z"), "and are not touched by the edit")
    }

    /// Plan v2 decision 5: deleting a visit returns its questions, never deletes them.
    func testDeletingAVisitReturnsItsQuestionsToOpen() throws {
        let (context, baby) = try makeContext()
        let a = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let b = try XCTUnwrap(DoctorVisitActions.addQuestion("Daily bath?", for: baby, in: context))
        let visit = try DoctorVisitActions.logVisit(date: Date(), note: nil, asking: [a, b], for: baby,
                                                    calendar: calendar, in: context)

        let returned = try DoctorVisitActions.delete(visit, in: context)

        XCTAssertEqual(returned, 2)
        XCTAssertFalse(context.hasChanges)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorVisit>()), 0)
        let all = try questions(context)
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.allSatisfy { $0.isOpen && $0.visit == nil })
    }

    // MARK: Questions

    func testAddingTrimsAndCapsAt500Characters() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("  " + String(repeating: "a", count: 600) + "\n",
                                                             for: baby, in: context))
        XCTAssertEqual(q.text.count, 500)
        XCTAssertTrue(q.isOpen)
        XCTAssertIdentical(q.baby, baby)
    }

    /// The cut never splits a grapheme: a family emoji is one Character.
    func testTheCapCountsCharactersNotScalars() {
        let text = String(repeating: "x", count: 499) + "👨‍👩‍👧" + "tail"
        XCTAssertEqual(DoctorVisitActions.clampedQuestion(text).last, "👨‍👩‍👧")
    }

    func testAnEmptyQuestionIsNotAdded() throws {
        let (context, baby) = try makeContext()
        XCTAssertNil(try DoctorVisitActions.addQuestion(" \n\t", for: baby, in: context))
        XCTAssertEqual(try questions(context).count, 0)
    }

    func testEditingToEmptyKeepsTheOldText() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        try DoctorVisitActions.edit(q, text: "   ", in: context)
        XCTAssertEqual(q.text, "Tummy sleep?")
        try DoctorVisitActions.edit(q, text: " Tummy sleep at 3 months? ", in: context)
        XCTAssertEqual(q.text, "Tummy sleep at 3 months?")
    }

    func testBackToOpenClearsTheStamp() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let visit = try DoctorVisitActions.logVisit(date: Date(), note: nil, asking: [q], for: baby,
                                                    calendar: calendar, in: context)
        try DoctorVisitActions.reopen(q, in: context)
        XCTAssertTrue(q.isOpen)
        XCTAssertNil(q.visit)
        XCTAssertEqual(visit.questions?.count ?? 0, 0)
    }

    /// A merge of "delete visit" on one device with "edit visit" on another
    /// can leave a stamp with no visit; the question must read as open.
    func testAQuestionStampedAtNoVisitIsOpen() {
        let q = DoctorQuestion(text: "Tummy sleep?")
        q.askedAt = date("2026-10-12T12:00:00Z")
        XCTAssertTrue(q.isOpen)
        XCTAssertEqual(DoctorPeriod.openQuestions([q]).count, 1)
    }

    /// A visit logged at 23:30 in Moscow is still that day for a device in New York.
    func testAVisitDayReadsTheSameDayAcrossTimeZones() throws {
        var moscow = Calendar(identifier: .gregorian)
        moscow.timeZone = TimeZone(identifier: "Europe/Moscow")!
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let stored = DoctorVisitActions.visitDay(date("2026-11-01T20:30:00Z"), calendar: moscow)
        XCTAssertEqual(moscow.component(.day, from: stored), 1)
        XCTAssertEqual(newYork.component(.day, from: stored), 1)
    }

    func testDeletingAnAskedQuestionLeavesTheVisit() throws {
        let (context, baby) = try makeContext()
        let q = try XCTUnwrap(DoctorVisitActions.addQuestion("Tummy sleep?", for: baby, in: context))
        let visit = try DoctorVisitActions.logVisit(date: Date(), note: "kept", asking: [q], for: baby,
                                                    calendar: calendar, in: context)
        try DoctorVisitActions.delete(q, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorVisit>()), 1)
        XCTAssertEqual(visit.note, "kept")
        XCTAssertEqual(visit.questions?.count ?? 0, 0)
    }
}

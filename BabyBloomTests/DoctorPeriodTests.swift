import XCTest
@testable import BabyBloom

/// Where the report's period starts (R4) and the open-question order (R3.5).
/// Plain objects, no store: the rules are pure.
final class DoctorPeriodTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    private func visit(_ day: String, created: String) -> DoctorVisit {
        let v = DoctorVisit(date: date(day))
        v.createdAt = date(created)
        return v
    }

    private let birth = ISO8601DateFormatter().date(from: "2026-09-01T07:40:00Z")!

    func testWithNoVisitThePeriodStartsAtTheBirthDay() {
        XCTAssertEqual(DoctorPeriod.start(visits: [], birthDate: birth, calendar: calendar),
                       date("2026-09-01T00:00:00Z"))
        XCTAssertNil(DoctorPeriod.latestVisit([]))
    }

    /// Entries made on the visit day belong to the new period: 00:00, not the visit time.
    func testThePeriodStartsAtMidnightOfTheLatestVisit() {
        let visits = [visit("2026-10-01T00:00:00Z", created: "2026-10-01T12:00:00Z"),
                      visit("2026-10-20T00:00:00Z", created: "2026-10-20T16:00:00Z")]
        XCTAssertEqual(DoctorPeriod.start(visits: visits, birthDate: birth, calendar: calendar),
                       date("2026-10-20T00:00:00Z"))
    }

    /// R4.3: a visit logged late with an earlier date never moves the period.
    func testALateLoggedEarlierVisitDoesNotMoveThePeriod() {
        let latest = visit("2026-10-20T00:00:00Z", created: "2026-10-20T16:00:00Z")
        let lateLogged = visit("2026-10-05T00:00:00Z", created: "2026-10-25T09:00:00Z")
        XCTAssertIdentical(DoctorPeriod.latestVisit([latest, lateLogged]), latest)
    }

    /// Manager's decision: two visits on one date → the one logged last.
    func testOnTheSameDateTheVisitLoggedLastWins() {
        let morning = visit("2026-10-20T00:00:00Z", created: "2026-10-20T09:00:00Z")
        let evening = visit("2026-10-20T00:00:00Z", created: "2026-10-20T19:00:00Z")
        XCTAssertIdentical(DoctorPeriod.latestVisit([evening, morning]), evening)
        XCTAssertIdentical(DoctorPeriod.latestVisit([morning, evening]), evening)
    }

    func testOpenQuestionsAreOldestFirstAndExcludeAsked() {
        let older = DoctorQuestion(text: "older"); older.createdAt = date("2026-10-02T10:00:00Z")
        let newer = DoctorQuestion(text: "newer"); newer.createdAt = date("2026-10-05T10:00:00Z")
        let asked = DoctorQuestion(text: "asked"); asked.createdAt = date("2026-10-01T10:00:00Z")
        asked.askedAt = date("2026-10-20T00:00:00Z")
        XCTAssertEqual(DoctorPeriod.openQuestions([newer, asked, older]).map(\.text), ["older", "newer"])
    }
}

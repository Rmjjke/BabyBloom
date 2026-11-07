import XCTest
import SwiftData
@testable import BabyBloom

#if targetEnvironment(simulator)
/// The four pediatrician fixtures: the totals the card and the Maestro flows
/// read, and the dates the period rules hang on. `now` is pinned so a run at
/// any hour or in any DST week sees the same days.
@MainActor
final class SeedScenarioDoctorTests: XCTestCase {

    private let cal = Calendar.current
    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 15))!
    }
    private var today: Date { cal.startOfDay(for: now) }
    private func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }

    private func seeded(_ scenario: SeedScenario) throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        scenario.seedDoctor(into: context, now: now)
        try context.save()
        return context
    }

    private func all<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }

    func testDoctorMonthTotals() throws {
        let c = try seeded(.doctorMonth)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Baby>()), 1)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<GrowthEntry>()), 10)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<FeedingEntry>()), 182)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<SleepEntry>()), 41)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<DiaperEntry>()), 140)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<CustomEvent>()), 15)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<DoctorVisit>()), 1)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<DoctorQuestion>()), 5)

        let feeds = try all(FeedingEntry.self, c)
        XCTAssertEqual(feeds.filter { $0.type == .breast }.count, 142)
        XCTAssertEqual(feeds.filter { $0.type == .formula }.count, 20)
        XCTAssertEqual(feeds.filter { $0.type == .pumped }.count, 20)
        XCTAssertEqual(try all(DiaperEntry.self, c).filter { $0.color == .green }.count, 2)
    }

    func testDoctorMonthPeriodHoldsEightWeighingsAndTwoAskedQuestions() throws {
        let c = try seeded(.doctorMonth)
        let baby = try XCTUnwrap(all(Baby.self, c).first)
        let visits = try all(DoctorVisit.self, c)
        let start = DoctorPeriod.start(visits: visits, birthDate: baby.birthDate)
        XCTAssertEqual(start, day(20))
        XCTAssertEqual(try all(GrowthEntry.self, c).filter { $0.date >= start }.count, 8)
        XCTAssertEqual(DoctorPeriod.latestVisit(visits)?.questions?.count, 2)
        XCTAssertEqual(DoctorPeriod.openQuestions(try all(DoctorQuestion.self, c)).count, 3)
    }

    func testDoctorNoVisitStartsAtBirth() throws {
        let c = try seeded(.doctorNoVisit)
        let baby = try XCTUnwrap(all(Baby.self, c).first)
        let visits = try all(DoctorVisit.self, c)
        XCTAssertEqual(visits.count, 0)
        XCTAssertEqual(DoctorPeriod.start(visits: visits, birthDate: baby.birthDate),
                       cal.startOfDay(for: baby.birthDate))
        XCTAssertEqual(DoctorPeriod.openQuestions(try all(DoctorQuestion.self, c)).count, 5)
    }

    func testDoctorVisitTodayHasNothingSinceTheVisit() throws {
        let c = try seeded(.doctorVisitToday)
        let visits = try all(DoctorVisit.self, c)
        XCTAssertEqual(visits.count, 2)
        XCTAssertEqual(DoctorPeriod.latestVisit(visits).map { Calendar.current.startOfDay(for: $0.date) }, today)
        XCTAssertTrue(try all(FeedingEntry.self, c).allSatisfy { $0.startTime < today })
        XCTAssertTrue(try all(SleepEntry.self, c).allSatisfy { $0.startTime < today })
        XCTAssertTrue(try all(DiaperEntry.self, c).allSatisfy { $0.time < today })
        XCTAssertTrue(try all(GrowthEntry.self, c).allSatisfy { $0.date < today })
        XCTAssertTrue(try all(CustomEvent.self, c).allSatisfy { $0.time < today })
        XCTAssertEqual(DoctorPeriod.periodDays(from: today, to: now), 0)
        XCTAssertEqual(DoctorPeriod.openQuestions(try all(DoctorQuestion.self, c)).count, 1)
    }

    func testDoctorEventsCapOverflowsTheFreeListAndKeepsBothVisits() throws {
        let c = try seeded(.doctorEventsCap)
        let events = try all(CustomEvent.self, c)
        XCTAssertEqual(events.count, 39)
        let cutoff = try XCTUnwrap(cal.date(byAdding: .day, value: -15, to: now))
        XCTAssertEqual(events.filter { $0.time >= cutoff }.count, 31, "past the free cap of 20")
        let visits = try all(DoctorVisit.self, c)
        XCTAssertEqual(visits.count, 2)
        let history = EventsHistory(events: events.sorted { $0.time > $1.time },
                                    visits: visits.sorted { $0.date > $1.date }, cutoff: cutoff)
        XCTAssertEqual(history.rows.count, 22, "20 capped events and both visits")
        XCTAssertEqual(DoctorPeriod.openQuestions(try all(DoctorQuestion.self, c)).count, 2)
    }

    func testDoctorTwoVisitsPicksTheLaterLoggedOnTheLatestDate() throws {
        let c = try seeded(.doctorTwoVisits)
        let baby = try XCTUnwrap(all(Baby.self, c).first)
        let visits = try all(DoctorVisit.self, c)
        XCTAssertEqual(visits.count, 3)
        let latest = try XCTUnwrap(DoctorPeriod.latestVisit(visits))
        XCTAssertEqual(latest.note, "Logged again in the evening.")
        // VC is logged last but dated a month back, so it cannot move the start.
        XCTAssertEqual(DoctorPeriod.start(visits: visits, birthDate: baby.birthDate), day(10))
        XCTAssertEqual(latest.questions?.count, 2)
        XCTAssertEqual(DoctorPeriod.openQuestions(try all(DoctorQuestion.self, c)).count, 1)
    }

    func testSeedTextsPassTheClosedWordScan() throws {
        let banned = try NSRegularExpression(
            pattern: #"\b(normal|abnormal|low|high|too|enough|only|good|poor|worry|concern|warning|should|risk|healthy|behind|ahead)\b"#,
            options: [.caseInsensitive]
        )
        for scenario in [SeedScenario.doctorMonth, .doctorNoVisit, .doctorVisitToday, .doctorTwoVisits, .doctorEventsCap] {
            let c = try seeded(scenario)
            let texts = try all(DoctorQuestion.self, c).map(\.text)
                + all(DoctorVisit.self, c).compactMap(\.note)
            for text in texts {
                let range = NSRange(text.startIndex..., in: text)
                XCTAssertNil(banned.firstMatch(in: text, range: range), "\(scenario): \(text)")
            }
        }
    }
}
#endif

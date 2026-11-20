import XCTest
import SwiftData
@testable import BabyBloom

#if targetEnvironment(simulator)
/// The offer fixtures land each moment on or past its threshold, or one short
/// of it, read through the same loader and rule the app uses, at any hour a
/// flow happens to run.
@MainActor
final class SeedScenarioOfferTests: XCTestCase {

    private let calendar = Calendar.autoupdatingCurrent
    private let hours = [0, 1, 12, 23]

    private func now(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: hour, minute: 30))!
    }

    private func facts(_ scenario: SeedScenario, now: Date) throws -> OfferRule.Facts {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        let suite = "offer-seed-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        scenario.seedOffer(into: context, now: now, defaults: defaults)
        try context.save()
        return OfferRule.Facts.load(in: context, onboardingEndedAt: OnboardingEnd.stored(defaults: defaults), now: now)
    }

    private func decision(_ scenario: SeedScenario, now: Date) throws -> OfferRule.Decision {
        OfferRule.decide(facts: try facts(scenario, now: now), ledger: .empty,
                         account: .init(isPremium: false, entitlementsResolved: true, cohort: .new),
                         situation: .calm, now: now, calendar: calendar)
    }

    private func due(_ scenario: SeedScenario, now: Date) throws -> [OfferContent] {
        let facts = try facts(scenario, now: now)
        return OfferRule.dueMoments(facts: facts, ended: try XCTUnwrap(facts.onboardingEndedAt), now: now, calendar: calendar)
    }

    func testEachFixtureStandsOnItsThresholdAtAnyHour() throws {
        let expected: [(SeedScenario, OfferRule.Decision)] = [
            (.offerDays2, .wait(.notDue)),
            (.offerDays3, .show(.firstResultDays, continuing: false)),
            (.offerWeighingClean, .show(.firstResultPoint, continuing: false)),
            (.offerOldest14, .wait(.notDue)),
            (.offerOldest16, .show(.historyEdge, continuing: false)),
            (.offerOnboarded27, .wait(.notDue)),
            (.offerOnboarded28, .show(.monthReport, continuing: false)),
        ]
        for hour in hours {
            for (scenario, wanted) in expected {
                XCTAssertEqual(try decision(scenario, now: now(hour: hour)), wanted, "\(scenario) at \(hour):30")
            }
        }
    }

    func testSixDaysAreAFirstResultAndSevenAFirstWeek() throws {
        for hour in hours {
            let at = now(hour: hour)
            XCTAssertEqual(try due(.offerDays6, now: at), [.firstResultDays], "\(hour):30")
            XCTAssertEqual(try due(.offerDays7, now: at), [.firstResultDays, .firstWeek], "\(hour):30")
        }
    }

    func testTheFlaggedWeighingHoldsAndTheCleanOneDoesNot() throws {
        for hour in hours {
            let at = now(hour: hour)
            let clean = try facts(.offerWeighingClean, now: at)
            XCTAssertEqual(clean.weighings.filter { $0.createdAt > clean.onboardingEndedAt! }.map(\.flagged), [false])
            let flagged = try facts(.offerWeighingFlagged, now: at)
            XCTAssertEqual(flagged.weighings.filter { $0.createdAt > flagged.onboardingEndedAt! }.map(\.flagged), [true])
            // 3.0 kg eight days after 3.4 kg at birth stands as a clinical
            // blocker, which comes before the flagged weighing's own day.
            XCTAssertEqual(try decision(.offerWeighingFlagged, now: at), .hold(.clinical), "\(hour):30")
        }
    }

    func testTheBirthWeightIsSetupAndNothingIsLaterThanNow() throws {
        for scenario in SeedScenario.offerScenarios {
            let at = now(hour: 0)
            let facts = try facts(scenario, now: at)
            let ended = try XCTUnwrap(facts.onboardingEndedAt)
            XCTAssertEqual(facts.weighings.filter { $0.createdAt <= ended }.count, 1, "\(scenario): the birth weight")
            XCTAssertTrue(facts.records.allSatisfy { $0.date <= at && $0.createdAt <= at }, "\(scenario)")
            XCTAssertTrue(facts.weighings.allSatisfy { $0.date <= at && $0.createdAt <= at }, "\(scenario)")
        }
    }
}
#endif

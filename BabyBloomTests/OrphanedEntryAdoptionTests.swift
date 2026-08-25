import XCTest
import SwiftData
@testable import BabyBloom

/// The defect: no insert site ever set `entry.baby`, so `Baby`'s `.cascade`
/// delete rules were inert — deleting the profile left every record behind.
@MainActor
final class OrphanedEntryAdoptionTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                             DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func makeBaby(in context: ModelContext) -> Baby {
        let baby = Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        return baby
    }

    /// Every entity type is adopted, not just the one that happened to be tested.
    private func insertOrphans(in context: ModelContext) {
        context.insert(FeedingEntry(startTime: Date(), type: .breast, side: .left, volumeML: nil))
        context.insert(SleepEntry(startTime: Date(), type: .nap))
        context.insert(DiaperEntry(time: Date(), type: .wet))
        context.insert(GrowthEntry(date: Date(), weightKg: 4.2, heightCm: 55, headCircumferenceCm: nil))
        context.insert(CustomEvent(time: Date(), type: .bath))
    }

    func testAdoptsEveryOrphanedEntryType() throws {
        let context = try makeContext()
        let baby = makeBaby(in: context)
        insertOrphans(in: context)
        try context.save()

        XCTAssertTrue(OrphanedEntryAdoption.adopt(in: context))

        XCTAssertEqual(try context.fetch(FetchDescriptor<FeedingEntry>()).first?.baby?.id, baby.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SleepEntry>()).first?.baby?.id, baby.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DiaperEntry>()).first?.baby?.id, baby.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GrowthEntry>()).first?.baby?.id, baby.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomEvent>()).first?.baby?.id, baby.id)
    }

    /// The point of the whole task: once entries are owned, deleting the Baby
    /// actually takes them with it.
    func testCascadeDeleteWorksAfterAdoption() throws {
        let context = try makeContext()
        let baby = makeBaby(in: context)
        insertOrphans(in: context)
        try context.save()
        OrphanedEntryAdoption.adopt(in: context)

        context.delete(baby)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<FeedingEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SleepEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DiaperEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<GrowthEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomEvent>()).count, 0)
    }

    /// A fresh install still in onboarding has no profile to adopt into. The
    /// pass must report "not done" so it runs again once one exists, instead of
    /// marking itself complete and leaving those entries orphaned forever.
    func testDoesNotClaimSuccessWithoutABaby() throws {
        let context = try makeContext()
        insertOrphans(in: context)
        try context.save()

        XCTAssertFalse(OrphanedEntryAdoption.adopt(in: context))
        XCTAssertNil(try context.fetch(FetchDescriptor<FeedingEntry>()).first?.baby)
    }

    func testIsIdempotent() throws {
        let context = try makeContext()
        let baby = makeBaby(in: context)
        insertOrphans(in: context)
        try context.save()

        XCTAssertTrue(OrphanedEntryAdoption.adopt(in: context))
        XCTAssertTrue(OrphanedEntryAdoption.adopt(in: context), "second run must be a clean no-op")
        XCTAssertEqual(try context.fetch(FetchDescriptor<FeedingEntry>()).first?.baby?.id, baby.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FeedingEntry>()).count, 1)
    }

    /// `runIfNeeded` must not burn its one-shot flag on an install that had no
    /// profile yet — otherwise the entries stay orphaned for good.
    func testRunIfNeededRetriesUntilAProfileExists() throws {
        let context = try makeContext()
        let defaults = UserDefaults(suiteName: "adoption-test-\(UUID().uuidString)")!
        insertOrphans(in: context)
        try context.save()

        OrphanedEntryAdoption.runIfNeeded(in: context, defaults: defaults)
        XCTAssertNil(try context.fetch(FetchDescriptor<FeedingEntry>()).first?.baby)

        let baby = makeBaby(in: context)
        try context.save()
        OrphanedEntryAdoption.runIfNeeded(in: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FeedingEntry>()).first?.baby?.id, baby.id)
    }
}

import XCTest
import SwiftData
@testable import BabyBloom

/// The store's shape, pinned: which models it holds, that CloudKit can mirror
/// every one of them, and which enum values are on disk.
final class AppSchemaTests: XCTestCase {

    /// Changing this list changes the store every installed version opens.
    /// Adding a model is safe (older versions ignore an unknown record type);
    /// removing or renaming one drops its table. Update the pin deliberately.
    func testTheStoreHoldsExactlyTheseModels() {
        let names = AppSchema.schema.entities.map(\.name).sorted()
        XCTAssertEqual(names, [
            "Baby", "CustomEvent", "DiaperEntry", "DoctorQuestion",
            "DoctorVisit", "FeedingEntry", "GrowthEntry", "Medicine", "SleepEntry"
        ])
    }

    /// CloudKit mirroring refuses a non-optional attribute without a default
    /// and a non-optional relationship. The store is local only today; the
    /// rules are pinned so that turning sync back on needs no model migration.
    func testEveryAttributeAndRelationshipIsCloudKitValid() {
        for entity in AppSchema.schema.entities {
            for attribute in entity.attributes {
                XCTAssertTrue(attribute.isOptional || attribute.defaultValue != nil,
                              "\(entity.name).\(attribute.name) needs a default or must be optional")
                XCTAssertFalse(attribute.isUnique,
                               "\(entity.name).\(attribute.name): CloudKit has no unique constraints")
            }
            for relationship in entity.relationships {
                XCTAssertTrue(relationship.isOptional,
                              "\(entity.name).\(relationship.name) must be optional for CloudKit")
                XCTAssertNotNil(relationship.inverseName,
                                "\(entity.name).\(relationship.name) needs an inverse for CloudKit")
            }
        }
    }

    func testTheNewModelsOpenAndRelateInAStore() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let baby = Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        let visit = DoctorVisit(date: Date())
        visit.baby = baby
        context.insert(visit)
        let question = DoctorQuestion(text: "Tummy sleep?")
        question.baby = baby
        question.visit = visit
        context.insert(question)
        try context.save()
        XCTAssertEqual(baby.doctorVisits?.count, 1)
        XCTAssertEqual(baby.doctorQuestions?.count, 1)
        XCTAssertEqual(visit.questions?.count, 1)

        // Deleting the profile takes its visits and questions with it.
        context.delete(baby)
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorVisit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<DoctorQuestion>()), 0)
    }

    @MainActor
    func testAMedicineOwnsItsDosesAndBelongsToTheBaby() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let baby = Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        medicine.baby = baby
        context.insert(medicine)
        for hours in [4.0, 1.0] {
            context.insert(CustomEvent.dose(of: medicine, at: Date().addingTimeInterval(-hours * 3600)))
        }
        try context.save()
        XCTAssertEqual(baby.medicines?.count, 1)
        XCTAssertEqual(medicine.doses?.count, 2)
        XCTAssertEqual(baby.customEvents?.count, 2)
    }
}

/// A persisted enum is CLOSED (DECISIONS 2026-11-01), so that sync can return.
///
/// Every case below is stored as its raw value. A device on an older build
/// that receives a record holding a value it does not know crashes on read:
/// "SwiftData/DefaultStore.swift: Fatal error: Failed to decode a composite
/// attribute". It does not skip the record;
/// it takes the whole app down, on every launch, until it updates.
///
/// If this test fails because you added a case: don't. Add a new model or a new
/// optional attribute instead — an older build ignores both. Removing or
/// renaming a case breaks reading the rows already on disk, on THIS build.
final class FrozenPersistedEnumTests: XCTestCase {

    private func raw<E: CaseIterable & RawRepresentable>(_: E.Type) -> [String] {
        E.allCases.map { "\($0.rawValue)" }
    }

    func testPersistedEnumCasesAreFrozen() {
        XCTAssertEqual(raw(FeedingEntry.FeedingType.self), ["breast", "formula", "pumped"])
        XCTAssertEqual(raw(FeedingEntry.BreastSide.self), ["left", "right", "both"])
        XCTAssertEqual(raw(DiaperEntry.DiaperType.self), ["wet", "dirty", "both"])
        XCTAssertEqual(raw(DiaperEntry.StoolColor.self),
                       ["yellow", "green", "black", "brown", "orange", "red", "white"])
        XCTAssertEqual(raw(CustomEvent.EventType.self), ["bath", "walk", "medication", "mood", "custom"])
        XCTAssertEqual(raw(CustomEvent.MoodLevel.self), ["1", "2", "3"])
        XCTAssertEqual(raw(Baby.Gender.self), ["male", "female"])
        XCTAssertEqual(raw(Baby.FeedingType.self), ["breast", "formula", "mixed"])
        XCTAssertEqual(raw(SleepEntry.SleepType.self), ["nap", "night"])
        XCTAssertEqual(raw(SleepEntry.SleepLocation.self), ["crib", "stroller", "arms"])
    }
}

import XCTest
import SwiftData
@testable import BabyBloom

/// What a dose is, and what happens to it when its medicine or baby goes.
@MainActor
final class MedicineModelTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func makeMedicine(in context: ModelContext) -> (Baby, Medicine) {
        let baby = Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        medicine.baby = baby
        context.insert(medicine)
        return (baby, medicine)
    }

    func testADoseIsAMedicationEventCarryingTheMedicinesNameAndDose() throws {
        let context = try makeContext()
        let (baby, medicine) = makeMedicine(in: context)
        let time = Date(timeIntervalSince1970: 1_780_000_000)
        let dose = CustomEvent.dose(of: medicine, at: time)
        context.insert(dose)
        try context.save()

        XCTAssertEqual(dose.type, .medication)
        XCTAssertEqual(dose.time, time)
        XCTAssertEqual(dose.medicationName, medicine.name)
        XCTAssertEqual(dose.medicationDose, medicine.doseText)
        XCTAssertTrue(dose.medicine === medicine)
        XCTAssertTrue(dose.baby === baby)
    }

    func testRenamingTheMedicineLeavesLoggedDosesAsLogged() throws {
        let context = try makeContext()
        let (_, medicine) = makeMedicine(in: context)
        let dose = CustomEvent.dose(of: medicine, at: Date())
        context.insert(dose)
        medicine.name = "Calpol"
        medicine.doseText = "5 ml"
        try context.save()

        XCTAssertEqual(dose.medicationName, "Paracetamol")
        XCTAssertEqual(dose.medicationDose, "2.5 ml")
    }

    func testDeletingTheMedicineKeepsEveryDoseAsANamedEvent() throws {
        let context = try makeContext()
        let (_, medicine) = makeMedicine(in: context)
        for hours in [3.0, 2.0, 1.0] {
            context.insert(CustomEvent.dose(of: medicine, at: Date().addingTimeInterval(-hours * 3600)))
        }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CustomEvent>()), 3)

        context.delete(medicine)
        try context.save()

        let events = try context.fetch(FetchDescriptor<CustomEvent>())
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events.allSatisfy { $0.medicine == nil })
        XCTAssertTrue(events.allSatisfy { $0.medicationName == "Paracetamol" })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Medicine>()), 0)
    }

    func testDeletingTheBabyRemovesItsMedicinesAndEvents() throws {
        let context = try makeContext()
        let (baby, medicine) = makeMedicine(in: context)
        context.insert(CustomEvent.dose(of: medicine, at: Date()))
        let bath = CustomEvent(time: Date(), type: .bath)
        bath.baby = baby
        context.insert(bath)
        try context.save()

        context.delete(baby)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Medicine>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CustomEvent>()), 0)
    }

    func testInitStoresTheGivenValuesAndACourseIsEndedOnlyOnceEndedAtIsSet() {
        let medicine = Medicine(name: "Vitamin D", intervalMinutes: 1440, doseText: "1 drop")
        XCTAssertEqual(medicine.name, "Vitamin D")
        XCTAssertEqual(medicine.intervalMinutes, 1440)
        XCTAssertEqual(medicine.doseText, "1 drop")
        XCTAssertNil(medicine.note)
        XCTAssertNil(medicine.maxDosesPer24h)
        XCTAssertFalse(medicine.isEnded)
        medicine.endedAt = Date()
        XCTAssertTrue(medicine.isEnded)
    }

    func testTheFormRanges() {
        XCTAssertEqual(Medicine.intervalMinutesRange, 15...2880)
        XCTAssertEqual(Medicine.maxDosesPer24hRange, 1...24)
    }
}

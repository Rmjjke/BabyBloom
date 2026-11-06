import XCTest
import SwiftData
@testable import BabyBloom

#if targetEnvironment(simulator)
/// The medicines fixture: the totals the Maestro flows read, and the two
/// statuses the seed is built to show. `now` is pinned so a run at any hour
/// sees the same doses.
@MainActor
final class SeedScenarioMedicineTests: XCTestCase {

    private let cal = Calendar.current
    private var now: Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 15))!
    }

    private func seeded() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        SeedScenario.medsTwoCourses.seedMedicines(into: context, now: now)
        try context.save()
        return context
    }

    private func medicine(_ name: String, _ context: ModelContext) throws -> Medicine {
        try XCTUnwrap(context.fetch(FetchDescriptor<Medicine>()).first { $0.name == name })
    }

    func testTotals() throws {
        let c = try seeded()
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Baby>()), 1)
        XCTAssertEqual(try c.fetchCount(FetchDescriptor<Medicine>()), 2)
        let events = try c.fetch(FetchDescriptor<CustomEvent>())
        XCTAssertEqual(events.count, 21)
        XCTAssertEqual(events.filter { $0.medicine != nil }.count, 19)
        XCTAssertEqual(try medicine("Paracetamol", c).doses?.count, 13)
        XCTAssertEqual(try medicine("Vitamin D", c).doses?.count, 6)

        let free = events.filter { $0.type == .medication && $0.medicine == nil }
        XCTAssertEqual(free.count, 2)
        XCTAssertEqual(free.filter { $0.medicationName == "Saline drops" }.count, 1)
        XCTAssertEqual(free.filter { $0.medicationName == nil }.count, 1)
    }

    func testEveryDoseCarriesItsMedicinesNameAndDoseText() throws {
        let c = try seeded()
        for medicine in try c.fetch(FetchDescriptor<Medicine>()) {
            for dose in medicine.doses ?? [] {
                XCTAssertEqual(dose.type, .medication)
                XCTAssertEqual(dose.medicationName, medicine.name)
                XCTAssertEqual(dose.medicationDose, medicine.doseText)
            }
        }
    }

    func testParacetamolIsWaitingForTheNextDoseFourHoursOut() throws {
        let c = try seeded()
        let paracetamol = try medicine("Paracetamol", c)
        XCTAssertEqual(paracetamol.maxDosesPer24h, 4)
        XCTAssertEqual(paracetamol.status(now: now),
                       .waiting(lastDose: now.addingTimeInterval(-2 * 3600),
                                until: now.addingTimeInterval(4 * 3600)))
    }

    func testVitaminDIsAllowedSinceTheLastDose() throws {
        let c = try seeded()
        XCTAssertEqual(try medicine("Vitamin D", c).status(now: now),
                       .allowed(lastDose: now.addingTimeInterval(-26 * 3600)))
    }

    /// The history keeps its own rules at any launch hour: no dose is early
    /// against another, no 24 hours is over the maximum, and the count of the
    /// last 24 hours never passes it. A wall-clock history broke all three
    /// after midnight.
    func testEveryDoseIsOnTimeAtAnyLaunchHour() throws {
        for hour in [0, 1, 3, 9, 15, 23] {
            let at = cal.date(bySettingHour: hour, minute: 30, second: 0, of: now)!
            let container = try ModelContainer(
                for: AppSchema.schema,
                configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
            )
            let c = ModelContext(container)
            SeedScenario.medsTwoCourses.seedMedicines(into: c, now: at)
            try c.save()
            for medicine in try c.fetch(FetchDescriptor<Medicine>()) {
                for dose in medicine.doses ?? [] {
                    let result = medicine.check(dose.time, now: at, editing: dose)
                    XCTAssertFalse(result.needsConfirmation, "\(medicine.name) at \(hour):30, dose \(dose.time)")
                }
                if let max = medicine.maxDosesPer24h {
                    XCTAssertLessThanOrEqual(medicine.schedule(now: at).dosesInLast24Hours, max)
                }
            }
            XCTAssertEqual(try medicine("Paracetamol", c).status(now: at),
                           .waiting(lastDose: at.addingTimeInterval(-2 * 3600),
                                    until: at.addingTimeInterval(4 * 3600)))
        }
    }

    func testNoEventIsLaterThanNow() throws {
        let c = try seeded()
        XCTAssertTrue(try c.fetch(FetchDescriptor<CustomEvent>()).allSatisfy { $0.time <= now })
    }
}
#endif

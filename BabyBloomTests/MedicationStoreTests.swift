import XCTest
import SwiftData
@testable import BabyBloom

/// The medication rules against a real store: ending, deleting, editing doses.
@MainActor
final class MedicationStoreTests: XCTestCase {

    private var previousLanguage: SupportedLanguage = .fallback

    override func setUp() async throws {
        try await super.setUp()
        previousLanguage = LocalizationManager.shared.language
        LocalizationManager.shared.setLanguage("en")
    }

    override func tearDown() async throws {
        LocalizationManager.shared.setLanguage(previousLanguage)
        try await super.tearDown()
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        return ModelContext(container)
    }

    private func makeMedicine(_ context: ModelContext, minutes: Int = 360) -> Medicine {
        let baby = Baby(name: "Mia", birthDate: Date(), gender: .female, feedingType: .breast)
        context.insert(baby)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: minutes, doseText: "2.5 ml")
        medicine.baby = baby
        context.insert(medicine)
        return medicine
    }

    @discardableResult
    private func give(_ medicine: Medicine, _ time: Date, in context: ModelContext) -> CustomEvent {
        let dose = CustomEvent.dose(of: medicine, at: time)
        context.insert(dose)
        return dose
    }

    /// Local noon, so doses a few hours either side stay on one calendar day
    /// for `Calendar.current`, which `Medicine.lines` uses.
    private var noon: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
    }

    // MARK: End and resume

    func testEndingACourseKeepsEveryDoseAndResumingReopensIt() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let now = noon
        for hours in [3.0, 2.0] { give(medicine, now.addingTimeInterval(-hours * 3600), in: context) }
        try context.save()

        let ended = now.addingTimeInterval(-60)
        medicine.endedAt = ended
        try context.save()
        XCTAssertEqual(medicine.status(now: now), .ended(ended))
        XCTAssertEqual(medicine.doseEvents.count, 2)

        medicine.endedAt = nil
        try context.save()
        XCTAssertNotEqual(medicine.status(now: now), .ended(ended))
        XCTAssertEqual(medicine.status(now: now),
                       .waiting(lastDose: now.addingTimeInterval(-2 * 3600), until: now.addingTimeInterval(4 * 3600)))
    }

    // MARK: Delete

    func testDeletingAMedicineLeavesItsDosesNamedAndUnlinked() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        for hours in [3.0, 2.0, 1.0] {
            give(medicine, Date().addingTimeInterval(-hours * 3600), in: context)
        }
        try context.save()

        context.delete(medicine)
        try context.save()

        let events = try context.fetch(FetchDescriptor<CustomEvent>())
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events.allSatisfy { $0.medicationName == "Paracetamol" && $0.medicine == nil })
    }

    // MARK: Editing doses

    func testAnEditedDoseTextStaysOnTheEventAndNotOnTheMedicine() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let dose = CustomEvent.dose(of: medicine, at: Date())
        dose.medicationDose = "3 ml"
        context.insert(dose)
        try context.save()

        XCTAssertEqual(dose.medicationName, "Paracetamol")
        XCTAssertEqual(dose.medicationDose, "3 ml")
        XCTAssertTrue(dose.medicine === medicine)
        XCTAssertEqual(medicine.doseText, "2.5 ml")
    }

    func testEditingADosesTimeAndTextKeepsTheNameAfterARename() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let dose = give(medicine, Date().addingTimeInterval(-3600), in: context)
        medicine.name = "Calpol"
        try context.save()

        dose.time = Date().addingTimeInterval(-7200)
        dose.medicationDose = "4 ml"
        try context.save()

        XCTAssertEqual(dose.medicationName, "Paracetamol")
        XCTAssertEqual(dose.medicationDose, "4 ml")
    }

    // MARK: Excluding the dose being edited

    func testTheEditedDoseIsLeftOutOfTheStatusAndTheLines() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let now = noon
        let older = give(medicine, now.addingTimeInterval(-2 * 3600), in: context)
        let newer = give(medicine, now.addingTimeInterval(-1 * 3600), in: context)
        try context.save()

        XCTAssertEqual(medicine.status(now: now, excluding: newer),
                       .waiting(lastDose: older.time, until: now.addingTimeInterval(4 * 3600)))
        XCTAssertEqual(medicine.status(now: now),
                       .waiting(lastDose: newer.time, until: now.addingTimeInterval(5 * 3600)))

        let expected = MedicationFormat.lines(status: .waiting(lastDose: older.time,
                                                               until: now.addingTimeInterval(4 * 3600)),
                                              intervalMinutes: 360, maxPer24h: nil,
                                              dosesInLast24Hours: 1, doseCount: 2, now: now)
        XCTAssertEqual(medicine.lines(now: now, excluding: newer), expected)
    }

    // MARK: doseEvents

    func testDoseEventsAreNewestFirst() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        let now = Date()
        let oldest = give(medicine, now.addingTimeInterval(-3 * 3600), in: context)
        let newest = give(medicine, now.addingTimeInterval(-1 * 3600), in: context)
        let middle = give(medicine, now.addingTimeInterval(-2 * 3600), in: context)
        try context.save()

        XCTAssertTrue(medicine.doseEvents.elementsEqual([newest, middle, oldest], by: ===))
    }

    func testALinkedEventOfAnotherTypeIsNotADose() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, Date().addingTimeInterval(-3600), in: context)
        let bath = CustomEvent(time: Date(), type: .bath)
        bath.medicine = medicine
        context.insert(bath)
        try context.save()

        XCTAssertEqual(medicine.doseEvents.count, 1)
        XCTAssertEqual(medicine.doseTimes().count, 1)
    }

    func testADeletedDoseDisappearsBeforeTheSave() throws {
        let context = try makeContext()
        let medicine = makeMedicine(context)
        give(medicine, Date().addingTimeInterval(-7200), in: context)
        let gone = give(medicine, Date().addingTimeInterval(-3600), in: context)
        try context.save()

        context.delete(gone)

        XCTAssertEqual(medicine.doseEvents.count, 1)
        XCTAssertFalse(medicine.doseEvents.contains { $0 === gone })
    }
}

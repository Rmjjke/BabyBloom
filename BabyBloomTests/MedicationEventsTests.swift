import XCTest
import SwiftData
@testable import BabyBloom

/// Medicines on the Events side: the row text, the cap that doses sit
/// outside, and the CSV columns.
@MainActor
final class MedicationEventsTests: XCTestCase {

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
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    // MARK: Row text

    func testADoseIsTitledByItsMedicineThenDoseAndNote() {
        let row = MedicationFormat.eventRow(typeWord: "Medication", isDose: true,
                                            name: "Paracetamol", dose: "2.5 ml", note: "after food")
        XCTAssertEqual(row.title, "Paracetamol")
        XCTAssertEqual(row.subtitle, "2.5 ml\u{00A0}· after food")
    }

    func testADoseWithNoDoseTextShowsOnlyItsNote() {
        let row = MedicationFormat.eventRow(typeWord: "Medication", isDose: true,
                                            name: "Vitamin D", dose: " ", note: nil)
        XCTAssertEqual(row.title, "Vitamin D")
        XCTAssertEqual(row.subtitle, "")
    }

    func testAFreeTextMedicationKeepsTheTypeWordAndShowsNameAndDose() {
        let row = MedicationFormat.eventRow(typeWord: "Medication", isDose: false,
                                            name: "Nurofen", dose: "2.5 ml", note: "night")
        XCTAssertEqual(row.title, "Medication")
        XCTAssertEqual(row.subtitle, "Nurofen\u{00A0}· 2.5 ml\u{00A0}· night")
    }

    func testAMedicationWithNeitherReadsAsBefore() {
        XCTAssertEqual(MedicationFormat.eventRow(typeWord: "Medication", isDose: false,
                                                 name: nil, dose: nil, note: "drops").subtitle, "drops")
        XCTAssertEqual(MedicationFormat.eventRow(typeWord: "Medication", isDose: false,
                                                 name: nil, dose: nil, note: nil).subtitle, "")
    }

    func testTextIsKeptAsTyped() {
        // A name that happens to be a copy key is shown, not looked up.
        let row = MedicationFormat.eventRow(typeWord: "Medication", isDose: true,
                                            name: "button.save", dose: nil, note: nil)
        XCTAssertEqual(row.title, "button.save")
    }

    // MARK: The cap

    func testDosesHaveTwentyRowsOfTheirOwn() throws {
        let context = try makeContext()
        let now = Date()
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        context.insert(medicine)
        var events: [CustomEvent] = []
        for index in 0..<25 {
            let bath = CustomEvent(time: now.addingTimeInterval(-Double(index) * 3600), type: .bath)
            context.insert(bath)
            events.append(bath)
        }
        for index in 0..<25 {
            let dose = CustomEvent.dose(of: medicine, at: now.addingTimeInterval(-Double(index) * 1800 - 60))
            context.insert(dose)
            events.append(dose)
        }
        try context.save()
        events.sort { $0.time > $1.time }

        let history = EventsHistory(events: events, visits: [], cutoff: nil)

        XCTAssertEqual(history.rows.count, 40, "twenty baths and twenty doses: neither pushes the other out")
        XCTAssertEqual(history.events.visible.filter(\.isDose).count, 20)
        XCTAssertEqual(history.events.visible.filter { !$0.isDose }.count, 20)
        XCTAssertEqual(history.events.deletable.count, 50, "delete-all still reaches every event")
        XCTAssertTrue(history.events.deletesRowsNotShown)
        let dates = history.rows.map(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >), "newest first across both")
    }

    func testDosesKeepTheFreeWindow() throws {
        let context = try makeContext()
        let now = Date()
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
        context.insert(medicine)
        let recent = CustomEvent.dose(of: medicine, at: now.addingTimeInterval(-3600))
        let old = CustomEvent.dose(of: medicine, at: now.addingTimeInterval(-20 * 86_400))
        context.insert(recent)
        context.insert(old)
        try context.save()

        let cutoff = HistoryWindow.cutoff(isPremium: false, now: now)
        let history = EventsHistory(events: [recent, old], visits: [], cutoff: cutoff)

        XCTAssertEqual(history.events.visible.count, 1)
        XCTAssertTrue(history.events.showsLockedFooter)
    }

    func testAnOlderMedicationEventStillCounts() throws {
        let context = try makeContext()
        let now = Date()
        var events: [CustomEvent] = []
        for index in 0..<22 {
            let event = CustomEvent(time: now.addingTimeInterval(-Double(index) * 600), type: .medication)
            event.medicationName = "Saline drops"
            context.insert(event)
            events.append(event)
        }
        try context.save()

        let history = EventsHistory(events: events, visits: [], cutoff: nil)

        XCTAssertEqual(history.rows.count, 20, "an unlinked medication event is not a dose")
    }

    func testTheMedicinesSeedListsEveryEventOnAFreeAccount() throws {
        let context = try makeContext()
        let now = Date()
        SeedScenario.medsTwoCourses.seedMedicines(into: context, now: now)
        try context.save()
        let events = try context.fetch(FetchDescriptor<CustomEvent>(sortBy: [SortDescriptor(\.time, order: .reverse)]))
        XCTAssertEqual(events.count, 21)

        let history = EventsHistory(events: events, visits: [],
                                    cutoff: HistoryWindow.cutoff(isPremium: false, now: now))

        XCTAssertEqual(history.rows.count, 21, "19 doses outside the cap and 2 older events")
    }

    // MARK: CSV

    func testTheEventsCSVCarriesTheNameAndDoseAsLogged() throws {
        let context = try makeContext()
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        context.insert(medicine)
        let dose = CustomEvent.dose(of: medicine, at: Date())
        context.insert(dose)
        let bath = CustomEvent(time: Date(), type: .bath)
        bath.notes = "warm"
        context.insert(bath)
        try context.save()
        // A rename later leaves the record as logged.
        medicine.name = "Calpol"

        let csv = ExportGenerator.csvString(feedings: [], sleeps: [], diapers: [], growths: [],
                                            events: [dose, bath], categories: [.events])
            .first { $0.name == "events.csv" }!.content
        let lines = csv.components(separatedBy: "\n")

        XCTAssertEqual(lines[0], "Date,Time,Type,Medication,Dose,Notes")
        XCTAssertTrue(lines[1].hasSuffix(",Medication,Paracetamol,2.5 ml,"), lines[1])
        XCTAssertTrue(lines[2].hasSuffix(",Bath,,,warm"), lines[2])
    }

    func testTheExportTableNotesCarryTheNameAndDose() {
        let dose = CustomEvent(time: Date(), type: .medication)
        dose.medicationName = "Paracetamol"
        dose.medicationDose = "2.5 ml"
        dose.notes = "night"
        let bare = CustomEvent(time: Date(), type: .medication)
        let bath = CustomEvent(time: Date(), type: .bath)
        bath.notes = "warm"

        XCTAssertEqual(ExportGenerator.eventNote(dose), "Paracetamol\u{00A0}· 2.5 ml\u{00A0}· night")
        XCTAssertNil(ExportGenerator.eventNote(bare))
        XCTAssertEqual(ExportGenerator.eventNote(bath), "warm")
    }
}

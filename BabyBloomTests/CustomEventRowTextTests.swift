import XCTest
import SwiftData
@testable import BabyBloom

/// The row text Events, Home and Recent activity share.
@MainActor
final class CustomEventRowTextTests: XCTestCase {

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

    func testAMedicationShowsItsNameAndDoseAsTyped() {
        let event = CustomEvent(time: Date(), type: .medication)
        event.medicationName = "Nurofen"
        event.medicationDose = "2.5 ml"
        event.notes = "night"
        XCTAssertEqual(event.rowText.title, "Medication")
        XCTAssertEqual(event.rowText.subtitle, "Nurofen\u{00A0}· 2.5 ml\u{00A0}· night")
    }

    func testADoseShowsItsMedicineNameAsTheTitle() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
        let context = ModelContext(container)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        context.insert(medicine)
        let dose = CustomEvent.dose(of: medicine, at: Date())
        context.insert(dose)
        XCTAssertEqual(dose.rowText.title, "Paracetamol")
        XCTAssertEqual(dose.rowText.subtitle, "2.5 ml")
    }

    func testAMoodShowsTheMoodWhenThereIsNoNote() {
        let event = CustomEvent(time: Date(), type: .mood)
        event.mood = .fussy
        XCTAssertEqual(event.rowText.title, "Mood")
        XCTAssertEqual(event.rowText.subtitle, CustomEvent.MoodLevel.fussy.displayName.l)
    }

    func testANoteWinsOverTheMood() {
        let event = CustomEvent(time: Date(), type: .mood)
        event.mood = .calm
        event.notes = "after the walk"
        XCTAssertEqual(event.rowText.subtitle, "after the walk")
    }

    func testABathWithNothingElseHasAnEmptySubtitle() {
        let event = CustomEvent(time: Date(), type: .bath)
        XCTAssertEqual(event.rowText.title, "Bath")
        XCTAssertEqual(event.rowText.subtitle, "")
    }
}

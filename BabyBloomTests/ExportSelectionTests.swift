import XCTest
@testable import BabyBloom

/// The Export button is on exactly when the file would hold something: a
/// ticked category with records in the range.
final class ExportSelectionTests: XCTestCase {

    private func exportable(_ ticked: Set<ExportCategory>,
                            _ counts: [ExportCategory: Int]) -> Set<ExportCategory> {
        ExportSelection.exportable(ticked: ticked) { counts[$0, default: 0] }
    }

    /// A log with an empty category: every box with records unticked leaves
    /// only the empty one ticked, and Export has nothing to write.
    func testOnlyAnEmptyCategoryTickedExportsNothing() {
        let counts: [ExportCategory: Int] = [.feeding: 12, .sleep: 0, .diapers: 8, .growth: 2, .events: 1]
        XCTAssertEqual(exportable([.sleep], counts), [])
    }

    func testNothingTickedOnAFullLogExportsNothing() {
        let counts: [ExportCategory: Int] = [.feeding: 12, .sleep: 5, .diapers: 8, .growth: 2, .events: 1]
        XCTAssertEqual(exportable([], counts), [])
    }

    func testEveryBoxTickedLeavesTheEmptyCategoryOut() {
        let counts: [ExportCategory: Int] = [.feeding: 12, .sleep: 0, .diapers: 8, .growth: 2, .events: 0]
        XCTAssertEqual(exportable(Set(ExportCategory.allCases), counts), [.feeding, .diapers, .growth])
    }

    func testOneTickedCategoryWithRecordsIsEnough() {
        let counts: [ExportCategory: Int] = [.feeding: 0, .sleep: 0, .diapers: 0, .growth: 2, .events: 0]
        XCTAssertEqual(exportable([.growth, .sleep], counts), [.growth])
    }
}

/// The caption under the format tiles names the report's place in the tab's
/// and the row's own words.
final class ExportDoctorHintTests: XCTestCase {

    override func tearDown() {
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    func testTheCaptionNamesThePathInEachLanguage() {
        let expected: [(SupportedLanguage, String, String)] = [
            (.en, "For the doctor's visit: More\u{00A0}› For the pediatrician",
             "For the doctor's visit: More, For the pediatrician"),
            (.ru, "Для приёма у\u{00A0}врача: Ещё\u{00A0}› Для педиатра",
             "Для приёма у\u{00A0}врача: Ещё, Для педиатра"),
            (.es, "Para la consulta médica: Más\u{00A0}› Para el pediatra",
             "Para la consulta médica: Más, Para el pediatra"),
        ]
        for (language, text, spoken) in expected {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(ExportDoctorHint.text, text, "\(language)")
            XCTAssertEqual(ExportDoctorHint.spokenText, spoken, "\(language)")
            // A plain space before the sign would let a line start with it.
            XCTAssertFalse(ExportDoctorHint.text.contains(" ›"), "\(language)")
        }
    }
}

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

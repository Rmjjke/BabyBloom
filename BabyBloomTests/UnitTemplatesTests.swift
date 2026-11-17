import XCTest
@testable import BabyBloom

/// A number and its unit come from one template, so the language decides the
/// space and the order, and the pair never breaks across lines.
@MainActor
final class UnitTemplatesTests: XCTestCase {

    override func tearDown() {
        LocalizationManager.shared.setLanguage("en")
        super.tearDown()
    }

    func testRussianUnitsFollowTheNumberGlued() {
        LocalizationManager.shared.setLanguage("ru")
        XCTAssertEqual(Units.kg("3,4"), "3,4\u{00A0}кг")
        XCTAssertEqual(Units.g("+640"), "+640\u{00A0}г")
        XCTAssertEqual(Units.cm("52,5"), "52,5\u{00A0}см")
        XCTAssertEqual(Units.ml("120"), "120\u{00A0}мл")
    }

    func testEnglishAndSpanishKeepTheSpace() {
        for language in ["en", "es"] {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(Units.kg("3.4"), "3.4\u{00A0}kg", language)
        }
    }

    /// The Japanese, Korean and Chinese templates write the unit with no space.
    func testATemplateWithoutASpaceGetsNone() {
        XCTAssertEqual(Units.format("%@kg", "3.4"), "3.4kg")
        XCTAssertEqual(Units.format("%@ ml", "120"), "120\u{00A0}ml")
    }

    /// Every language carries its own template, so Ukrainian writes its own
    /// unit rather than the English one.
    func testUkrainianWritesItsOwnUnit() {
        LocalizationManager.shared.setLanguage("uk")
        XCTAssertEqual(Units.kg("3,4"), "3,4\u{00A0}кг")
        XCTAssertEqual(Units.ml("120"), "120\u{00A0}мл")
    }
}

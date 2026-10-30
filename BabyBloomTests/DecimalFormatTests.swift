import XCTest
@testable import BabyBloom

/// Measurements used to print a decimal period in Russian because
/// `String(format:)` ignores the app language (Q-001).
final class DecimalFormatTests: XCTestCase {

    private var originalLanguage: SupportedLanguage!

    override func setUp() {
        super.setUp()
        originalLanguage = LocalizationManager.shared.language
    }

    override func tearDown() {
        // The manager is a process-wide singleton: leaking "ru" would skew
        // every later test that reads copy.
        LocalizationManager.shared.setLanguage(originalLanguage.rawValue)
        super.tearDown()
    }

    func testRussianUsesCommaAndKeepsTrailingZero() {
        LocalizationManager.shared.setLanguage("ru")
        XCTAssertEqual(4.29.appDecimal(2), "4,29")
        XCTAssertEqual(52.0.appDecimal(1), "52,0")
    }

    func testEnglishUsesPeriod() {
        LocalizationManager.shared.setLanguage("en")
        XCTAssertEqual(4.29.appDecimal(2), "4.29")
        XCTAssertEqual(52.0.appDecimal(1), "52.0")
    }
}

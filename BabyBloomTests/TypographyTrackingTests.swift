import XCTest
@testable import BabyBloom

/// The Latin-tuned tracking of the type scale: none for the CJK languages.
final class TypographyTrackingTests: XCTestCase {
    func testTrackingIsZeroForCJKAndUnchangedElsewhere() {
        for language in SupportedLanguage.allCases {
            for latin: CGFloat in [-0.4, -0.3, -0.2, 0.3, 4.5] {
                let expected: CGFloat = [.ja, .ko, .zhHant].contains(language) ? 0 : latin
                XCTAssertEqual(BBTheme.Typography.tracking(latin, for: language), expected, "\(language.rawValue)")
            }
        }
    }
}

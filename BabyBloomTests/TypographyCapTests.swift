import XCTest
import SwiftUI
@testable import BabyBloom

/// The app declares a Dynamic Type ceiling of AX2, and for a long time it did
/// not have one: `.dynamicTypeSize(...)` sets the SwiftUI environment, while
/// `BBTheme.Typography` sized its fonts through `UIFontMetrics.scaledValue(for:)`,
/// which reads the DEVICE setting and ignores that environment entirely. A card
/// that measured 442pt at AX2 measured 774pt at AX5 under the "cap".
///
/// These tests pin the cap on `scaledPointSize`, not on a rendered view, for two
/// reasons: a `Font` will not give its point size back, and the device content
/// size cannot be moved from inside the test process (only
/// `xcrun simctl ui booted content_size` moves it). The injected `category`
/// parameter is what makes the cap checkable at a size the host is not running
/// at; the `min` against AX2 that it exercises is the same line production uses.
final class TypographyCapTests: XCTestCase {

    private typealias Typography = BBTheme.Typography

    /// Every size on the D1 scale, with the text style each one is declared
    /// relative to. Kept in step with `BBTheme.Typography` by hand — a new
    /// entry there wants a line here.
    private static let scale: [(name: String, size: CGFloat, style: UIFont.TextStyle)] = [
        ("largeTitle", 30, .title1),
        ("title1", 26, .title2),
        ("title2", 21, .title3),
        ("title3", 18, .headline),
        ("body", 17, .body),
        ("callout", 16, .callout),
        ("caption", 12, .caption1),
        ("metric", 28, .title2),
    ]

    // MARK: - The cap holds

    func testAccessibilitySizesAboveTheCapAllRenderAtTheCapSize() {
        let above: [UIContentSizeCategory] = [
            .accessibilityExtraLarge,             // AX3
            .accessibilityExtraExtraLarge,        // AX4
            .accessibilityExtraExtraExtraLarge,   // AX5
        ]
        for entry in Self.scale {
            let capped = Typography.scaledPointSize(entry.size, relativeTo: entry.style,
                                                    for: Typography.maxContentSizeCategory)
            for category in above {
                XCTAssertEqual(
                    Typography.scaledPointSize(entry.size, relativeTo: entry.style, for: category),
                    capped,
                    "\(entry.name) grew past the AX2 cap at \(category.rawValue)"
                )
            }
        }
    }

    /// The regression this whole task exists for, in one number: uncapped, the
    /// AX5 point size is far above AX2's. If this assertion ever fails because
    /// the two are equal, the cap is being enforced by accident somewhere else
    /// and the `min` above is no longer proving anything.
    func testTheCapIsActuallyDoingWorkAtAX5() {
        let metrics = UIFontMetrics(forTextStyle: .body)
        let uncappedAX5 = metrics.scaledValue(
            for: 17,
            compatibleWith: UITraitCollection(
                preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        )
        let capped = Typography.scaledPointSize(17, relativeTo: .body,
                                                for: .accessibilityExtraExtraExtraLarge)
        XCTAssertGreaterThan(uncappedAX5, capped)
        XCTAssertEqual(capped, Typography.scaledPointSize(17, relativeTo: .body,
                                                          for: Typography.maxContentSizeCategory))
    }

    // MARK: - Nothing below the cap moved

    func testSizesAtOrBelowTheCapAreUntouched() {
        let below: [UIContentSizeCategory] = [
            .extraSmall, .small, .medium, .large, .extraLarge,
            .extraExtraLarge, .extraExtraExtraLarge,
            .accessibilityMedium,                 // AX1
            .accessibilityLarge,                  // AX2 — the cap itself
        ]
        for entry in Self.scale {
            let metrics = UIFontMetrics(forTextStyle: entry.style)
            for category in below {
                let traits = UITraitCollection(preferredContentSizeCategory: category)
                XCTAssertEqual(
                    Typography.scaledPointSize(entry.size, relativeTo: entry.style, for: category),
                    metrics.scaledValue(for: entry.size, compatibleWith: traits),
                    "\(entry.name) changed at \(category.rawValue), where the cap must not bind"
                )
            }
        }
    }

    /// At the default "Large" setting the D1 scale must render at its literal
    /// values — that property predates the cap and is what makes the design
    /// mockups match the app.
    func testDefaultSettingRendersTheLiteralScale() {
        for entry in Self.scale {
            XCTAssertEqual(
                Typography.scaledPointSize(entry.size, relativeTo: entry.style, for: .large),
                entry.size,
                accuracy: 0.01,
                "\(entry.name) is no longer its D1 value at the default content size"
            )
        }
    }

    // MARK: - The two ceilings cannot drift apart again

    func testSwiftUICeilingAndFontCeilingAreTheSameSize() {
        XCTAssertEqual(Typography.maxDynamicTypeSize, .accessibility2)
        XCTAssertEqual(Typography.maxContentSizeCategory, .accessibilityLarge)
        XCTAssertEqual(DynamicTypeSize(Typography.maxContentSizeCategory),
                       Typography.maxDynamicTypeSize)
    }
}

import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The paywall's title breaks between words, never inside one, and is never
/// cut: it steps from title1 to title2 and title3 while its widest word
/// misses the hero's line, as the screen heading does, and keeps every line
/// it needs.
///
/// Every shipped language runs, and both pseudo-languages. en, ru and es keep
/// title1 at Large, so the paywall looks as it did there.
@MainActor
final class PremiumHeroTitleFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let key = "onboarding.premium.title"
    private let widths: [CGFloat] = [320, 375, 402, 440]
    private let sizes: [UIContentSizeCategory] = [.large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                                  .accessibilityMedium, .accessibilityLarge]

    /// The title's steps, as `BBTheme.Typography` sets them: the base size,
    /// the style it scales with and the tuned Latin tracking.
    private let steps: [(size: CGFloat, style: UIFont.TextStyle, tracking: CGFloat)] = [
        (26, .title2, -0.3), (21, .title3, -0.2), (18, .headline, 0),
    ]

    /// Places a language's title is known not to fit even at title3, keyed
    /// "<width> <size>[ bold]".
    private static let knownMisses: [KnownMiss] = []

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    // MARK: - By arithmetic, at every size

    /// The hero's line is the screen less the 24-pt padding a side; some step
    /// holds the widest word with 8 pt to spare in every language, at every
    /// size up to the AX2 cap, Bold Text off and on.
    func testSomeStepHoldsTheWidestWordAtEverySize() throws {
        for language in FitLanguage.all {
            language.apply()
            let title = key.l
            for width in widths {
                for size in sizes {
                    for bold in [false, true] {
                        let step = chosenStep(title, line: line(width), size: size, bold: bold)
                        let qualifier = "\(Int(width)) \(sizeName(size))\(bold ? " bold" : "")"
                        let miss = step == nil
                            ? "widest unit \(points(widest(title, steps.count - 1, size, bold))) at title3 "
                                + "in \(points(line(width)))"
                            : nil
                        check(language, qualifier, miss)
                    }
                }
            }
        }
    }

    /// en, ru and es keep title1 at Large on every width: the look of the
    /// paywall there is unchanged.
    func testEnglishRussianAndSpanishKeepTitle1AtLarge() {
        for language in [FitLanguage.real(.en), .real(.ru), .real(.es)] {
            language.apply()
            for width in widths {
                for bold in [false, true] {
                    XCTAssertEqual(chosenStep(key.l, line: line(width), size: .large, bold: bold), 0,
                                   "\(language) \(Int(width))\(bold ? " bold" : ""): the title left title1")
                }
            }
        }
    }

    // MARK: - Hosted, at the device's size

    /// The hero as the paywalls stack it, at the device's text size: the
    /// title is set in the step the arithmetic chooses, wider than its widest
    /// word, and as tall as that step needs at the line, so no line is cut.
    /// In a ZStack over its gradient the hero was proposed less than its
    /// ideal height, and the title fell to one cut line («[[Bííttýý] Pré…»,
    /// en-XA at AX2 on 320). Run it at AX2 too (`content_size accessibility-large`).
    func testTheHostedTitleIsWholeInTheStepItChooses() throws {
        let size = UIApplication.shared.preferredContentSizeCategory
        for language in FitLanguage.all {
            for width in [CGFloat(320), 402] {
                for bold in [false, true] {
                    language.apply()
                    let title = key.l
                    let line = line(width)
                    let name = "\(language) \(Int(width)) \(sizeName(size))\(bold ? " bold" : "")"
                    let view = ScrollView {
                        VStack(spacing: 0) {
                            PremiumHero()
                            Color.clear.frame(height: 300)
                        }
                    }
                    .environment(\.locale, language.environmentLocale)
                    let root = try accessibility.host(view, size: CGSize(width: width, height: 900), bold: bold)
                    let text = try XCTUnwrap(accessibility.elements(root).first { $0.label == title },
                                             "\(name): no title in \(accessibility.elements(root))")
                    accessibility.close()
                    guard let step = chosenStep(title, line: line, size: size, bold: bold) else { continue }
                    let word = widest(title, step, size, bold)
                    XCTAssertGreaterThanOrEqual(text.frame.width + 0.5, word,
                                                "\(name): the widest unit \(points(word)) breaks in \(text)")
                    let needed = height(title, step, size, bold, in: line)
                    XCTAssertEqual(text.frame.height, needed, accuracy: 1,
                                   "\(name): not set whole at step \(step) (\(points(needed)) tall): \(text)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func line(_ width: CGFloat) -> CGFloat {
        width - 2 * BBTheme.Spacing.lg
    }

    /// The first step whose widest unit fits the line with the heading's
    /// spare; nil when none does.
    private func chosenStep(_ title: String, line: CGFloat, size: UIContentSizeCategory, bold: Bool) -> Int? {
        steps.indices.first { widest(title, $0, size, bold) + BBScreenTitleFit.spare <= line }
    }

    private func text(_ string: String, _ step: Int, _ size: UIContentSizeCategory) -> Text {
        let style = steps[step]
        return Text(string)
            .font(.system(size: BBTheme.Typography.scaledPointSize(style.size, relativeTo: style.style, for: size),
                          weight: .semibold, design: .default))
            .tracking(BBTheme.Typography.tracking(style.tracking))
    }

    private func widest(_ title: String, _ step: Int, _ size: UIContentSizeCategory, _ bold: Bool) -> CGFloat {
        title.lineBreakUnits.map { unit in
            fitting(text(unit, step, size).fixedSize(), bold, in: CGSize(width: 4000, height: 4000)).width
        }.max() ?? 0
    }

    private func height(_ title: String, _ step: Int, _ size: UIContentSizeCategory, _ bold: Bool,
                        in line: CGFloat) -> CGFloat {
        fitting(text(title, step, size), bold, in: CGSize(width: line, height: 4000)).height
    }

    private func fitting<V: View>(_ view: V, _ bold: Bool, in size: CGSize) -> CGSize {
        UIHostingController(rootView: view
            .environment(\.legibilityWeight, bold ? .bold : .regular)
            .environment(\.locale, LocalizationManager.shared.language.environmentLocale))
            .sizeThatFits(in: size)
    }

    /// Fails on a miss, unless the key is listed: then on no miss left.
    private func check(_ language: FitLanguage, _ qualifier: String, _ miss: String?,
                       file: StaticString = #filePath, line: UInt = #line) {
        if KnownMiss.listed(Self.knownMisses, language, qualifier) {
            XCTAssertNotNil(miss, "\(language) \(qualifier) fits now: remove its known-miss row", file: file, line: line)
        } else if let miss {
            XCTFail("\(language) \(key) \(qualifier): \(miss)", file: file, line: line)
        }
    }

    private func sizeName(_ size: UIContentSizeCategory) -> String {
        switch size {
        case .large: "Large"
        case .accessibilityMedium: "AX1"
        case .accessibilityLarge: "AX2"
        default: size.rawValue
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }
}

import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The progress card's figure and glyph grow with the text as its title does,
/// and the figure stands beside the title only while every word of the title
/// keeps whole next to it; otherwise it goes under the title's text.
///
/// The faces take their size from `category`, so the sizes above Large are
/// built here without moving the device; the row's branch reads the SwiftUI
/// size, set alongside. 256 pt is the card's inner width in a 320-pt window.
@MainActor
final class ProgressCardScaleTests: XCTestCase {

    private typealias Face = BBProgressCard.Face
    private typealias Card = (title: String, icon: String, figures: [String])

    private static let sizes: [(category: UIContentSizeCategory, size: DynamicTypeSize)] = [
        (.large, .large), (.extraLarge, .xLarge), (.extraExtraLarge, .xxLarge),
        (.extraExtraExtraLarge, .xxxLarge), (.accessibilityMedium, .accessibility1),
        (.accessibilityLarge, .accessibility2),
    ]
    private static let width: CGFloat = 256

    // MARK: - Faces

    /// The platform scales each size on its own curve and rounds it to the
    /// pixel, so 13 : 14 holds to within half a point, not exactly.
    func testFigureAndGlyphKeepTheirRatioToTheTitleAtEverySize() {
        for (category, _) in Self.sizes {
            let title = Face.title.pointSize(for: category)
            XCTAssertEqual(Face.figure.pointSize(for: category), title * 13 / 14, accuracy: 0.5, category.rawValue)
            XCTAssertEqual(Face.icon.pointSize(for: category), title, accuracy: 0.01, category.rawValue)
        }
    }

    func testFacesAreTheBuiltOnesAtLargeAndFollowBodyUpToAX2() {
        XCTAssertEqual(Face.title.pointSize(for: .large), 14, accuracy: 0.001)
        XCTAssertEqual(Face.figure.pointSize(for: .large), 13, accuracy: 0.001)
        XCTAssertEqual(Face.icon.pointSize(for: .large), 14, accuracy: 0.001)

        let body = UIFontMetrics(forTextStyle: .body)
        let ax2 = UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)
        XCTAssertEqual(Face.title.pointSize(for: .accessibilityLarge),
                       body.scaledValue(for: 14, compatibleWith: ax2), accuracy: 0.001)
        XCTAssertEqual(Face.figure.pointSize(for: .accessibilityLarge),
                       body.scaledValue(for: 13, compatibleWith: ax2), accuracy: 0.001)
        // About 1.8 × Large on iOS 26; a fixed face would stay at 1.
        XCTAssertGreaterThan(Face.figure.pointSize(for: .accessibilityLarge), 13 * 1.7)

        let figures = Self.sizes.map { Face.figure.pointSize(for: $0.category) }
        for (smaller, larger) in zip(figures, figures.dropFirst()) {
            XCTAssertLessThan(smaller, larger)
        }
        XCTAssertEqual(Face.figure.pointSize(for: .accessibilityExtraLarge),
                       Face.figure.pointSize(for: .accessibilityLarge), accuracy: 0.001)
    }

    /// The fonts themselves, not only their sizes: the drawn line and glyph
    /// widen with the face, a little less than its 1.8 (optical sizes).
    func testTheDrawnFigureAndGlyphGrowWithTheSize() {
        let line = "20 h 40 min of 14 h"
        let lineL = idealWidth(Text(line).font(Face.figure.font(for: .large)))
        let lineAX2 = idealWidth(Text(line).font(Face.figure.font(for: .accessibilityLarge)))
        XCTAssertGreaterThan(lineAX2 / lineL, 1.6, "\(lineL) → \(lineAX2)")

        let glyphL = idealWidth(Image(systemName: "moon.fill").font(Face.icon.font(for: .large)))
        let glyphAX2 = idealWidth(Image(systemName: "moon.fill").font(Face.icon.font(for: .accessibilityLarge)))
        XCTAssertGreaterThan(glyphAX2 / glyphL, 1.6, "\(glyphL) → \(glyphAX2)")
    }

    // MARK: - Beside or under

    /// Every progress card in each language, Regular and Bold, Large to AX2,
    /// with the widest figure it can show: under the title, every word of the
    /// title and of the figure fits 256 (a figure longer than the line wraps
    /// between its words); beside wherever the row's width fits, and at Large
    /// always, as before the figure scaled. The margins print for the record.
    func testEveryWordKeepsWholeBesideOrUnderAtEverySize() throws {
        var report: [String] = []
        for lang in ["ru", "en", "es"] {
            try inLanguage(lang) {
                for bold in [false, true] {
                    for (category, size) in Self.sizes {
                        for (index, card) in cards().enumerated() {
                            for figure in card.figures {
                                let label = "\(lang) \(bold ? "B" : "R") \(size) «\(card.title)» «\(figure)»"
                                for word in figure.split(separator: " ") {
                                    let widest = idealWidth(progressRow(card, String(word), category, .accessibility1, bold: bold))
                                    XCTAssertLessThanOrEqual(widest, Self.width, "under: «\(word)» misses, \(label)")
                                }
                                let under = idealWidth(progressRow(card, figure, category, .accessibility1, bold: bold))
                                let lines = under <= Self.width ? "one line" : "wraps between words"
                                guard !size.isAccessibilitySize else {
                                    report.append("\(label) under \(f(under)) \(lines)")
                                    continue
                                }
                                let beside = idealWidth(progressRow(card, figure, category, size, bold: bold))
                                if size == .large {
                                    XCTAssertLessThanOrEqual(beside, Self.width, "beside at Large, \(label)")
                                }
                                var line = "\(label) beside \(f(beside)) margin \(f(Self.width - beside, sign: true))"
                                    + " under \(f(under)) → \(beside <= Self.width ? "beside" : "under")"
                                // The sleep card draws the moon; the heart is the widest glyph of the three.
                                if index == 1 {
                                    let heart = idealWidth(progressRow(card, figure, category, size, bold: bold, icon: "heart.fill"))
                                    line += " (heart \(f(Self.width - heart, sign: true)))"
                                }
                                report.append(line)
                            }
                        }
                    }
                }
            }
        }
        print(report.map { "PROGRESS-FIT " + $0 }.joined(separator: "\n"))
    }

    /// The branch turns at the width measured above: a point short of it the
    /// figure stands under the title, a point past it beside. One-word titles,
    /// so beside is one line and plainly the lower of the two.
    func testTheRowTurnsAtItsBesideWidth() throws {
        for lang in ["ru", "en", "es"] {
            try inLanguage(lang) {
                for bold in [false, true] {
                    for (category, size) in Self.sizes where !size.isAccessibilitySize {
                        for card in cards().prefix(2) {
                            for figure in card.figures {
                                let label = "\(lang) \(bold ? "B" : "R") \(size) «\(card.title)» «\(figure)»"
                                let row = progressRow(card, figure, category, size, bold: bold)
                                let under = progressRow(card, figure, category, .accessibility1, bold: bold)
                                let beside = idealWidth(row)
                                XCTAssertEqual(height(row, width: beside - 1), height(under, width: beside - 1),
                                               accuracy: 0.5, "short of its width, \(label)")
                                XCTAssertLessThan(height(row, width: beside + 1), height(under, width: beside + 1) - 1,
                                                  "past its width, \(label)")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cards

    /// The four progress cards in the app's order (Home's three, then the
    /// diaper screen's daily norm), each with its widest figures: a count well
    /// past its target, and the sleep lines that measured widest.
    private func cards() -> [Card] {
        let count = BBProgressCard.valueText(current: 40, target: 30, measure: .count)
        let sleep = [BBProgressCard.valueText(current: 20 + 40.0 / 60, target: 14, measure: .hours),
                     BBProgressCard.valueText(current: 16 + 20.0 / 60, target: 16, measure: .hours)]
        return [("tab.feeding".l, "heart.fill", [count]),
                ("tab.sleep".l, "moon.fill", sleep),
                ("progress.wet_nappies".l, "drop.fill", [count]),
                ("stat.daily_norm".l, "checkmark.circle.fill", [count])]
    }

    private func progressRow(_ card: Card, _ figure: String, _ category: UIContentSizeCategory,
                             _ size: DynamicTypeSize, bold: Bool, icon: String? = nil) -> some View {
        BBProgressCard.Row(icon: icon ?? card.icon, color: .primary, title: card.title,
                           figure: figure, category: category)
            .environment(\.dynamicTypeSize, size)
            .environment(\.legibilityWeight, bold ? .bold : .regular)
    }

    // MARK: - Measuring

    private func inLanguage(_ lang: String, _ body: () throws -> Void) throws {
        let original = LocalizationManager.shared.language
        defer { LocalizationManager.shared.setLanguage(original) }
        LocalizationManager.shared.setLanguage(lang)
        try body()
    }

    private func idealWidth<V: View>(_ view: V) -> CGFloat {
        UIHostingController(rootView: view.fixedSize())
            .sizeThatFits(in: CGSize(width: 4000, height: 4000)).width
    }

    private func height<V: View>(_ view: V, width: CGFloat) -> CGFloat {
        UIHostingController(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true))
            .sizeThatFits(in: CGSize(width: width, height: 4000)).height
    }

    private func f(_ value: CGFloat, sign: Bool = false) -> String {
        String(format: sign ? "%+.1f" : "%.1f", Double(value))
    }
}

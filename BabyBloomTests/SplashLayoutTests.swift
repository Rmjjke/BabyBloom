import XCTest
import SwiftUI
@testable import BabyBloom

/// Where the splash puts its art and its words, window by window.
final class SplashLayoutTests: XCTestCase {

    private struct Window {
        let name: String
        let size: CGSize
        let insets: EdgeInsets
    }

    private static func window(_ name: String, _ width: CGFloat, _ height: CGFloat,
                               top: CGFloat = 0, side: CGFloat = 0, bottom: CGFloat = 0) -> Window {
        Window(name: name, size: CGSize(width: width, height: height),
               insets: EdgeInsets(top: top, leading: side, bottom: bottom, trailing: side))
    }

    /// The words' fitting size per language: the wordmark over the tagline row.
    private let stacks: [String: CGSize] = [
        "en": CGSize(width: 261.5, height: 83),
        "ru": CGSize(width: 219.6, height: 83),
        "es": CGSize(width: 256.1, height: 83),
    ]

    /// Windows where the words lie on the field under the figure, as they always have.
    private let today: [Window] = [
        window("iPhone 17 portrait", 402, 874, top: 62, bottom: 34),
        window("Pro Max portrait", 440, 956, top: 62, bottom: 34),
        window("SE portrait", 375, 667, top: 20),
        window("320 portrait", 320, 568, top: 20),
        window("iPad 11 portrait", 834, 1210, top: 24, bottom: 20),
        window("iPad 13 portrait", 1032, 1376, top: 24, bottom: 20),
        window("iPad 11 split 1/2", 600, 834, top: 24, bottom: 20),
        window("iPad 13 split 1/2", 683, 1032, top: 24, bottom: 20),
        window("iPad 13 split 1/3", 375, 1032, top: 24, bottom: 20),
    ]

    /// Windows where the filled art would put the words on its figure.
    private let beside: [Window] = [
        window("iPhone 17 landscape", 874, 402, side: 62, bottom: 21),
        window("Pro Max landscape", 956, 440, side: 62, bottom: 21),
        window("SE landscape", 667, 375),
        window("320 landscape", 568, 320),
        window("iPad 11 landscape", 1210, 834, top: 24, bottom: 20),
        window("iPad 11 split 2/3", 825, 834, top: 24, bottom: 20),
        window("iPad 13 landscape", 1376, 1032, top: 24, bottom: 20),
        window("iPad 13 split 2/3", 991, 1032, top: 24, bottom: 20),
    ]

    private func layout(_ w: Window, _ lang: String, rightToLeft: Bool = false) -> SplashLayout {
        SplashLayout(size: w.size, insets: w.insets, stack: stacks[lang]!, rightToLeft: rightToLeft)
    }

    private func scale(_ l: SplashLayout) -> CGFloat { l.artFrame.width / SplashLayout.art.width }

    private func figure(_ l: SplashLayout) -> CGRect {
        let s = scale(l), f = SplashLayout.figure
        return CGRect(x: l.artFrame.minX + f.minX * s, y: l.artFrame.minY + f.minY * s,
                      width: f.width * s, height: f.height * s)
    }

    private func stack(_ l: SplashLayout, _ lang: String) -> CGRect {
        let size = stacks[lang]!
        return CGRect(x: l.stackCenter.x - size.width / 2, y: l.stackCenter.y - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func safe(_ w: Window) -> CGRect {
        CGRect(x: w.insets.leading, y: w.insets.top,
               width: w.size.width - w.insets.leading - w.insets.trailing,
               height: w.size.height - w.insets.top - w.insets.bottom)
    }

    func testTodaysLayoutWhereTheWordsClearTheFigure() {
        for w in today {
            for lang in stacks.keys {
                let l = layout(w, lang)
                let fill = max(w.size.width / 941, w.size.height / 1362)
                XCTAssertFalse(l.isBeside, "\(w.name) \(lang)")
                XCTAssertEqual(l.artFrame.width, 941 * fill, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertEqual(l.artFrame.height, 1362 * fill, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertEqual(l.artFrame.midX, w.size.width / 2, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertEqual(l.artFrame.midY, w.size.height / 2, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertEqual(l.stackCenter.x, w.size.width / 2, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertEqual(l.stackCenter.y, 0.82 * w.size.height, accuracy: 0.001, "\(w.name) \(lang)")
                XCTAssertFalse(l.fadesLeft || l.fadesRight, "\(w.name) \(lang)")
            }
        }
    }

    func testBesideNumbersInEnglish() throws {
        // name: scale; the stack's left, right, top and bottom edges
        let expected: [String: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
            "iPhone 17 landscape": (0.5303, 470.46, 731.96, 149, 232),
            "Pro Max landscape": (0.5908, 528.37, 789.87, 168, 251),
            "SE landscape": (0.5207, 364.29, 625.79, 146, 229),
            // Width-bound: the words end on the trailing margin.
            "320 landscape": (0.4052, 282.50, 568 - 24, 118.5, 201.5),
            "iPad 11 landscape": (1.1815, 820.49, 1081.99, 377.5, 460.5),
            "iPad 11 split 2/3": (0.8649, 539.50, 825 - 24, 377.5, 460.5),
            "iPad 13 landscape": (1.4623, 981.96, 1243.46, 476.5, 559.5),
            "iPad 13 split 2/3": (1.0531, 675.10, 936.60, 476.5, 559.5),
        ]
        for w in beside {
            let (s, left, right, top, bottom) = try XCTUnwrap(expected[w.name])
            let l = layout(w, "en")
            let box = stack(l, "en")
            XCTAssertTrue(l.isBeside, w.name)
            XCTAssertEqual(scale(l), s, accuracy: 0.0001, w.name)
            XCTAssertEqual(box.minX, left, accuracy: 0.01, w.name)
            XCTAssertEqual(box.maxX, right, accuracy: 0.01, w.name)
            XCTAssertEqual(box.minY, top, accuracy: 0.01, w.name)
            XCTAssertEqual(box.maxY, bottom, accuracy: 0.01, w.name)
        }
        // On a full iPad 13 the figure fits at the fill scale: the art is drawn as today.
        let ipad = try XCTUnwrap(beside.first { $0.name == "iPad 13 landscape" })
        XCTAssertEqual(scale(layout(ipad, "en")), max(1376.0 / 941, 1032.0 / 1362), accuracy: 0.000_001)
    }

    func testBesideKeepsTheWordsOffTheFigureInEveryLanguage() {
        for w in beside {
            for lang in stacks.keys {
                let l = layout(w, lang)
                let fig = figure(l), box = stack(l, lang), safe = safe(w)
                let name = "\(w.name) \(lang)"
                XCTAssertTrue(l.isBeside, name)
                XCTAssertLessThanOrEqual(scale(l), max(w.size.width / 941, w.size.height / 1362) + 0.000_001, name)
                XCTAssertGreaterThanOrEqual(box.minX - fig.maxX, 32 - 0.001, name)
                XCTAssertEqual(box.midY, fig.midY, accuracy: 0.001, name)
                for rect in [fig, box] {
                    XCTAssertGreaterThanOrEqual(rect.minX - safe.minX, 24 - 0.001, name)
                    XCTAssertGreaterThanOrEqual(safe.maxX - rect.maxX, 24 - 0.001, name)
                    XCTAssertGreaterThanOrEqual(rect.minY - safe.minY, 24 - 0.001, name)
                    XCTAssertGreaterThanOrEqual(safe.maxY - rect.maxY, 24 - 0.001, name)
                }
                XCTAssertLessThanOrEqual(l.artFrame.minY, 0.001, name)
                XCTAssertGreaterThanOrEqual(l.artFrame.maxY, w.size.height - 0.001, name)
                XCTAssertEqual(l.fadesLeft, l.artFrame.minX > 0, name)
                XCTAssertEqual(l.fadesRight, l.artFrame.maxX < w.size.width, name)
            }
        }
    }

    func testRightToLeftPutsTheFigureOnTheRight() {
        for w in beside {
            let ltr = layout(w, "en"), rtl = layout(w, "en", rightToLeft: true)
            let width = w.size.width
            XCTAssertEqual(scale(rtl), scale(ltr), accuracy: 0.000_001, w.name)
            XCTAssertEqual(rtl.stackCenter.x, width - ltr.stackCenter.x, accuracy: 0.001, w.name)
            XCTAssertEqual(rtl.stackCenter.y, ltr.stackCenter.y, accuracy: 0.001, w.name)
            XCTAssertEqual(figure(rtl).minX, width - figure(ltr).maxX, accuracy: 0.001, w.name)
            XCTAssertEqual(figure(rtl).minY, figure(ltr).minY, accuracy: 0.001, w.name)
            XCTAssertEqual(rtl.fadesLeft, rtl.artFrame.minX > 0, w.name)
            XCTAssertEqual(rtl.fadesRight, rtl.artFrame.maxX < width, w.name)
        }
    }

    func testSideFadeIsOpaqueOverTheFigure() {
        // The fade's ramps end at the figure's edges, so the figure is never faded.
        let stops = SplashLayout.fadeStops(left: true, right: true)
        let start = SplashLayout.figure.minX / SplashLayout.art.width
        let end = SplashLayout.figure.maxX / SplashLayout.art.width
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.first?.opacity, 0)
        XCTAssertEqual(stops.last?.location, 1)
        XCTAssertEqual(stops.last?.opacity, 0)
        let opaque = stops.filter { $0.opacity == 1 }.map(\.location)
        XCTAssertEqual(opaque.count, 2)
        XCTAssertEqual(opaque[0], start, accuracy: 0.000_001)
        XCTAssertEqual(opaque[1], end, accuracy: 0.000_001)
        XCTAssertEqual(stops.map(\.opacity), [0, 0.15625, 0.5, 0.84375, 1, 1, 0.84375, 0.5, 0.15625, 0])
        // No side in the window: nothing fades.
        XCTAssertEqual(SplashLayout.fadeStops(left: false, right: false).map(\.opacity), [1, 1])
    }
}

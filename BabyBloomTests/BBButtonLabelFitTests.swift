import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// A button label's shape comes from its words' widths. Its ideal width is the
/// glyph and the widest word on one line, as measured for the design (within
/// 1 pt); the glyph goes when that misses the room, and a word wider than the
/// whole room sets the label at the AX1 size, then at xxxLarge's.
@MainActor
final class BBButtonLabelFitTests: XCTestCase {

    /// A 272-pt button (a 320-pt screen) less md 16 each side; 295 on 375.
    private let small: CGFloat = 240
    private let regular: CGFloat = 295

    private let trial = "Попробовать 7\u{00A0}дн. бесплатно"
    private let notify = "Включить уведомления"
    private let activar = "Activar notificaciones"
    private let export = "Экспортировать"
    private let tracker = "Создать мой трекер"

    /// CoreText widths: the semibold label and glyph, and with Bold Text the
    /// heavy ones, the weight SwiftUI sets a semibold font at under Bold Text
    /// (not bold: «Экспортировать» at Large is 140.5 bold, 146.4 heavy, and
    /// draws 146.7).
    func testTheIdealWidthIsTheGlyphAndTheWidestWord() {
        let cases: [(title: String, icon: String?, size: UIContentSizeCategory, regular: CGFloat, bold: CGFloat)] = [
            (trial, "arrow.right", .large, 137.3, 146.1),
            (trial, "arrow.right", .extraExtraExtraLarge, 177.4, 188.6),
            (trial, "arrow.right", .accessibilityMedium, 206.4, 219.4),
            (trial, "arrow.right", .accessibilityLarge, 240.3, 256.4),
            (notify, "bell.fill", .large, 138.8, 148.4),
            (notify, "bell.fill", .accessibilityLarge, 242.0, 259.6),
            (activar, "bell.fill", .accessibilityLarge, 241.0, 260.1),
            (tracker, "arrow.right", .large, 97.1, 103.3),
            (tracker, "arrow.right", .accessibilityLarge, 168.4, 179.9),
            (export, "square.and.arrow.up", .large, 164.4, 174.4),
            (export, "square.and.arrow.up", .accessibilityMedium, 246.5, 263.1),
            (export, "square.and.arrow.up", .accessibilityLarge, 287.5, 306.8),
            (export, nil, .large, 136.4, 146.4),
            (export, nil, .accessibilityMedium, 207.5, 223.1),
            (export, nil, .accessibilityLarge, 243.5, 261.8),
        ]
        for c in cases {
            let name = "«\(c.title)» \(c.icon ?? "no glyph") at \(c.size.rawValue)"
            let label = BBButtonLabel(title: c.title, icon: c.icon, category: c.size)
            XCTAssertEqual(idealWidth(label), c.regular, accuracy: 1, name)
            XCTAssertEqual(idealWidth(label.environment(\.legibilityWeight, .bold)), c.bold, accuracy: 1,
                           "\(name), Bold Text")
        }
    }

    /// The glyph stays while it and the widest word fit one line, and goes
    /// before a word would break.
    func testTheGlyphGoesBeforeAWordBreaks() {
        for size in [UIContentSizeCategory.large, .accessibilityMedium] {
            let kept = fitted(notify, "bell.fill", size, bold: false, in: small).width
            let bare = fitted(notify, nil, size, bold: false, in: small).width
            XCTAssertGreaterThan(kept - bare, 20, "«\(notify)» lost its glyph at \(size.rawValue)")
        }
        let dropped: [(title: String, icon: String, size: UIContentSizeCategory, bold: Bool)] = [
            (trial, "arrow.right", .accessibilityLarge, true),
            (notify, "bell.fill", .accessibilityLarge, true),
            (activar, "bell.fill", .accessibilityLarge, true),
            (export, "square.and.arrow.up", .accessibilityMedium, false),
            (export, "square.and.arrow.up", .accessibilityMedium, true),
        ]
        for c in dropped {
            let shown = fitted(c.title, c.icon, c.size, bold: c.bold, in: small)
            let bare = fitted(c.title, nil, c.size, bold: c.bold, in: small)
            XCTAssertEqual(shown.width, bare.width, accuracy: 0.5,
                           "«\(c.title)» kept its glyph at \(c.size.rawValue)\(c.bold ? ", Bold Text" : "")")
            XCTAssertEqual(shown.height, bare.height, accuracy: 0.5, c.title)
        }
        // «Экспортировать» at AX1 is the word alone at its own size.
        XCTAssertEqual(fitted(export, "square.and.arrow.up", .accessibilityMedium, bold: false, in: small).width,
                       207.5, accuracy: 1)
    }

    /// «Экспортировать» at AX2 is wider than a 320-pt screen's whole room, so it
    /// is set at the AX1 size on one line; on 375 it fits with its glyph, and
    /// with Bold Text there without it. Where even the AX1 size misses, the
    /// xxxLarge size takes over.
    func testOnlyAWordWiderThanTheRoomStepsDown() {
        let stepped = fitted(export, "square.and.arrow.up", .accessibilityLarge, bold: false, in: small)
        let atAX1 = fitted(export, nil, .accessibilityMedium, bold: false, in: small)
        XCTAssertEqual(stepped.width, 207.5, accuracy: 1)
        XCTAssertEqual(stepped.height, atAX1.height, accuracy: 0.5, "not one line at the AX1 size")
        XCTAssertEqual(fitted(export, "square.and.arrow.up", .accessibilityLarge, bold: true, in: small).width,
                       223.1, accuracy: 1, "Bold Text")

        XCTAssertEqual(fitted(export, "square.and.arrow.up", .accessibilityLarge, bold: false, in: regular).width,
                       287.5, accuracy: 1, "on 375")
        XCTAssertEqual(fitted(export, "square.and.arrow.up", .accessibilityLarge, bold: true, in: regular).width,
                       261.8, accuracy: 1, "on 375, Bold Text")

        // 200 pt is less than the word at the AX1 size (207.5).
        let atXXXL = idealWidth(BBButtonLabel(title: export, icon: nil, category: .extraExtraExtraLarge))
        XCTAssertLessThan(atXXXL, 200)
        XCTAssertEqual(fitted(export, nil, .accessibilityLarge, bold: false, in: 200).width, atXXXL, accuracy: 0.5)
    }

    /// A short label is never stepped down: «Создать мой трекер» at AX2 keeps
    /// its size and its glyph, wrapping between its words.
    func testAShortWordKeepsTheReadersSize() {
        let label = fitted(tracker, "arrow.right", .accessibilityLarge, bold: false, in: small)
        let bare = fitted(tracker, nil, .accessibilityLarge, bold: false, in: small)
        XCTAssertGreaterThan(label.width - bare.width, 20, "the glyph went")
        let oneLineAtAX2 = idealWidth(BBButtonLabel(title: "Создать", icon: nil, category: .accessibilityLarge))
        let oneLineAtAX1 = idealWidth(BBButtonLabel(title: "Создать", icon: nil, category: .accessibilityMedium))
        XCTAssertGreaterThan(oneLineAtAX2, oneLineAtAX1 + 10, "the sizes are too close to tell apart")
        XCTAssertGreaterThan(bare.height, height(of: BBButtonLabel(title: tracker, icon: nil, category: .accessibilityMedium),
                                                 in: small) + 4, "set smaller than AX2")
    }

    // MARK: - Measuring

    private func idealWidth<V: View>(_ view: V) -> CGFloat {
        UIHostingController(rootView: view.fixedSize())
            .sizeThatFits(in: CGSize(width: 4000, height: 4000)).width
    }

    /// The label's own size when the button leaves it `room`.
    private func fitted(_ title: String, _ icon: String?, _ size: UIContentSizeCategory,
                        bold: Bool, in room: CGFloat) -> CGSize {
        UIHostingController(rootView: BBButtonLabel(title: title, icon: icon, category: size)
            .environment(\.legibilityWeight, bold ? .bold : .regular))
            .sizeThatFits(in: CGSize(width: room, height: 4000))
    }

    private func height<V: View>(of view: V, in room: CGFloat) -> CGFloat {
        UIHostingController(rootView: view).sizeThatFits(in: CGSize(width: room, height: 4000)).height
    }
}

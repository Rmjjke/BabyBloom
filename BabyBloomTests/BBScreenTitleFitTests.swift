import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// A screen's title stays in the bar while its one line fits the bar's room,
/// and otherwise opens the content as `BBScreenHeading`, which steps down a
/// style while its widest word misses the heading's width.
///
/// The fit measures the bar's font as CoreText sets it; the bar draws a title
/// a little narrower, so a few cells below leave the bar one size before the
/// bar itself would cut them (marked "early"), never after.
@MainActor
final class BBScreenTitleFitTests: XCTestCase {

    /// iPhone SE and Display Zoom, iPhone 17, 17 Pro, 17 Pro Max.
    private let widths: [CGFloat] = [320, 375, 402, 440]
    private let sizes: [DynamicTypeSize] = [.large, .xLarge, .xxLarge, .xxxLarge,
                                            .accessibility1, .accessibility2]
    private let languages = ["en", "ru", "es"]
    private let keys = ["tab.feeding", "tab.sleep", "tab.growth", "nav.diapers", "nav.events",
                        "nav.recent_activity", "medication.title", "settings.export", "report.title"]

    /// The first size at which a title misses the bar on 320, 375, 402 and
    /// 440 pt; nil where it fits up to the AX2 cap. Every other title fits
    /// everywhere.
    private let firstMiss: [String: [String: [DynamicTypeSize?]]] = [
        "report.title": [
            "en": [.large, .xxxLarge, .accessibility1, .accessibility2],
            "ru": [.accessibility1, nil, nil, nil],
            "es": [.accessibility1, nil, nil, nil],
        ],
        "nav.recent_activity": [
            "en": [.accessibility1, nil, nil, nil],
            // Early on 320, 402 and 440: the bar cuts at xL, AX2 and never.
            "ru": [.large, .accessibility1, .accessibility1, .accessibility2],
            // Early on 440: the bar never cuts.
            "es": [.xLarge, .accessibility1, .accessibility2, .accessibility2],
        ],
        "settings.export": [
            // Early on 320 and 375: the bar cuts at xxL and AX2.
            "ru": [.xLarge, .accessibility1, .accessibility2, nil],
            "es": [.accessibility1, nil, nil, nil],
        ],
        "medication.title": [
            "es": [.accessibility1, nil, nil, nil],
        ],
    ]

    // MARK: - The bar

    func testTheBarInsetsItsTitle16PointsASideBelow414And20From() {
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 320), 288)
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 375), 343)
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 402), 370)
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 413), 381)
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 414), 374)
        XCTAssertEqual(BBScreenTitleFit.barRoom(width: 440), 400)
    }

    func testTheBarsFontIsLargeTitleBoldCappedAtAX2() {
        let points: [(DynamicTypeSize, CGFloat)] = [
            (.large, 34), (.xLarge, 36), (.xxLarge, 38), (.xxxLarge, 40),
            (.accessibility1, 44), (.accessibility2, 48), (.accessibility3, 48), (.accessibility5, 48),
        ]
        for (size, expected) in points {
            let font = BBScreenTitleFit.font(.largeTitle, size: size, boldText: false)
            XCTAssertEqual(font.pointSize, expected, "\(size)")
            XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold), "\(size)")
        }
    }

    func testNoWidthYetKeepsTheTitleInTheBar() {
        XCTAssertTrue(BBScreenTitleFit.fitsBar("For the pediatrician", width: 0,
                                               size: .accessibility2, boldText: true))
    }

    func testEachTitleLeavesTheBarAtTheSizeTheBarWouldCutItOrOneBefore() throws {
        var report: [String] = []
        for lang in languages {
            try inLanguage(lang) {
                for key in keys {
                    let title = key.l
                    let expected = firstMiss[key]?[lang] ?? [nil, nil, nil, nil]
                    for (width, miss) in zip(widths, expected) {
                        let found = sizes.first {
                            !BBScreenTitleFit.fitsBar(title, width: width, size: $0, boldText: false)
                        }
                        if found != miss {
                            report.append("\(lang) «\(title)» on \(width): first miss \(name(found)), expected \(name(miss))")
                        }
                    }
                }
            }
        }
        XCTAssertTrue(report.isEmpty, report.joined(separator: "\n"))
    }

    /// At the default size the phones from 375 pt keep every title where it was.
    func testAtLargeEveryTitleStaysInTheBarFrom375() throws {
        for lang in languages {
            try inLanguage(lang) {
                for key in keys {
                    for width: CGFloat in [375, 402, 440] {
                        XCTAssertTrue(BBScreenTitleFit.fitsBar(key.l, width: width, size: .large, boldText: false),
                                      "\(lang) «\(key.l)» on \(width)")
                    }
                }
            }
        }
    }

    func testALargerSizeOrBoldTextNeverBringsATitleBackIntoTheBar() throws {
        let all = DynamicTypeSize.allCases.filter { $0 <= .accessibility2 }
        for lang in languages {
            try inLanguage(lang) {
                for key in keys {
                    for width in widths {
                        var missed = false
                        for size in all {
                            let fits = BBScreenTitleFit.fitsBar(key.l, width: width, size: size, boldText: false)
                            let fitsBold = BBScreenTitleFit.fitsBar(key.l, width: width, size: size, boldText: true)
                            let name = "\(lang) «\(key.l)» on \(width) at \(size)"
                            XCTAssertFalse(missed && fits, "\(name): back in the bar")
                            XCTAssertFalse(!fits && fitsBold, "\(name): in the bar only with Bold Text")
                            missed = missed || !fits
                        }
                    }
                }
            }
        }
    }

    // MARK: - The heading's step

    /// The heading runs between the content's 16-pt margins on every screen.
    func testOnlyMedicamentosOn320StepsDown() throws {
        var report: [String] = []
        for lang in languages {
            try inLanguage(lang) {
                for key in keys {
                    for width in widths {
                        for size in sizes where !BBScreenTitleFit.fitsBar(key.l, width: width, size: size, boldText: false) {
                            let style = BBScreenTitleFit.headingStyle(key.l, width: width - 32, size: size, boldText: false)
                            let stepped = lang == "es" && key == "medication.title" && width == 320
                                && size >= .accessibility1
                            if (style != .largeTitle) != stepped {
                                report.append("\(lang) «\(key.l)» on \(width) at \(size): \(style)")
                            }
                        }
                    }
                }
            }
        }
        XCTAssertTrue(report.isEmpty, report.joined(separator: "\n"))
    }

    func testMedicamentosOn320StepsToTitle1AtAX1AndTitle2AtAX2() {
        let cases: [(DynamicTypeSize, BBScreenTitleFit.Style)] = [
            (.xxxLarge, .largeTitle), (.accessibility1, .title1), (.accessibility2, .title2),
        ]
        for (size, expected) in cases {
            XCTAssertEqual(BBScreenTitleFit.headingStyle("Medicamentos", width: 288, size: size, boldText: false),
                           expected, "\(size)")
        }
    }

    /// The heading chooses by layout what `headingStyle` chooses by arithmetic,
    /// so the two must measure a word alike.
    func testTheMeasuredFaceIsTheOneSwiftUISets() {
        var report: [String] = []
        for style in BBScreenTitleFit.Style.allCases {
            for size in sizes {
                for bold in [false, true] {
                    for word in ["pediatrician", "Medicamentos", "Недавние"] {
                        let measured = BBScreenTitleFit.width(
                            of: word, in: BBScreenTitleFit.font(style, size: size, boldText: bold))
                        let laidOut = idealWidth(Text(word).font(style.font)
                            .environment(\.dynamicTypeSize, size)
                            .environment(\.legibilityWeight, bold ? .bold : .regular))
                        if abs(laidOut - measured) > 1 {
                            report.append("«\(word)» \(style) \(size) bold=\(bold): laid out \(laidOut), measured \(measured)")
                        }
                    }
                }
            }
        }
        XCTAssertTrue(report.isEmpty, report.joined(separator: "\n"))
    }

    func testTheHeadingSetsTheStyleTheArithmeticChooses() {
        let cases: [(String, DynamicTypeSize)] = [
            ("Medicamentos", .xxxLarge), ("Medicamentos", .accessibility1), ("Medicamentos", .accessibility2),
            ("For the pediatrician", .large), ("For the pediatrician", .accessibility2),
        ]
        for (title, size) in cases {
            let chosen = BBScreenTitleFit.headingStyle(title, width: 288, size: size, boldText: false)
            let heading = height(BBScreenHeading(title: title, topPadding: 0)
                .environment(\.bbScreenTitleInBar, false), size: size, width: 288)
            let plain = BBScreenTitleFit.Style.allCases.map {
                height(Text(title).font($0.font), size: size, width: 288)
            }
            let name = "«\(title)» at \(size), \(chosen)"
            XCTAssertEqual(Set(plain.map { Int(($0 * 2).rounded()) }).count, plain.count, "\(name): the styles tell apart")
            XCTAssertEqual(heading, plain[BBScreenTitleFit.Style.allCases.firstIndex(of: chosen)!],
                           accuracy: 0.5, name)
        }
    }

    // MARK: - Where the bar holds the title

    func testAHeadingTheBarHoldsTakesNoRoomAndNoSpacing() {
        let stack = VStack(spacing: 24) {
            BBScreenHeading(title: "Feeding")
            Color.clear.frame(height: 10)
        }
        XCTAssertEqual(height(stack, size: .large, width: 320), 10, accuracy: 0.01)
        XCTAssertGreaterThan(height(stack.environment(\.bbScreenTitleInBar, false), size: .large, width: 320),
                             10 + 24 + 34)
    }

    // MARK: - Helpers

    private func name(_ size: DynamicTypeSize?) -> String {
        size.map { "\($0)" } ?? "none"
    }

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

    private func height<V: View>(_ view: V, size: DynamicTypeSize, width: CGFloat) -> CGFloat {
        UIHostingController(rootView: view
            .environment(\.dynamicTypeSize, size)
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true))
            .sizeThatFits(in: CGSize(width: width, height: 4000)).height
    }
}

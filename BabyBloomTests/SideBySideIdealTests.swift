import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The side-by-side rows keep every word whole: the Nutrition card's rows stand
/// beside only from the least width at which the stack gives each text at least
/// its widest word, and the event row puts its time under the texts below that.
///
/// The fonts scale by the device's content size, which a test cannot move, so
/// the larger sizes are built here from the sizes the app's fonts take there.
/// The decision cases need the device at Large and say so when it is not.
@MainActor
final class SideBySideIdealTests: XCTestCase {

    // MARK: - The least room, from known widths

    /// A text whose width at a proposal is its words packed greedily into lines.
    private func measure(_ words: [CGFloat], gap: CGFloat = 4) -> SideBySideIdeal.Measure {
        let oneLine = words.reduce(0, +) + gap * CGFloat(max(words.count - 1, 0))
        return SideBySideIdeal.Measure(oneLine: oneLine, least: 0, widestWord: words.max() ?? 0) { width in
            var widest: CGFloat = 0, line: CGFloat = -gap
            for word in words {
                if line + gap + word > width, line > 0 {
                    widest = max(widest, line)
                    line = word
                } else {
                    line += gap + word
                }
            }
            return max(widest, line)
        }
    }

    func testOneWordEachTakesBothWholeSideBySide() {
        // The label is the less flexible; the value's word outgrows its line.
        XCTAssertEqual(SideBySideIdeal.leastRoom(label: measure([50]), value: measure([80])), 130)
    }

    func testTheLessFlexibleTextIsOfferedHalfFirst() {
        let room = SideBySideIdeal.leastRoom(label: measure([70, 30, 40]), value: measure([60]))
        XCTAssertEqual(room, 130, "offered 65, the value takes its 60 and leaves 70 to the label's widest word")
    }

    func testAWrappedFirstLeavesTheSecondItsShare() {
        // The label is the less flexible and wraps; the value keeps its word.
        let label = measure([40, 40])
        let value = measure([30, 30, 30])
        let room = SideBySideIdeal.leastRoom(label: label, value: value)
        XCTAssertGreaterThanOrEqual(room / 2, label.widestWord)
        XCTAssertGreaterThanOrEqual(room - label.width(room / 2), value.widestWord)
        let lower = room - 0.5
        XCTAssertTrue(lower / 2 < label.widestWord || lower - label.width(lower / 2) < value.widestWord,
                      "half a point lower breaks a word")
    }

    func testATieGoesToTheLabel() {
        XCTAssertEqual(SideBySideIdeal.leastRoom(label: measure([40, 20]), value: measure([20, 40])), 80,
                       "offered 40, the label keeps «40» and leaves 40 to the value")
    }

    // MARK: - The model against a real stack

    /// The row's stack, as the Nutrition card builds it, with its two texts
    /// recording the width the stack offers them, from the ideal up: no word
    /// breaks there, and one does a point under it.
    func testTheStackDividesTheRoomAsTheModelSays() throws {
        try requireLarge()
        let original = LocalizationManager.shared.language
        addTeardownBlock { LocalizationManager.shared.setLanguage(original) }
        var report: [String] = []
        for lang in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(lang)
            for size in [UIContentSizeCategory.large, .extraExtraLarge, .extraExtraExtraLarge] {
                for bold in [false, true] {
                    for (label, status, dot) in rowTexts() {
                        let style = Style(size: size, bold: bold)
                        let probe = Probe()
                        let ideal = idealWidth(row(label, status, dot: dot, style: style, probe: probe))
                        let labelWord = idealWidth(labelText(label.oneWordALine, style))
                        let statusWord = idealWidth(statusText(status.oneWordALine, dot: dot, style))
                        func whole(at width: CGFloat) -> Bool {
                            layOut(row(label, status, dot: dot, style: style, probe: probe), width: width)
                            return (probe.label ?? 0) >= labelWord - 0.01 && (probe.status ?? 0) >= statusWord - 0.01
                        }
                        func offered() -> String {
                            "label \(probe.label ?? -1) for \(labelWord), status \(probe.status ?? -1) for \(statusWord)"
                        }
                        let name = "\(lang) \(size.rawValue) bold=\(bold) «\(label)» | «\(status)»"
                        for extra: CGFloat in stride(from: 0, through: 80, by: 2.5) where !whole(at: ideal + extra) {
                            report.append("\(name): a word breaks at the ideal \(ideal) + \(extra) (\(offered()))")
                            break
                        }
                        if whole(at: ideal - 1) {
                            report.append("\(name): still whole a point under the ideal \(ideal) (\(offered()))")
                        }
                    }
                }
            }
        }
        XCTAssertTrue(report.isEmpty, report.joined(separator: "\n"))
    }

    // MARK: - The Nutrition card's decision

    /// Every word of the three rows in a 256-pt card on a 320-pt screen.
    func testRussianOnA320ScreenStacksAtXXXLargeAndAtXXLargeBold() throws {
        try requireLarge()
        try inLanguage("ru") {
            let rows = cardRows(gain: .within, feeds: 8, nappies: 7)
            XCTAssertGreaterThan(cardIdeal(rows, Style(size: .extraExtraExtraLarge, bold: false)), 256)
            XCTAssertGreaterThan(cardIdeal(rows, Style(size: .extraExtraLarge, bold: true)), 256)
        }
    }

    func testEveryLanguageStaysBesideAtLargeOnA375Screen() throws {
        try requireLarge()
        for lang in ["en", "ru", "es"] {
            try inLanguage(lang) {
                for rows in [cardRows(gain: .within, feeds: 8, nappies: 7),
                             cardRows(gain: .below, feeds: 5, nappies: 4),
                             cardRows(gain: .below, feeds: 5, nappies: nil)] {
                    XCTAssertLessThanOrEqual(cardIdeal(rows, Style(size: .large, bold: false)), 311, lang)
                    XCTAssertLessThanOrEqual(cardIdeal(rows, Style(size: .large, bold: true)), 311, "\(lang) bold")
                }
            }
        }
    }

    // MARK: - The event row

    /// One-word titles over a subtitle, so a break inside the word is the only
    /// way the texts grow a line and the row grows past its badge.
    func testTheEventRowsIdealIsWhereItsLongestWordStopsBreaking() throws {
        try requireLarge()
        for title in ["Парацетамолсодержащий", "вскармливание", "Breastfeeding"] {
            for trailing in [nil, "5 нояб."] {
                let row = eventRow(title, trailing: trailing).beside
                let ideal = idealWidth(row)
                let wide = height(row, width: ideal + 100)
                let name = "«\(title)» trailing=\(trailing ?? "none") ideal \(ideal)"
                XCTAssertEqual(height(row, width: ideal), wide, accuracy: 0.5, "\(name): one line at its ideal")
                XCTAssertGreaterThan(height(row, width: ideal - 1), wide + 1, "\(name): the word breaks a point under it")
            }
        }
    }

    /// The row's content is the screen less the list's and the row's padding.
    func testTheLongFeedTitleMovesItsTimeUnderOnlyWhereItsWordWouldBreak() throws {
        try requireLarge()
        let history = idealWidth(eventRow("Грудное вскармливание", trailing: "5 нояб.").beside)
        let home = idealWidth(eventRow("Грудное вскармливание", trailing: nil).beside)
        print("EVENT_ROW_IDEAL history=\(history) home=\(home)")
        XCTAssertGreaterThan(history, 320 - 64, "time over date: under the texts on 320")
        XCTAssertLessThanOrEqual(history, 375 - 64, "time over date: beside on 375")
        XCTAssertLessThanOrEqual(home, 320 - 64, "time alone: the word stays whole beside it on 320")
    }

    private func eventRow(_ title: String, trailing: String?) -> BBEventRow {
        BBEventRow(icon: "heart.fill", iconColor: BBTheme.Colors.feeding,
                   title: title, subtitle: "15 мин", time: "09:40", trailing: trailing)
    }

    // MARK: - Rows built at a content size

    private struct Style {
        let size: UIContentSizeCategory
        let bold: Bool
        var label: CGFloat { BBTheme.Typography.scaledPointSize(15, relativeTo: .body, for: size) }
        var status: CGFloat { BBTheme.Typography.scaledPointSize(13, relativeTo: .caption1, for: size) }
        var icon: CGFloat { BBTheme.Typography.scaledPointSize(20, relativeTo: .body, for: size) }
    }

    private func rowTexts() -> [(String, String, Color?)] {
        let rows: [(String, Double?, StatusWord)] = [
            ("nutrition.row_gain".l, nil, .within), ("nutrition.row_gain".l, nil, .below),
            ("nutrition.row_gain".l, nil, .firstWeeks),
            ("nutrition.row_feeds".l, 8, .within), ("nutrition.row_feeds".l, 11.5, .above),
            ("nutrition.row_nappies".l, 7, .within), ("nutrition.row_nappies".l, 4, .below),
            ("nutrition.row_nappies".l, nil, .notEnoughData),
        ]
        return rows.map { ($0.0, NutritionSection.statusText(value: $0.1, word: $0.2), $0.2.dot) }
    }

    private func cardRows(gain: StatusWord, feeds: Double, nappies: Double?) -> [(String, String, Color?)] {
        let nappyWord: StatusWord = nappies == nil ? .notEnoughData : .within
        return [("nutrition.row_gain".l, NutritionSection.statusText(value: nil, word: gain), gain.dot),
                ("nutrition.row_feeds".l, NutritionSection.statusText(value: feeds, word: .within), StatusWord.within.dot),
                ("nutrition.row_nappies".l, NutritionSection.statusText(value: nappies, word: nappyWord), nappyWord.dot)]
    }

    private func cardIdeal(_ rows: [(String, String, Color?)], _ style: Style) -> CGFloat {
        rows.map { idealWidth(row($0.0, $0.1, dot: $0.2, style: style, probe: nil)) }.max() ?? 0
    }

    /// `NutritionSection`'s side-by-side row, in this test's fonts.
    private func row(_ label: String, _ status: String, dot: Color?, style: Style, probe: Probe?) -> some View {
        SideBySideIdeal(chrome: style.icon + 4 * BBTheme.Spacing.sm) {
            Group {
                labelText(label, style)
                labelText(label.oneWordALine, style)
                statusText(status, dot: dot, style).multilineTextAlignment(.trailing)
                statusText(status.oneWordALine, dot: dot, style)
            }
            .hidden()
            HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                Image(systemName: "heart.fill")
                    .font(.system(size: style.label * 14 / 15))
                    .frame(width: style.icon)
                Recorder(probe: probe, isLabel: true) { labelText(label, style) }
                Spacer(minLength: BBTheme.Spacing.sm)
                Recorder(probe: probe, isLabel: false) {
                    statusText(status, dot: dot, style).multilineTextAlignment(.trailing)
                }
            }
        }
        .environment(\.legibilityWeight, style.bold ? .bold : .regular)
    }

    private func labelText(_ text: String, _ style: Style) -> some View {
        Text(text)
            .font(.system(size: style.label, weight: .medium, design: .rounded))
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.legibilityWeight, style.bold ? .bold : .regular)
    }

    /// `BBTierValue` scales its own size by the device's, 1 at Large.
    private func statusText(_ text: String, dot: Color?, _ style: Style) -> some View {
        BBTierValue(text: text, dot: dot, size: style.status, style: .caption1)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.legibilityWeight, style.bold ? .bold : .regular)
    }

    // MARK: - Measuring

    private func requireLarge() throws {
        try XCTSkipUnless(UIApplication.shared.preferredContentSizeCategory == .large,
                          "the cases build their sizes from Large; the device is at "
                          + UIApplication.shared.preferredContentSizeCategory.rawValue)
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

    private func height<V: View>(_ view: V, width: CGFloat) -> CGFloat {
        UIHostingController(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true))
            .sizeThatFits(in: CGSize(width: width, height: 4000)).height
    }

    /// On the device's pixel grid, as the hosted sizes above are: at the
    /// renderer's default scale of 1 every glyph's advance rounds to a whole
    /// point and a text comes out points wider than measured.
    private func layOut<V: View>(_ view: V, width: CGFloat) {
        let renderer = ImageRenderer(content: view.frame(width: width))
        renderer.scale = UIScreen.main.scale
        _ = renderer.uiImage
    }
}

/// The widths a stack placed its two texts at, last layout.
private final class Probe: @unchecked Sendable {
    var label: CGFloat?
    var status: CGFloat?
}

/// Passes every proposal through to its one subview and notes the one it is
/// placed with.
private struct Recorder: Layout {
    let probe: Probe?
    let isLabel: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews[0].sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if isLabel { probe?.label = proposal.width } else { probe?.status = proposal.width }
        subviews[0].place(at: bounds.origin, proposal: proposal)
    }
}

import XCTest
@testable import BabyBloom

/// A format cut at one argument by its number, whatever order the
/// translation writes them in, so the styled value is always the right one.
@MainActor
final class FormatSplitTests: XCTestCase {

    /// [head, tail], nil when the format cannot be cut.
    private func cut(_ split: FormatSplit?) -> [String]? { split.map { [$0.head, $0.tail] } }

    // MARK: The cut

    func testTheCutFollowsTheNumberNotThePlace() {
        let english = FormatSplit("Since %1$@: %2$@", at: 2, value: "+320 g", filling: ["28 Oct"])
        XCTAssertEqual(cut(english), ["Since 28 Oct: ", ""])
        let swapped = FormatSplit("%2$@ desde el %1$@", at: 2, value: "+320 g", filling: ["28 oct."])
        XCTAssertEqual(cut(swapped), ["", " desde el 28 oct."])
    }

    func testUnnumberedSpecifiersCountInOrder() {
        XCTAssertEqual(cut(FormatSplit("%@ at %@", at: 2, value: "B", filling: ["A"])),
                       ["A at ", ""])
        XCTAssertEqual(cut(FormatSplit("Head: %@ cm", value: "34.5")), ["Head: ", " cm"])
    }

    func testANumberTargetAndANumberFiller() {
        // The styled value arrives as text even where the format counts it.
        XCTAssertEqual(cut(FormatSplit("%1$d of %2$d", value: "3", filling: [7])),
                       ["", " of 7"])
        XCTAssertEqual(cut(FormatSplit("%2$d of %1$d", value: "3", filling: [7])),
                       ["7 of ", ""])
    }

    func testAPercentSignAndARepeatedArgument() {
        XCTAssertEqual(cut(FormatSplit("Up %@%% this week", value: "12")), ["Up ", "% this week"])
        XCTAssertEqual(cut(FormatSplit("%1$@ (%1$@)", value: "X")), ["", " (X)"])
    }

    func testAFillerHoldingTheMarkerDoesNotMoveTheCut() {
        XCTAssertEqual(cut(FormatSplit("%1$@ weighs %2$@", at: 2, value: "4 kg", filling: ["Mi\u{E000}a"])),
                       ["Mia weighs ", ""])
    }

    func testNoArgumentAtThePositionOrTooFewFillers() {
        XCTAssertNil(FormatSplit("No argument here", value: "1"))
        XCTAssertNil(FormatSplit("%1$@ only", at: 2, value: "1"))
        XCTAssertNil(FormatSplit("Since %1$@: %2$@", at: 2, value: "+320 g"))
    }

    func testArgumentsByNumberEachOnce() {
        XCTAssertEqual(FormatSplit.arguments(in: "%2$@ — %1$ld"),
                       [FormatArgument(position: 1, conversion: "ld"), FormatArgument(position: 2, conversion: "@")])
        XCTAssertEqual(FormatSplit.arguments(in: "%@ at %@ (%1$@)").map(\.position), [1, 2])
        // «10% of» is text: no space flag, as the language lint reads it.
        XCTAssertEqual(FormatSplit.arguments(in: "10% of feeds, %d%%"), [FormatArgument(position: 1, conversion: "d")])
    }

    // MARK: The screen and the PDF bold the right value

    func testTheReportRowLabelIsTheTextBeforeTheValue() {
        let row = ReportRow(format: "%2$@ desde el %1$@", at: 2, filling: ["28 oct."], value: "+320 g")
        XCTAssertEqual(row.label, "")
        XCTAssertEqual(ReportRow(format: "Since %1$@: %2$@", at: 2, filling: ["28 Oct"], value: "+320 g").label,
                       "Since 28 Oct: ")
    }

    func testThePDFRowBoldsTheValueInEitherOrder() {
        XCTAssertEqual(DoctorReportPDF.row(format: "%2$@ desde el %1$@", at: 2, filling: ["28 oct."], "+320 g"),
                       "<b>+320 g</b> desde el 28 oct.")
        XCTAssertEqual(DoctorReportPDF.row(format: "Since %1$@: %2$@", at: 2, filling: ["28 Oct"], "+320 g"),
                       "Since 28 Oct: <b>+320 g</b>")
    }

    func testTheChangeSinceRowInEveryLanguage() {
        let previous = LocalizationManager.shared.language
        defer { LocalizationManager.shared.setLanguage(previous) }
        for language in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(language)
            let html = DoctorReportPDF.row(format: "report.change_since_fmt".l, at: 2, filling: ["DATE"], "+320 g")
            XCTAssertTrue(html.contains("<b>+320 g</b>"), "\(language): \(html)")
            XCTAssertTrue(html.contains("DATE"), "\(language): \(html)")
            XCTAssertFalse(html.contains("%"), "\(language): \(html)")
        }
    }
}

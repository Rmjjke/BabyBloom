import XCTest
import UIKit
@testable import BabyBloom

/// Every PDF table head keeps its words whole in its column, in every language
/// and the two pseudo ones. A head is one line of words that may wrap between
/// words but never inside one, so its widest line-break unit must fit the
/// column less the cell's padding.
///
/// The print formatter lays the 523.2-pt printable width out as 612 CSS px, so
/// the measures run in CSS px at the CSS sizes and the messages give page pt.
@MainActor
final class PDFHeaderFitTests: XCTestCase {

    /// Allowed misses, keyed "<file> <string key>" ("export feeding export.col.duration").
    private static let knownMisses: [KnownMiss] = [
        KnownMiss(.real(.ru), "export diapers export.col.time", width: 30.1, room: 26.1),
        KnownMiss(.real(.ru), "report medication.report_col_count", width: 55.9, room: 49.1),
    ]

    private let cssWidth: CGFloat = 612
    private let pointsPerPixel: CGFloat = 523.2 / 612
    /// The face the CSS asks for; Core Text falls back for the scripts it lacks,
    /// as WebKit does along the CSS list.
    /// `th` is bold by default; the report asks for 600, which Helvetica Neue
    /// lacks, and CSS matching takes the next heavier face, Bold, for it too.
    private let head = UIFont(name: "HelveticaNeue-Bold", size: 11)!

    override func tearDown() {
        FitLanguage.restore()
        super.tearDown()
    }

    /// The export's tables: body padding 24 and card padding 16 a side leave
    /// 532 px, `th` pads 10 a side, and `columnWidths` shares the width by the
    /// longest text per column. The rows are a typical day's, with the longest
    /// name each column can show and a note at the cap, so a head gets the
    /// share it has in a full export, not in an empty one.
    func testEveryExportHeadFitsItsColumn() {
        let table: CGFloat = cssWidth - 2 * 24 - 2 * 16
        for language in FitLanguage.all {
            language.apply()
            for (name, keys, row) in exportTables() {
                let heads = keys.map(\.l)
                let shares = Self.shares(ExportGenerator.columnWidths(headers: heads, rows: [row]))
                XCTAssertEqual(shares.count, keys.count, "\(language) \(name): \(shares)")
                for (index, key) in keys.enumerated() where index < shares.count {
                    let room = shares[index] / 100 * table - 2 * 10
                    check(language, "export \(name) \(key)", heads[index], font: head, room: room)
                }
            }
        }
    }

    /// The doctor report's medication table: fixed 34/30/12/24 % of the full
    /// 612 px, `th` padding 8 a side, weight 600.
    func testEveryMedicationHeadFitsItsColumn() {
        let columns: [(key: String, share: CGFloat)] = [
            ("medication.report_col_name", 34), ("medication.report_col_dose", 30),
            ("medication.report_col_count", 12), ("medication.report_col_dates", 24),
        ]
        for language in FitLanguage.all {
            language.apply()
            for column in columns {
                let room = column.share / 100 * cssWidth - 2 * 8
                check(language, "report \(column.key)", column.key.l, font: head, room: room)
            }
        }
    }

    private func check(_ language: FitLanguage, _ key: String, _ text: String, font: UIFont, room: CGFloat) {
        let width = FitMeasure.widestUnit(text, uiFont: font)
        let line = "\(language) \(key): widest unit \(pt(width)) in \(pt(room)) pt («\(text)»)"
        if KnownMiss.listed(Self.knownMisses, language, key) {
            if width <= room { XCTFail("\(line) fits now: remove its known-miss row") }
        } else {
            XCTAssertLessThanOrEqual(width, room, line)
        }
    }

    private func pt(_ px: CGFloat) -> String { String(format: "%.1f", px * pointsPerPixel) }

    /// The percentages of a `<colgroup>`, in order.
    private static func shares(_ colgroup: String) -> [CGFloat] {
        let pattern = try! NSRegularExpression(pattern: #"width: ([0-9.]+)%"#)
        let range = NSRange(colgroup.startIndex..., in: colgroup)
        return pattern.matches(in: colgroup, range: range).compactMap { match in
            Range(match.range(at: 1), in: colgroup).flatMap { Double(colgroup[$0]) }.map { CGFloat($0) }
        }
    }

    /// Each export table's head keys and a typical row, in the applied language.
    private func exportTables() -> [(String, [String], [String])] {
        let locale = LocalizationManager.shared.language.environmentLocale
        let date = Date(timeIntervalSince1970: 1_793_000_000)
        let day = DateFormatter()
        day.locale = locale
        day.dateStyle = .medium
        let time = DateFormatter()
        time.locale = locale
        time.setLocalizedDateFormatFromTemplate("jm")
        let longest = { (keys: [String]) in keys.map(\.l).max { $0.count < $1.count } ?? "" }
        let note = String(repeating: "n", count: 32)
        let (d, t) = (day.string(from: date), time.string(from: date))
        return [
            ("feeding", ["export.col.date", "export.col.time", "export.col.type", "export.col.side",
                         "export.col.volume", "export.col.duration"],
             [d, t, longest(FeedingEntry.FeedingType.allCases.map(\.displayName)),
              longest(FeedingEntry.BreastSide.allCases.map(\.displayName)), ReportFormat.ml(120),
              DurationText.minutes(15)]),
            ("sleep", ["export.col.date", "export.col.start", "export.col.end", "export.col.type", "export.col.duration"],
             [d, t, t, longest(SleepEntry.SleepType.allCases.map(\.displayName)), DurationText.minutes(95)]),
            ("diapers", ["export.col.date", "export.col.time", "export.col.type", "export.col.color", "export.col.notes"],
             [d, t, longest(DiaperEntry.DiaperType.allCases.map(\.displayName)),
              longest(DiaperEntry.StoolColor.allCases.map(\.displayName)), note]),
            ("growth", ["export.col.date", "export.col.weight", "export.col.height", "export.col.head"],
             [d, ReportFormat.kg(4.35), ReportFormat.cm(55.5), ReportFormat.cm(38.5)]),
            ("events", ["export.col.date", "export.col.time", "export.col.type", "export.col.notes"],
             [d, t, longest(CustomEvent.EventType.allCases.map(\.displayName)), note]),
        ]
    }
}

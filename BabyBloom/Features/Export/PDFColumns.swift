import UIKit

/// The column widths of a PDF table, measured at the faces the page prints in.
///
/// Every page prints its own table and would size its own columns, so the
/// widths are fixed from all the rows. A head may wrap between its words but
/// never inside one: each column first gets its head's widest line-break unit
/// plus the cell padding. What is left goes by what each column would take,
/// its head on one line or its longest cell, up to a cap that keeps one long
/// note from squeezing the rest; the note wraps instead. Character counts
/// would not hold this in every language: a CJK character is twice a Latin
/// one, a German head one long word.
enum PDFColumns {
    /// Shares of `width` in percent, one per head.
    ///
    /// When the heads alone are wider than the table, the shares follow the
    /// heads and some head breaks inside a word: the header fit test names it,
    /// and the fix is shorter copy, not a narrower measure.
    static func shares(heads: [String], rows: [[String]], headFont: UIFont, cellFont: UIFont,
                       width: CGFloat, padding: CGFloat) -> [CGFloat] {
        guard !heads.isEmpty else { return [] }
        // A pixel for the engine's own rounding of a percentage into a width.
        let sides = 2 * padding + 1
        let cap = cellFont.pointSize * 16
        let floors = heads.map { widestUnit($0, font: headFont) + sides }
        // A column would take its head on one line or its longest cell.
        let wants = heads.indices.map { column -> CGFloat in
            let cells = Set(rows.compactMap { column < $0.count ? $0[column] : nil })
            let longest = cells.map { measure($0, font: cellFont) }.max() ?? 0
            return max(floors[column], min(cap, max(measure(heads[column], font: headFont), longest)) + sides)
        }

        let widths: [CGFloat]
        let floorTotal = floors.reduce(0, +)
        let wantTotal = wants.reduce(0, +)
        if floorTotal >= width {
            widths = floors
        } else if wantTotal <= width {
            widths = wants
        } else {
            // Every head keeps its floor; the room above the floors goes by
            // how much more each column would take.
            let spare = width - floorTotal
            widths = zip(floors, wants).map { floor, want in floor + (want - floor) * spare / (wantTotal - floorTotal) }
        }
        let total = widths.reduce(0, +)
        return widths.map { $0 * 100 / total }
    }

    static func colgroup(_ shares: [CGFloat]) -> String {
        let columns = shares.map { "<col style=\"width: \(String(format: "%.2f", Double($0)))%\">" }
        return "<colgroup>\(columns.joined())</colgroup>"
    }

    private static func widestUnit(_ text: String, font: UIFont) -> CGFloat {
        text.lineBreakUnits.map { measure($0, font: font) }.max() ?? 0
    }

    private static func measure(_ text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

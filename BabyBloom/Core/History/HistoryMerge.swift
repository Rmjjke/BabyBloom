import Foundation

/// Rows that bypass the free window and the cap, merged into an already
/// windowed and capped list. Pediatrician visits are free on every list that
/// shows them, so they cannot go through `HistoryWindow`: a visit behind the
/// lock would hide the record the report starts from.
enum HistoryMerge {
    /// Both inputs newest first. Output newest first; on equal dates the
    /// windowed row comes first; windowed rows keep their relative order.
    /// Every input row appears exactly once.
    static func merge<Row>(_ windowed: [Row], exempt: [Row], date: (Row) -> Date) -> [Row] {
        var result: [Row] = []
        result.reserveCapacity(windowed.count + exempt.count)
        var w = 0, e = 0
        while w < windowed.count, e < exempt.count {
            // Strictly newer exempt wins; a tie falls to the windowed row.
            if date(exempt[e]) > date(windowed[w]) {
                result.append(exempt[e]); e += 1
            } else {
                result.append(windowed[w]); w += 1
            }
        }
        result.append(contentsOf: windowed[w...])
        result.append(contentsOf: exempt[e...])
        return result
    }
}

import UIKit

/// Composes an HTML document into whole A4 pages for `UIMarkupTextPrintFormatter`.
/// That engine slices its layout at the page height and ignores the CSS break
/// rules: a table row on the edge prints half on each page, and `thead` never
/// repeats. So every page is its own small document with its own formatter, and
/// the engine itself answers what fits (DECISIONS 2026-11-02).
enum PagedPDF {

    // MARK: Type

    // Not the system font: it draws Cyrillic «к» and Latin «ĸ» with one glyph, and
    // the text layer then spells every «к» U+0138, so a search for «кг» finds
    // nothing. Ligatures off for the same reason: «ﬁ» is one character there, and
    // a search for «fine» misses it.
    //
    // The list is long because this engine has no system fallback: a glyph no named
    // family holds prints as a boxed «?». It follows the system's cascade list, but
    // never name Apple Color Emoji: with it in the list the whole text prints boxed.
    private static let fallbackFamilies = [
        "Helvetica", "Arial", "PingFang SC", "PingFang TC", "Hiragino Sans",
        "Apple SD Gothic Neo", "Geeza Pro", "Noto Nastaliq Urdu", "Noto Sans Myanmar", "Thonburi", "Arial Hebrew",
        "Kohinoor Devanagari", "Kailasa", "Kohinoor Bangla", "Kohinoor Gujarati", "Mukta Mahee", "Noto Sans Kannada",
        "Khmer Sangam MN", "Lao Sangam MN", "Malayalam Sangam MN", "Noto Sans Oriya", "Sinhala Sangam MN",
        "Tamil Sangam MN", "Kohinoor Telugu", "Noto Sans Armenian", "Euphemia UCAS", "Apple Symbols",
        "STIX Two Math", "Zapf Dingbats", "Kefa III", "Galvji"
    ]

    static let cssType = """
        font-family: 'Helvetica Neue', \(fallbackFamilies.map { "'\($0)'" }.joined(separator: ", ")), sans-serif; \
        font-variant-ligatures: none; -webkit-font-variant-ligatures: none;
        """

    /// The same face and list for what is drawn around the HTML, like the report's
    /// footer. UIKit's own fallback sends a sign like ❤ to the colour emoji font,
    /// which a PDF context prints as a box and a gap.
    static func font(ofSize size: CGFloat) -> UIFont {
        let list = fallbackFamilies.map { UIFontDescriptor(fontAttributes: [.family: $0]) }
        let descriptor = UIFontDescriptor(name: "HelveticaNeue", size: size).addingAttributes([.cascadeList: list])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// A user's text as the PDF may print it, for the render only: this engine can
    /// print a colour emoji only as a box, in any form it is offered (a font, an
    /// image), and UIKit drawing the report's footer into the PDF prints one too.
    ///
    /// Unicode also tags digits, «#», «©» and the like as emoji-capable, so that tag
    /// alone must never filter: a lost digit in a question about a dose is worse
    /// than any box. Those stay as text, and lose only the request for the emoji
    /// form: «1️⃣» prints 1, «❤️» prints ❤. An emoji between two words or numbers
    /// leaves a space, or «5🍼10 мл» would read 510.
    static func withoutEmoji(_ text: String) -> String {
        var printable = String.UnicodeScalarView()
        var removed = false
        for character in text {
            let scalars = character.unicodeScalars
            let standIn = scalars.first.flatMap { textStandIns[$0.value] }
            let kept: [Unicode.Scalar]
            if let standIn {
                kept = Array(standIn.unicodeScalars)
            } else if let first = scalars.first, hasNoTextForm(first) {
                kept = []
            } else {
                // A skin tone or a joined emoji can cling to any letter or digit, which stays.
                let hasEmoji = scalars.contains(where: hasNoTextForm)
                kept = scalars.filter {
                    !hasNoTextForm($0) && $0.value != 0xFE0F && $0.value != 0x20E3 && !(hasEmoji && $0.value == 0x200D)
                }
            }
            if removed || standIn != nil, let next = kept.first, endsAWord(printable.last), endsAWord(next) {
                printable.append(" ")
            }
            printable.append(contentsOf: kept)
            removed = kept.isEmpty || scalars.contains(where: hasNoTextForm)
        }
        return String(printable)
    }

    /// What must not vanish with its emoji, or the sentence survives with its answer
    /// gone: «Iron ❌, Vit D ✅». The keycap ten, and the marks that say yes or no. A
    /// closed list (DECISIONS 2026-11-02); every other emoji leaves.
    private static let textStandIns: [UInt32: String] = [
        0x1F51F: "10",
        0x2705: "✓", 0x274C: "✗", 0x274E: "✗",
        0x2795: "+", 0x2796: "−", 0x2797: "÷",
        0x2753: "?", 0x2754: "?", 0x2755: "!", 0x2757: "!",
    ]

    /// Nothing the page can show: spaces and the invisible marks a removed emoji can
    /// leave behind (a joiner, a variation selector).
    static func isBlank(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy {
            $0.properties.isWhitespace || $0.properties.isVariationSelector
                || [.format, .control].contains($0.properties.generalCategory)
        }
    }

    private static func endsAWord(_ scalar: Unicode.Scalar?) -> Bool {
        guard let scalar else { return false }
        return scalar.properties.isAlphabetic || scalar.properties.numericType != nil
    }

    /// No family in `cssType` holds it (checked against every emoji-capable scalar).
    /// An unassigned scalar in the pictograph blocks is an emoji newer than this
    /// phone's Unicode tables, and has no font here either.
    private static func hasNoTextForm(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isEmojiPresentation || (scalar.properties.isEmoji && scalar.value >= 0x1F000)
            || (scalar.properties.generalCategory == .unassigned && (0x1F000...0x1FAFF).contains(scalar.value))
    }

    // MARK: Document

    /// Part of a document's flow.
    enum Item {
        /// Stays on one page.
        case block(String)
        /// May break between its rows, never inside one.
        case rows(Rows)
    }

    struct Rows {
        /// Before the first row: the heading, the table, its head.
        var opening: String
        /// Before the row that starts a new page, given its index: the head again.
        var continuation: (Int) -> String
        /// After the last row on each page.
        var closing: String
        var rows: [String]
        /// Moves to the next page as one, as long as it fits on one.
        var keepsTogether = false
    }

    struct Document {
        /// Everything up to and including `<body>`.
        var head: String
        var items: [Item]

        var atomCount: Int {
            items.reduce(0) { count, item in
                if case .rows(let rows) = item { return count + rows.rows.count }
                return count + 1
            }
        }

        /// The whole flow as one unbroken document.
        var html: String {
            let atoms = PagedPDF.atoms(of: items) { _ in false }
            return PagedPDF.page(atoms[...], head: head)
        }
    }

    // MARK: PDF

    static func data(_ document: Document, renderer: UIPrintPageRenderer = UIPrintPageRenderer()) -> Data {
        setPage(of: renderer)
        var wholePages: Int?
        // Laying a long export out whole costs seconds, to learn what its length says
        // already. Only a speed-up: one that does fit still comes out as one page.
        if document.atomCount < manyAtoms {
            let whole = UIMarkupTextPrintFormatter(markupText: document.html)
            renderer.addPrintFormatter(whole, startingAtPageAt: 0)
            wholePages = renderer.numberOfPages
            // The common one-page document is laid out once and drawn as it is.
            guard renderer.numberOfPages > 1 else { return draw(renderer) }
            whole.removeFromPrintPageRenderer()
        }
        var next = 0
        for formatter in pages(of: document, wholePages: wholePages, footerHeight: renderer.footerHeight) {
            formatter.removeFromPrintPageRenderer()
            renderer.addPrintFormatter(formatter, startingAtPageAt: next)
            // More than one only for a single row taller than a page.
            next += max(1, formatter.pageCount)
        }
        return draw(renderer)
    }

    private static func pages(of document: Document, wholePages: Int?,
                              footerHeight: CGFloat) -> [UIMarkupTextPrintFormatter] {
        func laidOut(_ html: String) -> (formatter: UIMarkupTextPrintFormatter, pages: Int) {
            // A long export makes hundreds of these in one run-loop turn.
            autoreleasepool {
                let probe = UIPrintPageRenderer()
                probe.footerHeight = footerHeight
                setPage(of: probe)
                let formatter = UIMarkupTextPrintFormatter(markupText: html)
                probe.addPrintFormatter(formatter, startingAtPageAt: 0)
                return (formatter, probe.numberOfPages)
            }
        }
        func fitsAlone(_ rows: Rows) -> Bool {
            laidOut(page(atoms(of: [.rows(rows)], splitting: { _ in false })[...], head: document.head)).pages == 1
        }
        // A list too long for a page of its own has to break after all.
        let flow = atoms(of: document.items) { $0.keepsTogether && !fitsAlone($0) }
        // The formatter that proved a page fits also draws it: a layout is the whole
        // cost of a long document, and this one is done.
        var fitted: [Int: (end: Int, formatter: UIMarkupTextPrintFormatter)] = [:]
        let runs = ranges(count: flow.count, hint: wholePages.map { flow.count / $0 } ?? typicalPage) { run in
            let (formatter, pages) = laidOut(page(flow[run], head: document.head))
            if pages == 1 { fitted[run.lowerBound] = (run.upperBound, formatter) }
            return pages == 1
        }
        return runs.map { run in
            if let kept = fitted[run.lowerBound], kept.end == run.upperBound { return kept.formatter }
            return UIMarkupTextPrintFormatter(markupText: page(flow[run], head: document.head))
        }
    }

    /// The most a page could hold, well above it: only a document past this skips the
    /// layout as a whole.
    private static let manyAtoms = 100
    /// Where the search for a long document's first page starts.
    private static let typicalPage = 30

    /// The runs of atoms that make the pages: each takes as many as `fits`, and at
    /// least one whatever its height. A layout per question is the whole cost, so
    /// it searches outwards from `hint`, then from the previous page's size,
    /// instead of bisecting the rest of the document for every page.
    ///
    /// Once two pages in a row held the same number, the next one that fits at that
    /// number does not look for one more. Pages past a run of wrapped notes can come
    /// out a row short of full, which costs nothing; the look for that row would cost
    /// a second layout on every page of a long export.
    static func ranges(count: Int, hint: Int, fits: (Range<Int>) -> Bool) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0
        var size = max(1, hint)
        var settled = false
        while start < count {
            var good = start + 1
            var bad = count + 1
            var probe = min(start + size, count)
            var step = 1
            while good + 1 < bad {
                let end = (good + 1..<bad).contains(probe) ? probe : (good + bad) / 2
                if fits(start..<end) {
                    good = end
                    if settled && end == start + size { break }
                    probe = end + step
                } else {
                    bad = end
                    probe = end - step
                }
                step *= 2
            }
            // The hint is a guess, so the first page settles nothing.
            settled = !ranges.isEmpty && good - start == size
            ranges.append(start..<good)
            size = good - start
            start = good
        }
        return ranges
    }

    // MARK: Atoms

    /// The smallest piece a page break may not enter.
    private struct Atom {
        var html: String
        /// The `Rows` it is a row of, which of them, and which item they are.
        var rows: Rows?
        var index = 0
        var item = 0
    }

    private static func atoms(of items: [Item], splitting: (Rows) -> Bool) -> [Atom] {
        items.enumerated().flatMap { item, content -> [Atom] in
            switch content {
            case .block(let html):
                return [Atom(html: html, item: item)]
            case .rows(let rows) where rows.keepsTogether && !splitting(rows):
                return [Atom(html: rows.opening + rows.rows.joined() + rows.closing, item: item)]
            case .rows(let rows):
                return rows.rows.enumerated().map { Atom(html: $1, rows: rows, index: $0, item: item) }
            }
        }
    }

    private static func page(_ atoms: ArraySlice<Atom>, head: String) -> String {
        var body = ""
        var open: Atom?
        for atom in atoms {
            if let rows = open?.rows, open?.item != atom.item {
                body += rows.closing
                open = nil
            }
            if let rows = atom.rows, open == nil {
                body += atom.index == 0 ? rows.opening : rows.continuation(atom.index)
                open = atom
            }
            body += atom.html
        }
        if let rows = open?.rows { body += rows.closing }
        return head + body + "</body></html>"
    }

    // MARK: Drawing

    private static let pageSize = CGSize(width: 595.2, height: 841.8)
    private static let margin: CGFloat = 36

    private static func setPage(of renderer: UIPrintPageRenderer) {
        let printable = CGRect(x: margin, y: margin,
                               width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)
        renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")
    }

    private static func draw(_ renderer: UIPrintPageRenderer) -> Data {
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, CGRect(origin: .zero, size: pageSize), nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            // A white page, margins and footer included: a PDF page is
            // transparent, and dark viewers drew the frame black (design review m5).
            UIColor.white.setFill()
            UIRectFill(UIGraphicsGetPDFContextBounds())
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

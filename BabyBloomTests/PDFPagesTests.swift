import XCTest
import PDFKit
import SwiftData
@testable import BabyBloom

/// Rendered PDFs read back: a page never cuts a line or a table row, the table
/// head repeats, and the text layer holds the letters printed.
@MainActor
final class PDFPagesTests: XCTestCase {

    private struct Report {
        let document: PDFDocument
        let weights: [String]
        let html: String
    }

    private func inLanguage(_ language: SupportedLanguage, _ body: () throws -> Void) rethrows {
        LocalizationManager.shared.setLanguage(language)
        defer { LocalizationManager.shared.setLanguage(.en) }
        try body()
    }

    private func seeded() throws -> (baby: Baby, context: ModelContext, container: ModelContainer) {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        SeedScenario.doctorNoVisit.seedDoctor(into: context, now: Date())
        return (try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first), context, container)
    }

    /// A seeded baby with a growth history plus `extraWeighings` older ones with weights no
    /// other line prints, so a row cut in two shows up as its weight printed twice.
    private func report(extraWeighings: Int, name: String? = nil, questions: [String]? = nil,
                        medicationNames: [String] = []) throws -> Report {
        let (baby, context, container) = try seeded()
        if let name { baby.name = name }
        let now = Date()
        for (offset, medication) in medicationNames.enumerated() {
            let event = CustomEvent(time: now.addingTimeInterval(-Double(offset + 1) * 600), type: .medication)
            event.medicationName = medication
            event.medicationDose = "5 ml"
            event.baby = baby
            context.insert(event)
        }
        let values = (0..<extraWeighings).map { 6 + Double($0) * 0.01 }
        for (offset, value) in values.enumerated() {
            let entry = GrowthEntry(date: baby.birthDate.addingTimeInterval(86_400 + Double(offset) * 6 * 3600),
                                    weightKg: value)
            entry.baby = baby
            context.insert(entry)
        }
        try context.save()
        let visits = try context.fetch(FetchDescriptor<DoctorVisit>())
        let open = try questions ?? DoctorPeriod.openQuestions(context.fetch(FetchDescriptor<DoctorQuestion>())).map(\.text)
        let start = DoctorPeriod.start(visits: visits, birthDate: baby.birthDate)
        let summary = DoctorReportSummary.make(
            input: .load(baby: baby, periodStart: start, in: context),
            periodStart: start, now: now, startsAtVisit: !visits.isEmpty, calendar: .current)
        let data = DoctorReportPDF.data(summary: summary, baby: baby, openQuestions: open, periodStart: start, now: now)
        let html = DoctorReportPDF.html(summary: summary, baby: baby, openQuestions: open, periodStart: start, now: now)
        let document = try XCTUnwrap(PDFDocument(data: data))
        return withExtendedLifetime(container) { Report(document: document, weights: values.map(ReportFormat.kg), html: html) }
    }

    private func exportPDF(rows: Int) throws -> (document: PDFDocument, weights: [String]) {
        let values = (0..<rows).map { 6 + Double($0) * 0.01 }
        let growths = values.enumerated().map { offset, value in
            GrowthEntry(date: Date().addingTimeInterval(-Double(offset) * 3600), weightKg: value)
        }
        let data = ExportGenerator.pdfData(baby: nil, feedings: [], sleeps: [], diapers: [], growths: growths,
                                           events: [], categories: [.growth], range: .all)
        return (try XCTUnwrap(PDFDocument(data: data)), values.map(ReportFormat.kg))
    }

    /// One string per page, with no-break spaces as plain ones: extractors differ on them.
    private func texts(_ document: PDFDocument) -> [String] {
        (0..<document.pageCount).map {
            (document.page(at: $0)?.string ?? "").replacingOccurrences(of: "\u{A0}", with: " ")
        }
    }

    private func plain(_ weights: [String]) -> [String] {
        weights.map { $0.replacingOccurrences(of: "\u{A0}", with: " ") }
    }

    private func assertEveryRowPrintedOnce(_ weights: [String], in pages: [String],
                                           file: StaticString = #filePath, line: UInt = #line) {
        let whole = pages.joined(separator: "\n")
        for weight in plain(weights) {
            XCTAssertEqual(whole.components(separatedBy: weight).count - 1, 1, "row «\(weight)»", file: file, line: line)
        }
    }

    private func assertHeadOnEveryPageWithRows(_ head: String, _ weights: [String], in pages: [String],
                                               file: StaticString = #filePath, line: UInt = #line) {
        let rows = plain(weights)
        for (index, page) in pages.enumerated() where rows.contains(where: page.contains) {
            XCTAssertTrue(page.contains(head), "page \(index + 1) has rows and no head", file: file, line: line)
        }
    }

    /// The footer sits in the bottom 36 + 24 pt; a line sliced at the page edge
    /// keeps its full box in the text layer, so it reads as reaching into that band.
    private func assertNoBodyLineInFooterBand(_ document: PDFDocument, _ label: String,
                                              file: StaticString = #filePath, line: UInt = #line) throws {
        for index in 0..<document.pageCount {
            let page = try XCTUnwrap(document.page(at: index))
            let lines = try XCTUnwrap(page.selection(for: page.bounds(for: .mediaBox))).selectionsByLine()
            XCTAssertFalse(lines.isEmpty, "\(label), page \(index + 1) reads as empty", file: file, line: line)
            for selection in lines {
                let text = selection.string ?? ""
                guard !text.contains("Page \(index + 1) of"), !text.hasPrefix("brand.name".l + " ·") else { continue }
                XCTAssertGreaterThanOrEqual(selection.bounds(for: page).minY, 60 - 0.5,
                                            "\(label), page \(index + 1): «\(text)»", file: file, line: line)
            }
        }
    }

    private var tableHead: String {
        ["export.col.date", "export.col.weight", "export.col.height", "export.col.head"].map(\.l).joined(separator: " ")
    }

    // MARK: Pages

    func testLongReportPrintsEveryRowWholeWithTheHeadOnEveryPage() throws {
        try inLanguage(.en) {
            let long = try report(extraWeighings: 120)
            XCTAssertGreaterThan(long.document.pageCount, 2)
            let pages = texts(long.document)
            assertEveryRowPrintedOnce(long.weights, in: pages)
            assertHeadOnEveryPageWithRows(tableHead, long.weights, in: pages)
            for (index, page) in pages.enumerated() {
                XCTAssertTrue(page.contains(String(format: "report.pdf.page_fmt".l, index + 1, long.document.pageCount)),
                              "page \(index + 1) has no «Page N of M»")
            }
        }
    }

    func testNoBodyLineEntersTheFooterBand() throws {
        try inLanguage(.en) {
            for extra in [0, 30, 120] {
                try assertNoBodyLineInFooterBand(try report(extraWeighings: extra).document, "\(extra) extra")
            }
        }
    }

    /// Forty long questions do not fit a page: they break between two of them,
    /// each printed once, with its number.
    func testQuestionsTallerThanAPageBreakBetweenThemAndKeepTheirNumbers() throws {
        try inLanguage(.en) {
            let filler = String(repeating: "How much vitamin D and for how long. ", count: 6)
            let questions = (1...40).map { "Tag\($0)x \(filler)" }
            let document = try report(extraWeighings: 0, questions: questions).document
            XCTAssertGreaterThan(document.pageCount, 2)
            try assertNoBodyLineInFooterBand(document, "questions")
            let whole = texts(document).joined(separator: "\n")
            for number in 1...40 {
                XCTAssertEqual(whole.components(separatedBy: "\(number). Tag\(number)x").count - 1, 1, "question \(number)")
            }
        }
    }

    /// A row taller than a page is the one thing that still slices; what follows
    /// it starts after all of its pages, and no page is drawn over another.
    func testARowTallerThanAPageTakesItsPagesAndTheRestFollows() throws {
        let tall = String(repeating: "<p>tall line</p>", count: 200)
        let document = PagedPDF.Document(head: "<html><body>", items: [
            .block("<p>first</p>"), .block(tall), .block("<p>after</p>"),
        ])
        let pdf = try XCTUnwrap(PDFDocument(data: PagedPDF.data(document)))
        XCTAssertGreaterThan(pdf.pageCount, 2)
        let pages = texts(pdf)
        XCTAssertTrue(pages[0].contains("first"))
        XCTAssertTrue(try XCTUnwrap(pages.last).contains("after"))
        // At least: a line sliced at this row's page edge reads twice.
        XCTAssertGreaterThanOrEqual(pages.joined().components(separatedBy: "tall line").count - 1, 200)
    }

    func testLongExportPrintsEveryRowWholeWithTheHeadOnEveryPage() throws {
        try inLanguage(.en) {
            let (document, weights) = try exportPDF(rows: 150)
            XCTAssertGreaterThan(document.pageCount, 2)
            let pages = texts(document)
            assertEveryRowPrintedOnce(weights, in: pages)
            assertHeadOnEveryPageWithRows(tableHead, weights, in: pages)
        }
    }

    /// Each page is its own table: a long note on a later page must not move the
    /// columns of the earlier ones, not even one with no place to wrap.
    func testExportColumnsStayPutFromPageToPage() throws {
        try inLanguage(.en) {
            let long = String(repeating: "A long note that takes a good part of the line. ", count: 2)
                + String(repeating: "x", count: 90)
            let diapers = (0..<120).map { index in
                DiaperEntry(time: Date().addingTimeInterval(-Double(index) * 3600), type: .wet,
                            notes: index > 90 ? long : nil)
            }
            let data = ExportGenerator.pdfData(baby: nil, feedings: [], sleeps: [], diapers: diapers, growths: [],
                                               events: [], categories: [.diapers], range: .all)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertGreaterThan(document.pageCount, 2)
            for head in ["export.col.time", "export.col.notes"].map(\.l) {
                let places = document.findString(head, withOptions: []).compactMap { selection -> CGFloat? in
                    selection.pages.first.map { selection.bounds(for: $0).minX.rounded() }
                }
                XCTAssertEqual(places.count, document.pageCount, head)
                XCTAssertEqual(Set(places).count, 1, "«\(head)» moves between pages: \(places)")
            }
        }
    }

    /// Without them the columns come out equal: a short time takes as much as a long note.
    func testExportColumnWidthsFollowTheLongestText() {
        let note = String(repeating: "x", count: 60)
        XCTAssertEqual(ExportGenerator.columnWidths(headers: ["Time", "Notes"], rows: [["08:00", note]]),
                       "<colgroup><col style=\"width: 18.6%\"><col style=\"width: 81.4%\"></colgroup>")
        let page = ExportGenerator.buildHTML(baby: nil, feedings: [], sleeps: [],
                                             diapers: [DiaperEntry(time: Date(), type: .wet, notes: note)],
                                             growths: [], events: [], categories: [.diapers], range: .all)
        XCTAssertTrue(page.contains("<colgroup>"), "the table uses them")
    }

    /// The report's pages are separate tables too: the weights stay in one column.
    func testReportColumnsStayPutFromPageToPage() throws {
        try inLanguage(.en) {
            let long = try report(extraWeighings: 40)
            XCTAssertGreaterThan(long.document.pageCount, 1)
            let places = plain(long.weights).compactMap { weight -> CGFloat? in
                let number = String(weight.prefix { $0 != " " })
                guard let found = long.document.findString(number, withOptions: []).first,
                      let page = found.pages.first else { return nil }
                return found.bounds(for: page).minX.rounded()
            }
            XCTAssertEqual(places.count, long.weights.count)
            XCTAssertEqual(Set(places).count, 1, "the weight column moves between pages: \(Set(places))")
        }
    }

    /// Two tables on one page keep their own heads: the second opens where the first closes.
    func testAdjacentExportTablesEachPrintTheirOwnHead() throws {
        try inLanguage(.en) {
            let start = Date().addingTimeInterval(-86_400)
            let sleeps = (0..<60).map { SleepEntry(startTime: start.addingTimeInterval(Double($0) * 60), type: .nap) }
            let weights = (0..<60).map { 6 + Double($0) * 0.01 }
            let growths = weights.enumerated().map { offset, value in
                GrowthEntry(date: start.addingTimeInterval(Double(offset) * 60), weightKg: value)
            }
            let data = ExportGenerator.pdfData(baby: nil, feedings: [], sleeps: sleeps, diapers: [], growths: growths,
                                               events: [], categories: [.sleep, .growth], range: .all)
            let pages = texts(try XCTUnwrap(PDFDocument(data: data)))
            let sleepHead = "export.col.start".l
            let growthHead = "export.col.weight".l
            let turn = try XCTUnwrap(pages.firstIndex { $0.contains(growthHead) })
            XCTAssertTrue(pages[..<turn].allSatisfy { $0.contains(sleepHead) }, "a sleep page lost its head")
            // Every growth row, also those on the page where the sleep table ends.
            assertHeadOnEveryPageWithRows(growthHead, weights.map(ReportFormat.kg), in: pages)
            XCTAssertFalse(pages[(turn + 1)...].contains { $0.contains(sleepHead) }, "growth rows under the sleep head")
        }
    }

    /// The section moves whole when it fits a page of its own: the heading and its
    /// questions print together, even though a part would fit on the page before.
    func testQuestionsThatFitAPageMoveToItWhole() throws {
        try inLanguage(.en) {
            let filler = String(repeating: "How much vitamin D and for how long. ", count: 3)
            let questions = (1...8).map { "Tag\($0)x \(filler)" }
            for extra in stride(from: 0, through: 40, by: 4) {
                let pages = texts(try report(extraWeighings: extra, questions: questions).document)
                let heading = "report.pdf.questions".l
                let first = try XCTUnwrap(pages.firstIndex { $0.contains(heading) }, "\(extra) extra")
                for number in 1...8 { XCTAssertTrue(pages[first].contains("Tag\(number)x"), "\(extra) extra, question \(number)") }
            }
        }
    }

    /// Past the row count that skips the whole layout, one that fits is still one page.
    func testAManyRowDocumentThatFitsAPageStaysOnOne() throws {
        let rows = PagedPDF.Rows(opening: "<p>", continuation: { _ in "<p>" }, closing: "</p>",
                                 rows: Array(repeating: "<span>x </span>", count: 150))
        let document = PagedPDF.Document(head: "<html><body>", items: [.rows(rows)])
        XCTAssertEqual(try XCTUnwrap(PDFDocument(data: PagedPDF.data(document))).pageCount, 1)
    }

    /// Past that count the pages come from the search alone, and wrapped notes make
    /// them uneven: still every row whole, once.
    func testALongExportWithWrappedNotesKeepsEveryRowWhole() throws {
        try inLanguage(.en) {
            let long = String(repeating: "A long note that wraps over a few lines of its cell. ", count: 3)
            let tags = (0..<320).map { "Tag\($0)x" }
            let diapers = tags.enumerated().map { index, tag in
                DiaperEntry(time: Date().addingTimeInterval(-Double(index) * 3600), type: .wet,
                            notes: index % 7 == 0 ? "\(tag) \(long)" : tag)
            }
            let data = ExportGenerator.pdfData(baby: nil, feedings: [], sleeps: [], diapers: diapers, growths: [],
                                               events: [], categories: [.diapers], range: .all)
            let document = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertGreaterThan(document.pageCount, 5)
            let pages = texts(document)
            let whole = pages.joined(separator: "\n")
            for tag in tags { XCTAssertEqual(whole.components(separatedBy: tag + " ").count + whole.components(separatedBy: tag + "\n").count - 2, 1, tag) }
            assertHeadOnEveryPageWithRows("export.col.notes".l, tags, in: pages)
        }
    }

    // MARK: Page ranges

    func testRangesTakeAsManyAtomsAsFit() {
        var probes = 0
        let ranges = PagedPDF.ranges(count: 20, hint: 5) { range in
            probes += 1
            return range.count <= 7
        }
        XCTAssertEqual(ranges, [0..<7, 7..<14, 14..<20])
        XCTAssertLessThan(probes, 10, "the second page and the last one start from the size of the first")
    }

    /// One layout a page once the pages settle: this is what a long export costs.
    func testRangesProbeOncePerPageOnceTwoPagesAgree() {
        var probes = 0
        let ranges = PagedPDF.ranges(count: 1000, hint: 30) { range in
            probes += 1
            return range.count <= 28
        }
        XCTAssertEqual(ranges.dropLast().map(\.count), Array(repeating: 28, count: 35))
        XCTAssertLessThan(probes, 35 + 10, "a settled page lays out once")
    }

    /// The first page is short of its headers, and the hint may match it by chance:
    /// the second page must still look for all it can hold.
    func testAFirstPageMatchingTheHintDoesNotHoldTheRestDown() {
        let ranges = PagedPDF.ranges(count: 100, hint: 10) { range in
            range.count <= (range.lowerBound == 0 ? 10 : 30)
        }
        XCTAssertEqual(ranges.prefix(3).map(\.count), [10, 30, 30])
    }

    /// Rows settle at the height of what came before, and a taller stretch still fits.
    func testASettledPageThatNoLongerFitsShrinks() {
        let ranges = PagedPDF.ranges(count: 200, hint: 20) { range in
            // Rows from 60 on are twice as tall.
            range.reduce(0) { $0 + ($1 >= 60 ? 2 : 1) } <= 20
        }
        XCTAssertEqual(ranges.prefix(5).map(\.count), [20, 20, 20, 10, 10])
        XCTAssertEqual(ranges.map(\.count).reduce(0, +), 200)
    }

    func testRangesGiveAnAtomTooTallForAPageItsOwnPage() {
        let ranges = PagedPDF.ranges(count: 5, hint: 2) { !$0.contains(2) && $0.count <= 2 }
        XCTAssertEqual(ranges, [0..<2, 2..<3, 3..<5])
    }

    func testRangesCoverEveryAtomOnceWhateverTheHint() {
        for hint in [0, 1, 3, 50] {
            let ranges = PagedPDF.ranges(count: 41, hint: hint) { $0.count <= 9 }
            XCTAssertEqual(ranges.map(\.count).reduce(0, +), 41, "hint \(hint)")
            XCTAssertEqual(ranges.first?.lowerBound, 0)
            for (one, next) in zip(ranges, ranges.dropFirst()) { XCTAssertEqual(one.upperBound, next.lowerBound) }
            XCTAssertEqual(ranges.dropLast().map(\.count), Array(repeating: 9, count: 4), "hint \(hint)")
        }
    }

    // MARK: Medications

    /// The medications table in a rendered PDF, in every language: each row
    /// once and searchable, and the head on every page the table reaches.
    func testMedicationsPrintEveryRowOnceWithTheHeadOnEveryPage() throws {
        let names = (1...70).map { String(format: "Medicine %02d", $0) }
        for language in [SupportedLanguage.en, .ru, .es] {
            try inLanguage(language) {
                let pages = texts(try report(extraWeighings: 0, medicationNames: names).document)
                XCTAssertGreaterThan(pages.count, 1, "\(language): the table should reach a second page")
                assertEveryRowPrintedOnce(names, in: pages)
                let head = "medication.report_col_dose".l.replacingOccurrences(of: "\u{A0}", with: " ")
                assertHeadOnEveryPageWithRows(head, names, in: pages)
                XCTAssertTrue(pages.joined().contains("medication.report_title".l), "\(language)")
            }
        }
    }

    // MARK: Text layer

    func testRussianTextLayerHoldsRealLetters() throws {
        try inLanguage(.ru) {
            let reportText = texts(try report(extraWeighings: 30).document).joined(separator: "\n")
            let exportText = texts(try exportPDF(rows: 30).document).joined(separator: "\n")
            for (name, text) in [("report", reportText), ("export", exportText)] {
                XCTAssertFalse(text.unicodeScalars.contains { $0.value == 0x138 }, "\(name) has U+0138")
                XCTAssertTrue(text.contains("кг"), "\(name): a search for «кг» finds nothing")
            }
            XCTAssertTrue(reportText.contains("brand.name".l), "the footnote and the footer name the app")
        }
    }

    /// A ligature reaches the text layer as one character (U+FB01), and a search
    /// for «fine» misses it.
    func testNoLanguageGetsForeignCharactersInTheTextLayer() throws {
        for language in [SupportedLanguage.en, .es] {
            try inLanguage(language) {
                let text = texts(try report(extraWeighings: 30).document).joined(separator: "\n")
                XCTAssertFalse(text.unicodeScalars.contains { [0x138, 0xFB01, 0xFB02].contains($0.value) },
                               "\(language): a substituted character")
                XCTAssertTrue(text.contains("Is it fine"), "\(language): the question is not searchable")
            }
        }
    }

    // MARK: Other scripts and emoji

    /// The pinned face has no Chinese or Thai, and the engine has no fallback of its
    /// own: only the named list keeps these from printing a boxed «?», which reads
    /// back as a NUL or a replacement character.
    func testOtherScriptsDrawThroughTheNamedFallback() throws {
        try inLanguage(.en) {
            let words = ["你好吗", "こんにちは", "안녕하세요", "สวัสดี", "नमस्ते", "Ελληνικά", "Tiếng Việt", "✓ ✗ + − ÷ ? !"]
            let document = try report(extraWeighings: 0, name: "美玲 🌸", questions: words + ["😀👶"]).document
            let lines = texts(document).joined(separator: "\n").components(separatedBy: "\n")
                // The footer is drawn by UIKit, whose emoji read back as a NUL though they print.
                .filter { !$0.hasPrefix("brand.name".l + " ·") }
            let body = lines.joined(separator: "\n")
            for word in words + ["美玲"] { XCTAssertTrue(body.contains(word), word) }
            XCTAssertFalse(body.unicodeScalars.contains { $0.value == 0 || $0.value == 0xFFFD }, "a boxed glyph: \(body)")
            XCTAssertFalse(lines.contains { $0.hasPrefix("\(words.count + 1).") }, "a question of emoji alone prints no empty line")
        }
    }

    func testEmojiLeaveTheHTMLAndTheTextAroundThemStays() {
        for (raw, printed) in [("Mia 🌸", "Mia "), ("🇷🇺 flag", " flag"), ("👩‍👧 two", " two"), ("👍🏽ok", "ok"),
                               ("🏳️‍🌈 pride", " pride"), ("🌶️ hot", " hot"), ("a & b", "a &amp; b")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
    }

    /// Unicode tags all of these as emoji-capable: a filter on that tag alone would
    /// eat a dose. They stay as text; only the request for the emoji form goes.
    func testNothingButEmojiLeavesTheHTML() {
        for kept in ["2 мл", "0 1 2 3 4 5 6 7 8 9", "#3", "* note", "© ® ™", "Weight: ", " · ", "«кг»", "你好", "→ ↑ ≥ ±"] {
            XCTAssertEqual(ExportGenerator.htmlEscape(kept), kept, kept)
        }
        for (raw, printed) in [("1️⃣ one", "1 one"), ("#️⃣", "#"), ("©️ 2026", "© 2026"), ("❤️ heart", "❤ heart"),
                               ("\u{1F51F} капель", "10 капель"), ("5\u{1F51F}", "5 10")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
    }

    /// A closed list: the marks that say yes or no become text, any other emoji leaves.
    func testMarksThatCarryAnAnswerBecomeTextAndNoOtherEmojiDoes() {
        for (raw, printed) in [("Iron ❌, Vit D ✅", "Iron ✗, Vit D ✓"), ("стул ➖, рвота ➕", "стул −, рвота +"),
                               ("❎", "✗"), ("6 ➗ 2", "6 ÷ 2"), ("Можно купать❓", "Можно купать?"), ("Да❔", "Да?"),
                               ("Важно❗", "Важно!"), ("Важно❕", "Важно!"), ("✅\u{FE0F}", "✓")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
        for (raw, printed) in [("⛔ stop", " stop"), ("🆗 ok", " ok"), ("⭐ star", " star"), ("🚫 no", " no")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
    }

    /// A skin tone or a joined emoji clings to the letter or digit before it, in one
    /// grapheme: only the emoji goes.
    func testAnEmojiClingingToALetterTakesNothingWithIt() {
        for (raw, printed) in [("2\u{1F3FD} мл", "2 мл"), ("мл\u{1F3FD} 5", "мл 5"), ("ok\u{1F3FB}", "ok"),
                               ("©\u{200D}\u{1F338} 2026", "© 2026")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
    }

    /// Two numbers must not fuse into a third, and a sentence keeps its punctuation tight.
    func testARemovedEmojiNeverJoinsItsNeighbours() {
        for (raw, printed) in [("5\u{1F37C}10 мл", "5 10 мл"), ("38\u{1F321}\u{FE0F}кашель", "38 кашель"),
                               ("Mia\u{1F338}Rose", "Mia Rose"), ("Ok\u{1F37C}?", "Ok?"), ("\u{1F338}Mia", "Mia"),
                               ("2\u{1F3FD}5", "2 5")] {
            XCTAssertEqual(ExportGenerator.htmlEscape(raw), printed, raw)
        }
    }

    /// An emoji newer than the phone's Unicode tables reads as unassigned: it still goes.
    func testAnEmojiNewerThanTheTablesLeavesToo() {
        XCTAssertEqual(ExportGenerator.htmlEscape("a\u{1FAFF} b"), "a b")
        XCTAssertEqual(ExportGenerator.htmlEscape("\u{1F100} kept"), "\u{1F100} kept", "a text symbol in the same blocks")
    }

    func testInvisibleResidueCountsAsBlank() {
        XCTAssertTrue(PagedPDF.isBlank(PagedPDF.withoutEmoji("\u{200D}\u{1F600}")))
        XCTAssertTrue(PagedPDF.isBlank(" \n\u{FE0E}"))
        XCTAssertFalse(PagedPDF.isBlank("\u{200D}a"))
    }

    func testAnExportNoteOfEmojiAlonePrintsTheDash() throws {
        let diaper = DiaperEntry(time: Date(), type: .wet, notes: "\u{1F600}")
        let page = ExportGenerator.buildHTML(baby: nil, feedings: [], sleeps: [], diapers: [diaper], growths: [],
                                             events: [], categories: [.diapers], range: .all)
        XCTAssertFalse(page.contains("<td></td>"), "an empty cell")
        XCTAssertTrue(page.contains("<td>—</td></tr>"), "the dash an absent note gets")
    }

    func testAfterTheEmojiGoNothingEmptyIsLeft() throws {
        try inLanguage(.en) {
            let some = try report(extraWeighings: 0, name: "🌸", questions: ["😀", "Is it fine?", "👶🍼", "And this?"]).html
            XCTAssertFalse(some.contains("<p class=\"name\">"), "a name of emoji alone leaves no empty line")
            XCTAssertTrue(some.contains("<ol><li>Is it fine?</li><li>And this?</li></ol>"), "the list renumbers")

            let none = try report(extraWeighings: 0, questions: ["😀", "  👶 "]).html
            XCTAssertFalse(none.contains("<ol>"), "no question left, no list")
            XCTAssertFalse(none.contains("report.pdf.questions".l), "no question left, no heading")
        }
    }

    /// UIKit draws the report's footer, and in a PDF it prints an emoji as a box too.
    func testAnEmojiInTheNameLeavesTheFooterToo() throws {
        try inLanguage(.en) {
            let some = try XCTUnwrap(report(extraWeighings: 0, name: "美玲 🌸").document.string)
            XCTAssertFalse(some.contains("🌸"))
            XCTAssertTrue(some.contains("\("brand.name".l) · 美玲 · "), "no space stays before the separator")

            let none = try XCTUnwrap(report(extraWeighings: 0, name: "🌸").document.string)
            XCTAssertFalse(none.contains("🌸"))
            XCTAssertTrue(none.contains("\("brand.name".l) · "))
            XCTAssertNil(none.range(of: "·\\s*·", options: .regularExpression), "a name of emoji alone leaves no gap")
        }
    }

    /// A sign with a text form stays in the name, so the footer needs a face for it:
    /// UIKit's own fallback picks the colour font, printed as a box and a gap.
    func testASignInTheNameDrawsInTheFooter() throws {
        try inLanguage(.en) {
            let names = [
                ("Mia ❤️", "Mia ❤"),
                ("Mia ☀️ ✅", "Mia ☀ ✓"),
                ("Mia ❤ ♥ ☀ ☺ ✈ ☎ ⚠ ✉ ✔ ☑", "Mia ❤ ♥ ☀ ☺ ✈ ☎ ⚠ ✉ ✔ ☑")
            ]
            for (typed, printed) in names {
                let document = try report(extraWeighings: 0, name: typed).document
                XCTAssertFalse(fontNames(document).contains { $0.contains("LastResort") }, typed)
                let text = try XCTUnwrap(document.string)
                XCTAssertTrue(text.contains("\("brand.name".l) · \(printed) · "), "no gap in the footer for \(typed)")
            }

            let scripts = try report(extraWeighings: 0, name: "美玲 سارة สมชาย").document
            XCTAssertFalse(fontNames(scripts).contains { $0.contains("LastResort") })
        }
    }

    /// The left of the footer stays one line and is cut short of the page number.
    /// UIKit draws its «…» with no character behind it, so the text layer simply
    /// ends at the cut: the period after the name is gone, the page number whole.
    func testALongNameIsCutOnOneFooterLineBeforeThePageNumber() throws {
        try inLanguage(.en) {
            let document = try report(extraWeighings: 0, name: String(repeating: "Mia ❤ ", count: 40)).document
            let page = try XCTUnwrap(document.page(at: 0))
            let band = CGRect(x: 0, y: 0, width: page.bounds(for: .mediaBox).width, height: 60)
            let lines = try XCTUnwrap(page.selection(for: band)).selectionsByLine()
            XCTAssertEqual(lines.count, 2, "the left text and the page number, one line each")

            let number = String(format: "report.pdf.page_fmt".l, 1, document.pageCount)
            let left = try XCTUnwrap(lines.first { $0.string?.hasPrefix("brand.name".l) == true })
            let right = try XCTUnwrap(lines.first { $0.string == number })
            XCTAssertEqual(left.bounds(for: page).midY, right.bounds(for: page).midY, accuracy: 3, "one baseline")
            XCTAssertLessThan(left.bounds(for: page).maxX, right.bounds(for: page).minX)
            XCTAssertEqual(left.string?.components(separatedBy: " · ").count, 2, "cut inside the name")
        }
    }

    func testEveryCharacterANameKeepsHasAFaceInTheFooter() {
        let font = PagedPDF.font(ofSize: 9) as CTFont
        for value in UInt32(0)...0x1FAFF {
            guard let scalar = Unicode.Scalar(value), scalar.properties.isEmoji else { continue }
            let kept = PagedPDF.withoutEmoji(String(scalar))
            guard !kept.isEmpty else { continue }
            let range = CFRange(location: 0, length: kept.utf16.count)
            let face = CTFontCopyPostScriptName(CTFontCreateForString(font, kept as CFString, range)) as String
            XCTAssertFalse(["AppleColorEmoji", "LastResort"].contains(face), "U+\(String(value, radix: 16)) in \(face)")
        }
    }

    /// The faces a file embeds, read from each page's resources.
    private func fontNames(_ document: PDFDocument) -> Set<String> {
        var names = Set<String>()
        for index in 0..<document.pageCount {
            var resources: CGPDFDictionaryRef?
            var fonts: CGPDFDictionaryRef?
            guard let page = document.page(at: index)?.pageRef?.dictionary,
                  CGPDFDictionaryGetDictionary(page, "Resources", &resources), let resources,
                  CGPDFDictionaryGetDictionary(resources, "Font", &fonts), let fonts else { continue }
            CGPDFDictionaryApplyBlock(fonts, { _, object, _ in
                var font: CGPDFDictionaryRef?
                var name: UnsafePointer<CChar>?
                if CGPDFObjectGetValue(object, .dictionary, &font), let font,
                   CGPDFDictionaryGetName(font, "BaseFont", &name), let name {
                    names.insert(String(cString: name))
                }
                return true
            }, nil)
        }
        return names
    }

    /// The removal is the PDF's alone: the file name, the CSV and the store keep
    /// what the parent typed.
    func testEmojiStayEverywhereButThePDF() throws {
        try inLanguage(.en) {
            XCTAssertTrue(DoctorReportPDF.fileName(babyName: "🌸", date: Date()).contains("🌸"))
            let note = DiaperEntry(time: Date(), type: .wet, notes: "🌸 ok")
            let csv = ExportGenerator.csvString(feedings: [], sleeps: [], diapers: [note], growths: [], events: [],
                                                categories: [.diapers])
            XCTAssertTrue(csv.contains { $0.1.contains("🌸 ok") }, "the CSV keeps the note as typed")
            let (baby, _, container) = try seeded()
            baby.name = "🌸"
            let page = ExportGenerator.buildHTML(baby: baby, feedings: [], sleeps: [], diapers: [], growths: [],
                                                 events: [], categories: [.growth], range: .all)
            XCTAssertEqual(baby.name, "🌸")
            XCTAssertTrue(page.contains("baby.default_name".l), "the export's title still names someone")
            withExtendedLifetime(container) {}
        }
    }
}

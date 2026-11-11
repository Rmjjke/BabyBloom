import XCTest
@testable import BabyBloom

final class ExportGeneratorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Deterministic language for assertions on localized output.
        LocalizationManager.shared.setLanguage("en")
    }

    // MARK: - CSV escaping

    func testCSVEscapesQuotesAndCommas() {
        // Notes contain a comma, double-quotes and a newline — all of which must
        // trigger RFC-4180 escaping (wrap in quotes, double the inner quotes).
        let diaper = DiaperEntry(
            time: Date(),
            type: .wet,
            color: .yellow,
            notes: "a,b \"c\"\nd"
        )
        let files = ExportGenerator.csvString(
            feedings: [], sleeps: [], diapers: [diaper], growths: [], events: [],
            categories: [.diapers]
        )
        let content = files.first { $0.name == "diapers.csv" }!.content

        XCTAssertTrue(content.contains("\"a,b \"\"c\"\"\nd\""),
                      "Notes field must be quoted with inner quotes doubled")
        // A field without special characters must NOT be wrapped in quotes.
        XCTAssertEqual(ExportGenerator.csvField("plain"), "plain")
    }

    func testACarriageReturnIsQuotedToo() {
        XCTAssertEqual(ExportGenerator.csvField("a\rb"), "\"a\rb\"")
    }

    /// Excel takes a CSV for UTF-8 only behind a byte-order mark; the text after
    /// it must read back whole, a comma inside a field included.
    func testAUkrainianCSVStartsWithABOMAndReadsBack() throws {
        LocalizationManager.shared.setLanguage("uk")
        addTeardownBlock { LocalizationManager.shared.setLanguage("en") }
        let diaper = DiaperEntry(time: Date(), type: .wet, color: .yellow, notes: "Годування, ніч")
        let content = ExportGenerator.csvString(
            feedings: [], sleeps: [], diapers: [diaper], growths: [], events: [],
            categories: [.diapers]
        ).first { $0.name == "diapers.csv" }!.content

        let url = try XCTUnwrap(ExportGenerator.writeTempCSV(name: "uk-bom-test.csv", content: content))
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])

        let text = try XCTUnwrap(String(data: data.dropFirst(3), encoding: .utf8))
        XCTAssertEqual(text, content)
        XCTAssertTrue(text.contains("\"Годування, ніч\""))
        XCTAssertTrue(text.hasPrefix(ExportGenerator.csvField("export.csv.date".l)))
    }

    // MARK: - CSV localization

    func testCSVUsesLocalizedValues() {
        LocalizationManager.shared.setLanguage("en")
        let feeding = FeedingEntry(startTime: Date(), type: .formula, side: nil, volumeML: 120)
        let files = ExportGenerator.csvString(
            feedings: [feeding], sleeps: [], diapers: [], growths: [], events: [],
            categories: [.feeding]
        )
        let content = files.first!.content

        // Type column must use the localized display name, not the raw enum value.
        let localizedType = FeedingEntry.FeedingType.formula.displayName.l
        XCTAssertEqual(localizedType, "Formula")
        XCTAssertTrue(content.contains("Formula"), "CSV must contain localized value")

        // Header row must be localized too.
        XCTAssertTrue(content.contains("export.csv.date".l))
        XCTAssertTrue(content.contains("export.csv.type".l))
    }

    // MARK: - Average per day (the report's rule)

    private var calendar: Calendar { .current }

    /// Noon of `daysAgo` days before the fixed `now`, so no entry sits on a midnight edge.
    private func noon(_ daysAgo: Int, from now: Date) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .hour, value: 12, to: day)!
    }

    private var fixedNow: Date {
        DateComponents(calendar: calendar, year: 2026, month: 10, day: 28, hour: 9).date!
    }

    func testAvgPerDayDividesByDaysWithEntries() {
        let now = fixedNow
        // 4 feeds one day, 2 another, a silent day between: (4+2) / 2 days = 3, not 6 / 3.
        let dates = (0..<4).map { _ in noon(3, from: now) } + [noon(1, from: now), noon(1, from: now)]

        let avg = ExportGenerator.averagePerDay(dates: dates, range: .all, now: now)

        XCTAssertEqual(avg!, 3.0, accuracy: 0.0001)
    }

    func testAvgPerDayIgnoresAPartialToday() {
        let now = fixedNow
        let finished = [noon(2, from: now), noon(2, from: now), noon(1, from: now), noon(1, from: now)]
        let today = [now.addingTimeInterval(-60)]

        let without = ExportGenerator.averagePerDay(dates: finished, range: .all, now: now)
        let with = ExportGenerator.averagePerDay(dates: finished + today, range: .all, now: now)

        XCTAssertEqual(without!, 2.0, accuracy: 0.0001)
        // Today's feed is counted nowhere in the rate: it must not lower or raise it.
        XCTAssertEqual(with!, 2.0, accuracy: 0.0001)
    }

    func testAvgPerDayIsNilWithoutAFinishedDay() {
        let now = fixedNow
        XCTAssertNil(ExportGenerator.averagePerDay(dates: [], range: .all, now: now))
        // Everything logged today: no finished day to average over.
        XCTAssertNil(ExportGenerator.averagePerDay(dates: [now.addingTimeInterval(-60)], range: .all, now: now))
    }

    func testAvgPerDayBoundedRangeDropsEntriesBeforeIt() {
        let now = fixedNow
        // 40 days back is outside `.week`; only the two in-range feeds on one day count.
        let dates = [noon(40, from: now), noon(2, from: now), noon(2, from: now)]

        let avg = ExportGenerator.averagePerDay(dates: dates, range: .week, now: now)

        XCTAssertEqual(avg!, 2.0, accuracy: 0.0001)
    }

    func testAvgPerDayBoundedRangeSkipsItsCutFirstDay() {
        // `.week` starts at «now − 7 days» mid-day: that day holds only the
        // feeds after the cut, so it would drag the rate down. 8 a day on the
        // six whole days after it, 2 late on the cut day.
        let now = fixedNow
        let cal = calendar
        let cutDay = cal.date(byAdding: .day, value: -7, to: now)!
        let late = cal.date(bySettingHour: 23, minute: 0, second: 0, of: cutDay)!
        XCTAssertGreaterThan(late, cutDay, "the late feeds sit after the cut")
        let whole = (1...6).flatMap { n in (0..<8).map { _ in noon(n, from: now) } }

        let avg = ExportGenerator.averagePerDay(dates: whole + [late, late], range: .week, now: now)

        XCTAssertEqual(avg!, 8.0, accuracy: 0.0001)
    }

    func testFileNamePartIsSafeAndNeverBlank() {
        XCTAssertEqual(ExportGenerator.fileNamePart("Mia/Ann: Jr"), "MiaAnn Jr")
        XCTAssertEqual(ExportGenerator.fileNamePart("  Mia \n"), "Mia")
        XCTAssertEqual(ExportGenerator.fileNamePart("   "), "baby.default_name".l)
        XCTAssertEqual(ExportGenerator.fileNamePart(String(repeating: "Я", count: 200)).count, 60)
        // Cut at 60 inside a gap, the name must not end in a space before « – ».
        XCTAssertEqual(ExportGenerator.fileNamePart(String(repeating: "a", count: 59) + " b"),
                       String(repeating: "a", count: 59))
        // An emoji family and a flag keep their joiners and tags; a bidi override goes.
        XCTAssertEqual(ExportGenerator.fileNamePart("Mia 👨‍👩‍👧‍👦"), "Mia 👨‍👩‍👧‍👦")
        XCTAssertEqual(ExportGenerator.fileNamePart("Mia 🏴󠁧󠁢󠁳󠁣󠁴󠁿"), "Mia 🏴󠁧󠁢󠁳󠁣󠁴󠁿")
        XCTAssertEqual(ExportGenerator.fileNamePart("Mia\u{202E}fdp"), "Miafdp")
    }

    // MARK: - File names

    /// Noon, so the day in the name is the same whatever zone the suite runs in.
    private var fileDay: Date {
        DateComponents(calendar: calendar, year: 2026, month: 11, day: 1, hour: 12).date!
    }

    func testTheExportPDFIsNamedAllEntries() {
        defer { LocalizationManager.shared.setLanguage(.en) }
        let expected: [(SupportedLanguage, String)] = [
            (.en, "All entries – Mia Rose – 2026-11-01.pdf"),
            (.ru, "Все записи – Mia Rose – 2026-11-01.pdf"),
            (.es, "Todos los registros – Mia Rose – 2026-11-01.pdf"),
        ]
        for (language, name) in expected {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(ExportGenerator.pdfFileName(babyName: "Mia Rose", date: fileDay), name)
        }
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(ExportGenerator.pdfFileName(babyName: "Mia/Ann: Jr", date: fileDay),
                       "All entries – MiaAnn Jr – 2026-11-01.pdf")
        XCTAssertEqual(ExportGenerator.pdfFileName(babyName: "  ", date: fileDay),
                       "All entries – Baby – 2026-11-01.pdf")
    }

    func testCSVFileNamesKeepTheirShape() {
        XCTAssertEqual(ExportGenerator.csvFileName(babyName: "Mia Rose", date: fileDay, file: "feeding.csv"),
                       "Mia_Rose_2026-11-01_feeding.csv")
        XCTAssertEqual(ExportGenerator.csvFileName(babyName: "", date: fileDay, file: "sleep.csv"),
                       "Baby_2026-11-01_sleep.csv")
    }

    /// A long name gives way inside the name only: the day and the extension
    /// stay, the whole fits the 255 bytes a file name may take, and the file
    /// is written. 60 family emoji are 1,500 bytes.
    func testEveryFileNameKeepsItsDateWithinTheByteLimit() {
        let family = "👨‍👩‍👧‍👦"
        let whole = [String(repeating: "Abcdefghij", count: 6), String(repeating: "Александра", count: 6)]
        let emoji = [String(repeating: family, count: 60), String(repeating: family, count: 20)]
        let makers: [(kind: String, end: String, make: (String) -> String)] = [
            ("export", ".pdf", { ExportGenerator.pdfFileName(babyName: $0, date: self.fileDay) }),
            ("report", ".pdf", { DoctorReportPDF.fileName(babyName: $0, date: self.fileDay) }),
            ("csv", "_feeding.csv", { ExportGenerator.csvFileName(babyName: $0, date: self.fileDay, file: "feeding.csv") }),
        ]
        defer {
            ExportGenerator.cleanupExports()
            LocalizationManager.shared.setLanguage(.en)
        }
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            for name in whole + emoji {
                for maker in makers {
                    let file = maker.make(name)
                    let label = "\(language) \(maker.kind) \(name.utf8.count) bytes: \(file)"
                    XCTAssertLessThanOrEqual(file.utf8.count, 255, label)
                    XCTAssertTrue(file.contains("2026-11-01"), label)
                    XCTAssertTrue(file.hasSuffix(maker.end), label)
                    if whole.contains(name) {
                        XCTAssertTrue(file.contains(maker.kind == "csv" ? ExportGenerator.fileSlug(name) : name), label)
                    } else {
                        // Whole emoji only: no half of a family left behind.
                        XCTAssertTrue(file.contains(family), label)
                        let rest = file.replacingOccurrences(of: family, with: "").unicodeScalars
                        XCTAssertFalse(rest.contains { $0.value == 0x200D || $0.properties.isEmojiPresentation }, label)
                    }
                    XCTAssertNotNil(ExportGenerator.writeTempFile(name: file, data: Data("x".utf8)), label)
                }
            }
        }
    }

    /// The tile's label says «a day»; a «/day» after the figure said it twice.
    func testTheFeedsADayTileIsTheBareFigure() {
        defer { LocalizationManager.shared.setLanguage(.en) }
        let now = Date()
        let feeds = [noon(2, from: now), noon(2, from: now), noon(1, from: now), noon(1, from: now)].map { start in
            let feed = FeedingEntry(startTime: start, type: .formula, side: nil, volumeML: 90)
            feed.endTime = start.addingTimeInterval(15 * 60)
            return feed
        }
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = ExportGenerator.buildHTML(
                baby: nil, feedings: feeds, sleeps: [], diapers: [], growths: [], events: [],
                categories: [.feeding], range: .all)
            XCTAssertTrue(page.contains("<span class=\"val\">\(WeeklyFormat.perDay(2))</span><span class=\"lbl\">\("export.summary.avg".l)</span>"),
                          "\(language)")
            XCTAssertFalse(page.contains("/\("filter.day".l.lowercased())"), "\(language)")
        }
    }

    func testTheFeedCountLeavesOutARunningFeed() {
        let running = FeedingEntry(startTime: fixedNow.addingTimeInterval(-600), type: .breast)
        XCTAssertTrue(running.isActive)
        let page = html(feeding: running)
        XCTAssertTrue(page.contains("<span class=\"val\">0</span><span class=\"lbl\">\("stat.feedings".l)</span>"))
    }

    /// An untimed bottle measured nothing: the PDF prints «—» and the CSV an
    /// empty cell, never «0 min» / «0»; a timed feed keeps its minutes.
    func testAFeedWithNoLengthExportsNoLength() {
        let start = fixedNow.addingTimeInterval(-3600)
        let untimed = FeedingEntry(startTime: start, type: .formula, side: nil, volumeML: 110)
        untimed.endTime = start
        let timed = FeedingEntry(startTime: start.addingTimeInterval(-7200), type: .formula, side: nil, volumeML: 90)
        timed.endTime = timed.startTime.addingTimeInterval(15 * 60)

        let page = html(feeding: untimed)
        XCTAssertTrue(page.contains("<td>\(ExportGenerator.htmlEscape(ReportFormat.ml(110)))</td><td>—</td></tr>"))
        XCTAssertFalse(page.contains("<td>\(ExportGenerator.htmlEscape(DurationText.minutes(0)))</td></tr>"))
        XCTAssertTrue(html(feeding: timed).contains("<td>\(ExportGenerator.htmlEscape(DurationText.minutes(15)))</td></tr>"))

        let csv = ExportGenerator.csvString(
            feedings: [untimed, timed], sleeps: [], diapers: [], growths: [], events: [],
            categories: [.feeding]
        ).first { $0.name == "feeding.csv" }!.content
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains { $0.hasSuffix(",110,") }, csv)
        XCTAssertTrue(lines.contains { $0.hasSuffix(",90,15") }, csv)
    }

    func testTheExportFooterSpeaksTheAppLanguage() {
        LocalizationManager.shared.setLanguage(.ru)
        defer { LocalizationManager.shared.setLanguage(.en) }
        let page = html()
        XCTAssertFalse(page.contains("Generated by"))
        XCTAssertTrue(page.contains(ExportGenerator.htmlEscape(
            String(format: "export.generated_by_fmt".l, "brand.name".l, "").trimmingCharacters(in: .whitespaces))))
    }

    /// Events has no Summary tile: an export of Events alone (a log of
    /// medicines only) opens with its table, not an empty card. Any tiled
    /// category keeps the card.
    func testTheSummaryCardNeedsATile() {
        let dose = CustomEvent(time: fixedNow.addingTimeInterval(-3600), type: .medication)
        let eventsOnly = ExportGenerator.buildHTML(
            baby: nil, feedings: [], sleeps: [], diapers: [], growths: [], events: [dose],
            categories: [.events], range: .all)
        XCTAssertFalse(eventsOnly.contains("class=\"card summary\""))
        XCTAssertFalse(eventsOnly.contains("<h2>\("export.summary".l)</h2>"))
        XCTAssertTrue(eventsOnly.contains("export.cat.events".l), "the Events table is still there")

        let diaper = DiaperEntry(time: fixedNow.addingTimeInterval(-7200), type: .wet)
        let withDiapers = ExportGenerator.buildHTML(
            baby: nil, feedings: [], sleeps: [], diapers: [diaper], growths: [], events: [dose],
            categories: [.diapers, .events], range: .all)
        XCTAssertTrue(withDiapers.contains("class=\"card summary\""))
        XCTAssertTrue(withDiapers.contains("<span class=\"val\">1</span><span class=\"lbl\">\("stat.diapers".l)</span>"))
    }

    // MARK: - Number format: PDF in the app language, CSV invariant

    private func html(growth: GrowthEntry? = nil, feeding: FeedingEntry? = nil,
                      sleep: SleepEntry? = nil) -> String {
        ExportGenerator.buildHTML(
            baby: nil, feedings: feeding.map { [$0] } ?? [], sleeps: sleep.map { [$0] } ?? [],
            diapers: [], growths: growth.map { [$0] } ?? [], events: [],
            categories: [.feeding, .sleep, .growth], range: .all)
    }

    func testPDFHTMLWritesNumbersInRussianWithLocalizedUnits() {
        LocalizationManager.shared.setLanguage("ru")
        defer { LocalizationManager.shared.setLanguage("en") }
        let nbsp = "\u{00A0}"
        let start = Date(timeIntervalSinceNow: -7200)
        let feeding = FeedingEntry(startTime: start, type: .formula, side: nil, volumeML: 120)
        feeding.endTime = start.addingTimeInterval(15 * 60)
        let sleep = SleepEntry(startTime: start, type: .nap)
        sleep.endTime = start.addingTimeInterval(5400)

        let out = html(growth: GrowthEntry(weightKg: 4.25, heightCm: 54.3, headCircumferenceCm: 37.0),
                       feeding: feeding, sleep: sleep)

        XCTAssertTrue(out.contains("4,25\(nbsp)кг"), "kg: comma + NBSP + ru unit")
        XCTAssertTrue(out.contains("54,3\(nbsp)см"))
        XCTAssertTrue(out.contains("37,0\(nbsp)см"))
        XCTAssertTrue(out.contains("120\(nbsp)мл"))
        XCTAssertTrue(out.contains("15\(nbsp)мин"))
        XCTAssertTrue(out.contains(String(format: "duration.h_min".l, 1, 30)), "sleep: hours and minutes, glued")
        XCTAssertFalse(out.contains("4.25"))
        XCTAssertFalse(out.contains("%."), "a format specifier leaked into the document")
        for english in [" kg", " cm", " ml", " min<", " h<"] {
            XCTAssertFalse(out.contains(english), "English unit left in the ru PDF: \(english)")
        }
    }

    /// A comma decimal inside a comma-separated file breaks every spreadsheet,
    /// so the CSV ignores the app language on purpose.
    func testCSVKeepsADotDecimalInRussian() {
        LocalizationManager.shared.setLanguage("ru")
        defer { LocalizationManager.shared.setLanguage("en") }

        let files = ExportGenerator.csvString(
            feedings: [], sleeps: [], diapers: [],
            growths: [GrowthEntry(weightKg: 4.25, heightCm: 54.3, headCircumferenceCm: 37.0)],
            events: [], categories: [.growth])
        let lines = files.first!.content.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasSuffix(",4.25,54.3,37.0"), "row was \(lines[1])")
        // Units sit in the header, localized, never in the cells.
        XCTAssertTrue(lines[0].contains("export.csv.weight_kg".l))
        XCTAssertFalse(lines[1].contains("кг"))
    }

    // MARK: - Locale split: machine columns vs document text

    /// CSV columns are DATA. They must stay Gregorian and ISO-shaped no matter
    /// which language the user picked or which calendar the device runs, or a
    /// spreadsheet cannot read them back.
    func testCSVFormatterIgnoresTheAppLanguage() {
        let reference = DateComponents(calendar: Calendar(identifier: .gregorian),
                                       timeZone: .current,
                                       year: 2026, month: 8, day: 24, hour: 14, minute: 30).date!
        for language in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(ExportGenerator.csvFormatter("yyyy-MM-dd").string(from: reference),
                           "2026-08-24", "CSV date drifted under \(language)")
            XCTAssertEqual(ExportGenerator.csvFormatter("HH:mm").string(from: reference),
                           "14:30", "CSV time drifted under \(language)")
        }
    }

    /// PDF text is PROSE. It must follow the language chosen in the app — the
    /// defect being fixed was a Spanish document carrying Russian dates because
    /// the formatter silently used the device locale.
    func testDocumentFormatterFollowsTheAppLanguage() {
        let reference = DateComponents(calendar: Calendar(identifier: .gregorian),
                                       timeZone: .current,
                                       year: 2026, month: 8, day: 24).date!
        var rendered: [String: String] = [:]
        for language in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(language)
            let text = ExportGenerator.documentFormatter { $0.dateStyle = .medium; $0.timeStyle = .none }
                .string(from: reference)
            rendered[language] = text
            XCTAssertTrue(text.contains("2026"), "\(language) lost the year: \(text)")
        }
        // Each language names the month its own way; identical output would mean
        // the locale never took.
        XCTAssertNotEqual(rendered["en"], rendered["ru"])
        XCTAssertNotEqual(rendered["en"], rendered["es"])
        XCTAssertNotEqual(rendered["ru"], rendered["es"])
    }
}

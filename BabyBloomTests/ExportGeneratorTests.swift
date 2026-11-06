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
    }

    func testTheExportFooterSpeaksTheAppLanguage() {
        LocalizationManager.shared.setLanguage(.ru)
        defer { LocalizationManager.shared.setLanguage(.en) }
        let page = html()
        XCTAssertFalse(page.contains("Generated by"))
        XCTAssertTrue(page.contains(ExportGenerator.htmlEscape(
            String(format: "export.generated_by_fmt".l, "brand.name".l, "").trimmingCharacters(in: .whitespaces))))
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

        XCTAssertTrue(out.contains("4,25\(nbsp)\("unit.kg".l)"), "kg: comma + NBSP + ru unit")
        XCTAssertTrue(out.contains("54,3\(nbsp)\("unit.cm".l)"))
        XCTAssertTrue(out.contains("37,0\(nbsp)\("unit.cm".l)"))
        XCTAssertTrue(out.contains("120\(nbsp)\("unit.ml".l)"))
        XCTAssertTrue(out.contains("15\(nbsp)\("unit.min".l)"))
        XCTAssertTrue(out.contains("1,5\(nbsp)\("unit.h".l)"), "sleep hours: 1 digit, ru separator")
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

import XCTest
import UIKit
@testable import BabyBloom

private typealias Feed = DoctorReportSummary.Input.Feed
private typealias Sleep = DoctorReportSummary.Input.Sleep
private typealias Diaper = DoctorReportSummary.Input.Diaper
private typealias Growth = DoctorReportSummary.Input.Growth
private typealias Dose = DoctorReportSummary.Input.Dose

/// The report PDF's HTML against the screen's own formatters, and against
/// the closed list of verdict words the report must never print
/// (teamdocs/content/doctor-report.md).
final class DoctorReportPDFTests: XCTestCase {

    /// Europe/Berlin, as `DoctorReportSummaryTests`: the clocks go back on 25 Oct.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private var periodStart: Date { at(12, 0) }
    private var now: Date { at(1, 9, month: 11) }

    override func tearDown() {
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    // MARK: Fixtures

    /// A 20-day period with every card filled; 18 of its days hold entries, so
    /// the days lines show. Growth dates sit at noon, clear of an age boundary.
    /// `birthDate` / `correctedBirthDate` move the baby the summary is made for:
    /// a due date after the weighings gives «before the due date», a birth three
    /// years back gives «past the WHO table».
    private func makeSummary(latestWeight: Double = 5.42, birthDate: Date? = nil,
                             correctedBirthDate: Date? = nil, doses: [Dose] = []) -> DoctorReportSummary {
        let days = Array(12...29)
        let feeds = days.flatMap { day -> [Feed] in
            [Feed(start: at(day, 8), end: at(day, 8).addingTimeInterval(20 * 60), type: .breast, volumeML: nil),
             Feed(start: at(day, 14), end: at(day, 14).addingTimeInterval(15 * 60), type: .formula, volumeML: 90)]
        }
        let sleeps = days.map { Sleep(start: at($0, 13), end: at($0, 13).addingTimeInterval(150 * 60)) }
        let diapers = days.flatMap { day in
            [Diaper(time: at(day, 9), type: .wet, color: nil),
             Diaper(time: at(day, 15), type: .dirty, color: day.isMultiple(of: 2) ? .yellow : .green)]
        }
        let growth = [
            Growth(date: at(14, 12), weightKg: 4.78, heightCm: 55, headCm: nil),
            Growth(date: at(28, 12), weightKg: latestWeight, heightCm: 58, headCm: 39),
        ]
        let input = DoctorReportSummary.Input(
            feeds: feeds, sleeps: sleeps, diapers: diapers, growth: growth, doses: doses,
            birthDate: birthDate ?? at(2, 12, month: 9),
            correctedBirthDate: correctedBirthDate ?? birthDate ?? at(2, 12, month: 9),
            birthWeightKg: 3.4, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: periodStart, now: now,
                                        startsAtVisit: true, calendar: calendar)
    }

    /// A 3-day period (30 Oct to 1 Nov, `periodDays == 2`) with entries on the
    /// 31st and today only, so the days lines WOULD show were the period long.
    private func makeShortSummary() -> DoctorReportSummary {
        let days = [31, 1]
        func stamp(_ index: Int, _ hour: Int) -> Date { index == 31 ? at(31, hour) : at(1, hour, month: 11) }
        let input = DoctorReportSummary.Input(
            feeds: days.map { Feed(start: stamp($0, 7), end: stamp($0, 7).addingTimeInterval(600), type: .breast, volumeML: nil) },
            sleeps: days.map { Sleep(start: stamp($0, 1), end: stamp($0, 3)) },
            diapers: days.flatMap { [Diaper(time: stamp($0, 6), type: .wet, color: nil),
                                     Diaper(time: stamp($0, 8), type: .dirty, color: .yellow)] },
            birthDate: at(2, 12, month: 9), correctedBirthDate: at(2, 12, month: 9),
            birthWeightKg: nil, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: at(30, 0), now: now,
                                        startsAtVisit: true, calendar: calendar)
    }

    private func makeEmptySummary(periodStart: Date? = nil, startsAtVisit: Bool = true) -> DoctorReportSummary {
        DoctorReportSummary.make(
            input: DoctorReportSummary.Input(birthDate: at(2, 12, month: 9),
                                             correctedBirthDate: at(2, 12, month: 9),
                                             birthWeightKg: nil, isMale: false),
            periodStart: periodStart ?? self.periodStart, now: now, startsAtVisit: startsAtVisit, calendar: calendar)
    }

    /// A visit today with nothing logged since: the one «no entries» line.
    private func makeNewPeriodSummary() -> DoctorReportSummary {
        let input = DoctorReportSummary.Input(
            // Weighed before the visit: a weighing today would be the period's
            // first entry, and the new-period card would not show.
            growth: [Growth(date: at(28, 12), weightKg: 5.5, heightCm: nil, headCm: nil)],
            birthDate: at(2, 12, month: 9), correctedBirthDate: at(2, 12, month: 9),
            birthWeightKg: nil, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: at(1, 0, month: 11), now: now,
                                        startsAtVisit: true, calendar: calendar)
    }

    /// Paracetamol given from 20 to 28 Oct (a linked dose and its copied name),
    /// an older free-text event, and one with no name.
    private var medicationDoses: [Dose] {
        let paracetamol = UUID()
        return [20, 22, 28].map {
            Dose(time: at($0, 8), name: "Paracetamol", doseText: "120 mg (5 ml)",
                 medicineID: paracetamol, medicineName: "Paracetamol")
        } + [Dose(time: at(25, 10), name: "Saline drops", doseText: nil),
             Dose(time: at(26, 10), name: nil, doseText: nil)]
    }

    /// 32 weeks: preterm, so the due date and the corrected age exist.
    private func makeBaby(gestationalWeeks: Int? = nil) -> Baby {
        let baby = Baby(name: "Mia", birthDate: at(2, 12, month: 9), gender: .female, feedingType: .breast)
        baby.gestationalWeeks = gestationalWeeks
        return baby
    }

    private func html(_ summary: DoctorReportSummary, baby: Baby? = nil, periodStart: Date? = nil,
                      questions: [String] = ["Rash on the cheeks?"]) -> String {
        DoctorReportPDF.html(summary: summary, baby: baby ?? makeBaby(), openQuestions: questions,
                             periodStart: periodStart ?? self.periodStart, now: now)
    }

    /// The text of a key before its first placeholder, for «this line is absent» checks.
    private func fixedPrefix(_ key: String) -> String {
        (key.l.components(separatedBy: "%").first ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// «label <b>value</b> tail», as the PDF's row builder splits the key.
    private func rowHTML(_ key: String, _ value: String) -> String {
        let split = FormatSplit(key.l, value: value)
        return "\(esc(split?.head ?? key.l))<b>\(esc(value))</b>\(esc(split?.tail ?? ""))"
    }

    private func esc(_ text: String) -> String { ExportGenerator.htmlEscape(text) }

    // MARK: a) Same numbers as the screen

    func testEveryNumberTheScreenShowsIsInTheHTML() throws {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let summary = makeSummary()
            let page = html(summary)
            func assertShown(_ value: String, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
                // Values print in bold, the way the screen's metric text is set apart.
                XCTAssertTrue(page.contains("<b>\(esc(value))</b>"), "\(language): \(what) «\(value)»",
                              file: file, line: line)
            }

            let growth = summary.growth
            assertShown(ReportFormat.kg(try XCTUnwrap(growth.latestWeight).value), "weight")
            assertShown(ReportFormat.cm(try XCTUnwrap(growth.latestHeight).value), "height")
            assertShown(try XCTUnwrap(growth.latestHead).value.appDecimal(1), "head")
            guard case .reading(let weightReading) = growth.weightPercentile,
                  case .reading(let heightReading) = growth.heightPercentile else {
                return XCTFail("the fixture must give both percentile readings, got \(growth.weightPercentile)")
            }
            assertShown(ReportFormat.glued(weightReading.badge), "weight percentile")
            assertShown(ReportFormat.glued(heightReading.badge), "height percentile")
            let change = try XCTUnwrap(growth.change)
            assertShown(ReportFormat.grams(change.grams), "change")
            XCTAssertTrue(page.contains(esc(ReportFormat.date(change.baseDate, now: now))), "\(language): change base date")
            XCTAssertTrue(page.contains(esc(ReportFormat.kg(try XCTUnwrap(growth.atBirthWeightKg)))), "\(language): at birth")

            let feeding = try XCTUnwrap(summary.feeding)
            assertShown(WeeklyFormat.perDay(try XCTUnwrap(feeding.feedsPerDay)), "feeds a day")
            assertShown(ReportFormat.ml(try XCTUnwrap(feeding.bottleMLPerDay)), "bottle a day")
            assertShown(ReportFormat.duration(try XCTUnwrap(feeding.breastfeedMedian)), "breastfeed average")
            let sleep = try XCTUnwrap(summary.sleep)
            assertShown(ReportFormat.duration(try XCTUnwrap(sleep.perDay)), "sleep a day")
            assertShown(ReportFormat.duration(try XCTUnwrap(sleep.longest)), "longest sleep")
            let diapers = try XCTUnwrap(summary.diapers)
            assertShown(WeeklyFormat.perDay(try XCTUnwrap(diapers.wetPerDay)), "wet a day")
            assertShown(WeeklyFormat.perDay(try XCTUnwrap(diapers.dirtyPerDay)), "dirty a day")

            // The fixture has entries on 18 of 20 days, so every days line shows.
            for days in [feeding.days, sleep.days, diapers.days] {
                XCTAssertTrue(days.showsLine)
                let line = String(format: "report.days_logged_fmt".l, days.withEntries, days.counted)
                XCTAssertTrue(page.contains(esc(line)), "\(language): days line «\(line)»")
            }

            // The weighings table: both weighings, newest first.
            let rows = growth.weighings.map { esc(ReportFormat.kg($0.weightKg)) }
            XCTAssertEqual(rows.count, 2)
            let first = try XCTUnwrap(page.range(of: rows[0]))
            let second = try XCTUnwrap(page.range(of: rows[1], range: first.upperBound..<page.endIndex))
            XCTAssertLessThan(first.lowerBound, second.lowerBound)
            // Its head on every page is pinned on the rendered file: PDFPagesTests.
            XCTAssertTrue(page.contains("<table class=\"weighings\"><colgroup>"))
        }
    }

    func testQuestionsAreNumberedAndEscaped() {
        let page = html(makeSummary(), questions: ["Rash <on> the cheeks?", "Vitamin D & iron?"])
        XCTAssertTrue(page.contains("<ol><li>Rash &lt;on&gt; the cheeks?</li><li>Vitamin D &amp; iron?</li></ol>"))
        XCTAssertFalse(html(makeSummary(), questions: []).contains("<ol>"), "no questions, no section")
    }

    func testVisitTodayPrintsNoEntriesInPlaceOfTheThreeSections() {
        let summary = makeNewPeriodSummary()
        XCTAssertTrue(summary.showsNewPeriodCard)
        let page = html(summary, questions: [])
        XCTAssertTrue(page.contains(esc("report.pdf.no_entries".l)))
        XCTAssertTrue(page.contains(esc(ReportFormat.kg(5.5))), "the standing growth facts stay")
        XCTAssertFalse(page.contains(esc("export.cat.feeding".l)))
        XCTAssertFalse(page.contains("<table class=\"weighings\">"), "period rows go")
    }

    // MARK: b) No verdicts

    private static let closedKeys = [
        "percentile.normal", "percentile.below_normal", "percentile.above_normal", "percentile.very_low",
        "percentile.very_high", "percentile.below3", "percentile.above97",
        "velocity.below", "velocity.within", "velocity.above", "velocity.expected_fmt",
        "nutrition.status_below", "nutrition.status_within", "nutrition.status_above",
        "breakdown.title", "breakdown.gain_days_fmt", "breakdown.feeds_fmt", "breakdown.nappies_fmt",
        "breakdown.disclaimer", "trend.stable", "trend.crossing_up",
        // Every form the copy holds; a form a language leaves out reads as its key and is skipped.
        "trend.drop.one", "trend.drop.other",
        "newborn.regained", "newborn.not_regained", "newborn.flag_loss", "newborn.flag_not_regained",
        "diaper.color.warning", "diaper.norm.fmt", "diaper.norm.label", "diaper.norm.hint",
        "stat.daily_norm", "growth.who_footnote",
        // PDF-only: the screen says it to the parent, the PDF says report.pdf.before_due_date.
        "percentile.before_due_date",
    ]

    private static let wordLists: [SupportedLanguage: String] = [
        .en: "normal|abnormal|low|high|too|enough|only|good|poor|worry|concern|warning|should|risk|healthy|behind|ahead",
        .ru: "норм\\w*|мало|много|слишком|достаточно|недостаточно|хорошо|плохо|тревож\\w*|опасн\\w*|риск\\w*|следует|стоит",
        .es: "normal\\w*|bajo|baja|alto|alta|demasiado|suficiente|insuficiente|solo|bien|mal|preocup\\w*|riesgo|debería|conviene",
    ]

    /// What a reader sees: the CSS and the tags are not words on the page
    /// («font-weight: normal» is not a verdict).
    private func visibleText(_ page: String) -> String {
        var text = page
        for pattern in ["<style>.*?</style>", "<[^>]+>"] {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        return text
    }

    /// Every card state the PDF has, each with the baby it is printed for.
    private func everyState() -> [(name: String, summary: DoctorReportSummary, baby: Baby, periodStart: Date)] {
        let preterm = makeBaby(gestationalWeeks: 32)
        return [
            ("filled", makeSummary(), makeBaby(), periodStart),
            ("medications", makeSummary(doses: medicationDoses), makeBaby(), periodStart),
            ("empty", makeEmptySummary(), makeBaby(), periodStart),
            ("short", makeShortSummary(), makeBaby(), at(30, 0)),
            ("new period", makeNewPeriodSummary(), makeBaby(), at(1, 0, month: 11)),
            ("preterm", makeSummary(correctedBirthDate: preterm.correctedBirthDate), preterm, periodStart),
            ("before the due date", makeSummary(correctedBirthDate: at(5, 12, month: 11)), makeBaby(), periodStart),
            ("past the WHO table", makeSummary(birthDate: at(2, 12, month: 9)
                .addingTimeInterval(-3 * 366 * 86_400)), makeBaby(), periodStart),
        ]
    }

    private func assertNoVerdict(in page: String, language: SupportedLanguage, state: String) throws {
        let lowered = page.lowercased()
        for key in Self.closedKeys {
            let value = key.l
            // A missing key reads as itself: nothing to scan.
            guard value != key else { continue }
            // The longest fixed stretch between the placeholders: a leading
            // label («Кормлений:») is shared with neutral rows, the verdict
            // part («в сутки, ориентир») is not.
            let specifier = try NSRegularExpression(pattern: "%(\\d+\\$)?[-+ 0#]*\\d*(\\.\\d+)?l{0,2}[@dfsu]")
            let fixed = specifier
                .stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: "\u{1}")
                .components(separatedBy: "\u{1}")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .max { $0.count < $1.count } ?? ""
            guard !fixed.isEmpty else { continue }
            XCTAssertFalse(lowered.contains(fixed), "\(language), \(state): «\(fixed)» from \(key) is in the PDF")
        }

        let words = try XCTUnwrap(Self.wordLists[language])
        // `\b` is ASCII-only for Cyrillic in some engines: lookarounds on letters instead.
        let regex = try NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}_])(?:\(words))(?![\\p{L}\\p{N}_])", options: [.caseInsensitive])
        let text = visibleText(page)
        let hit = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        XCTAssertNil(hit.flatMap { Range($0.range, in: text).map { String(text[$0]) } },
                     "\(language), \(state): a verdict word is in the PDF")
        XCTAssertFalse(page.contains("⚠"), "\(language), \(state): ⚠ is in the PDF")
    }

    func testNoVerdictInAnyLanguage() throws {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            for state in everyState() {
                let page = html(state.summary, baby: state.baby, periodStart: state.periodStart)
                try assertNoVerdict(in: page, language: language, state: state.name)
            }
        }
    }

    // MARK: Medications

    func testTheMedicationsSectionPrintsWhatWasGivenInEveryLanguage() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(makeSummary(doses: medicationDoses))
            XCTAssertTrue(page.contains("<h2>\(esc("medication.report_title".l))</h2>"), "\(language)")
            for key in ["medication.report_col_name", "medication.report_col_dose",
                        "medication.report_col_count", "medication.report_col_dates"] {
                XCTAssertTrue(page.contains("<th>\(esc(key.l))</th>"), "\(language): \(key)")
            }
            let range = ReportFormat.dayRange(at(20, 8), at(28, 8), now: now)
            XCTAssertTrue(page.contains("<tr><td>Paracetamol</td><td>120 mg (5 ml)</td><td>3</td><td>\(esc(range))</td></tr>"),
                          "\(language)")
            XCTAssertTrue(page.contains("<td>Saline drops</td><td></td><td>1</td>"), "\(language)")
            XCTAssertTrue(page.contains("<td>\(esc("medication.report_without_name".l))</td><td></td><td>1</td>"),
                          "\(language)")
            // After Diapers, before the footnote.
            let diapers = page.range(of: "<h2>\(esc("export.cat.diapers".l))</h2>")!.lowerBound
            let medications = page.range(of: "<h2>\(esc("medication.report_title".l))</h2>")!.lowerBound
            XCTAssertLessThan(diapers, medications, "\(language)")
        }
    }

    /// A changed dose takes a row per text with the name repeated; doses with
    /// no text beside texted ones are worded, also on the nameless line.
    func testAChangedDosePrintsARowPerTextInEveryLanguage() {
        let paracetamol = UUID()
        let doses = [20, 22].map {
            Dose(time: at($0, 8), name: "Paracetamol", doseText: "2.5 ml", medicineID: paracetamol,
                 medicineName: "Paracetamol")
        } + [Dose(time: at(26, 8), name: "Paracetamol", doseText: "5 ml", medicineID: paracetamol,
                  medicineName: "Paracetamol"),
             Dose(time: at(24, 9), name: nil, doseText: "1 ml"),
             Dose(time: at(25, 9), name: nil, doseText: nil)]
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(makeSummary(doses: doses))
            let first = ReportFormat.dayRange(at(20, 8), at(22, 8), now: now)
            let second = ReportFormat.dayRange(at(26, 8), at(26, 8), now: now)
            XCTAssertTrue(page.contains("<tr><td>Paracetamol</td><td>2.5 ml</td><td>2</td><td>\(esc(first))</td></tr>"
                                        + "<tr><td>Paracetamol</td><td>5 ml</td><td>1</td><td>\(esc(second))</td></tr>"),
                          "\(language): one row per text, in order of first use")
            let nameless = esc("medication.report_without_name".l)
            XCTAssertTrue(page.contains("<tr><td>\(nameless)</td><td>1 ml</td><td>1</td>"), "\(language)")
            XCTAssertTrue(page.contains("<tr><td>\(nameless)</td><td>\(esc("medication.report_dose_not_written".l))</td><td>1</td>"),
                          "\(language)")
        }
    }

    /// The screen's caption for one text of a changed dose.
    func testAChangedDoseReadsAsTextCountAndDaysOnTheScreen() {
        let line = MedicationFormat.reportDoseLine(
            .init(text: "2.5 ml", count: 10, first: at(20, 8), last: at(22, 8)), now: now)
        XCTAssertEqual(line, "2.5 ml\u{00A0}· " + MedicationFormat.doseCount(10) + "\u{00A0}· "
                       + ReportFormat.dayRange(at(20, 8), at(22, 8), now: now))
        let unwritten = MedicationFormat.reportDoseLine(
            .init(text: nil, count: 1, first: at(23, 8), last: at(23, 8)), now: now)
        XCTAssertTrue(unwritten.hasPrefix("medication.report_dose_not_written".l + "\u{00A0}· "))
    }

    func testNoDoseInThePeriodPrintsNoMedicationsSection() {
        for summary in [makeSummary(), makeEmptySummary(), makeNewPeriodSummary()] {
            let page = html(summary)
            XCTAssertFalse(page.contains(esc("medication.report_title".l)))
            XCTAssertFalse(page.contains(esc("medication.report_col_dose".l)))
        }
    }

    func testANameIsPrintedAsWrittenButForItsEmoji() {
        let doses = [Dose(time: at(20, 8), name: "Ibuprofen 💊 <syrup>", doseText: "2.5 ml & more")]
        let page = html(makeSummary(doses: doses))
        XCTAssertTrue(page.contains("<td>Ibuprofen  &lt;syrup&gt;</td><td>2.5 ml &amp; more</td>")
                      || page.contains("<td>Ibuprofen &lt;syrup&gt;</td><td>2.5 ml &amp; more</td>"), page)
        XCTAssertFalse(page.contains("💊"))
    }

    // MARK: c) Russian decimals

    func testRussianWeightHasACommaAndANoBreakSpace() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertTrue(html(makeSummary(latestWeight: 4.25)).contains("4,25\u{00A0}кг"))
    }

    // MARK: d) File name

    func testFileNameInEnglish() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(DoctorReportPDF.fileName(babyName: "Mia", date: now),
                       "Pediatrician report – Mia – 2026-11-01.pdf")
        XCTAssertEqual(DoctorReportPDF.fileName(babyName: "Mia/Ann: Jr", date: now),
                       "Pediatrician report – MiaAnn Jr – 2026-11-01.pdf")
    }

    func testFileNameInRussianAndSpanish() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(DoctorReportPDF.fileName(babyName: "Mia", date: now),
                       "Отчёт для педиатра – Mia – 2026-11-01.pdf")
        LocalizationManager.shared.setLanguage(.es)
        XCTAssertEqual(DoctorReportPDF.fileName(babyName: "Mia", date: now),
                       "Informe pediátrico – Mia – 2026-11-01.pdf")
    }

    func testABlankNameFallsBackToTheDefaultBabyName() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let fallback = "baby.default_name".l
            XCTAssertNotEqual(fallback, "baby.default_name")
            let expected = String(format: "report.pdf.file_fmt".l, fallback, "2026-11-01") + ".pdf"
            XCTAssertEqual(DoctorReportPDF.fileName(babyName: "   ", date: now), expected, "\(language)")
        }
    }

    /// Cut to 60 over the whole name, a long name pushed the date out.
    func testALongNameKeepsTheDate() {
        for (language, long) in [(SupportedLanguage.en, String(repeating: "Abcdefghij", count: 6)),
                                 (.ru, String(repeating: "Александра", count: 6))] {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(DoctorReportPDF.fileName(babyName: long, date: now),
                           String(format: "report.pdf.file_fmt".l, long, "2026-11-01") + ".pdf", "\(language)")
        }
    }

    // MARK: f) Preterm header

    func testAPretermHeaderPrintsTheDueDateAndCorrectedAge() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let baby = makeBaby(gestationalWeeks: 32)
            XCTAssertTrue(baby.isPreterm)
            let page = html(makeSummary(), baby: baby)

            let due = String(format: "report.pdf.due_fmt".l, ReportFormat.glued(baby.correctedBirthDate.appDayMonthYear))
            XCTAssertTrue(page.contains(esc(due)), "\(language): due date «\(due)»")
            let age = String(format: "report.age_corrected_fmt".l,
                             Baby.describeAge(from: baby.birthDate, to: now),
                             Baby.describeAge(from: baby.correctedBirthDate, to: now))
            XCTAssertTrue(page.contains(esc(String(format: "report.pdf.age_fmt".l, age))), "\(language): age «\(age)»")
        }
    }

    func testATermHeaderHasNoDueDateAndNoCorrectedAge() {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(makeSummary(), baby: makeBaby())
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.pdf.due_fmt"))), "\(language)")
            // The text between the two placeholders: «(corrected age: ».
            let corrected = (FormatSplit("report.age_corrected_fmt".l, at: 2, filling: [""])?.head ?? "")
                .trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(corrected.isEmpty)
            XCTAssertFalse(page.contains(esc(corrected)), "\(language)")
        }
    }

    // MARK: g) Percentile rows without a number

    func testAWeighingBeforeTheDueDatePrintsTheExplanationInsteadOfANumber() {
        let summary = makeSummary(correctedBirthDate: at(5, 12, month: 11))
        XCTAssertEqual(summary.growth.weightPercentile, .beforeDueDate)
        XCTAssertEqual(summary.growth.heightPercentile, .beforeDueDate)
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(summary)
            XCTAssertTrue(page.contains(esc("report.pdf.before_due_date".l)), "\(language)")
            XCTAssertEqual(page.components(separatedBy: esc("report.pdf.before_due_date".l)).count - 1, 1,
                           "\(language): weight and height share one sentence")
            XCTAssertTrue(summary.growth.repeatsWeightNote)
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.percentile_weight_fmt"))), "\(language)")
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.percentile_height_fmt"))), "\(language)")
            XCTAssertFalse(page.contains(esc("percentile.out_of_range".l)), "\(language)")
        }
    }

    func testAWeighingPastTheWHOTablePrintsTheRangeNoteInsteadOfANumber() {
        // Born three years before the weighings: older than the 24 months the table covers.
        let summary = makeSummary(birthDate: at(2, 12, month: 9).addingTimeInterval(-3 * 366 * 86_400))
        XCTAssertEqual(summary.growth.weightPercentile, .outOfRange)
        XCTAssertEqual(summary.growth.heightPercentile, .outOfRange)
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(summary)
            XCTAssertTrue(page.contains(esc("percentile.out_of_range".l)), "\(language)")
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.percentile_weight_fmt"))), "\(language)")
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.percentile_height_fmt"))), "\(language)")
            XCTAssertFalse(page.contains(esc("percentile.before_due_date".l)), "\(language)")
        }
    }

    // MARK: h) Short period

    func testAShortPeriodPrintsRawCountsAndNoDaysLine() throws {
        let summary = makeShortSummary()
        XCTAssertTrue(summary.isShort)
        let feeding = try XCTUnwrap(summary.feeding)
        let sleep = try XCTUnwrap(summary.sleep)
        let diapers = try XCTUnwrap(summary.diapers)
        // A long period would print these lines: one of two finished days has entries.
        XCTAssertTrue(feeding.days.showsLine && sleep.days.showsLine && diapers.days.showsLine)

        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(summary, periodStart: at(30, 0))
            XCTAssertTrue(page.contains(rowHTML("report.feeds_count_fmt", "\(feeding.totalFeeds)")), "\(language)")
            XCTAssertTrue(page.contains(rowHTML("report.wet_count_fmt", "\(diapers.wetCount)")), "\(language)")
            XCTAssertTrue(page.contains(rowHTML("report.dirty_count_fmt", "\(diapers.dirtyCount)")), "\(language)")
            XCTAssertTrue(page.contains(rowHTML("report.sleep_total_fmt", ReportFormat.duration(sleep.total))), "\(language)")
            XCTAssertFalse(page.contains(esc(fixedPrefix("report.days_logged_fmt"))), "\(language)")
            XCTAssertFalse(page.contains(esc(fixedPrefix("weekly.feeds_fmt"))), "no average in a short period")
        }
    }

    // MARK: i) No visit

    func testAPeriodFromBirthRendersTheSectionsAndNoEntriesLine() {
        let birth = at(2, 12, month: 9)
        let summary = makeEmptySummary(periodStart: birth, startsAtVisit: false)
        XCTAssertFalse(summary.showsNewPeriodCard)
        let page = html(summary, periodStart: birth)
        for key in ["export.cat.growth", "export.cat.feeding", "export.cat.sleep", "export.cat.diapers"] {
            XCTAssertTrue(page.contains("<h2>\(esc(key.l))</h2>"), key)
        }
        XCTAssertFalse(page.contains(esc("report.pdf.no_entries".l)))
    }

    // MARK: j) Weight chart

    private func labelWidth(_ text: String) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: DoctorReportPDF.chartLabelFont]).width
    }

    /// A girl born on 2 Sep, weighed on the median at each age.
    private func medianChart(_ ages: [Int]) throws -> WeightForAgeChart {
        let birth = at(2, 12, month: 9)
        let weighings = ages.map { days in
            WeightMeasurement(date: calendar.date(byAdding: .day, value: days, to: birth)!,
                              weightKg: WHOGrowthStandard.weight(atZ: 0, ageDays: days, isMale: false)!)
        }
        return try XCTUnwrap(WeightForAgeChart(weighings: weighings, correctedBirthDate: birth, isMale: false,
                                               calendar: calendar), "\(ages)")
    }

    /// The section follows the questions and precedes the closing line; its
    /// centiles and every axis label are text the doctor can search.
    func testTheChartPrintsAfterTheQuestionsWithItsLabelsAsText() throws {
        let summary = makeSummary()
        let chart = try XCTUnwrap(summary.growth.weightChart)
        XCTAssertEqual(chart.window.lowAgeDays, 35)
        XCTAssertEqual(chart.window.highAgeDays, 63)
        XCTAssertEqual(chart.ticks, [at(7, 12), at(2, 12, month: 11)])
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(summary)
            let heading = "<h2>\(esc("report.pdf.chart_title".l))<span class=\"curves\">"
                + "\(esc(ReportFormat.joiner + "report.pdf.chart_curves".l))</span></h2>"
            let questions = try XCTUnwrap(page.range(of: "</ol>", options: .backwards), "\(language)")
            let section = try XCTUnwrap(page.range(of: heading), "\(language)")
            let svg = try XCTUnwrap(page.range(of: "<svg"), "\(language)")
            let footnote = try XCTUnwrap(page.range(of: esc("report.footnote".l)), "\(language)")
            XCTAssertLessThan(questions.upperBound, section.lowerBound, "\(language): after the questions")
            XCTAssertLessThanOrEqual(section.upperBound, svg.lowerBound, "\(language)")
            XCTAssertLessThan(svg.lowerBound, footnote.lowerBound, "\(language): before the closing line")
            for centile in ["3", "50", "97"] {
                XCTAssertTrue(page.contains(">\(centile)</text>"), "\(language): \(centile)")
            }
            for kg in stride(from: chart.kgRange.lowerBound, through: chart.kgRange.upperBound, by: chart.kgStep) {
                let label = esc(Units.kg("\(kg)"))
                XCTAssertTrue(page.contains(">\(label)</text>"), "\(language): \(kg) kg")
            }
            let labels = DoctorReportPDF.chartXLabels(chart, now: now, width: labelWidth)
            XCTAssertEqual(labels.map(\.text), chart.ticks.map { ReportFormat.date($0, now: now) }, "\(language)")
            for label in labels {
                XCTAssertTrue(page.contains(">\(esc(label.text))</text>"), "\(language): «\(label.text)»")
            }
        }
    }

    /// No figure for the weight percentile, or one weighing, or none: no
    /// section, never an empty chart. Before the due date the window would
    /// reach the tables; the missing figure alone keeps the chart out.
    func testNoChartWithoutAPercentileFigureOrASecondWeighing() {
        let cases: [(String, DoctorReportSummary, Date)] = [
            ("before the due date", makeSummary(correctedBirthDate: at(5, 12, month: 11)), periodStart),
            ("past the WHO table",
             makeSummary(birthDate: at(2, 12, month: 9).addingTimeInterval(-3 * 366 * 86_400)), periodStart),
            ("one weighing", makeNewPeriodSummary(), at(1, 0, month: 11)),
            ("no weighing", makeEmptySummary(), periodStart),
            ("short period", makeShortSummary(), at(30, 0)),
        ]
        for (name, summary, start) in cases {
            XCTAssertNil(summary.growth.weightChart, name)
            for language in [SupportedLanguage.en, .ru, .es] {
                LocalizationManager.shared.setLanguage(language)
                let page = html(summary, periodStart: start)
                XCTAssertFalse(page.contains("<svg"), "\(name), \(language)")
                XCTAssertFalse(page.contains(esc("report.pdf.chart_title".l)), "\(name), \(language)")
            }
        }
    }

    /// Every x label inside page x 60…541 and clear of the one before it, in
    /// every language, this year's dates and year-dated ones alike. Each label
    /// names its tick: the window's start always, then month marks from the
    /// first that clears the start's label, every one or every 2nd, 4th….
    func testTheXLabelsStayInsideTheAxisAndApart() throws {
        let later = calendar.date(byAdding: .year, value: 3, to: now)!
        for ages in [[42, 56], [0, 30], [10, 95], [0, 365], [0, 700], [300, 700]] {
            let chart = try medianChart(ages)
            let marks = Array(chart.ticks.dropFirst())
            for language in [SupportedLanguage.en, .ru, .es] {
                LocalizationManager.shared.setLanguage(language)
                for reportDate in [now, later] {
                    let context = "\(ages), \(language), \(reportDate)"
                    let labels = DoctorReportPDF.chartXLabels(chart, now: reportDate, width: labelWidth)
                    XCTAssertEqual(labels.first?.date, chart.ticks.first, context)
                    XCTAssertEqual(labels.map(\.text), labels.map { ReportFormat.date($0.date, now: reportDate) },
                                   context)
                    let kept = labels.dropFirst().map(\.date)
                    if let firstKept = kept.first {
                        let rest = Array(marks[try XCTUnwrap(marks.firstIndex(of: firstKept), context)...])
                        let strides = (0...4).map { 1 << $0 }
                        XCTAssertTrue(strides.contains { by in
                            stride(from: 0, to: rest.count, by: by).map { rest[$0] } == kept
                        }, "\(context): \(labels.map(\.text))")
                    }
                    for label in labels {
                        XCTAssertGreaterThanOrEqual(label.left, 24, context)
                        XCTAssertLessThanOrEqual(label.left + label.width, 505, context)
                    }
                    for (before, after) in zip(labels, labels.dropFirst()) {
                        XCTAssertGreaterThanOrEqual(after.left, before.left + before.width + 4, context)
                    }
                }
            }
            // Room for every label: every tick keeps its date.
            let narrow = DoctorReportPDF.chartXLabels(chart, now: now) { _ in 10 }
            XCTAssertEqual(narrow.map(\.date), chart.ticks, "\(ages)")
        }
    }

    /// Labels too wide for their places take their ticks with them: the marks
    /// that would sit on the start's label go, then every second one, until
    /// the rest clear. The window's first date always stays.
    func testALabelTooWideForItsPlaceGoesWithItsTick() throws {
        let chart = try medianChart([0, 700])
        XCTAssertEqual(chart.ticks.count, 6)
        let wide = DoctorReportPDF.chartXLabels(chart, now: now) { _ in 120 }
        XCTAssertEqual(wide.map(\.date), [0, 3, 5].map { chart.ticks[$0] })
        for (before, after) in zip(wide, wide.dropFirst()) {
            XCTAssertGreaterThanOrEqual(after.left, before.left + before.width + 4)
        }
        let tooWide = DoctorReportPDF.chartXLabels(chart, now: now) { _ in 300 }
        XCTAssertEqual(tooWide.map(\.date), [chart.ticks[0]])
    }

    /// The svg draws a tick only under a label, so no tick goes unnamed; each
    /// tick stands at its own date on the axis, under its label.
    func testEveryTickDrawnCarriesItsDate() throws {
        let summary = makeSummary()
        let chart = try XCTUnwrap(summary.growth.weightChart)
        let domain = chart.window.domain
        // The plot runs from svg x 28 to 501 (page x 64…537).
        func axisX(_ date: Date) -> Double {
            28 + 473 * date.timeIntervalSince(domain.lowerBound) / domain.upperBound.timeIntervalSince(domain.lowerBound)
        }
        // A tick runs from the plot's bottom (y 96) 3 pt down; no gridline ends at y 99.
        let tickPattern = try NSRegularExpression(pattern: "<line x1=\"([0-9.]+)\" y1=\"96\\.00\" x2=\"[0-9.]+\" y2=\"99\\.00\"")
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let page = html(summary)
            let labels = DoctorReportPDF.chartXLabels(chart, now: now, width: labelWidth)
            let ticks = tickPattern.matches(in: page, range: NSRange(page.startIndex..., in: page)).compactMap { match in
                Range(match.range(at: 1), in: page).flatMap { Double(page[$0]) }
            }
            XCTAssertEqual(ticks.count, labels.count, "\(language)")
            for (x, label) in zip(ticks, labels) {
                XCTAssertEqual(x, axisX(label.date), accuracy: 0.01, "\(language): «\(label.text)»")
                XCTAssertTrue((Double(label.left)...Double(label.left + label.width)).contains(x),
                              "\(language): the tick at \(x) is outside «\(label.text)»")
            }
        }
    }

    // MARK: e) Rendering

    @MainActor
    func testDataIsAPDF() {
        let data = DoctorReportPDF.data(summary: makeSummary(), baby: makeBaby(),
                                        openQuestions: ["Rash on the cheeks?"],
                                        periodStart: periodStart, now: now)
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }
}

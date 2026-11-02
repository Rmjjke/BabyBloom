import XCTest
@testable import BabyBloom

private typealias Feed = DoctorReportSummary.Input.Feed
private typealias Sleep = DoctorReportSummary.Input.Sleep
private typealias Diaper = DoctorReportSummary.Input.Diaper
private typealias Growth = DoctorReportSummary.Input.Growth

/// The report PDF's HTML against the screen's own formatters, and against
/// Content's closed no-verdict list (teamdocs/content/doctor-report.md).
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
                             correctedBirthDate: Date? = nil) -> DoctorReportSummary {
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
            feeds: feeds, sleeps: sleeps, diapers: diapers, growth: growth,
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
            // first entry, and the new-period card would not show (R5).
            growth: [Growth(date: at(28, 12), weightKg: 5.5, heightCm: nil, headCm: nil)],
            birthDate: at(2, 12, month: 9), correctedBirthDate: at(2, 12, month: 9),
            birthWeightKg: nil, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: at(1, 0, month: 11), now: now,
                                        startsAtVisit: true, calendar: calendar)
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

    /// «label <b>value</b> tail», as the PDF's row builder splits the key at `%@`.
    private func rowHTML(_ key: String, _ value: String) -> String {
        let parts = key.l.replacingOccurrences(of: "%d", with: "%@").components(separatedBy: "%@")
        return "\(esc(parts.first ?? ""))<b>\(esc(value))</b>\(esc(parts.dropFirst().joined()))"
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
            XCTAssertTrue(page.contains("thead { display: table-header-group; }"))
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
        "percentile.very_high", "percentile.below3", "percentile.3_15", "percentile.15_50",
        "percentile.50_85", "percentile.85_97", "percentile.above97",
        "velocity.below", "velocity.within", "velocity.above", "velocity.expected_fmt",
        "nutrition.status_below", "nutrition.status_within", "nutrition.status_above",
        "breakdown.title", "breakdown.gain_fmt", "breakdown.feeds_fmt", "breakdown.nappies_fmt",
        "breakdown.disclaimer", "trend.stable", "trend.crossing_up", "trend.drop_fmt",
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

    // MARK: c) Russian decimals

    func testRussianWeightHasACommaAndANoBreakSpace() {
        LocalizationManager.shared.setLanguage(.ru)
        let unit = "unit.kg".l
        XCTAssertNotEqual(unit, "unit.kg")
        XCTAssertTrue(html(makeSummary(latestWeight: 4.25)).contains("4,25\u{00A0}\(unit)"))
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
            let corrected = "report.age_corrected_fmt".l.components(separatedBy: "%@")[1]
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

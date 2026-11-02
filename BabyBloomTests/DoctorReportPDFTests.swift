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
    private func makeSummary(latestWeight: Double = 5.42) -> DoctorReportSummary {
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
            birthDate: at(2, 12, month: 9), correctedBirthDate: at(2, 12, month: 9),
            birthWeightKg: 3.4, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: periodStart, now: now,
                                        startsAtVisit: true, calendar: calendar)
    }

    private func makeBaby() -> Baby {
        Baby(name: "Mia", birthDate: at(2, 12, month: 9), gender: .female, feedingType: .breast)
    }

    private func html(_ summary: DoctorReportSummary, questions: [String] = ["Rash on the cheeks?"]) -> String {
        DoctorReportPDF.html(summary: summary, baby: makeBaby(), openQuestions: questions,
                             periodStart: periodStart, now: now)
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
            assertShown(ReportFormat.duration(try XCTUnwrap(feeding.breastfeedAverage)), "breastfeed average")
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
        let input = DoctorReportSummary.Input(
            // Weighed before the visit: a weighing today would be the period's
            // first entry, and the new-period card would not show (R5).
            growth: [Growth(date: at(28, 12), weightKg: 5.5, heightCm: nil, headCm: nil)],
            birthDate: at(2, 12, month: 9), correctedBirthDate: at(2, 12, month: 9),
            birthWeightKg: nil, isMale: false)
        let summary = DoctorReportSummary.make(input: input, periodStart: at(1, 0, month: 11), now: now,
                                               startsAtVisit: true, calendar: calendar)
        XCTAssertTrue(summary.showsNewPeriodCard)
        let page = html(summary, questions: [])
        XCTAssertTrue(page.contains(esc("report.pdf.no_entries".l)))
        XCTAssertTrue(page.contains(esc(ReportFormat.kg(5.5))), "the standing growth facts stay")
        XCTAssertFalse(page.contains(esc("tab.feeding".l)))
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

    func testNoVerdictInAnyLanguage() throws {
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            // Every card state: filled, and the empty one (the «No … logged» lines).
            let empty = DoctorReportSummary.make(
                input: DoctorReportSummary.Input(birthDate: at(2, 12, month: 9),
                                                 correctedBirthDate: at(2, 12, month: 9),
                                                 birthWeightKg: nil, isMale: false),
                periodStart: periodStart, now: now, startsAtVisit: true, calendar: calendar)
            for summary in [makeSummary(), empty] {
                let page = html(summary)
                let lowered = page.lowercased()

                for key in Self.closedKeys {
                    let value = key.l
                    // A missing key reads as itself: nothing to scan.
                    guard value != key else { continue }
                    let fixed = (value.components(separatedBy: "%").first ?? "")
                        .trimmingCharacters(in: .whitespaces).lowercased()
                    guard !fixed.isEmpty else { continue }
                    XCTAssertFalse(lowered.contains(fixed), "\(language): «\(fixed)» from \(key) is in the PDF")
                }

                let words = try XCTUnwrap(Self.wordLists[language])
                // `\b` is ASCII-only for Cyrillic in some engines: lookarounds on letters instead.
                let regex = try NSRegularExpression(
                    pattern: "(?<![\\p{L}\\p{N}_])(?:\(words))(?![\\p{L}\\p{N}_])", options: [.caseInsensitive])
                let text = visibleText(page)
                let hit = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
                XCTAssertNil(hit.flatMap { Range($0.range, in: text).map { String(text[$0]) } },
                             "\(language): a verdict word is in the PDF")
                XCTAssertFalse(page.contains("⚠"), "\(language): ⚠ is in the PDF")
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

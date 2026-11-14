import XCTest
@testable import BabyBloom

/// A short month can end in its own period («2 нояб.» in Russian, «2. Nov.»
/// in German); a sentence or a spoken join that puts its period after the
/// date must not show a second one. Every shipped language, with a month
/// whose short form ends in a period and one whose does not — and, since that
/// split is CLDR's and moves between iOS releases, the same date forced into
/// each shape as well.
@MainActor
final class ShortDatePeriodTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        DateComponents(calendar: calendar, timeZone: .current,
                       year: 2026, month: month, day: day, hour: hour).date!
    }

    /// November is «нояб.» in Russian, May is «мая».
    private var dates: [Date] { [day(11, 2), day(5, 2)] }

    private let sentenceKeys = ["report.new_period_fmt", "report.empty_feeding_fmt",
                                "report.empty_sleep_fmt", "report.empty_diapers_fmt"]

    override func tearDown() {
        FitLanguage.restore()
        super.tearDown()
    }

    /// The date as rendered, plus the same date with a trailing period and
    /// without one, so both shapes reach every language's sentence.
    private func shapes(of date: String) -> [String] {
        let bare = date.hasSuffix(".") ? String(date.dropLast()) : date
        return [date, bare, bare + "."]
    }

    func testDateSentencesKeepOnePeriodAfterTheDate() {
        for language in SupportedLanguage.available {
            FitLanguage.real(language).apply()
            for key in sentenceKeys {
                let format = key.l
                for date in dates {
                    let rendered = [ReportFormat.dayMonth(date), ReportFormat.glued(date.appDayMonthYear)]
                    for text in rendered.flatMap(shapes) {
                        let sentence = ReportFormat.sentence(format, date: text)
                        XCTAssertFalse(sentence.contains(".."), "\(language) \(key): \(sentence)")
                        // Where the sentence ends on the date, exactly one
                        // period stands between it and what follows.
                        guard format.contains("%@.") else { continue }
                        let bare = text.hasSuffix(".") ? String(text.dropLast()) : text
                        let after = format.components(separatedBy: "%@.").dropFirst().joined()
                        XCTAssertTrue(sentence.contains(bare + "." + after),
                                      "\(language) \(key): «\(sentence)» lost the period after «\(bare)»")
                    }
                }
            }
        }
    }

    func testRussianNewPeriodLineReadsAsTheReportShowsIt() {
        FitLanguage.real(.ru).apply()
        XCTAssertEqual(ReportFormat.sentence("report.new_period_fmt".l, date: ReportFormat.dayMonth(day(11, 2))),
                       "Новый период начался 2\u{00A0}нояб. Новые записи появятся здесь.")
        XCTAssertEqual(ReportFormat.sentence("report.new_period_fmt".l, date: ReportFormat.dayMonth(day(5, 2))),
                       "Новый период начался 2\u{00A0}мая. Новые записи появятся здесь.")
        FitLanguage.real(.en).apply()
        XCTAssertEqual(ReportFormat.sentence("report.new_period_fmt".l, date: ReportFormat.dayMonth(day(11, 2))),
                       "A new period started on Nov\u{00A0}2. New entries will show here.")
    }

    /// The dose row's label joins its lines with periods; the visible row
    /// keeps the date as the language writes it.
    func testDoseRowLabelHasOnePeriodAfterTheDate() {
        for language in SupportedLanguage.available {
            FitLanguage.real(language).apply()
            for (doseTime, now) in [(day(11, 1, hour: 20), day(11, 14)), (day(5, 1, hour: 20), day(5, 14))] {
                let dose = CustomEvent(time: doseTime, type: .medication)
                dose.medicationDose = "2,5 мл"
                let label = DoseRow.spoken(dose, now: now)
                let visibleDay = MedicationFormat.doseDay(doseTime, now: now)
                XCTAssertEqual(visibleDay, ReportFormat.glued(doseTime.appDayMonth), "\(language): the visible day changed")
                XCTAssertFalse(label.contains(".."), "\(language): \(label)")
                let bare = visibleDay.hasSuffix(".") ? String(visibleDay.dropLast()) : visibleDay
                XCTAssertTrue(label.hasSuffix(bare + ". 2,5 мл"), "\(language): \(label)")
            }
        }
        FitLanguage.real(.ru).apply()
        let dose = CustomEvent(time: day(11, 1, hour: 20), type: .medication)
        dose.medicationDose = "2,5 мл"
        XCTAssertEqual(DoseRow.spoken(dose, now: day(11, 14)),
                       day(11, 1, hour: 20).appTimeOfDay + " 1\u{00A0}нояб. 2,5 мл")
    }

    func testSpokenJoinAddsAPeriodOnlyWhereThereIsNone() {
        XCTAssertEqual(MedicationFormat.spoken(["Ibuprofen", nil, "", "Next dose at 20:00"]),
                       "Ibuprofen. Next dose at 20:00")
        XCTAssertEqual(MedicationFormat.spoken(["Vit. D.", "1 нояб.", "2,5 мл"]), "Vit. D. 1 нояб. 2,5 мл")
        XCTAssertEqual(MedicationFormat.spoken(["One"]), "One")
        XCTAssertEqual(MedicationFormat.spoken([nil, ""]), "")
    }
}

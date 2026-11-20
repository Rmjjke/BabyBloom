import XCTest
@testable import BabyBloom

/// What each offer card shows: only the parent's own records, never a paid
/// figure or a price, and a line of text where a chart would be too thin.
@MainActor
final class OfferCardModelTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private var language: SupportedLanguage!

    override func setUp() {
        super.setUp()
        language = LocalizationManager.shared.language
        LocalizationManager.shared.setLanguage(.en)
    }

    override func tearDown() {
        LocalizationManager.shared.setLanguage(language)
        super.tearDown()
    }

    private func at(_ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 2 + day, hour: hour, minute: minute))!
    }

    private func input(feeds: [Date] = [], sleeps: [(start: Date, end: Date?)] = [], diapers: [Date] = [],
                       events: [Date] = [], growthDates: [Date] = [], weighings: [WeightMeasurement] = [],
                       name: String = "Mia", birth: Int = 0, now: Date) -> OfferCardModel.Input {
        OfferCardModel.Input(feeds: feeds, sleeps: sleeps, diapers: diapers, events: events,
                             growthDates: growthDates, weighings: weighings, babyName: name, isMale: false,
                             correctedBirthDate: at(birth, 6), onboardingEndedAt: at(0, 10), now: now,
                             calendar: calendar)
    }

    // MARK: - Days bars

    func testTheFirstResultBarsRunFromTheFirstRecordAfterOnboardingToToday() {
        let model = OfferCardModel.make(.firstResultDays, input: input(
            feeds: [at(0, 9), at(0, 11), at(1, 8), at(2, 7), at(2, 15)],   // 09:00 on day 0 is before onboarding ended
            sleeps: [(start: at(1, 13), end: at(1, 15))],
            diapers: [at(2, 9)],
            now: at(2, 18)))
        XCTAssertEqual(model.visual, .bars([2, 2, 3]), "one bar per day, oldest first, every kind of record")
        XCTAssertEqual(model.title, "offer.first_result_days.title".l)
        XCTAssertEqual(model.body, "offer.first_result_days.body".l)
        XCTAssertEqual(model.stats, [String(format: "offer.stat.feeds_fmt".l, "5"),
                                     String(format: "offer.stat.sleep_fmt".l, WeeklyFormat.duration(7200)),
                                     String(format: "offer.stat.diapers_fmt".l, "1")])
    }

    func testTheBarsKeepTheLastSevenDaysAndADayWithoutRecordsIsZero() {
        let feeds = (0...9).filter { $0 != 7 }.map { at($0) }
        let model = OfferCardModel.make(.firstResultDays, input: input(feeds: feeds, now: at(9, 18)))
        XCTAssertEqual(model.visual, .bars([1, 1, 1, 1, 0, 1, 1]), "days 3–9; day 7 has no record")
    }

    func testOneDayWithRecordsIsThinTextInPlaceOfAChart() {
        let model = OfferCardModel.make(.firstResultDays, input: input(
            feeds: [at(2, 8), at(2, 11)], events: [at(1, 10)], now: at(2, 18)))
        XCTAssertEqual(model.visual, .thin, "an event is a record day for the rule, never a bar")
        XCTAssertEqual(model.body, "offer.first_result_days.body_thin".l)
        XCTAssertEqual(model.stats, [], "no counts under a missing chart")
        XCTAssertTrue(model.accessibilityLabel.contains("offer.thin_data".l))
    }

    func testARunningSleepIsARecordWithNoLengthYet() {
        let model = OfferCardModel.make(.firstResultDays, input: input(
            feeds: [at(1, 8)], sleeps: [(start: at(2, 16), end: nil)], now: at(2, 18)))
        XCTAssertEqual(model.visual, .bars([1, 1]))
        XCTAssertEqual(model.stats.last, String(format: "offer.stat.sleep_fmt".l, WeeklyFormat.duration(0)))
    }

    func testTheFirstWeekAlwaysDrawsSevenDaysAndHasOneBody() {
        let model = OfferCardModel.make(.firstWeek, input: input(feeds: [at(6, 8), at(8, 9)], now: at(8, 18)))
        XCTAssertEqual(model.visual, .bars([0, 0, 0, 0, 1, 0, 1]))
        let thin = OfferCardModel.make(.firstWeek, input: input(feeds: [at(8, 9)], now: at(8, 18)))
        XCTAssertEqual(thin.visual, .thin)
        XCTAssertEqual(thin.body, "offer.first_week.body".l)
    }

    // MARK: - Curve

    func testTheFirstResultPointNamesTheBabyAndShowsTheNewestWeighing() throws {
        let weighings = [WeightMeasurement(date: at(3, 10), weightKg: 3.3),
                         WeightMeasurement(date: at(10, 10), weightKg: 3.6),
                         WeightMeasurement(date: at(12, 10), weightKg: 3.9)]   // after now: not yet
        let model = OfferCardModel.make(.firstResultPoint, input: input(weighings: weighings, now: at(10, 18)))
        XCTAssertEqual(model.title, String(format: "offer.first_result_point.title_fmt".l, "Mia"))
        let newest = weighings[1]
        XCTAssertEqual(model.stats, [ReportFormat.kg(3.6), newest.date.appDayMonth])
        XCTAssertTrue(model.accessibilityLabel.contains(
            String(format: "offer.a11y.point_fmt".l, ReportFormat.kg(3.6), newest.date.appDayMonth)))
        guard case .curve(let curve) = model.visual else { return XCTFail("a curve: both weighings have a WHO reference") }
        XCTAssertEqual(curve.points.map(\.kg), [3.3, 3.6])
        XCTAssertGreaterThanOrEqual(curve.band.count, 2)
        let newestAge = try XCTUnwrap(curve.points.last?.ageDays)
        XCTAssertEqual(curve.ageDomain.upperBound, newestAge + Double(OfferCardModel.curveLeadDays))
    }

    func testNoNameOrALaterWeighingUsesTheGrowthPointTitle() {
        let weighing = [WeightMeasurement(date: at(3, 10), weightKg: 3.3)]
        XCTAssertEqual(OfferCardModel.make(.firstResultPoint, input: input(weighings: weighing, name: "  ", now: at(4))).title,
                       "offer.growth_point.title".l)
        XCTAssertEqual(OfferCardModel.make(.growthPoint, input: input(weighings: weighing, now: at(4))).title,
                       "offer.growth_point.title".l)
    }

    func testAWeighingTheStandardCannotJudgeDrawsNoCurve() {
        // Corrected birth a month ahead: the weighing is before term.
        let model = OfferCardModel.make(.growthPoint, input: input(
            weighings: [WeightMeasurement(date: at(3, 10), weightKg: 2.1)], birth: 30, now: at(4)))
        XCTAssertEqual(model.visual, .none)
        XCTAssertEqual(model.stats.count, 2, "the weighing itself is still the parent's own")
    }

    func testNoWeighingShowsNoPointAndNoStats() {
        let model = OfferCardModel.make(.growthPoint, input: input(now: at(4)))
        XCTAssertEqual(model.visual, .none)
        XCTAssertEqual(model.stats, [])
    }

    // MARK: - History edge and month report

    func testTheHistoryEdgeCountsRecordDaysAndNamesTheFreeWindow() {
        let model = OfferCardModel.make(.historyEdge, input: input(
            feeds: [at(0, 11), at(0, 14), at(5)], diapers: [at(9)], events: [at(16)], now: at(16, 18)))
        XCTAssertEqual(model.title, PluralFamily.offerHistoryEdgeTitle.text(4))
        XCTAssertEqual(model.body, PluralFamily.offerHistoryEdgeBody.text(HistoryWindow.freeDays))
        XCTAssertEqual(model.visual, .none)
        XCTAssertEqual(model.stats, [])
    }

    func testTheMonthReportAveragesPerDayWithEntriesLikeTheWeeklyCard() {
        let model = OfferCardModel.make(.monthReport, input: input(
            feeds: [at(20, 8), at(20, 11), at(21, 8), at(21, 11)],
            sleeps: [(start: at(20, 13), end: at(20, 14)), (start: at(21, 13), end: at(21, 14))],
            diapers: [at(22, 9)],
            now: at(27, 18)))
        XCTAssertEqual(model.stats, [String(format: "weekly.feeds_fmt".l, WeeklyFormat.perDay(4.0 / 3)),
                                     String(format: "weekly.sleep_fmt".l, WeeklyFormat.duration(7200.0 / 3))])
        XCTAssertEqual(OfferCardModel.make(.monthReport, input: input(now: at(27))).stats, [])
    }

    // MARK: - Never a paid figure

    func testNoCardCarriesAPercentAPriceOrAnUnfilledPlaceholder() {
        let records = input(feeds: (0...27).map { at($0, 8) }, sleeps: [(start: at(26, 13), end: at(26, 15))],
                            diapers: [at(27, 9)], growthDates: [at(10, 10)],
                            weighings: [WeightMeasurement(date: at(3, 10), weightKg: 3.3),
                                        WeightMeasurement(date: at(10, 10), weightKg: 3.6)],
                            now: at(27, 18))
        for content in OfferContent.allCases {
            let model = OfferCardModel.make(content, input: records)
            let text = ([model.title, model.body, model.accessibilityLabel] + model.stats).joined(separator: " ")
            for mark in ["%", "$", "€", "₽", "£"] {
                XCTAssertFalse(text.contains(mark), "\(content): «\(mark)» in «\(text)»")
            }
        }
    }
}

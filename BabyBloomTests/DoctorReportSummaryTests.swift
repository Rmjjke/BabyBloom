import XCTest
@testable import BabyBloom

private typealias Feed = DoctorReportSummary.Input.Feed
private typealias Sleep = DoctorReportSummary.Input.Sleep
private typealias Diaper = DoctorReportSummary.Input.Diaper
private typealias Growth = DoctorReportSummary.Input.Growth
private typealias Days = DoctorReportSummary.Days
private typealias Measure = DoctorReportSummary.Measure

/// The report's rules (requirements.md R2–R5) on plain values with a fixed
/// clock. The day bucketing itself is pinned by `PeriodSummaryTests`.
///
/// The WHO and newborn functions count ages through `Calendar.current`, so
/// every growth date sits at noon and well clear of an age boundary: the
/// tests must pass in whatever zone the simulator runs.
final class DoctorReportSummaryTests: XCTestCase {

    /// Europe/Berlin: the clocks go back on 25 Oct 2026, so 25 Oct is 25 h long.
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// The default period: a visit on 12 Oct, opened on Sunday 1 Nov at 09:00,
    /// so 20 full days have passed and today is the 21st.
    private var visitStart: Date { at(12, 0) }
    private var now: Date { at(1, 9, month: 11) }

    private func input(feeds: [Feed] = [], sleeps: [Sleep] = [], diapers: [Diaper] = [],
                       growth: [Growth] = [], birth: Date? = nil, correctedBirth: Date? = nil,
                       birthWeight: Double? = nil) -> DoctorReportSummary.Input {
        let birthDate = birth ?? at(1, 12, month: 6)
        return DoctorReportSummary.Input(feeds: feeds, sleeps: sleeps, diapers: diapers, growth: growth,
                                         birthDate: birthDate,
                                         correctedBirthDate: correctedBirth ?? birthDate,
                                         birthWeightKg: birthWeight, isMale: false)
    }

    private func make(_ input: DoctorReportSummary.Input, start: Date? = nil, now: Date? = nil,
                      startsAtVisit: Bool = true) -> DoctorReportSummary {
        DoctorReportSummary.make(input: input, periodStart: start ?? visitStart, now: now ?? self.now,
                                 startsAtVisit: startsAtVisit, calendar: calendar)
    }

    private func feed(_ start: Date, minutes: Double = 15, _ type: FeedingEntry.FeedingType = .breast,
                      ml: Double? = nil) -> Feed {
        Feed(start: start, end: start.addingTimeInterval(minutes * 60), type: type, volumeML: ml)
    }

    private func sleep(_ start: Date, _ end: Date) -> Sleep { Sleep(start: start, end: end) }

    /// One feed at 10:00 on each day of October listed.
    private func dailyFeeds(_ days: [Int]) -> [Feed] { days.map { feed(at($0, 10)) } }

    // MARK: R2 — what counts

    func testRunningFeedsAndSleepsAreNotCountedAnywhere() {
        let running = input(feeds: [Feed(start: at(1, 8, month: 11), type: .formula)],
                            sleeps: [Sleep(start: at(1, 7, month: 11))])
        XCTAssertNil(make(running).feeding, "a running feed alone is no feed")
        XCTAssertNil(make(running).sleep, "a running sleep alone is no sleep")

        var mixed = running
        mixed.feeds.append(feed(at(31, 10)))
        mixed.sleeps.append(sleep(at(31, 13), at(31, 14)))
        let summary = make(mixed)
        XCTAssertEqual(summary.feeding?.totalFeeds, 1)
        XCTAssertEqual(summary.feeding?.byType, [], "the running formula is not a second type")
        XCTAssertEqual(summary.feeding?.days, Days(withEntries: 1, counted: 20),
                       "the running feed does not make today a day with a feed")
        XCTAssertEqual(summary.sleep?.total, 3600)
        XCTAssertEqual(summary.sleep?.days, Days(withEntries: 1, counted: 20))
    }

    func testANightCrossingThePeriodStartCountsOnlyItsPartOnDayZero() {
        let summary = make(input(sleeps: [
            sleep(at(11, 21), at(12, 5)),     // 3 h before the visit day, 5 h after
            sleep(at(11, 20), at(12, 0)),     // ends exactly at the start
            sleep(at(10, 13), at(10, 14)),    // wholly before
            sleep(at(13, 13), at(13, 14)),
        ]))
        XCTAssertEqual(summary.sleep?.total, 6 * 3600)
        XCTAssertEqual(summary.sleep?.longest, 5 * 3600)
        XCTAssertEqual(summary.sleep?.longestStart, visitStart, "the clipped part is filed on day 0")
        XCTAssertEqual(summary.sleep?.days.withEntries, 2)
        XCTAssertEqual(summary.sleep?.perDay, 3 * 3600)
    }

    /// 24–28 Oct crosses the autumn change: 25 Oct has 25 hours. Every entry
    /// stays on its own day and a night across the change is its real length.
    func testAPeriodAcrossTheDSTChangeKeepsDaysAndLengths() {
        let summary = make(input(
            feeds: [feed(at(24, 12)), feed(at(25, 23, 30)), feed(at(26, 0, 30)), feed(at(27, 12))],
            sleeps: [sleep(at(25, 1), at(25, 6))]),
                           start: at(24, 0), now: at(28, 10))
        XCTAssertEqual(summary.periodDays, 4)
        XCTAssertFalse(summary.isShort)
        XCTAssertEqual(summary.feeding?.days, Days(withEntries: 4, counted: 4),
                       "23:30 on the 25th and 00:30 on the 26th are two days")
        XCTAssertEqual(summary.feeding?.feedsPerDay, 1)
        XCTAssertEqual(summary.sleep?.total, 6 * 3600, "01:00–06:00 on 25 Oct is six hours")
    }

    // MARK: R3 — averages and the days line

    func testEachSectionAveragesOverItsOwnDays() {
        let feeds = (12...21).flatMap { day in [feed(at(day, 6)), feed(at(day, 12)), feed(at(day, 18))] }
        let sleeps = (12...31).map { sleep(at($0, 13), at($0, 15)) }
        let diapers = (12...16).flatMap { day in
            [Diaper(time: at(day, 8), type: .wet), Diaper(time: at(day, 14), type: .wet)]
        }
        let summary = make(input(feeds: feeds, sleeps: sleeps, diapers: diapers))
        XCTAssertEqual(summary.feeding?.feedsPerDay, 3, "30 feeds over the 10 days with a feed")
        XCTAssertEqual(summary.sleep?.perDay, 2 * 3600, "over the 20 days with sleep")
        XCTAssertEqual(summary.diapers?.wetPerDay, 2, "10 wet over the 5 days with a diaper")
        XCTAssertEqual(summary.diapers?.dirtyPerDay, 0)
        XCTAssertEqual(summary.feeding?.days, Days(withEntries: 10, counted: 20))
        XCTAssertEqual(summary.sleep?.days, Days(withEntries: 20, counted: 20))
    }

    /// Averages and the days line cover the FINISHED days: an untouched
    /// morning does not print «20 of 21», and a fed morning does not count as
    /// a whole day either.
    func testTheDaysLineCoversFinishedDaysOnly() {
        let everyPastDay = dailyFeeds(Array(12...31))
        let emptyToday = make(input(feeds: everyPastDay)).feeding?.days
        XCTAssertEqual(emptyToday, Days(withEntries: 20, counted: 20))
        XCTAssertEqual(emptyToday?.showsLine, false)

        let fedToday = make(input(feeds: everyPastDay + [feed(at(1, 8, month: 11))])).feeding
        XCTAssertEqual(fedToday?.days, Days(withEntries: 20, counted: 20))
        XCTAssertEqual(fedToday?.totalFeeds, 21, "today stays in the count")

        let gaps = dailyFeeds(Array(12...31).filter { ![15, 20, 25].contains($0) })
        let withGaps = make(input(feeds: gaps)).feeding?.days
        XCTAssertEqual(withGaps, Days(withEntries: 17, counted: 20))
        XCTAssertEqual(withGaps?.showsLine, true)
        XCTAssertEqual(make(input(feeds: gaps + [feed(at(1, 8, month: 11))])).feeding?.days,
                       Days(withEntries: 17, counted: 20))
    }

    /// The reviewer's case: three full days of 8 feeds, then 2 this morning.
    /// Dividing by four days read 6.5; the finished days say 8.
    func testAPartialTodayDoesNotPullTheAveragesDown() {
        let full = (29...31).flatMap { day in (0..<8).map { feed(at(day, 1 + $0 * 3)) } }
        let morning = [feed(at(1, 6, month: 11)), feed(at(1, 8, month: 11))]
        let wet = (29...31).flatMap { day in (0..<6).map { Diaper(time: at(day, 2 + $0 * 3), type: .wet) } }
        let summary = make(input(feeds: full + morning,
                                 diapers: wet + [Diaper(time: at(1, 7, month: 11), type: .wet)]),
                           start: at(29, 0))
        XCTAssertEqual(summary.feeding?.feedsPerDay, 8)
        XCTAssertEqual(summary.feeding?.totalFeeds, 26)
        XCTAssertEqual(summary.diapers?.wetPerDay, 6)
        XCTAssertEqual(summary.diapers?.wetCount, 19)
    }

    func testAShortPeriodHasCountsAndNoPerDayFigures() {
        let summary = make(input(
            feeds: [feed(at(31, 8), .formula, ml: 90), feed(at(31, 12)), feed(at(1, 7, month: 11), .formula, ml: 60)],
            sleeps: [sleep(at(31, 13), at(31, 15))],
            diapers: [Diaper(time: at(31, 9), type: .wet), Diaper(time: at(31, 10), type: .both)]),
                           start: at(31, 0))
        XCTAssertEqual(summary.periodDays, 1)
        XCTAssertTrue(summary.isShort)
        XCTAssertEqual(summary.feeding?.totalFeeds, 3)
        XCTAssertNil(summary.feeding?.feedsPerDay)
        XCTAssertNil(summary.feeding?.bottleMLPerDay, "a bottle a day is a per-day figure too")
        XCTAssertEqual(summary.feeding?.breastfeedAverage, 15 * 60, "not a per-day figure: kept")
        XCTAssertEqual(summary.sleep?.total, 2 * 3600)
        XCTAssertNil(summary.sleep?.perDay)
        XCTAssertEqual(summary.diapers?.wetCount, 2)
        XCTAssertEqual(summary.diapers?.dirtyCount, 1)
        XCTAssertNil(summary.diapers?.wetPerDay)
        XCTAssertNil(summary.diapers?.dirtyPerDay)

        XCTAssertTrue(make(input(), start: at(1, 0, month: 11)).isShort, "a visit today is day 0")
        XCTAssertTrue(make(input(), start: at(30, 0)).isShort, "two full days is still short")
        XCTAssertFalse(make(input(), start: at(29, 0)).isShort, "three full days is not short")
    }

    // MARK: R4 — growth

    func testTheLatestWeightIsOfAnyDateAndAFutureRowBeyondADayIsIgnored() {
        let before = make(input(growth: [Growth(date: at(1, 12, month: 9), weightKg: 5.0),
                                         Growth(date: at(20, 12, month: 9), weightKg: 5.4)])).growth
        XCTAssertEqual(before.latestWeight, Measure(value: 5.4, date: at(20, 12, month: 9)),
                       "a weighing before the period is still the latest")
        XCTAssertEqual(before.weighings, [], "but it is not one of the period's")

        let future = make(input(growth: [Growth(date: at(20, 12), weightKg: 5.4),
                                         Growth(date: at(1, 15, month: 11), weightKg: 5.6),
                                         Growth(date: at(4, 12, month: 11), weightKg: 9.9)])).growth
        XCTAssertEqual(future.latestWeight?.value, 5.6, "six hours ahead is inside the tolerance")
        XCTAssertEqual(future.weighings.map(\.weightKg), [5.6, 5.4])
    }

    func testTheChangeIsHiddenInTheNewbornWindow() {
        let birth = at(20, 12)
        let weighings = [Growth(date: at(21, 12), weightKg: 3.2), Growth(date: at(30, 12), weightKg: 3.5)]
        let newborn = make(input(growth: weighings, birth: birth, birthWeight: 3.4), start: at(20, 0))
        XCTAssertNil(newborn.growth.change)
        XCTAssertEqual(newborn.growth.latestWeight?.value, 3.5, "only the change is withheld")

        // Without a birth weight there is no newborn instrument, so no gate (D17).
        let ungated = make(input(growth: weighings, birth: birth), start: at(20, 0)).growth.change
        XCTAssertEqual(ungated?.grams, 300)
    }

    func testTheChangeIsHiddenWithOneWeighing() {
        let growth = make(input(growth: [Growth(date: at(20, 12), weightKg: 5.4)])).growth
        XCTAssertNotNil(growth.latestWeight)
        XCTAssertNil(growth.change)
    }

    func testTheChangeBaseIsTheLatestWeighingAtOrBeforeTheStart() {
        let change = make(input(growth: [
            Growth(date: at(1, 12), weightKg: 5.0),
            Growth(date: at(10, 12), weightKg: 5.3),
            Growth(date: at(20, 12), weightKg: 5.6),
            Growth(date: at(30, 12), weightKg: 5.9374),
        ], birthWeight: 3.4)).growth.change
        XCTAssertEqual(change?.baseDate, at(10, 12))
        XCTAssertEqual(change?.grams, 640, "637.4 g, to the nearest 10")
    }

    func testTheChangeBaseIsTheFirstWeighingInThePeriodWhenNoneIsBefore() {
        let gain = make(input(growth: [Growth(date: at(14, 12), weightKg: 5.2),
                                       Growth(date: at(22, 12), weightKg: 5.5),
                                       Growth(date: at(30, 12), weightKg: 5.9374)])).growth.change
        XCTAssertEqual(gain?.baseDate, at(14, 12))
        XCTAssertEqual(gain?.grams, 740)

        let loss = make(input(growth: [Growth(date: at(14, 12), weightKg: 5.5),
                                       Growth(date: at(30, 12), weightKg: 5.3)])).growth.change
        XCTAssertEqual(loss?.grams, -200, "a sign, never hidden for being a loss")
    }

    /// The visit's own weighing, stamped at 11:00 on the visit day, is the
    /// base — not the one a month before (design § 2.1).
    func testTheVisitDaysWeighingIsTheBase() {
        let change = make(input(growth: [Growth(date: at(12, 11, month: 9), weightKg: 4.2),
                                         Growth(date: at(12, 11), weightKg: 5.0),
                                         Growth(date: at(30, 12), weightKg: 5.42)],
                                birthWeight: 3.4)).growth.change
        XCTAssertEqual(change?.baseDate, at(12, 11))
        XCTAssertEqual(change?.grams, 420)
    }

    func testTheChangeIsHiddenWhenTheBaseIsTheLatestWeighing() {
        let growth = make(input(growth: [Growth(date: at(1, 12), weightKg: 5.0),
                                         Growth(date: at(10, 12), weightKg: 5.3)])).growth
        XCTAssertNil(growth.change, "nothing was weighed since the visit")
    }

    func testThePeriodsWeighingsAreNewestFirstWithASameDayHeightAndHead() {
        let weighings = make(input(growth: [
            Growth(date: at(10, 12), weightKg: 5.3, heightCm: 59),     // before the period
            Growth(date: at(15, 12), weightKg: 5.5, heightCm: 60),
            Growth(date: at(22, 8), weightKg: 5.7),
            Growth(date: at(22, 18), heightCm: 61, headCm: 39),        // no weight, same day
            Growth(date: at(29, 12), weightKg: 5.9, headCm: 40),
        ])).growth.weighings
        XCTAssertEqual(weighings, [
            .init(date: at(29, 12), weightKg: 5.9, heightCm: nil, headCm: 40),
            .init(date: at(22, 8), weightKg: 5.7, heightCm: 61, headCm: 39),
            .init(date: at(15, 12), weightKg: 5.5, heightCm: 60, headCm: nil),
        ])
    }

    func testAtBirthComesFromTheBirthWeightAndTheBirthDayHeight() {
        let birth = at(1, 9, month: 6)
        let growth = make(input(growth: [Growth(date: at(1, 18, month: 6), weightKg: 3.3, heightCm: 51),
                                         Growth(date: at(2, 12, month: 6), heightCm: 52)],
                                birth: birth, birthWeight: 3.4)).growth
        XCTAssertEqual(growth.atBirthWeightKg, 3.4, "the recorded birth weight, not a weighing")
        XCTAssertEqual(growth.atBirthHeightCm, 51)

        let unknown = make(input(growth: [Growth(date: at(2, 12, month: 6), heightCm: 52)], birth: birth)).growth
        XCTAssertNil(unknown.atBirthWeightKg)
        XCTAssertNil(unknown.atBirthHeightCm, "the next day's height is not a birth length")
    }

    func testBothPercentilesAreReadingsAtTheMeasurementsOwnDate() {
        let growth = make(input(growth: [Growth(date: at(1, 12), weightKg: 6.4, heightCm: 62, headCm: 40)])).growth
        guard case .reading(let weight) = growth.weightPercentile,
              case .reading(let height) = growth.heightPercentile
        else { return XCTFail("expected two readings, got \(growth.weightPercentile), \(growth.heightPercentile)") }
        XCTAssertFalse(weight.isBeyondChart)
        XCTAssertFalse(height.isBeyondChart)
        XCTAssertEqual(weight, WHOGrowthStandard.percentileReading(
            of: WeightMeasurement(date: at(1, 12), weightKg: 6.4),
            correctedBirthDate: at(1, 12, month: 6), isMale: false))
        XCTAssertEqual(growth.latestHead, Measure(value: 40, date: at(1, 12)))
    }

    /// Past the chart's edge the row keeps the reading, so the view prints the
    /// badge («> 97») rather than a clamped 99 that reads as measured.
    func testAPercentileBeyondTheChartIsAReadingFlaggedAsBeyond() {
        let growth = make(input(growth: [Growth(date: at(1, 12), weightKg: 12, heightCm: 80)],
                                birth: at(1, 12, month: 8))).growth
        guard case .reading(let weight) = growth.weightPercentile,
              case .reading(let height) = growth.heightPercentile
        else { return XCTFail("expected two readings") }
        XCTAssertTrue(weight.isBeyondChart)
        XCTAssertEqual(weight.percentile, 99)
        XCTAssertTrue(height.isBeyondChart)
    }

    /// Born at 30 weeks on 1 Oct: due on 10 Dec, so an October weighing has no
    /// honest percentile.
    func testAMeasurementBeforeTheDueDateHasNoPercentile() {
        let birth = at(1, 12)
        let corrected = calendar.date(byAdding: .day, value: 70, to: birth)!
        let growth = make(input(growth: [Growth(date: at(20, 12), weightKg: 1.6, heightCm: 42, headCm: 30)],
                                birth: birth, correctedBirth: corrected),
                          start: at(1, 0)).growth
        XCTAssertEqual(growth.weightPercentile, .beforeDueDate)
        XCTAssertEqual(growth.heightPercentile, .beforeDueDate)
        XCTAssertEqual(growth.latestWeight?.value, 1.6, "the weight itself still shows")
    }

    func testAMeasurementAt25MonthsIsOutOfRange() {
        let growth = make(input(growth: [Growth(date: at(20, 12), weightKg: 12.5, heightCm: 88)],
                                birth: at(1, 12, year: 2024))).growth
        XCTAssertEqual(growth.weightPercentile, .outOfRange)
        XCTAssertEqual(growth.heightPercentile, .outOfRange)
    }

    func testNoMeasurementHasNoPercentileRow() {
        let empty = make(input()).growth
        XCTAssertEqual(empty.weightPercentile, DoctorReportSummary.PercentileRow.none)
        XCTAssertEqual(empty.heightPercentile, DoctorReportSummary.PercentileRow.none)
        XCTAssertTrue(empty.isEmpty)
        XCTAssertNil(empty.change)

        let heightOnly = make(input(growth: [Growth(date: at(1, 12), heightCm: 62)])).growth
        XCTAssertEqual(heightOnly.weightPercentile, DoctorReportSummary.PercentileRow.none)
        XCTAssertFalse(heightOnly.isEmpty)
    }

    // MARK: R5 — feeding, sleep, diapers

    func testByTypeIsHiddenWithOneTypeAndMostFrequentFirstWithMore() {
        let breastOnly = make(input(feeds: [feed(at(13, 8)), feed(at(13, 12))])).feeding
        XCTAssertEqual(breastOnly?.byType, [])

        let mixed = make(input(feeds: [
            feed(at(13, 8)),
            feed(at(13, 10), .formula, ml: 90), feed(at(14, 10), .formula, ml: 90),
            feed(at(13, 12), .pumped, ml: 60), feed(at(14, 12), .pumped), feed(at(15, 12), .pumped),
        ])).feeding
        XCTAssertEqual(mixed?.byType, [.init(type: .pumped, count: 3), .init(type: .formula, count: 2),
                                       .init(type: .breast, count: 1)])

        let tie = make(input(feeds: [feed(at(13, 10), .formula), feed(at(13, 8))])).feeding
        XCTAssertEqual(tie?.byType.map(\.type), [.breast, .formula], "a tie keeps a fixed order")
    }

    func testBottleADayIsFormulaPlusExpressedOverDaysWithAVolume() {
        let feeding = make(input(feeds: [
            feed(at(13, 8), .formula, ml: 90), feed(at(13, 14), .pumped, ml: 60),
            feed(at(14, 8), .formula),                   // no volume
            feed(at(15, 8), .formula, ml: 0),            // an unfilled field
            feed(at(16, 8), .formula, ml: 120),
            feed(at(17, 8), .breast),
        ])).feeding
        XCTAssertEqual(feeding?.bottleMLPerDay, 135, "270 ml over the 2 days with a measured bottle")

        XCTAssertNil(make(input(feeds: [feed(at(13, 8), .formula), feed(at(14, 8))])).feeding?.bottleMLPerDay,
                     "no volume logged: no row")
    }

    func testTheBreastfeedAverageIsOverFinishedBreastfeedsOnly() {
        let feeding = make(input(feeds: [
            feed(at(13, 8), minutes: 10), feed(at(14, 8), minutes: 20),
            feed(at(15, 8), minutes: 30, .formula, ml: 90),
            Feed(start: at(1, 8, month: 11), type: .breast),     // running
        ])).feeding
        XCTAssertEqual(feeding?.breastfeedAverage, 15 * 60)
        XCTAssertNil(make(input(feeds: [feed(at(13, 8), .formula)])).feeding?.breastfeedAverage)
    }

    func testABothDiaperCountsAsWetAndAsDirty() {
        let diapers = make(input(diapers: [Diaper(time: at(13, 8), type: .wet),
                                           Diaper(time: at(13, 10), type: .dirty),
                                           Diaper(time: at(13, 12), type: .both)])).diapers
        XCTAssertEqual(diapers?.wetCount, 2)
        XCTAssertEqual(diapers?.dirtyCount, 2)
    }

    func testStoolColoursAreMostFrequentFirst() {
        let diapers = make(input(diapers: [
            Diaper(time: at(13, 8), type: .dirty, color: .yellow),
            Diaper(time: at(13, 10), type: .both, color: .green),
            Diaper(time: at(14, 10), type: .dirty, color: .green),
            Diaper(time: at(15, 10), type: .dirty, color: .green),
            Diaper(time: at(15, 12), type: .dirty),
        ])).diapers
        XCTAssertEqual(diapers?.colors, [.init(color: .green, count: 3), .init(color: .yellow, count: 1)])

        let none = make(input(diapers: [Diaper(time: at(13, 8), type: .wet)])).diapers
        XCTAssertEqual(none?.colors, [], "no colour logged: no line")
    }

    func testASectionWithNoEntryInThePeriodIsNil() {
        let summary = make(input(feeds: [feed(at(13, 8))],
                                 sleeps: [sleep(at(5, 13), at(5, 14))],
                                 diapers: [Diaper(time: at(11, 23, 59), type: .wet)]))
        XCTAssertNotNil(summary.feeding)
        XCTAssertNil(summary.sleep, "a sleep before the period does not count")
        XCTAssertNil(summary.diapers, "a minute before the visit day is the old period")
        XCTAssertFalse(summary.showsNewPeriodCard)
    }

    /// A visit today with nothing logged since: one card, and the growth facts
    /// that do not depend on the period still there.
    func testTheNewPeriodCardOnlyWhenTheVisitStartsAnEmptyPeriod() {
        let today = at(1, 0, month: 11)
        let old = input(feeds: [feed(at(31, 20)), Feed(start: at(1, 8, month: 11), type: .breast)],
                        sleeps: [sleep(at(31, 13), at(31, 15))],
                        diapers: [Diaper(time: at(31, 21), type: .wet)],
                        growth: [Growth(date: at(25, 12), weightKg: 5.8)])
        let visitToday = make(old, start: today)
        XCTAssertTrue(visitToday.showsNewPeriodCard, "the running feed is not an entry")
        XCTAssertEqual(visitToday.growth.latestWeight?.value, 5.8)

        XCTAssertFalse(make(old, start: today, startsAtVisit: false).showsNewPeriodCard,
                       "never for «since birth»")

        var fed = old
        fed.feeds.append(feed(at(1, 7, month: 11)))
        XCTAssertFalse(make(fed, start: today).showsNewPeriodCard)

        var weighed = old
        weighed.growth.append(Growth(date: at(1, 8, month: 11), weightKg: 5.9))
        XCTAssertFalse(make(weighed, start: today).showsNewPeriodCard)

        XCTAssertFalse(make(input(), start: at(12, 0)).showsNewPeriodCard,
                       "a visit weeks ago with nothing since shows the «No … since» lines")
    }

    // MARK: Boundaries

    func testAnEntryExactlyAtTheStartCountsAndOneJustBeforeDoesNot() {
        let summary = make(input(feeds: [feed(visitStart), feed(visitStart.addingTimeInterval(-60))]))
        XCTAssertEqual(summary.feeding?.totalFeeds, 1)
    }

    /// A sleep is held at `now` too: with -BBNow behind the real clock it
    /// cannot count sleep that has not happened in that world.
    func testASleepIsClippedAtNow() {
        let summary = make(input(sleeps: [sleep(at(1, 7, month: 11), at(1, 11, month: 11))]))
        XCTAssertEqual(summary.sleep?.total, 2 * 3600, "07:00 → now 09:00")
    }
}

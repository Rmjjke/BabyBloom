import XCTest
@testable import BabyBloom

/// The weekly card's rules with a fixed clock: Monday weeks (D8), averages over
/// days with entries (D19), the gain pair (D27) and the newborn gate (D17).
final class WeeklySummaryTests: XCTestCase {

    private let calendar = WeeklySummary.calendar

    /// Local time, so the week edges are the parent's midnights.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Wednesday 28 Oct 2026: last week is Mon 19 – Sun 25 Oct.
    private lazy var now = date(2026, 10, 28)

    private func input(feeds: [Date] = [], sleeps: [(Date, Date)] = [], other: [Date] = [],
                       weights: [(Date, Double)] = [], birth: Date? = nil,
                       birthWeight: Double? = nil) -> WeeklySummary.Input {
        let birthDate = birth ?? date(2026, 6, 1)
        return WeeklySummary.Input(
            feeds: feeds,
            sleeps: sleeps.map { (start: $0.0, end: $0.1) },
            otherEntries: other,
            measurements: weights.map { WeightMeasurement(date: $0.0, weightKg: $0.1) },
            birthDate: birthDate, correctedBirthDate: birthDate,
            birthWeightKg: birthWeight, isMale: false)
    }

    func testLastWeekIsMondayToSundayWhateverTheLocale() {
        let week = WeeklySummary.lastWeek(now: now)
        XCTAssertEqual(week.start, date(2026, 10, 19, 0))
        XCTAssertEqual(week.end, date(2026, 10, 26, 0))
        XCTAssertEqual(calendar.component(.weekday, from: week.start), 2, "a Monday")
    }

    /// The boundary QA seeds (L3): at Sunday 23:59 "last week" is still the
    /// one before; one minute later it is the week that just ended.
    func testSundayMidnightTurnsTheWeek() {
        let sunday = date(2026, 10, 25, 23, 59)
        let monday = date(2026, 10, 26, 0, 0)
        XCTAssertEqual(WeeklySummary.lastWeek(now: sunday).start, date(2026, 10, 12, 0))
        XCTAssertEqual(WeeklySummary.lastWeek(now: monday).start, date(2026, 10, 19, 0))
    }

    func testAnEmptyWeekHasNoSummary() {
        let only = input(feeds: [date(2026, 10, 27)])   // this week, not last
        XCTAssertNil(WeeklySummary.make(now: now, input: only))
    }

    /// D19: 12 feeds over the 3 days that have entries is 4 a day, not 12/7.
    func testAveragesDivideByDaysWithEntries() throws {
        let feeds = (0..<4).flatMap { hour in
            [date(2026, 10, 19, 8 + hour), date(2026, 10, 21, 8 + hour), date(2026, 10, 25, 8 + hour)]
        }
        let summary = try XCTUnwrap(WeeklySummary.make(now: now, input: input(feeds: feeds)))
        XCTAssertEqual(summary.current.daysWithEntries, 3)
        XCTAssertEqual(summary.current.feedsPerDay, 4)
        XCTAssertEqual(summary.current.feedsByDay, [4, 0, 4, 0, 0, 0, 4])
        XCTAssertNil(summary.current.sleepPerDay, "no sleep logged: the row is left out, not 0")
    }

    /// A diaper-only day still counts as a day with entries.
    func testEveryKindCountsTowardsDaysWithEntries() throws {
        let summary = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 19)], other: [date(2026, 10, 20)])))
        XCTAssertEqual(summary.current.daysWithEntries, 2)
        XCTAssertEqual(summary.current.feedsPerDay, 0.5)
    }

    /// A sleep belongs to the day it starts, whole, even across midnight.
    func testSleepCountsOnItsStartDay() throws {
        let night = (date(2026, 10, 25, 22), date(2026, 10, 26, 6))   // Sunday into Monday
        let nap = (date(2026, 10, 20, 13), date(2026, 10, 20, 14, 30))
        let summary = try XCTUnwrap(WeeklySummary.make(now: now, input: input(sleeps: [night, nap])))
        XCTAssertEqual(summary.current.sleepByDay[6], 8 * 3600)
        XCTAssertEqual(summary.current.sleepByDay[1], 90 * 60)
        XCTAssertEqual(summary.current.longestSleep, 8 * 3600)
        XCTAssertEqual(summary.current.sleepPerDay, (8 * 3600 + 90 * 60) / 2)
    }

    /// S2: nothing in the week before, so nothing to compare with.
    func testTheFirstWeekHasNoPrevious() throws {
        let first = try XCTUnwrap(WeeklySummary.make(now: now, input: input(feeds: [date(2026, 10, 22)])))
        XCTAssertNil(first.previous)
        let second = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22), date(2026, 10, 14)])))
        XCTAssertEqual(second.previous?.daysWithEntries, 1)
    }

    /// D27: the pair whose LATER weighing is inside the week, ≥ 3 days apart,
    /// rounded to 10 g. 4.000 → 4.209 kg over 7 days is 209 g/week → 210.
    func testGainIsThePairEndingInTheWeek() throws {
        let weights = [(date(2026, 10, 15), 4.0), (date(2026, 10, 22), 4.209)]
        let summary = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights)))
        XCTAssertEqual(summary.gain, .perWeek(210))
        XCTAssertEqual(WeeklySummary.signed(210), "+210")
        XCTAssertEqual(WeeklySummary.signed(-30), "-30")
    }

    /// A pair that ended before the week is that week's gain, not this one's.
    func testAnOlderPairIsNotRepeated() throws {
        let weights = [(date(2026, 10, 5), 4.0), (date(2026, 10, 12), 4.2)]
        let summary = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights)))
        XCTAssertEqual(summary.gain, .needsWeighing)
    }

    /// A weighing after the week's end is not part of last week's pair.
    func testAWeighingAfterTheWeekIsIgnored() throws {
        let weights = [(date(2026, 10, 15), 4.0), (date(2026, 10, 22), 4.2), (date(2026, 10, 27), 4.3)]
        let summary = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights)))
        XCTAssertEqual(summary.gain, .perWeek(200))
    }

    /// D17: inside the newborn window there is no number, whatever the pair.
    func testNoNumberInTheNewbornWindow() throws {
        let birth = date(2026, 10, 12)
        let weights = [(date(2026, 10, 15), 3.3), (date(2026, 10, 22), 3.5)]
        let summary = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights,
                                   birth: birth, birthWeight: 3.4)))
        XCTAssertEqual(summary.gain, .newborn)
    }

    /// D17 on the week-before line too (review, 2026-10-29). Born 25 Sep: last
    /// week's pair ends on day 28 and shows a number, but the week before's
    /// ends on day 21, inside the dip, and must not.
    func testTheWeekBeforeLineHasTheNewbornGateToo() throws {
        let weights = [(date(2026, 10, 12), 3.3), (date(2026, 10, 16), 3.35), (date(2026, 10, 23), 3.6)]
        let gated = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights,
                                   birth: date(2026, 9, 25), birthWeight: 3.4)))
        guard case .perWeek = gated.gain else { return XCTFail("last week's pair is past the window") }
        XCTAssertNil(gated.previousGain)

        // Without a birth weight there is no newborn instrument, so no gate.
        let ungated = try XCTUnwrap(WeeklySummary.make(
            now: now, input: input(feeds: [date(2026, 10, 22)], weights: weights, birth: date(2026, 9, 25))))
        XCTAssertNotNil(ungated.previousGain)
    }

    /// A day with only a sleep on it is a day with entries.
    func testASleepOnlyDayCounts() throws {
        let summary = try XCTUnwrap(WeeklySummary.make(now: now, input: input(
            feeds: [date(2026, 10, 19)], sleeps: [(date(2026, 10, 21, 13), date(2026, 10, 21, 14))])))
        XCTAssertEqual(summary.current.daysWithEntries, 2)
        XCTAssertEqual(summary.current.feedsPerDay, 0.5)
    }

    /// 10 g rounding, and a loss keeps its sign. Not at an exact .5: the
    /// grams come out of kg arithmetic, and 0.205 kg is not 205 g in binary.
    func testGainRoundingAndSign() throws {
        // 4.000 → 4.214 kg over 7 days: 214 g → 210; 4.000 → 3.970: −30.
        let up = try XCTUnwrap(WeeklySummary.make(now: now, input: input(
            feeds: [date(2026, 10, 22)], weights: [(date(2026, 10, 15), 4.0), (date(2026, 10, 22), 4.214)])))
        XCTAssertEqual(up.gain, .perWeek(210))
        let down = try XCTUnwrap(WeeklySummary.make(now: now, input: input(
            feeds: [date(2026, 10, 22)], weights: [(date(2026, 10, 15), 4.0), (date(2026, 10, 22), 3.97)])))
        XCTAssertEqual(down.gain, .perWeek(-30))
        XCTAssertEqual(WeeklySummary.signed(0), "0")
    }
}

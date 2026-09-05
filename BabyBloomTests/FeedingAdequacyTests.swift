import XCTest
@testable import BabyBloom

final class FeedingAdequacyTests: XCTestCase {

    // MARK: - Feeding frequency reference

    func testFeedingReferenceNarrowsWithAge() {
        let newborn = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .breast)
        let older   = FeedingAdequacy.feedingReference(correctedAgeDays: 150, style: .breast)
        XCTAssertEqual(newborn, 8...12)
        XCTAssertEqual(older, 5...7)
    }

    func testFormulaFedBabiesAreHeldToALowerFrequency() {
        // A formula-fed newborn genuinely feeds less often; one table for both
        // would flag healthy babies.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .formula), 6...8)
    }

    /// The rows change on an exact day, so both sides of every seam are pinned:
    /// a `<` where `<=` belongs would otherwise shift a whole band by a day and
    /// still leave the suite green.
    func testEachAgeBandStartsOnTheDayTheTableSays() {
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 27, style: .breast), 8...12)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 28, style: .breast), 7...9)

        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 119, style: .formula), 5...7)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 120, style: .formula), 4...6)
    }

    func testMixedFeedingUsesTheUnionOfBothBands() {
        // Neither table fully applies, so the stricter edge of each must not bite.
        let mixed = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .mixed)
        XCTAssertEqual(mixed, 6...12)
    }

    /// The union has to hold on every row, not just the newborn one — each row
    /// pairs different bands and so produces a different union.
    func testMixedFeedingUnionHoldsOnTheLaterRowsToo() {
        // 7...9 with 5...7.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 28, style: .mixed), 5...9)
        // 5...7 with 4...6.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 150, style: .mixed), 4...7)
    }

    func testFeedingReferenceIsNilPastSixMonths() {
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 200, style: .breast))
    }

    /// The feature is meant to cover the whole of 0–6 months and stop the day
    /// after. An off-by-one in the age guard would quietly cut it short.
    func testFeedingReferenceCoversTheLastCoveredDayAndStopsTheDayAfter() {
        XCTAssertEqual(FeedingAdequacy.maxAgeDays, 183)
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 183, style: .breast), 5...7)
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 184, style: .breast))
    }

    /// The gate and the table are separate questions, and the Dashboard's ring
    /// depends on it: past six months `feedingReference` withholds a verdict
    /// while `feedingBand` still names the last row, so a display target has a
    /// number without any caller carrying an unreachable fallback.
    func testTheBandOutlivesTheReferenceItGates() {
        let pastTheRange = FeedingAdequacy.maxAgeDays + 1
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: pastTheRange, style: .breast))
        XCTAssertEqual(FeedingAdequacy.feedingBand(correctedAgeDays: pastTheRange, style: .breast), 5...7)

        // Inside the range the two must never disagree — the reference IS the
        // band plus a gate.
        for days in [0, 27, 28, 119, 120, FeedingAdequacy.maxAgeDays] {
            XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: days, style: .breast),
                           FeedingAdequacy.feedingBand(correctedAgeDays: days, style: .breast),
                           "day \(days)")
        }
    }

    // MARK: - Wet nappy reference

    /// The charted ramp is not simply "the day number": it flattens at 3, so
    /// day 4 expects 3, the same as day 3.
    func testWetNappyMinimumFollowsTheChartedRampInTheFirstDays() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 1), 1)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 2), 2)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 3), 3)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 4), 3)
    }

    func testWetNappyMinimumIsSixFromDayFive() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 5), 6)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 90), 6)
    }

    /// A reference of zero would read as "none expected", which is never true.
    func testWetNappyMinimumIsNeverZeroOnTheDayOfBirth() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 0), 1)
    }

    // MARK: - Window

    /// A fixed instant in a fixed calendar for the whole test case.
    ///
    /// `Date()` advances between calls, so a window anchored on one call sits
    /// microseconds before an entry anchored on a later one and silently drops
    /// it. The device calendar adds a second trap: a daylight-saving transition
    /// inside the window changes its duration by an hour, which moves every
    /// per-day figure the tests assert on — twice a year, on some devices only.
    /// A UTC calendar and a fixed date remove both.
    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let now = FeedingAdequacyTests.calendar.date(
        from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!

    private func day(_ offset: Int) -> Date {
        Self.calendar.date(byAdding: .day, value: offset, to: now)!
    }

    private func hours(_ offset: Int) -> Date {
        Self.calendar.date(byAdding: .hour, value: offset, to: now)!
    }

    func testWindowSpansTheNewestMeasurablePair() throws {
        let measurements = [
            WeightMeasurement(date: day(-30), weightKg: 3.4),
            WeightMeasurement(date: day(-9),  weightKg: 4.0),
            WeightMeasurement(date: day(0),   weightKg: 4.3),
        ]
        let window = FeedingAdequacy.window(for: measurements)
        // Nothing here sits inside the velocity floor, so the newest measurable
        // pair is the last two. The older weighing is history; the assessment
        // covers the latest gap.
        XCTAssertEqual(Self.calendar.dateComponents([.day],
                                                    from: try XCTUnwrap(window).start,
                                                    to: try XCTUnwrap(window).end).day, 9)
    }

    /// The window follows the pair the GAIN is measured over, not the last two
    /// weighings, once a short tail widens that pair.
    ///
    /// One Growth screen prints three day counts of the same window — this
    /// section's header, the gain card and the breakdown card. Left on the last
    /// two, the header would read "over 1 day" above a card reading "over 8
    /// days", each true of a different pair, and the feed rate underneath would
    /// be counted over a stretch the gain never described.
    func testWindowFollowsTheWidenedGainPairRatherThanTheLastTwoWeighings() throws {
        let measurements = [
            WeightMeasurement(date: day(-8), weightKg: 4.00),
            WeightMeasurement(date: day(-1), weightKg: 4.25),
            WeightMeasurement(date: day(0),  weightKg: 4.26),
        ]
        let window = try XCTUnwrap(FeedingAdequacy.window(for: measurements))
        XCTAssertEqual(window.start, day(-8))
        XCTAssertEqual(window.end, day(0))
    }

    /// The fallback the widening did NOT take away: two weighings closer
    /// together than `WeightVelocity.minimumIntervalDays` still define a window.
    /// There is no gain to report over them, but feeds and nappies over two days
    /// are countable, and withholding the whole section because the gain is
    /// unknown is the same "shows less" defect from the other side. Nothing
    /// contradicts anything here — with no reading, no card prints a rival
    /// interval.
    func testAGapTooShortForAGainStillDefinesAFeedingWindow() throws {
        let measurements = [
            WeightMeasurement(date: day(-2), weightKg: 4.00),
            WeightMeasurement(date: day(0),  weightKg: 4.06),
        ]
        XCTAssertNil(WeightVelocity.pair(in: measurements))
        let window = try XCTUnwrap(FeedingAdequacy.window(for: measurements))
        XCTAssertEqual(window.duration, 2 * 86_400)
    }

    func testWindowIsNilWithFewerThanTwoWeighings() {
        XCTAssertNil(FeedingAdequacy.window(for: [WeightMeasurement(date: day(0), weightKg: 4.0)]))
        XCTAssertNil(FeedingAdequacy.window(for: []))
    }

    /// Two weighings recorded at the same instant leave no interval to count
    /// over; a zero-length window would divide every rate by a floor of one day
    /// and report a made-up figure rather than nothing.
    func testWindowIsNilWhenTheTwoLatestWeighingsShareAnInstant() {
        let sameMoment = day(0)
        XCTAssertNil(FeedingAdequacy.window(for: [
            WeightMeasurement(date: sameMoment, weightKg: 4.0),
            WeightMeasurement(date: sameMoment, weightKg: 4.1),
        ]))
    }

    /// Below a full day there is nothing "per day" can honestly mean: both
    /// counters floor their denominator at one day, so a part-day window would
    /// report a fraction of the real feeding rate and score full coverage off a
    /// single logged day. The boundary is pinned from both sides.
    func testWindowIsNilWhenTheWeighingsAreLessThanADayApart() {
        XCTAssertNil(FeedingAdequacy.window(for: [
            WeightMeasurement(date: hours(-23), weightKg: 4.00),
            WeightMeasurement(date: day(0),     weightKg: 4.05),
        ]))

        let exactlyOneDay = FeedingAdequacy.window(for: [
            WeightMeasurement(date: day(-1), weightKg: 4.00),
            WeightMeasurement(date: day(0),  weightKg: 4.05),
        ])
        XCTAssertEqual(exactlyOneDay?.duration, 86_400)
    }

    // MARK: - Feeding style from the logs

    func testStyleIsBreastWhenAlmostAllFeedsAreBreast() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 == 0 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .breast)
    }

    func testStyleIsFormulaWhenPumpedAndFormulaDominate() {
        // Pumped milk is given by bottle on a formula-like schedule, so it
        // counts with formula for frequency purposes.
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .formula : .pumped) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .formula)
    }

    func testStyleIsMixedWhenNeitherDominates() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .mixed)
    }

    func testStyleOfNothingIsMixed() {
        // With no evidence, take the widest reference rather than guessing.
        XCTAssertEqual(FeedingAdequacy.style(of: []), .mixed)
    }

    /// The dominance threshold decides which reference column a baby is judged
    /// against, so the exact share it turns on is pinned from both sides: a
    /// `>` where `>=` belongs would push a whole class of babies onto the wider
    /// mixed band and still leave the suite green.
    func testStyleTreatsTheDominanceShareAsInclusive() {
        let eightBreast = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 8 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: eightBreast), .breast)

        let sevenBreast = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 7 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: sevenBreast), .mixed)

        let eightBottle = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 8 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: eightBottle), .formula)

        let sevenBottle = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 7 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: sevenBottle), .mixed)
    }

    // MARK: - Rate and coverage

    func testRateIsPerDayOverTheWindow() {
        let window = DateInterval(start: day(-10), end: day(0))
        let dates = (0..<20).map { day(-$0 / 2) }
        XCTAssertEqual(FeedingAdequacy.rate(of: dates, in: window), 2.0, accuracy: 0.01)

        // Feeds from before the window belong to an earlier gap, and one logged
        // ahead of the last weighing belongs to no gap yet. Counting either
        // would put a feeding figure beside a gain measured over other days —
        // the one thing the shared window exists to prevent.
        let withEntriesOutsideTheWindow = dates + [day(-20), day(-11), day(20)]
        XCTAssertEqual(FeedingAdequacy.rate(of: withEntriesOutsideTheWindow, in: window),
                       2.0, accuracy: 0.01)
    }

    func testCoverageFailsWhenMostDaysHaveNoEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        // Ten entries, all on one day: plenty of records, almost no coverage.
        let clustered = Array(repeating: day(-1), count: 10)
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(clustered, in: window))
    }

    func testCoveragePassesWhenMostDaysHaveAnEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        let spread = (0...10).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(spread, in: window))
    }

    /// Coverage is the line between reporting a figure and reporting
    /// `notEnoughData`, so the exact fraction it turns on is pinned from both
    /// sides rather than only sampled well away from it.
    func testCoverageHoldsAtExactlyHalfTheDaysAndFailsJustBelow() {
        let window = DateInterval(start: day(-10), end: day(0))

        let halfTheDays = (0..<5).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(halfTheDays, in: window))

        let oneDayShort = (0..<4).map { day(-$0) }
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(oneDayShort, in: window))
    }

    /// A PART-DAY window counts whole calendar days, like every other day count
    /// in this module.
    ///
    /// 10 d 15 h with five covered days: 5/10 is exactly the half that passes,
    /// while rounding the real duration makes it 5/11 — 0.45 — and the figure
    /// is withheld as "not enough data". Rounding and truncation disagree on
    /// about half of all part-day windows, and part-day windows are the normal
    /// case, because a weighing happens whenever a parent reaches the scales.
    /// This fails on the rounding implementation.
    func testAPartDayWindowIsCountedInWholeCalendarDays() {
        let start = day(-11).addingTimeInterval(9 * 3_600)
        let window = DateInterval(start: start, end: day(0))
        XCTAssertEqual(window.duration / 86_400, 10.625, accuracy: 0.01,
                       "the fixture is only a test if the window really is a part-day one")

        let fiveCoveredDays = (0..<5).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(fiveCoveredDays, in: window),
                      "5/10 passes; rounding the duration to 11 days would withhold the figure")
    }

    /// The same exclusion, on the other counter: a parent who logged diligently
    /// a fortnight ago and barely since has no coverage of THIS gap.
    func testCoverageIgnoresDaysLoggedOutsideTheWindow() {
        let window = DateInterval(start: day(-10), end: day(0))
        let oneDayInsideAndSixBefore = [day(-1)] + (11...16).map { day(-$0) }
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(oneDayInsideAndSixBefore, in: window))
    }

    /// The pairing every caller depends on: an empty log rates as zero, and that
    /// zero is only ever safe to show because coverage refuses it first. An
    /// unlogged window is unknown, never "no feeds".
    func testAnEmptyLogRatesAsZeroAndHasNoCoverage() {
        let window = DateInterval(start: day(-10), end: day(0))
        XCTAssertEqual(FeedingAdequacy.rate(of: [], in: window), 0)
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage([], in: window))
    }

    // MARK: - Assembly

    private func measurements(gainGramsPerDay: Double, days: Int) -> [WeightMeasurement] {
        let start = 4.0
        return [
            WeightMeasurement(date: day(-days), weightKg: start),
            WeightMeasurement(date: day(0), weightKg: start + gainGramsPerDay * Double(days) / 1000),
        ]
    }

    private func feeds(perDay: Int, days: Int, type: FeedingEntry.FeedingType = .breast) -> [FeedingAdequacy.Feed] {
        (0..<days).flatMap { d in
            (0..<perDay).map { _ in FeedingAdequacy.Feed(date: day(-d), type: type) }
        }
    }

    private func nappies(perDay: Int, days: Int) -> [Date] {
        (0..<days).flatMap { d in (0..<perDay).map { _ in day(-d) } }
    }

    /// A birth date this many days before `now` **in the device calendar**.
    ///
    /// Deliberately not `day(-ageDays)`: `assess` measures age with
    /// `Calendar.current`, so a UTC-built fixture disagrees with it by a day on
    /// any host whose offset changes across the window — Australia/Sydney
    /// leaving DST on 2026-04-05 turns a 184-day-old into a 183-day-old and
    /// waves them past the six-month guard. The entries either side keep using
    /// `day(_:)`, whose UTC spacing is what fixes the window's duration.
    private func birthDate(ageDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -ageDays, to: now)!
    }

    private func assess(gain: Double, feedsPerDay: Int, nappiesPerDay: Int,
                        days: Int = 9, ageDays: Int = 40,
                        feedType: FeedingEntry.FeedingType = .breast) -> FeedingAdequacy.Assessment? {
        let birth = birthDate(ageDays: ageDays)
        return FeedingAdequacy.assess(
            birthDate: birth,
            correctedBirthDate: birth,
            isMale: true,
            measurements: measurements(gainGramsPerDay: gain, days: days),
            feeds: feeds(perDay: feedsPerDay, days: days, type: feedType),
            wetNappies: nappies(perDay: nappiesPerDay, days: days),
            now: now
        )
    }

    /// THE medical rule of this feature.
    func testGainWithinReferenceNeverWarrantsABreakdownHoweverPoorTheOtherSignals() throws {
        // Healthy gain, almost no feeds logged, almost no nappies: the baby is
        // getting enough, and the app must say nothing.
        let assessment = try XCTUnwrap(assess(gain: 30, feedsPerDay: 2, nappiesPerDay: 1))
        XCTAssertEqual(assessment.gain, .within)
        XCTAssertEqual(assessment.feeding, .below)
        XCTAssertEqual(assessment.nappies, .below)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }

    /// Gaining faster than the reference is not a problem either, and the band
    /// above must map onto the same calm verdict as the band within — a
    /// `case .within` that forgot `.above` would fall through to the trigger.
    func testGainAboveReferenceReadsAsWithinAndNeverWarrantsABreakdown() throws {
        // Pin the fixture itself: if 60 g/day ever stopped landing above the WHO
        // band for this age, the assertions below would pass on a `.within`
        // reading and prove nothing about the mapping they exist to test.
        let weighings = measurements(gainGramsPerDay: 60, days: 9)
        XCTAssertEqual(WeightVelocity.measure(from: weighings[0], to: weighings[1],
                                              correctedBirthDate: birthDate(ageDays: 40), isMale: true)?.band,
                       .above)

        let assessment = try XCTUnwrap(assess(gain: 60, feedsPerDay: 2, nappiesPerDay: 1))
        XCTAssertEqual(assessment.gain, .within)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }

    func testGainBelowReferenceWarrantsABreakdown() throws {
        let assessment = try XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7))
        XCTAssertEqual(assessment.gain, .below)
        XCTAssertTrue(assessment.warrantsBreakdown)
    }

    func testSignalsReportBelowAgainstTheirReferences() throws {
        let assessment = try XCTUnwrap(assess(gain: 5, feedsPerDay: 3, nappiesPerDay: 2))
        XCTAssertEqual(assessment.feeding, .below)
        XCTAssertEqual(assessment.nappies, .below)
        XCTAssertEqual(try XCTUnwrap(assessment.feedingsPerDay), 3, accuracy: 0.2)
        XCTAssertEqual(try XCTUnwrap(assessment.wetNappiesPerDay), 2, accuracy: 0.2)
    }

    /// The feeding verdict turns on the reference's lower bound, so that bound is
    /// pinned from both sides: a `<=` where `<` belongs would call a baby feeding
    /// exactly at the reference "below" it.
    func testFeedingVerdictTurnsExactlyAtTheReferenceLowerBound() throws {
        // Breast at 40 days corrected: 7...9.
        let atTheBound = try XCTUnwrap(assess(gain: 30, feedsPerDay: 7, nappiesPerDay: 7))
        XCTAssertEqual(atTheBound.feedingReference, 7...9)
        XCTAssertEqual(atTheBound.feeding, .within)

        let oneShort = try XCTUnwrap(assess(gain: 30, feedsPerDay: 6, nappiesPerDay: 7))
        XCTAssertEqual(oneShort.feeding, .below)
    }

    /// The same seam on the nappy counter: at the clinical minimum the baby is
    /// within it, one below it is not.
    func testNappyVerdictTurnsExactlyAtTheClinicalMinimum() throws {
        let atTheMinimum = try XCTUnwrap(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 6))
        XCTAssertEqual(atTheMinimum.wetNappyMinimum, 6)
        XCTAssertEqual(atTheMinimum.nappies, .within)

        let oneShort = try XCTUnwrap(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 5))
        XCTAssertEqual(oneShort.nappies, .below)
    }

    /// The two age clocks are genuinely different, and only a preterm baby can
    /// tell them apart: every other fixture here passes the same date twice, so
    /// swapping the two lookups would be invisible. A baby born ten weeks early
    /// is at postnatal day 40 and corrected age −30 on the same morning, and
    /// each reference must read its own clock.
    func testPretermBabyTakesFeedsFromCorrectedAgeAndNappiesFromPostnatalDays() throws {
        let birth = birthDate(ageDays: 40)
        // Ten weeks early: the due date is still 30 days away.
        let dueDate = Calendar.current.date(byAdding: .day, value: 30, to: now)!
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth,
            correctedBirthDate: dueDate,
            isMale: true,
            measurements: measurements(gainGramsPerDay: 30, days: 9),
            feeds: [],
            wetNappies: nappies(perDay: 7, days: 9),
            now: now
        ))
        // Corrected age −30 is the newborn row, whose mixed union is 6...12.
        // Off the postnatal clock this would be 5...9.
        XCTAssertEqual(assessment.feedingReference, 6...12,
                       "feeds are judged on corrected age — a preterm baby is not a 40-day-old")
        // Postnatal day 40 is long past the first-week ramp; the ramp is about
        // the transition after birth, not maturity. Off the corrected clock
        // this would be 1.
        XCTAssertEqual(assessment.wetNappyMinimum, 6,
                       "nappies are judged on postnatal days — this baby has been out for 40 of them")
    }

    /// The reference column comes from what was actually logged over the window,
    /// not from the profile answer — a bottle-fed baby must not be judged against
    /// the breast table.
    func testFeedingReferenceFollowsTheStyleActuallyLogged() throws {
        let breastFed = try XCTUnwrap(assess(gain: 30, feedsPerDay: 6, nappiesPerDay: 7, feedType: .breast))
        XCTAssertEqual(breastFed.feedingReference, 7...9)
        XCTAssertEqual(breastFed.feeding, .below)

        // Six bottles a day is within the formula table, and the same six feeds
        // must not read as "below" merely because the breast table is stricter.
        let bottleFed = try XCTUnwrap(assess(gain: 30, feedsPerDay: 6, nappiesPerDay: 7, feedType: .formula))
        XCTAssertEqual(bottleFed.feedingReference, 5...7)
        XCTAssertEqual(bottleFed.feeding, .within)
    }

    /// An unlogged signal must never read as zero.
    func testUnloggedSignalsAreNotEnoughDataRatherThanZero() throws {
        let birth = birthDate(ageDays: 40)
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements(gainGramsPerDay: 5, days: 9),
            feeds: [], wetNappies: [], now: now
        ))
        XCTAssertEqual(assessment.feeding, .notEnoughData)
        XCTAssertEqual(assessment.nappies, .notEnoughData)
        XCTAssertNil(assessment.feedingsPerDay)
        XCTAssertNil(assessment.wetNappiesPerDay)
        // The reference goes too: a minimum shown beside no measurement invites
        // the reader to supply the missing number themselves, and they will
        // supply zero.
        XCTAssertNil(assessment.wetNappyMinimum)
    }

    /// The two references are deliberately not symmetric, and this pins the
    /// difference so it cannot drift into an accident: the feeding reference is
    /// an age-band fact and is offered even with nothing logged, while
    /// `wetNappyMinimum` is withheld alongside its missing count.
    func testTheFeedingReferenceIsOfferedEvenWhenNothingWasLogged() throws {
        let birth = birthDate(ageDays: 40)
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements(gainGramsPerDay: 5, days: 9),
            feeds: [], wetNappies: [], now: now
        ))
        // No feeds means no evidence of a style, so the widest band applies.
        XCTAssertEqual(assessment.feedingReference, 5...9)
    }

    /// The mirror of the test above: once the log covers the window, both the
    /// figure and the reference it is judged against are reported.
    func testLoggedSignalsCarryBothTheFigureAndItsReference() throws {
        let assessment = try XCTUnwrap(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 7))
        XCTAssertEqual(try XCTUnwrap(assessment.feedingsPerDay), 8, accuracy: 0.01)
        XCTAssertEqual(assessment.feedingReference, 7...9)
        XCTAssertEqual(try XCTUnwrap(assessment.wetNappiesPerDay), 7, accuracy: 0.01)
        XCTAssertEqual(assessment.wetNappyMinimum, 6)
    }

    /// The window the parent is told about is the gap between the two weighings,
    /// so a "6 a day over 9 days" line cannot quote a stretch nothing was counted
    /// over.
    ///
    /// Whole-day gaps only: they cannot tell truncation from rounding, which is
    /// what the two tests below are for.
    func testWindowDaysReportsTheGapBetweenTheTwoWeighings() throws {
        XCTAssertEqual(try XCTUnwrap(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 7)).windowDays, 9)
        XCTAssertEqual(try XCTUnwrap(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 7, days: 2)).windowDays, 2)
    }

    /// A part-day gap counts as the whole days it contains, and this is the case
    /// that tells that apart from rounding to nearest.
    ///
    /// Rounding was individually defensible, but one pair of weighings is
    /// described three times down a single Growth screen — `WeightGainCard`,
    /// this window label, and `FeedingBreakdownCard` — and the two cards take
    /// their count from `WeightVelocity.intervalDays`. A render of the three
    /// stacked showed "9 days", "10 days", "9 days" for one pair. So the label
    /// understates by a matter of hours rather than disagreeing with its
    /// neighbours.
    ///
    /// **The equality assertion below is true by construction, not by
    /// coverage.** `windowDays` and `intervalDays` are now the same
    /// `Calendar.current.dateComponents([.day], from:to:)` call over the same
    /// two dates, so no fixture built in this file can separate them — and this
    /// file's dates are built in a pinned UTC calendar besides, which is a
    /// second reason it cannot. It is kept as a statement of the invariant a
    /// reader of either function should not break.
    /// `testWindowDaysSurvivesADaylightSavingTransition` is the test that can
    /// actually fail when it is broken.
    func testWindowDaysTruncatesSoTheLabelAgreesWithTheCardsAroundIt() throws {
        let birth = birthDate(ageDays: 40)
        // 9 days 14 hours: rounds to 10, truncates to 9.
        let measurements = [
            WeightMeasurement(date: hours(-230), weightKg: 4.0),
            WeightMeasurement(date: now, weightKg: 4.3),
        ]
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements, feeds: [], wetNappies: [], now: now
        ))
        XCTAssertEqual(assessment.windowDays, 9, "9.58 days is 9 whole days, not 10")

        let reading = try XCTUnwrap(WeightVelocity.latest(measurements: measurements,
                                                          correctedBirthDate: birth,
                                                          isMale: true))
        XCTAssertEqual(assessment.windowDays, reading.intervalDays,
                       "the section header and the cards either side of it name one period")
    }

    /// The same one-period promise, through the case that can actually break
    /// it now: a short tail moves the gain onto an older pair, and the header
    /// has to move with it.
    ///
    /// On the last-two rule this fails three ways at once — `windowDays` reads
    /// 1 against the card's 8, the gain reads `notEnoughData` while the card
    /// shows a band, and the feed rate is 16 a day because two days of feeds
    /// were divided by a one-day window.
    func testWindowDaysAndTheGainFollowTheSameWidenedPair() throws {
        let birth = birthDate(ageDays: 40)
        let measurements = [
            WeightMeasurement(date: day(-8), weightKg: 4.00),
            WeightMeasurement(date: day(-1), weightKg: 4.25),
            WeightMeasurement(date: day(0),  weightKg: 4.26),
        ]
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements,
            feeds: feeds(perDay: 8, days: 8),
            wetNappies: nappies(perDay: 7, days: 8),
            now: now
        ))
        let reading = try XCTUnwrap(WeightVelocity.latest(measurements: measurements,
                                                          correctedBirthDate: birth,
                                                          isMale: true))
        XCTAssertEqual(reading.intervalDays, 8)
        XCTAssertEqual(assessment.windowDays, reading.intervalDays,
                       "the header names the period the gain card names")
        XCTAssertNotEqual(assessment.gain, .notEnoughData)
        XCTAssertEqual(try XCTUnwrap(assessment.feedingsPerDay), 8, accuracy: 0.01,
                       "feeds are counted over the same widened window")
    }

    /// The one case where a real-seconds day count and a calendar day count
    /// disagree — and the whole reason `windowDays` is computed the second way.
    ///
    /// Both `FeedingAdequacy.assess` and `WeightVelocity` read
    /// `Calendar.current`, so a DST fixture can only reach them by moving the
    /// process's default time zone; the pinned UTC calendar the rest of this
    /// file uses is by definition unable to express this case. Restored in a
    /// teardown block, because other suites in this process assert on
    /// calendar-derived output.
    ///
    /// Against the previous implementation — `Int(window.duration / 86_400)` —
    /// this fails with 8 instead of 9, which is the parent seeing "Over 8 days"
    /// as a header directly above "119 g/week over 9 days".
    func testWindowDaysSurvivesADaylightSavingTransition() throws {
        let originalZone = NSTimeZone.default
        addTeardownBlock { NSTimeZone.default = originalZone }
        let london = TimeZone(identifier: "Europe/London")!
        NSTimeZone.default = london

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = london
        // The UK springs forward on 2026-03-29, so noon on the 22nd to noon on
        // the 31st is nine calendar days but only 8 d 23 h of elapsed time.
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 12))!
        let end   = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31, hour: 12))!
        XCTAssertEqual(end.timeIntervalSince(start), 9 * 86_400 - 3_600,
                       "this fixture only tests anything while it is an hour short of nine days")

        let birth = calendar.date(byAdding: .day, value: -40, to: end)!
        let measurements = [
            WeightMeasurement(date: start, weightKg: 4.0),
            WeightMeasurement(date: end,   weightKg: 4.3),
        ]
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements, feeds: [], wetNappies: [], now: end
        ))
        let reading = try XCTUnwrap(WeightVelocity.latest(measurements: measurements,
                                                          correctedBirthDate: birth,
                                                          isMale: true))

        XCTAssertEqual(assessment.windowDays, 9,
                       "nine calendar days, even though only 8 d 23 h elapsed")
        XCTAssertEqual(assessment.windowDays, reading.intervalDays,
                       "the header and the cards either side of it name one period, DST or not")
    }

    /// The truncation is a LABEL change and must stay one: the per-day figures
    /// divide by the window's real duration, not by the whole days it is called.
    ///
    /// 230 nappies over 9.583 days is exactly 24 a day. Dividing by the label
    /// instead would give 25.6, and dividing by the old rounded 10 would give
    /// 23 — either would move a number the parent reads.
    func testPerDayRatesStillDivideByTheRealDurationNotTheWholeDayLabel() throws {
        let birth = birthDate(ageDays: 40)
        let measurements = [
            WeightMeasurement(date: hours(-230), weightKg: 4.0),
            WeightMeasurement(date: now, weightKg: 4.3),
        ]
        // One an hour across the whole window: 230 entries, ten distinct days,
        // so the coverage gate is comfortably satisfied.
        let wetNappies = (0...229).map { hours(-$0) }
        let assessment = try XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements, feeds: [], wetNappies: wetNappies, now: now
        ))
        XCTAssertEqual(assessment.windowDays, 9)
        XCTAssertEqual(try XCTUnwrap(assessment.wetNappiesPerDay), 24, accuracy: 0.01,
                       "230 entries over 9.583 real days is 24 a day, whatever the label says")
    }

    func testAssessmentIsNilPastSixMonths() {
        XCTAssertNil(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7, ageDays: 200))
    }

    /// The feature covers the whole of 0–6 months and stops the day after, and
    /// the guard is pinned from both sides so an off-by-one cannot quietly cut a
    /// day off the end.
    func testAssessmentCoversTheLastDayOfSixMonthsAndStopsTheDayAfter() {
        XCTAssertNotNil(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 7, ageDays: 183))
        XCTAssertNil(assess(gain: 30, feedsPerDay: 8, nappiesPerDay: 7, ageDays: 184))
    }

    func testAssessmentIsNilWithoutTwoWeighings() {
        let birth = birthDate(ageDays: 40)
        XCTAssertNil(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: [WeightMeasurement(date: day(0), weightKg: 4.0)],
            feeds: [], wetNappies: [], now: now
        ))
    }

    /// A weighing gap under 3 days is noise, and WeightVelocity already refuses
    /// it. The assessment must degrade to notEnoughData, not to a false calm.
    func testShortWeighingGapLeavesGainUnknownAndCannotTrigger() throws {
        let assessment = try XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7, days: 2))
        XCTAssertEqual(assessment.gain, .notEnoughData)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }

    /// The other side of that floor: at three days the gain is measurable again
    /// and a poor one does trigger. Without this, refusing every gap would look
    /// just as green.
    func testAThreeDayWeighingGapIsTheShortestThatCanTrigger() throws {
        let assessment = try XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7, days: 3))
        XCTAssertEqual(assessment.gain, .below)
        XCTAssertTrue(assessment.warrantsBreakdown)
    }

    /// The Diapers screen's editable target must not be able to change a
    /// clinical verdict — this asserts the assessment ignores it entirely.
    func testNappyVerdictIgnoresTheUserEditableDailyTarget() throws {
        UserDefaults.standard.set(2, forKey: "diaperDailyNorm")
        defer { UserDefaults.standard.removeObject(forKey: "diaperDailyNorm") }
        let assessment = try XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 3))
        XCTAssertEqual(assessment.nappies, .below, "3 a day is below the clinical 6, whatever the user set")
    }
}

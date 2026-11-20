import XCTest
@testable import BabyBloom

/// The offer rule decides when Home asks a parent for money, so each moment,
/// gap and hold is pinned here with its edge. The calendar is Lisbon's: the
/// clocks go forward on 29 March 2026 (day 27 below), inside the month-report
/// window.
final class OfferRuleTests: XCTestCase {

    typealias Rule = OfferRule

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Lisbon")!
        return calendar
    }()

    /// Onboarding ended on day 0 at 09:00.
    private var ended: Date { at(0, 9) }

    private func at(_ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let date = calendar.date(byAdding: .day, value: day, to: start)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }

    private func record(_ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Rule.Record {
        Rule.Record(date: at(day, hour, minute), createdAt: at(day, hour, minute))
    }

    private func weighing(_ day: Int, flagged: Bool = false) -> Rule.Weighing {
        Rule.Weighing(date: at(day, 12), createdAt: at(day, 12), flagged: flagged)
    }

    private func facts(days: [Int], weighings: [Rule.Weighing] = [], clinical: Bool = false) -> Rule.Facts {
        Rule.Facts(onboardingEndedAt: ended, records: days.map { record($0) },
                   weighings: weighings, clinicalBlocked: clinical)
    }

    private let free = Rule.Account(isPremium: false, entitlementsResolved: true, cohort: .new)

    /// Offers shown on the given days and then tapped (or closed).
    private func ledger(_ offers: [(OfferContent, Int)], closed: Bool = false) -> OfferLedger {
        var ledger = OfferLedger.empty
        for (content, day) in offers {
            ledger.recordShown(content, now: at(day, 12))
            if closed { ledger.recordClosed(content, now: at(day, 12)) } else { ledger.recordTapped(content, now: at(day, 12)) }
        }
        return ledger
    }

    private func decide(_ facts: Rule.Facts,
                        ledger: OfferLedger = .empty,
                        account: Rule.Account? = nil,
                        situation: Rule.Situation = .calm,
                        at now: Date,
                        forced: OfferContent? = nil) -> Rule.Decision {
        Rule.decide(facts: facts, ledger: ledger, account: account ?? free, situation: situation,
                    now: now, calendar: calendar, forced: forced)
    }

    private func show(_ content: OfferContent) -> Rule.Decision { .show(content, continuing: false) }

    // MARK: - Numbers

    func testConstantsAreThePlansNumbers() {
        XCTAssertEqual(Rule.firstResultDays, 3)
        XCTAssertEqual(Rule.firstWeekDays, 7)
        XCTAssertEqual(Rule.monthReportDays, 28)
        XCTAssertEqual(Rule.recentRecordDays, 7)
        XCTAssertEqual(Rule.earlyPeriodDays, 30)
        XCTAssertEqual(Rule.earlyGapDays, 7)
        XCTAssertEqual(Rule.gapDays, 30)
        XCTAssertEqual(Rule.formerSubscriberGapDays, 30)
        XCTAssertEqual(Rule.slowPaceCloses, 3)
        XCTAssertEqual(Rule.slowGapDays, 90)
        XCTAssertEqual(Rule.cohortQuietDays, 14)
        XCTAssertEqual(Rule.stayDays, 3)
    }

    // MARK: - Moments, each alone

    func testNothingIsDueWithoutRecordsOrWithoutABaby() {
        XCTAssertEqual(decide(facts(days: []), at: at(5)), .wait(.notDue))
        let noBaby = Rule.Facts(onboardingEndedAt: nil, records: [record(0), record(1), record(2)])
        XCTAssertEqual(decide(noBaby, at: at(3)), .wait(.notDue))
    }

    func testFirstResultOnTheThirdDistinctDay() {
        XCTAssertEqual(decide(facts(days: [0, 0, 1]), at: at(1, 18)), .wait(.notDue))
        XCTAssertEqual(decide(facts(days: [0, 1, 2]), at: at(2, 18)), show(.firstResultDays))
    }

    func testARecordDatedBeforeOnboardingEndedDoesNotCount() {
        var early = facts(days: [1, 2])
        early.records.append(record(0, 8))     // during setup, before 09:00
        XCTAssertEqual(decide(early, at: at(2, 18)), .wait(.notDue))
        early.records.append(record(0, 11))
        XCTAssertEqual(decide(early, at: at(2, 18)), show(.firstResultDays))
    }

    func testDaysAreCalendarDaysNotSpansOfHours() {
        let night = Rule.Facts(onboardingEndedAt: ended,
                               records: [record(0, 23, 50), record(1, 0, 10), record(2, 0, 5)])
        // Three calendar days inside 25 hours.
        XCTAssertEqual(decide(night, at: at(2, 1)), show(.firstResultDays))
    }

    func testTheFirstWeighingAddedInTheAppShowsThePoint() {
        XCTAssertEqual(decide(facts(days: [], weighings: [weighing(1)]), at: at(1, 18)), show(.firstResultPoint))
    }

    func testTheBirthWeightOnboardingWroteIsNotAWeighingAddedInTheApp() {
        let birth = Rule.Weighing(date: at(-10, 0), createdAt: ended.addingTimeInterval(-30), flagged: false)
        XCTAssertEqual(decide(facts(days: [], weighings: [birth]), at: at(1, 18)), .wait(.notDue))
    }

    func testFirstResultContentIsWhicheverCameFirst() {
        // The third day starts at 10:00 on day 2.
        XCTAssertEqual(decide(facts(days: [0, 1, 2], weighings: [weighing(2)]), at: at(2, 18)),
                       show(.firstResultDays))
        XCTAssertEqual(decide(facts(days: [0, 1, 2], weighings: [weighing(1)]), at: at(2, 18)),
                       show(.firstResultPoint))
    }

    func testFirstWeekOnTheSeventhDistinctDay() {
        let shown = ledger([(.firstResultDays, 2)])
        XCTAssertEqual(decide(facts(days: Array(0...5)), ledger: shown, at: at(9, 18)), .wait(.notDue))
        XCTAssertEqual(decide(facts(days: Array(0...6)), ledger: shown, at: at(9, 18)), show(.firstWeek))
    }

    func testHistoryEdgeWhenTheOldestRecordLeavesTheFreeWindow() {
        // Seeds `offerOldest14` and `offerOldest16`.
        XCTAssertEqual(decide(facts(days: [0]), at: at(14, 18)), .wait(.notDue))
        XCTAssertEqual(decide(facts(days: [0]), at: at(16, 18)), show(.historyEdge))
        // The edge itself: the free history keeps 15 days counting today.
        XCTAssertEqual(decide(facts(days: [0]), at: at(14, 23, 59)), .wait(.notDue))
        XCTAssertEqual(decide(facts(days: [0]), at: at(15, 0, 1)), show(.historyEdge))
    }

    func testAWeighingIsNotARecordDay() {
        // Six record days and a weighing on the seventh: no first week.
        XCTAssertEqual(Rule.dueMoments(facts: facts(days: Array(0...5), weighings: [weighing(6)]),
                                       ended: ended, now: at(6, 18), calendar: calendar),
                       [.firstResultDays])
        // A weighing alone in the last week is not a recent record for the report.
        XCTAssertEqual(Rule.dueMoments(facts: facts(days: [0], weighings: [weighing(25)]),
                                       ended: ended, now: at(28, 18), calendar: calendar),
                       [.firstResultPoint, .historyEdge])
    }

    func testMonthReportAfter28DaysWithARecentRecord() {
        let shown = ledger([(.historyEdge, 15)])
        // Seeds `offerOnboarded27` and `offerOnboarded28`; day 27 is the DST day.
        XCTAssertEqual(decide(facts(days: [0, 25]), ledger: shown, at: at(27, 18)), .wait(.notDue))
        XCTAssertEqual(decide(facts(days: [0, 25]), ledger: shown, at: at(28, 18)), show(.monthReport))
        // The last record 7 days back is not recent: no use, nothing to report.
        XCTAssertEqual(decide(facts(days: [0, 21]), ledger: shown, at: at(28, 18)), .wait(.notDue))
    }

    func testOpenedLaterThanTheTriggerTheMomentStillShows() {
        XCTAssertEqual(decide(facts(days: [0, 1, 2]), at: at(20, 18)), show(.firstResultDays))
    }

    // MARK: - Two due together

    func testTwoDueTogetherTheEarlierShowsAndTheOtherWaitsItsGap() {
        let week = facts(days: Array(0...6))
        XCTAssertEqual(decide(week, at: at(6, 18)), show(.firstResultDays))
        let shown = ledger([(.firstResultDays, 6)])
        XCTAssertEqual(decide(week, ledger: shown, at: at(12, 18)), .wait(.gap))
        XCTAssertEqual(decide(week, ledger: shown, at: at(13, 18)), show(.firstWeek))
    }

    // MARK: - Gaps

    func testTheGapIsSevenDaysInTheFirstThirtyDays() {
        let shown = ledger([(.firstResultDays, 3)])
        XCTAssertEqual(decide(facts(days: Array(0...6)), ledger: shown, at: at(9, 18)), .wait(.gap))
        XCTAssertEqual(decide(facts(days: Array(0...6)), ledger: shown, at: at(10, 8)), show(.firstWeek))
    }

    func testTheGapIsThirtyDaysAfterwards() {
        let shown = ledger([(.firstResultDays, 2), (.firstWeek, 9), (.historyEdge, 40)])
        // Records run to day 80; the ones after `now` are ignored.
        let data = facts(days: Array(0...6) + Array(60...80))
        XCTAssertEqual(decide(data, ledger: shown, at: at(69, 18)), .wait(.gap))
        XCTAssertEqual(decide(data, ledger: shown, at: at(70, 8)), show(.monthReport))
    }

    // MARK: - Holds

    func testEachHoldHoldsAndSpendsNothing() {
        let base = facts(days: [0, 1, 2])
        let now = at(2, 18)
        XCTAssertEqual(decide(base, at: now), show(.firstResultDays))

        var cases: [(Rule.Hold, Rule.Decision)] = []
        cases.append((.unresolved, decide(base, account: .init(isPremium: false, entitlementsResolved: false, cohort: .new), at: now)))
        cases.append((.premium, decide(base, account: .init(isPremium: true, entitlementsResolved: true, cohort: .new), at: now)))
        cases.append((.cohortQuiet, decide(base, account: .init(isPremium: false, entitlementsResolved: true, cohort: .beforeOffers(launchAt: at(0, 12))), at: now)))
        cases.append((.clinical, decide(facts(days: [0, 1, 2], clinical: true), at: now)))
        cases.append((.flaggedWeighingDay, decide(facts(days: [0, 1, 2], weighings: [weighing(2, flagged: true)]), at: now)))
        cases.append((.medicationDue, decide(base, situation: .init(medicationDue: true), at: now)))
        cases.append((.notificationLaunch, decide(base, situation: .init(launchedFromNotification: true), at: now)))
        cases.append((.sheetOpen, decide(base, situation: .init(sheetOpen: true), at: now)))
        cases.append((.weeklyCardNew, decide(base, situation: .init(weeklyCardNew: true), at: now)))

        XCTAssertEqual(Set(cases.map(\.0)), Set(Rule.Hold.allCases), "every hold has a case")
        for (hold, decision) in cases {
            XCTAssertEqual(decision, .hold(hold), "\(hold)")
        }
        // The ledger is untouched by a hold, so the moment shows once it lifts.
        XCTAssertEqual(decide(base, at: now), show(.firstResultDays))
        XCTAssertEqual(decide(facts(days: [0, 1, 2], weighings: [weighing(2, flagged: true)]), at: at(3, 9)),
                       show(.firstResultDays), "the flagged weighing holds its own day only")
    }

    func testHoldsAreCheckedInOrder() {
        let both = Rule.Account(isPremium: true, entitlementsResolved: false, cohort: .new)
        XCTAssertEqual(decide(facts(days: [0, 1, 2]), account: both, at: at(2, 18)), .hold(.unresolved))
        let premium = Rule.Account(isPremium: true, entitlementsResolved: true, cohort: .new)
        XCTAssertEqual(decide(facts(days: [0, 1, 2], clinical: true), account: premium, at: at(2, 18)), .hold(.premium))
    }

    // MARK: - The three days on Home

    func testTheCardStaysThreeDaysThenCountsAsClosed() {
        var open = OfferLedger.empty
        open.recordShown(.firstResultDays, now: at(2, 12))
        let data = facts(days: [0, 1, 2])

        XCTAssertEqual(decide(data, ledger: open, at: at(3, 9)), .show(.firstResultDays, continuing: true))
        XCTAssertEqual(decide(data, ledger: open, situation: .init(sheetOpen: true), at: at(3, 9)), .hold(.sheetOpen))
        XCTAssertNil(open.settle(now: at(4, 23, 59), calendar: calendar))
        XCTAssertEqual(decide(data, ledger: open, at: at(4, 23, 59)), .show(.firstResultDays, continuing: true))

        XCTAssertEqual(open.settle(now: at(5, 0, 1), calendar: calendar), .firstResultDays)
        XCTAssertEqual(open.closesInRow, 1)
        XCTAssertNil(open.open)
        XCTAssertEqual(decide(data, ledger: open, at: at(5, 0, 1)), .wait(.notDue))
    }

    // MARK: - Slow pace

    func testThreeClosesInARowSlowThePaceToNinetyDays() {
        let closed = ledger([(.firstResultDays, 2), (.firstWeek, 9), (.historyEdge, 16)], closed: true)
        XCTAssertEqual(closed.closesInRow, 3)
        let data = facts(days: Array(0...6) + Array(20...140))
        XCTAssertEqual(decide(data, ledger: closed, at: at(50, 18)), .wait(.slowPace))
        XCTAssertEqual(decide(data, ledger: closed, at: at(105, 18)), .wait(.slowPace))
        XCTAssertEqual(decide(data, ledger: closed, at: at(106, 8)), show(.monthReport))
    }

    func testATapEndsTheStreak() {
        var mixed = ledger([(.firstResultDays, 2), (.firstWeek, 9)], closed: true)
        mixed.recordShown(.historyEdge, now: at(16, 12))
        mixed.recordTapped(.historyEdge, now: at(16, 12))
        XCTAssertEqual(mixed.closesInRow, 0)
        XCTAssertEqual(decide(facts(days: Array(0...6) + Array(20...140)), ledger: mixed, at: at(50, 18)),
                       show(.monthReport))
    }

    // MARK: - Subscribers

    func testASubscriberNeverSeesAnOffer() {
        let premium = Rule.Account(isPremium: true, entitlementsResolved: true, cohort: .new)
        XCTAssertEqual(decide(facts(days: [0, 1, 2]), account: premium, at: at(2, 18)), .hold(.premium))
        XCTAssertEqual(decide(facts(days: []), account: premium, at: at(2, 18), forced: .firstWeek), .hold(.premium))
    }

    func testAFormerSubscriberReentersAtTheThirtyDayPace() {
        var former = OfferLedger.empty
        former.notePremium(now: at(40, 12), calendar: calendar)
        let data = facts(days: [0])
        XCTAssertEqual(decide(data, ledger: former, at: at(60, 18)), .wait(.gap))
        XCTAssertEqual(decide(data, ledger: former, at: at(70, 8)), show(.historyEdge))

        // An offer after the subscription ended counts from that offer instead.
        former.recordShown(.firstResultDays, now: at(50, 12))
        former.recordTapped(.firstResultDays, now: at(50, 12))
        XCTAssertEqual(decide(data, ledger: former, at: at(79, 18)), .wait(.gap))
        XCTAssertEqual(decide(data, ledger: former, at: at(80, 8)), show(.historyEdge))
    }

    // MARK: - Installs before 1.4.0

    private var launch: Date { at(100, 8) }
    private var older: Rule.Account { Rule.Account(isPremium: false, entitlementsResolved: true, cohort: .beforeOffers(launchAt: launch)) }

    func testAnOlderInstallSeesNoOfferForFourteenDays() {
        var spent = OfferLedger.empty
        spent.spendAtCohortLaunch([], launchAt: launch, now: launch)
        let data = facts(days: [90, 91, 92, 93, 94, 95, 96, 97, 98, 99])
        XCTAssertEqual(decide(data, ledger: spent, account: older, at: at(113, 23, 59)), .hold(.cohortQuiet))
        XCTAssertNotEqual(decide(data, ledger: spent, account: older, at: at(114, 0, 1)), .hold(.cohortQuiet))
    }

    func testMomentsAlreadyTrueAtThatLaunchAreSpentUnshown() {
        let data = facts(days: Array(0...20) + Array(95...98))
        let spentMoments = Rule.spentAtCohortLaunch(facts: data, launchAt: launch, calendar: calendar)
        XCTAssertEqual(spentMoments, Set(OfferMoment.allCases))

        var ledger = OfferLedger.empty
        ledger.spendAtCohortLaunch(spentMoments, launchAt: launch, now: launch)
        XCTAssertTrue(ledger.allMomentsUsed)
        XCTAssertNil(ledger.lastShownAt, "spent, not shown")

        // After the quiet days: no new data, no offer.
        XCTAssertEqual(decide(data, ledger: ledger, account: older, at: at(114, 18)), .wait(.notDue))
        // A clean weighing added since that launch: the recurring growth point.
        var weighed = data
        weighed.weighings = [weighing(110)]
        XCTAssertEqual(decide(weighed, ledger: ledger, account: older, at: at(114, 18)), show(.growthPoint))
        // A flagged one is no reason to sell.
        weighed.weighings = [weighing(110, flagged: true)]
        XCTAssertEqual(decide(weighed, ledger: ledger, account: older, at: at(114, 18)), .wait(.notDue))
        // 28 days after the spent month report, with recent records: another one.
        let later = facts(days: Array(0...20) + Array(95...127))
        XCTAssertEqual(decide(later, ledger: ledger, account: older, at: at(127, 18)), .wait(.notDue))
        XCTAssertEqual(decide(later, ledger: ledger, account: older, at: at(128, 8)), show(.monthReport))
    }

    func testAMomentThatBecomesTrueLaterStillShows() {
        let data = facts(days: Array(90...100))
        let spentMoments = Rule.spentAtCohortLaunch(facts: data, launchAt: at(100, 23), calendar: calendar)
        XCTAssertEqual(spentMoments, [.firstResult, .firstWeek, .monthReport])

        var ledger = OfferLedger.empty
        ledger.spendAtCohortLaunch(spentMoments, launchAt: launch, now: launch)
        XCTAssertEqual(decide(data, ledger: ledger, account: older, at: at(114, 18)), show(.historyEdge))
    }

    func testTheSpendReadsTheFactsAsTheyStoodAtThatLaunch() {
        var data = facts(days: Array(95...99))
        // Added after the launch, dated long before it.
        data.records.append(Rule.Record(date: at(0), createdAt: at(101)))
        let spentMoments = Rule.spentAtCohortLaunch(facts: data, launchAt: launch, calendar: calendar)
        XCTAssertFalse(spentMoments.contains(.historyEdge))
        XCTAssertTrue(spentMoments.contains(.firstResult))
    }

    // MARK: - Lever

    func testTheForcedContentSkipsMomentsAndPaceButNotHolds() {
        XCTAssertEqual(decide(facts(days: []), at: at(1), forced: .monthReport), show(.monthReport))
        let recent = ledger([(.firstResultDays, 1)])
        XCTAssertEqual(decide(facts(days: []), ledger: recent, at: at(1), forced: .growthPoint), show(.growthPoint))
        XCTAssertEqual(decide(facts(days: []), situation: .init(sheetOpen: true), at: at(1), forced: .monthReport),
                       .hold(.sheetOpen))
    }
}

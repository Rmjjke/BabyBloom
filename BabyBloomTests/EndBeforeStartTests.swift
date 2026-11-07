import XCTest
import SwiftData
@testable import BabyBloom

/// A sleep or a feed stored with its end before its start. Earlier versions of
/// Add Sleep saved one when Start was moved past End, and a timer stopped on a
/// phone whose clock runs behind still can. Such a row reads 0 min on every
/// surface and is never rewritten.
@MainActor
final class EndBeforeStartTests: XCTestCase {

    private let calendar = WeeklySummary.calendar

    /// 2026, local time: the weekly card's weeks are the parent's midnights.
    private func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Wednesday 28 Oct: last week is Mon 19 – Sun 25 Oct.
    private var now: Date { date(10, 28, 12) }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        return (container, ModelContext(container))
    }

    /// The row the form saved: Start moved to 14:00 past an End of 13:01, the
    /// History row QA read as «-59 min».
    private func backwardsSleep() -> SleepEntry {
        let sleep = SleepEntry(startTime: date(10, 21, 14), type: .nap)
        sleep.endTime = date(10, 21, 13, 1)
        return sleep
    }

    /// A 10-hour night, Thursday to Friday.
    private func night() -> SleepEntry {
        let sleep = SleepEntry(startTime: date(10, 22, 20), type: .night)
        sleep.endTime = date(10, 23, 6)
        return sleep
    }

    // MARK: The form's save rule

    /// Past times only: End set to 12:30, then Start moved to 14:00.
    func testAnEndBeforeTheStartIsSavedAsTheStart() {
        let entry = SleepEntry.manual(start: date(10, 21, 14), end: date(10, 21, 12, 30),
                                      type: .nap, location: .crib)
        XCTAssertEqual(entry.endTime, date(10, 21, 14))
        XCTAssertEqual(entry.duration, 0)
        XCTAssertEqual(entry.type, .nap)
        XCTAssertEqual(entry.location, .crib)
    }

    func testAnEndAfterTheStartIsSavedAsSet() {
        let entry = SleepEntry.manual(start: date(10, 21, 12), end: date(10, 21, 13, 30),
                                      type: .night, location: nil)
        XCTAssertEqual(entry.endTime, date(10, 21, 13, 30))
        XCTAssertEqual(entry.duration, 90 * 60)
    }

    // MARK: The models: Today, History, the Sleep chart, the export, the widget

    func testAStoredSleepEndingBeforeItsStartLastsZero() {
        let sleep = backwardsSleep()
        XCTAssertEqual(sleep.duration, 0)
        XCTAssertEqual(sleep.durationFormatted, String(format: "duration.min_only".l, 0).gluingNumbersToUnits)
        XCTAssertEqual(sleep.endTime, date(10, 21, 13, 1), "reading never rewrites the row")
        XCTAssertEqual(night().duration, 10 * 3600)
    }

    func testAStoredFeedEndingBeforeItsStartLastsZero() {
        let feed = FeedingEntry(startTime: date(10, 21, 9), type: .breast)
        // 90 s back, not a whole minute: unguarded, the text reads "-30 sec",
        // where -120 s would print "0 sec" by itself.
        feed.endTime = date(10, 21, 8, 59).addingTimeInterval(-30)
        XCTAssertEqual(feed.duration, 0)
        XCTAssertEqual(feed.durationFormatted, String(format: "duration.sec".l, 0))
    }

    // MARK: The weekly card, from the store

    func testTheWeeklyCardReadsTheRowAsZero() throws {
        let (container, context) = try makeContext()
        context.insert(Baby(name: "Mia", birthDate: date(6, 1, 12), gender: .female, feedingType: .breast))
        context.insert(backwardsSleep())
        context.insert(night())
        try context.save()

        let input = try XCTUnwrap(WeeklySummary.Input.load(in: context, now: now))
        let week = try XCTUnwrap(WeeklySummary.make(now: now, input: input)).current

        XCTAssertEqual(week.sleepByDay[2], 0, "Wednesday: the row reads 0 min")
        XCTAssertEqual(week.sleepByDay[3], 10 * 3600, "Thursday's night is not reduced by it")
        XCTAssertEqual(week.longestSleep, 10 * 3600)
        // Still an entry, as History lists it: 10 h over two days with entries.
        XCTAssertTrue(week.dayHasEntries[2])
        XCTAssertEqual(week.sleepPerDay, 5 * 3600)
        withExtendedLifetime(container) {}
    }

    // MARK: The report (screen and PDF), from the store

    func testTheReportReadsTheRowAsZero() throws {
        let (container, context) = try makeContext()
        let baby = Baby(name: "Mia", birthDate: date(6, 1, 12), gender: .female, feedingType: .breast)
        context.insert(baby)
        context.insert(backwardsSleep())
        context.insert(night())
        let backwardsFeed = FeedingEntry(startTime: date(10, 21, 9), type: .breast)
        backwardsFeed.endTime = date(10, 21, 8, 58)
        let feed = FeedingEntry(startTime: date(10, 22, 9), type: .breast)
        feed.endTime = date(10, 22, 9, 20)
        context.insert(backwardsFeed)
        context.insert(feed)
        try context.save()

        let periodStart = date(10, 19, 0)
        let input = DoctorReportSummary.Input.load(baby: baby, periodStart: periodStart, in: context)
        let report = DoctorReportSummary.make(input: input, periodStart: periodStart, now: now,
                                              startsAtVisit: false, calendar: calendar)

        let sleep = try XCTUnwrap(report.sleep)
        XCTAssertEqual(sleep.total, 10 * 3600)
        XCTAssertEqual(sleep.longest, 10 * 3600)
        let feeding = try XCTUnwrap(report.feeding)
        XCTAssertEqual(feeding.totalFeeds, 2)
        XCTAssertEqual(feeding.breastfeedMedian, 10 * 60, "the median of 0 and 20 min")
        withExtendedLifetime(container) {}
    }
}

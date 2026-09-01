import XCTest
@testable import BabyBloom

/// The interval table is the same one the feeding reminder is scheduled on.
/// These pin it so the widget and the notification can never drift apart —
/// which is the whole reason the arithmetic was pulled out of
/// `NotificationManager` in the first place.
final class FeedingRhythmTests: XCTestCase {

    // MARK: - The age table

    func testAgeTableAtEveryBoundary() {
        let expected: [(months: Int, hours: Double?)] = [
            (0, 2.5), (1, 3.0), (2, 3.0), (3, 3.5), (5, 3.5),
            (6, 4.0), (8, 4.0), (9, 4.5), (11, 4.5),
        ]
        for row in expected {
            XCTAssertEqual(FeedingRhythm.interval(ageMonths: row.months),
                           row.hours.map { $0 * 3600 },
                           "age \(row.months) months")
        }
    }

    /// Not an edge case — a product decision. From a year old the app stops
    /// telling parents when to feed, and anything derived from this must stay
    /// silent too rather than invent a due time.
    func testTwelveMonthsAndOlderHasNoInterval() {
        XCTAssertNil(FeedingRhythm.interval(ageMonths: 12))
        XCTAssertNil(FeedingRhythm.interval(ageMonths: 24))
    }

    // MARK: - The adaptive interval

    func testThreeOrMoreFeedingsUseTheLoggedRhythmPlusGrace() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Three feedings, two 2-hour gaps.
        let times = [base, base.addingTimeInterval(7200), base.addingTimeInterval(14400)]
        // 120 minutes averaged + a 10-minute grace.
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       130 * 60)
    }

    func testFewerThanThreeFeedingsFallBackToTheAgeTable() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = [base, base.addingTimeInterval(7200)]
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       3.0 * 3600)
    }

    /// A gap longer than eight hours is a night, not a rhythm. Letting it into
    /// the average would push the next feed hours out and silence the widget
    /// for the whole morning.
    func testGapsOverEightHoursAreIgnored() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = [base,
                     base.addingTimeInterval(7200),        // +2h
                     base.addingTimeInterval(7200 + 36000)] // +10h — a night
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       130 * 60)
    }

    /// The 12+ month silence must survive the adaptive path too. The method
    /// this replaced checked the feeding count first and never re-checked the
    /// age, so a toddler with three logged feedings still got a reminder.
    func testTwelveMonthsStaysSilentEvenWithALoggedRhythm() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = [base, base.addingTimeInterval(7200), base.addingTimeInterval(14400)]
        XCTAssertNil(FeedingRhythm.interval(ageMonths: 12, recentFeedings: times))
    }

    // MARK: - The date the widget renders

    func testNextFeedIsTheLastFeedingPlusTheInterval() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(FeedingRhythm.nextFeed(afterLastFeedingAt: last,
                                              ageMonths: 1,
                                              recentFeedings: []),
                       last.addingTimeInterval(3.0 * 3600))
    }

    /// Two distinct reasons to predict nothing, and the widget renders a
    /// different thing for each — so both must be reachable.
    func testNoPredictionWithoutAFeeding() {
        XCTAssertNil(FeedingRhythm.nextFeed(afterLastFeedingAt: nil,
                                            ageMonths: 1,
                                            recentFeedings: []))
    }

    func testNoPredictionFromTwelveMonths() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNil(FeedingRhythm.nextFeed(afterLastFeedingAt: last,
                                            ageMonths: 12,
                                            recentFeedings: []))
    }
}

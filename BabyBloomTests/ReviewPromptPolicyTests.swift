import XCTest
@testable import BabyBloom

/// The review prompt spends one of Apple's three prompts a year, so every rule
/// that withholds it is pinned here, each with its edge. The simulator can only
/// show that the system sheet appears; it cannot show that it would NOT have
/// appeared on day two or on a second request in the same version.
final class ReviewPromptPolicyTests: XCTestCase {

    private let now = ReviewPromptTestClock.noon
    private let day: TimeInterval = 86_400

    /// Every threshold met, nothing blocking — each test breaks exactly one thing.
    private func eligible() -> ReviewPromptPolicy.State {
        ReviewPromptPolicy.State(
            totalEntries: 20,
            firstLaunchDate: now.addingTimeInterval(-3 * day),
            now: now,
            lastRequestVersion: nil,
            lastRequestDate: nil,
            currentVersion: "1.1",
            blockers: .none,
            calendar: ReviewPromptTestClock.calendar
        )
    }

    private func eligible(at hour: Int, _ minute: Int = 0) -> ReviewPromptPolicy.State {
        var state = eligible()
        state.now = ReviewPromptTestClock.date(2026, 9, 23, hour, minute)
        // Keep the 3-day rule exactly met at the new hour, so only the hour varies.
        state.firstLaunchDate = state.now.addingTimeInterval(-3 * day)
        return state
    }

    func testConstants() {
        XCTAssertEqual(ReviewPromptPolicy.minimumEntries, 20)
        XCTAssertEqual(ReviewPromptPolicy.minimumDaysSinceFirstLaunch, 3)
        XCTAssertEqual(ReviewPromptPolicy.minimumDaysBetweenRequests, 90)
    }

    func testRequestsWhenEveryThresholdIsMetExactly() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: eligible()))
    }

    // MARK: - Entry count

    func testNineteenEntriesIsTooFew() {
        var state = eligible()
        state.totalEntries = 19
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    // MARK: - Days since first launch

    func testJustUnderThreeDaysIsTooSoon() {
        var state = eligible()
        state.firstLaunchDate = now.addingTimeInterval(-3 * day + 1)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    /// No first-launch date means the service never ran; "not yet" is the
    /// safe reading.
    func testMissingFirstLaunchDateNeverRequests() {
        var state = eligible()
        state.firstLaunchDate = nil
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    /// A clock moved backwards puts the first launch in the future.
    func testFirstLaunchInTheFutureNeverRequests() {
        var state = eligible()
        state.firstLaunchDate = now.addingTimeInterval(day)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    // MARK: - Once per version

    func testSecondRequestInTheSameVersionIsRefused() {
        var state = eligible()
        state.lastRequestVersion = "1.1"
        state.lastRequestDate = now.addingTimeInterval(-200 * day)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state),
                       "once per version holds even when 90 days have passed")
    }

    func testEarlierVersionNinetyDaysAgoIsAskedAgain() {
        var state = eligible()
        state.lastRequestVersion = "1.0"
        state.lastRequestDate = now.addingTimeInterval(-90 * day)
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: state))
    }

    // MARK: - 90 days between attempts

    func testNewVersionButUnderNinetyDaysIsTooSoon() {
        var state = eligible()
        state.lastRequestVersion = "1.0"
        state.lastRequestDate = now.addingTimeInterval(-90 * day + 1)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    func testLastRequestInTheFutureIsTreatedAsTooSoon() {
        var state = eligible()
        state.lastRequestVersion = "1.0"
        state.lastRequestDate = now.addingTimeInterval(day)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
    }

    // MARK: - Quiet hours (22:00–07:00 local)

    func testQuietHoursEdges() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: eligible(at: 21, 59)), "21:59 asks")
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: eligible(at: 22, 0)), "22:00 refuses")
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: eligible(at: 3, 0)), "03:00 refuses")
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: eligible(at: 6, 59)), "06:59 refuses")
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: eligible(at: 7, 0)), "07:00 asks")
    }

    /// LOCAL time: the same instant is night in one zone and morning in another.
    func testQuietHoursFollowTheCalendarsZone() {
        var state = eligible(at: 23)
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
        state.calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!   // 06:00 there
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
        state.calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")! // 02:30 there
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state))
        state.calendar.timeZone = TimeZone(identifier: "America/New_York")! // 17:00 there
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: state))
    }

    /// Quiet hours are a timing rule, so the developer hook skips them...
    func testBypassIgnoresQuietHours() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: eligible(at: 23), bypassingThresholds: true))
    }

    /// ...but a blocker still holds at night with the bypass on.
    func testBypassAtNightStillHonoursBlockers() {
        var state = eligible(at: 23)
        state.blockers.newbornFlag = true
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state, bypassingThresholds: true))
    }

    // MARK: - Blockers (the calm rule)

    func testEachBlockerAloneStopsTheRequest() {
        let cases: [ReviewPromptPolicy.Blockers] = [
            .init(belowReferenceGain: true),
            .init(newbornFlag: true),
            .init(failedTransaction: true),
        ]
        for blockers in cases {
            var state = eligible()
            state.blockers = blockers
            XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state), "\(blockers)")
        }
    }

    // MARK: - The simulator hook

    /// The hook exists so run-and-look reaches the system sheet on a fresh
    /// install, which fails every threshold at once.
    func testBypassSkipsEveryThreshold() {
        let fresh = ReviewPromptPolicy.State(
            totalEntries: 1,
            firstLaunchDate: now,
            now: now,
            lastRequestVersion: "1.1",
            lastRequestDate: now,
            currentVersion: "1.1",
            blockers: .none
        )
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: fresh))
        XCTAssertTrue(ReviewPromptPolicy.shouldRequest(state: fresh, bypassingThresholds: true))
    }

    /// ...but never the blockers: those are the part worth watching hold.
    func testBypassDoesNotSkipBlockers() {
        var state = eligible()
        state.blockers.belowReferenceGain = true
        XCTAssertFalse(ReviewPromptPolicy.shouldRequest(state: state, bypassingThresholds: true))
    }
}

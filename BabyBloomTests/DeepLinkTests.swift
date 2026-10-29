import XCTest
@testable import BabyBloom

/// L4: QA opens these exact URLs, so the round trip and the rejects are pinned.
final class DeepLinkTests: XCTestCase {

    func testEveryDestinationRoundTrips() {
        for destination in DeepLink.Destination.allCases {
            XCTAssertEqual(DeepLink.destination(from: DeepLink.url(destination)), destination)
        }
        XCTAssertEqual(DeepLink.url(.feeding).absoluteString, "nenita://tab/feeding")
    }

    func testCaseInsensitive() {
        XCTAssertEqual(DeepLink.destination(from: URL(string: "NENITA://Tab/Sleep")!), .sleep)
    }

    func testRejectsAnythingElse() {
        for string in ["nenita://tab/", "nenita://tab/more", "nenita://tab/feeding/extra",
                       "nenita://growth/feeding", "https://tab/feeding", "nenita:feeding"] {
            XCTAssertNil(DeepLink.destination(from: URL(string: string)!), string)
        }
    }

    /// D16: the widget's capsule starts a feed only when none runs, and the
    /// per-minute copies of the entry keep that state.
    func testWidgetControlFollowsTheRunningFeed() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let idle = BabyBloomEntry(date: now, babyName: "Mia", lastFeedingTime: nil,
                                  sleepStartTime: nil, lastSleepDuration: nil,
                                  todayFeedingCount: 0, isAsleep: false, nextFeedingTime: nil)
        XCTAssertEqual(WidgetControl.state(for: idle), .start)
        let start = now.addingTimeInterval(-600)
        let running = BabyBloomEntry(date: now, babyName: "Mia", lastFeedingTime: start,
                                     sleepStartTime: nil, lastSleepDuration: nil,
                                     todayFeedingCount: 1, isAsleep: false, nextFeedingTime: nil,
                                     runningFeedStart: start)
        XCTAssertEqual(WidgetControl.state(for: running.at(now.addingTimeInterval(60))),
                       .running(since: start))
    }

    func testEveryDestinationHasATab() {
        for destination in DeepLink.Destination.allCases {
            XCTAssertEqual(MainTabView.Tab(destination).rawValue,
                           destination == .home ? "dashboard" : destination.rawValue)
        }
    }
}

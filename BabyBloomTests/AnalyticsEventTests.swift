import XCTest
@testable import BabyBloom

/// The payload guard: every event the app can send maps to an allow-listed
/// name, allow-listed keys, and values of an allow-listed type — tokens from a
/// closed vocabulary, Bools, and the one Int (`seconds_visible`). `.int` itself
/// takes any Int; what keeps other numbers out is this list, together with the
/// closed enum and the exhaustiveness guard below.
///
/// The allow-list below is a SECOND, independent statement of the contract. It
/// is meant to be edited by hand when an event is added, so a new property is
/// a decision someone made on purpose rather than a side effect.
final class AnalyticsEventTests: XCTestCase {

    private enum Expected: Equatable {
        case bool
        case int
        case token(Set<String>)
    }

    private static let pages: Set<String> = [
        "welcome", "name", "birth", "feeding", "growth", "fact",
        "growth_showcase", "notifications", "widgets", "generating", "premium",
    ]
    private static let plans: Set<String> = ["weekly", "monthly", "yearly"]
    private static let kinds: Set<String> = ["feeding", "sleep", "diaper", "growth", "event"]
    /// One total across kinds, with edges clear of the clinical 8-12 feeds a day.
    private static let totals: Set<String> = ["0", "1-5", "6-15", "16+"]

    private static let allowList: [String: [String: Expected]] = [
        "onboarding_page_viewed":  ["page": .token(pages)],
        "onboarding_completed":    ["birth_measurements_known": .bool],
        "paywall_shown":           ["source": .token(["onboarding", "settings", "history_lock", "locked_card", "events"])],
        "plan_selected":           ["plan": .token(plans)],
        "purchase_result":         ["plan": .token(plans),
                                    "result": .token(["success", "cancelled", "failed", "pending",
                                                      "already_subscribed"])],
        "restore_result":          ["result": .token(["found", "not_found", "failed", "cancelled"])],
        "paywall_closed_x":        ["seconds_visible": .int],
        "first_entry":             ["kind": .token(kinds)],
        // One aggregate a day — never an event per entry, never a per-kind
        // count: presence per kind and one bucketed total (DECISIONS 2026-09-23).
        "daily_activity":          ["feeding": .bool, "sleep": .bool, "diaper": .bool,
                                    "growth": .bool, "event": .bool, "total": .token(totals)],
        "notification_permission": ["granted": .bool],
        "widget_installed":        [:],
        "history_lock_shown":      ["surface": .token(["feeding", "sleep", "diaper", "events", "recent_activity"])],
        "review_prompt_requested": [:],
    ]

    /// Every event carries this, added by the facade rather than by a case.
    private static let buildChannel: (key: String, values: Set<String>) =
        ("build_channel", ["appstore", "testflight", "development", "simulator"])

    /// Every case, with every value of every token parameter.
    private static var everyEvent: [AnalyticsEvent] {
        var events: [AnalyticsEvent] = []
        events += AnalyticsEvent.OnboardingPage.allCases.map { .onboardingPageViewed($0) }
        events += [true, false].map { .onboardingCompleted(birthMeasurementsKnown: $0) }
        events += AnalyticsEvent.PaywallSource.allCases.map { .paywallShown($0) }
        events += AnalyticsEvent.Plan.allCases.map { .planSelected($0) }
        for plan in AnalyticsEvent.Plan.allCases {
            events += AnalyticsEvent.PurchaseOutcome.allCases.map { .purchaseResult(plan, $0) }
        }
        events += AnalyticsEvent.RestoreOutcome.allCases.map { .restoreResult($0) }
        events += [0, 7, 3_600].map { .paywallClosedX(secondsVisible: $0) }
        events += AnalyticsEvent.EntryKind.allCases.map { .firstEntry($0) }
        // Every total bucket, with kinds both present and absent.
        events += [0, 1, 3, 8].map {
            .dailyActivity(AnalyticsEvent.DailyActivity(
                AnalyticsEvent.DayCounts(feeding: $0, sleep: 0, diaper: $0, growth: 0, event: $0),
                reportedAt: Date(timeIntervalSince1970: 1_790_000_000)))
        }
        events += [true, false].map { .notificationPermission(granted: $0) }
        events.append(.widgetInstalled)
        events += AnalyticsEvent.HistorySurface.allCases.map { .historyLockShown($0) }
        events.append(.reviewPromptRequested)
        return events
    }

    /// Does not run; it exists to stop COMPILING when a case is added, so the
    /// author is sent here to extend `everyEvent` and the allow-list.
    private func exhaustivenessGuard(_ event: AnalyticsEvent) {
        switch event {
        case .onboardingPageViewed, .onboardingCompleted, .paywallShown, .planSelected,
             .purchaseResult, .restoreResult, .paywallClosedX, .firstEntry, .dailyActivity,
             .notificationPermission, .widgetInstalled, .historyLockShown, .reviewPromptRequested:
            break
        }
    }

    func testTheWalkCoversEveryEventName() {
        XCTAssertEqual(Set(Self.everyEvent.map(\.name)), Set(AnalyticsEvent.Name.allCases))
        XCTAssertEqual(Set(AnalyticsEvent.Name.allCases.map(\.rawValue)), Set(Self.allowList.keys))
    }

    func testEveryEventMapsToAnAllowListedPayload() {
        for channel in AnalyticsEvent.BuildChannel.allCases {
            for event in Self.everyEvent {
                let payload = event.payload(channel: channel)
                guard let expected = Self.allowList[payload.name] else {
                    XCTFail("\(payload.name) is not allow-listed"); continue
                }
                XCTAssertEqual(Set(payload.properties.keys),
                               Set(expected.keys).union([Self.buildChannel.key]),
                               "keys of \(payload.name)")
                for (key, value) in payload.properties {
                    if key == Self.buildChannel.key {
                        guard case .token(let token) = value.storage else {
                            XCTFail("build_channel is not a token"); continue
                        }
                        XCTAssertTrue(Self.buildChannel.values.contains(token))
                        continue
                    }
                    switch (expected[key], value.storage) {
                    case (.bool?, .bool), (.int?, .int):
                        break
                    case (.token(let allowed)?, .token(let token)):
                        XCTAssertTrue(allowed.contains(token), "\(payload.name).\(key) = \(token)")
                    default:
                        XCTFail("\(payload.name).\(key) has an unexpected type: \(value.storage)")
                    }
                }
            }
        }
    }

    func testNamesAndKeysAreStableSnakeCase() {
        let snake = /^[a-z][a-z0-9_]{0,39}$/
        for name in AnalyticsEvent.Name.allCases {
            XCTAssertNotNil(name.rawValue.wholeMatch(of: snake), name.rawValue)
        }
        for key in AnalyticsEvent.Key.allCases {
            XCTAssertNotNil(key.rawValue.wholeMatch(of: snake), key.rawValue)
        }
    }

    func testEveryOnboardingStepHasItsOwnPageID() {
        let ids = OnboardingStep.allCases.map { AnalyticsEvent.OnboardingPage($0).rawValue }
        XCTAssertEqual(ids.count, Set(ids).count, "two steps share a page id")
        XCTAssertEqual(Set(ids), Self.pages)
    }

    @MainActor func testPlanComesOnlyFromTheThreeProductIDs() {
        XCTAssertEqual(AnalyticsEvent.Plan(productID: SubscriptionManager.weeklyID), .weekly)
        XCTAssertEqual(AnalyticsEvent.Plan(productID: SubscriptionManager.monthlyID), .monthly)
        XCTAssertEqual(AnalyticsEvent.Plan(productID: SubscriptionManager.yearlyID), .yearly)
        XCTAssertNil(AnalyticsEvent.Plan(productID: "com.nenita.app.premium.lifetime"))
    }

    func testTheTotalIsBucketedAtTheAgreedEdges() {
        let expected: [(Int, String)] = [(0, "0"), (1, "1-5"), (5, "1-5"), (6, "6-15"),
                                         (15, "6-15"), (16, "16+"), (80, "16+"), (-1, "0")]
        for (count, bucket) in expected {
            XCTAssertEqual(AnalyticsEvent.TotalBucket(count: count).rawValue, bucket, "count \(count)")
        }
    }

    /// A day says which kinds were logged and roughly how much in all — never
    /// how many feeds — and travels at noon of that day, outside any session.
    func testDailyActivityCarriesPresenceATotalAndItsOwnNoon() {
        let noon = Date(timeIntervalSince1970: 1_790_000_000)
        let counts = AnalyticsEvent.DayCounts(feeding: 9, sleep: 3, diaper: 0, growth: 1, event: 0)
        let payload = AnalyticsEvent.dailyActivity(AnalyticsEvent.DailyActivity(counts, reportedAt: noon))
            .payload(channel: .appstore)
        XCTAssertEqual(payload.properties["feeding"], .bool(true))
        XCTAssertEqual(payload.properties["sleep"], .bool(true))
        XCTAssertEqual(payload.properties["diaper"], .bool(false))
        XCTAssertEqual(payload.properties["growth"], .bool(true))
        XCTAssertEqual(payload.properties["event"], .bool(false))
        XCTAssertEqual(payload.properties["total"], .token(AnalyticsEvent.TotalBucket.sixToFifteen))
        XCTAssertEqual(payload.timestamp, noon)
        XCTAssertTrue(payload.outsideSession)
        // Every other event keeps the SDK's own time and session.
        let other = AnalyticsEvent.reviewPromptRequested.payload(channel: .appstore)
        XCTAssertNil(other.timestamp)
        XCTAssertFalse(other.outsideSession)
    }

    /// The same order AmplitudeCore's own detection uses, so dev and QA
    /// traffic never reads as `appstore`.
    func testBuildChannelKeepsEverythingButTheStoreOutOfAppstore() {
        typealias C = AnalyticsEvent.BuildChannel
        XCTAssertEqual(C.detect(isSimulator: true, hasEmbeddedProfile: false, receiptName: "receipt"), .simulator)
        XCTAssertEqual(C.detect(isSimulator: false, hasEmbeddedProfile: true, receiptName: "sandboxReceipt"), .development)
        XCTAssertEqual(C.detect(isSimulator: false, hasEmbeddedProfile: true, receiptName: nil), .development)
        XCTAssertEqual(C.detect(isSimulator: false, hasEmbeddedProfile: false, receiptName: "sandboxReceipt"), .testflight)
        XCTAssertEqual(C.detect(isSimulator: false, hasEmbeddedProfile: false, receiptName: "receipt"), .appstore)
    }

    func testSecondsVisibleIsWholeAndNeverNegative() {
        let shown = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertEqual(AnalyticsEvent.paywallClosedX(since: shown, now: shown.addingTimeInterval(12.9)),
                       .paywallClosedX(secondsVisible: 12))
        // A clock moved backwards must not send a negative duration.
        XCTAssertEqual(AnalyticsEvent.paywallClosedX(since: shown, now: shown.addingTimeInterval(-60)),
                       .paywallClosedX(secondsVisible: 0))
    }
}

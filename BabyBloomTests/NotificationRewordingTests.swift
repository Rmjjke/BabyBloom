import UserNotifications
import XCTest
@testable import BabyBloom

/// A notification scheduled in one language is written again in the next one
/// after a switch, at the moment it was going to fire.
@MainActor
final class NotificationRewordingTests: XCTestCase {

    /// Holds requests as the system centre would: an add under a pending id
    /// replaces it.
    private final class FakeCenter: NotificationCenterSeam, @unchecked Sendable {
        private let lock = NSLock()
        private var store: [String: UNNotificationRequest] = [:]

        var requests: [String: UNNotificationRequest] { lock.withLock { store } }

        func pending() async -> [UNNotificationRequest] { lock.withLock { Array(store.values) } }

        func add(_ request: UNNotificationRequest, then: (@Sendable () -> Void)?) {
            lock.withLock { store[request.identifier] = request }
            then?()
        }

        func remove(_ identifiers: [String]) {
            lock.withLock { identifiers.forEach { store[$0] = nil } }
        }
    }

    private let center = FakeCenter()
    private let babyName = "Mia"

    /// Every kind the manager posts. `bb.engage.monthly_growth` is only ever
    /// cancelled, never posted.
    private let everyKind: Set<String> = [
        "bb.feeding.reminder", "bb.feeding.active.bf", "bb.sleep.wake_window", "bb.sleep.active",
        "bb.diaper.reminder", "bb.engage.measurements", "bb.engage.weekly_summary", "bb.engage.idle",
        "bb.growth.weigh_in", "bb.growth.newborn_flag", "bb.growth.gain_low",
    ]

    override func setUp() async throws {
        try await super.setUp()
        #if !targetEnvironment(simulator)
        throw XCTSkip("the weekly request is posted through a simulator-only lever")
        #endif
        let manager = NotificationManager.shared
        let previousCenter = manager.center
        let language = LocalizationManager.shared.language
        let defaults = UserDefaults.standard
        let keys = ["hasLoggedFirstFeeding", "hasLoggedFirstSleep", "hasFirstGrowthEntry",
                    "bb.storedBabyName", "bb.growth.lastGainSignalAt", "BBWeeklyNotifyIn"]
        let saved = keys.map { defaults.object(forKey: $0) }
        addTeardownBlock { @MainActor in
            manager.center = previousCenter
            LocalizationManager.shared.setLanguage(language)
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        manager.center = center
        keys.forEach(defaults.removeObject(forKey:))
        LocalizationManager.shared.setLanguage(.en)
    }

    // MARK: Scenarios

    /// The kinds that can be pending together; the sleep pair and the two
    /// growth signals exclude each other, so they come in separate passes.
    private enum Scenario: CaseIterable { case awake, asleep, newborn, older }

    private func post(_ scenario: Scenario, babyName: String) {
        let manager = NotificationManager.shared
        let now = Date()
        let calendar = Calendar.current
        switch scenario {
        case .awake:
            manager.onFeedingSaved(ageMonths: 0, babyName: babyName, isActiveBF: true)
            manager.onSleepEnded(ageMonths: 0, endedAt: now)
            manager.scheduleIdleReminder()
            UserDefaults.standard.set(3600, forKey: "BBWeeklyNotifyIn")
            manager.rescheduleWeeklySummary()
        case .asleep:
            manager.onSleepStarted(ageMonths: 0, babyName: babyName, isNight: false)
        case .newborn:
            let birth = calendar.date(byAdding: .day, value: -5, to: now)!
            manager.onGrowthDataChanged(
                babyName: babyName, birthDate: birth, correctedBirthDate: birth, birthWeightKg: 3.5, isMale: false,
                measurements: [WeightMeasurement(date: calendar.date(byAdding: .day, value: 4, to: birth)!, weightKg: 3.1)],
                isPremium: false, now: now)
        case .older:
            // NewbornWindowGateTests' control: two post-window intervals below the reference.
            let birth = calendar.date(byAdding: .day, value: -47, to: now)!
            let measurements = [26, 33, 40].enumerated().map { index, day in
                WeightMeasurement(date: calendar.date(byAdding: .day, value: day, to: birth)!,
                                  weightKg: 4.00 + 0.02 * Double(index))
            }
            manager.onGrowthDataChanged(
                babyName: babyName, birthDate: birth, correctedBirthDate: birth, birthWeightKg: 3.5, isMale: false,
                measurements: measurements, isPremium: true, now: now)
        }
    }

    /// The words each kind is written from, resolved straight from the table:
    /// what a request must read in whatever language is current.
    private func expected(_ id: String, babyName: String) -> (title: String, body: String)? {
        let format = { (key: String) in String(format: key.l, babyName) }
        return switch id {
        case "bb.feeding.reminder": ("notification.feeding_title".l, "notification.feeding_body".l)
        case "bb.feeding.active.bf": ("notification.feeding_long_title".l, "notification.feeding_long_body".l)
        case "bb.sleep.wake_window": ("notification.sleep_title".l, "notification.sleep_body".l)
        case "bb.sleep.active": ("notification.sleep_active_title".l, "notification.sleep_active_body".l)
        case "bb.diaper.reminder": ("notification.diaper_title".l, format("notification.diaper_body"))
        case "bb.engage.measurements": (format("notification.measurements_title"), "notification.measurements_body".l)
        case "bb.engage.weekly_summary": ("notification.weekly_title".l, "notification.weekly_body".l)
        case "bb.engage.idle": ("notification.idle_title".l, format("notification.idle_body"))
        case "bb.growth.weigh_in": ("notification.weigh_in_title".l, format("notification.weigh_in_body"))
        case "bb.growth.newborn_flag": ("notification.newborn_flag_title".l, "newborn.flag_loss".l)
        case "bb.growth.gain_low": ("notification.gain_low_title".l, "notification.gain_low_body".l)
        default: nil
        }
    }

    private func texts() -> [String: (title: String, body: String)] {
        center.requests.mapValues { ($0.content.title, $0.content.body) }
    }

    // MARK: Tests

    /// The acceptance: after a switch to de, every pending request reads as
    /// the de table resolves its words. de ships only its brand name until its
    /// copy lands, so today this is English by fallback; the ru pass below is
    /// the check that the words really change.
    func testASwitchToGermanRewordsEveryKindAndKeepsTheFireMoment() async throws {
        var covered: Set<String> = []
        for scenario in Scenario.allCases {
            center.remove(Array(center.requests.keys))
            post(scenario, babyName: babyName)
            let before = center.requests
            covered.formUnion(before.keys)

            LocalizationManager.shared.setLanguage(.de)
            let later = Date().addingTimeInterval(600)
            let reworded = await NotificationRewording.reword(center: center, now: later)
            XCTAssertEqual(Set(reworded), Set(before.keys), "\(scenario)")

            for (id, request) in center.requests {
                let want = try XCTUnwrap(expected(id, babyName: babyName), id)
                XCTAssertEqual(request.content.title, want.title, id)
                XCTAssertEqual(request.content.body, want.body, id)
                XCTAssertEqual(request.content.sound, before[id]?.content.sound, id)
                XCTAssertEqual(request.content.interruptionLevel, before[id]?.content.interruptionLevel, id)
                let old = try XCTUnwrap(before[id]?.trigger as? UNTimeIntervalNotificationTrigger, id)
                let new = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger, id)
                // Ten minutes on, the request fires at the same moment.
                XCTAssertEqual(new.timeInterval, old.timeInterval - 600, accuracy: 1, id)
            }
            LocalizationManager.shared.setLanguage(.en)
        }
        XCTAssertEqual(covered, everyKind)
    }

    /// The same pass into a language with its copy: every title and body
    /// changes, and none reads as a raw key.
    func testASwitchToRussianChangesEveryString() async {
        for scenario in Scenario.allCases {
            center.remove(Array(center.requests.keys))
            post(scenario, babyName: babyName)
            let english = texts()

            LocalizationManager.shared.setLanguage(.ru)
            await NotificationRewording.reword(center: center, now: Date())
            for (id, russian) in texts() {
                XCTAssertNotEqual(russian.title, english[id]?.title, id)
                XCTAssertNotEqual(russian.body, english[id]?.body, id)
                XCTAssertFalse(russian.title.hasPrefix("notification."), id)
                XCTAssertFalse(russian.body.hasPrefix("notification."), id)
            }
            LocalizationManager.shared.setLanguage(.en)
        }
    }

    /// A baby with no name is called by the language's default word, so the
    /// default follows the switch rather than staying English.
    func testTheDefaultNameFollowsTheLanguage() async throws {
        post(.awake, babyName: "baby.default_name".l)
        let english = try XCTUnwrap(center.requests["bb.diaper.reminder"]).content.body
        XCTAssertTrue(english.contains("baby.default_name".l), english)

        LocalizationManager.shared.setLanguage(.ru)
        await NotificationRewording.reword(center: center, now: Date())
        let russian = try XCTUnwrap(center.requests["bb.diaper.reminder"]).content.body
        XCTAssertEqual(russian, String(format: "notification.diaper_body".l, "baby.default_name".l))
        XCTAssertNotEqual("baby.default_name".l, "Baby")
    }

    /// The weekly summary's calendar trigger is kept as it is.
    func testACalendarTriggerIsKept() async throws {
        let words = NotificationWords(title: .init("notification.weekly_title"),
                                      body: .init("notification.weekly_body"), fireAt: nil)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(year: 2030, month: 1, day: 7, hour: 9, minute: 0), repeats: false)
        center.add(request("bb.engage.weekly_summary", words: words, trigger: trigger))

        LocalizationManager.shared.setLanguage(.ru)
        await NotificationRewording.reword(center: center, now: Date())
        let reworded = try XCTUnwrap(center.requests["bb.engage.weekly_summary"])
        XCTAssertEqual((reworded.trigger as? UNCalendarNotificationTrigger)?.dateComponents, trigger.dateComponents)
        XCTAssertEqual(reworded.content.title, "notification.weekly_title".l)
    }

    /// Under a second left, the request is left alone: it fires in the old
    /// language either way, and a new interval of zero is not allowed.
    func testARequestAboutToFireIsLeftAlone() async throws {
        let now = Date()
        let words = NotificationWords(title: .init("notification.feeding_title"),
                                      body: .init("notification.feeding_body"), fireAt: now.addingTimeInterval(0.5))
        center.add(request("bb.feeding.reminder", words: words,
                           trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)))

        LocalizationManager.shared.setLanguage(.ru)
        let reworded = await NotificationRewording.reword(center: center, now: now)
        XCTAssertEqual(reworded, [])
        XCTAssertEqual(try XCTUnwrap(center.requests["bb.feeding.reminder"]).content.title, "old")
    }

    /// A request with no words (an earlier build's, a medication reminder) is
    /// not touched: the medication pass writes its own again.
    func testARequestWithoutWordsIsNotTouched() async throws {
        let content = UNMutableNotificationContent()
        content.title = "old"
        center.add(UNNotificationRequest(identifier: "bb.med.x", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)))

        LocalizationManager.shared.setLanguage(.ru)
        let reworded = await NotificationRewording.reword(center: center, now: Date())
        XCTAssertEqual(reworded, [])
        XCTAssertEqual(try XCTUnwrap(center.requests["bb.med.x"]).content.title, "old")
    }

    /// An id posted while the pass ran is newer than the pass's copy: the
    /// copy is not put back over it.
    func testAnIdTouchedDuringThePassIsNotPutBack() async throws {
        let words = NotificationWords(title: .init("notification.idle_title"),
                                      body: .init("notification.idle_body", babyName),
                                      fireAt: Date().addingTimeInterval(3600))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        center.add(request("bb.engage.idle", words: words, trigger: trigger))
        center.add(request("bb.feeding.reminder", words: words, trigger: trigger))

        LocalizationManager.shared.setLanguage(.ru)
        let reworded = await NotificationRewording.reword(center: center, now: Date(),
                                                          skipping: { ["bb.engage.idle"] })
        XCTAssertEqual(reworded, ["bb.feeding.reminder"])
        XCTAssertEqual(try XCTUnwrap(center.requests["bb.engage.idle"]).content.title, "old")
        XCTAssertEqual(try XCTUnwrap(center.requests["bb.feeding.reminder"]).content.title,
                       "notification.idle_title".l)
    }

    /// A repeating interval keeps its trigger: it counts from its add, not
    /// from a stored moment.
    func testARepeatingIntervalIsKept() async throws {
        let words = NotificationWords(title: .init("notification.feeding_title"),
                                      body: .init("notification.feeding_body"), fireAt: nil)
        center.add(request("bb.feeding.reminder", words: words,
                           trigger: UNTimeIntervalNotificationTrigger(timeInterval: 7200, repeats: true)))

        LocalizationManager.shared.setLanguage(.ru)
        let reworded = await NotificationRewording.reword(center: center, now: Date())
        XCTAssertEqual(reworded, ["bb.feeding.reminder"])
        let trigger = try XCTUnwrap(center.requests["bb.feeding.reminder"]?.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.timeInterval, 7200)
    }

    /// A launch re-words only when the language moved since the last wording;
    /// before any wording is recorded there is nothing to compare.
    func testALaunchRewordsOnlyWhenTheLanguageMoved() {
        XCTAssertTrue(NotificationManager.shouldReword(worded: "en", current: "ru"))
        XCTAssertFalse(NotificationManager.shouldReword(worded: "ru", current: "ru"))
        XCTAssertFalse(NotificationManager.shouldReword(worded: nil, current: "ru"))
    }

    private func request(_ id: String, words: NotificationWords, trigger: UNNotificationTrigger) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "old"
        content.userInfo = words.userInfo
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}

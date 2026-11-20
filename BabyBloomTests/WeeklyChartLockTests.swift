import XCTest
@testable import BabyBloom

/// The weekly charts of Feeding, Sleep and Diaper are Premium: what stands
/// under their header, the reason line's window, and the paywall list that
/// names them.
@MainActor
final class WeeklyChartLockTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: - States

    func testNothingStandsUnderTheHeaderUntilTheEntitlementsAreKnown() {
        for premium in [false, true] {
            for records in [false, true] {
                XCTAssertEqual(WeeklyChartLock.state(tracker: .sleep, entitlementsResolved: false, isPremium: premium,
                                                     weekHasRecords: records, reasonOpen: true), .hidden)
            }
        }
    }

    func testASubscriberSeesTheChart() {
        for records in [false, true] {
            XCTAssertEqual(WeeklyChartLock.state(tracker: .feeding, entitlementsResolved: true, isPremium: true,
                                                 weekHasRecords: records, reasonOpen: true), .chart)
        }
    }

    func testAFreeUserSeesTheTrackersTeaserForAWeekWithRecords() {
        for tracker in WeeklyChartTracker.allCases {
            XCTAssertEqual(WeeklyChartLock.state(tracker: tracker, entitlementsResolved: true, isPremium: false,
                                                 weekHasRecords: true, reasonOpen: false),
                           .locked(teaserKey: "premium.teaser_weekly_\(tracker.rawValue)", reasonKey: nil))
        }
    }

    func testAnEmptyWeekReadsTheNeutralTeaser() {
        for tracker in WeeklyChartTracker.allCases {
            XCTAssertEqual(WeeklyChartLock.state(tracker: tracker, entitlementsResolved: true, isPremium: false,
                                                 weekHasRecords: false, reasonOpen: false),
                           .locked(teaserKey: "premium.teaser_weekly_empty", reasonKey: nil))
        }
    }

    func testAnOpenWindowAddsTheReasonOverEitherTeaser() {
        XCTAssertEqual(WeeklyChartLock.state(tracker: .diaper, entitlementsResolved: true, isPremium: false,
                                             weekHasRecords: true, reasonOpen: true),
                       .locked(teaserKey: "premium.teaser_weekly_diaper", reasonKey: "premium.weekly_reason"))
        XCTAssertEqual(WeeklyChartLock.state(tracker: .diaper, entitlementsResolved: true, isPremium: false,
                                             weekHasRecords: false, reasonOpen: true),
                       .locked(teaserKey: "premium.teaser_weekly_empty", reasonKey: "premium.weekly_reason"))
    }

    func testEveryLineOfTheCardIsTranslatedInEveryLanguage() throws {
        let keys = WeeklyChartTracker.allCases.map(WeeklyChartLock.teaserKey(for:))
            + [WeeklyChartLock.emptyTeaserKey, WeeklyChartLock.reasonKey, "premium.locked_hint",
               "premium.opens_a11y_hint", "section.weekly_chart"]
        for language in SupportedLanguage.available {
            let table = try ownTable(language)
            for key in keys {
                XCTAssertFalse(table[key, default: ""].isEmpty, "\(language) \(key)")
            }
        }
    }

    /// The language's own file: the app's lookup falls back to English, so a
    /// key missing from a language would still read as translated through it.
    private func ownTable(_ language: SupportedLanguage) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: language.rawValue, withExtension: "json", subdirectory: "Localization")
                ?? Bundle.main.url(forResource: language.rawValue, withExtension: "json"),
            "\(language.rawValue).json is not in the app bundle")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    // MARK: - The reason window

    private func open(launch: Date, now: Date, closedAt: Date? = nil, formerSubscriber: Bool = false) -> Bool {
        WeeklyChartLock.reasonOpen(cohort: .beforeOffers(launchAt: launch), closedAt: closedAt,
                                   formerSubscriber: formerSubscriber, now: now, calendar: calendar)
    }

    func testTheReasonReadsForThirteenCalendarDaysAfterTheFirstLaunchAndNotOnTheFourteenth() {
        let launch = date(2026, 11, 20, 23, 50)
        XCTAssertTrue(open(launch: launch, now: launch))
        XCTAssertTrue(open(launch: launch, now: date(2026, 11, 21, 0, 10)), "a new day is not a closed window")
        XCTAssertTrue(open(launch: launch, now: date(2026, 12, 3, 23, 59)), "day 13")
        XCTAssertFalse(open(launch: launch, now: date(2026, 12, 4, 0, 0)), "day 14")
        XCTAssertFalse(open(launch: launch, now: date(2027, 1, 30)))
        XCTAssertEqual(WeeklyChartLock.reasonDays, 14)
    }

    func testTheWindowCountsCalendarDaysAcrossTheClockChange() {
        // 25 Oct 2026: Madrid falls back an hour; day 13 is still day 13.
        let launch = date(2026, 10, 20, 9)
        XCTAssertTrue(open(launch: launch, now: date(2026, 11, 2, 23, 30)))
        XCTAssertFalse(open(launch: launch, now: date(2026, 11, 3, 0, 30)))
    }

    func testAFirstTapClosesTheWindow() {
        let launch = date(2026, 11, 20)
        XCTAssertFalse(open(launch: launch, now: date(2026, 11, 22), closedAt: date(2026, 11, 21)))
    }

    func testAFormerSubscriberAndANewInstallReadNoReason() {
        let launch = date(2026, 11, 20)
        XCTAssertFalse(open(launch: launch, now: launch, formerSubscriber: true))
        XCTAssertFalse(WeeklyChartLock.reasonOpen(cohort: .new, closedAt: nil, formerSubscriber: false,
                                                  now: launch, calendar: calendar))
    }

    // MARK: - The window's store

    private func freshDefaults() -> UserDefaults {
        let name = "WeeklyChartLockTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testATapOnOneScreenClosesTheWindowForGoodAndKeepsTheFirstDate() {
        let defaults = freshDefaults()
        let launch = date(2026, 11, 20)
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: launch, defaults: defaults)
        let window = WeeklyChartReasonWindow(defaults: defaults, calendar: calendar, formerSubscriber: { false })
        XCTAssertTrue(window.isOpen(now: date(2026, 11, 21)))

        window.close(now: date(2026, 11, 21))
        window.close(now: date(2026, 11, 23))
        XCTAssertFalse(window.isOpen(now: date(2026, 11, 22)))
        XCTAssertEqual(window.closedAt, date(2026, 11, 21))

        let nextLaunch = WeeklyChartReasonWindow(defaults: defaults, calendar: calendar, formerSubscriber: { false })
        XCTAssertFalse(nextLaunch.isOpen(now: date(2026, 11, 22)), "the close survives a relaunch")
        XCTAssertEqual(defaults.object(forKey: WeeklyChartReasonWindow.closedAtKey) as? Date, date(2026, 11, 21))
    }

    func testTheWindowReadsTheCohortWrittenAfterItWasMade() {
        let defaults = freshDefaults()
        let window = WeeklyChartReasonWindow(defaults: defaults, calendar: calendar, formerSubscriber: { false })
        XCTAssertFalse(window.isOpen(now: date(2026, 11, 20)), "no cohort yet")
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: date(2026, 11, 20), defaults: defaults)
        XCTAssertTrue(window.isOpen(now: date(2026, 11, 20)))
    }

    func testANewInstallNeverReadsTheSubscriptionMark() {
        let defaults = freshDefaults()
        OfferCohort.recordIfNeeded(onboardingCompleted: false, now: date(2026, 11, 20), defaults: defaults)
        var reads = 0
        let window = WeeklyChartReasonWindow(defaults: defaults, calendar: calendar,
                                             formerSubscriber: { reads += 1; return false })
        XCTAssertFalse(window.isOpen(now: date(2026, 11, 20)))
        XCTAssertEqual(reads, 0)
    }

    func testAFormerSubscribersWindowStaysShut() {
        let defaults = freshDefaults()
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: date(2026, 11, 20), defaults: defaults)
        let window = WeeklyChartReasonWindow(defaults: defaults, calendar: calendar, formerSubscriber: { true })
        XCTAssertFalse(window.isOpen(now: date(2026, 11, 20)))
    }

    // MARK: - The week

    func testTheWeekIsMondayToSundayAroundToday() {
        let week = WeeklyChartLock.currentWeek(now: date(2026, 11, 22, 23, 59), calendar: calendar)  // a Sunday
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first, calendar.startOfDay(for: date(2026, 11, 16)))
        XCTAssertEqual(week.last, calendar.startOfDay(for: date(2026, 11, 22)))
        XCTAssertEqual(calendar.component(.weekday, from: week[0]), 2)
        let monday = WeeklyChartLock.currentWeek(now: date(2026, 11, 23, 0, 1), calendar: calendar)
        XCTAssertEqual(monday.first, calendar.startOfDay(for: date(2026, 11, 23)))
    }

    // MARK: - The card's words for VoiceOver

    func testEachPartIsReadAsOneSentence() {
        XCTAssertEqual(BBLockedCard.sentences(["Charts are Premium now.", "See each day", "Premium"]),
                       "Charts are Premium now. See each day. Premium.")
        XCTAssertEqual(BBLockedCard.sentences(["週間グラフ。", "毎日を見る"]), "週間グラフ。 毎日を見る.")
        XCTAssertEqual(BBLockedCard.sentences(["Why?", "Wait…"]), "Why? Wait…")
    }

    // MARK: - The paywall list

    func testThePaywallListNamesExactlyWhatIsPaidInItsOrder() {
        XCTAssertEqual(PremiumFeatureList.features.map(\.key),
                       ["onboarding.premium.f1", "onboarding.premium.f5", "onboarding.premium.f6", "onboarding.premium.f3"])
        XCTAssertEqual(PremiumFeatureList.features.map(\.icon),
                       ["infinity", "chart.bar.fill", "chart.line.uptrend.xyaxis", "doc.text.fill"])
        XCTAssertFalse(PremiumFeatureList.features.contains { $0.key == "onboarding.premium.f2" }, "events are free")
        for feat in PremiumFeatureList.features {
            XCTAssertNotNil(UIImage(systemName: feat.icon), feat.icon)
        }
    }

    func testEveryLineOfTheListIsTranslatedInEveryLanguage() throws {
        for language in SupportedLanguage.available {
            let table = try ownTable(language)
            for feat in PremiumFeatureList.features {
                XCTAssertFalse(table[feat.key, default: ""].isEmpty, "\(language) \(feat.key)")
            }
        }
    }
}

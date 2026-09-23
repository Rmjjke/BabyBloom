import XCTest
import SwiftData
@testable import BabyBloom

/// The facade's rules, against a spy backend, a private defaults suite and a
/// clock the test moves: when it is a no-op, what the opt-out stops, the
/// once-only events and the daily aggregate. Nothing here constructs the
/// Amplitude SDK or touches the network.
@MainActor
final class AnalyticsFacadeTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var spy: SpyAnalyticsBackend!
    private var widgetProbeCalls = 0
    private var widgetPresent = false
    /// Noon, 2026-09-23, in a fixed zone — the facade's "now".
    private var now = Date(timeIntervalSince1970: 1_790_157_600)
    private var countedDays: [DateInterval] = []
    private var dayCounts: AnalyticsEvent.DayCounts? = AnalyticsEvent.DayCounts(
        feeding: 9, sleep: 4, diaper: 2, growth: 1, event: 0)

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        suiteName = "AnalyticsFacadeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        spy = SpyAnalyticsBackend()
        widgetProbeCalls = 0
        widgetPresent = false
        countedDays = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeFacade(backend: AnalyticsBackend? = nil,
                            channel: AnalyticsEvent.BuildChannel = .appstore) -> Analytics {
        Analytics(backend: backend ?? spy, defaults: defaults, channel: channel,
                  calendar: calendar,
                  clock: { [unowned self] in self.now },
                  widgetProbe: { [unowned self] in
                      self.widgetProbeCalls += 1
                      return self.widgetPresent
                  })
    }

    private func start(_ analytics: Analytics, hasCompletedOnboarding: Bool = false) {
        analytics.start(hasCompletedOnboarding: hasCompletedOnboarding) { [unowned self] day in
            self.countedDays.append(day)
            return self.dayCounts
        }
    }

    private func advance(days: Int) {
        now = calendar.date(byAdding: .day, value: days, to: now)!
    }

    // MARK: - No-op rules

    func testNoKeyIsANoOpWhateverElseIsTrue() {
        for simulator in [true, false] {
            for debug in [true, false] {
                for spyRequested in [true, false] {
                    XCTAssertEqual(Analytics.decide(hasAPIKey: false, isSimulator: simulator,
                                                    isDebug: debug, spyRequested: spyRequested),
                                   .noop(.noAPIKey))
                }
            }
        }
    }

    func testSimulatorAndDebugAreNoOpsEvenWithAKey() {
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: true, isDebug: false, spyRequested: false),
                       .noop(.simulator))
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: true, isDebug: true, spyRequested: false),
                       .noop(.simulator))
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: false, isDebug: true, spyRequested: false),
                       .noop(.debugBuild))
    }

    func testOnlyAReleaseDeviceBuildWithAKeySends() {
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: false, isDebug: false, spyRequested: false),
                       .amplitude)
        // The spy hook is simulator-only; on a device the argument means nothing.
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: false, isDebug: false, spyRequested: true),
                       .amplitude)
        XCTAssertEqual(Analytics.decide(hasAPIKey: true, isSimulator: true, isDebug: true, spyRequested: true),
                       .spy)
    }

    /// The real shared instance, as the test host built it: simulator + Debug.
    func testTheAppsOwnFacadeIsANoOpInTheTestHost() {
        XCTAssertTrue(Analytics.shared.backend is NoopAnalyticsBackend)
    }

    /// A build that can never send keeps no state either — the test host runs
    /// the real app, and it must leave `UserDefaults` as it found it.
    func testANoOpFacadeWritesNothing() async {
        let inert = makeFacade(backend: NoopAnalyticsBackend())
        start(inert, hasCompletedOnboarding: true)
        inert.noteEntrySaved(.feeding)
        inert.notePendingPurchase(.yearly)
        await inert.appBecameActive()
        XCTAssertTrue(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true,
                      "wrote: \(defaults.persistentDomain(forName: suiteName) ?? [:])")
        XCTAssertTrue(countedDays.isEmpty)
        XCTAssertEqual(widgetProbeCalls, 0)
    }

    // MARK: - Opt-out

    func testDefaultIsOnAndStartTellsTheBackend() {
        let analytics = makeFacade()
        XCTAssertTrue(analytics.isEnabled)
        start(analytics)
        XCTAssertEqual(spy.optOutCalls, [false])
    }

    func testOptOutStopsSendsAndOptInResumesThem() {
        let analytics = makeFacade()
        start(analytics)

        analytics.setEnabled(false)
        XCTAssertEqual(spy.optOutCalls.last, true)
        analytics.track(.paywallShown(.settings))
        analytics.noteEntrySaved(.feeding)
        analytics.track(.reviewPromptRequested)
        XCTAssertTrue(spy.sent.isEmpty, "sent while opted out: \(spy.names)")

        analytics.setEnabled(true)
        XCTAssertEqual(spy.optOutCalls.last, false)
        analytics.track(.reviewPromptRequested)
        XCTAssertEqual(spy.names, ["review_prompt_requested"])
    }

    func testAStoredOptOutIsHonouredAtLaunch() {
        defaults.set(false, forKey: Analytics.enabledKey)
        let analytics = makeFacade()
        start(analytics, hasCompletedOnboarding: true)
        XCTAssertEqual(spy.optOutCalls, [true])
        analytics.track(.onboardingPageViewed(.welcome))
        XCTAssertTrue(spy.sent.isEmpty)
    }

    /// Opted out at launch → the SDK object is never created, which is what
    /// keeps even its remote-config request from happening.
    func testAmplitudeBackendIsNeverConstructedForAnOptedOutLaunch() {
        defaults.set(false, forKey: Analytics.enabledKey)
        let backend = AmplitudeAnalyticsBackend(apiKey: "not-a-real-key")
        let analytics = makeFacade(backend: backend)
        start(analytics, hasCompletedOnboarding: true)
        analytics.track(.reviewPromptRequested)
        analytics.noteEntrySaved(.sleep)
        XCTAssertFalse(backend.hasConstructedSDK)
    }

    /// A child view's first event can land before the app root's `start`.
    func testAnEventBeforeStartStillTellsTheBackendTheChoiceFirst() {
        let analytics = makeFacade()
        analytics.track(.onboardingPageViewed(.welcome))
        start(analytics)
        XCTAssertEqual(spy.optOutCalls, [false], "told once, before the send")
        XCTAssertEqual(spy.names, ["onboarding_page_viewed"])
    }

    // MARK: - Payload

    func testEveryEventCarriesTheBuildChannel() {
        let analytics = makeFacade(channel: .testflight)
        start(analytics)
        analytics.track(.widgetInstalled)
        analytics.noteEntrySaved(.growth)
        XCTAssertEqual(spy.sent.count, 2)
        for payload in spy.sent {
            XCTAssertEqual(payload.properties["build_channel"], .token(AnalyticsEvent.BuildChannel.testflight))
        }
    }

    // MARK: - First entry

    func testFirstEntryIsReportedOncePerKindAndNothingPerEntry() {
        let analytics = makeFacade()
        start(analytics)
        analytics.noteEntrySaved(.feeding)
        analytics.noteEntrySaved(.feeding)
        analytics.noteEntrySaved(.sleep)
        analytics.noteEntrySaved(.feeding)
        XCTAssertEqual(spy.names, ["first_entry", "first_entry"])
        XCTAssertEqual(spy.sent[0].properties["kind"], .token(AnalyticsEvent.EntryKind.feeding))
        XCTAssertEqual(spy.sent[1].properties["kind"], .token(AnalyticsEvent.EntryKind.sleep))
    }

    func testAnInstallFromBeforeAnalyticsReportsNoFirsts() {
        let analytics = makeFacade()
        start(analytics, hasCompletedOnboarding: true)
        analytics.noteEntrySaved(.diaper)
        XCTAssertTrue(spy.sent.isEmpty)
    }

    func testAKindLoggedWhileOptedOutIsNotAFirstLater() {
        let analytics = makeFacade()
        start(analytics)
        analytics.setEnabled(false)
        analytics.noteEntrySaved(.event)
        analytics.setEnabled(true)
        analytics.noteEntrySaved(.event)
        XCTAssertTrue(spy.sent.isEmpty)
    }

    // MARK: - Daily activity

    func testTheFirstLaunchReportsNoDayAndTheNextDayReportsYesterday() async {
        let analytics = makeFacade()
        start(analytics)
        await analytics.appBecameActive()
        XCTAssertTrue(spy.sent.isEmpty, "no earlier day to speak for")
        XCTAssertTrue(countedDays.isEmpty)

        advance(days: 1)
        await analytics.appBecameActive()
        XCTAssertEqual(spy.names, ["daily_activity"])
        let today = calendar.startOfDay(for: now)
        XCTAssertEqual(countedDays, [DateInterval(start: calendar.date(byAdding: .day, value: -1, to: today)!,
                                                  end: today)],
                       "the whole PREVIOUS local day, and only it")
        let payload = spy.sent[0]
        XCTAssertEqual(payload.properties["feeding"], .bool(true))
        XCTAssertEqual(payload.properties["sleep"], .bool(true))
        XCTAssertEqual(payload.properties["diaper"], .bool(true))
        XCTAssertEqual(payload.properties["growth"], .bool(true))
        XCTAssertEqual(payload.properties["event"], .bool(false))
        XCTAssertEqual(payload.properties["total"], .token(AnalyticsEvent.TotalBucket.sixteenPlus))
        // Noon of the REPORTED day, local — not the moment of the first open.
        let reportedDay = calendar.date(byAdding: .day, value: -1, to: today)!
        XCTAssertEqual(payload.timestamp, calendar.date(bySettingHour: 12, minute: 0, second: 0, of: reportedDay))
        XCTAssertTrue(payload.outsideSession)
    }

    func testTheDayIsReportedOnceHoweverOftenTheAppComesBack() async {
        let analytics = makeFacade()
        start(analytics)
        advance(days: 1)
        await analytics.appBecameActive()
        await analytics.appBecameActive()
        start(analytics)   // a second onAppear of the app root
        XCTAssertEqual(spy.names, ["daily_activity"])
    }

    /// A launch can land before `start` hands over the counter; the day must
    /// not be marked done then, or it is lost.
    func testAForegroundingBeforeStartDoesNotSpendTheDay() async {
        let analytics = makeFacade()
        start(analytics)
        advance(days: 1)
        let relaunched = makeFacade()      // same defaults, a new process
        await relaunched.appBecameActive() // before its start
        XCTAssertTrue(spy.sent.isEmpty)
        start(relaunched)
        XCTAssertEqual(spy.names, ["daily_activity"])
    }

    /// A marker in the future — the clock moved back, or the simulator's
    /// day-offset hook — is pulled back to today without sending, and the
    /// real next day still reports.
    func testAFutureDayMarkerIsResetToTodayWithoutSending() async {
        let analytics = makeFacade()
        start(analytics)
        advance(days: 2)
        await analytics.appBecameActive()
        XCTAssertEqual(spy.names, ["daily_activity"])
        advance(days: -2)
        await analytics.appBecameActive()
        XCTAssertEqual(spy.names, ["daily_activity"], "nothing for the future marker")
        XCTAssertEqual(defaults.object(forKey: Analytics.dailyActivityDayKey) as? Date,
                       calendar.startOfDay(for: now))
        advance(days: 1)
        await analytics.appBecameActive()
        XCTAssertEqual(spy.names, ["daily_activity", "daily_activity"])
    }

    func testNoBabyOrOptedOutSendsNoDayButStillSpendsIt() async {
        let analytics = makeFacade()
        start(analytics)

        dayCounts = nil
        advance(days: 1)
        await analytics.appBecameActive()

        dayCounts = AnalyticsEvent.DayCounts(feeding: 1, sleep: 0, diaper: 0, growth: 0, event: 0)
        analytics.setEnabled(false)
        advance(days: 1)
        await analytics.appBecameActive()
        analytics.setEnabled(true)
        await analytics.appBecameActive()   // same day: no back-fill
        XCTAssertTrue(spy.sent.isEmpty, "sent: \(spy.names)")
    }

    // MARK: - Widget

    func testWidgetInstalledIsReportedOnce() async {
        widgetPresent = true
        let analytics = makeFacade()
        start(analytics, hasCompletedOnboarding: true)
        await analytics.appBecameActive()
        advance(days: 1)
        await analytics.appBecameActive()
        XCTAssertEqual(spy.names.filter { $0 == "widget_installed" }, ["widget_installed"])
        XCTAssertEqual(widgetProbeCalls, 1, "stops asking WidgetKit once reported")
    }

    func testWidgetKitIsAskedAtMostOnceADay() async {
        let analytics = makeFacade()
        start(analytics, hasCompletedOnboarding: true)
        await analytics.appBecameActive()
        await analytics.appBecameActive()
        XCTAssertEqual(widgetProbeCalls, 1)
        widgetPresent = true
        await analytics.appBecameActive()
        XCTAssertFalse(spy.names.contains("widget_installed"), "same day: not asked again")
        advance(days: 1)
        await analytics.appBecameActive()
        XCTAssertEqual(widgetProbeCalls, 2)
        XCTAssertTrue(spy.names.contains("widget_installed"))
    }

    func testAFutureWidgetProbeDayIsResetUnprobed() async {
        let analytics = makeFacade()
        start(analytics, hasCompletedOnboarding: true)
        advance(days: 3)
        await analytics.appBecameActive()
        advance(days: -3)
        widgetPresent = true
        await analytics.appBecameActive()
        XCTAssertEqual(widgetProbeCalls, 1, "a future probe day is not a reason to ask again")
        XCTAssertEqual(defaults.object(forKey: Analytics.widgetProbeDayKey) as? Date,
                       calendar.startOfDay(for: now))
        advance(days: 1)
        await analytics.appBecameActive()
        XCTAssertEqual(widgetProbeCalls, 2)
    }

    func testWidgetIsNotProbedWhileOptedOut() async {
        widgetPresent = true
        let analytics = makeFacade()
        start(analytics)
        analytics.setEnabled(false)
        await analytics.appBecameActive()
        XCTAssertEqual(widgetProbeCalls, 0)
        XCTAssertFalse(defaults.bool(forKey: Analytics.widgetReportedKey),
                       "a later opt-in must still report the widget")
    }

    // MARK: - History lock

    func testTheHistoryLockIsReportedOncePerSurfacePerDay() {
        let analytics = makeFacade()
        start(analytics)
        analytics.noteHistoryLockShown(.feeding)
        analytics.noteHistoryLockShown(.feeding)
        analytics.noteHistoryLockShown(.events)
        advance(days: 1)
        analytics.noteHistoryLockShown(.feeding)
        XCTAssertEqual(spy.sent.map { $0.properties["surface"] },
                       [.token(AnalyticsEvent.HistorySurface.feeding), .token(AnalyticsEvent.HistorySurface.events),
                        .token(AnalyticsEvent.HistorySurface.feeding)] as [AnalyticsValue?])
    }

    // MARK: - Ask to Buy

    func testAnApprovedAskToBuyReportsSuccessExactlyOnce() {
        let analytics = makeFacade()
        start(analytics)
        analytics.notePendingPurchase(.yearly)
        advance(days: 1)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.yearlyID, purchaseDate: now, isOwnPurchase: true)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.yearlyID, purchaseDate: now, isOwnPurchase: true)
        XCTAssertEqual(spy.names, ["purchase_result"])
        XCTAssertEqual(spy.sent[0].properties["plan"], .token(AnalyticsEvent.Plan.yearly))
        XCTAssertEqual(spy.sent[0].properties["result"], .token(AnalyticsEvent.PurchaseOutcome.success))
    }

    /// Only the parent's own purchase, made after the plan went pending, may
    /// answer a pending marker; a restore, like a new attempt, clears it.
    func testAStaleSharedOrClearedMarkerReportsNothing() {
        let analytics = makeFacade()
        start(analytics)
        let before = now.addingTimeInterval(-60)
        analytics.notePendingPurchase(.weekly)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.monthlyID, purchaseDate: now, isOwnPurchase: true)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.weeklyID, purchaseDate: before, isOwnPurchase: true)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.weeklyID, purchaseDate: now, isOwnPurchase: false)
        analytics.clearPendingPurchases()   // what restorePurchases() and purchase(_:) do first
        analytics.resolvePendingPurchase(productID: SubscriptionManager.weeklyID, purchaseDate: now, isOwnPurchase: true)
        XCTAssertTrue(spy.sent.isEmpty, "sent: \(spy.names)")
    }

    // MARK: - A backend that cannot send

    /// The setting is back ON but the backend was retired by an opt-out
    /// earlier in the session: nothing is sent, and no once-only marker is
    /// spent — every one of them still fires once the backend can send.
    func testARetiredBackendBurnsNoOnceOnlyMarker() async {
        widgetPresent = true
        let analytics = makeFacade()
        start(analytics)
        analytics.notePendingPurchase(.monthly)
        spy.canSend = false
        advance(days: 1)

        analytics.noteEntrySaved(.feeding)
        analytics.noteHistoryLockShown(.sleep)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.monthlyID, purchaseDate: now, isOwnPurchase: true)
        await analytics.appBecameActive()
        XCTAssertTrue(spy.sent.isEmpty)
        XCTAssertEqual(widgetProbeCalls, 0)

        spy.canSend = true   // the next launch's fresh SDK
        analytics.noteEntrySaved(.feeding)
        analytics.noteHistoryLockShown(.sleep)
        analytics.resolvePendingPurchase(productID: SubscriptionManager.monthlyID, purchaseDate: now, isOwnPurchase: true)
        await analytics.appBecameActive()
        XCTAssertEqual(Set(spy.names), ["first_entry", "history_lock_shown", "purchase_result",
                                        "daily_activity", "widget_installed"])
        XCTAssertEqual(spy.sent.count, 5)
    }
}

/// `daily_activity`'s source, against an in-memory store.
@MainActor
final class DailyActivityCounterTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                             DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    func testCountsOnlyThatDayPerKindAndNothingWithoutABaby() throws {
        let context = try makeContext()
        let day = DateInterval(start: Date(timeIntervalSince1970: 1_790_000_000), duration: 86_400)
        let inside = day.start.addingTimeInterval(3_600)
        XCTAssertNil(DailyActivityCounter.counts(in: context, over: day), "no baby, no day")

        context.insert(Baby(name: "Test", birthDate: day.start, gender: .female, feedingType: .breast))
        for _ in 0..<8 { context.insert(FeedingEntry(startTime: inside, type: .formula, side: nil, volumeML: 90)) }
        context.insert(FeedingEntry(startTime: day.end, type: .breast, side: .left, volumeML: nil)) // next day
        context.insert(SleepEntry(startTime: inside, type: .nap))
        context.insert(DiaperEntry(time: day.start.addingTimeInterval(-1), type: .wet))           // day before
        context.insert(GrowthEntry(date: inside, weightKg: 4.1, heightCm: nil, headCircumferenceCm: nil))
        try context.save()

        XCTAssertEqual(DailyActivityCounter.counts(in: context, over: day),
                       AnalyticsEvent.DayCounts(feeding: 8, sleep: 1, diaper: 0, growth: 1, event: 0))
    }
}

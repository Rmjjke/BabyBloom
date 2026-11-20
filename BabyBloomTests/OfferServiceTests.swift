import XCTest
import SwiftData
@testable import BabyBloom

/// The parts around the pure rule: the two copies of the ledger, the cohort
/// flag, the facts read from the store, and what the service records.
@MainActor
final class OfferServiceTests: XCTestCase {

    private final class MemoryVault: OfferLedgerVault {
        var data: Data?
        func read() -> Data? { data }
        func write(_ data: Data) { self.data = data }
        func delete() { data = nil }
    }

    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "offer-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private let calendar = Calendar.autoupdatingCurrent

    private func at(_ day: Int, _ hour: Int = 12) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let date = calendar.date(byAdding: .day, value: day, to: start)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    private func encoded(_ ledger: OfferLedger) -> Data { try! JSONEncoder().encode(ledger) }

    // MARK: - Store

    func testLoadMergesBothCopiesAndBringsThemLevel() throws {
        var local = OfferLedger.empty
        local.recordShown(.firstResultDays, now: at(3))
        var kept = OfferLedger.empty
        kept.recordShown(.firstWeek, now: at(9))
        let vault = MemoryVault()
        vault.data = encoded(kept)
        defaults.set(encoded(local), forKey: OfferLedgerStore.defaultsKey)

        let ledger = OfferLedgerStore(defaults: defaults, keychain: vault).load()
        XCTAssertNotNil(ledger.shownAt(.firstResult))
        XCTAssertNotNil(ledger.shownAt(.firstWeek))
        let both = [vault.data, defaults.data(forKey: OfferLedgerStore.defaultsKey)]
            .map { try? JSONDecoder().decode(OfferLedger.self, from: $0 ?? Data()) }
        XCTAssertEqual(both, [ledger, ledger], "both copies hold the merged ledger")
    }

    func testAReinstallReadsTheKeychainCopy() {
        var shown = OfferLedger.empty
        shown.recordShown(.historyEdge, now: at(16))
        let vault = MemoryVault()
        vault.data = encoded(shown)
        // A fresh install: UserDefaults is empty, the Keychain item survived.
        let ledger = OfferLedgerStore(defaults: defaults, keychain: vault).load()
        XCTAssertEqual(ledger, shown)
        XCTAssertNotNil(defaults.data(forKey: OfferLedgerStore.defaultsKey))
    }

    func testAnUnreadableCopyCountsAsAbsentAndResetEmptiesBoth() {
        let vault = MemoryVault()
        vault.data = Data("not json".utf8)
        let store = OfferLedgerStore(defaults: defaults, keychain: vault)
        XCTAssertEqual(store.load(), .empty)

        var ledger = OfferLedger.empty
        ledger.recordShown(.firstWeek, now: at(9))
        store.save(ledger)
        store.reset()
        XCTAssertNil(vault.data)
        XCTAssertNil(defaults.data(forKey: OfferLedgerStore.defaultsKey))
        XCTAssertEqual(store.load(), .empty)
    }

    func testTheKeychainItemRoundTrips() {
        let vault = KeychainLedgerVault(service: "com.nenita.app.offer.tests", account: UUID().uuidString)
        defer { vault.delete() }
        XCTAssertNil(vault.read())
        vault.write(Data("one".utf8))
        vault.write(Data("two".utf8))
        XCTAssertEqual(vault.read(), Data("two".utf8), "a second write updates the item")
        vault.delete()
        XCTAssertNil(vault.read())
    }

    // MARK: - Cohort

    func testTheCohortIsWrittenOnceAtTheFirstLaunch() {
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: at(20), defaults: defaults)
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: at(25), defaults: defaults)
        XCTAssertEqual(OfferCohort.current(defaults: defaults, now: at(30)), .beforeOffers(launchAt: at(20)))
    }

    func testAnInstallThatOnboardsWithOffersIsNew() {
        OfferCohort.recordIfNeeded(onboardingCompleted: false, now: at(0), defaults: defaults)
        // Completing onboarding later does not make it an older install.
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: at(1), defaults: defaults)
        XCTAssertEqual(OfferCohort.current(defaults: defaults, now: at(2)), .new)
    }

    // MARK: - Facts from the store

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        addTeardownBlock { _ = container }
        return context
    }

    @discardableResult
    private func insertBaby(_ context: ModelContext, birthWeightKg: Double? = 3.5) -> Baby {
        let baby = Baby(name: "Mia", birthDate: at(0, 6), gender: .female, feedingType: .breast)
        baby.birthWeightKg = birthWeightKg
        baby.createdAt = at(0, 9)
        context.insert(baby)
        return baby
    }

    private func insertWeighing(_ context: ModelContext, kg: Double, day: Int, createdAt: Date) {
        let entry = GrowthEntry(date: at(day, 10), weightKg: kg)
        entry.createdAt = createdAt
        context.insert(entry)
    }

    func testNoBabyMeansNoFacts() throws {
        let facts = OfferRule.Facts.load(in: try makeContext(), onboardingEndedAt: nil, now: at(5))
        XCTAssertNil(facts.onboardingEndedAt)
    }

    func testOnboardingEndFallsBackToAMinuteAfterTheBaby() throws {
        let context = try makeContext()
        insertBaby(context)
        XCTAssertEqual(OfferRule.Facts.load(in: context, onboardingEndedAt: nil, now: at(5)).onboardingEndedAt,
                       at(0, 9).addingTimeInterval(60))
        XCTAssertEqual(OfferRule.Facts.load(in: context, onboardingEndedAt: at(0, 10), now: at(5)).onboardingEndedAt,
                       at(0, 10))
    }

    func testRecordsOfEveryKindAreRead() throws {
        let context = try makeContext()
        insertBaby(context)
        context.insert(FeedingEntry(startTime: at(1), type: .breast))
        context.insert(SleepEntry(startTime: at(2), type: .nap))
        context.insert(DiaperEntry(time: at(3), type: .wet))
        context.insert(CustomEvent(time: at(4), type: .bath))
        let facts = OfferRule.Facts.load(in: context, onboardingEndedAt: at(0, 10), now: at(5))
        XCTAssertEqual(Set(facts.records.map(\.date)), [at(1), at(2), at(3), at(4)])
    }

    func testAWeighingIsFlaggedByTheBlockersStandingRightAfterIt() throws {
        let context = try makeContext()
        insertBaby(context)
        let ended = at(0, 10)
        // Onboarding's birth weight: before the line, never judged.
        insertWeighing(context, kg: 3.5, day: 0, createdAt: at(0, 9))
        insertWeighing(context, kg: 3.4, day: 3, createdAt: at(3, 11))   // 97 %: clean
        insertWeighing(context, kg: 3.0, day: 5, createdAt: at(5, 11))   // 86 %: over 10 % lost
        let facts = OfferRule.Facts.load(in: context, onboardingEndedAt: ended, now: at(5, 12))
        let byDay = Dictionary(uniqueKeysWithValues: facts.weighings.map { (calendar.component(.day, from: $0.date), $0.flagged) })
        XCTAssertEqual(byDay, [2: false, 5: false, 7: true])
        XCTAssertTrue(facts.clinicalBlocked)
    }

    // MARK: - Service

    private final class Clock { var now: Date; init(_ now: Date) { self.now = now } }

    private func makeService(clock: Clock, events: @escaping @MainActor (AnalyticsEvent) -> Void) -> OfferService {
        OfferService(store: OfferLedgerStore(defaults: defaults, keychain: MemoryVault()),
                     defaults: defaults, calendar: calendar, clock: { clock.now }, track: events)
    }

    func testShownIsReportedOnceAndCloseAndTapAreReported() {
        let clock = Clock(at(3))
        var events: [AnalyticsEvent] = []
        let service = makeService(clock: clock) { events.append($0) }
        service.recordShown(.firstResultDays)
        service.recordShown(.firstResultDays)
        service.recordClosed(.firstResultDays)
        clock.now = at(10)
        service.recordShown(.firstWeek)
        service.recordTapped(.firstWeek)
        XCTAssertEqual(events, [.offerShown(.firstResultDays), .offerClosed(.firstResultDays, expired: false),
                                .offerShown(.firstWeek), .offerTapped(.firstWeek)])
        XCTAssertEqual(service.ledger.closesInRow, 0)
    }

    func testACardWhoseDaysRanOutIsReportedAsExpired() throws {
        let clock = Clock(at(3, 20))
        var events: [AnalyticsEvent] = []
        let service = makeService(clock: clock) { events.append($0) }
        service.recordShown(.firstResultDays)
        clock.now = at(6, 8)
        let decision = service.evaluate(in: try makeContext(), isPremium: false, entitlementsResolved: true,
                                        situation: .calm)
        XCTAssertEqual(events.last, .offerClosed(.firstResultDays, expired: true))
        XCTAssertNil(service.ledger.open)
        XCTAssertEqual(service.ledger.closesInRow, 1)
        XCTAssertEqual(decision, .wait(.notDue))
    }

    func testAnOlderInstallSpendsWhatWasTrueAtItsLaunchWhileItIsQuiet() throws {
        let context = try makeContext()
        insertBaby(context)
        OnboardingEnd.record(now: at(0, 10), defaults: defaults)
        for day in 1...8 {
            let feed = FeedingEntry(startTime: at(day), type: .breast)
            feed.createdAt = at(day)
            context.insert(feed)
        }
        OfferCohort.recordIfNeeded(onboardingCompleted: true, now: at(20), defaults: defaults)
        let service = makeService(clock: Clock(at(21))) { _ in }
        let decision = service.evaluate(in: context, isPremium: false, entitlementsResolved: true, situation: .calm)
        XCTAssertEqual(decision, .hold(.cohortQuiet))
        XCTAssertEqual(service.ledger.spentAt(.firstResult), at(20))
        XCTAssertEqual(service.ledger.spentAt(.firstWeek), at(20))
        // The oldest record was 19 days old at the launch: past the free window.
        XCTAssertEqual(service.ledger.spentAt(.historyEdge), at(20))
        XCTAssertNil(service.ledger.spentAt(.monthReport), "20 days after onboarding: not yet a month")
        XCTAssertNil(service.ledger.shownAt(.firstResult), "spent, never shown")
        XCTAssertTrue(service.ledger.cohortSpent)
    }

    func testASubscriberIsNotedAndHeld() throws {
        let service = makeService(clock: Clock(at(40))) { _ in }
        let decision = service.evaluate(in: try makeContext(), isPremium: true, entitlementsResolved: true,
                                        situation: .calm)
        XCTAssertEqual(decision, .hold(.premium))
        XCTAssertEqual(service.ledger.lastSeenPremiumAt, at(40))
    }

    // MARK: - Analytics

    func testThePaywallNamesTheOfferCardOnlyFromTheOfferSource() {
        let fromOffer = AnalyticsEvent.paywallShown(.offer, offer: .monthReport).payload(channel: .simulator)
        XCTAssertEqual(fromOffer.properties["content"], .token(OfferContent.monthReport))
        let elsewhere = AnalyticsEvent.paywallShown(.settings, offer: .monthReport).payload(channel: .simulator)
        XCTAssertNil(elsewhere.properties["content"])
    }

    func testThePaywallNamesTheTrackerOnlyFromTheWeeklyChartSource() {
        let fromChart = AnalyticsEvent.paywallShown(.weeklyChart, tracker: .sleep).payload(channel: .simulator)
        XCTAssertEqual(fromChart.properties["source"], .token(AnalyticsEvent.PaywallSource.weeklyChart))
        XCTAssertEqual(fromChart.properties["tracker"], .token(AnalyticsEvent.ChartTracker.sleep))
        XCTAssertNil(fromChart.properties["content"])
        let elsewhere = AnalyticsEvent.paywallShown(.historyLock, tracker: .sleep).payload(channel: .simulator)
        XCTAssertNil(elsewhere.properties["tracker"])
    }
}

import XCTest
import SwiftData
@testable import BabyBloom

/// Home's offer slot: what it draws after an evaluation, what × / a hold / a
/// tap record, the rating's silence after a card, the subscription mark from
/// the app's root, and the live parts of Home's situation.
@MainActor
final class OfferCardSlotTests: XCTestCase {

    private final class MemoryVault: OfferLedgerVault {
        var data: Data?
        func read() -> Data? { data }
        func write(_ data: Data) { self.data = data }
        func delete() { data = nil }
    }

    private final class Clock { var now: Date; init(_ now: Date) { self.now = now } }

    private var defaults: UserDefaults!
    private var suite: String!
    private let vault = MemoryVault()
    private let calendar = Calendar.autoupdatingCurrent
    private var events: [AnalyticsEvent] = []

    override func setUp() {
        super.setUp()
        suite = "offer-slot-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        events = []
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func at(_ day: Int, _ hour: Int = 12) -> Date {
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let date = calendar.date(byAdding: .day, value: day, to: start)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    /// One service per "launch": both share the ledger's two copies, as a
    /// relaunch does.
    private func makeService(_ clock: Clock) -> OfferService {
        OfferService(store: OfferLedgerStore(defaults: defaults, keychain: vault), defaults: defaults,
                     calendar: calendar, clock: { clock.now }, track: { [unowned self] in events.append($0) })
    }

    private func makeReview() -> ReviewPromptService { ReviewPromptService(defaults: defaults) }

    /// A new install whose onboarding ended on day 0 and has records on days
    /// 0–2: the first result (days) is due on day 2.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        context.autosaveEnabled = false
        addTeardownBlock { _ = container }
        OfferCohort.recordIfNeeded(onboardingCompleted: false, now: at(0, 8), defaults: defaults)
        OnboardingEnd.record(now: at(0, 10), defaults: defaults)
        let baby = Baby(name: "Mia", birthDate: at(0, 6), gender: .female, feedingType: .breast)
        baby.createdAt = at(0, 9)
        context.insert(baby)
        for day in 0...2 { context.insert(FeedingEntry(startTime: at(day, 14), type: .breast)) }
        return context
    }

    private func evaluate(_ slot: OfferSlotState, _ context: ModelContext, premium: Bool = false,
                          situation: OfferRule.Situation = .calm) {
        slot.evaluate(in: context, isPremium: premium, entitlementsResolved: true, situation: situation)
    }

    // MARK: - Evaluation

    func testADueMomentDrawsItsCardOnceAndSilencesTheRating() throws {
        let context = try makeContext()
        let clock = Clock(at(2, 18))
        let review = makeReview()
        let slot = OfferSlotState(service: makeService(clock), review: review)
        evaluate(slot, context)
        XCTAssertEqual(slot.content, .firstResultDays)
        XCTAssertTrue(review.suppressedForSession)
        evaluate(slot, context)   // Home appears again: the same card, not reported twice
        XCTAssertEqual(slot.content, .firstResultDays)
        XCTAssertEqual(events, [.offerShown(.firstResultDays)])
    }

    func testASubscriberOrAHoldDrawsNothingAndKeepsTheRating() throws {
        let context = try makeContext()
        let clock = Clock(at(2, 18))
        for (premium, situation) in [(true, OfferRule.Situation.calm),
                                     (false, OfferRule.Situation(sheetOpen: true)),
                                     (false, OfferRule.Situation(medicationDue: true)),
                                     (false, OfferRule.Situation(launchedFromNotification: true))] {
            let review = makeReview()
            let slot = OfferSlotState(service: makeService(clock), review: review)
            evaluate(slot, context, premium: premium, situation: situation)
            XCTAssertNil(slot.content, "premium \(premium), \(situation)")
            XCTAssertFalse(review.suppressedForSession)
        }
        XCTAssertFalse(events.contains(.offerShown(.firstResultDays)))
    }

    func testAfterARatingAskNoCardShowsInTheProcessAndNothingIsSpent() throws {
        let context = try makeContext()
        let clock = Clock(at(2, 18))
        let review = makeReview()
        review.noteAskedThisSession()
        let service = makeService(clock)
        let slot = OfferSlotState(service: service, review: review)
        evaluate(slot, context)
        XCTAssertNil(slot.content)
        XCTAssertNil(service.ledger.lastShownAt)
        XCTAssertFalse(makeReview().askedThisSession, "a new process may show it")
        let relaunched = OfferSlotState(service: makeService(clock), review: makeReview())
        evaluate(relaunched, context)
        XCTAssertEqual(relaunched.content, .firstResultDays, "the moment was kept for the next visit")
        XCTAssertEqual(events, [.offerShown(.firstResultDays)])
    }

    // MARK: - ×

    func testAClosedCardStaysClosedAlsoAfterARelaunch() throws {
        let context = try makeContext()
        let clock = Clock(at(2, 18))
        let slot = OfferSlotState(service: makeService(clock), review: makeReview())
        evaluate(slot, context)
        slot.close(reduceMotion: false)
        XCTAssertNil(slot.content)
        evaluate(slot, context)
        XCTAssertNil(slot.content, "the same visit")

        clock.now = at(3, 9)
        let relaunched = OfferSlotState(service: makeService(clock), review: makeReview())
        evaluate(relaunched, context)
        XCTAssertNil(relaunched.content, "a relaunch reads the close from the ledger")
        XCTAssertEqual(events, [.offerShown(.firstResultDays), .offerClosed(.firstResultDays, expired: false)])
    }

    func testWithReduceMotionTheCardFadesInPlaceBeforeItGoes() async throws {
        let context = try makeContext()
        let slot = OfferSlotState(service: makeService(Clock(at(2, 18))), review: makeReview())
        evaluate(slot, context)
        slot.close(reduceMotion: true)
        XCTAssertTrue(slot.fadingOut)
        XCTAssertEqual(slot.content, .firstResultDays, "still in the stack: nothing below it moves")
        slot.close(reduceMotion: true)   // a second tap during the fade records nothing
        try await Task.sleep(for: .seconds(0.5))
        XCTAssertNil(slot.content)
        XCTAssertFalse(slot.fadingOut)
        XCTAssertEqual(events.filter { if case .offerClosed = $0 { return true } else { return false } }.count, 1)
    }

    // MARK: - Holds

    func testAHoldTakesTheCardAwaySpendingNothingAndItComesBackAtTheNextAppear() throws {
        let context = try makeContext()
        let service = makeService(Clock(at(2, 18)))
        let slot = OfferSlotState(service: service, review: makeReview())
        evaluate(slot, context)
        slot.hold(reduceMotion: true)
        XCTAssertNil(slot.content)
        XCTAssertEqual(service.ledger.closesInRow, 0)
        evaluate(slot, context)
        XCTAssertEqual(slot.content, .firstResultDays, "the open card continues")
        XCTAssertEqual(events, [.offerShown(.firstResultDays)], "neither the hold nor the return is reported")
    }

    // MARK: - Tap

    func testTheCardStaysUnderItsPaywallAndLeavesWhenItCloses() throws {
        let context = try makeContext()
        let slot = OfferSlotState(service: makeService(Clock(at(2, 18))), review: makeReview())
        evaluate(slot, context)
        slot.tap()
        slot.hold(reduceMotion: false)   // the paywall is a sheet: not a hold for its own card
        evaluate(slot, context, situation: OfferRule.Situation(sheetOpen: true))
        XCTAssertEqual(slot.content, .firstResultDays)
        slot.paywallClosed()
        XCTAssertNil(slot.content)
        evaluate(slot, context)
        XCTAssertNil(slot.content, "a tapped card is done for its moment")
        XCTAssertEqual(events, [.offerShown(.firstResultDays), .offerTapped(.firstResultDays)])
    }

    // MARK: - The rating

    func testAfterACardTheRatingIsSilentForTheProcess() throws {
        let review = makeReview()
        review.noteEntrySaved()
        XCTAssertTrue(review.hasPendingSave)
        review.suppressForSession()
        XCTAssertFalse(review.hasPendingSave, "a save waiting for its sheet is dropped")
        review.noteEntrySaved()
        XCTAssertFalse(review.hasPendingSave)
        XCTAssertFalse(review.consumePendingSave(in: try makeContext(), transactionFailedThisSession: false))
        XCTAssertFalse(makeReview().suppressedForSession, "a new process asks again")
    }

    // MARK: - The subscription mark

    func testTheRootWritesTheMarkOnlyForAResolvedSubscriberAndOnceADay() {
        let clock = Clock(at(4, 9))
        let service = makeService(clock)
        service.noteAccount(isPremium: true, resolved: false)
        service.noteAccount(isPremium: false, resolved: true)
        XCTAssertNil(service.ledger.lastSeenPremiumAt)
        service.noteAccount(isPremium: true, resolved: true)
        XCTAssertEqual(service.ledger.lastSeenPremiumAt, at(4, 9))
        clock.now = at(4, 20)
        service.noteAccount(isPremium: true, resolved: true)
        XCTAssertEqual(service.ledger.lastSeenPremiumAt, at(4, 9), "one write a day")
        // A later launch as a free user still reads it: the weekly charts'
        // reason line is for people who never subscribed.
        XCTAssertNotNil(makeService(Clock(at(40))).ledger.lastSeenPremiumAt)
        XCTAssertEqual(events, [])
    }

    // MARK: - Home's situation

    func testOnlyMedicationNotificationAndSheetAreLiveHolds() {
        XCTAssertFalse(OfferRule.Situation.calm.holdsLive)
        XCTAssertFalse(OfferRule.Situation(weeklyCardNew: true).holdsLive, "the turnover cannot start mid-visit")
        XCTAssertTrue(OfferRule.Situation(medicationDue: true).holdsLive)
        XCTAssertTrue(OfferRule.Situation(launchedFromNotification: true).holdsLive)
        XCTAssertTrue(OfferRule.Situation(sheetOpen: true).holdsLive)
    }

    func testADoseIsDueOnHomeOnceItsIntervalHasPassed() throws {
        let context = try makeContext()
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
        context.insert(medicine)
        XCTAssertFalse(Medicine.doseDueOnHome([medicine], now: at(3, 9)), "no dose yet: not on Home")
        context.insert(CustomEvent.dose(of: medicine, at: at(3, 8)))
        XCTAssertFalse(Medicine.doseDueOnHome([medicine], now: at(3, 13)), "inside the 6 h interval")
        XCTAssertTrue(Medicine.doseDueOnHome([medicine], now: at(3, 14)))
        medicine.endedAt = at(3, 13)
        XCTAssertFalse(Medicine.doseDueOnHome([medicine], now: at(3, 14)), "an ended course")
    }

    func testTheWeeklyCardIsNewOnTheTurnoverDayUnlessHidden() throws {
        let week = WeeklySummary.calendar
        let monday = week.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 9))!
        let input = WeeklySummary.Input(feeds: [week.date(byAdding: .day, value: -3, to: monday)!],
                                        birthDate: at(-30), correctedBirthDate: at(-30), isMale: false)
        let summary = try XCTUnwrap(WeeklySummary.make(now: monday, input: input))
        XCTAssertTrue(WeeklySummary.cardIsNew(summary, hiddenWeek: "", now: monday))
        XCTAssertFalse(WeeklySummary.cardIsNew(summary, hiddenWeek: WeeklySummaryCard.key(of: summary.week), now: monday))
        let tuesday = week.date(byAdding: .day, value: 1, to: monday)!
        XCTAssertFalse(WeeklySummary.cardIsNew(summary, hiddenWeek: "", now: tuesday))
        XCTAssertFalse(WeeklySummary.cardIsNew(nil, hiddenWeek: "", now: monday))
    }
}

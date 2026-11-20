import Foundation
import SwiftData
import os

/// Puts the offer rule together with the store, the ledger and the account,
/// and records what the card did. Home asks `evaluate` what to show and
/// reports the card's appearance, × and tap back.
@MainActor
final class OfferService {

    static let shared = OfferService()

    private let store: OfferLedgerStore
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let clock: () -> Date
    private let track: @MainActor (AnalyticsEvent) -> Void
    private static let log = Logger(subsystem: "com.nenita.app", category: "Offer")

    init(store: OfferLedgerStore = OfferLedgerStore(),
         defaults: UserDefaults = .standard,
         calendar: Calendar = .autoupdatingCurrent,
         clock: @escaping () -> Date = { AppClock.now },
         track: @escaping @MainActor (AnalyticsEvent) -> Void = { Analytics.shared.track($0) }) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.clock = clock
        self.track = track
    }

    var ledger: OfferLedger { store.load() }

    /// What Home may show now. Brings the ledger up to date first: a card
    /// whose days ran out is closed (and reported as expired), an older
    /// install's moments already true at its first launch are spent once, and
    /// a subscriber is noted for the former-subscriber pace.
    func evaluate(in context: ModelContext,
                  isPremium: Bool,
                  entitlementsResolved: Bool,
                  situation: OfferRule.Situation) -> OfferRule.Decision {
        let now = clock()
        var ledger = store.load()
        let before = ledger
        let account = OfferRule.Account(isPremium: isPremium,
                                        entitlementsResolved: entitlementsResolved,
                                        cohort: OfferCohort.current(defaults: defaults, now: now))
        let facts = OfferRule.Facts.load(in: context,
                                         onboardingEndedAt: OnboardingEnd.stored(defaults: defaults),
                                         now: now)

        if let expired = ledger.settle(now: now, calendar: calendar) {
            track(.offerClosed(expired, expired: true))
        }
        if case .beforeOffers(let launchAt) = account.cohort, !ledger.cohortSpent {
            ledger.spendAtCohortLaunch(OfferRule.spentAtCohortLaunch(facts: facts, launchAt: launchAt, calendar: calendar),
                                       launchAt: launchAt, now: now)
        }
        if entitlementsResolved && isPremium {
            ledger.notePremium(now: now, calendar: calendar)
        }
        if ledger != before { store.save(ledger) }

        let decision = OfferRule.decide(facts: facts, ledger: ledger, account: account, situation: situation,
                                        now: now, calendar: calendar, forced: Self.forced)
        Self.log.info("Offer decision: \(String(describing: decision), privacy: .public)")
        return decision
    }

    /// Writes the former-subscriber mark as soon as the account is known to
    /// be Premium, from the app's root: a subscriber who never opens Home
    /// before the subscription lapses still counts as a former subscriber.
    func noteAccount(isPremium: Bool, resolved: Bool) {
        guard isPremium && resolved else { return }
        var ledger = store.load()
        guard ledger.notePremium(now: clock(), calendar: calendar) else { return }
        store.save(ledger)
    }

    /// The card appeared. Reported once per card, however often Home redraws.
    func recordShown(_ content: OfferContent) {
        var ledger = store.load()
        let before = ledger
        ledger.recordShown(content, now: clock())
        guard ledger != before else { return }
        store.save(ledger)
        track(.offerShown(content))
    }

    func recordClosed(_ content: OfferContent) {
        var ledger = store.load()
        guard ledger.recordClosed(content, now: clock()) else { return }
        store.save(ledger)
        track(.offerClosed(content, expired: false))
    }

    /// The tap that opens the paywall; the paywall reports its own
    /// `paywall_shown` with the `.offer` source and this content.
    func recordTapped(_ content: OfferContent) {
        var ledger = store.load()
        ledger.recordTapped(content, now: clock())
        store.save(ledger)
        track(.offerTapped(content))
    }

    // MARK: - Simulator levers

    #if targetEnvironment(simulator)
    /// `-BBForceOffer <content>`: that card, skipping the moments and the
    /// pace — never the holds, which are worth seeing hold.
    private static let forced = UserDefaults.standard.string(forKey: "BBForceOffer").flatMap(OfferContent.init(rawValue:))

    /// Runs once at launch. `-BBOfferLedgerReset true` empties both copies;
    /// then a preset, if any of its arguments is given:
    /// `-BBOfferLastShownDaysAgo <n>`, `-BBOfferClosesInRow <k>`,
    /// `-BBOfferShownMoments first_result,first_week`.
    func applyLaunchLevers(arguments: UserDefaults = .standard) {
        if arguments.bool(forKey: "BBOfferLedgerReset") { store.reset() }
        let hasPreset = ["BBOfferLastShownDaysAgo", "BBOfferClosesInRow", "BBOfferShownMoments"]
            .contains { arguments.object(forKey: $0) != nil }
        guard hasPreset else { return }
        let now = clock()
        let lastShown = arguments.object(forKey: "BBOfferLastShownDaysAgo") == nil ? nil
            : calendar.date(byAdding: .day, value: -arguments.integer(forKey: "BBOfferLastShownDaysAgo"), to: now)
        let moments = (arguments.string(forKey: "BBOfferShownMoments") ?? "")
            .split(separator: ",").compactMap { OfferMoment(rawValue: String($0)) }
        store.save(.preset(lastShownAt: lastShown,
                           closesInRow: arguments.integer(forKey: "BBOfferClosesInRow"),
                           shownMoments: moments, now: now))
    }
    #else
    private static let forced: OfferContent? = nil
    #endif
}

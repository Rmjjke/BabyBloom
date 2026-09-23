import Foundation
import OSLog
import SwiftData

/// The stateful half of the review prompt: what `ReviewPromptPolicy` needs
/// remembered across launches (UserDefaults) and within a session (a save that
/// has not been answered yet). The decision itself stays in the pure policy.
@MainActor
final class ReviewPromptService {

    static let shared = ReviewPromptService()

    enum Key {
        static let firstLaunchDate    = "reviewPrompt.firstLaunchDate"
        static let lastRequestVersion = "reviewPrompt.lastRequestVersion"
        static let lastRequestDate    = "reviewPrompt.lastRequestDate"
    }

    private let defaults: UserDefaults
    /// Injected so quiet hours and the day thresholds are testable against a
    /// fixed zone and instant; the app runs on the device's own clock.
    private let calendar: Calendar
    private let clock: () -> Date
    private static let log = Logger(subsystem: "com.nenita.app", category: "ReviewPrompt")

    /// A save that happened inside a sheet and is waiting for that sheet to
    /// go. Process-lifetime on purpose: a pending save must not survive into a
    /// launch, which is one of the moments we never ask in.
    private(set) var hasPendingSave = false

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .autoupdatingCurrent,
         clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.clock = clock
    }

    // MARK: - Persistence

    /// Written once and never moved. An install that predates this feature
    /// starts its three days on the first launch of the version that has it.
    func recordFirstLaunchIfNeeded(now: Date? = nil) {
        guard defaults.object(forKey: Key.firstLaunchDate) == nil else { return }
        defaults.set(now ?? clock(), forKey: Key.firstLaunchDate)
    }

    var firstLaunchDate: Date? { defaults.object(forKey: Key.firstLaunchDate) as? Date }
    var lastRequestVersion: String? { defaults.string(forKey: Key.lastRequestVersion) }
    var lastRequestDate: Date? { defaults.object(forKey: Key.lastRequestDate) as? Date }

    func recordRequest(version: String, at date: Date) {
        defaults.set(version, forKey: Key.lastRequestVersion)
        defaults.set(date, forKey: Key.lastRequestDate)
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: - Session

    func noteEntrySaved() { hasPendingSave = true }

    /// Friction inside a quick sheet cancels the success before it: a parent
    /// who has just declined the paywall is not asked for a rating when they
    /// close the sheet. `PaywallView` calls this on appearing.
    func discardPendingSave() { hasPendingSave = false }

    /// Answers the pending save, once: true means "call `requestReview` now",
    /// and the request has already been recorded. Nothing pending → false, so
    /// a Cancel, a launch or a tab switch can never reach the prompt.
    func consumePendingSave(in context: ModelContext,
                            transactionFailedThisSession: Bool,
                            now: Date? = nil) -> Bool {
        guard hasPendingSave else { return false }
        hasPendingSave = false
        let now = now ?? clock()

        // Thresholds first — quiet hours, counts and dates alone: nearly every
        // save stops here, so the store's babies and weighings are read, and
        // the growth engine run, only when the answer could still be yes.
        // A refusal records nothing, so the version's attempt stays unspent.
        var state = ReviewPromptPolicy.State(
            totalEntries: Self.totalEntries(in: context),
            firstLaunchDate: firstLaunchDate,
            now: now,
            lastRequestVersion: lastRequestVersion,
            lastRequestDate: lastRequestDate,
            currentVersion: Self.currentVersion,
            blockers: .none,
            calendar: calendar
        )
        guard ReviewPromptPolicy.shouldRequest(state: state,
                                               bypassingThresholds: Self.forceOverride) else {
            Self.log.info("Review prompt not requested: thresholds (entries \(state.totalEntries), quiet hours \(ReviewPromptPolicy.isQuietHour(now, calendar: self.calendar))).")
            return false
        }
        state.blockers = Self.blockers(in: context,
                                       transactionFailedThisSession: transactionFailedThisSession,
                                       now: now)
        guard ReviewPromptPolicy.shouldRequest(state: state,
                                               bypassingThresholds: Self.forceOverride) else {
            let b = state.blockers
            Self.log.info("Review prompt not requested: gainBelow \(b.belowReferenceGain), newbornFlag \(b.newbornFlag), failedTransaction \(b.failedTransaction).")
            return false
        }
        recordRequest(version: state.currentVersion, at: now)
        // TODO(TelemetryDeck analytics task): emit `review_prompt_requested`
        // here — the system never says whether it showed anything.
        Self.log.notice("Review prompt requested.")
        return true
    }

    // MARK: - Reading the store

    /// Counted, not fetched: this runs once per save and needs no rows.
    private static func totalEntries(in context: ModelContext) -> Int {
        let counts = [
            try? context.fetchCount(FetchDescriptor<FeedingEntry>()),
            try? context.fetchCount(FetchDescriptor<SleepEntry>()),
            try? context.fetchCount(FetchDescriptor<DiaperEntry>()),
            try? context.fetchCount(FetchDescriptor<GrowthEntry>()),
            try? context.fetchCount(FetchDescriptor<CustomEvent>())
        ]
        return counts.reduce(0) { $0 + ($1 ?? 0) }
    }

    private static func blockers(in context: ModelContext,
                                 transactionFailedThisSession: Bool,
                                 now: Date) -> ReviewPromptPolicy.Blockers {
        var blockers = ReviewPromptPolicy.Blockers.none
        // `babies.first` by creation date, the app's single-baby rule.
        let babies = (try? context.fetch(FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        if let baby = babies.first {
            let growth = (try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? []
            blockers = ReviewPromptPolicy.clinicalBlockers(
                birthDate: baby.birthDate,
                birthWeightKg: baby.birthWeightKg,
                correctedBirthDate: baby.correctedBirthDate,
                isMale: baby.gender == .male,
                measurements: growth.weightMeasurements,
                now: now
            )
        }
        blockers.failedTransaction = transactionFailedThisSession
        return blockers
    }

    // MARK: - Simulator hook

    #if targetEnvironment(simulator)
    /// `-BBForceReviewPrompt true`: skips the thresholds — never the blockers —
    /// so run-and-look can reach the system sheet, which development builds
    /// show on every request. Simulator-gated like the other hooks
    /// (DECISIONS 2026-08-26); harmless on the simulator, but a shipped binary
    /// should not carry a lever that spends the year's three prompts.
    private static let forceOverride = UserDefaults.standard.bool(forKey: "BBForceReviewPrompt")
    #else
    private static let forceOverride = false
    #endif
}

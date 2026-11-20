import Foundation

/// Whether this install finished onboarding before the version with offers,
/// and when that version first launched. One flag, written in one place (the
/// app root's first appearance) and never moved; the offer rule's quiet days
/// and the locked chart's reason line both read it.
enum OfferCohort {

    enum Key {
        static let cohort   = "offer.cohort"
        static let launchAt = "offer.cohortLaunchAt"
    }

    private static let beforeOffers = "pre_1_4_0"
    private static let new = "new"

    /// The first launch with this code decides: onboarding already done means
    /// an install from before offers existed.
    static func recordIfNeeded(onboardingCompleted: Bool, now: Date, defaults: UserDefaults = .standard) {
        guard defaults.string(forKey: Key.cohort) == nil else { return }
        defaults.set(onboardingCompleted ? beforeOffers : new, forKey: Key.cohort)
        defaults.set(now, forKey: Key.launchAt)
    }

    static func current(defaults: UserDefaults = .standard, now: Date) -> OfferRule.Cohort {
        #if targetEnvironment(simulator)
        if let forced = forced(defaults: defaults, now: now) { return forced }
        #endif
        guard defaults.string(forKey: Key.cohort) == beforeOffers,
              let launchAt = defaults.object(forKey: Key.launchAt) as? Date else { return .new }
        return .beforeOffers(launchAt: launchAt)
    }

    #if targetEnvironment(simulator)
    /// `-BBOfferCohort pre|new`, with `-BBOfferCohortLaunchDaysAgo <n>` for
    /// the launch date of `pre` (default 0, today). Read over the stored flag,
    /// never written into it, so the next launch without the lever is the
    /// install's own cohort again.
    private static func forced(defaults: UserDefaults, now: Date) -> OfferRule.Cohort? {
        switch defaults.string(forKey: "BBOfferCohort") {
        case "pre":
            let days = defaults.integer(forKey: "BBOfferCohortLaunchDaysAgo")
            let launchAt = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -days, to: now) ?? now
            return .beforeOffers(launchAt: launchAt)
        case "new":
            return .new
        default:
            return nil
        }
    }
    #endif
}

/// When onboarding ended, the line before which records and weighings are
/// setup rather than the app at work. Written by onboarding's last step.
enum OnboardingEnd {

    static let key = "onboarding.endedAt"

    static func record(now: Date, defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: key)
    }

    static func stored(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    /// Installs that finished onboarding before the key existed have only the
    /// baby, which onboarding's last step creates: a minute after it stands
    /// in, clear of the birth weight saved with it.
    static let fallbackAfterBaby: TimeInterval = 60
}

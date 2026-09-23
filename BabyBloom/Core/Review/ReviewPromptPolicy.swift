import Foundation

/// When the app may ASK iOS for the App Store rating prompt.
///
/// `requestReview` is only a request: the system decides whether anything is
/// shown, caps it at three prompts per app per 365 days, and never reports the
/// outcome. So this policy is not about the prompt — it is about not spending
/// one of those three on the wrong moment. Pure, like `Core/Growth`:
/// persistence lives in `ReviewPromptService`, the call site in
/// `ReviewPromptTrigger`.
///
/// The trigger is a moment of success (an entry just saved, its sheet gone),
/// never a moment of friction — see DECISIONS 2026-09-22.
enum ReviewPromptPolicy {

    /// Logged entries across all five kinds. A parent twenty entries in has
    /// found out what the app is; one on day one has not.
    static let minimumEntries = 20

    /// Elapsed time since the first launch — the novelty glow is not a rating.
    static let minimumDaysSinceFirstLaunch = 3

    /// Spaces requests across versions: a release a fortnight after the last
    /// one does not earn a second ask. It does not keep us under Apple's cap —
    /// once per version plus 90 days still allows up to five requests in a
    /// rolling year, and Apple's three is what binds.
    static let minimumDaysBetweenRequests = 90

    /// Quiet hours, LOCAL time: 22:00 up to 07:00. A night timer stop or save
    /// is when a parent wants the phone gone — a prompt then earns one star or
    /// a blind dismissal, and it would spend this version's attempt. A refusal
    /// records nothing, so the next daytime save that meets the rules asks.
    static let quietHoursStart = 22
    static let quietHoursEnd = 7

    static func isQuietHour(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    /// The calm rule, applied to asking for a rating: an anxious or annoyed
    /// parent is not the moment, and a one-star review for the wrong reason
    /// costs more than a missed prompt.
    struct Blockers: Equatable {
        /// The latest gain verdict reads below its reference.
        var belowReferenceGain = false
        /// A first-weeks flag (>10% loss, not regained by day 14) is up.
        var newbornFlag = false
        /// A purchase or restore failed earlier in this session.
        var failedTransaction = false

        static let none = Blockers()

        var any: Bool { belowReferenceGain || newbornFlag || failedTransaction }
    }

    struct State: Equatable {
        var totalEntries: Int
        /// nil only if the service never ran — treated as "not yet".
        var firstLaunchDate: Date?
        var now: Date
        var lastRequestVersion: String?
        var lastRequestDate: Date?
        var currentVersion: String
        var blockers: Blockers
        /// Whose clock "local time" is. Injected so quiet hours are testable
        /// in a fixed zone; the app passes the device's autoupdating calendar.
        var calendar: Calendar = .autoupdatingCurrent
    }

    /// `bypassingThresholds` is the simulator hook's lever: it skips the
    /// count, age, version, interval and quiet-hours rules so run-and-look can
    /// reach the system sheet at any hour — and deliberately NOT the blockers,
    /// which are the part worth seeing hold. Quiet hours are a timing rule, not
    /// a calm-rule blocker, so they fall on the bypassed side.
    ///
    /// Blockers can only ever turn a yes into a no, which is what lets the
    /// service ask with `.none` first and read the store only for a yes.
    static func shouldRequest(state: State, bypassingThresholds: Bool = false) -> Bool {
        guard !state.blockers.any else { return false }
        if bypassingThresholds { return true }

        guard !isQuietHour(state.now, calendar: state.calendar) else { return false }
        guard state.totalEntries >= minimumEntries else { return false }

        // Negative intervals (a clock set backwards) fail these checks, which
        // is the safe direction: skipping a prompt costs nothing.
        guard let firstLaunch = state.firstLaunchDate,
              state.now.timeIntervalSince(firstLaunch) >= days(minimumDaysSinceFirstLaunch)
        else { return false }

        if state.lastRequestVersion == state.currentVersion { return false }
        if let last = state.lastRequestDate,
           state.now.timeIntervalSince(last) < days(minimumDaysBetweenRequests) {
            return false
        }
        return true
    }

    /// The two clinical blockers, composed from the engine's own predicates —
    /// never re-derived. The gain half is exactly what `WeightGainCard` shows:
    /// no verdict while `gainDeferral` holds it, otherwise
    /// `WeightVelocity.latest`'s band. That card, not `FeedingAdequacy`, is the
    /// source because it covers the first year, where `assess` stops at six
    /// months. Free or paid does not matter: blocking more is the safe side.
    static func clinicalBlockers(
        birthDate: Date,
        birthWeightKg: Double?,
        correctedBirthDate: Date,
        isMale: Bool,
        measurements: [WeightMeasurement],
        now: Date = Date()
    ) -> Blockers {
        var blockers = Blockers()
        let deferral = NewbornWeightLoss.gainDeferral(birthWeightKg: birthWeightKg,
                                                      birthDate: birthDate,
                                                      measurements: measurements,
                                                      now: now)
        if deferral == nil,
           WeightVelocity.latest(measurements: measurements,
                                 correctedBirthDate: correctedBirthDate,
                                 isMale: isMale)?.band == .below {
            blockers.belowReferenceGain = true
        }
        let status = NewbornWeightLoss.analyse(birthWeightKg: birthWeightKg,
                                               birthDate: birthDate,
                                               measurements: measurements,
                                               now: now)
        blockers.newbornFlag = !(status?.flags.isEmpty ?? true)
        return blockers
    }

    private static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * 86_400 }
}

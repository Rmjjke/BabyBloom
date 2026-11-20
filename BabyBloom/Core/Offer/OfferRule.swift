import Foundation

/// When Home may show the Premium offer card, and which one.
///
/// An offer is tied to a moment when the person's own data has just made a
/// paid function useful, never to a timer alone; it waits out any moment of
/// worry or busyness (the holds), and it slows down for people who keep
/// closing it. DECISIONS 2026-11-20 gives the why of each number; every number
/// is a constant here so one can change without touching the logic.
///
/// Pure, like `ReviewPromptPolicy`: the facts come from `OfferFacts+Store`,
/// the ledger from `OfferLedgerStore`, the live situation from Home, and
/// `OfferService` puts them together. A day is a calendar day of the
/// calendar passed in (the device's, in the app).
enum OfferRule {

    // MARK: - The numbers

    /// Distinct days with records for `first_result`.
    static let firstResultDays = 3
    /// Distinct days with records for `first_week`.
    static let firstWeekDays = 7
    /// Days after onboarding ended before `month_report`, and between two
    /// month reports afterwards.
    static let monthReportDays = 28
    /// A month report needs a record on one of the last this-many days,
    /// today included: no recent use, nothing to report.
    static let recentRecordDays = 7
    /// The first days after onboarding ended run on the short gap.
    static let earlyPeriodDays = 30
    /// The gap between two offers in the early period, and after it.
    static let earlyGapDays = 7
    static let gapDays = 30
    /// A former subscriber re-enters at this pace, from the later of the last
    /// offer and the last day seen subscribed.
    static let formerSubscriberGapDays = 30
    /// This many closes in a row without a tap slow the pace to `slowGapDays`.
    static let slowPaceCloses = 3
    static let slowGapDays = 90
    /// An install from before 1.4.0 sees no offer for this many days from its
    /// first 1.4.0 launch.
    static let cohortQuietDays = 14
    /// A shown card stays on Home on its day and the days after, this many
    /// days in all; then it leaves and counts as closed.
    static let stayDays = 3

    // MARK: - Inputs

    /// A feeding, sleep, diaper or custom event: the kinds the free history
    /// window hides. `createdAt` cuts the facts at an older install's first
    /// 1.4.0 launch.
    struct Record: Equatable, Sendable {
        var date: Date
        var createdAt: Date
    }

    /// A growth entry with a weight. Only those created after onboarding
    /// ended count as added in the app: onboarding's birth weight is created
    /// before that line.
    struct Weighing: Equatable, Sendable {
        var date: Date
        var createdAt: Date
        /// The weighing raised a clinical flag when it was added.
        var flagged: Bool
    }

    /// What the person's data says.
    struct Facts: Equatable, Sendable {
        /// `nil` while there is no baby: nothing is due.
        var onboardingEndedAt: Date?
        var records: [Record] = []
        var weighings: [Weighing] = []
        /// The rating prompt's clinical blockers hold right now.
        var clinicalBlocked = false

        /// The same facts as they stood at `cut`: only what had been created
        /// by then. The cohort spend reads the moments through it.
        func cut(at cut: Date) -> Facts {
            var facts = self
            facts.records = records.filter { $0.createdAt <= cut }
            facts.weighings = weighings.filter { $0.createdAt <= cut }
            return facts
        }
    }

    /// The install's cohort, one flag written at the first launch with this code.
    enum Cohort: Equatable, Sendable {
        /// Onboarding was not done yet at that launch.
        case new
        /// Onboarding was already done: an install from before 1.4.0.
        case beforeOffers(launchAt: Date)
    }

    struct Account: Equatable, Sendable {
        var isPremium: Bool
        var entitlementsResolved: Bool
        var cohort: Cohort
    }

    /// What is on screen now; Home knows it, the store does not.
    struct Situation: Equatable, Sendable {
        /// A dose may be taken now on a course Home shows.
        var medicationDue = false
        var launchedFromNotification = false
        var sheetOpen = false
        /// Today the weekly summary card is new on Home.
        var weeklyCardNew = false

        static let calm = Situation()
    }

    // MARK: - Output

    /// Why an offer waits for a cleaner moment. A hold never spends a moment.
    enum Hold: String, CaseIterable, Sendable {
        case unresolved, premium, cohortQuiet, clinical, flaggedWeighingDay,
             medicationDue, notificationLaunch, sheetOpen, weeklyCardNew
    }

    /// Why nothing is offered even with no hold on.
    enum Wait: String, Sendable {
        /// No moment and no recurring offer is due.
        case notDue
        /// The last offer is too recent.
        case gap
        /// Three closes in a row: the 90-day pace.
        case slowPace
    }

    enum Decision: Equatable, Sendable {
        /// `continuing`: the card already open stays; nothing new is recorded.
        case show(OfferContent, continuing: Bool)
        case hold(Hold)
        case wait(Wait)

        var content: OfferContent? {
            if case .show(let content, _) = self { return content }
            return nil
        }
    }

    // MARK: - The rule

    /// - Parameters:
    ///   - ledger: settled first (`OfferLedger.settle`), so an open card here
    ///     is inside its stay.
    ///   - forced: the simulator lever's content — skips the moments and the
    ///     pace, never the holds, which are the part worth seeing hold.
    static func decide(facts: Facts,
                       ledger: OfferLedger,
                       account: Account,
                       situation: Situation,
                       now: Date,
                       calendar: Calendar,
                       forced: OfferContent? = nil) -> Decision {
        if let hold = hold(facts: facts, account: account, situation: situation, now: now, calendar: calendar) {
            return .hold(hold)
        }
        if let card = ledger.open {
            return .show(card.content, continuing: true)
        }
        if let forced { return .show(forced, continuing: false) }

        guard let ended = facts.onboardingEndedAt else { return .wait(.notDue) }
        let candidate: OfferContent?
        let recurring = ledger.allMomentsUsed
        if recurring {
            candidate = recurringContent(facts: facts, ledger: ledger, account: account,
                                         ended: ended, now: now, calendar: calendar)
        } else {
            candidate = dueMoments(facts: facts, ended: ended, now: now, calendar: calendar)
                .first { content in content.moment.map { !ledger.isUsed($0) } ?? false }
        }
        guard let candidate else { return .wait(.notDue) }
        if let wait = pace(ledger: ledger, account: account, ended: ended, recurring: recurring,
                           now: now, calendar: calendar) {
            return .wait(wait)
        }
        return .show(candidate, continuing: false)
    }

    /// The moments whose condition holds on these facts, in priority order,
    /// each with the content it would show. Used for spending at the cohort
    /// launch too, so the two can never read a moment differently.
    static func dueMoments(facts: Facts, ended: Date, now: Date, calendar: Calendar) -> [OfferContent] {
        let records = facts.records.filter { $0.date <= now }
        let added = facts.weighings.filter { $0.createdAt > ended && $0.date <= now && $0.createdAt <= now }

        // Days count records dated from the end of onboarding on: a feed
        // logged during setup for earlier that morning is not the app at work.
        // A weighing is not a record here; it is the first result's other path.
        let counted = records.map(\.date).filter { $0 >= ended }.sorted()
        var days: [Date] = []      // the first record of each distinct day
        for date in counted where days.last.map({ !calendar.isDate($0, inSameDayAs: date) }) ?? true {
            days.append(date)
        }

        var due: [OfferContent] = []
        let firstWeighing = added.map(\.createdAt).min()
        let thirdDay = days.count >= firstResultDays ? days[firstResultDays - 1] : nil
        switch (thirdDay, firstWeighing) {
        case let (day?, weighing?): due.append(weighing <= day ? .firstResultPoint : .firstResultDays)
        case (_?, nil): due.append(.firstResultDays)
        case (nil, _?): due.append(.firstResultPoint)
        case (nil, nil): break
        }
        if days.count >= firstWeekDays { due.append(.firstWeek) }
        if let cutoff = HistoryWindow.cutoff(now: now, calendar: calendar),
           let oldest = records.map(\.date).min(), oldest < cutoff {
            due.append(.historyEdge)
        }
        if self.days(from: ended, to: now, calendar: calendar) >= monthReportDays,
           hasRecentRecord(records: records, now: now, calendar: calendar) {
            due.append(.monthReport)
        }
        return due
    }

    /// The moments an older install had already reached at its first 1.4.0
    /// launch: spent unshown, so such a person meets the moments that become
    /// true later and the recurring offer, not a burst of old ones.
    static func spentAtCohortLaunch(facts: Facts, launchAt: Date, calendar: Calendar) -> Set<OfferMoment> {
        guard let ended = facts.onboardingEndedAt else { return [] }
        let due = dueMoments(facts: facts.cut(at: launchAt), ended: ended, now: launchAt, calendar: calendar)
        return Set(due.compactMap(\.moment))
    }

    /// Whole calendar days from `a` to `b`: 23:59 to 00:01 is one day.
    static func days(from a: Date, to b: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)).day ?? 0
    }

    // MARK: - Parts

    private static func hold(facts: Facts, account: Account, situation: Situation,
                             now: Date, calendar: Calendar) -> Hold? {
        if !account.entitlementsResolved { return .unresolved }
        if account.isPremium { return .premium }
        if case .beforeOffers(let launchAt) = account.cohort,
           days(from: launchAt, to: now, calendar: calendar) < cohortQuietDays {
            return .cohortQuiet
        }
        if facts.clinicalBlocked { return .clinical }
        if facts.weighings.contains(where: { $0.flagged && calendar.isDate($0.createdAt, inSameDayAs: now) }) {
            return .flaggedWeighingDay
        }
        if situation.medicationDue { return .medicationDue }
        if situation.launchedFromNotification { return .notificationLaunch }
        if situation.sheetOpen { return .sheetOpen }
        if situation.weeklyCardNew { return .weeklyCardNew }
        return nil
    }

    /// After the four moments: a new clean weighing since the last offer,
    /// otherwise another month report. No new data, no offer.
    private static func recurringContent(facts: Facts, ledger: OfferLedger, account: Account,
                                         ended: Date, now: Date, calendar: Calendar) -> OfferContent? {
        var since = ledger.lastShownAt ?? ended
        if ledger.lastShownAt == nil, case .beforeOffers(let launchAt) = account.cohort { since = launchAt }
        let newClean = facts.weighings.contains {
            !$0.flagged && $0.createdAt > ended && $0.createdAt > since && $0.createdAt <= now
        }
        if newClean { return .growthPoint }

        let last = ledger.lastMonthReport ?? ended
        if days(from: last, to: now, calendar: calendar) >= monthReportDays,
           hasRecentRecord(records: facts.records, now: now, calendar: calendar) {
            return .monthReport
        }
        return nil
    }

    /// The pace. Each limit is checked on its own and the strictest wins: the
    /// slow pace after closes, a former subscriber's 30 days, the base gap.
    private static func pace(ledger: OfferLedger, account: Account, ended: Date, recurring: Bool,
                             now: Date, calendar: Calendar) -> Wait? {
        if let last = ledger.lastShownAt {
            let since = days(from: last, to: now, calendar: calendar)
            if ledger.closesInRow >= slowPaceCloses, since < slowGapDays { return .slowPace }
            let early = days(from: ended, to: now, calendar: calendar) < earlyPeriodDays
            // The recurring offer is at most one per 30 days whatever the age.
            let gap = early && !recurring ? earlyGapDays : gapDays
            if since < gap { return .gap }
        }
        if let premium = ledger.lastSeenPremiumAt {
            let reference = max(premium, ledger.lastShownAt ?? premium)
            if days(from: reference, to: now, calendar: calendar) < formerSubscriberGapDays { return .gap }
        }
        return nil
    }

    private static func hasRecentRecord(records: [Record], now: Date, calendar: Calendar) -> Bool {
        records.map(\.date).contains { date in
            let distance = days(from: date, to: now, calendar: calendar)
            return distance >= 0 && distance < recentRecordDays
        }
    }
}

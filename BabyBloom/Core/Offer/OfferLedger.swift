import Foundation

/// What the app remembers about the Premium offers it has shown: per moment
/// the day it was shown (or spent unshown), the last offer, the closes in a
/// row and the card that is still on Home.
///
/// Pure value; `OfferLedgerStore` keeps it in UserDefaults and in a
/// synchronizable Keychain item so it survives a reinstall, and `merge`
/// reconciles the two copies. Every mutation stamps `updatedAt`.
struct OfferLedger: Codable, Equatable, Sendable {

    struct OpenCard: Codable, Equatable, Sendable {
        var content: OfferContent
        var shownAt: Date
    }

    /// Keyed by `OfferMoment.rawValue`: a String-keyed dictionary encodes as a
    /// JSON object, an enum-keyed one as a flat array that is harder to read
    /// back from a Keychain dump.
    private(set) var shownDates: [String: Date] = [:]
    private(set) var spentDates: [String: Date] = [:]
    private(set) var lastShownAt: Date?
    private(set) var closesInRow = 0
    private(set) var open: OpenCard?
    private(set) var lastMonthReportAt: Date?
    /// The last day the person was seen subscribed; a former subscriber's
    /// pace is measured from it.
    private(set) var lastSeenPremiumAt: Date?
    /// The moments already true at the first 1.4.0 launch of an older install
    /// were written once; never recomputed, so a record deleted later cannot
    /// bring a spent moment back.
    private(set) var cohortSpent = false
    private(set) var updatedAt = Date.distantPast

    static let empty = OfferLedger()

    func shownAt(_ moment: OfferMoment) -> Date? { shownDates[moment.rawValue] }
    func spentAt(_ moment: OfferMoment) -> Date? { spentDates[moment.rawValue] }

    /// Shown or spent: either way the moment is never offered again.
    func isUsed(_ moment: OfferMoment) -> Bool {
        shownAt(moment) != nil || spentAt(moment) != nil
    }

    var allMomentsUsed: Bool { OfferMoment.allCases.allSatisfy(isUsed) }

    /// The last month report, shown or spent, that a repeated one counts from.
    var lastMonthReport: Date? {
        [lastMonthReportAt, shownAt(.monthReport), spentAt(.monthReport)].compactMap { $0 }.max()
    }

    // MARK: - Events

    /// The card appeared. Calling it again for the card already open is a
    /// no-op, so a Home that re-renders cannot restart the 3-day stay.
    mutating func recordShown(_ content: OfferContent, now: Date) {
        if open?.content == content { return }
        stampShown(content, now: now)
        open = OpenCard(content: content, shownAt: now)
        updatedAt = now
    }

    /// × on the card: one more close in the streak. A × on a card that is no
    /// longer open (its days ran out meanwhile, and that already counted as a
    /// close) changes nothing.
    @discardableResult
    mutating func recordClosed(_ content: OfferContent, now: Date) -> Bool {
        guard open?.content == content else { return false }
        open = nil
        closesInRow += 1
        updatedAt = now
        return true
    }

    /// A tap opens the paywall: the offer counts as shown and the streak ends.
    /// Closing the paywall does not bring the card back.
    mutating func recordTapped(_ content: OfferContent, now: Date) {
        if open?.content != content { stampShown(content, now: now) }
        open = nil
        closesInRow = 0
        updatedAt = now
    }

    /// Writes the moments already true at an older install's first 1.4.0
    /// launch as spent, once.
    mutating func spendAtCohortLaunch(_ moments: Set<OfferMoment>, launchAt: Date, now: Date) {
        guard !cohortSpent else { return }
        for moment in OfferMoment.allCases where moments.contains(moment) && !isUsed(moment) {
            spentDates[moment.rawValue] = launchAt
        }
        cohortSpent = true
        updatedAt = now
    }

    /// Records that the person is subscribed today. Returns whether anything
    /// changed, so the store writes at most once a day.
    @discardableResult
    mutating func notePremium(now: Date, calendar: Calendar) -> Bool {
        if let last = lastSeenPremiumAt, calendar.isDate(last, inSameDayAs: now) { return false }
        lastSeenPremiumAt = now
        updatedAt = now
        return true
    }

    /// An open card whose stay is over leaves Home and counts as closed —
    /// also when a hold kept it hidden all along. Returns its content so the
    /// caller can report the close as expired.
    mutating func settle(now: Date, calendar: Calendar) -> OfferContent? {
        guard let card = open,
              OfferRule.days(from: card.shownAt, to: now, calendar: calendar) >= OfferRule.stayDays
        else { return nil }
        open = nil
        closesInRow += 1
        updatedAt = now
        return card.content
    }

    private mutating func stampShown(_ content: OfferContent, now: Date) {
        if let moment = content.moment, shownDates[moment.rawValue] == nil {
            shownDates[moment.rawValue] = now
        }
        if content == .monthReport { lastMonthReportAt = now }
        lastShownAt = now
    }

    // MARK: - Two copies

    /// Reconciles the UserDefaults copy with the Keychain copy (after a
    /// reinstall, or from a second device through iCloud Keychain).
    ///
    /// Moment dates: the earliest wins, so a moment used on either side stays
    /// used. Dates that hold the pace back (last shown, last month report,
    /// last seen subscribed): the latest wins, so a merge can only slow
    /// offers down. The streak and the open card come from the copy written
    /// last — they describe one sequence of events and cannot be mixed.
    static func merge(_ a: OfferLedger, _ b: OfferLedger) -> OfferLedger {
        var result = a.updatedAt >= b.updatedAt ? a : b
        result.shownDates = a.shownDates.merging(b.shownDates, uniquingKeysWith: min)
        result.spentDates = a.spentDates.merging(b.spentDates, uniquingKeysWith: min)
        result.lastShownAt = latest(a.lastShownAt, b.lastShownAt)
        result.lastMonthReportAt = latest(a.lastMonthReportAt, b.lastMonthReportAt)
        result.lastSeenPremiumAt = latest(a.lastSeenPremiumAt, b.lastSeenPremiumAt)
        result.cohortSpent = a.cohortSpent || b.cohortSpent
        return result
    }

    private static func latest(_ a: Date?, _ b: Date?) -> Date? {
        [a, b].compactMap { $0 }.max()
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case shownDates = "shownAt", spentDates = "spentAt", lastShownAt, closesInRow, open,
             lastMonthReportAt, lastSeenPremiumAt, cohortSpent, updatedAt
    }

    init() {}

    /// Every field optional on the way in: a copy written by an older or newer
    /// build still decodes, and a field it lacks takes its empty value.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        shownDates = try c.decodeIfPresent([String: Date].self, forKey: .shownDates) ?? [:]
        spentDates = try c.decodeIfPresent([String: Date].self, forKey: .spentDates) ?? [:]
        lastShownAt = try c.decodeIfPresent(Date.self, forKey: .lastShownAt)
        closesInRow = try c.decodeIfPresent(Int.self, forKey: .closesInRow) ?? 0
        open = try? c.decodeIfPresent(OpenCard.self, forKey: .open)
        lastMonthReportAt = try c.decodeIfPresent(Date.self, forKey: .lastMonthReportAt)
        lastSeenPremiumAt = try c.decodeIfPresent(Date.self, forKey: .lastSeenPremiumAt)
        cohortSpent = try c.decodeIfPresent(Bool.self, forKey: .cohortSpent) ?? false
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }
}

#if targetEnvironment(simulator)
extension OfferLedger {
    /// The ledger preset lever: a state the rule can be looked at from without
    /// living through it.
    static func preset(lastShownAt: Date?, closesInRow: Int, shownMoments: [OfferMoment], now: Date) -> OfferLedger {
        var ledger = OfferLedger()
        ledger.lastShownAt = lastShownAt
        ledger.closesInRow = closesInRow
        for moment in shownMoments { ledger.shownDates[moment.rawValue] = lastShownAt ?? now }
        ledger.updatedAt = now
        return ledger
    }
}
#endif

import Foundation

/// A moment when the person's own data has just made a paid function useful.
/// Each is offered at most once per install; the order of the cases is the
/// priority when two are due on the same day.
enum OfferMoment: String, Codable, CaseIterable, Sendable {
    case firstResult = "first_result"
    case firstWeek = "first_week"
    case historyEdge = "history_edge"
    case monthReport = "month_report"
}

/// What an offer card shows. The raw value is the analytics `content` name and
/// the stem of the card's copy keys (`offer.<content>.title`), so renaming a
/// case is a data change, not a refactor.
enum OfferContent: String, Codable, CaseIterable, Sendable {
    case firstResultDays = "first_result_days"
    case firstResultPoint = "first_result_point"
    case firstWeek = "first_week"
    case historyEdge = "history_edge"
    case monthReport = "month_report"
    /// The recurring offer on a new clean weighing; it belongs to no moment.
    case growthPoint = "growth_point"

    /// The once-per-install moment this content spends, `nil` for the
    /// recurring `growthPoint`. A repeated month report also maps to
    /// `.monthReport`; the ledger only stamps a moment the first time.
    var moment: OfferMoment? {
        switch self {
        case .firstResultDays, .firstResultPoint: return .firstResult
        case .firstWeek: return .firstWeek
        case .historyEdge: return .historyEdge
        case .monthReport: return .monthReport
        case .growthPoint: return nil
        }
    }
}

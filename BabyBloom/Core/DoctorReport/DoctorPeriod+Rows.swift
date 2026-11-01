import Foundation

/// Display rules for the report's header and the visit rows. Pure, like
/// `DoctorPeriod`, so Events, Recent activity and the tests agree.
extension DoctorPeriod {

    /// Whole calendar days from the start of `start`'s day to the start of
    /// `now`'s day. Midnight to midnight through `Calendar` rather than a
    /// 24 h division, which would be off by one across a DST change. Never
    /// negative: a visit synced from another device may be dated ahead of
    /// this one's clock.
    static func periodDays(from start: Date, to now: Date, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, days)
    }

    /// Date descending, then the one logged last. The same order as
    /// `latestVisit`, so the top visit row in Events is the visit that the
    /// report's period starts at.
    static func newestFirst(_ visits: [DoctorVisit]) -> [DoctorVisit] {
        visits.sorted { a, b in
            a.date != b.date ? a.date > b.date : a.createdAt > b.createdAt
        }
    }

    /// First non-blank line of a note, trimmed: the one-line preview under a
    /// visit row. nil when the note is missing or only whitespace.
    static func noteFirstLine(_ note: String?) -> String? {
        note?
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}

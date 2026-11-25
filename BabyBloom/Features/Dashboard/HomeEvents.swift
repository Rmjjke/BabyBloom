import Foundation

/// Which events Home's Events section lists. Generic over the item so the
/// rule is tested without a store.
enum HomeEvents {
    /// Three rows keep the section shorter than the stat grid above it; the
    /// rest of the day is one tap away in Events.
    static let limit = 3

    /// The items on `now`'s calendar day, newest first, at most `limit`.
    /// Items at the same time keep their input order. A later time today
    /// sorts first, as it does in the Events history.
    static func today<T>(_ items: [T],
                         time: (T) -> Date,
                         now: Date,
                         calendar: Calendar = .current) -> [T] {
        items.enumerated()
            .filter { calendar.isDate(time($0.element), inSameDayAs: now) }
            .sorted {
                let (a, b) = (time($0.element), time($1.element))
                return a != b ? a > b : $0.offset < $1.offset
            }
            .prefix(limit)
            .map(\.element)
    }

    /// Whether `saved` has a row on Home: its time is today and it is among
    /// the newest three of the day.
    static func isOnHome<T, ID: Equatable>(_ saved: ID,
                                           among items: [T],
                                           id: (T) -> ID,
                                           time: (T) -> Date,
                                           now: Date,
                                           calendar: Calendar = .current) -> Bool {
        today(items, time: time, now: now, calendar: calendar).contains { id($0) == saved }
    }

    /// The same test right after a save, when `items` (a query) may not yet
    /// hold the saved item: it is counted then, after the others, so a tie
    /// at the same time leaves it off Home and Events is pushed. A wrong push
    /// still shows the event; a wrong cue on Home would show nothing.
    static func isOnHome<T, ID: Equatable>(saved: T,
                                           among items: [T],
                                           id: (T) -> ID,
                                           time: (T) -> Date,
                                           now: Date,
                                           calendar: Calendar = .current) -> Bool {
        let savedID = id(saved)
        let known = items.contains { id($0) == savedID } ? items : items + [saved]
        return isOnHome(savedID, among: known, id: id, time: time, now: now, calendar: calendar)
    }
}

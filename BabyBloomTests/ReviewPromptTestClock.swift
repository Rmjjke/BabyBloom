import Foundation

/// A fixed zone and instant for the review-prompt tests. Quiet hours read the
/// LOCAL hour, so a suite on the wall clock would pass by day and fail by
/// night; everything here runs at noon in a zone that observes DST.
enum ReviewPromptTestClock {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    static let noon = date(2026, 9, 23, 12)
}

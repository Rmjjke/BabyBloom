import Foundation

/// "Now" for the code that has a lever to move it: the weekly summary, its
/// notification and the seeds that set them up (L3).
///
/// `-BBNow 2026-10-26T00:00:00` (ISO 8601, local time when no offset is given)
/// pins the clock on the simulator, so QA can stand on a Monday, a Sunday
/// 23:59 or a newborn week without changing the Mac's date. Simulator-gated
/// like the other levers (DECISIONS 2026-08-26): a device binary does not
/// contain the key. Everything else in the app keeps reading `Date()`; only
/// the weekly path is under test here, and a global clock swap is its own job.
enum AppClock {
    static var now: Date {
        #if targetEnvironment(simulator)
        if let pinned = pinned { return pinned }
        #endif
        return Date()
    }

    #if targetEnvironment(simulator)
    /// Read once: a lever is a launch argument, it does not change mid-run.
    private static let pinned: Date? = {
        guard let raw = UserDefaults.standard.string(forKey: "BBNow") else { return nil }
        let withOffset = ISO8601DateFormatter()
        if let date = withOffset.date(from: raw) { return date }
        let local = ISO8601DateFormatter()
        local.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        local.timeZone = .current
        guard let date = local.date(from: raw) else {
            // A typo would silently run on the real clock and the screenshot
            // would show the wrong week; say so loudly instead.
            fatalError("-BBNow \(raw) is not ISO 8601 (e.g. 2026-10-26T09:00:00)")
        }
        return date
    }()
    #endif
}

import Foundation

// MARK: - Dates in the app's language

/// `.formatted(.dateTime…)` resolves against `Locale.current` — the DEVICE
/// language — not the one the user picked in Settings. That mismatch shipped:
/// an English UI on a Russian phone rendered English labels beside Russian
/// dates, and vice versa.
///
/// Every on-screen date and time goes through these helpers, which pin the
/// app's language the same way `BBCharts` pins its axis labels; clock times
/// take the device's 12/24-hour cycle on top. The export PDF prints its times
/// on that same locale; the CSV's machine-readable columns are pinned to
/// `en_US_POSIX` instead (see `ExportGenerator`).
extension Date {
    /// Time of day in the app's language on the device's 12/24-hour clock:
    /// "14:30" or "2:30 PM" in English alike, as the phone is set. The same
    /// locale the date pickers get from the environment, so the two agree.
    var appTimeOfDay: String { appTimeOfDay(in: Date.appTimeLocale) }

    /// The locale clock times are formatted in; the app's environment locale.
    static var appTimeLocale: Locale { LocalizationManager.shared.language.environmentLocale }

    func appTimeOfDay(in locale: Locale) -> String {
        formatted(.dateTime.hour().minute().locale(locale))
    }

    /// Day and month — "Aug 25", "25 авг.", "25 ago.".
    var appDayMonth: String {
        formatted(.dateTime.day().month().locale(LocalizationManager.shared.language.locale))
    }

    /// Day, month and year — "Aug 25, 2026". For the visit detail, where an
    /// old visit is ambiguous without its year.
    var appDayMonthYear: String {
        formatted(.dateTime.day().month().year().locale(LocalizationManager.shared.language.locale))
    }
}

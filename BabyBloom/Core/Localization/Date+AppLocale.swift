import Foundation

// MARK: - Dates in the app's language

/// `.formatted(.dateTime…)` resolves against `Locale.current` — the DEVICE
/// language — not the one the user picked in Settings. That mismatch shipped:
/// an English UI on a Russian phone rendered English labels beside Russian
/// dates, and vice versa.
///
/// Every on-screen date goes through these two helpers, which pin the app's
/// language the same way `BBCharts` already pins its axis labels. Exported
/// files deliberately do NOT use them: machine-readable columns there are
/// pinned to `en_US_POSIX` instead (see `ExportGenerator`).
extension Date {
    /// Time of day — "2:30 PM" in English, "14:30" in Russian and Spanish.
    var appTimeOfDay: String {
        formatted(.dateTime.hour().minute().locale(LocalizationManager.shared.language.locale))
    }

    /// Day and month — "Aug 25", "25 авг.", "25 ago.".
    var appDayMonth: String {
        formatted(.dateTime.day().month().locale(LocalizationManager.shared.language.locale))
    }
}

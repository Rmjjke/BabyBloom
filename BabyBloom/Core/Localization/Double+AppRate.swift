import Foundation

// MARK: - Measured rates in the app's language

extension Double {
    /// A measured per-day rate, rendered in the app's language.
    ///
    /// One decimal only when the value is not whole — "9 a day" reads better
    /// than "9.0 a day", while 7.6 must NOT become "8": the verdict beside it
    /// compares the raw value against a whole bound, and a rounded display
    /// would contradict its own status word.
    ///
    /// The decimal separator follows the app's chosen language, not the
    /// device — Russian and Spanish want "7,6".
    var appRate: String {
        let formatter = NumberFormatter()
        formatter.locale = LocalizationManager.shared.language.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: self as NSNumber) ?? String(format: "%.0f", self)
    }
}

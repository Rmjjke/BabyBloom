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
    /// `roundingMode = .down` is load-bearing, NOT a stylistic choice — do not
    /// restore the default. Rounding to one decimal only narrows the
    /// contradiction above from 0.5 wide to 0.05: with half-even rounding a
    /// measured 7.96 displays as "8" while the verdict beside it still reads
    /// "below the reference", against a reference that starts at 8. That strip
    /// is reachable — the rate divides by the raw un-floored interval between
    /// two weighings, so 20 feeds over 2.5157 days is 7.95007… — and every
    /// bound in the feeding table (8, 7, 6, 5, 4) has one beneath it.
    /// Truncating is one-sided and sufficient: a below-bound value can never
    /// display AT the bound, whole values are untouched, and the mirror case is
    /// already harmless ("8 a day · within the reference" is consistent).
    ///
    /// The decimal separator follows whatever the app's chosen language uses,
    /// not the device's — which is the point of pinning the locale here. Note
    /// that this is a per-language fact and not a guess worth making in
    /// advance: Spanish is pinned to `es_419`, which takes a period, so es
    /// renders "7.6" and ru renders "7,6".
    var appRate: String {
        let formatter = NumberFormatter()
        formatter.locale = LocalizationManager.shared.language.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.roundingMode = .down
        return formatter.string(from: self as NSNumber) ?? String(format: "%.0f", self)
    }
}

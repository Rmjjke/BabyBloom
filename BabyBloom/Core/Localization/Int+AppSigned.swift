import Foundation

extension Int {
    /// "+210", "0", "-30" in the app's language: a change always carries its
    /// sign, and the sign is the language's own — Swedish, Norwegian and
    /// Finnish write a loss with the minus sign U+2212, not a hyphen.
    var appSigned: String { appSigned(locale: LocalizationManager.shared.language.locale) }

    func appSigned(locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        // As `appDecimal`: a 1200 g week stays one word in a tile.
        formatter.usesGroupingSeparator = false
        if self > 0 { formatter.positivePrefix = formatter.plusSign }
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
}

import SwiftUI

// MARK: - Appearance preference

/// Light/dark preference, stored under "appAppearance".
///
/// `.system` follows the device setting, which is what the app always did
/// before this became configurable — so it stays the default and an existing
/// install keeps behaving exactly as it did.
///
/// Every colour lives in the Asset Catalog with both a light and a dark
/// variant, so switching needs no per-view work: overriding the color scheme
/// is enough.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// `nil` hands control back to the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var labelKey: String { "settings.appearance.\(rawValue)" }

    var symbolName: String {
        switch self {
        case .system: "iphone"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }

    static func from(_ raw: String) -> AppAppearance {
        AppAppearance(rawValue: raw) ?? .system
    }
}

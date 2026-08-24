import Foundation

// MARK: - Supported Languages

/// The single source of truth for the languages the app ships.
///
/// Adding a language (say Japanese) is one case here plus the matching files:
///   1. `case ja` below — every switch is exhaustive, so the compiler points at
///      whatever else needs a value;
///   2. `BabyBloom/Resources/Localization/ja.json` with the same key set as
///      `en.json`, and a byte-identical copy in `WidgetResources/Localization/`;
///   3. `BabyBloom/Resources/ja.lproj/InfoPlist.strings` — the presence of the
///      `.lproj` folder is what makes iOS (and the App Store listing) treat the
///      app as localized for that language;
///   4. the `for f in …` list in project.yml's "Verify widget localization
///      copies in sync" pre-build script.
enum SupportedLanguage: String, CaseIterable, Identifiable, Sendable {
    case en
    case ru
    case es

    var id: String { rawValue }

    /// Used when the device speaks a language we do not ship, and whenever a
    /// stored preference no longer matches a shipped language.
    static let fallback: SupportedLanguage = .en

    /// The language's own name for itself — what the picker shows. Deliberately
    /// not translated: a Spanish speaker scans the list for "Español", not for
    /// whatever the current UI language calls Spanish.
    var endonym: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        }
    }

    /// Locale for system-formatted output (weekday and month names in charts).
    /// Not derived from `rawValue` so each language can pin the region it wants
    /// — `es` is Latin-American neutral rather than Castilian.
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .ru: return Locale(identifier: "ru_RU")
        case .es: return Locale(identifier: "es_419")
        }
    }

    /// How the language builds the age words ("3 days" / "3 дня" / "3 días").
    var pluralRule: PluralRule {
        switch self {
        case .en, .es: return .singularPlural
        case .ru: return .slavic
        }
    }

    enum PluralRule: Sendable {
        /// One form for 1, one form for everything else.
        case singularPlural
        /// Russian-style one / few / many split.
        case slavic
    }

    /// Resolves an IETF language tag ("es-419", "ru-RU", "en") against the
    /// shipped list by its primary subtag. `nil` when we do not ship it.
    init?(languageTag: String?) {
        guard let base = languageTag?.split(separator: "-").first?.lowercased() else { return nil }
        self.init(rawValue: base)
    }
}

// MARK: - Localization Manager

/// Singleton that loads translations from JSON files.
/// JSON files live at Resources/Localization/{language}.json.
/// Add a new language by adding a `SupportedLanguage` case and dropping a new
/// JSON file with the same keys.
final class LocalizationManager: @unchecked Sendable {
    static let shared = LocalizationManager()

    private(set) var currentLanguage: String
    private var strings: [String: String] = [:]

    /// Language to use before the user has picked one: the device language if
    /// we ship it, `SupportedLanguage.fallback` otherwise. Once the user picks
    /// in Settings, that choice is stored under "appLanguage" and wins from
    /// then on.
    static var deviceDefault: String { deviceDefaultLanguage.rawValue }

    static var deviceDefaultLanguage: SupportedLanguage {
        SupportedLanguage(languageTag: Locale.preferredLanguages.first) ?? .fallback
    }

    /// The active language as a known case — the entry point for anything that
    /// needs more than the raw code (locale, plural rule, display name).
    var language: SupportedLanguage {
        SupportedLanguage(rawValue: currentLanguage) ?? .fallback
    }

    /// The App Group suite both targets can reach. The widget runs in its own
    /// process with its own `UserDefaults.standard`, so a language stored only
    /// there is invisible to it — the shared suite is the only channel.
    ///
    /// Computed rather than stored: `UserDefaults` is not `Sendable`, so a
    /// static `let` trips Swift 6 strict concurrency. Foundation caches the
    /// suite internally, so re-creating the handle costs nothing.
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.nenita.app")
    }

    private static let languageKey = "appLanguage"

    /// Resolution order: a `-appLanguage` launch argument, then the App Group
    /// (what the app and the widget agree on), then this process's own
    /// defaults (where the app stored the choice before the shared suite
    /// existed — keeps upgrading users on their language), then the device.
    /// `setLanguage` writes back to the App Group, so a legacy value migrates
    /// itself the first time the app runs.
    ///
    /// The argument domain is read explicitly because it only outranks the
    /// other domains WITHIN `UserDefaults.standard`; the App Group is a
    /// separate store and would otherwise shadow the argument that e2e flows
    /// use to pin the language.
    private static func storedLanguage() -> SupportedLanguage {
        let launchArgument = UserDefaults.standard
            .volatileDomain(forName: UserDefaults.argumentDomain)[languageKey] as? String
        let saved = launchArgument
            ?? sharedDefaults?.string(forKey: languageKey)
            ?? UserDefaults.standard.string(forKey: languageKey)
        return saved.flatMap(SupportedLanguage.init(rawValue:)) ?? deviceDefaultLanguage
    }

    private init() {
        let resolved = Self.storedLanguage()
        currentLanguage = resolved.rawValue
        load(resolved)
    }

    func setLanguage(_ language: String) {
        setLanguage(SupportedLanguage(rawValue: language) ?? .fallback)
    }

    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language.rawValue
        Self.sharedDefaults?.set(language.rawValue, forKey: Self.languageKey)
        load(language)
    }

    func string(for key: String) -> String {
        strings[key] ?? key
    }

    // MARK: Private

    private func load(_ language: SupportedLanguage) {
        if let dict = loadJSON(language.rawValue) {
            strings = dict
        } else if language != .fallback, let dict = loadJSON(SupportedLanguage.fallback.rawValue) {
            strings = dict
        }
    }

    private func loadJSON(_ language: String) -> [String: String]? {
        // Try subdirectory first, fall back to bundle root (depends on how xcodegen copies resources)
        let url = Bundle.main.url(forResource: language, withExtension: "json", subdirectory: "Localization")
            ?? Bundle.main.url(forResource: language, withExtension: "json")
        guard
            let url,
            let data = try? Data(contentsOf: url),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return dict
    }
}

// MARK: - String Extension

extension String {
    /// Returns the localized value for this key from the active JSON file.
    /// Falls back to the key itself if not found.
    var l: String { LocalizationManager.shared.string(for: self) }
}

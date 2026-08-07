import Foundation

// MARK: - Localization Manager

/// Singleton that loads translations from JSON files.
/// JSON files live at Resources/Localization/{language}.json.
/// Add a new language by dropping a new JSON file with the same keys.
final class LocalizationManager: @unchecked Sendable {
    static let shared = LocalizationManager()

    private(set) var currentLanguage: String
    private var strings: [String: String] = [:]

    /// Language to use before the user has picked one. Russian-speaking devices
    /// get Russian; everyone else gets English. Once the user picks in Settings,
    /// that choice is stored under "appLanguage" and wins from then on.
    static var deviceDefault: String {
        let code = Locale.preferredLanguages.first?
            .split(separator: "-").first?.lowercased()
        return code == "ru" ? "ru" : "en"
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? Self.deviceDefault
        currentLanguage = saved
        load(saved)
    }

    func setLanguage(_ language: String) {
        currentLanguage = language
        load(language)
    }

    func string(for key: String) -> String {
        strings[key] ?? key
    }

    // MARK: Private

    private func load(_ language: String) {
        if let dict = loadJSON(language) {
            strings = dict
        } else if language != "ru", let fallback = loadJSON("ru") {
            strings = fallback
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

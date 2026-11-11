import Foundation
import os

// MARK: - Supported Languages

/// The single source of truth for the languages the app knows.
///
/// A case alone ships nothing: a language is offered (picker, device
/// resolution, a stored choice) only once its JSON is in the bundle — see
/// `available`. Adding a language (say Italian) is:
///   1. `case it` below — every switch is exhaustive, so the compiler points at
///      whatever else needs a value;
///   2. `BabyBloom/Resources/Localization/it.json` and a byte-identical copy in
///      `WidgetResources/Localization/` (the pre-build script checks every
///      JSON in that folder; a file may hold only part of the keys, the rest
///      read English);
///   3. `BabyBloom/Resources/it.lproj/InfoPlist.strings` — the presence of the
///      `.lproj` folder is what makes iOS (and the App Store listing) treat the
///      app as localized for that language.
///
/// Raw values are BCP-47 tags and double as the JSON file names, so a regional
/// or script variant is its own language: `pt-BR` and `pt-PT`, `zh-Hant`.
enum SupportedLanguage: String, CaseIterable, Identifiable, Sendable {
    case en
    case ru
    case es
    case uk
    case ja
    case ko
    case fr
    case de
    case sv
    case nb
    case da
    case fi
    case ptBR = "pt-BR"
    case ptPT = "pt-PT"
    case zhHant = "zh-Hant"

    var id: String { rawValue }

    /// Used when the device speaks a language we do not ship, whenever a
    /// stored preference no longer matches a shipped language, and for every
    /// key a language's file does not have yet.
    static let fallback: SupportedLanguage = .en

    /// The language's own name for itself — what the picker shows. Deliberately
    /// not translated: a Spanish speaker scans the list for "Español", not for
    /// whatever the current UI language calls Spanish.
    var endonym: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .es: return "Español"
        case .uk: return "Українська"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .sv: return "Svenska"
        case .nb: return "Norsk bokmål"
        case .da: return "Dansk"
        case .fi: return "Suomi"
        case .ptBR: return "Português (Brasil)"
        case .ptPT: return "Português (Portugal)"
        case .zhHant: return "繁體中文"
        }
    }

    /// Locale for system-formatted output (weekday and month names in charts).
    /// Not derived from `rawValue` and not from the device region: each
    /// language pins one region, so a language reads one way on every phone —
    /// `es` is Latin-American neutral rather than Castilian, `zh-Hant` takes
    /// Taiwan's formats in Hong Kong and Macau too.
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .ru: return Locale(identifier: "ru_RU")
        case .es: return Locale(identifier: "es_419")
        case .uk: return Locale(identifier: "uk_UA")
        case .ja: return Locale(identifier: "ja_JP")
        case .ko: return Locale(identifier: "ko_KR")
        case .fr: return Locale(identifier: "fr_FR")
        case .de: return Locale(identifier: "de_DE")
        case .sv: return Locale(identifier: "sv_SE")
        case .nb: return Locale(identifier: "nb_NO")
        case .da: return Locale(identifier: "da_DK")
        case .fi: return Locale(identifier: "fi_FI")
        case .ptBR: return Locale(identifier: "pt_BR")
        case .ptPT: return Locale(identifier: "pt_PT")
        case .zhHant: return Locale(identifier: "zh_Hant_TW")
        }
    }

    /// For SwiftUI's environment (date pickers) and every clock time the app
    /// formats: the language's month names and formats, but the user's own
    /// 12/24-hour choice, which a fixed identifier would replace with the
    /// pinned region's. One locale for both, so a sheet's picker and its
    /// status line never show two clocks.
    var environmentLocale: Locale { environmentLocale(hourCycle: Locale.current.hourCycle) }

    func environmentLocale(hourCycle: Locale.HourCycle) -> Locale {
        var components = Locale.Components(locale: locale)
        components.hourCycle = hourCycle
        return Locale(components: components)
    }

    /// Always Gregorian, speaking the app language: weekday and month names
    /// follow the language, the week starts on Monday (`gregorian`). Not
    /// the device's calendar: a phone set to the Japanese or Buddhist calendar
    /// would otherwise date a birth «Reiwa 8» in an English app, and the
    /// report a doctor reads would carry a year they cannot place.
    var environmentCalendar: Calendar { Self.gregorian(locale: environmentLocale) }

    /// The base for every date the app formats itself. `.formatted(.dateTime…
    /// .locale(x))` keeps the DEVICE calendar whatever the locale says (a
    /// Japanese-calendar phone printed "Oct 26, Reiwa 8" in English), while a
    /// `DateFormatter` takes the calendar of the locale it is given — so the
    /// format styles start from this instead.
    var dateFormat: Date.FormatStyle { Self.dateFormat(locale: locale) }

    static func dateFormat(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: gregorian(locale: locale))
    }

    /// The calendar the app counts its own weeks and months in: the charts'
    /// week and range, the export and report periods.
    var calendar: Calendar { Self.gregorian(locale: locale) }

    /// Gregorian in the given language, the week starting on Monday in every
    /// language (ISO weeks, as the weekly summary counts them): a US phone's
    /// Sunday week would make the chart's week and the weekly card two
    /// different seven days.
    static func gregorian(locale: Locale) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// Picks the glyph forms of characters several scripts share: 骨 and 直
    /// are drawn differently in Japanese and in Traditional Chinese, and a
    /// name the parent typed should look the way their language writes it.
    /// The locale alone does not reach the text renderer.
    var typesettingLanguage: Locale.Language { locale.language }

    // MARK: Which languages ship

    /// The cases whose JSON is in this bundle, in declaration order. Read once
    /// per process: the bundle does not change under a running app. The app
    /// and the widget each check their own bundle.
    static let available: [SupportedLanguage] = available { hasFile($0) }

    static func available(where hasFile: (SupportedLanguage) -> Bool) -> [SupportedLanguage] {
        allCases.filter { $0 == fallback || hasFile($0) }
    }

    static func hasFile(_ language: SupportedLanguage, in bundle: Bundle = .main) -> Bool {
        LocalizationManager.url(for: language.rawValue, in: bundle) != nil
    }

    /// The best shipped language for a list of BCP-47 tags, most preferred
    /// first: Foundation's own matcher, the one iOS uses for an app's
    /// localizations. It walks the WHOLE list ([it, de] gives de), maps
    /// regional variants (pt-AO → pt-PT, es-MX → es, no and nn → nb, zh-HK →
    /// zh-Hant) and never crosses scripts, so a zh-Hans-only list gets the
    /// fallback, as it gets an English App Store page.
    static func resolve(preferred: [String], available: [SupportedLanguage]) -> SupportedLanguage {
        // The matcher answers the first candidate when nothing matches, so the
        // fallback leads the list.
        let candidates = [fallback] + available.filter { $0 != fallback }
        return Bundle.preferredLocalizations(from: candidates.map(\.rawValue), forPreferences: preferred)
            .lazy.compactMap(SupportedLanguage.init(rawValue:)).first ?? fallback
    }

    /// The picker's order: the current language on top, so the row the user
    /// came from is where the eye lands, then the rest by their own names.
    /// Code-point order, not a locale's collation: the list is one list in
    /// every app language (Latin, then Cyrillic, then the CJK names).
    static func pickerOrder(current: SupportedLanguage, available: [SupportedLanguage]) -> [SupportedLanguage] {
        let rest = available.filter { $0 != current }.sorted {
            $0.endonym.compare($1.endonym, options: [.caseInsensitive]) == .orderedAscending
        }
        return [current] + rest
    }
}

// MARK: - Localization Manager

/// Singleton that loads translations from JSON files.
/// JSON files live at Resources/Localization/{language}.json.
final class LocalizationManager: @unchecked Sendable {
    static let shared = LocalizationManager()

    private(set) var currentLanguage: String
    /// The language's table and the English fallback, swapped as one value so
    /// a reader never pairs a new table with the previous fallback.
    private var tables: (strings: [String: String], fallback: [String: String]) = ([:], [:])
    /// Always loaded: every key a language's file lacks reads English rather
    /// than its raw key, so a half-translated file is usable, not broken.
    private let english: [String: String]
    /// A debug pseudo-language that replaces the table while the stored
    /// language stays real; nil in every release and device build.
    private(set) var pseudo: PseudoLanguage?

    #if DEBUG
    private static let log = Logger(subsystem: "com.nenita.app", category: "Localization")
    private let missingLock = NSLock()
    private var reportedMissing: Set<String> = []
    #endif

    /// Language to use before the user has picked one: the best shipped match
    /// for the device's preferred-language list. Once the user picks in
    /// Settings, that choice is stored under "appLanguage" and wins from then
    /// on.
    static var deviceDefault: String { deviceDefaultLanguage.rawValue }

    static var deviceDefaultLanguage: SupportedLanguage {
        SupportedLanguage.resolve(preferred: Locale.preferredLanguages, available: SupportedLanguage.available)
    }

    /// The active language as a known case — the entry point for anything that
    /// needs more than the raw code (locale, plural rule, display name).
    var language: SupportedLanguage {
        pseudo?.base ?? SupportedLanguage(rawValue: currentLanguage) ?? .fallback
    }

    /// The language a root view hands to SwiftUI for a stored picker value:
    /// the pseudo-language's base while one is on, so ja-XB typesets as
    /// Japanese.
    static func environmentLanguage(for stored: String) -> SupportedLanguage {
        shared.pseudo?.base ?? effective(stored)
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

    static let languageKey = "appLanguage"

    /// The stored language for a reader with no `@AppStorage` of its own: the
    /// widget, and this manager's first value. Order: a `-appLanguage` launch
    /// argument, then the App Group (the widget's own defaults never hold the
    /// choice), then this process's defaults, then the device. In the app the
    /// picker's `@AppStorage` is the truth — `BabyBloomApp.init` hands it over
    /// before the first view, and `setLanguage` mirrors it to the App Group.
    ///
    /// The argument domain is read explicitly because it only outranks the
    /// other domains WITHIN `UserDefaults.standard`; the App Group is a
    /// separate store and would otherwise shadow the argument that e2e flows
    /// use to pin the language.
    private static func storedLanguage() -> SupportedLanguage {
        let launchArgument = UserDefaults.standard
            .volatileDomain(forName: UserDefaults.argumentDomain)[languageKey] as? String
        return resolveStored(
            [launchArgument, sharedDefaults?.string(forKey: languageKey),
             UserDefaults.standard.string(forKey: languageKey)],
            preferred: Locale.preferredLanguages, available: SupportedLanguage.available)
    }

    /// The first stored value that names a shipped language, else the device.
    /// A value for a language whose file is gone falls through rather than
    /// pinning the app to English.
    static func resolveStored(_ stored: [String?], preferred: [String],
                              available: [SupportedLanguage]) -> SupportedLanguage {
        for value in stored.compactMap({ $0 }) {
            if let language = SupportedLanguage(rawValue: value), available.contains(language) {
                return language
            }
        }
        return SupportedLanguage.resolve(preferred: preferred, available: available)
    }

    // MARK: The iOS per-app Language

    /// Where the app keeps the per-app `AppleLanguages` it last saw.
    static let seenAppleLanguagesKey = "appLanguage.seenAppleLanguages"

    /// iOS Settings › <app> › Language writes `AppleLanguages` into the app's
    /// own defaults and relaunches it, but a stored in-app choice outranks the
    /// device, so the change did nothing. Called once at app launch, before
    /// anything reads the language: a per-app list that changed since the last
    /// launch becomes the stored choice. Only the app's OWN domain counts —
    /// the global list is the device language, which a stored choice is meant
    /// to outrank.
    static func adoptPerAppLanguageChange() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let standard = UserDefaults.standard
        let current = standard.persistentDomain(forName: bundleID)?["AppleLanguages"] as? [String]
        let seen = standard.array(forKey: seenAppleLanguagesKey) as? [String]
        standard.set(current ?? [], forKey: seenAppleLanguagesKey)
        guard let adopted = perAppLanguageChange(current: current, seen: seen, device: Locale.preferredLanguages,
                                                 available: SupportedLanguage.available) else { return }
        standard.set(adopted.rawValue, forKey: languageKey)
        sharedDefaults?.set(adopted.rawValue, forKey: languageKey)
    }

    /// The language to adopt, or nil. `seen == nil` is the first launch that
    /// records the list (a fresh install, or the update that brought this
    /// check): there is no "since", so a list set before an upgrade does not
    /// overturn the choice the user made in the app. An empty `seen` is a
    /// recorded "no per-app language". A list that went away is a change too —
    /// the app set back to the device's language — so `device`, the global
    /// list by then, is adopted.
    static func perAppLanguageChange(current: [String]?, seen: [String]?, device: [String],
                                     available: [SupportedLanguage]) -> SupportedLanguage? {
        guard let seen else { return nil }
        let now = current ?? []
        guard now != seen else { return nil }
        return SupportedLanguage.resolve(preferred: now.isEmpty ? device : now, available: available)
    }

    private init() {
        english = Self.loadJSON(SupportedLanguage.fallback.rawValue) ?? [:]
        let resolved = Self.storedLanguage()
        currentLanguage = resolved.rawValue
        #if DEBUG && targetEnvironment(simulator)
        // The launch argument only: a value persisted in the app's domain would
        // keep the simulator in a pseudo-language after a plain launch.
        pseudo = (UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)["BBPseudoLanguage"] as? String)
            .flatMap(PseudoLanguage.init)
        #endif
        load(resolved)
    }

    #if DEBUG
    /// Turns a pseudo-language on or off in-process, for hosted tests.
    func setPseudo(_ language: PseudoLanguage?) {
        pseudo = language
        load(SupportedLanguage(rawValue: currentLanguage) ?? .fallback)
    }
    #endif

    /// Re-reads the stored language and reloads the table if it moved.
    ///
    /// The app resolves its language once, at launch, and that is enough: a new
    /// choice in Settings goes through `setLanguage`. A widget extension has no
    /// such moment. iOS keeps the extension process alive across timeline
    /// refreshes, so this singleton held whatever language it read when the
    /// process first started and the widget went on rendering the OLD language
    /// after the user changed it — until iOS happened to restart the extension,
    /// which could be hours. Timeline generation calls this first.
    func refreshFromStore() {
        let resolved = Self.storedLanguage()
        guard resolved.rawValue != currentLanguage else { return }
        currentLanguage = resolved.rawValue
        load(resolved)
    }

    func setLanguage(_ language: String) {
        setLanguage(Self.effective(language))
    }

    /// What a stored raw value means today: itself when it names a shipped
    /// language, else the device's best match — never a language with no file.
    static func effective(_ stored: String) -> SupportedLanguage {
        resolveStored([stored], preferred: Locale.preferredLanguages, available: SupportedLanguage.available)
    }

    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language.rawValue
        Self.sharedDefaults?.set(language.rawValue, forKey: Self.languageKey)
        load(language)
    }

    func string(for key: String) -> String {
        let current = tables
        if let value = current.strings[key] { return value }
        #if DEBUG
        reportMissing(key)
        #endif
        return Self.lookup(key, in: current.strings, english: current.fallback)
    }

    /// The template of `family` for a number with these operands in the app's
    /// language; the chain is in `pluralTemplate(_:_:language:in:english:)`.
    func pluralTemplate(_ family: PluralFamily, _ operands: PluralOperands) -> String {
        let current = tables
        return Self.pluralTemplate(family, operands, language: language,
                                   in: current.strings, english: current.fallback)
    }

    /// The language's value, else English, else the key itself — the raw key
    /// is what a missing English entry looks like, and the lint catches it.
    static func lookup(_ key: String, in table: [String: String], english: [String: String]) -> String {
        table[key] ?? english[key] ?? key
    }

    // MARK: Private

    private func load(_ language: SupportedLanguage) {
        if let pseudo {
            tables = Self.branded(PseudoLanguage.table(from: english, pseudo), english: english)
            return
        }
        let table = language == .fallback ? english : (Self.loadJSON(language.rawValue) ?? [:])
        tables = Self.branded(table, english: english)
    }

    static let brandKey = "brand.name"
    static let brandToken = "{brand}"

    /// The language's table and its English fallback with `{brand}` replaced by
    /// the language's `brand.name` (English's when the file has none), once per
    /// load — so renaming the app is one value per language, not a hunt through
    /// every sentence that names it. The fallback takes the language's name too,
    /// so a key the language lacks never shows another language's name. A
    /// language that declines the name (ru «в Ночку») writes those forms inline;
    /// only its nominative uses the token.
    static func branded(_ table: [String: String], english: [String: String])
        -> (strings: [String: String], fallback: [String: String]) {
        let brand = table[brandKey] ?? english[brandKey] ?? ""
        return (fill(table, brand: brand), fill(english, brand: brand))
    }

    private static func fill(_ table: [String: String], brand: String) -> [String: String] {
        table.mapValues { $0.contains(brandToken) ? $0.replacingOccurrences(of: brandToken, with: brand) : $0 }
    }

    #if DEBUG
    /// Once per key and language: a view body asks for its strings on every
    /// render, and a file that is still being translated misses hundreds.
    private func reportMissing(_ key: String) {
        let tag = "\(currentLanguage):\(key)"
        missingLock.lock()
        let isNew = reportedMissing.insert(tag).inserted
        missingLock.unlock()
        guard isNew else { return }
        Self.log.debug("Missing key \(key, privacy: .public) in \(self.currentLanguage, privacy: .public)")
    }
    #endif

    fileprivate static func url(for language: String, in bundle: Bundle) -> URL? {
        // Try subdirectory first, fall back to bundle root (depends on how xcodegen copies resources)
        bundle.url(forResource: language, withExtension: "json", subdirectory: "Localization")
            ?? bundle.url(forResource: language, withExtension: "json")
    }

    private static func loadJSON(_ language: String) -> [String: String]? {
        guard
            let url = url(for: language, in: .main),
            let data = try? Data(contentsOf: url),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return nil }
        return dict
    }
}

// MARK: - String Extension

extension String {
    /// Returns the localized value for this key from the active JSON file,
    /// else English, else the key itself.
    var l: String { LocalizationManager.shared.string(for: self) }
}

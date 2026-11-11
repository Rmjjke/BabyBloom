import XCTest
@testable import BabyBloom

/// Which language the app speaks: the device's preferred-language list, a
/// stored choice, a per-app choice made in iOS Settings, the shipped files,
/// and what a key no file has reads as.
final class LanguageResolutionTests: XCTestCase {
    private let all = SupportedLanguage.allCases

    // MARK: Device list

    func testRegionalVariantsResolveOverTheWholeList() {
        let rows: [([String], SupportedLanguage)] = [
            (["pt"], .ptBR), (["pt-BR"], .ptBR),
            (["pt-PT"], .ptPT), (["pt-AO"], .ptPT),
            (["nb"], .nb), (["no"], .nb), (["nn-NO"], .nb),
            (["zh-TW"], .zhHant), (["zh-HK"], .zhHant), (["zh-MO"], .zhHant), (["zh-Hant-TW"], .zhHant),
            (["it", "de"], .de),
            (["es-ES"], .es), (["es-MX"], .es),
            (["fr-CA"], .fr),
            (["ru-UA"], .ru),
            (["uk-UA"], .uk), (["ja-JP"], .ja), (["ko-KR"], .ko),
            (["en-GB"], .en), (["it"], .en),
        ]
        for (preferred, expected) in rows {
            XCTAssertEqual(SupportedLanguage.resolve(preferred: preferred, available: all), expected, "\(preferred)")
        }
    }

    /// Scripts are never crossed: a Simplified-only device reads English, as
    /// its App Store page does, and reaches a later language in its list.
    func testSimplifiedChineseFallsBackRatherThanToTraditional() {
        for preferred in [["zh-Hans"], ["zh-Hans-CN"], ["zh-CN"], ["zh-Hans", "en"]] {
            XCTAssertEqual(SupportedLanguage.resolve(preferred: preferred, available: all), .en, "\(preferred)")
        }
        XCTAssertEqual(SupportedLanguage.resolve(preferred: ["zh-Hans", "ja"], available: all), .ja)
    }

    // MARK: Shipped files

    func testALanguageWithNoFileIsNotOffered() {
        let shipped = SupportedLanguage.available { $0 == .ru || $0 == .ptBR }
        XCTAssertEqual(shipped, [.en, .ru, .ptBR])
        XCTAssertEqual(SupportedLanguage.resolve(preferred: ["de", "ja"], available: shipped), .en)
        XCTAssertEqual(SupportedLanguage.resolve(preferred: ["de", "pt"], available: shipped), .ptBR)
        // The other region of the same language beats English, as iOS's own
        // matcher has it.
        XCTAssertEqual(SupportedLanguage.resolve(preferred: ["de", "pt-PT"], available: shipped), .ptBR)
    }

    func testEnglishIsAlwaysAvailable() {
        XCTAssertEqual(SupportedLanguage.available { _ in false }, [.en])
    }

    func testTheBundleShipsTheLaunchLanguages() {
        XCTAssertTrue(Set(SupportedLanguage.available).isSuperset(of: [.en, .ru, .es]))
    }

    // MARK: Stored choice

    /// A choice stored by an earlier version outranks the device.
    func testAStoredChoiceWinsOverTheDevice() {
        for stored in ["en", "ru", "es"] {
            XCTAssertEqual(LocalizationManager.resolveStored([stored], preferred: ["de-DE"], available: all).rawValue,
                           stored)
        }
        XCTAssertEqual(LocalizationManager.resolveStored([nil, "es", "ru"], preferred: ["de"], available: all), .es)
    }

    func testAStoredLanguageThatNoLongerShipsFallsThroughToTheDevice() {
        let shipped: [SupportedLanguage] = [.en, .ru, .es]
        XCTAssertEqual(LocalizationManager.resolveStored(["ja"], preferred: ["ru-RU"], available: shipped), .ru)
        XCTAssertEqual(LocalizationManager.resolveStored(["xx", "ja"], preferred: ["fr"], available: shipped), .en)
        XCTAssertEqual(LocalizationManager.resolveStored([nil, nil], preferred: ["es-MX"], available: shipped), .es)
    }

    // MARK: Per-app Language in iOS Settings

    func testAPerAppLanguageChangedSinceTheLastLaunchIsAdopted() {
        XCTAssertEqual(LocalizationManager.perAppLanguageChange(current: ["de-DE"], seen: [], device: ["fr"],
                                                                available: all), .de)
        XCTAssertEqual(LocalizationManager.perAppLanguageChange(current: ["pt-AO"], seen: ["ru"], device: ["fr"],
                                                                available: all), .ptPT)
    }

    /// Set back to the device's language in iOS Settings: the per-app list is
    /// gone, and the device list is the choice.
    func testAPerAppLanguageSetBackToTheDeviceAdoptsTheDevice() {
        XCTAssertEqual(LocalizationManager.perAppLanguageChange(current: nil, seen: ["ru"], device: ["fr-CA"],
                                                                available: all), .fr)
        XCTAssertEqual(LocalizationManager.perAppLanguageChange(current: [], seen: ["ru"], device: ["en-GB"],
                                                                available: all), .en)
    }

    func testNoChangeOrNoRecordAdoptsNothing() {
        // First launch that records: a 1.2.0 user's stored choice stays.
        XCTAssertNil(LocalizationManager.perAppLanguageChange(current: ["de"], seen: nil, device: ["fr"], available: all))
        XCTAssertNil(LocalizationManager.perAppLanguageChange(current: ["de"], seen: ["de"], device: ["fr"], available: all))
        XCTAssertNil(LocalizationManager.perAppLanguageChange(current: nil, seen: [], device: ["fr"], available: all))
        XCTAssertNil(LocalizationManager.perAppLanguageChange(current: nil, seen: nil, device: ["fr"], available: all))
    }

    // MARK: Missing keys

    func testAMissingKeyReadsEnglishThenTheKey() {
        let english = ["a": "A", "b": "B"]
        XCTAssertEqual(LocalizationManager.lookup("a", in: ["a": "А"], english: english), "А")
        XCTAssertEqual(LocalizationManager.lookup("b", in: ["a": "А"], english: english), "B")
        XCTAssertEqual(LocalizationManager.lookup("c", in: ["a": "А"], english: english), "c")
    }

    /// A language with no file at all reads English, not raw keys.
    func testALanguageWithoutAFileReadsEnglish() throws {
        let original = LocalizationManager.shared.language
        defer { LocalizationManager.shared.setLanguage(original) }
        LocalizationManager.shared.setLanguage(.en)
        let english = "tab.feeding".l
        XCTAssertNotEqual(english, "tab.feeding")
        // Once every language ships, `testAMissingKeyReadsEnglishThenTheKey`
        // carries the rule alone.
        guard let missing = SupportedLanguage.allCases.first(where: { !SupportedLanguage.hasFile($0) }) else {
            throw XCTSkip("every language ships a file")
        }
        LocalizationManager.shared.setLanguage(missing)
        XCTAssertEqual("tab.feeding".l, english)
    }

    // MARK: Picker

    func testThePickerListsTheCurrentLanguageFirstThenByOwnName() {
        let order = SupportedLanguage.pickerOrder(current: .ru, available: all).map(\.endonym)
        XCTAssertEqual(order, [
            "Русский",
            "Dansk", "Deutsch", "English", "Español", "Français", "Norsk bokmål",
            "Português (Brasil)", "Português (Portugal)", "Suomi", "Svenska",
            "Українська", "日本語", "繁體中文", "한국어",
        ])
        XCTAssertEqual(SupportedLanguage.pickerOrder(current: .es, available: [.en, .ru, .es]), [.es, .en, .ru])
    }

    // MARK: Calendar and typesetting

    func testDatesAreGregorianWhateverTheDeviceCalendar() {
        for language in all {
            XCTAssertEqual(language.environmentCalendar.identifier, .gregorian, "\(language)")
            XCTAssertEqual(language.dateFormat.calendar.identifier, .gregorian, "\(language)")
        }
        // The date style starts Gregorian even from a locale that names
        // another calendar, the way a Japanese-calendar phone's does.
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let text = date.formatted(SupportedLanguage.dateFormat(locale: Locale(identifier: "en_US@calendar=japanese"))
            .day().month().year())
        XCTAssertTrue(text.contains("2026"), text)
        XCTAssertFalse(text.contains("Reiwa"), text)
    }

    func testTheTypesettingLanguageCarriesTheScript() {
        XCTAssertEqual(SupportedLanguage.ja.typesettingLanguage.languageCode, "ja")
        XCTAssertEqual(SupportedLanguage.zhHant.typesettingLanguage.languageCode, "zh")
        XCTAssertEqual(SupportedLanguage.zhHant.typesettingLanguage.script, "Hant")
    }
}

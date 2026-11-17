import XCTest
@testable import BabyBloom

/// The app's name is written once per language (`brand.name`) and filled into
/// every `{brand}` at load. A language that declines the name lists those
/// sentences in `brand-declined.txt` and writes the forms inline.
final class BrandTokenTests: XCTestCase {

    private let token = LocalizationManager.brandToken
    private let brandKey = LocalizationManager.brandKey

    // MARK: The fill

    func testTheTokenTakesTheLanguagesName() {
        let english = ["brand.name": "Bitty", "a": "In {brand}", "b": "Only {brand} here"]
        let spanish = ["brand.name": "Nenita", "a": "En {brand}"]
        let (strings, fallback) = LocalizationManager.branded(spanish, english: english)
        XCTAssertEqual(strings["a"], "En Nenita")
        // A key the language lacks reads English, still with the language's name.
        XCTAssertEqual(LocalizationManager.lookup("b", in: strings, english: fallback), "Only Nenita here")
        // A file with no name of its own takes English's.
        XCTAssertEqual(LocalizationManager.branded(["a": "En {brand}"], english: english).strings["a"], "En Bitty")
    }

    func testNoBraceSurvivesALoad() throws {
        let english = try table("en")
        for language in shipped {
            let (strings, fallback) = LocalizationManager.branded(try table(language), english: english)
            for (key, value) in strings.merging(fallback, uniquingKeysWith: { a, _ in a })
            where value.contains("{") || value.contains("}") {
                XCTFail("\(language) \(key): \(value)")
            }
        }
    }

    func testRenamingTheBrandRenamesEverySentence() throws {
        let english = try table("en")
        let sentences = english.filter { $0.value.contains(token) }.map(\.key)
        XCTAssertFalse(sentences.isEmpty)
        for language in ["en", "es"] {
            var renamed = try table(language)
            renamed[brandKey] = "Zyx"
            let (strings, _) = LocalizationManager.branded(renamed, english: english)
            for key in sentences {
                XCTAssertTrue(strings[key]?.contains("Zyx") == true, "\(language) \(key) kept the old name")
            }
        }
    }

    // MARK: The shipped files

    /// Each sentence English writes with `{brand}` holds the token, or is a
    /// declared declined form. No sentence types any language's name by hand:
    /// that is how a Spanish fact once said "Bitty".
    func testEverySentenceNamesTheAppByTokenOrADeclaredForm() throws {
        let english = try table("en")
        let declined = try declinedForms()
        let names = try Set(shipped.compactMap { try table($0)[brandKey] })
        for language in shipped {
            let strings = try table(language)
            for (key, englishValue) in english where englishValue.contains(token) {
                guard let value = strings[key] else { continue }
                let isDeclined = declined.contains("\(language) \(key)")
                XCTAssertNotEqual(value.contains(token), isDeclined,
                                  isDeclined ? "\(language) \(key): declared declined but holds \(token)"
                                             : "\(language) \(key): names the app without \(token)")
            }
            for (key, value) in strings where key != brandKey {
                for name in names where value.contains(name) {
                    XCTFail("\(language) \(key): types \"\(name)\" instead of \(token)")
                }
            }
            // A declined form keeps the name's stem: renaming the app in a
            // declining language fails here until its forms are rewritten.
            let stem = String(try XCTUnwrap(strings[brandKey]).dropLast())
            for (key, value) in strings where declined.contains("\(language) \(key)") && !value.contains(stem) {
                XCTFail("\(language) \(key): declined form without \"\(stem)\"")
            }
        }
        for entry in declined {
            let parts = entry.split(separator: " ").map(String.init)
            XCTAssertEqual(parts.count, 2, "brand-declined.txt: \"\(entry)\"")
            guard parts.count == 2 else { continue }
            XCTAssertTrue(shipped.contains(parts[0]), "brand-declined.txt: \(parts[0]) ships no file")
            XCTAssertTrue(english[parts[1]]?.contains(token) == true,
                          "brand-declined.txt: \(parts[1]) does not name the app in en")
        }
    }

    /// The name goes into sentences that later pass through `String(format:)`.
    func testTheNameIsSafeToFillIn() throws {
        for language in shipped {
            let name = try XCTUnwrap(try table(language)[brandKey], "\(language): no \(brandKey)")
            XCTAssertFalse(name.isEmpty || name.contains("%") || name.contains("{") || name.contains("}"),
                           "\(language): \(brandKey) \"\(name)\"")
        }
    }

    /// These two send the parent to a row in iOS Settings, which carries the
    /// display name. A declined form (ru «для Ночки») names the app, not the row.
    func testTheSettingsRowStringsCarryTheDisplayName() throws {
        let english = try table("en")
        let declined = try declinedForms()
        for language in shipped {
            let displayName = try XCTUnwrap(try infoPlistStrings(language)["CFBundleDisplayName"])
            let strings = LocalizationManager.branded(try table(language), english: english).strings
            for key in ["medication.reminder_off_in_settings", "settings.live_activity_off_in_ios"]
            where !declined.contains("\(language) \(key)") {
                XCTAssertTrue(strings[key]?.contains(displayName) == true, "\(language) \(key) lacks \"\(displayName)\"")
            }
        }
    }

    // MARK: Files

    private var shipped: [String] { SupportedLanguage.available.map(\.rawValue) }

    private func table(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "json"),
                                "\(language).json is not in the app bundle")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private func declinedForms() throws -> Set<String> {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "brand-declined", withExtension: "txt"),
                                "brand-declined.txt is not in the app bundle")
        return Set(try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") })
    }

    private func infoPlistStrings(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: nil, localization: language),
            "\(language).lproj/InfoPlist.strings is not in the app bundle")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
    }
}

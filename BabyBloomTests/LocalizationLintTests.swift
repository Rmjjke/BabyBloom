import XCTest
@testable import BabyBloom

/// The rules every language file keeps, checked over every shipped language
/// against English:
/// - no key English lacks, and — for a language in `complete-languages.txt` —
///   no key missing; plural families (`age.day.one`, `.few`, …) compare by
///   their base name, so a language's own categories are not read as extras;
/// - the same arguments with the same types as English in every value (`%d`
///   read as `%@` crashes `String(format:)`); in a format string, never
///   positional and plain mixed, no stray `%`;
/// - `{brand}` is the only `{…}` token, with no stray brace; no value is empty;
/// - the widget's copies are byte-equal to the app's, and each language's
///   `InfoPlist.strings` has English's keys and a display name equal to
///   `brand.name`.
///
/// What it cannot see: layout (the fit tests), formatting that comes from the
/// environment locale (dates, numbers), and which plural categories a
/// language's rule allows — a family is compared by name only.
final class LocalizationLintTests: XCTestCase {

    // MARK: Shipped files

    private func table(_ language: String, in bundle: Bundle = .main) throws -> [String: String] {
        let url = try XCTUnwrap(bundle.url(forResource: language, withExtension: "json"),
                                "\(language).json is not in \(bundle.bundleURL.lastPathComponent)")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private var shipped: [String] { SupportedLanguage.available.map(\.rawValue) }

    private func completeLanguages() throws -> [String] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "complete-languages", withExtension: "txt"),
                                "complete-languages.txt is not in the app bundle")
        return try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    func testEveryShippedLanguageKeepsTheRules() throws {
        let english = try table("en")
        let complete = Set(try completeLanguages())
        for language in shipped {
            let problems = LocalizationLint.problems(in: try table(language), english: english,
                                                     complete: complete.contains(language))
            XCTAssertEqual(problems, [], "\(language): \(problems.count) problem(s)")
        }
    }

    func testTheCompleteSetNamesShippedLanguagesOnly() throws {
        let complete = try completeLanguages()
        XCTAssertTrue(complete.contains("en"), "English is the fallback and always complete")
        XCTAssertEqual(complete.count, Set(complete).count, "a language listed twice")
        for code in complete {
            XCTAssertNotNil(SupportedLanguage(rawValue: code), "\(code): not a supported language")
            XCTAssertTrue(shipped.contains(code), "\(code): listed as complete but no file ships")
        }
    }

    /// The missing keys of every shipped language, by name — attached to the
    /// run and printed, so a language being translated shows what is left.
    func testCompletenessReport() throws {
        let english = try table("en")
        var lines: [String] = []
        for language in shipped {
            let missing = LocalizationLint.missingKeys(in: try table(language), english: english)
            lines.append("\(language): \(missing.count) missing" + (missing.isEmpty ? "" : " — " + missing.joined(separator: ", ")))
        }
        let report = lines.joined(separator: "\n")
        print("LOCALIZATION_COMPLETENESS\n\(report)")
        let attachment = XCTAttachment(string: report)
        attachment.name = "Localization completeness"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The widget renders from its own copy; the build's pre-build check
    /// catches drift too, this catches it in a run that skipped that phase.
    func testTheWidgetCopiesAreByteEqual() throws {
        let widget = try XCTUnwrap(
            Bundle.main.builtInPlugInsURL.flatMap { Bundle(url: $0.appendingPathComponent("BabyBloomWidget.appex")) },
            "the widget extension is not in the app bundle")
        for language in shipped {
            let app = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "json"))
            let copy = try XCTUnwrap(widget.url(forResource: language, withExtension: "json"),
                                     "\(language).json has no widget copy")
            XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: app), "\(language): widget copy differs")
        }
        let widgetLanguages = (widget.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent }
        XCTAssertEqual(Set(widgetLanguages), Set(shipped), "the widget holds a language the app does not ship")
    }

    func testEveryLanguageNamesTheAppInItsInfoPlist() throws {
        let english = try infoPlistStrings("en")
        for language in shipped {
            let problems = LocalizationLint.infoPlistProblems(try infoPlistStrings(language), english: english,
                                                              brandName: try table(language)["brand.name"])
            XCTAssertEqual(problems, [], "\(language): InfoPlist.strings")
        }
    }

    /// Compiled into a binary plist in the bundle; `NSDictionary` reads either form.
    private func infoPlistStrings(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: nil, localization: language),
            "\(language).lproj/InfoPlist.strings is not in the app bundle")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "\(language): unreadable InfoPlist.strings")
    }

    // MARK: Each rule fails on its own fixture

    private let english: [String: String] = [
        "brand.name": "Bitty",
        "plain": "Weight is 10% below birth weight",
        "count_fmt": "%d feeds",
        "pair_fmt": "%@ at %@",
        "percent_fmt": "%d%% of birth weight",
        "dose.one": "%d dose",
        "dose.many": "%d doses",
    ]

    private func problems(_ table: [String: String], complete: Bool = true) -> [String] {
        LocalizationLint.problems(in: table, english: english, complete: complete)
    }

    func testTheFixtureItselfPasses() {
        XCTAssertEqual(problems(english), [])
        // A plain string's % is text: "10% del" never goes through String(format:).
        var spanish = english
        spanish["plain"] = "Un 10% del peso al nacer"
        spanish["pair_fmt"] = "%2$@, %1$@"
        spanish["count_fmt"] = "%1$d tomas (%1$d)"
        XCTAssertEqual(problems(spanish), [])
    }

    func testAMissingKeyFailsACompleteLanguageOnly() {
        var table = english
        table["count_fmt"] = nil
        XCTAssertEqual(problems(table), ["count_fmt: missing"])
        XCTAssertEqual(problems(table, complete: false), [])
        XCTAssertEqual(LocalizationLint.missingKeys(in: table, english: english), ["count_fmt"])
    }

    func testPluralFamiliesCompareByBaseName() {
        var table = english
        table["dose.many"] = nil
        table["dose.few"] = "%d doses"
        table["dose.other"] = "%d doses"
        XCTAssertEqual(problems(table), [])
        table["dose.one"] = nil
        table["dose.few"] = nil
        table["dose.other"] = nil
        XCTAssertEqual(problems(table), ["dose: missing"])
    }

    func testAKeyEnglishLacksFails() {
        var table = english
        table["stale.key"] = "Old"
        XCTAssertEqual(problems(table, complete: false), ["stale.key: not in English"])
    }

    func testAWrongArgumentTypeFails() {
        var table = english
        table["count_fmt"] = "%@ feeds"
        XCTAssertEqual(problems(table), ["count_fmt: arguments [1@], English [1d]"])
    }

    func testAMissingOrAddedArgumentFails() {
        var table = english
        table["pair_fmt"] = "%@"
        table["dose.one"] = "%d dose of %@"
        XCTAssertEqual(problems(table), ["dose.one: arguments [1d, 2@], English [1d]",
                                         "pair_fmt: arguments [1@], English [1@, 2@]"])
    }

    func testAPluralFormMayDropItsNumber() {
        var table = english
        table["dose.one"] = "One dose"
        XCTAssertEqual(problems(table), [])
    }

    func testMixingPositionalAndPlainFails() {
        var table = english
        table["pair_fmt"] = "%2$@ at %@"
        XCTAssertEqual(problems(table), ["pair_fmt: positional and plain arguments mixed"])
    }

    func testAStrayPercentInAFormatStringFails() {
        var table = english
        table["percent_fmt"] = "%d% of birth weight"
        XCTAssertEqual(problems(table), ["percent_fmt: a stray %"])
    }

    func testOnlyTheBrandTokenIsAllowed() {
        var table = english
        table["plain"] = "{brand} keeps {count} feeds"
        XCTAssertEqual(problems(table), ["plain: token {count}"])
        table["plain"] = "{brand} keeps feeds"
        XCTAssertEqual(problems(table), [])
        table["plain"] = "{{brand}} keeps feeds"
        XCTAssertEqual(problems(table), ["plain: a stray brace"])
    }

    func testAPlainStringGainingAnArgumentFails() {
        var table = english
        table["plain"] = "%@ weighs 10% less"
        XCTAssertEqual(problems(table), ["plain: arguments [1@], English []"])
    }

    func testADisplayNameUnlikeTheBrandFails() {
        let english = ["CFBundleDisplayName": "Bitty", "NSFaceIDUsageDescription": "Unlock"]
        XCTAssertEqual(LocalizationLint.infoPlistProblems(english, english: english, brandName: "Bitty"), [])
        let russian = ["CFBundleDisplayName": "Bitty"]
        XCTAssertEqual(LocalizationLint.infoPlistProblems(russian, english: english, brandName: "Ночка"),
                       ["CFBundleDisplayName: Bitty, brand.name Ночка", "NSFaceIDUsageDescription: missing"])
    }

    func testAnEmptyValueFails() {
        var table = english
        table["plain"] = " "
        XCTAssertEqual(problems(table), ["plain: empty"])
    }
}

/// The rules over in-memory tables, so each one has a fixture of its own.
enum LocalizationLint {
    static let pluralCategories: Set<String> = ["zero", "one", "two", "few", "many", "other"]

    /// `age.day.few` → `age.day`; a key with no category suffix is its own base.
    static func base(of key: String) -> String {
        guard let dot = key.lastIndex(of: "."), pluralCategories.contains(String(key[key.index(after: dot)...])) else {
            return key
        }
        return String(key[..<dot])
    }

    /// The home-screen name is `brand.name`; every permission prompt English has.
    static func infoPlistProblems(_ strings: [String: String], english: [String: String], brandName: String?) -> [String] {
        var found = Set(english.keys).subtracting(strings.keys).map { "\($0): missing" }
        found += Set(strings.keys).subtracting(english.keys).map { "\($0): not in English" }
        if strings["CFBundleDisplayName"] != brandName {
            found.append("CFBundleDisplayName: \(strings["CFBundleDisplayName"] ?? "none"), brand.name \(brandName ?? "none")")
        }
        return found.sorted()
    }

    static func missingKeys(in table: [String: String], english: [String: String]) -> [String] {
        let present = Set(table.keys.map(base))
        return Set(english.keys.map(base)).subtracting(present).sorted()
    }

    static func problems(in table: [String: String], english: [String: String], complete: Bool) -> [String] {
        var found: [String] = complete ? missingKeys(in: table, english: english).map { "\($0): missing" } : []
        let englishBases = Dictionary(grouping: english.keys, by: base)
        for (key, value) in table {
            guard let family = englishBases[base(of: key)] else {
                found.append("\(key): not in English")
                continue
            }
            found += problems(key: key, value: value, english: family.compactMap { english[$0] },
                              isFamily: base(of: key) != key)
        }
        return found.sorted()
    }

    private static func problems(key: String, value: String, english: [String], isFamily: Bool) -> [String] {
        var found: [String] = []
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { found.append("\(key): empty") }
        let tokens = tokens(value)
        for token in tokens where token != "{brand}" { found.append("\(key): token \(token)") }
        // "{{brand}}" holds a valid token and still renders "{Bitty}".
        if tokens.reduce(value, { $0.replacingOccurrences(of: $1, with: "") }).contains(where: { "{}".contains($0) }) {
            found.append("\(key): a stray brace")
        }

        let reference = english.map(scan)
        let own = scan(value)
        // A value is a format string when English formats it; a plain
        // string's "%" is text and never reaches String(format:). Arguments
        // are compared everywhere, so a translation cannot add one either.
        if key.hasSuffix("_fmt") || reference.contains(where: { !$0.arguments.isEmpty || $0.escapes }) {
            if own.mixed { found.append("\(key): positional and plain arguments mixed") }
            if own.stray { found.append("\(key): a stray %") }
        }
        if isFamily {
            // A plural form may drop its number ("One dose"), never add one.
            let allowed = Set(reference.flatMap(\.arguments))
            if !Set(own.arguments).isSubset(of: allowed) {
                found.append("\(key): arguments \(list(own.arguments)), English \(list(allowed.sorted()))")
            }
        } else if let first = reference.first, own.arguments != first.arguments {
            found.append("\(key): arguments \(list(own.arguments)), English \(list(first.arguments))")
        }
        return found
    }

    private static func list(_ arguments: [String]) -> String { "[" + arguments.joined(separator: ", ") + "]" }

    private static func tokens(_ value: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "\\{[^{}]*\\}")
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
            .compactMap { Range($0.range, in: value).map { String(value[$0]) } }
    }

    /// Each argument as position + type ("1d", "2@"), sorted, so a translation
    /// may reorder with `%2$@` but not change what it reads. The space flag is
    /// left out on purpose: "10% of" would read as `% o`, so a `%` followed by
    /// a space counts as stray in a format string and as text elsewhere.
    struct Scan { var arguments: [String]; var mixed: Bool; var stray: Bool; var escapes: Bool }

    private static let specifier = try! NSRegularExpression(
        pattern: "%(?:(%)|(\\d+\\$)?[-+0#']*\\d*(?:\\.\\d+)?(?:hh|h|ll|l|q|z|t|j|L)?([@dDiuUxXoOfFeEgGaAcCsSp]))")

    static func scan(_ value: String) -> Scan {
        var result = Scan(arguments: [], mixed: false, stray: false, escapes: false)
        var next = 0, positional = false, plain = false, covered = 0
        let ns = value as NSString
        for match in specifier.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
            covered += ns.substring(with: match.range).filter { $0 == "%" }.count
            if match.range(at: 1).location != NSNotFound { result.escapes = true; continue }
            let position: Int
            if match.range(at: 2).location != NSNotFound {
                positional = true
                position = Int(ns.substring(with: match.range(at: 2)).dropLast()) ?? 0
            } else {
                plain = true
                next += 1
                position = next
            }
            let type = ns.substring(with: match.range(at: 3))
            result.arguments.append("\(position)\(["D": "d", "i": "d", "U": "u"][type] ?? type)")
        }
        // "%1$@ … %1$@" reads one argument twice: still one argument.
        result.arguments = Set(result.arguments).sorted()
        result.mixed = positional && plain
        result.stray = value.filter { $0 == "%" }.count > covered
        return result
    }
}

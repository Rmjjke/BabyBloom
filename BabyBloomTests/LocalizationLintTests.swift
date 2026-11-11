import XCTest
@testable import BabyBloom

/// The rules every language file keeps, checked over every shipped language
/// against English:
/// - no key English lacks, and — for a language in `complete-languages.txt` —
///   no key missing;
/// - plural families: a key `<family>.<category>` belongs to a family only when
///   `<family>` is a `PluralFamily`, and families compare by `<family>.#`, so a
///   language's own categories are not extras and a plain `x` never merges
///   with `x.other`. English holds exactly the families the code reads; a
///   complete language holds `.other` plus every category its rule selects for
///   the numbers the family shows; no language holds a category its rule never
///   names; every family value takes exactly one argument of the family's kind;
/// - the same arguments with the same types as English in every other value
///   (`%d` read as `%@` crashes `String(format:)`); in a format string, never
///   positional and plain mixed, no stray `%`, and every argument numbered
///   (`%1$@`) when there are two or more, so a translation may reorder them;
/// - `{brand}` is the only `{…}` token, with no stray brace; no value is empty;
/// - ja and zh-Hant write no space between a number and a counter or between
///   Han/Kana and Latin text; ko none between a number and its counter;
/// - the widget's copies are byte-equal to the app's, and each language's
///   `InfoPlist.strings`, in the app and in the widget, has a display name
///   equal to `brand.name` and no key English lacks — and, for a complete
///   language, every key English has.
///
/// What it cannot see: layout (the fit tests) and formatting that comes from
/// the environment locale (dates, numbers).
final class LocalizationLintTests: XCTestCase {

    // MARK: Shipped files

    private func table(_ language: String, in bundle: Bundle = .main) throws -> [String: String] {
        let url = try XCTUnwrap(bundle.url(forResource: language, withExtension: "json"),
                                "\(language).json is not in \(bundle.bundleURL.lastPathComponent)")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private var shipped: [SupportedLanguage] { SupportedLanguage.available }

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
            let problems = LocalizationLint.problems(in: try table(language.rawValue), english: english,
                                                     complete: complete.contains(language.rawValue),
                                                     language: language)
            XCTAssertEqual(problems, [], "\(language.rawValue): \(problems.count) problem(s)")
        }
    }

    /// Code and copy cannot drift: a family the code reads has English copy,
    /// and English holds no family the code does not know.
    func testEnglishHoldsExactlyTheFamiliesTheCodeReads() throws {
        XCTAssertEqual(LocalizationLint.familyProblems(english: try table("en")), [])
    }

    func testTheCompleteSetNamesShippedLanguagesOnly() throws {
        let complete = try completeLanguages()
        XCTAssertTrue(complete.contains("en"), "English is the fallback and always complete")
        XCTAssertEqual(complete.count, Set(complete).count, "a language listed twice")
        for code in complete {
            XCTAssertNotNil(SupportedLanguage(rawValue: code), "\(code): not a supported language")
            XCTAssertTrue(shipped.map(\.rawValue).contains(code), "\(code): listed as complete but no file ships")
        }
    }

    /// The missing keys of every shipped language, by name — attached to the
    /// run and printed, so a language being translated shows what is left.
    func testCompletenessReport() throws {
        let english = try table("en")
        var lines: [String] = []
        for language in shipped {
            let missing = LocalizationLint.missingKeys(in: try table(language.rawValue), english: english)
            lines.append("\(language.rawValue): \(missing.count) missing" + (missing.isEmpty ? "" : " — " + missing.joined(separator: ", ")))
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
        for language in shipped.map(\.rawValue) {
            let app = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "json"))
            let copy = try XCTUnwrap(widget.url(forResource: language, withExtension: "json"),
                                     "\(language).json has no widget copy")
            XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: app), "\(language): widget copy differs")
        }
        let widgetLanguages = (widget.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .map { $0.deletingPathExtension().lastPathComponent }
        XCTAssertEqual(Set(widgetLanguages), Set(shipped.map(\.rawValue)), "the widget holds a language the app does not ship")
    }

    /// A language still being translated holds only the prompts it has: iOS
    /// reads the base Info.plist's English for the rest.
    func testEveryLanguageNamesTheAppInItsInfoPlist() throws {
        let english = try infoPlistStrings("en")
        let complete = Set(try completeLanguages())
        for language in shipped.map(\.rawValue) {
            let problems = LocalizationLint.infoPlistProblems(try infoPlistStrings(language), english: english,
                                                              brandName: try table(language)["brand.name"],
                                                              complete: complete.contains(language))
            XCTAssertEqual(problems, [], "\(language): InfoPlist.strings")
        }
    }

    /// The widget's `.lproj` is what lists the language among the extension's
    /// own localizations; its name follows the app's.
    func testEveryLanguageNamesTheWidgetInItsInfoPlist() throws {
        let widget = try XCTUnwrap(
            Bundle.main.builtInPlugInsURL.flatMap { Bundle(url: $0.appendingPathComponent("BabyBloomWidget.appex")) },
            "the widget extension is not in the app bundle")
        let english = try infoPlistStrings("en", in: widget)
        for language in shipped.map(\.rawValue) {
            let problems = LocalizationLint.infoPlistProblems(try infoPlistStrings(language, in: widget), english: english,
                                                              brandName: try table(language)["brand.name"])
            XCTAssertEqual(problems, [], "\(language): the widget's InfoPlist.strings")
        }
        XCTAssertEqual(Set(widget.localizations.filter { $0 != "Base" }), Set(shipped.map(\.rawValue)),
                       "the widget's localizations differ from the shipped languages")
    }

    /// Compiled into a binary plist in the bundle; `NSDictionary` reads either form.
    private func infoPlistStrings(_ language: String, in bundle: Bundle = .main) throws -> [String: String] {
        let url = try XCTUnwrap(
            bundle.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: nil, localization: language),
            "\(language).lproj/InfoPlist.strings is not in \(bundle.bundleURL.lastPathComponent)")
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String], "\(language): unreadable InfoPlist.strings")
    }

    // MARK: Each rule fails on its own fixture

    private let english: [String: String] = [
        "brand.name": "Bitty",
        "plain": "Weight is 10% below birth weight",
        "count_fmt": "%d feeds",
        "pair_fmt": "%1$@ at %2$@",
        "percent_fmt": "%d%% of birth weight",
        "question.count.one": "%d question",
        "question.count.other": "%d questions",
        "trend.drop.other": "Dropped about %@ centile spaces.",
    ]

    private let russian: [String: String] = [
        "brand.name": "Ночка",
        "plain": "Вес на 10% ниже веса при рождении",
        "count_fmt": "%d кормлений",
        "pair_fmt": "%1$@ в %2$@",
        "percent_fmt": "%d%% от веса при рождении",
        "question.count.one": "%d вопрос",
        "question.count.few": "%d вопроса",
        "question.count.many": "%d вопросов",
        "question.count.other": "%d вопроса",
        "trend.drop.other": "Снижение примерно на %@ коридора.",
    ]

    private func problems(_ table: [String: String], complete: Bool = true,
                          language: SupportedLanguage = .en) -> [String] {
        LocalizationLint.problems(in: table, english: english, complete: complete, language: language)
    }

    func testTheFixtureItselfPasses() {
        XCTAssertEqual(problems(english), [])
        XCTAssertEqual(problems(russian, language: .ru), [])
        // A plain string's % is text: "10% del" never goes through String(format:).
        var spanish = english
        spanish["plain"] = "Un 10% del peso al nacer"
        spanish["pair_fmt"] = "%2$@, %1$@"
        spanish["count_fmt"] = "%1$d tomas (%1$d)"
        spanish["trend.drop.one"] = "Ha bajado alrededor de %@ espacio."
        XCTAssertEqual(problems(spanish, language: .es), [])
    }

    func testAMissingKeyFailsACompleteLanguageOnly() {
        var table = english
        table["count_fmt"] = nil
        XCTAssertEqual(problems(table), ["count_fmt: missing"])
        XCTAssertEqual(problems(table, complete: false), [])
        XCTAssertEqual(LocalizationLint.missingKeys(in: table, english: english), ["count_fmt"])
    }

    /// ru's `.few/.many` and es's `trend.drop.one` are the language's own
    /// categories of an English family, never keys English lacks.
    func testPluralFamiliesCompareByFamilyBase() {
        XCTAssertEqual(problems(russian, complete: false, language: .ru), [])
        var table = english
        table["question.count.other"] = nil
        XCTAssertEqual(problems(table), ["question.count.other: missing"])
        // An incomplete language with a family's .other has the family.
        var partial = russian
        partial["question.count.many"] = nil
        partial["question.count.few"] = nil
        partial["question.count.one"] = nil
        XCTAssertEqual(LocalizationLint.missingKeys(in: partial, english: english), [])
        partial["question.count.other"] = nil
        partial["question.count.one"] = "%d вопрос"
        XCTAssertEqual(LocalizationLint.missingKeys(in: partial, english: english), ["question.count.other"])
    }

    /// A complete ru without `.many` would show the `.other` (genitive
    /// singular) form for 25: «25 вопроса».
    func testACompleteLanguageHoldsEveryCategoryItsRuleSelects() {
        var table = russian
        table["question.count.many"] = nil
        XCTAssertEqual(problems(table, language: .ru), ["question.count.many: missing"])
        XCTAssertEqual(problems(table, complete: false, language: .ru), [])
        // es selects .one for «1,0», so a complete es needs trend.drop.one; en never does.
        var spanish = english
        XCTAssertEqual(problems(spanish, language: .es), ["trend.drop.one: missing"])
        spanish["trend.drop.one"] = "Ha bajado alrededor de %@ espacio."
        XCTAssertEqual(problems(spanish, language: .es), [])
        // Whole millions (es and fr .many) are out of every family's range.
        XCTAssertEqual(LocalizationLint.requiredCategories(.questionCount, .fr), [.one, .other])
        XCTAssertEqual(LocalizationLint.requiredCategories(.trendDrop, .en), [.other])
        XCTAssertEqual(LocalizationLint.requiredCategories(.trendDrop, .da), [.one, .other])
        XCTAssertEqual(LocalizationLint.requiredCategories(.ageDays, .ru), [.one, .few, .many, .other])
        XCTAssertEqual(LocalizationLint.requiredCategories(.ageDays, .ja), [.other])
    }

    func testACategoryTheRuleNeverNamesFails() {
        var table = english
        table["question.count.few"] = "%d questions"
        XCTAssertEqual(problems(table), ["question.count.few: en never selects few"])
    }

    func testAPlainKeyNeverMergesWithAFamily() {
        var table = english
        table["question.count"] = "%d questions"
        XCTAssertEqual(problems(table), ["question.count: collides with the family question.count"])
        // A category word on a name the code reads as no family is a plain key.
        var stray = english
        stray["dose.other"] = "%d doses"
        XCTAssertEqual(problems(stray, complete: false), ["dose.other: not in English"])
        XCTAssertTrue(LocalizationLint.familyProblems(english: stray).contains("dose.other: no plural family of that name"))
    }

    func testEnglishMustHoldEveryFamily() {
        let expected = PluralFamily.allCases.filter { ![.questionCount, .trendDrop].contains($0) }
            .map { "\($0.rawValue): no English copy" }
        XCTAssertEqual(LocalizationLint.familyProblems(english: english), expected.sorted())
    }

    func testAFamilyValueTakesExactlyOneArgumentOfItsKind() {
        var table = english
        table["question.count.one"] = "One question"
        XCTAssertEqual(problems(table), ["question.count.one: arguments [], the family takes [1d]"])
        table["question.count.one"] = "%1$d question of %2$@"
        XCTAssertEqual(problems(table), ["question.count.one: arguments [1d, 2@], the family takes [1d]"])
        table = english
        table["trend.drop.other"] = "Dropped about %d centile spaces."
        XCTAssertEqual(problems(table), ["trend.drop.other: arguments [1d], the family takes [1@]"])
        table["trend.drop.other"] = "Dropped about %1$@ centile spaces."
        XCTAssertEqual(problems(table), [])
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
        table["count_fmt"] = "%1$d feeds of %2$@"
        XCTAssertEqual(problems(table), ["count_fmt: arguments [1d, 2@], English [1d]",
                                         "pair_fmt: arguments [1@], English [1@, 2@]"])
    }

    func testMixingPositionalAndPlainFails() {
        var table = english
        table["pair_fmt"] = "%2$@ at %@"
        XCTAssertEqual(problems(table), ["pair_fmt: positional and plain arguments mixed"])
    }

    func testSeveralArgumentsMustBeNumbered() {
        var table = english
        table["pair_fmt"] = "%@ at %@"
        XCTAssertEqual(problems(table), ["pair_fmt: plain arguments in a string with several"])
        // A translation may reorder numbered arguments; one argument needs no number.
        table["pair_fmt"] = "%2$@ — %1$@"
        table["count_fmt"] = "%1$d feeds"
        XCTAssertEqual(problems(table), [])
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
        // A language being translated may lack a prompt, never the name or a key English lacks.
        let ukrainian = ["CFBundleDisplayName": "Нічка", "NSCameraUsageDescription": "Камера"]
        XCTAssertEqual(LocalizationLint.infoPlistProblems(ukrainian, english: english, brandName: "Нічка", complete: false),
                       ["NSCameraUsageDescription: not in English"])
        XCTAssertEqual(LocalizationLint.infoPlistProblems(["CFBundleDisplayName": "Bitty"], english: english,
                                                          brandName: "Нічка", complete: false),
                       ["CFBundleDisplayName: Bitty, brand.name Нічка"])
    }

    func testAnEmptyValueFails() {
        var table = english
        table["plain"] = " "
        XCTAssertEqual(problems(table), ["plain: empty"])
    }

    // MARK: Number and counter in ja, ko, zh-Hant

    func testJapaneseAndChineseWriteNoSpaceAroundANumberOrLatinText() {
        for language in [SupportedLanguage.ja, .zhHant] {
            XCTAssertEqual(LocalizationLint.cjkSpacingProblems(
                ["age.days.other": "生後%d日", "trend.drop.other": "%@ポイント", "plain": "在{brand}中", "count_fmt": "共%d天"],
                language: language), [], "\(language)")
            XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["age.days.other": "%d\u{00A0}日"], language: language),
                           ["age.days.other: a space in \"%d\u{00A0}日\""], "\(language)")
            XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["count_fmt": "共 %d 天"], language: language),
                           ["count_fmt: a space in \"%d 天\"", "count_fmt: a space in \"共 %d\""], "\(language)")
            XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["plain": "在 {brand} 中"], language: language),
                           ["plain: a space in \"} 中\"", "plain: a space in \"在 {\""], "\(language)")
            XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["plain": "7\u{2009}日間"], language: language),
                           ["plain: a space in \"7\u{2009}日\""], "\(language)")
        }
    }

    func testKoreanWritesNoSpaceBetweenANumberAndItsCounter() {
        XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["age.days.other": "생후 %d일", "plain": "Bitty 앱"],
                                                           language: .ko), [])
        XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["age.days.other": "생후 %d 일"], language: .ko),
                       ["age.days.other: a space in \"%d 일\""])
        // Every other language may space as it likes.
        XCTAssertEqual(LocalizationLint.cjkSpacingProblems(["age.days.other": "%d 日"], language: .en), [])
    }

    func testTheSpacingRuleRunsWithTheOthers() {
        var table = english
        table["question.count.one"] = nil  // ja names .other only
        table["count_fmt"] = "%d 回"
        XCTAssertEqual(problems(table, complete: false, language: .ja), ["count_fmt: a space in \"%d 回\""])
    }
}

/// The rules over in-memory tables, so each one has a fixture of its own.
enum LocalizationLint {

    /// `age.days.few` → (ageDays, few); nil for a key outside every family,
    /// a category word on an unknown name included.
    static func member(_ key: String) -> (family: PluralFamily, category: PluralCategory)? {
        guard let dot = key.lastIndex(of: "."),
              let category = PluralCategory(rawValue: String(key[key.index(after: dot)...])),
              let family = PluralFamily(rawValue: String(key[..<dot])) else { return nil }
        return (family, category)
    }

    /// `age.days.few` → `age.days.#`; any other key is its own base, so a
    /// plain `x` and the family `x` are two entries, never one.
    static func base(of key: String) -> String {
        member(key).map { "\($0.family.rawValue).#" } ?? key
    }

    /// `.other` plus every category the language's rule selects for a number
    /// the family can show: whole numbers 0…999, or 0.0…99.9 at the family's
    /// digits. Whole millions (es, fr `.many`) are out of range on purpose:
    /// lookup falls back to `.other` there.
    static func requiredCategories(_ family: PluralFamily, _ language: SupportedLanguage) -> Set<PluralCategory> {
        var found: Set<PluralCategory> = [.other]
        switch family.kind {
        case .integer:
            for n in 0...999 { found.insert(language.pluralCategory(PluralOperands(n))) }
        case .decimal(let digits):
            let scale = Int(pow(10, Double(digits)))
            for k in 0..<(100 * scale) {
                found.insert(language.pluralCategory(PluralOperands(Double(k) / Double(scale), fractionDigits: digits)))
            }
        }
        return found
    }

    /// English is the family list's other half: every `PluralFamily` has its
    /// `.other`, and no key with a category word names a family the code lacks.
    static func familyProblems(english: [String: String]) -> [String] {
        var found = PluralFamily.allCases.filter { english[$0.key(.other)] == nil }.map { "\($0.rawValue): no English copy" }
        for key in english.keys where member(key) == nil {
            if let dot = key.lastIndex(of: "."), PluralCategory(rawValue: String(key[key.index(after: dot)...])) != nil {
                found.append("\(key): no plural family of that name")
            }
        }
        return found.sorted()
    }

    /// The home-screen name is `brand.name`; a complete language has every
    /// permission prompt English has.
    static func infoPlistProblems(_ strings: [String: String], english: [String: String], brandName: String?,
                                  complete: Bool = true) -> [String] {
        var found = complete ? Set(english.keys).subtracting(strings.keys).map { "\($0): missing" } : []
        found += Set(strings.keys).subtracting(english.keys).map { "\($0): not in English" }
        if strings["CFBundleDisplayName"] != brandName {
            found.append("CFBundleDisplayName: \(strings["CFBundleDisplayName"] ?? "none"), brand.name \(brandName ?? "none")")
        }
        return found.sorted()
    }

    /// A family counts as present by its `.other`, the one category every
    /// language holds; it is named by that key.
    static func missingKeys(in table: [String: String], english: [String: String]) -> [String] {
        let present = Set(table.keys.compactMap { key -> String? in
            guard let member = member(key) else { return key }
            return member.category == .other ? base(of: key) : nil
        })
        return Set(english.keys.map(base)).subtracting(present)
            .map { $0.hasSuffix(".#") ? String($0.dropLast(2)) + ".other" : $0 }
            .sorted()
    }

    static func problems(in table: [String: String], english: [String: String], complete: Bool,
                         language: SupportedLanguage) -> [String] {
        var found: [String] = complete ? missingKeys(in: table, english: english).map { "\($0): missing" } : []
        let englishBases = Dictionary(grouping: english.keys, by: base)
        for (key, value) in table {
            if PluralFamily(rawValue: key) != nil {
                found.append("\(key): collides with the family \(key)")
                continue
            }
            guard let family = englishBases[base(of: key)] else {
                found.append("\(key): not in English")
                continue
            }
            if let member = member(key), !language.pluralCategories.contains(member.category) {
                found.append("\(key): \(language.rawValue) never selects \(member.category.rawValue)")
            }
            found += problems(key: key, value: value, english: family.compactMap { english[$0] })
        }
        if complete {
            // `.other` is already in the missing keys above.
            for family in PluralFamily.allCases where english[family.key(.other)] != nil {
                for category in requiredCategories(family, language).subtracting([.other])
                where table[family.key(category)] == nil {
                    found.append("\(family.key(category)): missing")
                }
            }
        }
        found += cjkSpacingProblems(table, language: language)
        return found.sorted()
    }

    private static func problems(key: String, value: String, english: [String]) -> [String] {
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
            if own.plain && !own.mixed && Set(own.arguments.map { $0.dropLast() }).count > 1 {
                found.append("\(key): plain arguments in a string with several")
            }
        }
        if let member = member(key) {
            // The category, not the copy, picks the word for the number, so
            // every form shows it: «один вопрос» would read for 21 too.
            let expected = member.family.arguments
            if own.arguments != expected {
                found.append("\(key): arguments \(list(own.arguments)), the family takes \(list(expected))")
            }
        } else if let first = reference.first, own.arguments != first.arguments {
            found.append("\(key): arguments \(list(own.arguments)), English \(list(first.arguments))")
        }
        return found
    }

    // MARK: Number and counter in ja, ko, zh-Hant

    private static let number = "(?:\\d|%(?:\\d+\\$)?[d@])"
    private static let space = "[ \\u00A0\\u2009\\u202F\\u3000]+"
    private static let hanKana = "[\\p{Han}\\p{Hiragana}\\p{Katakana}\\u30FC]"
    // `{brand}` reads as Latin text; the `d` of `%d` / `%1$d` is the number's, not a word.
    private static let latin = "(?:(?<!%)(?<!\\$)[A-Za-z]|\\{|\\})"

    private static let spacingRules: [SupportedLanguage: [NSRegularExpression]] = {
        let hanRules = [
            "\(number)\(space)\(hanKana)", "\(hanKana)\(space)\(number)",
            "\(latin)\(space)\(hanKana)", "\(hanKana)\(space)\(latin)",
        ].map { try! NSRegularExpression(pattern: $0) }
        let korean = [try! NSRegularExpression(pattern: "\(number)\(space)\\p{Hangul}")]
        return [.ja: hanRules, .zhHant: hanRules, .ko: korean]
    }()

    /// Apple's ja and zh-TW strings write «7日», «在Bitty中»; ko spaces words
    /// but writes «7일». The space is the template's, so the template is checked.
    static func cjkSpacingProblems(_ table: [String: String], language: SupportedLanguage) -> [String] {
        guard let rules = spacingRules[language] else { return [] }
        var found: [String] = []
        for (key, value) in table {
            let ns = value as NSString
            for rule in rules {
                for match in rule.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
                    found.append("\(key): a space in \"\(ns.substring(with: match.range))\"")
                }
            }
        }
        return found.sorted()
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
    struct Scan { var arguments: [String]; var mixed: Bool; var plain: Bool; var stray: Bool; var escapes: Bool }

    private static let specifier = try! NSRegularExpression(
        pattern: "%(?:(%)|(\\d+\\$)?[-+0#']*\\d*(?:\\.\\d+)?(?:hh|h|ll|l|q|z|t|j|L)?([@dDiuUxXoOfFeEgGaAcCsSp]))")

    static func scan(_ value: String) -> Scan {
        var result = Scan(arguments: [], mixed: false, plain: false, stray: false, escapes: false)
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
        result.plain = plain
        result.stray = value.filter { $0 == "%" }.count > covered
        return result
    }
}

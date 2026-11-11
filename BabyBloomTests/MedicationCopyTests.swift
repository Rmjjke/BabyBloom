import XCTest
@testable import BabyBloom

/// The medication strings against the safety word list in
/// teamdocs/content/medications.md: the app counts the time between doses
/// and never prescribes, so no string tells a parent to give, allows a dose
/// or calls one safe or early. A word added to the list there is added here.
final class MedicationCopyTests: XCTestCase {

    private static let languages = ["en", "ru", "es"]

    /// Whole words, case-insensitive. Kept narrow on purpose: «не раньше»
    /// and «Последняя» are fine, «рано» and «можно» are not.
    private static let safetyWords: [String: String] = [
        "en": "give|gives|giving|gave|given|allowed|allow|should|must|safe|safely|unsafe|recommend\\w*|advise\\w*"
            + "|too|early|overdose\\w*|warning|danger\\w*|time for|you can",
        "ru": "да(?:й|йте|ть|вать|ём|ли|дим|дите)|можно|нельзя|пора|разреш\\w*|рекоменд\\w*|следует|стоит|должн\\w*"
            + "|безопасн\\w*|опасн\\w*|рано|передозиров\\w*|предупрежд\\w*|внимание|норм\\w*",
        "es": "da|dar|dale|darle|dado|dada|dele|puedes|puede|permitid\\w*|debes|debe|debería|conviene|segur[oa]s?"
            + "|peligr\\w*|recomend\\w*|pronto|demasiado|sobredosis|advertencia|toca|es hora",
    ]

    /// The CSV columns live under `export.csv.*` but belong to the feature.
    private static let extraKeys = ["export.csv.medication", "export.csv.dose"]

    /// Reads the shipped JSON itself: `LocalizationManager` answers one key
    /// at a time and cannot list a prefix.
    private func strings(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: language, withExtension: "json", subdirectory: "Localization")
                ?? Bundle.main.url(forResource: language, withExtension: "json"),
            "\(language).json is not in the app bundle")
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private func medicationKeys(_ strings: [String: String]) -> [String] {
        strings.keys.filter { $0.hasPrefix("medication.") || $0.hasPrefix("notification.medication_") }.sorted()
    }

    /// A plural family's keys read as its `.other` key: each language holds
    /// the categories its own rule selects (ru `.few`, `.many`).
    private func byFamily(_ keys: [String]) -> Set<String> {
        let members = Dictionary(uniqueKeysWithValues: PluralFamily.allCases.flatMap { family in
            PluralCategory.allCases.map { (family.key($0), family.key(.other)) }
        })
        return Set(keys.map { members[$0] ?? $0 })
    }

    /// Each specifier as (position, type): "%@ … %d" and "%1$@ … %2$d" give the
    /// same list, so a translation may reorder its arguments but not change them.
    private func placeholders(_ value: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: "%(\\d+\\$)?[-+ 0#]*\\d*(?:\\.\\d+)?l{0,2}([@dfsu])")
        var next = 0
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { match in
            let position: Int
            if let r = Range(match.range(at: 1), in: value) {
                position = Int(value[r].dropLast()) ?? 0
            } else {
                next += 1
                position = next
            }
            let type = Range(match.range(at: 2), in: value).map { String(value[$0]) } ?? ""
            return "\(position)\(type)"
        }.sorted()
    }

    func testNoMedicationStringTellsTheParentWhatToGive() throws {
        for language in Self.languages {
            let all = try strings(language)
            let keys = medicationKeys(all)
            XCTAssertFalse(keys.isEmpty, "\(language): no medication strings")
            let words = try XCTUnwrap(Self.safetyWords[language])
            // `\b` is ASCII-only for Cyrillic in some engines: lookarounds on letters instead.
            let regex = try NSRegularExpression(
                pattern: "(?<![\\p{L}\\p{N}_])(?:\(words))(?![\\p{L}\\p{N}_])", options: [.caseInsensitive])
            for key in keys {
                let value = all[key] ?? ""
                let hit = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value))
                XCTAssertNil(hit.flatMap { Range($0.range, in: value).map { String(value[$0]) } },
                             "\(language) \(key): a word from the safety list")
                XCTAssertFalse(value.contains("!"), "\(language) \(key): an exclamation mark")
            }
        }
    }

    func testEveryLanguageHasEveryMedicationKeyWithTheSameArguments() throws {
        let en = try strings("en")
        let enKeys = medicationKeys(en) + Self.extraKeys
        for language in Self.languages {
            let other = try strings(language)
            XCTAssertEqual(byFamily(medicationKeys(other) + Self.extraKeys), byFamily(enKeys), "\(language): key sets differ")
            for key in enKeys {
                let value = try XCTUnwrap(other[key], "\(language) \(key): missing")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language) \(key): empty")
                // A specifier the translation lacks or adds crashes String(format:).
                XCTAssertEqual(try placeholders(value), try placeholders(en[key] ?? ""), "\(language) \(key): arguments")
            }
        }
    }

    func testANumberInAMedicationStringIsGluedToItsUnit() throws {
        let plainSpaceAfterDigit = try NSRegularExpression(pattern: "\\d ")
        for language in Self.languages {
            let all = try strings(language)
            for key in medicationKeys(all) {
                let value = all[key] ?? ""
                XCTAssertNil(plainSpaceAfterDigit.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                             "\(language) \(key): a plain space after a number («24 hours»)")
            }
        }
    }
}

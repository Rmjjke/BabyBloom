import XCTest
@testable import BabyBloom

/// The two debug pseudo-languages: what each does to a value, what it must
/// leave alone, and that the release picker can never offer one.
final class PseudoLanguageTests: XCTestCase {

    static func json(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: language, withExtension: "json", subdirectory: "Localization")
            ?? Bundle.main.url(forResource: language, withExtension: "json"))
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private func specifiers(_ value: String) -> [String] {
        PseudoLanguage.spans(value).filter(\.1).map(\.0).sorted()
    }

    func testEveryValueKeepsItsSpecifiersAndTokens() throws {
        let english = try Self.json("en")
        for language in PseudoLanguage.allCases {
            let table = PseudoLanguage.table(from: english, language)
            XCTAssertEqual(Set(table.keys), Set(english.keys))
            for (key, value) in english {
                XCTAssertEqual(specifiers(table[key]!), specifiers(value), "\(language.rawValue) \(key)")
            }
        }
    }

    func testEnXALengthensEveryWordAndBrackets() {
        XCTAssertEqual(PseudoLanguage.enXA.transform("Save"), "[Šáávéé]")
        // ⌈0.4 × 5⌉ = 2 extra letters; vowels doubled in turn.
        XCTAssertEqual(PseudoLanguage.enXA.transform("Sleep"), "[Šléééép]")
        // No vowel: the letters themselves are doubled.
        XCTAssertEqual(PseudoLanguage.enXA.transform("PDF"), "[PPDDF]")
        XCTAssertEqual(PseudoLanguage.enXA.transform("%d\u{00A0}days"), "[%d\u{00A0}dááýýš]")
        XCTAssertEqual(PseudoLanguage.enXA.transform("{brand} %1$@"), "[{brand} %1$@]")
    }

    func testEnXAGrowsAboutFortyPercent() throws {
        let english = try Self.json("en")
        let table = PseudoLanguage.table(from: english, .enXA)
        let before = english.values.reduce(0) { $0 + $1.count }
        let after = table.values.reduce(0) { $0 + $1.count }
        XCTAssertGreaterThan(Double(after) / Double(before), 1.3)
    }

    func testJaXBIsFullWidthWithoutSpaces() throws {
        XCTAssertEqual(PseudoLanguage.jaXB.transform("Log a feed"), "「Ｌｏｇａｆｅｅｄ」")
        XCTAssertEqual(PseudoLanguage.jaXB.transform("%@ ate %d\u{00A0}ml!"), "「%@ａｔｅ%d\u{00A0}ｍｌ！」")
        let table = PseudoLanguage.table(from: try Self.json("en"), .jaXB)
        XCTAssertFalse(table.values.contains { $0.contains(" ") })
    }

    func testPluralFamiliesReadThroughTheBaseRule() throws {
        let english = try Self.json("en")
        let table = PseudoLanguage.table(from: english, .jaXB)
        // ja's rule names only .other, so one day reads English's .other template.
        let template = LocalizationManager.pluralTemplate(.ageDays, PluralOperands(1), language: .ja,
                                                          in: table, english: english)
        XCTAssertEqual(template, table["age.days.other"])
    }

    func testThePickerNeverOffersAPseudoLanguage() {
        let manager = LocalizationManager.shared
        let before = manager.currentLanguage
        defer { manager.setPseudo(nil); manager.setLanguage(before) }
        for pseudo in PseudoLanguage.allCases {
            XCTAssertNil(SupportedLanguage(rawValue: pseudo.rawValue))
            manager.setPseudo(pseudo)
            XCTAssertEqual(manager.language, pseudo.base)
            XCTAssertFalse(SupportedLanguage.available.map(\.rawValue).contains(pseudo.rawValue))
            let order = SupportedLanguage.pickerOrder(current: manager.language, available: SupportedLanguage.available)
            XCTAssertFalse(order.map(\.rawValue).contains(pseudo.rawValue))
            // A stored pseudo code is never kept: it resolves to a shipped language.
            XCTAssertTrue(SupportedLanguage.available.contains(LocalizationManager.effective(pseudo.rawValue)))
        }
    }

    func testTheOverrideReplacesTheTableAndGoesAway() {
        let manager = LocalizationManager.shared
        let before = manager.currentLanguage
        defer { manager.setPseudo(nil); manager.setLanguage(before) }
        manager.setLanguage(.en)
        manager.setPseudo(.enXA)
        XCTAssertTrue("button.save".l.hasPrefix("["))
        manager.setPseudo(.jaXB)
        XCTAssertTrue("button.save".l.hasPrefix("「"))
        manager.setPseudo(nil)
        XCTAssertEqual(manager.language, .en)
        XCTAssertFalse("button.save".l.hasPrefix("["))
    }
}

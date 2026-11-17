import XCTest
@testable import BabyBloom

/// The CLDR cardinal rules of the 15 languages, the operands of a number as
/// shown, and the lookup chain of a plural family.
final class PluralRulesTests: XCTestCase {

    private func category(_ language: SupportedLanguage, _ n: Int) -> PluralCategory {
        language.pluralCategory(PluralOperands(n))
    }

    private func category(_ language: SupportedLanguage, _ shown: String) -> PluralCategory {
        language.pluralCategory(PluralOperands(posix: shown))
    }

    // MARK: The acceptance rows

    func testZeroAndOneAreSingularInFrenchAndBrazilianPortuguese() {
        for language in [SupportedLanguage.fr, .ptBR] {
            XCTAssertEqual(category(language, 0), .one, "\(language)")
            XCTAssertEqual(category(language, 1), .one, "\(language)")
            XCTAssertEqual(category(language, 2), .other, "\(language)")
        }
        XCTAssertEqual(category(.fr, "1.0"), .one)
        XCTAssertEqual(category(.fr, "1.5"), .one)
        XCTAssertEqual(category(.fr, "2.0"), .other)
    }

    func testRussianAndUkrainianSplitOneFewMany() {
        for language in [SupportedLanguage.ru, .uk] {
            XCTAssertEqual(category(language, 21), .one, "\(language)")
            XCTAssertEqual(category(language, 22), .few, "\(language)")
            XCTAssertEqual(category(language, 25), .many, "\(language)")
            XCTAssertEqual(category(language, "1.5"), .other, "\(language)")
        }
        XCTAssertEqual(category(.ru, "1.0"), .other)
    }

    func testJapaneseKoreanAndChineseHaveOnlyOther() {
        for language in [SupportedLanguage.ja, .ko, .zhHant] {
            for n in [0, 1, 2, 5, 21, 100] { XCTAssertEqual(category(language, n), .other, "\(language) \(n)") }
            XCTAssertEqual(category(language, "1.0"), .other, "\(language)")
            XCTAssertEqual(language.pluralCategories, [.other])
        }
    }

    /// The centile-drop flag shows one decimal from 1,0 up.
    func testTheTrendDropRows() {
        XCTAssertEqual(category(.es, "1.0"), .one)
        XCTAssertEqual(category(.es, "1.5"), .other)
        XCTAssertEqual(category(.nb, "1.0"), .one)
        XCTAssertEqual(category(.da, "1.5"), .one)
        XCTAssertEqual(category(.ptPT, "1.0"), .other)
        XCTAssertEqual(category(.en, "1.0"), .other)
        XCTAssertEqual(category(.de, "1.0"), .other)
    }

    /// The flag as shown: the digits pick the form, so 0.96 reads singular.
    /// Latin American Spanish writes a decimal point.
    func testTheTrendDropSentenceInSpanish() {
        let previous = LocalizationManager.shared.currentLanguage
        defer { LocalizationManager.shared.setLanguage(previous) }
        LocalizationManager.shared.setLanguage("es")
        let tail = " de percentil. Conviene comentarlo con el pediatra."
        XCTAssertEqual(PluralFamily.trendDrop.text(1.0), "Ha bajado alrededor de\u{00A0}1.0\u{00A0}espacio" + tail)
        XCTAssertEqual(PluralFamily.trendDrop.text(0.96), "Ha bajado alrededor de\u{00A0}1.0\u{00A0}espacio" + tail)
        XCTAssertEqual(PluralFamily.trendDrop.text(1.5), "Ha bajado alrededor de\u{00A0}1.5\u{00A0}espacios" + tail)
    }

    // MARK: CLDR samples

    /// The integer samples CLDR lists for each category, per rule family.
    func testTheCLDRIntegerSamples() {
        let samples: [(languages: [SupportedLanguage], rows: [PluralCategory: [Int]])] = [
            ([.en, .de, .sv, .fi, .nb], [.one: [1], .other: [0, 2, 3, 16, 100, 1000, 1_000_000]]),
            ([.da], [.one: [1], .other: [0, 2, 16, 100]]),
            ([.es, .ptPT], [.many: [1_000_000, 2_000_000], .other: [0, 2, 16, 100, 1000, 10_000]]),
            ([.fr, .ptBR], [.one: [0, 1], .many: [1_000_000], .other: [2, 16, 100, 1000]]),
            ([.ru, .uk], [.one: [1, 21, 31, 101, 1001], .few: [2, 3, 4, 22, 24, 102, 1002],
                          .many: [0, 5, 11, 12, 14, 19, 20, 100, 111, 112, 1000]]),
        ]
        XCTAssertEqual(category(.es, 1), .one)
        XCTAssertEqual(category(.ptPT, 1), .one)
        for sample in samples {
            for language in sample.languages {
                for (expected, numbers) in sample.rows {
                    for n in numbers {
                        XCTAssertEqual(category(language, n), expected, "\(language) \(n)")
                    }
                }
            }
        }
    }

    func testEveryLanguageSelectsOnlyItsOwnCategories() {
        let shown = (0...300).map(String.init) + (0...300).map { String(format: "%.1f", Double($0) / 10) }
        for language in SupportedLanguage.allCases {
            let selected = Set(shown.map { category(language, $0) } + [category(language, 1_000_000)])
            XCTAssertEqual(selected, language.pluralCategories, "\(language)")
        }
    }

    // MARK: Operands

    func testTheOperandsOfANumberAsShown() {
        let x = PluralOperands(posix: "1.50")
        XCTAssertEqual([x.i, x.v, x.f, x.t], [1, 2, 50, 5])
        XCTAssertEqual(x.n, 1.5)
        let whole = PluralOperands(21)
        XCTAssertEqual([whole.i, whole.v, whole.f, whole.t], [21, 0, 0, 0])
        XCTAssertEqual(PluralOperands(-3).i, 3)
    }

    /// The category follows the digits the screen shows, not the raw value.
    func testADecimalTakesTheCategoryOfItsRoundedForm() {
        XCTAssertEqual(PluralOperands.posixString(0.96, fractionDigits: 1), "1.0")
        XCTAssertEqual(SupportedLanguage.es.pluralCategory(PluralOperands(0.96, fractionDigits: 1)), .one)
        XCTAssertEqual(SupportedLanguage.es.pluralCategory(PluralOperands(1.04, fractionDigits: 1)), .one)
        XCTAssertEqual(SupportedLanguage.es.pluralCategory(PluralOperands(1.06, fractionDigits: 1)), .other)
        // The POSIX digits equal the localized digits for every shipped language.
        for value in [0.04, 0.96, 1.05, 1.15, 2.25, 2.35, 13.45] {
            for language in SupportedLanguage.allCases {
                let formatter = NumberFormatter()
                formatter.locale = language.locale
                formatter.numberStyle = .decimal
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
                formatter.usesGroupingSeparator = false
                let localized = formatter.string(from: value as NSNumber)!
                let digits = localized.replacingOccurrences(of: formatter.decimalSeparator, with: ".")
                XCTAssertEqual(digits, PluralOperands.posixString(value, fractionDigits: 1), "\(language) \(value)")
            }
        }
    }

    // MARK: Lookup

    func testALeftOutCategoryFallsBackToOther() {
        let family = PluralFamily.durationDays
        let spanish = [family.key(.one): "%d día", family.key(.other): "%d días"]
        let english = [family.key(.one): "%d day", family.key(.other): "%d days"]
        func template(_ n: Int, _ language: SupportedLanguage, _ table: [String: String]) -> String {
            LocalizationManager.pluralTemplate(family, PluralOperands(n), language: language, in: table, english: english)
        }
        XCTAssertEqual(template(1, .es, spanish), "%d día")
        XCTAssertEqual(template(1_000_000, .es, spanish), "%d días")
        // A language with no family at all reads English, by English's rule.
        XCTAssertEqual(template(1, .ru, [:]), "%d day")
        XCTAssertEqual(template(0, .fr, [:]), "%d days")
        XCTAssertEqual(template(5, .ru, [family.key(.one): "%d день", family.key(.other): "%d дня"]), "%d дня")
        // French .many (whole millions) left out reads .other, not English.
        let french = [family.key(.one): "%d jour", family.key(.other): "%d jours"]
        XCTAssertEqual(template(1_000_000, .fr, french), "%d jours")
        XCTAssertEqual(template(0, .fr, french), "%d jour")
        XCTAssertEqual(LocalizationManager.pluralTemplate(family, PluralOperands(1), language: .en, in: [:], english: [:]),
                       "duration.days.other")
    }

    func testEveryFamilyNamesItsKind() {
        XCTAssertEqual(PluralFamily.trendDrop.kind, .decimal(fractionDigits: 1))
        for family in PluralFamily.allCases where family != .trendDrop {
            XCTAssertEqual(family.kind, .integer, "\(family)")
        }
        XCTAssertEqual(PluralFamily.ageDays.key(.many), "age.days.many")
    }
}

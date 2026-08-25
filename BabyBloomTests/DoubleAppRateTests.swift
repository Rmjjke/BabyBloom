import XCTest
@testable import BabyBloom

/// Guards the rule `Double.appRate` exists to enforce, which has now been got
/// wrong twice: a measured rate must NEVER display as a bound it sits below.
///
/// The verdict rendered beside the rate compares the RAW value against a whole
/// bound, so any display rounding that can reach the bound produces a line that
/// refutes itself — "8 a day · below the reference" against a reference of
/// 8–12. `%.0f` had a 0.5-wide window for this; `maximumFractionDigits = 1`
/// with the default half-even rounding still had a 0.05-wide one. Only
/// `roundingMode = .down` closes it.
///
/// These tests fail if that rounding mode is removed. That is their whole job.
final class DoubleAppRateTests: XCTestCase {

    /// The feeding table's lower bounds. Every one of them has a reachable
    /// strip of values just beneath it.
    private let bounds: [Double] = [8, 7, 6, 5, 4]

    private var original: SupportedLanguage!

    override func setUp() {
        super.setUp()
        original = LocalizationManager.shared.language
        LocalizationManager.shared.setLanguage("en")
    }

    /// Restored so this suite cannot leak a language into its neighbours —
    /// several of them assert on localized output and run in the same process.
    override func tearDown() {
        LocalizationManager.shared.setLanguage(original)
        super.tearDown()
    }

    // MARK: - The rule

    /// The case whose absence let the defect through twice.
    ///
    /// This input is reachable, not theoretical: `feedingsPerDay` divides by the
    /// raw un-floored interval between two weighings, so 20 feeds over 2.5157
    /// days is 7.950073…, which the previous implementation rendered as "8"
    /// while the verdict beside it read "below the reference".
    ///
    /// Pinned as an exact string because here the exact string IS the property.
    func testJustBelowABoundNeverRendersAsTheBound() {
        XCTAssertEqual((7.95).appRate, "7.9")
        XCTAssertEqual((7.96).appRate, "7.9")
        XCTAssertEqual((20.0 / 2.5157).appRate, "7.9")

        XCTAssertNotEqual((7.95).appRate, "8", "a below-bound rate displayed AS the bound")
        XCTAssertNotEqual((7.96).appRate, "8", "a below-bound rate displayed AS the bound")
    }

    /// The same rule stated as the property it protects, across every bound in
    /// the feeding table: whatever a sub-bound value renders as, reading that
    /// rendering back must not reach the bound. Catches a rounding mode that
    /// happens to be right at 8 but wrong elsewhere.
    func testNoValueBelowABoundEverReadsBackAtOrAboveIt() {
        for bound in bounds {
            for delta in [0.001, 0.01, 0.04, 0.05, 0.06, 0.4] {
                let value = bound - delta
                let rendered = value.appRate

                XCTAssertNotEqual(rendered, "\(Int(bound))",
                                  "\(value) rendered as the bound itself (\(rendered))")

                let readBack = Double(rendered.replacingOccurrences(of: ",", with: "."))
                XCTAssertNotNil(readBack, "unparseable rendering: \(rendered)")
                XCTAssertLessThan(readBack!, bound,
                                  "\(value) rendered as \(rendered), which reads back at or above \(bound)")
            }
        }
    }

    // MARK: - What the rounding mode must NOT break

    /// Why `minimumFractionDigits` is 0: "9 a day" reads better than "9.0".
    func testWholeValuesStayWhole() {
        XCTAssertEqual((9.0).appRate, "9")
        XCTAssertEqual((8.0).appRate, "8")
        XCTAssertEqual((12.0).appRate, "12")
        XCTAssertEqual((4.0).appRate, "4")
    }

    /// A genuine fraction must survive intact — truncating is aimed at the
    /// near-miss strip, not at fractions in general.
    func testGenuineFractionSurvives() {
        XCTAssertEqual((7.6).appRate, "7.6")
        XCTAssertEqual((10.5).appRate, "10.5")
    }

    // MARK: - Language, not device

    /// The separator follows the app's chosen language. Asserted as a property
    /// — "ru uses a comma, en and es use a period" — rather than by pinning the
    /// whole string, and deliberately NOT assuming es behaves like ru: Spanish
    /// is pinned to `es_419`, which takes a period.
    func testSeparatorFollowsTheAppLanguageNotTheDevice() {
        LocalizationManager.shared.setLanguage("ru")
        let ru = (7.6).appRate
        XCTAssertTrue(ru.contains(","), "ru should use a comma, got \(ru)")
        XCTAssertFalse(ru.contains("."), "ru leaked a period, got \(ru)")

        LocalizationManager.shared.setLanguage("en")
        let en = (7.6).appRate
        XCTAssertTrue(en.contains("."), "en should use a period, got \(en)")

        LocalizationManager.shared.setLanguage("es")
        let es = (7.6).appRate
        XCTAssertTrue(es.contains("."), "es is pinned to es_419, which uses a period, got \(es)")

        XCTAssertNotEqual(ru, en, "ru and en rendered identically — the locale never took")
    }

    /// Switching the language must change what the SAME value renders as,
    /// otherwise the helper could be caching the first locale it saw.
    func testRenderingTracksLanguageChanges() {
        LocalizationManager.shared.setLanguage("en")
        let first = (7.6).appRate
        LocalizationManager.shared.setLanguage("ru")
        let second = (7.6).appRate
        LocalizationManager.shared.setLanguage("en")
        let third = (7.6).appRate

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, third, "switching back did not restore the English rendering")
    }

    /// The rule must hold in every language, not just the one the separator
    /// tests happen to run in.
    func testTheRuleHoldsInEveryLanguage() {
        for language in SupportedLanguage.allCases {
            LocalizationManager.shared.setLanguage(language)
            let rendered = (7.95).appRate
            XCTAssertNotEqual(rendered, "8",
                              "\(language.rawValue) displayed a below-bound rate as the bound")
            XCTAssertTrue(rendered.hasPrefix("7"),
                          "\(language.rawValue) rendered 7.95 as \(rendered)")
        }
    }
}

import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The onboarding texts set beside an icon or a switch break between words,
/// never inside one. Where a word misses its column, every card of the page
/// sets its text under its icon, the optional-measure switch goes under its
/// title, and the feeding hint takes a smaller size; where the words fit, the
/// shape is the beside one at every text size.
@MainActor
final class OnboardingWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    // MARK: - The welcome cards

    /// A 272-pt window at Large leaves a title about 76 pt beside its badge and
    /// check. ru «Подгузники» (about 89) and es «crecimiento» (about 83) miss
    /// that, so every card sets its title under its badge, at the card's
    /// leading edge (the page's 24 and the card's 16); en «Feeding» (about 56)
    /// fits, so English keeps the titles beside, past the 42-pt badge.
    func testTheWelcomeTitlesGoUnderTheBadgesWhereAWordMisses() throws {
        try requireSize(.large)
        let screen = CGSize(width: 272, height: 1000)
        for (language, stacked) in [(SupportedLanguage.ru, true), (.en, false), (.es, true)] {
            LocalizationManager.shared.setLanguage(language)
            let titles = try texts(welcomeTitles(), in: page(WelcomePage(onStart: {}), screen), language.rawValue)
            assertShape(titles, stacked: stacked, under: 40, beside: 98, language.rawValue)
            assertWordsWhole(titles, welcomeFont, language.rawValue)
        }
    }

    // MARK: - The notifications bullets

    /// A 240-pt window at Large leaves a bullet 96 pt beside its icon. ru
    /// «подстраивается» (about 110) misses it, so all three go under their
    /// icons, at the card's leading edge (the page's 24 and the card's 24); en
    /// «suggested» (about 69) and es «calculamos» (about 74) fit, so English
    /// and Spanish keep them beside, past the 32-pt icon.
    func testTheNotificationBulletsGoUnderTheIconsWhereAWordMisses() throws {
        try requireSize(.large)
        let screen = CGSize(width: 240, height: 1400)
        for (language, stacked) in [(SupportedLanguage.ru, true), (.en, false), (.es, false)] {
            LocalizationManager.shared.setLanguage(language)
            let bullets = try texts(notificationBullets(),
                                    in: page(NotificationsPage(babyName: "Mia", onContinue: {}), screen),
                                    language.rawValue)
            assertShape(bullets, stacked: stacked, under: 48, beside: 96, language.rawValue)
            assertWordsWhole(bullets, bulletFont, language.rawValue)
        }
    }

    // MARK: - The optional-measure switch

    /// The switch beside its title and hint leaves them about 90 pt in a
    /// 240-pt window at Large: en «Circumference» (110), ru «Окружность» (97)
    /// and «корректированному» (118) miss it, so the switch goes under the
    /// hint at the title's x; en «Preterm» (58) and «compared» (55) fit, so
    /// the preterm switch in English stays beside. On a 320-pt screen every
    /// word fits and every switch stays beside.
    func testTheSwitchGoesUnderItsTitleWhereAWordMisses() throws {
        try requireSize(.large)
        let cases: [(width: CGFloat, language: SupportedLanguage, surface: Surface, stacked: Bool)] = [
            (240, .ru, .growthSwitch, true), (240, .en, .growthSwitch, true),
            (240, .ru, .birthSwitch, true), (240, .en, .birthSwitch, false),
            (320, .ru, .growthSwitch, false), (320, .en, .growthSwitch, false),
            (320, .ru, .birthSwitch, false), (320, .en, .birthSwitch, false),
        ]
        for c in cases {
            LocalizationManager.shared.setLanguage(c.language)
            let name = "\(c.language.rawValue) \(Int(c.width)) \(c.surface)"
            let screen = CGSize(width: c.width, height: 1400)
            try assertSwitch(c.surface, on: screen, stacked: c.stacked, name)
        }
    }

    // MARK: - The feeding rows

    /// A 250-pt window at Large leaves a name 72 pt beside its icon and the
    /// check, which every row keeps room for. ru «Смешанное» (about 98) misses
    /// it, so all three names go under their icons; en «Formula» and es
    /// «Fórmula» (about 64) fit, so English and Spanish keep the rows beside.
    func testTheFeedingNamesGoUnderTheIconsWhereAWordMisses() throws {
        try requireSize(.large)
        let screen = CGSize(width: 250, height: 1400)
        for (language, stacked) in [(SupportedLanguage.ru, true), (.en, false), (.es, false)] {
            LocalizationManager.shared.setLanguage(language)
            let elements = try page(feedingPage(), screen)
            try assertFeedingRows(in: elements, stacked: stacked, language.rawValue)
        }
    }

    // MARK: - The feeding hint

    /// ru «персонализированного» at AX2 (about 272 regular, 287 in Bold Text)
    /// misses a 260-pt column, and in Bold Text the 272 a 320-pt screen
    /// leaves, so the hint is set at the AX1 size, where it fits; a column
    /// too narrow for that too takes xxxLarge's. On 375 (327), at AX1 and in
    /// English and Spanish the hint keeps the reader's size.
    func testTheFeedingHintStepsDownOnlyWhereAWordMissesTheColumn() {
        let cases: [(language: SupportedLanguage, size: UIContentSizeCategory, column: CGFloat, bold: Bool,
                     setAt: UIContentSizeCategory)] = [
            (.ru, .accessibilityLarge, 272, true, .accessibilityMedium),
            (.ru, .accessibilityLarge, 260, false, .accessibilityMedium),
            (.ru, .accessibilityLarge, 230, false, .extraExtraExtraLarge),
            (.ru, .accessibilityLarge, 327, false, .accessibilityLarge),
            (.ru, .accessibilityLarge, 327, true, .accessibilityLarge),
            (.ru, .accessibilityMedium, 272, false, .accessibilityMedium),
            (.en, .accessibilityLarge, 260, false, .accessibilityLarge),
            (.es, .accessibilityLarge, 260, false, .accessibilityLarge),
        ]
        for c in cases {
            LocalizationManager.shared.setLanguage(c.language)
            let text = "onboarding.feeding_hint".l
            let name = "\(c.language.rawValue)\(c.bold ? " bold" : "") at \(c.size.rawValue) in \(Int(c.column))"
            let hint = height(of: FeedingHint(text: text, category: c.size), in: c.column, bold: c.bold)
            XCTAssertEqual(hint, height(of: plainHint(text, at: c.setAt), in: c.column, bold: c.bold),
                           accuracy: 0.5, name)
        }
        // The cases sit on the two sides of the word's width.
        let word = "персонализированного"
        XCTAssertGreaterThan(wordWidth(word, hintFont(.accessibilityLarge)), 260)
        XCTAssertLessThan(wordWidth(word, hintFont(.accessibilityLarge)), 272)
        XCTAssertGreaterThan(wordWidth(word, hintFont(.accessibilityLarge), bold: true), 272)
        XCTAssertLessThan(wordWidth(word, hintFont(.accessibilityLarge), bold: true), 327)
        XCTAssertLessThan(wordWidth(word, hintFont(.accessibilityMedium), bold: true), 272)
        XCTAssertGreaterThan(wordWidth(word, hintFont(.accessibilityMedium)), 230)
        XCTAssertLessThan(wordWidth(word, hintFont(.extraExtraExtraLarge)), 230)
    }

    // MARK: - The accessibility sizes on the phones

    /// Run with the simulator at AX1 (`content_size accessibility-medium`).
    func testEveryWordIsWholeAtAX1OnTheSmallPhones() throws {
        try requireSize(.accessibilityMedium)
        try assertEveryPage(at: .accessibilityMedium)
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testEveryWordIsWholeAtAX2OnTheSmallPhones() throws {
        try requireSize(.accessibilityLarge)
        try assertEveryPage(at: .accessibilityLarge)
    }

    /// The four surfaces and the preterm switch on a 320-pt screen (an SE
    /// with Display Zoom) and on 375, in each language and in Russian with
    /// Bold Text: every word whole, and the shape where the widths leave no
    /// doubt about it.
    private func assertEveryPage(at size: UIContentSizeCategory) throws {
        let variants: [(language: SupportedLanguage, weight: LegibilityWeight)] = [
            (.ru, .regular), (.en, .regular), (.es, .regular), (.ru, .bold),
        ]
        for width in [CGFloat(320), 375] {
            let screen = CGSize(width: width, height: 2400)
            for variant in variants {
                LocalizationManager.shared.setLanguage(variant.language)
                let bold = variant.weight == .bold
                let name = "\(variant.language.rawValue)\(bold ? " bold" : "") \(Int(width)) \(size.rawValue)"
                func expected(_ surface: Surface) -> Bool? {
                    expectedStacked(surface, width: width, language: variant.language, bold: bold, size: size)
                }

                let titles = try texts(welcomeTitles(), in: page(WelcomePage(onStart: {}), screen, weight: variant.weight),
                                       "\(name) welcome")
                if let stacked = expected(.welcome) {
                    assertShape(titles, stacked: stacked, under: 40, beside: 98, "\(name) welcome")
                }
                assertWordsWhole(titles, welcomeFont, bold: bold, "\(name) welcome")

                let bullets = try texts(notificationBullets(),
                                        in: page(NotificationsPage(babyName: "Mia", onContinue: {}), screen,
                                                 weight: variant.weight),
                                        "\(name) notifications")
                if let stacked = expected(.notifications) {
                    assertShape(bullets, stacked: stacked, under: 48, beside: 96, "\(name) notifications")
                }
                assertWordsWhole(bullets, bulletFont, bold: bold, "\(name) notifications")

                let feeding = try page(feedingPage(), screen, weight: variant.weight)
                try assertFeedingRows(in: feeding, stacked: expected(.feedingRows), bold: bold, "\(name) feeding")
                try assertFeedingHint(in: feeding, column: width - 48, size: size, bold: bold, "\(name) feeding hint")

                for surface in [Surface.growthSwitch, .birthSwitch] {
                    try assertSwitch(surface, on: screen, stacked: expected(surface), weight: variant.weight,
                                     "\(name) \(surface)")
                }
            }
        }
    }

    private enum Surface { case welcome, notifications, feedingRows, growthSwitch, birthSwitch }

    /// nil where a word lands within a few points of its column, or in Bold
    /// Text: there only the words are checked. On 375 every word fits beside.
    private func expectedStacked(_ surface: Surface, width: CGFloat, language: SupportedLanguage, bold: Bool,
                                 size: UIContentSizeCategory) -> Bool? {
        if bold { return nil }
        if width >= 375 { return false }
        let ax2 = size == .accessibilityLarge
        switch (surface, language) {
        // «Подгузники», «Смешанное» and «корректированному» miss by 8 pt or more.
        case (.welcome, .ru), (.feedingRows, .ru), (.birthSwitch, .ru): return true
        case (.notifications, .ru): return ax2 ? true : nil
        // «Окружность» lands on its column at AX2; at AX1 it fits.
        case (.growthSwitch, .ru): return ax2 ? nil : false
        // «Circumference» misses at AX2 and lands on its column at AX1.
        case (.growthSwitch, .en): return ax2 ? true : nil
        case (.welcome, .en), (.notifications, .en), (.feedingRows, .en), (.birthSwitch, .en): return false
        case (.welcome, .es): return ax2 ? true : nil
        case (.notifications, .es), (.feedingRows, .es): return false
        default: return nil
        }
    }

    // MARK: - Pages and texts

    private var welcomeFont: Font { BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded) }
    private var bulletFont: Font { BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded) }
    private var switchTitleFont: Font { BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded) }
    private var switchHintFont: Font { BBTheme.Typography.scaled(12, relativeTo: .body, weight: .regular, design: .rounded) }
    private var feedingNameFont: Font { BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded) }

    private func hintFont(_ size: UIContentSizeCategory) -> Font {
        .system(size: BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: size), weight: .regular,
                design: .rounded)
    }

    private func plainHint(_ text: String, at size: UIContentSizeCategory) -> some View {
        Text(text)
            .font(hintFont(size))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func welcomeTitles() -> [String] {
        ["onboarding.feature.feeding", "onboarding.feature.sleep", "onboarding.feature.growth", "nav.diapers"].map(\.l)
    }

    private func notificationBullets() -> [String] {
        ["onboarding.notify.b1", "onboarding.notify.b2", "onboarding.notify.b3"].map(\.l)
    }

    private func feedingPage() -> FeedingPage {
        FeedingPage(feedingType: .constant(.breast), babyName: "Mia", onBack: {})
    }

    /// The page with the switch, the switch on so its slider shows too.
    private func switchPage(_ surface: Surface, _ screen: CGSize,
                            weight: LegibilityWeight) throws -> (title: String, hint: String,
                                                                 elements: [HostedAccessibility.Element]) {
        if surface == .growthSwitch {
            let elements = try page(GrowthPage(weightKg: .constant(3.5), heightCm: .constant(50),
                                               headCm: .constant(34), includeHead: .constant(true),
                                               knowsMeasurements: .constant(true), onBack: {}),
                                    screen, weight: weight)
            return ("form.head_cm".l, "onboarding.growth_head_optional".l, elements)
        }
        let birth = Date().addingTimeInterval(-60 * 86_400)
        let elements = try page(BirthPage(birthDate: .constant(birth), gender: .constant(.female),
                                          gestationalWeeks: .constant(34), wasBornEarly: .constant(true),
                                          onBack: {}),
                                screen, weight: weight)
        return ("form.preterm".l, "form.preterm_hint".l, elements)
    }

    /// The page on the flow's ground, as OnboardingView stacks them, read once
    /// its entrance animations have settled.
    private func page<V: View>(_ page: V, _ screen: CGSize,
                               weight: LegibilityWeight = .regular) throws -> [HostedAccessibility.Element] {
        let root = try accessibility.host(ZStack {
            OnboardingBackground()
            VStack(spacing: 0) { page }
        }
        .environment(\.legibilityWeight, weight), size: screen)
        // The welcome cards slide in over 0.95 s; the host waits 0.5.
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        let elements = accessibility.elements(root)
        accessibility.close()
        for element in elements {
            XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(element) is past the left edge")
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(element) is past the right edge")
        }
        return elements
    }

    private func texts(_ labels: [String], in elements: [HostedAccessibility.Element],
                       _ name: String) throws -> [HostedAccessibility.Element] {
        try labels.map { label in
            try XCTUnwrap(elements.first { $0.label == label }, "\(name): «\(label)» is not in \(elements)")
        }
    }

    // MARK: - Checks

    /// Under its icon a text starts at the card's leading edge; beside it, past the icon.
    private func assertShape(_ texts: [HostedAccessibility.Element], stacked: Bool, under: CGFloat, beside: CGFloat,
                             _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        for text in texts {
            XCTAssertEqual(text.frame.minX, stacked ? under : beside, accuracy: 0.5,
                           "\(name): «\(text.label)» is not \(stacked ? "under" : "beside") its icon",
                           file: file, line: line)
        }
    }

    /// The switch has no label of its own; the sliders, also unlabelled, are
    /// wider than 100.
    private func assertSwitch(_ surface: Surface, on screen: CGSize, stacked: Bool?,
                              weight: LegibilityWeight = .regular, _ name: String,
                              file: StaticString = #filePath, line: UInt = #line) throws {
        let page = try switchPage(surface, screen, weight: weight)
        let titleText = try XCTUnwrap(page.elements.first { $0.label == page.title }, "\(name): no «\(page.title)»",
                                      file: file, line: line)
        let hintText = try XCTUnwrap(page.elements.first { $0.label == page.hint }, "\(name): no «\(page.hint)»",
                                     file: file, line: line)
        let toggle = try XCTUnwrap(page.elements.first { $0.label.isEmpty && $0.frame.width < 100 && $0.frame.height < 44 },
                                   "\(name): no switch in \(page.elements)", file: file, line: line)
        if stacked == true {
            XCTAssertGreaterThanOrEqual(toggle.frame.minY, hintText.frame.maxY - 0.5,
                                        "\(name): the switch \(toggle) is not under «\(page.hint)»", file: file, line: line)
            XCTAssertEqual(toggle.frame.minX, titleText.frame.minX, accuracy: 12,
                           "\(name): the switch \(toggle) is not at «\(page.title)»'s x", file: file, line: line)
        } else if stacked == false {
            XCTAssertGreaterThanOrEqual(toggle.frame.minX, titleText.frame.maxX,
                                        "\(name): the switch \(toggle) is not beside «\(page.title)»", file: file, line: line)
            XCTAssertLessThan(toggle.frame.minY, hintText.frame.maxY,
                              "\(name): the switch \(toggle) is under «\(page.hint)»", file: file, line: line)
        }
        let bold = weight == .bold
        assertWordsWhole([titleText], switchTitleFont, bold: bold, name, file: file, line: line)
        assertWordsWhole([hintText], switchHintFont, bold: bold, name, file: file, line: line)
    }

    /// Each row is one button labelled with its name. Beside, a row is the
    /// 46-pt icon and the padding tall; under its icon, the name adds a line.
    /// The name's room is the row less the padding, the icon, the check and
    /// the gaps (130) beside, the padding (32) under. The selected row's
    /// border sits 1.5 pt outside it.
    private func assertFeedingRows(in elements: [HostedAccessibility.Element], stacked: Bool?, bold: Bool = false,
                                   _ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let names = Baby.FeedingType.allCases.map(\.displayName.l)
        let rows = try texts(names, in: elements, name)
        let heights = rows.map(\.frame.height)
        XCTAssertLessThanOrEqual(heights.max()! - heights.min()!, 3.5, "\(name): the rows take two shapes: \(rows)",
                                 file: file, line: line)
        if let stacked {
            for row in rows {
                if stacked {
                    XCTAssertGreaterThanOrEqual(row.frame.height, 100, "\(name): «\(row.label)» is not under its icon",
                                                file: file, line: line)
                } else {
                    XCTAssertLessThanOrEqual(row.frame.height, 85, "\(name): «\(row.label)» is not beside its icon",
                                             file: file, line: line)
                }
            }
        }
        let rowWidth = rows.map(\.frame.width).min()!
        let room = rowWidth - (rows[0].frame.height >= 100 ? 32 : 130)
        for label in names {
            let width = wordWidth(label, feedingNameFont, bold: bold)
            XCTAssertGreaterThanOrEqual(room + 0.5, width, "\(name): «\(label)» (\(width)) is broken in \(room)",
                                        file: file, line: line)
        }
    }

    /// The hint takes the first of the reader's size, AX1's and xxxLarge's
    /// at which its widest word fits the column, and keeps every word whole.
    private func assertFeedingHint(in elements: [HostedAccessibility.Element], column: CGFloat,
                                   size: UIContentSizeCategory, bold: Bool, _ name: String,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        let text = "onboarding.feeding_hint".l
        let hint = try XCTUnwrap(elements.first { $0.label == text }, "\(name): no hint in \(elements)",
                                 file: file, line: line)
        let steps = [size, .accessibilityMedium, .extraExtraExtraLarge]
        let setAt = steps.first { step in
            text.split(separator: " ").allSatisfy { wordWidth(String($0), hintFont(step), bold: bold) <= column }
        } ?? .extraExtraExtraLarge
        assertWordsWhole([hint], hintFont(setAt), bold: bold, "\(name) at \(setAt.rawValue)", file: file, line: line)
        // The width alone would pass a hint left at a larger size with a word
        // broken; its height tells the size it was set at.
        XCTAssertEqual(hint.frame.height, height(of: plainHint(text, at: setAt), in: column, bold: bold),
                       accuracy: 1, "\(name): not set at \(setAt.rawValue)", file: file, line: line)
    }

    /// A text laid out narrower than its widest word has broken that word.
    /// Words part at plain spaces, as they wrap.
    private func assertWordsWhole(_ texts: [HostedAccessibility.Element], _ font: Font, bold: Bool = false,
                                  _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        for text in texts {
            let widest = text.label.split(separator: " ")
                .map { (String($0), wordWidth(String($0), font, bold: bold)) }
                .max { $0.1 < $1.1 } ?? ("", 0)
            XCTAssertGreaterThanOrEqual(text.frame.width + 0.5, widest.1,
                                        "\(name): «\(widest.0)» (\(widest.1)) is broken in «\(text.label)» at \(text.frame.width)",
                                        file: file, line: line)
        }
    }

    private func wordWidth(_ word: String, _ font: Font, bold: Bool = false) -> CGFloat {
        let view = Text(word).font(font).fixedSize().environment(\.legibilityWeight, bold ? .bold : .regular)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
    }

    private func height<V: View>(of view: V, in column: CGFloat, bold: Bool = false) -> CGFloat {
        UIHostingController(rootView: view.environment(\.legibilityWeight, bold ? .bold : .regular))
            .sizeThatFits(in: CGSize(width: column, height: 4000)).height
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

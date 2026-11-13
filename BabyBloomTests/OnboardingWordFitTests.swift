import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The onboarding texts set beside an icon or a switch break between words,
/// never inside one. Where a word misses its column, every card of the page
/// sets its text under its icon, the optional-measure switch goes under its
/// title, and the feeding hint takes a smaller size; where the words fit, the
/// shape is the beside one at every text size. The pages' titles step from
/// title1 to title2 and title3, and the percentile card's label to a smaller
/// size, only where a word misses; the card is held on the growth showcase
/// and as the Growth screen sets it.
///
/// Every shipped language runs, and both pseudo-languages. The shapes are
/// pinned for en, ru and es; the other languages are held to whole words,
/// the screen's edges and the hint's computed size.
@MainActor
final class OnboardingWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    /// The languages whose shapes were read off the simulator and pinned.
    private let pinned: [FitLanguage] = [.real(.en), .real(.ru), .real(.es)]

    /// Places a language is known not to fit, keyed by the string key, the
    /// window's width, the size (Large, AX1, AX2) and " bold" with Bold Text
    /// ("onboarding.notify.b1 320 AX2 bold"; a cut tagline is
    /// "onboarding.tagline lines 320 AX2"); a page past the screen's edges
    /// is keyed by the page ("welcome edges 272 Large"; also notifications,
    /// feeding, growth, birth); feeding rows of uneven heights are keyed
    /// "feeding rows <width> <size>[ bold]" (width = the heights' spread,
    /// room = the 3.5-pt tolerance).
    private static let knownMisses: [KnownMiss] = [
        // Full-width names wrap per character beside their icons, to unequal line counts.
        KnownMiss(.pseudo(.jaXB), "feeding rows 250 Large", width: 15.0, room: 3.5),
        KnownMiss(.pseudo(.jaXB), "feeding rows 320 AX2", width: 37.0, room: 3.5),
        KnownMiss(.pseudo(.jaXB), "feeding rows 320 AX2 bold", width: 37.0, room: 3.5),
        KnownMiss(.pseudo(.jaXB), "feeding rows 375 AX1", width: 20.0, room: 3.5),
        KnownMiss(.pseudo(.jaXB), "feeding rows 375 AX1 bold", width: 20.0, room: 3.5),
        // «Lait infantile» wraps between its words beside the icon; its
        // neighbours keep one line.
        KnownMiss(.real(.fr), "feeding rows 320 AX1", width: 17.0, room: 3.5),
        KnownMiss(.pseudo(.enXA), "form.head_cm 320 AX1 bold", width: 252.0, room: 237.3),
        KnownMiss(.pseudo(.enXA), "form.head_cm 320 AX2", width: 272.3, room: 224.7),
        KnownMiss(.pseudo(.enXA), "form.head_cm 320 AX2 bold", width: 295.0, room: 226.3),
    ]

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
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
        let stackedIn: [FitLanguage: Bool] = [.real(.ru): true, .real(.en): false, .real(.es): true]
        for language in FitLanguage.all {
            language.apply()
            let qualifier = "272 Large"
            let welcome = try page(WelcomePage(onStart: {}), screen, language, "welcome edges \(qualifier)")
            let titles = try texts(welcomeTitleKeys, in: welcome, "\(language) \(qualifier)")
            try assertTaglineWhole(in: welcome, language, qualifier)
            // Unpinned languages: only whole words, no shape.
            if let stacked = stackedIn[language] {
                assertShape(titles.map(\.element), stacked: stacked, under: 40, beside: 98, "\(language) \(qualifier)")
            }
            assertWordsWhole(titles, welcomeFont, language, qualifier)
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
        let stackedIn: [FitLanguage: Bool] = [.real(.ru): true, .real(.en): false, .real(.es): false]
        for language in FitLanguage.all {
            language.apply()
            let qualifier = "240 Large"
            let bullets = try texts(notificationBulletKeys,
                                    in: page(NotificationsPage(babyName: "Mia", onContinue: {}), screen,
                                             language, "notifications edges \(qualifier)"),
                                    "\(language) \(qualifier)")
            // Unpinned languages: only whole words, no shape.
            if let stacked = stackedIn[language] {
                assertShape(bullets.map(\.element), stacked: stacked, under: 48, beside: 96, "\(language) \(qualifier)")
            }
            assertWordsWhole(bullets, bulletFont, language, qualifier)
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
        let stackedIn: [FitLanguage: [Surface: Bool]] = [
            .real(.ru): [.growthSwitch: true, .birthSwitch: true],
            .real(.en): [.growthSwitch: true, .birthSwitch: false],
        ]
        for language in FitLanguage.all {
            language.apply()
            for width: CGFloat in [240, 320] {
                for surface in [Surface.growthSwitch, .birthSwitch] {
                    // Only en and ru are pinned: elsewhere the switch's place
                    // is free, its texts' words are not.
                    var stacked: Bool?
                    if let pins = stackedIn[language] {
                        stacked = width >= 320 ? false : pins[surface]
                    }
                    let screen = CGSize(width: width, height: 1400)
                    try assertSwitch(surface, on: screen, stacked: stacked, language, "\(Int(width)) Large")
                }
            }
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
        let stackedIn: [FitLanguage: Bool] = [.real(.ru): true, .real(.en): false, .real(.es): false]
        for language in FitLanguage.all {
            language.apply()
            let qualifier = "250 Large"
            let elements = try page(feedingPage(), screen, language, "feeding edges \(qualifier)")
            // Unpinned languages: only whole words, no shape.
            try assertFeedingRows(in: elements, stacked: stackedIn[language], language, qualifier)
        }
    }

    // MARK: - The feeding hint

    /// ru «персонализированного» at AX2 (about 272 regular, 287 in Bold Text)
    /// misses a 260-pt column, and in Bold Text the 272 a 320-pt screen
    /// leaves, so the hint is set at the AX1 size, where it fits; a column
    /// too narrow for that too takes xxxLarge's. On 375 (327), at AX1 and in
    /// English and Spanish the hint keeps the reader's size. Pins of measured
    /// widths: every language's hint is held to its computed size on the
    /// pages below.
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
            FitLanguage.real(c.language).apply()
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
    /// with Display Zoom) and on 375, in every language with Bold Text off
    /// and on: every word whole, and the shape where the widths leave no
    /// doubt about it.
    private func assertEveryPage(at size: UIContentSizeCategory) throws {
        for width in [CGFloat(320), 375] {
            let screen = CGSize(width: width, height: 2400)
            for language in FitLanguage.all {
                for weight in [LegibilityWeight.regular, .bold] {
                    language.apply()
                    let bold = weight == .bold
                    let qualifier = "\(Int(width)) \(sizeName(size))\(bold ? " bold" : "")"
                    let name = "\(language) \(qualifier)"
                    func expected(_ surface: Surface) -> Bool? {
                        expectedStacked(surface, width: width, language: language, bold: bold, size: size)
                    }

                    let welcome = try page(WelcomePage(onStart: {}), screen, language,
                                           "welcome edges \(qualifier)", weight: weight)
                    let titles = try texts(welcomeTitleKeys, in: welcome, "\(name) welcome")
                    try assertTaglineWhole(in: welcome, bold: bold, language, qualifier)
                    if let stacked = expected(.welcome) {
                        assertShape(titles.map(\.element), stacked: stacked, under: 40, beside: 98, "\(name) welcome")
                    }
                    assertWordsWhole(titles, welcomeFont, bold: bold, language, qualifier)

                    let bullets = try texts(notificationBulletKeys,
                                            in: page(NotificationsPage(babyName: "Mia", onContinue: {}), screen,
                                                     language, "notifications edges \(qualifier)", weight: weight),
                                            "\(name) notifications")
                    if let stacked = expected(.notifications) {
                        assertShape(bullets.map(\.element), stacked: stacked, under: 48, beside: 96,
                                    "\(name) notifications")
                    }
                    assertWordsWhole(bullets, bulletFont, bold: bold, language, qualifier)

                    let feeding = try page(feedingPage(), screen, language, "feeding edges \(qualifier)", weight: weight)
                    try assertFeedingRows(in: feeding, stacked: expected(.feedingRows), bold: bold, language, qualifier)
                    try assertFeedingHint(in: feeding, column: width - 48, size: size, bold: bold, language, qualifier)
                    try assertTitle("onboarding.feeding_title", in: feeding, column: width - 48, bold: bold,
                                    language, qualifier)

                    let namePage = try page(NamePage(name: .constant("Mia"), onBack: {}), screen, language,
                                            "name edges \(qualifier)", weight: weight)
                    try assertTitle("onboarding.name_title", in: namePage, column: width - 48, bold: bold,
                                    language, qualifier)

                    // The page's 24 a side, the card's 16, the ring and its gap.
                    let showcase = try page(showcasePage(), screen, language, "showcase edges \(qualifier)",
                                            weight: weight)
                    try assertPercentileCard(in: showcase, column: width - 48 - 32 - 72, size: size, bold: bold,
                                             language, "\(qualifier) showcase")
                    // The Growth screen's 16 a side, the card's 16, the ring and its gap.
                    let growthCard = try page(growthScreenCard(), screen, language,
                                              "growth card edges \(qualifier)", weight: weight)
                    try assertPercentileCard(in: growthCard, column: width - 32 - 32 - 72, size: size, bold: bold,
                                             language, "\(qualifier) growth screen")

                    for surface in [Surface.growthSwitch, .birthSwitch] {
                        try assertSwitch(surface, on: screen, stacked: expected(surface), weight: weight,
                                         language, qualifier)
                    }
                }
            }
        }
    }

    private enum Surface { case welcome, notifications, feedingRows, growthSwitch, birthSwitch }

    /// nil where a word lands within a few points of its column, or in Bold
    /// Text: there only the words are checked. On 375 every word fits beside.
    private func expectedStacked(_ surface: Surface, width: CGFloat, language: FitLanguage, bold: Bool,
                                 size: UIContentSizeCategory) -> Bool? {
        // The other languages' shape is not pinned: only their words are checked.
        guard pinned.contains(language), !bold else { return nil }
        if width >= 375 { return false }
        let ax2 = size == .accessibilityLarge
        switch (surface, language.base) {
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
    private var taglineFont: Font { BBTheme.Typography.scaled(18, relativeTo: .body, weight: .medium, design: .rounded) }
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

    private let welcomeTitleKeys = ["onboarding.feature.feeding", "onboarding.feature.sleep",
                                    "onboarding.feature.growth", "nav.diapers"]
    private let notificationBulletKeys = ["onboarding.notify.b1", "onboarding.notify.b2", "onboarding.notify.b3"]

    private func feedingPage() -> FeedingPage {
        FeedingPage(feedingType: .constant(.breast), babyName: "Mia", onBack: {})
    }

    /// The showcase with a birth weight, so it shows the percentile card.
    private func showcasePage() -> GrowthShowcasePage {
        GrowthShowcasePage(babyName: "Mia", birthDate: Date().addingTimeInterval(-10 * 86_400), gender: .female,
                           birthWeightKg: 3.45, gestationalWeeks: nil, onContinue: {})
    }

    /// The card as the Growth screen sets it: in its explainer, 16 from the
    /// screen's edges.
    private func growthScreenCard() -> some View {
        ExplainerCard(explainer: .percentile) {
            PercentileCard(percentile: 61, badge: "61",
                           captionLines: ["percentile.by_who_newborn".l, "percentile.by_who_newborn".l])
        }
        .padding(.horizontal, BBTheme.Spacing.md)
    }

    /// The page with the switch, the switch on so its slider shows too.
    private func switchPage(_ surface: Surface, _ screen: CGSize, _ language: FitLanguage, _ qualifier: String,
                            weight: LegibilityWeight) throws -> (titleKey: String, hintKey: String,
                                                                 elements: [HostedAccessibility.Element]) {
        if surface == .growthSwitch {
            let elements = try page(GrowthPage(weightKg: .constant(3.5), heightCm: .constant(50),
                                               headCm: .constant(34), includeHead: .constant(true),
                                               knowsMeasurements: .constant(true), onBack: {}),
                                    screen, language, "growth edges \(qualifier)", weight: weight)
            return ("form.head_cm", "onboarding.growth_head_optional", elements)
        }
        let birth = Date().addingTimeInterval(-60 * 86_400)
        let elements = try page(BirthPage(birthDate: .constant(birth), gender: .constant(.female),
                                          gestationalWeeks: .constant(34), wasBornEarly: .constant(true),
                                          onBack: {}),
                                screen, language, "birth edges \(qualifier)", weight: weight)
        return ("form.preterm", "form.preterm_hint", elements)
    }

    /// The page on the flow's ground, as OnboardingView stacks them, read once
    /// its entrance animations have settled; `edgesKey` names its check
    /// against the screen's edges.
    private func page<V: View>(_ page: V, _ screen: CGSize, _ language: FitLanguage, _ edgesKey: String,
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
        var misses: [String] = []
        for element in elements {
            if element.frame.minX < -0.5 {
                misses.append("\(element) left edge \(points(element.frame.minX)) in \(points(screen.width))")
            }
            if element.frame.maxX > screen.width + 0.5 {
                misses.append("\(element) right edge \(points(element.frame.maxX)) in \(points(screen.width))")
            }
        }
        check(language, edgesKey, misses.isEmpty ? nil : misses.joined(separator: "; "))
        return elements
    }

    /// Each key's text on the page, found by the string it reads.
    private func texts(_ keys: [String], in elements: [HostedAccessibility.Element],
                       _ name: String) throws -> [(key: String, element: HostedAccessibility.Element)] {
        try keys.map { key in
            let label = key.l
            let element = try XCTUnwrap(elements.first { $0.label == label }, "\(name): «\(label)» is not in \(elements)")
            return (key, element)
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
                              weight: LegibilityWeight = .regular, _ language: FitLanguage, _ qualifier: String,
                              file: StaticString = #filePath, line: UInt = #line) throws {
        let name = "\(language) \(qualifier) \(surface)"
        let page = try switchPage(surface, screen, language, qualifier, weight: weight)
        let title = page.titleKey.l
        let hint = page.hintKey.l
        let titleText = try XCTUnwrap(page.elements.first { $0.label == title }, "\(name): no «\(title)»",
                                      file: file, line: line)
        let hintText = try XCTUnwrap(page.elements.first { $0.label == hint }, "\(name): no «\(hint)»",
                                     file: file, line: line)
        let toggle = try XCTUnwrap(page.elements.first { $0.label.isEmpty && $0.frame.width < 100 && $0.frame.height < 44 },
                                   "\(name): no switch in \(page.elements)", file: file, line: line)
        try assertTitle(surface == .growthSwitch ? "onboarding.growth_title" : "onboarding.birth_title",
                        in: page.elements, column: screen.width - 48, bold: weight == .bold, language, qualifier,
                        file: file, line: line)
        if stacked == true {
            XCTAssertGreaterThanOrEqual(toggle.frame.minY, hintText.frame.maxY - 0.5,
                                        "\(name): the switch \(toggle) is not under «\(hint)»", file: file, line: line)
            XCTAssertEqual(toggle.frame.minX, titleText.frame.minX, accuracy: 12,
                           "\(name): the switch \(toggle) is not at «\(title)»'s x", file: file, line: line)
        } else if stacked == false {
            XCTAssertGreaterThanOrEqual(toggle.frame.minX, titleText.frame.maxX,
                                        "\(name): the switch \(toggle) is not beside «\(title)»", file: file, line: line)
            XCTAssertLessThan(toggle.frame.minY, hintText.frame.maxY,
                              "\(name): the switch \(toggle) is under «\(hint)»", file: file, line: line)
        }
        let bold = weight == .bold
        assertWordsWhole([(page.titleKey, titleText)], switchTitleFont, bold: bold, language, qualifier,
                         file: file, line: line)
        assertWordsWhole([(page.hintKey, hintText)], switchHintFont, bold: bold, language, qualifier,
                         file: file, line: line)
    }

    /// Each row is one button labelled with its name. Beside, a row is the
    /// 46-pt icon and the padding tall; under its icon, the name adds a line.
    /// The name's room is the row less the padding, the icon, the check and
    /// the gaps (130) beside, the padding (32) under. The selected row's
    /// border sits 1.5 pt outside it.
    private func assertFeedingRows(in elements: [HostedAccessibility.Element], stacked: Bool?, bold: Bool = false,
                                   _ language: FitLanguage, _ qualifier: String,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        let name = "\(language) \(qualifier) feeding"
        let keys = Baby.FeedingType.allCases.map(\.displayName)
        let rows = try texts(keys, in: elements, name).map(\.element)
        let heights = rows.map(\.frame.height)
        let spread = heights.max()! - heights.min()!
        check(language, "feeding rows \(qualifier)",
              spread > 3.5 ? "the rows take two shapes, heights \(points(spread)) apart in 3.5: \(rows)" : nil,
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
        for key in keys {
            let width = FitMeasure.widestUnit(key.l, font: feedingNameFont, bold: bold)
            check(language, "\(key) \(qualifier)",
                  width > room + 0.5 ? "widest unit \(points(width)) in \(points(room))" : nil,
                  file: file, line: line)
        }
    }

    /// The hint takes the first of the reader's size, AX1's and xxxLarge's
    /// at which its widest unit fits the column, and keeps every unit whole.
    private func assertFeedingHint(in elements: [HostedAccessibility.Element], column: CGFloat,
                                   size: UIContentSizeCategory, bold: Bool, _ language: FitLanguage, _ qualifier: String,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        let key = "onboarding.feeding_hint"
        let name = "\(language) \(key) \(qualifier)"
        let text = key.l
        let hint = try XCTUnwrap(elements.first { $0.label == text }, "\(name): no hint in \(elements)",
                                 file: file, line: line)
        let steps = [size, .accessibilityMedium, .extraExtraExtraLarge]
        let widest = steps.map { FitMeasure.widestUnit(text, font: hintFont($0), bold: bold) }
        let index = widest.firstIndex { $0 <= column }
        let setAt = steps[index ?? steps.count - 1]
        // Past xxxLarge nothing is left to shrink: the unit breaks.
        var miss: String?
        if index == nil {
            miss = "widest unit \(points(widest[steps.count - 1])) at xxxLarge in \(points(column))"
        } else if hint.frame.width + 0.5 < widest[index!] {
            miss = "widest unit \(points(widest[index!])) in \(points(hint.frame.width)), column \(points(column))"
        }
        check(language, "\(key) \(qualifier)", miss, file: file, line: line)
        // The width alone would pass a hint left at a larger size with a word
        // broken; its height tells the size it was set at.
        XCTAssertEqual(hint.frame.height, height(of: plainHint(text, at: setAt), in: column, bold: bold),
                       accuracy: 1, "\(name): not set at \(setAt.rawValue)", file: file, line: line)
    }

    /// A page's title takes the first of title1, title2 and title3 whose
    /// widest unit fits the column with the heading's spare, title3 where none
    /// does, and keeps every unit whole.
    private func assertTitle(_ key: String, in elements: [HostedAccessibility.Element], column: CGFloat,
                             bold: Bool, _ language: FitLanguage, _ qualifier: String,
                             file: StaticString = #filePath, line: UInt = #line) throws {
        let text = key.l
        let name = "\(language) \(key) \(qualifier)"
        let title = try XCTUnwrap(elements.first { $0.label == text }, "\(name): no title in \(elements)",
                                  file: file, line: line)
        let faces: [(name: String, style: (String) -> Text)] = [
            ("title1", BBTheme.Typography.title1), ("title2", BBTheme.Typography.title2),
            ("title3", BBTheme.Typography.title3),
        ]
        let widest = faces.map { widestUnit(text, $0.style, face: $0.name, bold: bold) }
        let index = widest.firstIndex { $0.width + BBScreenTitleFit.spare <= column } ?? faces.count - 1
        let face = faces[index]
        check(language, "\(key) \(qualifier)",
              title.frame.width + 0.5 < widest[index].width
                  ? "widest unit «\(widest[index].unit)» \(points(widest[index].width)) in \(face.name) "
                      + "in \(points(title.frame.width)), column \(points(column))" : nil,
              file: file, line: line)
        // A title left in title1 with a word broken can be as wide as the
        // column; its height tells the face it was set in.
        XCTAssertEqual(title.frame.height,
                       height(of: face.style(text).multilineTextAlignment(.center), in: column, bold: bold),
                       accuracy: 1, "\(name): not set in \(face.name)", file: file, line: line)
    }

    /// The card's label takes the first of the reader's size, AX1's,
    /// xxxLarge's, xxLarge's, xLarge's and Large's at which its widest unit
    /// fits the column the ring leaves; the label and the figure are one
    /// element, so their height tells the size.
    private func assertPercentileCard(in elements: [HostedAccessibility.Element], column: CGFloat,
                                      size: UIContentSizeCategory, bold: Bool, _ language: FitLanguage,
                                      _ qualifier: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let key = "percentile.weight"
        let name = "\(language) \(key) \(qualifier)"
        let text = key.l
        let label = try XCTUnwrap(elements.first { $0.label.hasPrefix(text) }, "\(name): no label in \(elements)",
                                  file: file, line: line)
        let steps: [UIContentSizeCategory] = [size, .accessibilityMedium, .extraExtraExtraLarge, .extraExtraLarge,
                                              .extraLarge, .large]
        let natural = BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: size)
        let sizes = steps.map { min(natural, BBTheme.Typography.scaledPointSize(14, relativeTo: .body, for: $0)) }
        let widest = sizes.map { FitMeasure.widestUnit(text, font: labelFont($0), bold: bold) }
        let index = widest.firstIndex { $0 <= column }
        // Past Large nothing is left to shrink: the unit breaks.
        check(language, "\(key) \(qualifier)",
              index == nil ? "widest unit \(points(widest[steps.count - 1])) at Large in \(points(column))" : nil,
              file: file, line: line)
        let setAt = sizes[index ?? steps.count - 1]
        let plain = VStack(alignment: .leading, spacing: 4) {
            Text(text).font(labelFont(setAt)).fixedSize(horizontal: false, vertical: true)
            BBTheme.Typography.metric("61")
        }
        XCTAssertEqual(label.frame.height, height(of: plain, in: column, bold: bold), accuracy: 1,
                       "\(name): not set at \(points(setAt)) pt in \(points(column))", file: file, line: line)
    }

    private func labelFont(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// The widest line-break unit in one of the theme's text faces, its
    /// tracking included; faces are the same on every page, so each unit is
    /// measured once.
    private func widestUnit(_ text: String, _ style: (String) -> Text, face: String,
                            bold: Bool) -> (unit: String, width: CGFloat) {
        text.lineBreakUnits.map { unit in
            let key = "\(face)\(bold ? " bold" : "") \(unit)"
            if let width = Self.faceWidths[key] { return (unit, width) }
            let view = style(unit).fixedSize().environment(\.legibilityWeight, bold ? .bold : .regular)
            let width = UIHostingController(rootView: view)
                .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
                .width
            Self.faceWidths[key] = width
            return (unit, width)
        }
        .max { $0.width < $1.width } ?? ("", 0)
    }

    private static var faceWidths: [String: CGFloat] = [:]

    /// The tagline under the brand name keeps every line it needs: as tall as
    /// the same text needs at its own width, and no word broken. The hero once
    /// had a fixed 320-pt height, and at AX2 the tagline lost its last lines.
    private func assertTaglineWhole(in elements: [HostedAccessibility.Element], bold: Bool = false,
                                    _ language: FitLanguage, _ qualifier: String,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        let tagline = try texts(["onboarding.tagline"], in: elements, "\(language) \(qualifier)")
        assertWordsWhole(tagline, taglineFont, bold: bold, language, qualifier, file: file, line: line)
        let text = tagline[0].element
        let needed = height(of: Text(text.label).font(taglineFont).multilineTextAlignment(.center),
                            in: text.frame.width + 0.5, bold: bold)
        check(language, "onboarding.tagline lines \(qualifier)",
              text.frame.height + 1 < needed ? "cut: \(points(text.frame.height)) tall of \(points(needed))" : nil,
              file: file, line: line)
    }

    /// A text laid out narrower than its widest unit has broken that unit.
    private func assertWordsWhole(_ texts: [(key: String, element: HostedAccessibility.Element)], _ font: Font,
                                  bold: Bool = false, _ language: FitLanguage, _ qualifier: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        for (key, text) in texts {
            let widest = text.label.lineBreakUnits
                .map { ($0, FitMeasure.wordWidth($0, font: font, bold: bold)) }
                .max { $0.1 < $1.1 } ?? ("", 0)
            check(language, "\(key) \(qualifier)",
                  text.frame.width + 0.5 < widest.1
                      ? "widest unit «\(widest.0)» \(points(widest.1)) in \(points(text.frame.width))" : nil,
                  file: file, line: line)
        }
    }

    /// Fails on a miss, unless the key is listed: then on no miss left.
    private func check(_ language: FitLanguage, _ key: String, _ miss: String?,
                       file: StaticString = #filePath, line: UInt = #line) {
        if KnownMiss.listed(Self.knownMisses, language, key) {
            XCTAssertNotNil(miss, "\(language) \(key) fits now: remove its known-miss row", file: file, line: line)
        } else if let miss {
            XCTFail("\(language) \(key): \(miss)", file: file, line: line)
        }
    }

    private func sizeName(_ size: UIContentSizeCategory) -> String {
        switch size {
        case .large: "Large"
        case .accessibilityMedium: "AX1"
        case .accessibilityLarge: "AX2"
        default: size.rawValue
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    /// The pinned measures of the hint test's literal word.
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

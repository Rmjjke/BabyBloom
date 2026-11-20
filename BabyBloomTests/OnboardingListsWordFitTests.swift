import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// Every icon-and-text list of the onboarding pages keeps each word whole, in
/// every shipped language, on a 320 and a 375-pt screen, with Bold Text off
/// and on, at the content size the simulator runs (the gate runs the class at
/// Large, AX1 and AX2): the growth showcase's bullets and its invitation, the
/// notification bullets, the welcome cards, the feeding names, the growth
/// page's note, the last page's free and Premium lists and the paywall's
/// features.
///
/// A text laid out narrower than its widest word has broken that word. The
/// pages stand side by side in one window per language, width and weight, as
/// OnboardingView sets them, and are read from the accessibility tree.
@MainActor
final class OnboardingListsWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    func testEveryOnboardingListKeepsWordsWholeAt320() throws {
        try checkLists(width: 320)
    }

    func testEveryOnboardingListKeepsWordsWholeAt375() throws {
        try checkLists(width: 375)
    }

    // MARK: Lists

    private struct List {
        let name: String
        let view: AnyView
        let texts: () -> [String]
        let font: Font
        /// The smaller sizes a list steps down to when a word misses at
        /// `font`, largest first: a word is judged at the first that fits,
        /// as the list draws it.
        var steps: [Font] = []
        /// The text is part of one element with its label (the last page's
        /// card reads "Free, Feeds…"), so it is found inside that element's
        /// label; the element's width is still the text's own.
        var inCombined = false
    }

    private static let name = "Mia"
    private static let height: CGFloat = 2400

    private var bulletFont: Font { BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded) }
    private var noteFont: Font { BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded) }

    private func lists() -> [List] {
        let name = Self.name
        let birth = Date().addingTimeInterval(-10 * 86_400)
        return [
            List(name: "showcase bullets",
                 view: AnyView(GrowthShowcasePage(babyName: name, birthDate: birth, gender: .female,
                                                  birthWeightKg: 3.45, gestationalWeeks: nil, onContinue: {})),
                 texts: { [String(format: "onboarding.showcase.bullet1".l, name),
                           "onboarding.showcase.bullet2".l, "onboarding.showcase.bullet3".l] },
                 font: bulletFont),
            List(name: "showcase invitation",
                 view: AnyView(GrowthShowcasePage(babyName: name, birthDate: birth, gender: .female,
                                                  birthWeightKg: nil, gestationalWeeks: nil, onContinue: {})),
                 texts: { [String(format: "onboarding.showcase.invite".l, name)] },
                 font: noteFont),
            List(name: "notification bullets",
                 view: AnyView(NotificationsPage(babyName: name, onContinue: {})),
                 texts: { ["onboarding.notify.b1".l, "onboarding.notify.b2".l, "onboarding.notify.b3".l] },
                 font: bulletFont),
            List(name: "welcome cards",
                 view: AnyView(WelcomePage(onStart: {})),
                 texts: { ["onboarding.feature.feeding".l, "onboarding.feature.sleep".l,
                           "onboarding.feature.growth".l, "nav.diapers".l] },
                 font: BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded)),
            List(name: "feeding names",
                 view: AnyView(FeedingPage(feedingType: .constant(.breast), babyName: name, onBack: {})),
                 texts: { Baby.FeedingType.allCases.map { $0.displayName.l } },
                 font: BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded)),
            List(name: "growth note",
                 view: AnyView(GrowthPage(weightKg: .constant(3.5), heightCm: .constant(50), headCm: .constant(34),
                                          includeHead: .constant(false), knowsMeasurements: .constant(false),
                                          onBack: {})),
                 texts: { ["onboarding.growth_unknown_note".l] },
                 font: noteFont),
            List(name: "free card",
                 view: AnyView(WidgetShowcasePage(babyName: name, isFinishing: false, onFinish: {})),
                 texts: { ["onboarding.widget.free_list".l, "onboarding.widget.premium_list".l] },
                 font: BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded),
                 inCombined: true),
            List(name: "paywall features",
                 view: AnyView(PaywallView(source: .settings).environment(SubscriptionManager())),
                 texts: { PremiumFeatureList.features.map { $0.key.l } },
                 font: BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded),
                 steps: PercentileLabel.steps.map {
                     .system(size: PremiumFeatureRow.pointSize(for: $0), weight: .medium, design: .rounded)
                 }),
        ]
    }

    // MARK: Check

    private func checkLists(width: CGFloat) throws {
        let size = sizeName(UIApplication.shared.preferredContentSizeCategory)
        var misses: [String] = []
        for language in SupportedLanguage.available.map(FitLanguage.real) {
            language.apply()
            for bold in [false, true] {
                try autoreleasepool {
                    misses += try judge(language, width: width, bold: bold,
                                        "\(language) \(Int(width)) \(size)\(bold ? " bold" : "")")
                }
            }
        }
        XCTAssert(misses.isEmpty, "\(misses.count) misses:\n" + misses.joined(separator: "\n"))
    }

    /// Hosts every page in a column of its own, the screen's width each, and
    /// judges each list's texts against the widest word they hold.
    private func judge(_ language: FitLanguage, width: CGFloat, bold: Bool, _ tag: String) throws -> [String] {
        defer { accessibility.close() }
        let lists = lists()
        let scene = HStack(alignment: .top, spacing: 0) {
            ForEach(lists.indices, id: \.self) { index in
                ZStack {
                    OnboardingBackground()
                    VStack(spacing: 0) { lists[index].view }
                }
                .frame(width: width, height: Self.height)
                .clipped()
            }
        }
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.legibilityWeight, bold ? .bold : .regular)
        .appLanguageEnvironment(language.base)
        // The pages fade and slide in on appear; read them where they settle.
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
        let root = try accessibility.host(scene, size: CGSize(width: width * CGFloat(lists.count), height: Self.height),
                                          bold: bold)
        // The welcome cards slide in over 0.95 s; the host waits 0.5.
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        let elements = accessibility.elements(root)

        var misses: [String] = []
        for (index, list) in lists.enumerated() {
            let column = CGFloat(index) * width ..< CGFloat(index + 1) * width
            let inColumn = elements.filter { column.contains($0.frame.midX) }
            for text in list.texts() {
                let match: (String) -> Bool = list.inCombined ? { $0.contains(text) } : { $0 == text }
                guard let element = inColumn.first(where: { match($0.label) }) else {
                    misses.append("\(tag) \(list.name): «\(text)» is not on the page")
                    continue
                }
                // The paywall's rows read as one element whose frame is their
                // text's column (measured at 320 pt AX2: x 40…277, the text's own
                // edges), so every list's room is its element's width.
                let room = element.frame.width
                // A word that holds a hyphen may break after it (the design
                // system's rule): its parts are what must stay whole.
                let pieces = text.lineBreakUnits
                    .flatMap { $0.replacingOccurrences(of: "-", with: "-\n").split(separator: "\n").map(String.init) }
                let tries = ([list.font] + list.steps).map { font in
                    pieces.map { ($0, FitMeasure.wordWidth($0, font: font, bold: bold)) }
                        .max { $0.1 < $1.1 } ?? ("", 0)
                }
                let widest = tries.first { $0.1 <= room + 0.5 } ?? tries[tries.count - 1]
                if room + 0.5 < widest.1 {
                    misses.append("\(tag) \(list.name): «\(widest.0)» \(points(widest.1)) in \(points(room))")
                }
            }
        }
        return misses
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
}

import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The round brand badge always stands beside the brand name or the setup
/// title, so VoiceOver passes over it. Built from a named asset without
/// `decorative:`, SwiftUI hands VoiceOver the file name, "BBLogo", in every
/// language.
@MainActor
final class BrandMarkAccessibilityTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)
    private let birth = Calendar.current.date(byAdding: .day, value: -40, to: Date())!

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    func testTheWelcomePageReadsTheBrandNameAndNotTheBadge() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            let root = try accessibility.host(WelcomePage(onStart: {}), size: screen)
            // The hero springs in from zero opacity after a 0.1 s delay.
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            assertNoAssetName(in: root, reads: "brand.name".l, language)
        }
    }

    func testTheSetupPageReadsItsTitleAndNotTheBadge() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            let page = GeneratingPage(babyName: "Mia", birthDate: birth, onDone: {})
            let root = try accessibility.host(page, size: screen)
            assertNoAssetName(in: root, reads: String(format: "onboarding.gen.title_named".l, "Mia"), language)
        }
    }

    /// The masthead of both paywalls, the onboarding page and the one in the app.
    func testThePremiumHeroReadsItsTitleAndNotTheBadge() throws {
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            let root = try accessibility.host(PremiumHero(), size: screen)
            assertNoAssetName(in: root, reads: "onboarding.premium.title".l, language)
        }
    }

    private func assertNoAssetName(in root: UIView, reads title: String, _ language: SupportedLanguage,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let elements = accessibility.elements(root)
        XCTAssertFalse(elements.isEmpty, "\(language): no accessibility elements", file: file, line: line)
        let named = elements.filter { $0.label.localizedCaseInsensitiveContains("BBLogo") }
        XCTAssertTrue(named.isEmpty, "\(language): the badge reads its file name: \(named)", file: file, line: line)
        XCTAssertTrue(elements.contains { $0.label.contains(title) },
                      "\(language): «\(title)» is not read; the tree: \(elements)", file: file, line: line)
    }
}

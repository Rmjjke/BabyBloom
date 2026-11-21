import XCTest
@testable import BabyBloom

/// The gallery reads the language the app last stored in the App Group, with
/// no relaunch of the process that reads it.
@MainActor
final class WidgetGalleryTests: XCTestCase {

    func testTheGalleryFollowsTheStoredLanguage() throws {
        let shared = try XCTUnwrap(UserDefaults(suiteName: "group.com.nenita.app"))
        let key = LocalizationManager.languageKey
        let stored = shared.object(forKey: key)
        let language = LocalizationManager.shared.language
        addTeardownBlock { @MainActor in
            shared.set(stored, forKey: key)
            LocalizationManager.shared.setLanguage(language)
        }

        shared.set("ru", forKey: key)
        XCTAssertEqual(WidgetGallery.small().name, "Ночка")
        XCTAssertTrue(WidgetGallery.medium().name.hasPrefix("Ночка") && WidgetGallery.medium().name.hasSuffix("Подробно"))
        XCTAssertTrue(WidgetGallery.medium().description.hasPrefix("Кормления"))

        shared.set("es", forKey: key)
        XCTAssertEqual(WidgetGallery.small().name, "Nenita")
        XCTAssertTrue(WidgetGallery.medium().name.hasPrefix("Nenita") && WidgetGallery.medium().name.hasSuffix("Detallado"))
        XCTAssertTrue(WidgetGallery.small().description.hasPrefix("Un vistazo"))
    }

    /// The onboarding specimen is one VoiceOver element that reads as the
    /// gallery names and describes the medium widget, in the app's language.
    func testTheOnboardingSpecimenReadsAsTheMediumWidget() {
        let language = LocalizationManager.shared.language
        addTeardownBlock { @MainActor in LocalizationManager.shared.setLanguage(language) }
        // The strings glue short words with no-break spaces; compare the words.
        func label() -> String { WidgetShowcasePage.specimenLabel.replacingOccurrences(of: "\u{00A0}", with: " ") }

        LocalizationManager.shared.setLanguage("en")
        XCTAssertEqual(label(), "Bitty — Detailed, Feedings and sleep at a glance, and a button to start a feeding")
        LocalizationManager.shared.setLanguage("ru")
        XCTAssertEqual(label(), "Ночка — Подробно, Кормления и сон малыша и кнопка, чтобы начать кормление")
    }

    /// What VoiceOver meets on the page where the specimen stands: one element
    /// with that reading and no button trait — not the sample's readings one by
    /// one and a Start Feeding control that does nothing in onboarding.
    func testTheOnboardingSpecimenIsOneElementWithNoButton() throws {
        let accessibility = HostedAccessibility()
        let shared = try XCTUnwrap(UserDefaults(suiteName: "group.com.nenita.app"))
        let key = LocalizationManager.languageKey
        let stored = shared.object(forKey: key)
        let language = LocalizationManager.shared.language
        addTeardownBlock { @MainActor in
            accessibility.close()
            shared.set(stored, forKey: key)
            LocalizationManager.shared.setLanguage(language)
        }

        for code in ["en", "ru"] {
            LocalizationManager.shared.setLanguage(code)
            let root = try accessibility.host(WidgetShowcasePage(babyName: "Mia", isFinishing: false, onFinish: {}),
                                              size: CGSize(width: 390, height: 844))
            // The page springs in from zero opacity after a 0.1 s delay.
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            let elements = accessibility.elements(root)
            let specimen = elements.filter { $0.label == WidgetShowcasePage.specimenLabel }
            XCTAssertEqual(specimen.count, 1, "\(code): \(elements)")
            guard let frame = specimen.first?.frame else { continue }
            XCTAssertFalse(specimen[0].traits.contains(.button), "\(code): the specimen reads as a button")
            XCTAssertTrue(specimen[0].traits.contains(.image), "\(code): the specimen does not read as a picture")
            let inside = elements.filter { frame.insetBy(dx: -1, dy: -1).contains($0.frame) }
            XCTAssertEqual(inside.count, 1, "\(code): more than the specimen inside its frame: \(inside)")
            XCTAssertFalse(elements.contains { $0.label == "button.start_feeding".l }, "\(code): \(elements)")
            accessibility.close()
        }
    }
}

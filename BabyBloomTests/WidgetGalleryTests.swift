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
}

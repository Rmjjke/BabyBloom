import XCTest
import SwiftData
import SwiftUI
@testable import BabyBloom

/// The store stays on the device: its configuration names no CloudKit
/// database, it is the file earlier builds opened, and Settings no longer has
/// an iCloud Sync line saying otherwise.
@MainActor
final class LocalStoreTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// The configuration builds up to 1.2.0 opened the store with.
    private let earlier = ModelConfiguration(schema: AppSchema.schema,
                                             groupContainer: .identifier("group.com.nenita.app"),
                                             cloudKitDatabase: .automatic)

    func testTheStoreNamesNoCloudKitContainer() {
        // The earlier one names this app's container, so a nil is the
        // configuration's doing, not the test host's.
        XCTAssertNotNil(earlier.cloudKitContainerIdentifier)
        XCTAssertNil(SharedStore.configuration.cloudKitContainerIdentifier)
    }

    /// A store at another path would leave every user's data behind, unread.
    func testTheStoreIsTheFileEarlierBuildsOpened() throws {
        let group = try XCTUnwrap(FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.nenita.app"))
        let store = group.appending(path: "Library/Application Support/default.store")
        XCTAssertEqual(SharedStore.configuration.url, earlier.url)
        XCTAssertEqual(SharedStore.configuration.url.standardizedFileURL.path, store.standardizedFileURL.path)
    }

    /// Every Settings row in all three languages; the list is hosted tall so
    /// none falls below the window.
    func testSettingsHasNoICloudSyncLine() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        container.mainContext.insert(Baby(name: "Mia", birthDate: Date().addingTimeInterval(-90 * 86_400),
                                          gender: .female, feedingType: .breast))
        try container.mainContext.save()

        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let view = NavigationStack { ProfileView() }
                .environment(SubscriptionManager())
                .modelContainer(container)
            let root = try accessibility.host(view, size: CGSize(width: 402, height: 2000))
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            let labels = accessibility.elements(root, automation: true).map(\.label)
            accessibility.close()

            // Its neighbour in the section is there, so the rows were read.
            XCTAssertTrue(labels.contains { $0.contains("settings.analytics".l) }, "\(language): \(labels)")
            // The row said «iCloud» in every language.
            XCTAssertFalse(labels.contains { $0.contains("iCloud") }, "\(language): \(labels)")
        }
    }
}

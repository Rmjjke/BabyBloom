import SwiftData

/// The app process's one ModelContainer over the App Group store.
///
/// It lives here rather than on `BabyBloomApp` because the Live Activity's Stop
/// intent runs in the app process too — sometimes in a background launch with
/// no scene at all — and it must write through the SAME container as the UI.
/// Two containers on one store in one process would each keep their own
/// context and could save over each other.
enum SharedStore {
    @MainActor static let container: ModelContainer = {
        let schema = Schema([
            Baby.self,
            FeedingEntry.self,
            SleepEntry.self,
            DiaperEntry.self,
            GrowthEntry.self,
            CustomEvent.self
        ])
        let config = ModelConfiguration(schema: schema,
                                        groupContainer: .identifier("group.com.nenita.app"),
                                        cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

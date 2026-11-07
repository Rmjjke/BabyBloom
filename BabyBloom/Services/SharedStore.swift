import SwiftData

/// The app process's one ModelContainer over the App Group store.
///
/// It lives here rather than on `BabyBloomApp` because the Live Activity's Stop
/// intent runs in the app process too — sometimes in a background launch with
/// no scene at all — and it must write through the SAME container as the UI.
/// Two containers on one store in one process would each keep their own
/// context and could save over each other.
enum SharedStore {
    /// Local only: no CloudKit database, so nothing leaves the device. The
    /// models still follow CloudKit's rules, so turning sync back on needs no
    /// model migration; the rest it needs is in DECISIONS 2026-11-07.
    static var configuration: ModelConfiguration {
        ModelConfiguration(schema: AppSchema.schema,
                           groupContainer: .identifier("group.com.nenita.app"),
                           cloudKitDatabase: .none)
    }

    @MainActor static let container: ModelContainer = {
        do {
            return try ModelContainer(for: AppSchema.schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

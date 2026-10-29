import AppIntents
import Foundation

/// The widget's "Start feeding" button (D16).
///
/// A `LiveActivityIntent`, like `StopTimerIntent`, for the same two reasons:
/// it runs in the APP's process, where the store is writable and synced and
/// `TimerActions` exists; and only from there may the Live Activity start
/// while the app is in the background. A plain widget intent would run in the
/// extension, which opens the store read-only. Its body is compiled only into
/// the app (`LIVE_ACTIVITY_APP`).
struct StartFeedingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start feeding"
    /// The widget's button only: Shortcuts has the app itself for this.
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        #if LIVE_ACTIVITY_APP
        await MainActor.run {
            if TimerActions.startFeedingFromWidget(in: SharedStore.container.mainContext) {
                _ = Analytics.shared.track(.widgetFeedingLogged)
            }
        }
        // The activity's request must go through before iOS suspends us.
        await LiveActivitySync.shared.settle()
        #endif
        return .result()
    }
}

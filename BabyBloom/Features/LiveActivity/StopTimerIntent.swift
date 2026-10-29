import AppIntents
import Foundation

/// The Stop button on the Lock Screen and in the Dynamic Island.
///
/// A `LiveActivityIntent` runs in the APP's process (launched in the background
/// if needed), never in the widget extension, so the stop goes through the
/// same `TimerActions` path as the in-app button, store, reminders and all.
/// The type is compiled into both targets because the extension's
/// `Button(intent:)` needs it. Its body is compiled only into the app
/// (`LIVE_ACTIVITY_APP`, project.yml), where TimerActions exists.
struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop timer"
    /// Not a Shortcuts/Spotlight action: it takes a raw entry id and only makes
    /// sense from the activity that carries one.
    static let isDiscoverable = false

    @Parameter(title: "Entry")
    var entryID: String

    @Parameter(title: "Kind")
    var kind: String

    init() {}

    init(entryID: UUID, kind: TimerKind) {
        self.entryID = entryID.uuidString
        self.kind = kind.rawValue
    }

    func perform() async throws -> some IntentResult {
        #if LIVE_ACTIVITY_APP
        guard let id = UUID(uuidString: entryID), let timerKind = TimerKind(rawValue: kind) else {
            return .result()
        }
        await MainActor.run {
            let stopped = TimerActions.stop(entryID: id, kind: timerKind,
                                            in: SharedStore.container.mainContext)
            if stopped {
                // Counted like any finished entry, but no review prompt (R2.2):
                // the app is in the background and the parent is at the Lock Screen.
                Analytics.shared.noteEntrySaved(timerKind == .feeding ? .feeding : .sleep)
                _ = Analytics.shared.track(.liveActivityStoppedFromLockScreen)
                // A Lock-Screen-only week plans its Monday notification here.
                NotificationManager.shared.rescheduleWeeklySummary()
            } else {
                // Already stopped or deleted (a second tap, or the app won the
                // race): nothing to write, but the activity must still go (R2.3).
                TimerActions.afterChange()
            }
        }
        // The end must reach the Lock Screen before iOS suspends a background launch.
        await LiveActivitySync.shared.settle()
        #endif
        return .result()
    }
}

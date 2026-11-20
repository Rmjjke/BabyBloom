import Foundation
import Observation
import UserNotifications

/// Whether the current foreground visit began with a tap on one of the app's
/// notifications: the parent came for that notification's subject, and Home
/// shows no Premium card on top of it.
///
/// It is the app's notification-center delegate, and on purpose it answers
/// only the tap. With no `willPresent`, a notification that fires while the
/// app is open is handled exactly as before the delegate existed: the system
/// shows nothing.
@MainActor
@Observable
final class NotificationLaunch: NSObject {

    static let shared = NotificationLaunch()

    /// Set by a tap, cleared when the app goes to the background.
    private(set) var isActive = false

    /// Called from the app's `init`: the system delivers the tap that launched
    /// the app only to a delegate set before launching finishes.
    func install(center: UNUserNotificationCenter = .current()) {
        center.delegate = self
    }

    func noteTap() { isActive = true }

    func sceneMovedToBackground() { isActive = false }
}

extension NotificationLaunch: UNUserNotificationCenterDelegate {
    /// The app registers no notification actions, so every response is the
    /// default tap that opens the app; a dismiss reaches here only for a
    /// category that asks for it, and is no visit.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let opened = response.actionIdentifier != UNNotificationDismissActionIdentifier
        if opened {
            Task { @MainActor in NotificationLaunch.shared.noteTap() }
        }
        completionHandler()
    }
}

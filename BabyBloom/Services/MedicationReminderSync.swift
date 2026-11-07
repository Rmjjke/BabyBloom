import CoreData
import Foundation
import os
import SwiftData
import UIKit
import UserNotifications

/// A medication reminder as the notification centre takes it.
struct ScheduledReminder: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    /// Seconds from now. Elapsed time, as the interval is: a night the clocks
    /// change on moves the wall clock, not the moment.
    let delay: TimeInterval
}

/// The part of the notification centre the reconcile uses; tests pass a fake.
protocol ReminderCenter: Sendable {
    func pendingIdentifiers() async -> [String]
    func add(_ reminder: ScheduledReminder) async
    func remove(_ identifiers: [String]) async
}

struct SystemReminderCenter: ReminderCenter {
    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    /// No badge, the default sound and the plain interruption level: a fact to
    /// read when it comes, not one that breaks through a Focus. It comes at
    /// night like at any other hour, which is what the parent turned it on for.
    func add(_ reminder: ScheduledReminder) async {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.delay), repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
    }

    func remove(_ identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Keeps this device's medication reminders in step with the store: it asks
/// `MedicationReminderPlan` what should be pending and makes the notification
/// centre agree, removing any `bb.med.*` request the plan no longer wants.
///
/// A pass runs at once after every local store save, so every surface that
/// logs, moves or deletes a dose, or edits, ends or deletes a medication, is
/// covered without a call of its own; on a remote store change; on every
/// foregrounding and backgrounding; when a switch changes; and when
/// notifications are allowed. The body names the dose it counts from: with
/// sync back on and nothing pushing, a dose logged on another phone would
/// reach this reminder only when the app next ran here.
@MainActor
final class MedicationReminderSync {
    static let shared = MedicationReminderSync(center: SystemReminderCenter())

    private let center: ReminderCenter
    private let defaults: UserDefaults
    private let context: @MainActor () -> ModelContext
    private var isStarted = false
    private var observers: [NSObjectProtocol] = []
    private var pendingChange: Task<Void, Never>?
    /// The pass in flight. Each new pass waits for it, so the last one, read
    /// from the freshest store, is the one that lands.
    private var tail: Task<Void, Never>?
    private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    private static let log = Logger(subsystem: "com.nenita.app", category: "Notifications")

    init(center: ReminderCenter, defaults: UserDefaults = .standard,
         context: @escaping @MainActor () -> ModelContext = { SharedStore.container.mainContext }) {
        self.center = center
        self.defaults = defaults
        self.context = context
    }

    /// Subscribes once: the root `.onAppear` fires again on a language change.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        // Block observers: `Notification` is not Sendable and cannot cross
        // onto the main actor under Swift 6.
        // A local save passes at once: a parent who logs a dose and locks the
        // phone must not keep the old time pending.
        observers.append(NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.remoteStoreChanged() }
        })
        reconcile()
    }

    /// Remote changes can come in bursts (a CloudKit import, were sync turned
    /// back on); one pass per burst.
    private func remoteStoreChanged() {
        pendingChange?.cancel()
        pendingChange = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    /// One pass, from the store as it is when the pass runs.
    func reconcile() {
        let previous = tail
        tail = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let now = AppClock.now
            let courses = Self.courses(in: context(), now: now, defaults: defaults)
            await apply(MedicationReminderPlan.reminders(for: courses), now: now)
            NotificationManager.shared.logPendingIfAsked()
        }
    }

    /// A pass at backgrounding, held open by a background task: the app may be
    /// suspended right after, and the pass awaits the notification centre.
    func reconcileBeforeSuspension() {
        endBackgroundTask()
        let id = UIApplication.shared.beginBackgroundTask(withName: "medication reminders") { [weak self] in
            self?.endBackgroundTask()
        }
        backgroundTask = id
        reconcile()
        let pass = tail
        Task { [weak self] in
            await pass?.value
            // Only its own: a later backgrounding may have begun another.
            if self?.backgroundTask == id { self?.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// Makes the centre hold exactly `wanted` among the medication ids. Every
    /// wanted request is added again: the same id replaces the old one, so a
    /// moved time or a changed name takes effect.
    func apply(_ wanted: [MedicationReminderPlan.Reminder], now: Date) async {
        let stale = MedicationReminderPlan.stale(pending: await center.pendingIdentifiers(), wanted: wanted)
        if !stale.isEmpty { await center.remove(stale) }
        for reminder in wanted {
            let words = MedicationFormat.reminder(name: reminder.name, lastDose: reminder.lastDose,
                                                  fireDate: reminder.fireDate)
            await center.add(ScheduledReminder(identifier: reminder.identifier, title: words.title,
                                               body: words.body, delay: Self.delay(until: reminder.fireDate, now: now)))
        }
        Self.log.info("medication reminders: \(wanted.count, privacy: .public) pending, \(stale.count, privacy: .public) removed")
    }

    static func courses(in context: ModelContext, now: Date, defaults: UserDefaults) -> [MedicationReminderPlan.Course] {
        let medicines = (try? context.fetch(FetchDescriptor<Medicine>())) ?? []
        return medicines.map { medicine in
            MedicationReminderPlan.Course(
                id: medicine.id, name: medicine.name,
                isOn: defaults.bool(forKey: MedicationReminderPlan.switchKey(for: medicine.id)),
                isEnded: medicine.isEnded, schedule: medicine.schedule(now: now))
        }
    }

    private static func delay(until fire: Date, now: Date) -> TimeInterval {
        #if targetEnvironment(simulator)
        // `-BBMedicationNotifyIn 5` delivers in five seconds with the words of
        // the real fire time, so the banner can be looked at without waiting.
        let lever = UserDefaults.standard.integer(forKey: "BBMedicationNotifyIn")
        if lever > 0 { return TimeInterval(lever) }
        #endif
        return fire.timeIntervalSince(now)
    }
}

/// Whether iOS lets the app notify, as the reminder switches draw it. Read at
/// launch, on every foregrounding (the parent may come back from Settings)
/// and after the app's ask.
@MainActor @Observable
final class NotificationPermission {
    static let shared = NotificationPermission()

    enum State { case notAsked, allowed, denied }

    /// Until the first read: a switch drawn as not asked shows its stored
    /// value and stays usable, and its ask resolves at once if iOS has already
    /// answered.
    private(set) var state: State = .notAsked

    func refresh() async {
        state = Self.state(of: await Self.status())
    }

    static func state(of status: UNAuthorizationStatus) -> State {
        switch status {
        case .notDetermined: .notAsked
        case .denied: .denied
        // Authorized, provisional, ephemeral, and statuses newer than this code.
        default: .allowed
        }
    }

    /// Nonisolated, so the settings object never crosses onto the main actor.
    nonisolated private static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

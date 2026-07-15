import Foundation
import UserNotifications

// MARK: - Notification Manager

final class NotificationManager: @unchecked Sendable {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Notification IDs

    private enum NID: String {
        case feedingReminder     = "bb.feeding.reminder"
        case feedingActiveBF     = "bb.feeding.active.bf"
        case sleepWakeWindow     = "bb.sleep.wake_window"
        case sleepActive         = "bb.sleep.active"
        case diaperReminder      = "bb.diaper.reminder"
        case engageMeasurements  = "bb.engage.measurements"
        case engageMonthlyGrowth = "bb.engage.monthly_growth"
        case engageWeekly        = "bb.engage.weekly_summary"
        case engageIdle          = "bb.engage.idle"
    }

    // MARK: - UserDefaults keys

    private let kFirstFeeding    = "hasLoggedFirstFeeding"
    private let kFirstSleep      = "hasLoggedFirstSleep"
    private let kFirstGrowth     = "hasFirstGrowthEntry"
    private let kWeeklyScheduled = "hasScheduledWeeklySummary"
    private let kBabyName        = "bb.storedBabyName"

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                guard granted else { return }
                self?.scheduleWeeklySummary()
            }
    }

    // MARK: - App lifecycle

    func onAppForegrounded() {
        guard UserDefaults.standard.bool(forKey: kFirstFeeding) ||
              UserDefaults.standard.bool(forKey: kFirstSleep) else { return }
        let name = storedBabyName
        cancel(.engageIdle)
        post(id: .engageIdle,
             title: "notification.idle_title".l,
             body:  String(format: "notification.idle_body".l, name),
             in:    48 * 3600)
    }

    // MARK: - Feeding events

    /// Call every time a feeding entry is created.
    /// - Parameter recentFeedingTimes: dates of the last ≤7 feedings (supplied by the view).
    ///   When ≥3 are available, the reminder uses the observed average interval
    ///   (+10 min buffer); otherwise it falls back to the age-based table.
    func onFeedingSaved(ageMonths: Int, babyName: String, isActiveBF: Bool, recentFeedingTimes: [Date] = []) {
        storeBabyName(babyName)
        let isFirst = !UserDefaults.standard.bool(forKey: kFirstFeeding)
        if isFirst {
            UserDefaults.standard.set(true, forKey: kFirstFeeding)
            scheduleMeasurementsPrompt(babyName: babyName)
            scheduleDiaperReminderIfNeeded(ageMonths: ageMonths, babyName: babyName)
        }
        // Re-schedule feeding reminder from now.
        // Smart interval: with ≥3 recent feedings use the measured average + 10 min buffer,
        // otherwise fall back to the age-based table.
        cancel(.feedingReminder)
        let smartInterval: TimeInterval?
        if recentFeedingTimes.count >= 3 {
            smartInterval = calculateAverageIntervalMinutes(times: recentFeedingTimes) * 60 + 10 * 60
        } else {
            smartInterval = feedingInterval(ageMonths: ageMonths)
        }
        if let interval = smartInterval {
            post(id: .feedingReminder,
                 title: "notification.feeding_title".l,
                 body:  "notification.feeding_body".l,
                 in:    interval)
        }
        // BF active-session alert
        cancel(.feedingActiveBF)
        if isActiveBF {
            post(id: .feedingActiveBF,
                 title: "notification.feeding_long_title".l,
                 body:  "notification.feeding_long_body".l,
                 in:    40 * 60,
                 timeSensitive: true)
        }
    }

    /// Call when a breastfeeding timer is stopped.
    func onFeedingTimerStopped(ageMonths: Int) {
        cancel(.feedingActiveBF)
        cancel(.feedingReminder)
        if let interval = feedingInterval(ageMonths: ageMonths) {
            post(id: .feedingReminder,
                 title: "notification.feeding_title".l,
                 body:  "notification.feeding_body".l,
                 in:    interval)
        }
    }

    // MARK: - Sleep events

    /// Call when a sleep timer starts or a manual sleep entry is saved (active).
    func onSleepStarted(ageMonths: Int, babyName: String, isNight: Bool) {
        storeBabyName(babyName)
        let isFirst = !UserDefaults.standard.bool(forKey: kFirstSleep)
        if isFirst {
            UserDefaults.standard.set(true, forKey: kFirstSleep)
            scheduleDiaperReminderIfNeeded(ageMonths: ageMonths, babyName: babyName)
        }
        cancel(.sleepWakeWindow)
        cancel(.sleepActive)
        post(id: .sleepActive,
             title: "notification.sleep_active_title".l,
             body:  "notification.sleep_active_body".l,
             in:    activeSleepInterval(isNight: isNight, ageMonths: ageMonths),
             timeSensitive: true)
    }

    /// Call when sleep ends (timer stopped or manual entry with endTime).
    func onSleepEnded(ageMonths: Int) {
        cancel(.sleepActive)
        cancel(.sleepWakeWindow)
        if let ww = wakeWindow(ageMonths: ageMonths) {
            post(id: .sleepWakeWindow,
                 title: "notification.sleep_title".l,
                 body:  "notification.sleep_body".l,
                 in:    ww)
        }
    }

    // MARK: - Diaper events

    /// Call every time a diaper entry is saved.
    func onDiaperSaved(ageMonths: Int, babyName: String) {
        storeBabyName(babyName)
        scheduleDiaperReminder(ageMonths: ageMonths, babyName: babyName)
    }

    // MARK: - Growth events

    /// Call when the first GrowthEntry is saved.
    func onFirstGrowthEntrySaved() {
        cancel(.engageMeasurements)
        UserDefaults.standard.set(true, forKey: kFirstGrowth)
        scheduleMonthlyGrowthReminder()
    }

    // MARK: - Private: Diaper

    private func scheduleDiaperReminderIfNeeded(ageMonths: Int, babyName: String) {
        // Only start diaper reminders once (when first feeding OR sleep is logged)
        let alreadyActive = UserDefaults.standard.bool(forKey: kFirstFeeding) ||
                            UserDefaults.standard.bool(forKey: kFirstSleep)
        if !alreadyActive {
            scheduleDiaperReminder(ageMonths: ageMonths, babyName: babyName)
        }
    }

    private func scheduleDiaperReminder(ageMonths: Int, babyName: String) {
        cancel(.diaperReminder)
        guard let interval = diaperInterval(ageMonths: ageMonths) else { return }
        post(id: .diaperReminder,
             title: "notification.diaper_title".l,
             body:  String(format: "notification.diaper_body".l, babyName),
             in:    interval)
    }

    // MARK: - Private: Engagement

    private func scheduleMeasurementsPrompt(babyName: String) {
        guard !UserDefaults.standard.bool(forKey: kFirstGrowth) else { return }
        cancel(.engageMeasurements)
        post(id: .engageMeasurements,
             title: String(format: "notification.measurements_title".l, babyName),
             body:  "notification.measurements_body".l,
             in:    3 * 24 * 3600)
    }

    private func scheduleMonthlyGrowthReminder() {
        cancel(.engageMonthlyGrowth)
        let content      = UNMutableNotificationContent()
        content.title    = "notification.monthly_growth_title".l
        content.body     = "notification.monthly_growth_body".l
        content.sound    = .default
        var comps        = DateComponents()
        comps.day        = 1
        comps.hour       = 10
        comps.minute     = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: NID.engageMonthlyGrowth.rawValue,
                                        content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func scheduleWeeklySummary() {
        guard !UserDefaults.standard.bool(forKey: kWeeklyScheduled) else { return }
        UserDefaults.standard.set(true, forKey: kWeeklyScheduled)
        cancel(.engageWeekly)
        let content      = UNMutableNotificationContent()
        content.title    = "notification.weekly_title".l
        content.body     = "notification.weekly_body".l
        content.sound    = .default
        var comps        = DateComponents()
        comps.weekday    = 1   // Sunday
        comps.hour       = 20
        comps.minute     = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: NID.engageWeekly.rawValue,
                                        content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Private: Baby name storage

    private var storedBabyName: String {
        UserDefaults.standard.string(forKey: kBabyName) ?? "Baby"
    }

    private func storeBabyName(_ name: String) {
        UserDefaults.standard.set(name, forKey: kBabyName)
    }

    // MARK: - Average interval

    /// Average interval (in minutes) between the most recent feedings.
    /// Uses the last 7 entries, ignores gaps > 8 h, and defaults to 120 min
    /// when there is not enough usable data. Ported 1:1 from the former
    /// NotificationService for smart feeding reminders.
    func calculateAverageIntervalMinutes(times: [Date]) -> Double {
        guard times.count >= 2 else { return 120 } // default 2h
        let sorted = times.sorted()
        let recent = Array(sorted.suffix(7))
        var intervals: [Double] = []
        for i in 1..<recent.count {
            let interval = recent[i].timeIntervalSince(recent[i-1]) / 60
            if interval > 0 && interval < 480 { // ignore > 8h gaps
                intervals.append(interval)
            }
        }
        guard !intervals.isEmpty else { return 120 }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    // MARK: - Private: Age-based interval tables

    /// Returns nil when reminders should be disabled for this age group.
    private func feedingInterval(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:      return 2.5 * 3600   // 0–4 weeks: every ~2–3 h
        case 1...2:  return 3.0 * 3600
        case 3...5:  return 3.5 * 3600
        case 6...8:  return 4.0 * 3600
        case 9...11: return 4.5 * 3600
        default:     return nil           // 12+ months: parent-managed
        }
    }

    private func wakeWindow(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:       return 1.0 * 3600
        case 1...2:   return 1.5 * 3600
        case 3...5:   return 2.0 * 3600
        case 6...7:   return 2.5 * 3600
        case 8...11:  return 3.0 * 3600
        case 12...17: return 4.0 * 3600
        default:      return nil
        }
    }

    private func diaperInterval(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:      return 4 * 3600
        case 1...5:  return 6 * 3600
        case 6...11: return 8 * 3600
        default:     return nil
        }
    }

    private func activeSleepInterval(isNight: Bool, ageMonths: Int) -> TimeInterval {
        if isNight { return 9 * 3600 }
        return ageMonths <= 2 ? 2.5 * 3600 : 2.0 * 3600
    }

    // MARK: - Private: Core post / cancel

    private func post(id: NID, title: String, body: String, in seconds: TimeInterval, timeSensitive: Bool = false) {
        let content      = UNMutableNotificationContent()
        content.title    = title
        content.body     = body
        content.sound    = .default
        if timeSensitive {
            content.interruptionLevel = .timeSensitive
        }
        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request  = UNNotificationRequest(identifier: id.rawValue, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancel(_ id: NID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id.rawValue])
    }
}

import Foundation
import UserNotifications

// MARK: - Smart Notification Service
// Analyzes last 5-7 intervals to predict next event time
actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission
    func requestAuthorization() async throws {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    var isAuthorized: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule Feeding Reminder
    func scheduleFeedingReminder(lastFeedingTime: Date, averageIntervalMinutes: Double) async {
        let identifier = "feeding_reminder"
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let intervalWithBuffer = averageIntervalMinutes + 10 // +10 min buffer
        let fireDate = lastFeedingTime.addingTimeInterval(intervalWithBuffer * 60)

        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Время кормления 🍼"
        content.body = "Малыш скоро проголодается. Среднее время между кормлениями — \(Int(averageIntervalMinutes)) мин."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Schedule Sleep Tiredness Reminder
    func scheduleSleepReminder(ageMonths: Int, lastSleepEnd: Date) async {
        let identifier = "sleep_reminder"
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Awake windows by age
        let awakeWindowHours: Double
        switch ageMonths {
        case 0..<2: awakeWindowHours = 1.0
        case 2..<4: awakeWindowHours = 1.5
        case 4..<6: awakeWindowHours = 2.0
        case 6..<9: awakeWindowHours = 2.5
        case 9..<12: awakeWindowHours = 3.0
        default: awakeWindowHours = 3.5
        }

        let fireDate = lastSleepEnd.addingTimeInterval(awakeWindowHours * 3600)
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Малыш устал 😴"
        content.body = "По возрастной норме время бодрствования (\(Int(awakeWindowHours * 60)) мин) заканчивается. Пора укладывать."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Schedule Diaper Reminder
    func scheduleDiaperReminder() async {
        let identifier = "diaper_reminder"
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        // Every 2.5 hours
        let content = UNMutableNotificationContent()
        content.title = "Подгузник 👶"
        content.body = "Прошло 2.5 часа — не забудьте проверить подгузник."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2.5 * 3600, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Schedule Medication Reminder
    func scheduleMedicationReminder(name: String, dose: String, time: Date, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Лекарство 💊"
        content.body = "\(name) — \(dose)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "med_\(identifier)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Schedule Weekly Weighing
    func scheduleWeighingReminder() async {
        let identifier = "weighing_reminder"
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Взвешивание 📏"
        content.body = "Пора взвесить малыша! Запишите рост и вес, чтобы отслеживать динамику."
        content.sound = .default

        // Every Monday at 10:00
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Calculate Average Interval
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

    // MARK: - Cancel All
    func cancelAll() async {
        await center.removeAllPendingNotificationRequests()
    }

    func cancelNotification(identifier: String) async {
        await center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

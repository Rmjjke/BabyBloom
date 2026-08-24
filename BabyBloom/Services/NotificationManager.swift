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
        case growthWeighIn       = "bb.growth.weigh_in"
        case growthNewbornFlag   = "bb.growth.newborn_flag"
        case growthGainLow       = "bb.growth.gain_low"
    }

    // MARK: - UserDefaults keys

    private let kFirstFeeding    = "hasLoggedFirstFeeding"
    private let kFirstSleep      = "hasLoggedFirstSleep"
    private let kFirstGrowth     = "hasFirstGrowthEntry"
    private let kWeeklyScheduled = "hasScheduledWeeklySummary"
    private let kBabyName        = "bb.storedBabyName"
    private let kLastGainSignal  = "bb.growth.lastGainSignalAt"

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
        // Weekly summary is idempotent (fixed ID, cancel-before-add); (re)schedule it
        // here so users who granted permission after launch still get it.
        scheduleWeeklySummary()
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
            scheduleDiaperReminderIfNeeded(ageMonths: ageMonths, babyName: babyName, isFirstActivation: isFirst)
        }
        // Re-schedule feeding reminder from now.
        cancel(.feedingReminder)
        if let interval = feedingReminderInterval(ageMonths: ageMonths, recentFeedingTimes: recentFeedingTimes) {
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
            scheduleDiaperReminderIfNeeded(ageMonths: ageMonths, babyName: babyName, isFirstActivation: isFirst)
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
    /// The wake-window reminder is scheduled relative to `endedAt`, not "now",
    /// so a sleep logged after the fact still fires at the correct moment.
    func onSleepEnded(ageMonths: Int, endedAt: Date) {
        cancel(.sleepActive)
        cancel(.sleepWakeWindow)
        guard let ww = wakeWindow(ageMonths: ageMonths) else { return }
        let remaining = ww - Date().timeIntervalSince(endedAt)
        guard remaining > 0 else { return }
        post(id: .sleepWakeWindow,
             title: "notification.sleep_title".l,
             body:  "notification.sleep_body".l,
             in:    remaining)
    }

    /// Deprecated: retained so existing call-sites compile until Workstream C
    /// wires in the real end time. Assumes the sleep ended just now.
    @available(*, deprecated, message: "Use onSleepEnded(ageMonths:endedAt:) with the real end time.")
    func onSleepEnded(ageMonths: Int) {
        onSleepEnded(ageMonths: ageMonths, endedAt: Date())
    }

    // MARK: - Diaper events

    /// Call every time a diaper entry is saved.
    func onDiaperSaved(ageMonths: Int, babyName: String) {
        storeBabyName(babyName)
        scheduleDiaperReminder(ageMonths: ageMonths, babyName: babyName)
    }

    // MARK: - Delete events

    /// Delay from `now` for a reminder that belongs to a PAST event — the
    /// interval runs from when the event happened, not from when an entry was
    /// deleted. Returns nil when reminders are off for this age (`interval` is
    /// nil), when nothing survives to anchor on, or when the moment has already
    /// gone by: a reminder for a feeding four hours ago is noise, not help.
    ///
    /// Deleting one entry must never leave the parent with NO reminder until
    /// they happen to log the next one — that is the bug this exists to close.
    func reanchoredDelay(interval: TimeInterval?, anchor: Date?, now: Date = Date()) -> TimeInterval? {
        guard let interval, let anchor else { return nil }
        let remaining = interval - now.timeIntervalSince(anchor)
        return remaining > 0 ? remaining : nil
    }

    /// Call when a feeding entry is deleted.
    /// - Parameters:
    ///   - remainingActive: whether an active breastfeeding session still exists.
    ///     The active-BF alert is cancelled only when no active session remains.
    ///   - remainingFeedingTimes: start times of the feedings that SURVIVE the
    ///     delete. The generic reminder is re-anchored on the newest of them.
    func onFeedingDeleted(ageMonths: Int, remainingActive: Bool, remainingFeedingTimes: [Date]) {
        cancel(.feedingReminder)
        if !remainingActive {
            cancel(.feedingActiveBF)
        }
        guard let delay = reanchoredDelay(
            interval: feedingReminderInterval(ageMonths: ageMonths,
                                              recentFeedingTimes: remainingFeedingTimes),
            anchor: remainingFeedingTimes.max()
        ) else { return }
        post(id: .feedingReminder,
             title: "notification.feeding_title".l,
             body:  "notification.feeding_body".l,
             in:    delay)
    }

    /// Call when a sleep entry is deleted.
    /// - Parameters:
    ///   - remainingActive: whether an active sleep session still exists. While
    ///     one does, it governs the reminders and nothing is recomputed.
    ///   - lastRemainingSleepEnd: end time of the newest FINISHED sleep that
    ///     survives the delete; the wake window is re-anchored on it.
    func onSleepDeleted(ageMonths: Int, remainingActive: Bool, lastRemainingSleepEnd: Date?) {
        guard !remainingActive else { return }
        cancel(.sleepActive)
        cancel(.sleepWakeWindow)
        guard let endedAt = lastRemainingSleepEnd else { return }
        onSleepEnded(ageMonths: ageMonths, endedAt: endedAt)
    }

    /// Call when a diaper entry is deleted.
    /// - Parameter lastRemainingDiaperTime: time of the newest diaper that
    ///   survives the delete; the reminder is re-anchored on it.
    func onDiaperDeleted(ageMonths: Int, babyName: String, lastRemainingDiaperTime: Date?) {
        cancel(.diaperReminder)
        guard let delay = reanchoredDelay(interval: diaperInterval(ageMonths: ageMonths),
                                          anchor: lastRemainingDiaperTime) else { return }
        post(id: .diaperReminder,
             title: "notification.diaper_title".l,
             body:  String(format: "notification.diaper_body".l, babyName),
             in:    delay)
    }

    // MARK: - Growth events

    /// Call when the first GrowthEntry is saved.
    func onFirstGrowthEntrySaved() {
        cancel(.engageMeasurements)
        UserDefaults.standard.set(true, forKey: kFirstGrowth)
        // Weigh-in reminders are scheduled by `onGrowthDataChanged`, which knows
        // the baby's age and when it was last weighed.
    }

    /// Recomputes every growth-driven notification from the current data.
    ///
    /// Call after any change to the weight history and whenever the growth screen
    /// appears. Every path here is cancel-before-add, so calling it repeatedly is
    /// safe and — more importantly — a signal that no longer applies gets taken
    /// down rather than left to fire.
    func onGrowthDataChanged(
        babyName: String,
        birthDate: Date,
        correctedBirthDate: Date,
        birthWeightKg: Double?,
        isMale: Bool,
        measurements: [WeightMeasurement],
        isPremium: Bool,
        now: Date = Date()
    ) {
        storeBabyName(babyName)
        scheduleWeighInReminder(birthDate: birthDate, measurements: measurements, babyName: babyName, now: now)
        scheduleNewbornFlagIfNeeded(
            birthDate: birthDate,
            birthWeightKg: birthWeightKg,
            measurements: measurements,
            now: now
        )
        scheduleGainSignalIfNeeded(
            correctedBirthDate: correctedBirthDate,
            isMale: isMale,
            measurements: measurements,
            isPremium: isPremium,
            now: now
        )
    }

    // MARK: - Private: Growth reminders

    /// How often it is worth weighing, by age. Newborns change fast enough that
    /// a few days matter; a nine-month-old does not.
    func weighInIntervalDays(ageDays: Int) -> Int {
        switch ageDays {
        case ..<14:  return 3
        case ..<90:  return 7
        case ..<365: return 14
        default:     return 30
        }
    }

    private func scheduleWeighInReminder(
        birthDate: Date,
        measurements: [WeightMeasurement],
        babyName: String,
        now: Date
    ) {
        cancel(.growthWeighIn)
        // Replaces the old fixed monthly reminder, which nagged every 1st of the
        // month regardless of age or of whether the parent had just weighed.
        // Cancelled here too so it stops firing for users who already have it.
        cancel(.engageMonthlyGrowth)

        let ageDays = days(from: birthDate, to: now)
        guard ageDays >= 0 else { return }
        let interval = TimeInterval(weighInIntervalDays(ageDays: ageDays) * 24 * 3600)

        // Measure from the last weighing, so a parent who just weighed is not
        // reminded tomorrow.
        let last = measurements.map(\.date).max() ?? birthDate
        let due = last.addingTimeInterval(interval)
        let delay = max(due.timeIntervalSince(now), 3600)
        post(id: .growthWeighIn,
             title: "notification.weigh_in_title".l,
             body:  String(format: "notification.weigh_in_body".l, babyName),
             in:    delay)
    }

    /// The one growth signal that is free for everyone. It is about safety, and
    /// paywalling it would be indefensible.
    private func scheduleNewbornFlagIfNeeded(
        birthDate: Date,
        birthWeightKg: Double?,
        measurements: [WeightMeasurement],
        now: Date
    ) {
        cancel(.growthNewbornFlag)
        guard let status = NewbornWeightLoss.analyse(
            birthWeightKg: birthWeightKg,
            birthDate: birthDate,
            measurements: measurements,
            now: now
        ), let flag = status.flags.first else { return }

        // A few hours out, not instantly: the card already says this on screen,
        // so the notification's job is to catch a parent who has closed the app.
        post(id: .growthNewbornFlag,
             title: "notification.newborn_flag_title".l,
             body:  flag == .lossExceeds10Percent
                    ? "newborn.flag_loss".l
                    : "newborn.flag_not_regained".l,
             in:    4 * 3600)
    }

    /// Premium: analysis rather than safety.
    private func scheduleGainSignalIfNeeded(
        correctedBirthDate: Date,
        isMale: Bool,
        measurements: [WeightMeasurement],
        isPremium: Bool,
        now: Date
    ) {
        cancel(.growthGainLow)
        guard isPremium else { return }
        guard WeightVelocity.consecutiveBelowReference(
            measurements: measurements,
            correctedBirthDate: correctedBirthDate,
            isMale: isMale
        ) else { return }

        // At most one of these a week. An app about a worrying subject must not
        // become the thing generating the worry.
        let last = UserDefaults.standard.object(forKey: kLastGainSignal) as? Date
        if let last, now.timeIntervalSince(last) < 7 * 24 * 3600 { return }
        UserDefaults.standard.set(now, forKey: kLastGainSignal)

        post(id: .growthGainLow,
             title: "notification.gain_low_title".l,
             body:  "notification.gain_low_body".l,
             in:    4 * 3600)
    }

    private func days(from: Date, to: Date) -> Int {
        Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Bridge from the SwiftData layer. Kept separate from the primitive-taking
    /// method above so the scheduling logic stays testable without a model
    /// container, matching how the rest of this service is built.
    func onGrowthDataChanged(baby: Baby, entries: [GrowthEntry], isPremium: Bool) {
        onGrowthDataChanged(
            babyName: baby.name,
            birthDate: baby.birthDate,
            correctedBirthDate: baby.correctedBirthDate,
            birthWeightKg: baby.birthWeightKg,
            isMale: baby.gender == .male,
            measurements: entries.weightMeasurements,
            isPremium: isPremium
        )
    }

    // MARK: - Private: Diaper

    /// Start diaper reminders once, on the first feeding OR sleep activation.
    /// The caller passes `isFirstActivation` because the `kFirstFeeding`/`kFirstSleep`
    /// flags are already set by the time this runs, so they can't be checked here.
    private func scheduleDiaperReminderIfNeeded(ageMonths: Int, babyName: String, isFirstActivation: Bool) {
        guard isFirstActivation else { return }
        scheduleDiaperReminder(ageMonths: ageMonths, babyName: babyName)
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

    private func scheduleWeeklySummary() {
        // Idempotent: fixed ID, cancel-before-add. Safe to call repeatedly
        // (e.g. from onAppForegrounded) so a late-granted permission still gets it.
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

    // MARK: - Interval tables (internal for @testable access)

    /// Resolved feeding-reminder interval: the measured average (+10 min buffer)
    /// when ≥3 recent feedings are available, otherwise the age-based table.
    /// Returns nil when reminders are disabled for this age group.
    func feedingReminderInterval(ageMonths: Int, recentFeedingTimes: [Date]) -> TimeInterval? {
        if recentFeedingTimes.count >= 3 {
            return calculateAverageIntervalMinutes(times: recentFeedingTimes) * 60 + 10 * 60
        }
        return feedingInterval(ageMonths: ageMonths)
    }

    /// Returns nil when reminders should be disabled for this age group.
    func feedingInterval(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:      return 2.5 * 3600   // 0–4 weeks: every ~2–3 h
        case 1...2:  return 3.0 * 3600
        case 3...5:  return 3.5 * 3600
        case 6...8:  return 4.0 * 3600
        case 9...11: return 4.5 * 3600
        default:     return nil           // 12+ months: parent-managed
        }
    }

    func wakeWindow(ageMonths: Int) -> TimeInterval? {
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

    func diaperInterval(ageMonths: Int) -> TimeInterval? {
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

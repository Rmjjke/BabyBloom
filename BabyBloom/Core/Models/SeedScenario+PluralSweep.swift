import Foundation
import OSLog
import SwiftData

#if targetEnvironment(simulator)
/// The plural sweep: one count `n` (`-BBCount`, default 21) put on as many
/// screens as can carry it, so every plural form of a language can be read in
/// place by relaunching with another `n`. Everything hangs off `now`.
///
/// Which screen gets `n`, in priority order when they conflict:
/// 1. the medicine's 24-hour dose count — always;
/// 2. the questions asked at the latest visit — always;
/// 3. the weight-gain interval (and the nutrition window it defines) — from
///    `n = 7`;
/// 4. the age in days — only below 7, where the age still reads in days.
///
/// 3 and 4 cannot share one baby. The age reads in days only in the first
/// week, while every growth card ignores weighings inside the 21-day newborn
/// window, and the trend needs four weeks of them on top. So below 7 the baby
/// is `n` days old with no weighings. From 7 up the age reads in weeks or
/// months whatever it is, and the baby is made old enough for the weighings.
/// Between 3 and 6 the gain interval could show too; the age wins there,
/// because 5 and 6 are its only way to reach a «many» form in days.
///
/// The trend reads the drop `-BBDrop` (default 1.5 centile spaces) whenever
/// the weighings exist; it never touches `n`.
extension SeedScenario {
    /// Below this the age is told in days (`Baby.describeAge`).
    private static let ageInDaysBelow = 7

    /// The first weighing's day of life: past the newborn window with room to
    /// spare, so neither the gain deferral nor the trend's filter drops it.
    private static let firstWeighingDayOfLife = NewbornWeightLoss.observationWindowDays + 9

    func seedPluralSweep(into context: ModelContext, now: Date = AppClock.now,
                         count n: Int = SeedScenario.pluralSweepCount,
                         drop: Double = SeedScenario.pluralSweepDrop) {
        let cal = Calendar.current
        func daysAgo(_ k: Int) -> Date { cal.date(byAdding: .day, value: -k, to: now)! }

        let showsAgeInDays = n < Self.ageInDaysBelow
        // Older than `n`, so the gain pair is (n days ago, today) and the
        // series still spans the trend's four weeks.
        let firstWeighing = max(GrowthTrend.minimumSpanDays, n + 1)
        let ageDays = showsAgeInDays ? n : firstWeighing + Self.firstWeighingDayOfLife

        let baby = Baby(name: "Mia", birthDate: daysAgo(ageDays), gender: .female, feedingType: .mixed)
        // 1.5 SD under the median, the 7th centile. Under the 9th the trend
        // flags a fall from one space, so every drop from 1.0 up is shown.
        baby.birthWeightKg = (WHOGrowthStandard.weight(atZ: -1.5, ageDays: 0, isMale: false)! * 1000)
            .rounded() / 1000
        context.insert(baby)

        if !showsAgeInDays {
            // Scored with the same age the trend uses, so each lands on its z.
            // The two references round up to the gram and the latest down: the
            // drop can only come out a hair above the one asked for, never
            // under it — under, a drop of exactly 1.0 would read as stable.
            func weighing(daysAgo k: Int, z: Double, roundUp: Bool) {
                let date = daysAgo(k)
                guard let age = WHOGrowthStandard.correctedAgeDaysIfBorn(
                        on: date, correctedBirthDate: baby.correctedBirthDate),
                      let kg = WHOGrowthStandard.weight(atZ: z, ageDays: age, isMale: false) else { return }
                let grams = (kg * 1000).rounded(roundUp ? .up : .down)
                let entry = GrowthEntry(date: date, weightKg: grams / 1000)
                entry.baby = baby
                context.insert(entry)
            }
            weighing(daysAgo: firstWeighing, z: 0, roundUp: true)
            weighing(daysAgo: n, z: 0, roundUp: true)
            weighing(daysAgo: 0, z: -drop * GrowthTrend.zPerCentileSpace, roundUp: false)
        }

        // `n` doses spaced 24 h / (n + 1) apart, the latest now, so all of
        // them sit inside the last 24 hours. The interval is that spacing
        // rounded down to the form's 15-minute step, so each dose is on time,
        // and the maximum is `n`: the count line reads n of n, at the limit
        // and never over it. Both hold up to n = 95; from 96 the spacing is
        // under the 15-minute floor (doses read early), and from 1440 the
        // one-minute floor pushes the oldest doses past 24 hours.
        let spacing = max(1, 24 * 60 / (n + 1))
        let medicine = Medicine(name: "Saline drops", intervalMinutes: max(15, spacing / 15 * 15),
                                doseText: "1 drop")
        medicine.maxDosesPer24h = n
        medicine.baby = baby
        let step = TimeInterval(spacing) * 60
        medicine.createdAt = now.addingTimeInterval(-step * Double(n))
        context.insert(medicine)
        for index in 0..<n {
            context.insert(CustomEvent.dose(of: medicine, at: now.addingTimeInterval(-step * Double(index))))
        }

        // A visit today with every question asked at it: the report's asked
        // section counts the latest visit's questions only.
        let visit = DoctorVisit(date: DoctorVisitActions.visitDay(now, calendar: cal))
        visit.createdAt = now
        visit.baby = baby
        context.insert(visit)
        for index in 0..<n {
            let question = DoctorQuestion(text: "Question \(index + 1)")
            question.createdAt = now.addingTimeInterval(-Double(n - 1 - index) * 60)
            question.baby = baby
            context.insert(question)
            question.visit = visit
            question.askedAt = visit.date
        }
    }

    // MARK: Launch arguments

    private static let countArgumentKey = "BBCount"
    private static let dropArgumentKey = "BBDrop"

    /// `-BBCount`: a positive whole number, 21 when absent.
    static var pluralSweepCount: Int {
        launchValue(countArgumentKey, default: 21) { Int($0).flatMap { $0 > 0 ? $0 : nil } }
    }

    /// `-BBDrop`: a positive number of centile spaces, 1.5 when absent.
    static var pluralSweepDrop: Double {
        launchValue(dropArgumentKey, default: 1.5) { Double($0).flatMap { $0 > 0 && $0.isFinite ? $0 : nil } }
    }

    /// Absent is the default; present but unusable traps, as an unknown
    /// scenario does: a typo must not pass as a sweep of the default count.
    private static func launchValue<T>(_ key: String, default fallback: T,
                                       parse: (String) -> T?) -> T {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return fallback }
        if let value = parse(raw) { return value }
        log.fault("""
            -\(key, privacy: .public) was \"\(raw, privacy: .public)\", \
            which is not a positive number. Nothing was seeded.
            """)
        fatalError("-\(key) was \"\(raw)\", which is not a positive number")
    }
}
#endif

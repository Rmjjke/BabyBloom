import Foundation
import SwiftData

#if targetEnvironment(simulator)
/// The weekly-summary fixtures (L3). Built from `AppClock.now`, so a run with
/// `-BBNow 2026-10-25T23:59:00` and one with `-BBNow 2026-10-26T00:00:00`
/// stand on either side of the Sunday → Monday edge with the same data.
extension SeedScenario {
    func seedWeekly(into context: ModelContext) {
        let calendar = WeeklySummary.calendar
        let now = AppClock.now
        let lastWeek = WeeklySummary.lastWeek(now: now)
        let before = lastWeek.shifted(byWeeks: -1)
        func day(_ week: WeeklySummary.Week, _ index: Int, hour: Int) -> Date {
            calendar.date(byAdding: .hour, value: 24 * index + hour, to: week.start)!
        }

        let isNewborn = self == .weeklyNewborn
        let birth = isNewborn
            ? calendar.date(byAdding: .day, value: -10, to: lastWeek.end)!
            : calendar.date(byAdding: .day, value: -60, to: now)!
        let baby = Baby(name: "Mia", birthDate: birth, gender: .female, feedingType: .breast)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        func logDay(_ week: WeeklySummary.Week, _ index: Int, feeds: Int, napHours: Double) {
            let start = day(week, index, hour: 0)
            guard start >= birth else { return }
            for feed in 0..<feeds {
                let time = day(week, index, hour: 1 + feed * 3)
                let entry = FeedingEntry(startTime: time, type: .breast, side: .left, volumeML: nil)
                entry.endTime = time.addingTimeInterval(15 * 60)
                entry.baby = baby
                context.insert(entry)
            }
            // A night that starts at 21:00 and ends the next morning, plus a nap.
            for (hour, length) in [(21, 7.0), (13, napHours)] {
                let sleep = SleepEntry(startTime: day(week, index, hour: hour), type: hour == 21 ? .night : .nap)
                sleep.endTime = sleep.startTime.addingTimeInterval(length * 3600)
                sleep.baby = baby
                context.insert(sleep)
            }
            let nappy = DiaperEntry(time: day(week, index, hour: 9), type: .wet)
            nappy.baby = baby
            context.insert(nappy)
        }

        let lastWeekDays = self == .weeklyGaps ? [0, 1, 3, 4] : Array(0...6)
        for index in lastWeekDays { logDay(lastWeek, index, feeds: 8, napHours: 1.5) }
        if self != .weeklyFirstWeek {
            for index in 0...6 { logDay(before, index, feeds: 7, napHours: 2) }
        }

        // Weighings: a pair ending last week (+210 g over 7 days), and one
        // ending the week before (+180), for the "Week before" line.
        let weighings: [(Date, Double)]
        switch self {
        case .weeklyFirstWeek:
            weighings = []
        case .weeklyNewborn:
            weighings = [(birth, 3.4), (day(lastWeek, 4, hour: 10), 3.3)]
        default:
            weighings = [(day(before, 0, hour: 10), 4.32),
                         (day(lastWeek, 0, hour: 10), 4.5),
                         (day(lastWeek, 6, hour: 10), 4.68)]
        }
        for (date, kg) in weighings {
            let entry = GrowthEntry(date: date, weightKg: kg, heightCm: nil, headCircumferenceCm: nil)
            entry.baby = baby
            context.insert(entry)
        }
    }
}
#endif

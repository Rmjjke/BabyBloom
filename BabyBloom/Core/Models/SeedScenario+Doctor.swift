import Foundation
import SwiftData

#if targetEnvironment(simulator)
/// The pediatrician-screen fixtures. Everything hangs off `now`, so a pinned
/// `-BBNow` moves the visits, the logs and the period together.
///
/// Models are inserted directly and never through `DoctorVisitActions`: a seed
/// must be able to write states the actions refuse (a question asked before it
/// was written) and must not send analytics for a fixture.
extension SeedScenario {
    func seedDoctor(into context: ModelContext, now: Date = AppClock.now) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
        // Wall-clock time on a calendar day, not `+ hours * 3600`, which lands
        // an hour off on the two days a year the clocks change.
        func at(_ n: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day(n))!
        }

        let baby = Baby(name: "Mia", birthDate: at(62, 8), gender: .female, feedingType: .mixed)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        func weigh(_ date: Date, _ kg: Double, height: Double? = nil, head: Double? = nil) {
            let entry = GrowthEntry(date: date, weightKg: kg, heightCm: height, headCircumferenceCm: head)
            entry.baby = baby
            context.insert(entry)
        }
        weigh(at(62, 8), 3.40, height: 51)
        weigh(at(35, 10), 4.30)
        // Eight weighings inside the day-20 period; height and head only at
        // its two ends, so the report shows a first and a last value.
        let kgByDay: [(Int, Double)] = [(20, 4.75), (18, 4.81), (15, 4.90), (12, 4.99),
                                        (9, 5.08), (6, 5.17), (3, 5.26), (1, 5.32)]
        for (n, kg) in kgByDay {
            weigh(at(n, 10), kg,
                  height: n == 20 ? 56 : (n == 1 ? 58 : nil),
                  head: n == 20 ? 38.5 : (n == 1 ? 39.0 : nil))
        }

        func feed(_ date: Date, _ type: FeedingEntry.FeedingType, side: FeedingEntry.BreastSide? = nil,
                  ml: Double? = nil, minutes: Int) {
            let entry = FeedingEntry(startTime: date, type: type, side: side, volumeML: ml)
            entry.endTime = date.addingTimeInterval(Double(minutes) * 60)
            entry.baby = baby
            context.insert(entry)
        }
        for n in 1...20 {
            for (slot, hour) in [1, 4, 7, 10, 13, 16, 19].enumerated() {
                switch slot {
                case 0...4: feed(at(n, hour), .breast, side: slot % 2 == 0 ? .left : .right, minutes: 15)
                case 5: feed(at(n, hour), .formula, ml: 120, minutes: 10)
                default: feed(at(n, hour), .pumped, ml: 90, minutes: 10)
                }
            }
        }
        // Before the period: they only have to exist, for the "older logs are
        // not in the report" side of the assertions.
        for n in 21...27 {
            for (slot, hour) in [1, 4, 7, 10, 13, 16].enumerated() {
                feed(at(n, hour), .breast, side: slot % 2 == 0 ? .left : .right, minutes: 15)
            }
        }

        func sleep(_ start: Date, _ type: SleepEntry.SleepType, hours: Double) {
            let entry = SleepEntry(startTime: start, type: type)
            entry.endTime = start.addingTimeInterval(hours * 3600)
            entry.baby = baby
            context.insert(entry)
        }
        for n in 1...20 {
            sleep(at(n, 0, 30), .night, hours: 6)
            sleep(at(n, 13), .nap, hours: 1.5)
        }
        // Starts before the day-20 period and ends inside it: the one entry
        // that straddles the boundary.
        sleep(at(21, 21), .night, hours: 7)

        for n in 1...20 {
            for hour in [2, 6, 10, 14, 18] {
                let entry = DiaperEntry(time: at(n, hour), type: .wet)
                entry.baby = baby
                context.insert(entry)
            }
            for hour in [8, 20] {
                let green = hour == 8 && (n == 5 || n == 12)
                let entry = DiaperEntry(time: at(n, hour), type: .dirty, color: green ? .green : .yellow)
                entry.baby = baby
                context.insert(entry)
            }
        }

        // Half inside the 15-day free window, half outside it.
        for n in stride(from: 2, through: 30, by: 2) {
            let event = CustomEvent(time: at(n, 19, 30), type: .bath)
            event.baby = baby
            context.insert(event)
        }

        func visit(day date: Date, created: Date, note: String? = nil) -> DoctorVisit {
            // Noon of the day, as `DoctorVisitActions.visitDay` stores a visit.
            let visit = DoctorVisit(date: DoctorVisitActions.visitDay(date, calendar: cal), note: note)
            visit.createdAt = created
            visit.baby = baby
            context.insert(visit)
            return visit
        }
        // `askedAt` is the visit's day, as `DoctorVisitActions` stamps it; a
        // nil visit leaves the question open.
        func question(_ text: String, created: Date, askedAt visit: DoctorVisit? = nil) {
            let q = DoctorQuestion(text: text)
            q.createdAt = created
            q.baby = baby
            context.insert(q)
            if let visit {
                q.visit = visit
                q.askedAt = visit.date
            }
        }

        let q1 = ("Is it fine that she sleeps on her tummy?", at(25, 21))
        let q2 = ("When can we start a bath every day?", at(23, 21))
        let q3 = ("How much vitamin D, and for how long?", at(12, 21))
        let q4 = ("Is the rash on her cheeks from the formula?", at(6, 21))
        let q5 = ("When are the next vaccinations?", at(2, 21))
        let v20Note = "Vitamin D: 1 drop a day.\nNext visit in a month."

        switch self {
        case .doctorMonth:
            let v20 = visit(day: day(20), created: at(20, 18), note: v20Note)
            question(q1.0, created: q1.1, askedAt: v20)
            question(q2.0, created: q2.1, askedAt: v20)
            question(q3.0, created: q3.1)
            question(q4.0, created: q4.1)
            question(q5.0, created: q5.1)
        case .doctorNoVisit:
            for q in [q1, q2, q3, q4, q5] { question(q.0, created: q.1) }
        case .doctorVisitToday:
            let v20 = visit(day: day(20), created: at(20, 18), note: v20Note)
            let v0 = visit(day: day(0), created: now)
            question(q1.0, created: q1.1, askedAt: v20)
            question(q2.0, created: q2.1, askedAt: v20)
            question(q3.0, created: q3.1, askedAt: v0)
            question(q4.0, created: q4.1, askedAt: v0)
            question(q5.0, created: q5.1)
        case .doctorTwoVisits:
            let va = visit(day: day(10), created: at(10, 12), note: "First entry.")
            let vb = visit(day: day(10), created: at(10, 20), note: "Logged again in the evening.")
            // Logged two hours ago for a visit a month back: dated earlier than
            // VA/VB, so it must not move the period start.
            let vc = visit(day: day(30), created: now.addingTimeInterval(-2 * 3600))
            question(q1.0, created: q1.1, askedAt: va)
            question(q2.0, created: q2.1, askedAt: vb)
            question(q3.0, created: q3.1, askedAt: vb)
            // Written on day 6 but asked at a day-30 visit: the late-log quirk
            // `logVisit` allows, where `askedAt` predates `createdAt`.
            question(q4.0, created: q4.1, askedAt: vc)
            question(q5.0, created: q5.1)
        default:
            break
        }
    }
}
#endif

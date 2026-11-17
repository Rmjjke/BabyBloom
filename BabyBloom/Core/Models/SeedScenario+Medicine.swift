import Foundation
import SwiftData

#if targetEnvironment(simulator)
/// The medicines fixture. Everything hangs off `now`, so a pinned `-BBNow`
/// moves the doses and the times they allow together.
///
/// Each course is laid out backwards from its latest dose in steps of exactly
/// its interval, by elapsed time. So every dose is on time and no 24 hours
/// holds more than the maximum at whatever hour the app is launched. A history
/// pinned to wall-clock hours broke its own rules after midnight.
///
/// Doses are inserted through `CustomEvent.dose(of:at:)`, the one way a dose
/// is made, so the name and dose copies on each event are the real ones.
extension SeedScenario {
    func seedMedicines(into context: ModelContext, now: Date = AppClock.now) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        let baby = Baby(name: "Mia", birthDate: cal.date(byAdding: .day, value: -120, to: today)!,
                        gender: .female, feedingType: .mixed)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        func course(_ name: String, every minutes: Int, dose: String?, max: Int? = nil,
                    latest: Date, count: Int) {
            let medicine = Medicine(name: name, intervalMinutes: minutes, doseText: dose)
            medicine.maxDosesPer24h = max
            medicine.baby = baby
            let step = TimeInterval(minutes) * 60
            medicine.createdAt = latest.addingTimeInterval(-step * Double(count))
            context.insert(medicine)
            for index in 0..<count {
                context.insert(CustomEvent.dose(of: medicine, at: latest.addingTimeInterval(-step * Double(index))))
            }
        }

        // Every six hours with a maximum of 4 in 24 hours: 13 doses over three
        // days and a bit, so several pairs sit across midnight. The latest is
        // two hours ago: the next is four hours from launch, and the count of
        // the last 24 hours reads 4 of 4.
        course("Paracetamol", every: 6 * 60, dose: "\(2.5.appDecimal(1))\u{00A0}\("unit.ml".l)", max: 4,
               latest: now.addingTimeInterval(-2 * 3600), count: 13)

        // Once a day. The latest is 26 hours ago, so the next is allowed at
        // launch.
        course("Vitamin D", every: 24 * 60, dose: "1 drop",
               latest: now.addingTimeInterval(-26 * 3600), count: 6)

        // Logged the way the app logged a medication before medicines: one
        // with a typed name, one from the quick tile with nothing.
        func at(_ daysAgo: Int, _ hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0,
                     of: cal.date(byAdding: .day, value: -daysAgo, to: today)!)!
        }
        let named = CustomEvent(time: at(4, 10), type: .medication)
        named.medicationName = "Saline drops"
        named.baby = baby
        context.insert(named)
        let bare = CustomEvent(time: at(5, 11), type: .medication)
        bare.baby = baby
        context.insert(bare)
    }
}
#endif

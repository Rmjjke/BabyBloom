import Foundation
import SwiftData

#if targetEnvironment(simulator)
/// The offer rule's fixtures: each puts one moment on or past its threshold,
/// or one short of it, relative to `AppClock.now`, so `-BBNow` moves the picture.
///
/// They also write the end of onboarding, which the rule counts from, and
/// set every `createdAt` by hand: the rule tells records written during setup
/// from records written in the app by that stamp, and `Date()` would put a
/// `-BBNow` run's whole history after the line.
///
/// A fresh install launched with `-hasCompletedOnboarding true` records the
/// cohort of installs from before offers, which holds every offer for its
/// first 14 days; a flow that wants to see a card passes `-BBOfferCohort new`.
extension SeedScenario {

    static let offerScenarios: [SeedScenario] = [
        .offerDays2, .offerDays3, .offerDays6, .offerDays7,
        .offerWeighingClean, .offerWeighingFlagged,
        .offerOldest14, .offerOldest16,
        .offerOnboarded27, .offerOnboarded28,
    ]

    func seedOffer(into context: ModelContext, now: Date = AppClock.now, defaults: UserDefaults = .standard) {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: now)
        // Every record sits at half of today's elapsed time, on whichever day:
        // never after `now`, never across midnight, whatever hour a flow runs.
        let timeOfDay = now.timeIntervalSince(today) / 2
        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: today)!.addingTimeInterval(timeOfDay)
        }

        let ended: Date
        let recordDays: [Int]
        var weighingKg: Double?
        switch self {
        case .offerDays2:   ended = calendar.date(byAdding: .day, value: -1, to: today)!; recordDays = [1, 0]
        case .offerDays3:   ended = calendar.date(byAdding: .day, value: -2, to: today)!; recordDays = [2, 1, 0]
        case .offerDays6:   ended = calendar.date(byAdding: .day, value: -5, to: today)!; recordDays = Array((0...5).reversed())
        case .offerDays7:   ended = calendar.date(byAdding: .day, value: -6, to: today)!; recordDays = Array((0...6).reversed())
        // Born eight days ago at 3.4 kg: 3.3 is a 3 % dip, 3.0 is past the
        // 10 % loss the newborn check flags.
        case .offerWeighingClean:   ended = calendar.date(byAdding: .day, value: -1, to: today)!; recordDays = [1]; weighingKg = 3.3
        case .offerWeighingFlagged: ended = calendar.date(byAdding: .day, value: -1, to: today)!; recordDays = [1]; weighingKg = 3.0
        // The free history keeps 15 days counting today: 14 days old is
        // inside it, 16 is past its edge. Two record days, below the first result.
        case .offerOldest14: ended = calendar.date(byAdding: .day, value: -20, to: today)!; recordDays = [14, 0]
        case .offerOldest16: ended = calendar.date(byAdding: .day, value: -20, to: today)!; recordDays = [16, 0]
        // The month report counts 28 calendar days from onboarding's end and
        // needs a record in the last week.
        case .offerOnboarded27: ended = daysAgo(27); recordDays = [1, 0]
        case .offerOnboarded28: ended = daysAgo(28); recordDays = [1, 0]
        default: return
        }

        let isWeighing = weighingKg != nil
        let birth = calendar.date(byAdding: .day, value: isWeighing ? -8 : -40, to: today)!
        let baby = Baby(name: "Mia", birthDate: birth, gender: .female, feedingType: .breast)
        baby.birthWeightKg = 3.4
        // Onboarding's last step creates the baby just before it ends.
        baby.createdAt = ended.addingTimeInterval(-30)
        context.insert(baby)
        OnboardingEnd.record(now: ended, defaults: defaults)

        // The birth weight onboarding writes: before the line, never a weighing
        // added in the app.
        let birthWeight = GrowthEntry(date: birth, weightKg: 3.4, heightCm: nil, headCircumferenceCm: nil)
        birthWeight.createdAt = baby.createdAt
        birthWeight.baby = baby
        context.insert(birthWeight)

        for day in recordDays {
            let time = max(daysAgo(day), ended)
            let feed = FeedingEntry(startTime: time, type: .breast, side: .left, volumeML: nil)
            feed.endTime = min(time.addingTimeInterval(15 * 60), now)
            feed.createdAt = time
            feed.baby = baby
            context.insert(feed)
            let nappy = DiaperEntry(time: time, type: .wet)
            nappy.createdAt = time
            nappy.baby = baby
            context.insert(nappy)
        }

        if let weighingKg {
            let weighing = GrowthEntry(date: daysAgo(0), weightKg: weighingKg, heightCm: nil, headCircumferenceCm: nil)
            weighing.createdAt = daysAgo(0)
            weighing.baby = baby
            context.insert(weighing)
        }
    }
}
#endif

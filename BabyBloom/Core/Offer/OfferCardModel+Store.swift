import Foundation

extension OfferCardModel.Input {
    init(baby: Baby, feeds: [FeedingEntry], sleeps: [SleepEntry], diapers: [DiaperEntry],
         growth: [GrowthEntry], events: [CustomEvent], onboardingEndedAt: Date, now: Date) {
        self.init(
            feeds: feeds.map(\.startTime),
            sleeps: sleeps.map { (start: $0.startTime, end: $0.endTime) },
            diapers: diapers.map(\.time),
            events: events.map(\.time),
            growthDates: growth.map(\.date),
            weighings: growth.weightMeasurements(asOf: now),
            babyName: baby.name,
            isMale: baby.gender == .male,
            correctedBirthDate: baby.correctedBirthDate,
            onboardingEndedAt: onboardingEndedAt,
            now: now)
    }
}

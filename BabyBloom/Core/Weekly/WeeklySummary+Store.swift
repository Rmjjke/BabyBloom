import Foundation
import SwiftData

/// The bridge from the store to the pure `WeeklySummary.Input`, shared by the
/// Dashboard (its @Query arrays) and the notification (a fetch).
extension WeeklySummary.Input {
    init(baby: Baby, feeds: [FeedingEntry], sleeps: [SleepEntry], diapers: [DiaperEntry],
         growth: [GrowthEntry], events: [CustomEvent]) {
        self.init(
            feeds: feeds.map(\.startTime),
            sleeps: sleeps.compactMap { entry in entry.endTime.map { (start: entry.startTime, end: $0) } },
            otherEntries: diapers.map(\.time) + growth.map(\.date) + events.map(\.time),
            measurements: growth.weightMeasurements(asOf: AppClock.now),
            birthDate: baby.birthDate,
            correctedBirthDate: baby.correctedBirthDate,
            birthWeightKg: baby.birthWeightKg,
            isMale: baby.gender == .male)
    }

    /// For the notification, which has no view and so no @Query. Entries from
    /// three weeks back are enough for last week and the one before; growth is
    /// read whole, since a weighing pair can reach further back.
    @MainActor
    static func load(in context: ModelContext, now: Date) -> WeeklySummary.Input? {
        var babyQuery = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        babyQuery.fetchLimit = 1
        guard let baby = (try? context.fetch(babyQuery))?.first else { return nil }
        let since = WeeklySummary.week(containing: now).shifted(byWeeks: -2).start
        let feeds = (try? context.fetch(FetchDescriptor<FeedingEntry>(
            predicate: #Predicate { $0.startTime >= since }))) ?? []
        let sleeps = (try? context.fetch(FetchDescriptor<SleepEntry>(
            predicate: #Predicate { $0.startTime >= since }))) ?? []
        let diapers = (try? context.fetch(FetchDescriptor<DiaperEntry>(
            predicate: #Predicate { $0.time >= since }))) ?? []
        let events = (try? context.fetch(FetchDescriptor<CustomEvent>(
            predicate: #Predicate { $0.time >= since }))) ?? []
        let growth = (try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? []
        return WeeklySummary.Input(baby: baby, feeds: feeds, sleeps: sleeps, diapers: diapers,
                                   growth: growth, events: events)
    }
}

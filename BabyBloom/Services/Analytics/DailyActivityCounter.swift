import Foundation
import SwiftData

/// Reads one local day's entry counts for `daily_activity`, straight from the
/// store: counted, never fetched. The raw counts go no further than the
/// facade, which reduces them to presence and one bucketed total.
enum DailyActivityCounter {

    /// nil when there is no baby: a day before onboarding finished has nothing
    /// to report, and zeros would read as an inactive parent.
    @MainActor
    static func counts(in context: ModelContext, over day: DateInterval) -> AnalyticsEvent.DayCounts? {
        guard ((try? context.fetchCount(FetchDescriptor<Baby>())) ?? 0) > 0 else { return nil }
        let start = day.start, end = day.end
        // Each kind by the date it is filed under in its own list — a feed or
        // a nap by when it STARTED, so one spanning midnight counts once.
        let feeding = count(FetchDescriptor<FeedingEntry>(predicate: #Predicate { $0.startTime >= start && $0.startTime < end }), in: context)
        let sleep = count(FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.startTime >= start && $0.startTime < end }), in: context)
        let diaper = count(FetchDescriptor<DiaperEntry>(predicate: #Predicate { $0.time >= start && $0.time < end }), in: context)
        let growth = count(FetchDescriptor<GrowthEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }), in: context)
        let event = count(FetchDescriptor<CustomEvent>(predicate: #Predicate { $0.time >= start && $0.time < end }), in: context)
        return AnalyticsEvent.DayCounts(feeding: feeding, sleep: sleep, diaper: diaper,
                                        growth: growth, event: event)
    }

    private static func count<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> Int {
        (try? context.fetchCount(descriptor)) ?? 0
    }
}

import Foundation
import SwiftData

/// The one place a feeding or sleep timer starts, stops, changes side or is
/// deleted. The screens and the Live Activity's Stop intent come through here,
/// and so will the widget's start button (planned: widget-interactive, D16), so
/// each change gets the same side effects wherever it is made: save, widget
/// reload, the reminder hook (a side change has none), and a Live Activity
/// reconcile.
///
/// The review prompt is NOT here: it is a view concern, and a stop made from the
/// Lock Screen must never ask for a review (R2.2). Views call it themselves
/// after a `stop` that returned true.
@MainActor
enum TimerActions {

    /// Runs after every mutation. A seam for the unit tests, which swap it out
    /// so an in-memory store never reconciles real activities on the simulator.
    static var afterChange: @MainActor () -> Void = { LiveActivitySync.shared.reconcile() }

    // MARK: Start

    @discardableResult
    static func startBreastfeed(side: FeedingEntry.BreastSide = .left,
                                in context: ModelContext) -> FeedingEntry {
        // Fetched BEFORE the insert: the reminder's interval average is built
        // from past feeds, as the screen's pre-insert query always passed it.
        let recent = recentFeedingTimes(in: context)
        let baby = firstBaby(in: context)
        let entry = FeedingEntry(startTime: Date(), type: .breast, side: side, volumeML: nil)
        entry.baby = baby
        context.insert(entry)
        try? context.save()
        WidgetRefresh.entriesChanged()
        NotificationManager.shared.onFeedingSaved(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            isActiveBF: true,
            recentFeedingTimes: recent
        )
        afterChange()
        return entry
    }

    @discardableResult
    static func startSleep(_ type: SleepEntry.SleepType, in context: ModelContext) -> SleepEntry {
        let baby = firstBaby(in: context)
        let entry = SleepEntry(startTime: Date(), type: type)
        entry.baby = baby
        context.insert(entry)
        try? context.save()
        WidgetRefresh.entriesChanged()
        NotificationManager.shared.onSleepStarted(
            ageMonths: baby?.ageInMonths ?? 0,
            babyName: baby?.name ?? "baby.default_name".l,
            isNight: type == .night
        )
        afterChange()
        return entry
    }

    // MARK: Stop

    /// Stops the running entry with this id. Returns false and writes nothing
    /// when it is gone or already stopped — a second tap on the Lock Screen, or
    /// a stop that raced an in-app one, must not move the end time (R2.3).
    @discardableResult
    static func stop(entryID: UUID, kind: TimerKind, at date: Date = Date(),
                     in context: ModelContext) -> Bool {
        let ageMonths = firstBaby(in: context)?.ageInMonths ?? 0
        switch kind {
        case .feeding:
            guard let entry = fetchOne(FeedingEntry.self, id: entryID, in: context),
                  entry.endTime == nil else { return false }
            entry.endTime = date
            try? context.save()
            WidgetRefresh.entriesChanged()
            NotificationManager.shared.onFeedingTimerStopped(ageMonths: ageMonths)
        case .sleep:
            guard let entry = fetchOne(SleepEntry.self, id: entryID, in: context),
                  entry.endTime == nil else { return false }
            entry.endTime = date
            try? context.save()
            WidgetRefresh.entriesChanged()
            NotificationManager.shared.onSleepEnded(ageMonths: ageMonths, endedAt: date)
        }
        afterChange()
        return true
    }

    // MARK: Edit

    static func setSide(_ side: FeedingEntry.BreastSide, of entry: FeedingEntry,
                        in context: ModelContext) {
        entry.side = side
        // Saved now rather than left to autosave: the Lock Screen title reads
        // the store, and should change with the tap.
        try? context.save()
        WidgetRefresh.entriesChanged()
        afterChange()
    }

    // MARK: Delete

    static func delete(feedings: [FeedingEntry], in context: ModelContext) {
        feedings.forEach { context.delete($0) }
        try? context.save()
        WidgetRefresh.entriesChanged()
        let remaining = (try? context.fetch(feedsNewestFirst)) ?? []
        NotificationManager.shared.onFeedingDeleted(
            ageMonths: firstBaby(in: context)?.ageInMonths ?? 0,
            remainingActive: remaining.contains { $0.isActive },
            remainingFeedingTimes: Array(remaining.prefix(7).map(\.startTime))
        )
        afterChange()
    }

    static func delete(sleeps: [SleepEntry], in context: ModelContext) {
        sleeps.forEach { context.delete($0) }
        try? context.save()
        WidgetRefresh.entriesChanged()
        let remaining = (try? context.fetch(
            FetchDescriptor<SleepEntry>(sortBy: [SortDescriptor(\.startTime, order: .reverse)]))) ?? []
        NotificationManager.shared.onSleepDeleted(
            ageMonths: firstBaby(in: context)?.ageInMonths ?? 0,
            remainingActive: remaining.contains { $0.isActive },
            lastRemainingSleepEnd: remaining.compactMap(\.endTime).max()
        )
        afterChange()
    }

    // MARK: Store reads

    /// The screens use `babies.first` sorted by creation; so does this.
    private static func firstBaby(in context: ModelContext) -> Baby? {
        var descriptor = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static var feedsNewestFirst: FetchDescriptor<FeedingEntry> {
        FetchDescriptor<FeedingEntry>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
    }

    private static func recentFeedingTimes(in context: ModelContext) -> [Date] {
        var descriptor = feedsNewestFirst
        descriptor.fetchLimit = 7
        return ((try? context.fetch(descriptor)) ?? []).map(\.startTime)
    }

    private static func fetchOne(_: FeedingEntry.Type, id: UUID, in context: ModelContext) -> FeedingEntry? {
        var descriptor = FetchDescriptor<FeedingEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private static func fetchOne(_: SleepEntry.Type, id: UUID, in context: ModelContext) -> SleepEntry? {
        var descriptor = FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

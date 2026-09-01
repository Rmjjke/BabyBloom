import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Shared SwiftData Store (App Group)
/// Lazily-opened, read-only container over the shared App Group store.
/// Created once per process to avoid re-opening the same store on repeated
/// timeline reloads. Widget extensions must NOT enable CloudKit sync, so the
/// container is opened with `cloudKitDatabase: .none`; the app target owns
/// sync. The models were made CloudKit-compatible in A1, so `.none` reads the
/// same store without any schema mismatch.
enum WidgetDataStore {
    static let appGroupIdentifier = "group.com.nenita.app"

    private static let schema = Schema([
        Baby.self, FeedingEntry.self, SleepEntry.self,
        DiaperEntry.self, GrowthEntry.self, CustomEvent.self
    ])

    // ModelContainer is Sendable, so this can be a plain (non-isolated) static.
    static let shared: ModelContainer? = {
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }()
}

// MARK: - Widget Provider
struct BabyBloomProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyBloomEntry {
        Self.placeholderSample()
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyBloomEntry) -> Void) {
        LocalizationManager.shared.refreshFromStore()
        completion(Self.fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyBloomEntry>) -> Void) {
        // Before anything is read: this process outlives a language change.
        LocalizationManager.shared.refreshFromStore()
        let entry = Self.fetchEntry()
        // One entry per minute for the whole refresh window, plus one exactly
        // at the due moment. Every duration the views show is a static string
        // computed from the entry's date (owner ruling: minutes, never
        // seconds), so the entries ARE the clock — WidgetKit swaps them in on
        // schedule and nothing is ever staler than a minute. Live
        // `Text(_:style:)` was the previous mechanism and could not drop its
        // seconds component.
        let refresh = entry.date.addingTimeInterval(15 * 60)
        var dates = stride(from: TimeInterval(0), to: 15 * 60, by: 60)
            .map { entry.date.addingTimeInterval($0) }
        if let due = entry.nextFeedingTime, due > entry.date, due < refresh {
            dates.append(due)
        }
        // Set first: a due moment on the minute grid would otherwise produce
        // two entries with an equal date, and equal-date behaviour is
        // WidgetKit's to define, not ours to lean on.
        let entries = Array(Set(dates)).sorted().map { entry.at($0) }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    // MARK: Data

    /// The redacted loading placeholder WidgetKit shows while a real timeline
    /// is being fetched — the only caller that WANTS invented data. (The
    /// gallery is not this: WidgetKit fills that through `getSnapshot(in:)`
    /// with `context.isPreview`, which returns real data here.) Deliberately
    /// internally consistent: a logged feeding at one month old always has a
    /// predicted next feed, so this carries one 45 minutes out and shows the
    /// countdown that is the whole point of the widget, rather than the old
    /// "time since" framing.
    static func placeholderSample() -> BabyBloomEntry {
        BabyBloomEntry(
            date: Date(),
            babyName: "baby.default_name".l,
            lastFeedingTime: Date().addingTimeInterval(-7200),
            sleepStartTime: Date().addingTimeInterval(-3 * 3600),
            lastSleepDuration: String(format: "duration.h_min".l, 2, 15),
            todayFeedingCount: 6,
            isAsleep: false,
            nextFeedingTime: Date().addingTimeInterval(45 * 60)
        )
    }

    /// What `fetchEntry()` falls back to when there is nothing real to show:
    /// no App Group store, or a store with no `Baby` yet. Kept separate from
    /// `placeholderSample()` on purpose — that one is invented data for the
    /// redacted loading state; this is what a real person who has not finished
    /// onboarding actually sees, and showing them a fabricated "6 today" and
    /// a 2h15m nap for a baby that doesn't exist would be a defect, not a
    /// placeholder. Do NOT collapse these back into one function.
    static func emptyEntry() -> BabyBloomEntry {
        BabyBloomEntry(
            date: Date(),
            babyName: "baby.default_name".l,
            lastFeedingTime: nil,
            sleepStartTime: nil,
            lastSleepDuration: nil,
            todayFeedingCount: 0,
            isAsleep: false,
            nextFeedingTime: nil
        )
    }

    /// Reads live data from the shared App Group container. Any failure
    /// (missing App Group, unopenable store, empty database) falls back to
    /// `emptyEntry()` so the widget never crashes and never invents data.
    static func fetchEntry() -> BabyBloomEntry {
        guard let container = WidgetDataStore.shared else {
            return emptyEntry()
        }
        // A fresh context (not `mainContext`) so this works from any thread the
        // WidgetKit timeline machinery calls us on, without an actor hop.
        let ctx = ModelContext(container)

        // Baby profile (first created).
        var babyDescriptor = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        babyDescriptor.fetchLimit = 1
        guard let baby = (try? ctx.fetch(babyDescriptor))?.first else {
            // No baby set up yet — nothing meaningful to show.
            return emptyEntry()
        }

        // Recent feedings (cap the fetch; only need today's count + the latest).
        var feedingDescriptor = FetchDescriptor<FeedingEntry>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        feedingDescriptor.fetchLimit = 50
        let feedings = (try? ctx.fetch(feedingDescriptor)) ?? []
        let todayCount = feedings.filter { Calendar.current.isDateInToday($0.startTime) }.count

        // The same arithmetic the feeding reminder is scheduled on, so the
        // widget and the push cannot contradict each other.
        let recent = Array(feedings.prefix(7).map(\.startTime))
        let nextFeed = FeedingRhythm.nextFeed(afterLastFeedingAt: feedings.first?.startTime,
                                              ageMonths: baby.ageInMonths,
                                              recentFeedings: recent)

        // Latest sleep entry.
        var sleepDescriptor = FetchDescriptor<SleepEntry>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        sleepDescriptor.fetchLimit = 1
        let lastSleep = (try? ctx.fetch(sleepDescriptor))?.first

        return BabyBloomEntry(
            date: Date(),
            babyName: baby.name.isEmpty ? "baby.default_name".l : baby.name,
            lastFeedingTime: feedings.first?.startTime,
            sleepStartTime: lastSleep?.startTime,
            lastSleepDuration: lastSleep?.durationFormatted,
            todayFeedingCount: todayCount,
            isAsleep: lastSleep?.isActive ?? false,
            nextFeedingTime: nextFeed
        )
    }
}

// MARK: - Widget Configuration
struct BabyBloomWidget: Widget {
    let kind: String = "BabyBloomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyBloomProvider()) { entry in
            BabyBloomSmallWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("brand.name".l)
        .description("widget.description_small".l)
        .supportedFamilies([.systemSmall])
    }
}

struct BabyBloomMediumWidget: Widget {
    let kind: String = "BabyBloomMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyBloomProvider()) { entry in
            BabyBloomMediumWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName(String(format: "widget.name_medium".l, "brand.name".l))
        .description("widget.description_medium".l)
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Widget Bundle
@main
struct BabyBloomWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyBloomWidget()
        BabyBloomMediumWidget()
    }
}

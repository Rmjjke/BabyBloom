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
        Self.placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyBloomEntry) -> Void) {
        LocalizationManager.shared.refreshFromStore()
        completion(Self.fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyBloomEntry>) -> Void) {
        // Before anything is read: this process outlives a language change.
        LocalizationManager.shared.refreshFromStore()
        let entry = Self.fetchEntry()
        // Roughly every 15 minutes to keep the underlying data fresh. The
        // countdown itself does NOT depend on this — `Text(_:style:)` is
        // re-rendered by the system every minute — but the wording has to
        // change the moment the feed falls due, so a second entry is placed
        // exactly there rather than polling for it.
        let refresh = Date().addingTimeInterval(15 * 60)
        var entries = [entry]
        if let due = entry.nextFeedingTime, due > entry.date, due < refresh {
            entries.append(BabyBloomEntry(date: due,
                                          babyName: entry.babyName,
                                          lastFeedingTime: entry.lastFeedingTime,
                                          lastSleepDuration: entry.lastSleepDuration,
                                          todayFeedingCount: entry.todayFeedingCount,
                                          isAsleep: entry.isAsleep,
                                          nextFeedingTime: entry.nextFeedingTime,
                                          ageMonths: entry.ageMonths))
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    // MARK: Data

    /// Static placeholder used for the widget gallery and as a graceful
    /// fallback whenever the shared store is unavailable or empty.
    static func placeholderEntry() -> BabyBloomEntry {
        BabyBloomEntry(
            date: Date(),
            babyName: "baby.default_name".l,
            lastFeedingTime: Date().addingTimeInterval(-7200),
            lastSleepDuration: String(format: "duration.h_min".l, 2, 15),
            todayFeedingCount: 6,
            isAsleep: false,
            nextFeedingTime: nil,
            ageMonths: 1
        )
    }

    /// Reads live data from the shared App Group container. Any failure
    /// (missing App Group, unopenable store, empty database) falls back to the
    /// placeholder so the widget never crashes.
    static func fetchEntry() -> BabyBloomEntry {
        guard let container = WidgetDataStore.shared else {
            return placeholderEntry()
        }
        // A fresh context (not `mainContext`) so this works from any thread the
        // WidgetKit timeline machinery calls us on, without an actor hop.
        let ctx = ModelContext(container)

        // Baby profile (first created).
        var babyDescriptor = FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])
        babyDescriptor.fetchLimit = 1
        guard let baby = (try? ctx.fetch(babyDescriptor))?.first else {
            // No baby set up yet — nothing meaningful to show.
            return placeholderEntry()
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
            lastSleepDuration: lastSleep?.durationFormatted,
            todayFeedingCount: todayCount,
            isAsleep: lastSleep?.isActive ?? false,
            nextFeedingTime: nextFeed,
            ageMonths: baby.ageInMonths
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

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
        // Reload roughly every 15 minutes to keep "time ago" values fresh.
        let nextUpdate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
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
            isAsleep: false
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
            isAsleep: lastSleep?.isActive ?? false
        )
    }
}

// MARK: - Widget Configuration
struct BabyBloomWidget: Widget {
    let kind: String = "BabyBloomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyBloomProvider()) { entry in
            if #available(iOS 17.0, *) {
                BabyBloomSmallWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                BabyBloomSmallWidgetView(entry: entry)
            }
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
            if #available(iOS 17.0, *) {
                BabyBloomMediumWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                BabyBloomMediumWidgetView(entry: entry)
            }
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

// MARK: - Color Extension (duplicated for widget target)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

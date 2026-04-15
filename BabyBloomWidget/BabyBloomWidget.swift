import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Timeline Entry
struct BabyBloomEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let lastFeedingTime: Date?
    let lastSleepDuration: String?
    let todayFeedingCount: Int
    let isAsleep: Bool
}

// MARK: - Widget Provider
struct BabyBloomProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyBloomEntry {
        BabyBloomEntry(
            date: Date(),
            babyName: "Малыш",
            lastFeedingTime: Date().addingTimeInterval(-7200),
            lastSleepDuration: "2 ч 15 мин",
            todayFeedingCount: 6,
            isAsleep: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyBloomEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyBloomEntry>) -> Void) {
        // Reload every 15 minutes
        let entry = BabyBloomEntry(
            date: Date(),
            babyName: "Малыш",
            lastFeedingTime: nil,
            lastSleepDuration: nil,
            todayFeedingCount: 0,
            isAsleep: false
        )
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View
struct BabyBloomSmallWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🌸")
                    .font(.system(size: 20))
                Text("BabyBloom")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            if let lastFeeding = entry.lastFeedingTime {
                let mins = Int(Date().timeIntervalSince(lastFeeding) / 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Кормление")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(mins < 60 ? "\(mins) мин назад" : "\(mins / 60) ч назад")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                Text("Сегодня: \(entry.todayFeedingCount)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#6B5EA8"), Color(hex: "#9B8EC8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Medium Widget View
struct BabyBloomMediumWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        HStack(spacing: 0) {
            // Left: Baby info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🌸")
                    Text(entry.babyName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if entry.isAsleep {
                    Label("Спит сейчас", systemImage: "moon.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Label("Кормлений: \(entry.todayFeedingCount)", systemImage: "heart.fill")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .leading)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1)

            // Right: Quick stats
            VStack(spacing: 8) {
                widgetStatRow(icon: "heart.fill", title: "Кормление",
                              value: entry.lastFeedingTime.map { timeAgo($0) } ?? "—")
                widgetStatRow(icon: "moon.fill", title: "Сон",
                              value: entry.lastSleepDuration ?? "—")
            }
            .padding(14)
            .frame(maxHeight: .infinity)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#6B5EA8"), Color(hex: "#B08ED8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func widgetStatRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 60 { return "\(mins) мин" }
        return "\(mins / 60) ч \(mins % 60) мин"
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
        .configurationDisplayName("BabyBloom")
        .description("Быстрый обзор состояния малыша")
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
        .configurationDisplayName("BabyBloom — Подробно")
        .description("Обзор кормлений и сна малыша")
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

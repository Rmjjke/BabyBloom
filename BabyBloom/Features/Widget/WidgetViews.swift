import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Entry
struct BabyBloomEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let lastFeedingTime: Date?
    let lastSleepDuration: String?
    let todayFeedingCount: Int
    let isAsleep: Bool
}

/// The brand gradient, as the widget's CONTAINER background rather than a
/// background on the content.
///
/// It used to be `.background(...)` on the inner stack while the container
/// kept `.fill.tertiary`. The content sits inside the system's margins, so the
/// gradient rendered as a square-cornered rectangle with the container's own
/// near-black fill showing around it as a frame — the whole reason this
/// redesign started. Nothing in-process catches that: a view rendered outside
/// a widget container has neither margins nor a container background.
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color("BBGradientStart"), Color("BBGradientEnd")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Small Widget View
struct BabyBloomSmallWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // SF Symbol, not the 🌸 this used to be: Apple Color Emoji does
                // not resolve inside the widget extension on a simulator and the
                // glyph renders as a tofu box — which then reaches anything shot
                // from a simulator, App Store captures included. `leaf.fill` is
                // also what `SplashView` already uses for the brand mark.
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                Text("brand.name".l)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            if let lastFeeding = entry.lastFeedingTime {
                let mins = Int(Date().timeIntervalSince(lastFeeding) / 60)
                VStack(alignment: .leading, spacing: 2) {
                    Text("tab.feeding".l)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(mins < 60
                         ? String(format: "stats.min_ago".l, mins)
                         : String(format: "stats.h_ago".l, mins / 60))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        // "16 мин назад" does not fit the small widget at 18pt
                        // and was truncating to "16 мин наз…". English fits, so
                        // this only ever shows up in the other two languages.
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                Text(String(format: "widget.today_count".l, entry.todayFeedingCount))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                    Text(entry.babyName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if entry.isAsleep {
                    Label("status.sleeping_now".l, systemImage: "moon.fill")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Label(String(format: "widget.feedings_count".l, entry.todayFeedingCount),
                      systemImage: "heart.fill")
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
                widgetStatRow(icon: "heart.fill", title: "tab.feeding".l,
                              value: entry.lastFeedingTime.map { timeAgo($0) } ?? "—")
                widgetStatRow(icon: "moon.fill", title: "tab.sleep".l,
                              value: entry.lastSleepDuration ?? "—")
            }
            .padding(14)
            .frame(maxHeight: .infinity)
        }
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

    /// Same shape as SleepEntry.durationFormatted, on an elapsed interval
    /// rather than a stored duration.
    private func timeAgo(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 60 { return String(format: "duration.min_only".l, mins) }
        return String(format: "duration.h_min".l, mins / 60, mins % 60)
    }
}

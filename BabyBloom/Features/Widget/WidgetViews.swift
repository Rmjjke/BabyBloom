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
    /// When the next feed is due. `nil` for two different reasons, and the
    /// views render a different thing for each: nothing logged yet (the
    /// invitation), and 12+ months, where the app deliberately does not
    /// predict (elapsed time instead).
    let nextFeedingTime: Date?
    let ageMonths: Int

    var hasLoggedAFeeding: Bool { lastFeedingTime != nil }
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

/// Wording shared by both sizes, so the two cannot describe the same state
/// differently.
enum WidgetCopy {
    static func headline(for entry: BabyBloomEntry) -> String {
        guard entry.nextFeedingTime != nil else { return "widget.last_feed".l }
        return "widget.feeding_in".l
    }

    /// True once the due moment has passed. The timeline places an entry
    /// exactly at that moment, so this flips without polling.
    static func isDue(_ entry: BabyBloomEntry) -> Bool {
        guard let next = entry.nextFeedingTime else { return false }
        return next <= entry.date
    }

    /// The countdown is rendered from a DATE, never a formatted string: the
    /// system re-renders `Text(_:style:)` every minute, so it stays right
    /// between the 15-minute timeline reloads.
    @ViewBuilder
    static func hero(for entry: BabyBloomEntry) -> some View {
        if let next = entry.nextFeedingTime, next > entry.date {
            Text(next, style: .relative)
        } else if entry.nextFeedingTime != nil {
            Text("widget.time_to_feed".l)
        } else if let last = entry.lastFeedingTime {
            // 12+ months: the app does not predict here, so neither do we.
            Text(last, style: .relative)
        } else {
            Text("—")
        }
    }
}

// MARK: - Small Widget View
struct BabyBloomSmallWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.hasLoggedAFeeding {
                Text(WidgetCopy.headline(for: entry))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                WidgetCopy.hero(for: entry)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetCopy.isDue(entry) ? Color("BBAccent") : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Label(String(format: "widget.today_short".l, entry.todayFeedingCount),
                          systemImage: "heart.fill")
                    if entry.isAsleep {
                        Image(systemName: "moon.fill")
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            } else {
                // The first day is not an error state. The name is what tells
                // the parent this widget is theirs and working.
                Text(entry.babyName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("widget.log_first_feeding".l)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium Widget View
struct BabyBloomMediumWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        Group {
            if entry.hasLoggedAFeeding {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WidgetCopy.headline(for: entry))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        WidgetCopy.hero(for: entry)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetCopy.isDue(entry) ? Color("BBAccent") : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text(entry.babyName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 14) {
                        statRow(icon: "heart.fill", title: "widget.last_feed".l,
                                value: entry.lastFeedingTime.map { relative($0) } ?? "—")
                        statRow(icon: "moon.fill",
                                title: entry.isAsleep ? "widget.sleeping".l : "tab.sleep".l,
                                value: entry.lastSleepDuration ?? "—")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // No split at all here: an invitation reads as one sentence,
                // and a half-empty two-column grid reads as a fault.
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.babyName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("widget.log_first_feeding".l)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func statRow(icon: String, title: String, value: String) -> some View {
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
    private func relative(_ date: Date) -> String {
        let mins = Int(Date().timeIntervalSince(date) / 60)
        if mins < 60 { return String(format: "duration.min_only".l, mins) }
        return String(format: "duration.h_min".l, mins / 60, mins % 60)
    }
}

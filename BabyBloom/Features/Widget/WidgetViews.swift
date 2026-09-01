import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Entry
struct BabyBloomEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let lastFeedingTime: Date?
    /// Start of the most recent sleep. Carried as a DATE so a running sleep
    /// can tick alongside the hero instead of freezing at fetch time.
    let sleepStartTime: Date?
    /// Only honest once the sleep has ended and its length has stopped
    /// moving; a running sleep is rendered from `sleepStartTime` instead.
    let lastSleepDuration: String?
    let todayFeedingCount: Int
    let isAsleep: Bool
    /// When the next feed is due. `nil` for two different reasons, and the
    /// views render a different thing for each: nothing logged yet (the
    /// invitation), and 12+ months, where the app deliberately does not
    /// predict (elapsed time instead).
    let nextFeedingTime: Date?

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
    /// The locale every `Text(_:style:)` in the widget formats through.
    ///
    /// SwiftUI takes the format locale from the environment, and nothing in a
    /// widget process sets it — so it fell back to the device's, and a Russian
    /// widget read "Кормление через / 1 hr, 11 min". The app's language is a
    /// JSON table rather than a bundle language, so system-formatted output
    /// has to be pointed at it explicitly; `Date+AppLocale` and `Double+AppRate`
    /// already resolve the same way through this same property.
    static var formattingLocale: Locale { LocalizationManager.shared.language.locale }

    /// `nil` in the due state on purpose: the hero there is already a whole
    /// sentence ("Time to feed"), and a "Feeding in" label above it read as a
    /// broken one.
    static func headline(for entry: BabyBloomEntry) -> String? {
        guard let next = entry.nextFeedingTime else { return "widget.last_feed".l }
        return next > entry.date ? "widget.feeding_in".l : nil
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
    ///
    /// No fallback branch for "nothing logged": both call sites gate on
    /// `hasLoggedAFeeding` and render the invitation instead.
    @ViewBuilder
    static func hero(for entry: BabyBloomEntry) -> some View {
        if let next = entry.nextFeedingTime {
            if next > entry.date {
                Text(next, style: .relative)
            } else {
                Text("widget.time_to_feed".l)
            }
        } else if let last = entry.lastFeedingTime {
            // 12+ months: the app does not predict here, so neither do we.
            Text(last, style: .relative)
        }
    }
}

// MARK: - Small Widget View
struct BabyBloomSmallWidgetView: View {
    let entry: BabyBloomEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.hasLoggedAFeeding {
                if let headline = WidgetCopy.headline(for: entry) {
                    Text(headline)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                // White in every state, the due one included: BBAccent over
                // BBGradientEnd measures 1.44:1, and the hero can scale down
                // far enough that the 4.5:1 threshold applies. The changed
                // wording carries the state instead — the same word-not-colour
                // rule DECISIONS.md sets for FeedingAdequacy.
                WidgetCopy.hero(for: entry)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
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
        .environment(\.locale, WidgetCopy.formattingLocale)
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
                        if let headline = WidgetCopy.headline(for: entry) {
                            Text(headline)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        // See the small widget: the due state is carried by
                        // the wording, not by a tint that fails contrast.
                        WidgetCopy.hero(for: entry)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if WidgetCopy.isDue(entry), let due = entry.nextFeedingTime {
                            overdueLine(due)
                        }
                        Spacer(minLength: 0)
                        Text(entry.babyName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 14) {
                        // At 12+ months the hero IS the elapsed feed time, so
                        // this row would print the same fact twice in two
                        // different formats. Sleep is the column's content there.
                        if entry.nextFeedingTime != nil, let last = entry.lastFeedingTime {
                            statRow(icon: "heart.fill", title: "widget.last_feed".l) {
                                Text(last, style: .relative)
                            }
                        }
                        statRow(icon: "moon.fill",
                                title: entry.isAsleep ? "widget.sleeping".l : "tab.sleep".l) {
                            sleepValue
                        }
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
        .environment(\.locale, WidgetCopy.formattingLocale)
    }

    /// The spec's "same, plus how long overdue". Rendered off the due date so
    /// it keeps counting up between timeline reloads like the hero does.
    private func overdueLine(_ due: Date) -> some View {
        HStack(spacing: 4) {
            Text("widget.overdue_by".l)
            Text(due, style: .relative)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    /// A running sleep has to tick; a finished one has a fixed length and the
    /// string baked at fetch time is still true.
    @ViewBuilder
    private var sleepValue: some View {
        if entry.isAsleep, let started = entry.sleepStartTime {
            Text(started, style: .relative)
        } else {
            Text(entry.lastSleepDuration ?? "—")
        }
    }

    private func statRow<Value: View>(icon: String, title: String,
                                      @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                value()
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

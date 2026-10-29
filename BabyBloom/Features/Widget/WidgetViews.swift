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
    /// Start of a feeding timer that is running now (any kind). It turns the
    /// start button into a link with the elapsed minutes.
    var runningFeedStart: Date? = nil
    /// Its Live Activity title, for the same glyph there and here (a bottle
    /// shows a drop, a breastfeed a heart).
    var runningFeedTitle: TimerTitle? = nil
    /// False until onboarding has created a Baby. The capsule then only opens
    /// the app: a feed started before onboarding would be found hours later
    /// as a timer nobody started.
    var hasBaby = true

    var hasLoggedAFeeding: Bool { lastFeedingTime != nil }

    /// The same snapshot at a different minute — how the provider turns one
    /// fetch into a per-minute timeline without re-reading the store.
    /// Adding a field to this struct? It must be copied here too, or every
    /// entry after the first silently freezes it at the fetch-time value.
    func at(_ date: Date) -> BabyBloomEntry {
        BabyBloomEntry(date: date,
                       babyName: babyName,
                       lastFeedingTime: lastFeedingTime,
                       sleepStartTime: sleepStartTime,
                       lastSleepDuration: lastSleepDuration,
                       todayFeedingCount: todayFeedingCount,
                       isAsleep: isAsleep,
                       nextFeedingTime: nextFeedingTime,
                       runningFeedStart: runningFeedStart,
                       runningFeedTitle: runningFeedTitle,
                       hasBaby: hasBaby)
    }
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
    /// The locale any future `Text(_:style:)` in the widget would format
    /// through. Kept pinned on both views even though the current widget
    /// renders no live text: a Russian widget once read "1 hr, 11 min"
    /// because nothing set this, and the pin is what stops a reintroduced
    /// `Text(style:)` from regressing silently (the render-dump guard test
    /// leans on it too).
    static var formattingLocale: Locale { LocalizationManager.shared.language.locale }

    /// A duration as the widget speaks it: whole minutes through the app's
    /// JSON strings, never seconds. Owner ruling on build 5 — "2 мин 0 с"
    /// implies a precision no glanceable widget should claim. `Text(_:style:)`
    /// cannot do this (its units are not configurable), which is why the
    /// timeline carries one entry per minute instead and every duration is
    /// computed statically from the ENTRY's date.
    ///
    /// Countdowns round UP so the widget never promises "0 мин" while time
    /// remains; elapsed values round down, as clocks do.
    static func minutesText(_ interval: TimeInterval, countdown: Bool = false) -> String {
        let total = max(0, countdown ? Int(ceil(interval / 60)) : Int(interval / 60))
        return total >= 60
            ? String(format: "duration.h_min".l, total / 60, total % 60)
            : String(format: "duration.min_only".l, total)
    }

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

    /// Every duration is computed from the ENTRY's date — the honest clock:
    /// WidgetKit shows each timeline entry at its own minute, so a string
    /// derived from `entry.date` is minute-accurate by construction, where
    /// `Date()` would freeze at whatever moment the system chose to render.
    ///
    /// No fallback branch for "nothing logged": both call sites gate on
    /// `hasLoggedAFeeding` and render the invitation instead.
    @ViewBuilder
    static func hero(for entry: BabyBloomEntry) -> some View {
        if let next = entry.nextFeedingTime {
            if next > entry.date {
                Text(minutesText(next.timeIntervalSince(entry.date), countdown: true))
            } else {
                Text("widget.time_to_feed".l)
            }
        } else if let last = entry.lastFeedingTime {
            // 12+ months: the app does not predict here, so neither do we.
            Text(minutesText(entry.date.timeIntervalSince(last)))
        }
    }
}

// MARK: - Start-feeding control (D16, design note § 5)

/// What the capsule does. Idle, it starts a feed through `StartFeedingIntent`.
/// While a feed runs, it is a link to the Feeding tab, so a second tap can
/// never start a second feed. Before onboarding it looks idle but only opens
/// the app.
enum WidgetControl: Equatable {
    case start
    case openApp
    case running(since: Date)

    static func state(for entry: BabyBloomEntry) -> WidgetControl {
        if let since = entry.runningFeedStart { return .running(since: since) }
        return entry.hasBaby ? .start : .openApp
    }
}

/// A BBSurface capsule: white on the gradient's light end measures 2.64:1,
/// BBPrimary on BBSurface 5.6 / 6.2 (note § 5). Visually 36 pt high, with a
/// 44 pt hit area.
struct WidgetFeedControl: View {
    let entry: BabyBloomEntry
    /// `tab.feeding` on the small widget, `button.start_feeding` on the medium.
    let label: String
    /// False on the onboarding showcase: the same look, nothing to tap.
    let isInteractive: Bool
    /// False on the small family: WidgetKit ignores a `Link` there, and the
    /// widget's own `widgetURL` already opens Feeding.
    var linksToFeeding = true

    var body: some View {
        switch WidgetControl.state(for: entry) {
        case .start:
            if isInteractive {
                Button(intent: StartFeedingIntent()) { idle }
                    .buttonStyle(.plain)
            } else {
                idle
            }
        case .openApp:
            linked { idle }
        case .running(let since):
            linked { running(since) }
        }
    }

    @ViewBuilder
    private func linked<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if isInteractive && linksToFeeding {
            Link(destination: DeepLink.url(.feeding)) { content() }
        } else {
            content()
        }
    }

    /// VoiceOver hears what the tap does, not "play, Feeding": the small
    /// widget's visible label is only the tab name.
    private var idle: some View {
        capsule {
            Image(systemName: "play.fill")
            Text(label)
        }
        .foregroundStyle(Color("BBPrimary"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("button.start_feeding".l)
    }

    /// No words, only the glyph and the minutes (note § 5, owner #25: whole
    /// minutes, never seconds). VoiceOver gets the words the glyph stands for,
    /// as on the Live Activity.
    private func running(_ since: Date) -> some View {
        let title = entry.runningFeedTitle ?? .breast
        let minutes = WidgetCopy.minutesText(entry.date.timeIntervalSince(since))
        return capsule {
            Image(systemName: title.glyph)
            Text(minutes)
                .monospacedDigit()
        }
        .foregroundStyle(Color("BBTextPrimary"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.key.l), \(minutes)")
    }

    private func capsule<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Capsule().fill(Color("BBSurface")))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
    }
}

// MARK: - Small Widget View
struct BabyBloomSmallWidgetView: View {
    let entry: BabyBloomEntry
    var isInteractive = true

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
            } else {
                // The first day is not an error state. The name is what tells
                // the parent this widget is theirs and working.
                Text(entry.babyName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("widget.log_first_feeding".l)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            // Today's count left this size to make room for the control; it
            // stays on the medium widget (note § 5).
            WidgetFeedControl(entry: entry, label: "tab.feeding".l,
                              isInteractive: isInteractive, linksToFeeding: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // The small family takes one tap target; the control above is its own.
        .widgetURL(isInteractive ? DeepLink.url(.feeding) : nil)
        .environment(\.locale, WidgetCopy.formattingLocale)
    }
}

// MARK: - Medium Widget View
struct BabyBloomMediumWidgetView: View {
    let entry: BabyBloomEntry
    var isInteractive = true

    var body: some View {
        Group {
            if entry.hasLoggedAFeeding {
                HStack(alignment: .top, spacing: 20) {
                    link(.feeding) {
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        // At 12+ months the hero IS the elapsed feed time, so
                        // this row would print the same fact twice in two
                        // different formats. Sleep is the column's content there.
                        if entry.nextFeedingTime != nil, let last = entry.lastFeedingTime {
                            link(.feeding) {
                                statRow(icon: "heart.fill", title: "widget.last_feed".l) {
                                    Text(WidgetCopy.minutesText(entry.date.timeIntervalSince(last)))
                                }
                            }
                            .layoutPriority(1)
                        }
                        link(.sleep) {
                            statRow(icon: "moon.fill",
                                    title: entry.isAsleep ? "widget.sleeping".l : "tab.sleep".l) {
                                sleepValue
                            }
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 0)
                        control
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
                    Spacer(minLength: 0)
                    control
                        .frame(maxWidth: 190)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        // Anything outside the links and the control opens Feeding too.
        .widgetURL(isInteractive ? DeepLink.url(.feeding) : nil)
        .environment(\.locale, WidgetCopy.formattingLocale)
    }

    private var control: some View {
        WidgetFeedControl(entry: entry, label: "button.start_feeding".l, isInteractive: isInteractive)
    }

    /// A tap area per section (note § 5). Off on the onboarding showcase,
    /// where a link would leave onboarding for a tab that is not there yet.
    @ViewBuilder
    private func link<Content: View>(_ destination: DeepLink.Destination,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        if isInteractive {
            Link(destination: DeepLink.url(destination)) { content() }
        } else {
            content()
        }
    }

    /// The spec's "same, plus how long overdue", in whole minutes. Hidden for
    /// the first partial minute — "Просрочено на 0 мин" would undercut the
    /// hero that just said it is time.
    @ViewBuilder
    private func overdueLine(_ due: Date) -> some View {
        let overdue = entry.date.timeIntervalSince(due)
        if overdue >= 60 {
            HStack(spacing: 4) {
                Text("widget.overdue_by".l)
                Text(WidgetCopy.minutesText(overdue))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    /// A running sleep advances with the per-minute entries; a finished one
    /// has a fixed length and the string baked at fetch time is still true.
    @ViewBuilder
    private var sleepValue: some View {
        if entry.isAsleep, let started = entry.sleepStartTime {
            Text(WidgetCopy.minutesText(entry.date.timeIntervalSince(started)))
        } else {
            Text(entry.lastSleepDuration ?? "—")
        }
    }

    /// Up to 40 pt high, down to 30 on the smallest medium widgets (SE: 148 pt,
    /// a 10.2" iPad: 141). The rows have layout priority, so the stack sets the
    /// control's 44 pt aside first and splits the rest between them; a fixed
    /// 40 pushed the column 5–19 pt past those widgets' margins.
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
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 40, alignment: .leading)
        .contentShape(Rectangle())
    }
}

import AppIntents
import SwiftUI
import WidgetKit

// The Live Activity's views, compiled into the app AND the widget extension:
// the extension renders them on the Lock Screen and in the Dynamic Island, and
// BabyBloomTests renders them for review (LiveActivityRenderDump).
//
// Only asset-catalog colours by name and system text styles here: DesignSystem
// (BBTheme) is not part of the widget target. Spec: teamdocs/design/
// m1-live-activity.md §§ 2–4. Calm rule: no colour or glyph changes with how
// long a timer has run.

extension TimerKind {
    var tint: Color { Color(self == .feeding ? "BBFeeding" : "BBSleep") }
}

extension TimerTitle {
    var glyph: String {
        switch self {
        case .nap:   return "sun.max.fill"
        case .night: return "moon.fill"
        default:     return "heart.fill"
        }
    }
}

/// The ticking elapsed time. The system draws it, so it needs no updates; the
/// 24 h upper bound only keeps the range valid, the activity ends long before.
struct TimerElapsedText: View {
    let startTime: Date

    var body: some View {
        Text(timerInterval: startTime...startTime.addingTimeInterval(24 * 3600), countsDown: false)
            .monospacedDigit()
    }
}

/// One spec for both surfaces (§ 4): capsule, BBPrimary fill, BBOnPrimary label,
/// the same glyph and word as the in-app stop for that timer.
struct TimerStopButton: View {
    let attributes: TimerActivityAttributes

    var body: some View {
        Button(intent: StopTimerIntent(entryID: attributes.entryID, kind: attributes.kind)) {
            Label(attributes.kind == .feeding ? "button.finish".l : "button.woke_up".l,
                  systemImage: attributes.kind == .feeding ? "stop.fill" : "sun.max.fill")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color("BBOnPrimary"))
                .padding(.horizontal, 16)
                .frame(minWidth: 96, minHeight: 44)
                .background(Capsule().fill(Color("BBPrimary")))
                // Horizontal only: the label never truncates, but a vertical
                // fixedSize asks the Island's region for more height than it has.
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock Screen

struct TimerLockScreenView: View {
    let attributes: TimerActivityAttributes
    let state: TimerActivityAttributes.ContentState
    /// Past `staleDate` (start + 8 h) or ended by the system: the digits would
    /// be wrong or frozen, so none are shown (R4.2).
    let isStale: Bool

    private var startedLine: String {
        String(format: "live_activity.started_fmt".l, attributes.startTime.appTimeOfDay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(attributes.kind.tint.opacity(0.22))
                    Image(systemName: state.endedAt == nil ? state.title.glyph : "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BBPrimary"))
                }
                .frame(width: 32, height: 32)
                Text(state.title.key.l)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color("BBTextPrimary"))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    primaryLine
                    Text(startedLine)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color("BBTextSecondary"))
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                if state.endedAt == nil {
                    TimerStopButton(attributes: attributes)
                }
            }
        }
        .padding(16)
        // The system gives an activity about 160 pt of height; past xxxLarge the
        // Stop label and the timer no longer fit it (render dump, AX5).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    @ViewBuilder private var primaryLine: some View {
        if let endedAt = state.endedAt {
            Text(String(format: "live_activity.saved_fmt".l,
                        WidgetCopy.minutesText(endedAt.timeIntervalSince(attributes.startTime))))
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color("BBTextPrimary"))
                .lineLimit(1)
        } else if isStale {
            Text("live_activity.continues_in_app".l)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(Color("BBTextSecondary"))
                .lineLimit(2)
        } else {
            // The timer never truncates; the title above gives way first.
            TimerElapsedText(startTime: attributes.startTime)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(Color("BBTextPrimary"))
                .fixedSize()
        }
    }
}

// MARK: - Dynamic Island (always on black: pinned to the dark scheme)
// Text size capped at xLarge: the Island's regions are fixed by the system and
// a larger glyph spills past them (render dump, AX5).

struct TimerIslandCompactLeading: View {
    let kind: TimerKind
    let title: TimerTitle

    var body: some View {
        Image(systemName: title.glyph)
            .font(.body)
            .foregroundStyle(kind.tint)
            .environment(\.colorScheme, .dark).dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

struct TimerIslandCompactTrailing: View {
    let startTime: Date
    let isStale: Bool

    var body: some View {
        Group {
            if isStale {
                Image(systemName: "ellipsis")
            } else {
                // Fixed width holds "1:23:45": Text(timerInterval:) is greedy in
                // the Island and would otherwise push the camera gap.
                TimerElapsedText(startTime: startTime)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .font(.system(.body, design: .rounded).weight(.semibold))
        .foregroundStyle(Color("BBTextPrimary"))
        .environment(\.colorScheme, .dark).dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

struct TimerIslandMinimal: View {
    let kind: TimerKind
    let title: TimerTitle

    var body: some View {
        TimerIslandCompactLeading(kind: kind, title: title)
    }
}

struct TimerIslandExpandedLeading: View {
    let kind: TimerKind
    let title: TimerTitle

    var body: some View {
        ZStack {
            Circle().fill(kind.tint.opacity(0.22))
            Image(systemName: title.glyph)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(kind.tint)
        }
        .frame(width: 36, height: 36)
        .environment(\.colorScheme, .dark).dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

struct TimerIslandExpandedTrailing: View {
    let startTime: Date
    let isStale: Bool

    var body: some View {
        Group {
            if isStale {
                Text(String(format: "live_activity.started_fmt".l, startTime.appTimeOfDay))
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color("BBTextSecondary"))
            } else {
                TimerElapsedText(startTime: startTime)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color("BBTextPrimary"))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
            }
        }
        .environment(\.colorScheme, .dark).dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

struct TimerIslandExpandedBottom: View {
    let attributes: TimerActivityAttributes
    let state: TimerActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(isStale ? "live_activity.continues_in_app".l : state.title.key.l)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color("BBTextSecondary"))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            TimerStopButton(attributes: attributes)
        }
        .environment(\.colorScheme, .dark).dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

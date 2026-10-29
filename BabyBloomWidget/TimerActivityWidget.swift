import ActivityKit
import SwiftUI
import WidgetKit

/// The feeding / sleep timer on the Lock Screen and in the Dynamic Island.
/// Views live in BabyBloom/Features/LiveActivity (shared with the tests); this
/// is only the system's configuration around them.
struct TimerActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // The widget's localization singleton is otherwise refreshed only
            // in getTimeline; an activity can render with no timeline at all.
            let _ = LocalizationManager.shared.refreshFromStore()
            TimerLockScreenView(attributes: context.attributes, state: context.state,
                                isStale: context.isStale)
                .environment(\.locale, WidgetCopy.formattingLocale)
                .activityBackgroundTint(Color("BBSurface"))
                .activitySystemActionForegroundColor(Color("BBPrimary"))
        } dynamicIsland: { context in
            let _ = LocalizationManager.shared.refreshFromStore()
            let stale = context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TimerIslandExpandedLeading(kind: context.attributes.kind, title: context.state.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerIslandExpandedTrailing(startTime: context.attributes.startTime, isStale: stale)
                        .environment(\.locale, WidgetCopy.formattingLocale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimerIslandExpandedBottom(attributes: context.attributes, state: context.state,
                                              isStale: stale)
                        .environment(\.locale, WidgetCopy.formattingLocale)
                }
            } compactLeading: {
                TimerIslandCompactLeading(kind: context.attributes.kind, title: context.state.title)
            } compactTrailing: {
                TimerIslandCompactTrailing(startTime: context.attributes.startTime, isStale: stale)
                    .environment(\.locale, WidgetCopy.formattingLocale)
            } minimal: {
                TimerIslandMinimal(kind: context.attributes.kind, title: context.state.title)
            }
            .keylineTint(Color("BBPrimary"))
        }
    }
}

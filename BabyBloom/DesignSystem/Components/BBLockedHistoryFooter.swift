import SwiftUI

/// The one locked row that stands in for everything older than the free
/// history window, on all five list surfaces (feeding, sleep, diaper, events,
/// recent activity). Its own file for the same reason `LockBadge` has one: it
/// is drawn identically at every site and nothing about it belongs to the
/// section that happens to render it first.
///
/// Calm tint, never alarm red: nothing is wrong and nothing was lost — the
/// rows are still in the store and come back the moment a subscription does.
/// Red is this app's colour for "your data is about to go away", and the
/// delete button two rows below is using it.
struct BBLockedHistoryFooter: View {
    /// Which list is drawing it, for `history_lock_shown`.
    let surface: AnalyticsEvent.HistorySurface
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(BBTheme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("history.free_window".l)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .body,
                                                        weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                    Text("history.unlock".l)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .body,
                                                        weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(BBTheme.Spacing.md)
            // Apple's minimum target. The row is short enough at default type
            // size that the padding alone would leave it under 44pt.
            .frame(minHeight: 44)
            .background(BBTheme.Colors.primary.opacity(0.08))
            .cornerRadius(BBTheme.Radius.md)
            // The whole row sells, not just the glyph and the two labels.
            .contentShape(Rectangle())
        }
        .buttonStyle(BBScaleButtonStyle())
        // A LABEL only — deliberately no `accessibilityElement(children:)` and
        // no hint. Overriding the label is enough to replace the composed one,
        // while `children: .ignore` on a Button can take `.isButton` and its
        // activation with it, which would leave a VoiceOver user a padlock
        // they cannot open: the one failure worse than showing no padlock at
        // all. `bbLockedAccessibility` appends `premium.locked_a11y` as the
        // VALUE, so the row reads «Показаны последние 15 дней, Доступно с
        // Премиум, кнопка» — the state, the gate, the affordance, once each.
        // A hint would repeat the gate a third time, since the visible second
        // line already says it.
        .accessibilityLabel(Text("history.free_window".l))
        .bbLockedAccessibility(true)
        // On insertion, not on scroll: the hosting lists are plain VStacks, so
        // this reads "a day on which a capped list was opened", whether or not
        // the parent scrolled down to the row. The facade sends it at most
        // once per surface per local day.
        .onAppear { Analytics.shared.noteHistoryLockShown(surface) }
    }
}

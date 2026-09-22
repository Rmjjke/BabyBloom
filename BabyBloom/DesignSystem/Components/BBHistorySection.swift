import SwiftUI
import SwiftData

/// The one locked row that stands in for everything older than the free
/// window, on all five list surfaces (feeding, sleep, diaper, events, recent
/// activity).
///
/// Calm tint, never alarm red: nothing is wrong and nothing was lost — the
/// rows are still in the store and come back the moment a subscription does.
/// Red is this app's colour for "your data is about to go away", and the
/// delete button two rows below is using it.
struct BBLockedHistoryFooter: View {
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
        // Without this the two labels are read as one run-on sentence; the
        // explicit label keeps the window and the offer as separate phrases.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("history.free_window".l))
        .accessibilityHint(Text("history.unlock".l))
        .bbLockedAccessibility(true)
    }
}

/// Reusable history section shared by the feeding, sleep and diaper screens:
/// a "History" header, a time-range filter picker, an empty state, and a
/// swipe-to-delete list with a "delete all" button for the filtered range.
///
/// A free account sees only the last `HistoryWindow.freeDays` days of the
/// chosen range; older rows collapse into one locked footer that opens the
/// paywall. Deleting is deliberately NOT windowed — see `onDeleteAll`.
struct BBHistorySection<Entry: PersistentModel & Identifiable, Row: View>: View {
    let entries: [Entry]
    @Binding var filter: HistoryFilter
    let dateKeyPath: KeyPath<Entry, Date>
    let emptyIcon: String
    let emptyColor: Color
    let emptyTitle: String
    let emptySubtitle: String
    /// The entitlement, not a date: the section derives the boundary itself so
    /// three call sites cannot disagree about what "15 days" means.
    let isPremium: Bool
    @ViewBuilder let row: (Entry) -> Row
    let onDelete: (Entry) -> Void
    let onDeleteAll: ([Entry]) -> Void
    let onUnlock: () -> Void

    private var filtered: [Entry] {
        let cutoff = filter.startDate()
        return entries.filter { $0[keyPath: dateKeyPath] >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.history")
            BBHistoryFilterPicker(selected: $filter)

            if filtered.isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    color: emptyColor,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                // `items` is the FULL picker-filtered range and stays that way:
                // it is what the delete button acts on. Only `window.visible`
                // is rendered.
                let items = filtered
                let window = HistoryWindow.split(
                    items,
                    date: { $0[keyPath: dateKeyPath] },
                    cutoff: HistoryWindow.cutoff(isPremium: isPremium)
                )
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(window.visible) { entry in
                        SwipeToDeleteRow(onDelete: { onDelete(entry) }) {
                            row(entry)
                        }
                    }
                }
                // Only when something is actually held back — a fresh install,
                // and any range that fits inside the window, must never see a
                // padlock for rows that do not exist.
                //
                // When `visible` is empty but `hiddenCount` is not (a Year
                // range holding nothing recent), the footer stands alone rather
                // than the empty state taking over: "no records" would be a lie
                // about a list that has records.
                if window.hiddenCount > 0 {
                    BBLockedHistoryFooter(onUnlock: onUnlock)
                }
                // `items`, never `window.visible`: a paywall may gate what a
                // parent can SEE of their own records, never what they can
                // remove (DECISIONS 2026-09-01). The confirmation says so when
                // the two differ.
                BBDeleteHistoryButton(deletesHiddenRows: window.hiddenCount > 0) {
                    onDeleteAll(items)
                }
            }
        }
    }
}

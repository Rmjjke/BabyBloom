import SwiftUI
import SwiftData

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
    /// `nil` means unlimited. Comes from `SubscriptionManager.historyCutoff`,
    /// which is the single place the entitlement, the unresolved-entitlement
    /// grace and the 15-day arithmetic meet — the section derives none of it.
    let historyCutoff: Date?
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

            // No `cap:` — this section renders the whole range, so the window
            // is the only thing that can hold a row back.
            let model = HistoryWindow.list(filtered,
                                           date: { $0[keyPath: dateKeyPath] },
                                           cutoff: historyCutoff)

            if model.deletable.isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    color: emptyColor,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(model.visible) { entry in
                        SwipeToDeleteRow(onDelete: { onDelete(entry) }) {
                            row(entry)
                        }
                    }
                }
                // When `visible` is empty but the footer is up (a Year range
                // holding nothing recent), the footer stands alone rather than
                // the empty state taking over: "no records" would be a lie
                // about a list that has records.
                if model.showsLockedFooter {
                    BBLockedHistoryFooter(onUnlock: onUnlock)
                }
                // `model.deletable`, never `model.visible`: a paywall may gate
                // what a parent can SEE of their own records, never what they
                // can remove (DECISIONS 2026-09-01).
                BBDeleteHistoryButton(deletesHiddenRows: model.deletesRowsNotShown) {
                    onDeleteAll(model.deletable)
                }
            }
        }
    }
}

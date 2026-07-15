import SwiftUI
import SwiftData

/// Reusable history section shared by the feeding, sleep and diaper screens:
/// a "History" header, a time-range filter picker, an empty state, and a
/// swipe-to-delete list with a "delete all" button for the filtered range.
struct BBHistorySection<Entry: PersistentModel & Identifiable, Row: View>: View {
    let entries: [Entry]
    @Binding var filter: HistoryFilter
    let dateKeyPath: KeyPath<Entry, Date>
    let emptyIcon: String
    let emptyColor: Color
    let emptyTitle: String
    let emptySubtitle: String
    @ViewBuilder let row: (Entry) -> Row
    let onDelete: (Entry) -> Void
    let onDeleteAll: ([Entry]) -> Void

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
                let items = filtered
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(items) { entry in
                        SwipeToDeleteRow(onDelete: { onDelete(entry) }) {
                            row(entry)
                        }
                    }
                }
                BBDeleteHistoryButton {
                    onDeleteAll(items)
                }
            }
        }
    }
}

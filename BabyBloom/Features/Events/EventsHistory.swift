import Foundation
import SwiftData

/// One row of the Events history: a logged event, or a pediatrician visit
/// that is listed there but never deleted from there.
enum EventsHistoryRow: Identifiable {
    case event(CustomEvent)
    case visit(DoctorVisit)

    var id: PersistentIdentifier {
        switch self {
        case .event(let event): return event.persistentModelID
        case .visit(let visit): return visit.persistentModelID
        }
    }

    var date: Date {
        switch self {
        case .event(let event): return event.time
        case .visit(let visit): return visit.date
        }
    }
}

/// What the Events screen renders. The window and the cap only ever see
/// events, so the locked footer still means "events older than 15 days" and a
/// visit can never raise it; visits are merged in afterwards.
struct EventsHistory {
    /// Footer and delete-all come from here: events only.
    let events: HistoryWindow.List<CustomEvent>
    let rows: [EventsHistoryRow]

    var showsEmptyState: Bool { events.deletable.isEmpty && rows.isEmpty }
    /// Delete-all reaches events only, so it has nothing to offer without them.
    var showsDeleteAll: Bool { !events.deletable.isEmpty }

    /// A medicine's doses keep the window and have twenty rows of their own:
    /// at four a day they would fill the shared twenty in five days and push
    /// every bath and walk out, and uncapped a year of daily drops would draw
    /// hundreds of rows. The medication's own screen lists every dose. Each
    /// half decides its footer the usual way; delete-all reaches every event.
    init(events: [CustomEvent], visits: [DoctorVisit], cutoff: Date?, cap: Int = 20) {
        let others = HistoryWindow.list(events.filter { !$0.isDose }, date: { $0.time }, cutoff: cutoff, cap: cap)
        let doses = HistoryWindow.list(events.filter(\.isDose), date: { $0.time }, cutoff: cutoff, cap: cap)
        let visible = HistoryMerge.merge(others.visible, exempt: doses.visible, date: { $0.time })
        self.events = HistoryWindow.List(deletable: events,
                                         visible: visible,
                                         showsLockedFooter: others.showsLockedFooter || doses.showsLockedFooter)
        self.rows = HistoryMerge.merge(
            visible.map(EventsHistoryRow.event),
            exempt: DoctorPeriod.newestFirst(visits).map(EventsHistoryRow.visit),
            date: \.date
        )
    }
}

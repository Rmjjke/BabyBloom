import WidgetKit

/// Ask the widget for a new timeline after the app changes what it shows.
///
/// Without this, an entry logged in the app reaches the widget only on its own
/// ~15-minute cadence, so a parent who has just logged a feed sees the old
/// countdown — the one case where the staleness is obvious and looks broken.
/// A named call site is deliberate: the next person adding an entry type gets
/// a symbol to grep for.
///
/// Called on every create, delete, and timer-stop for a feeding or sleep
/// entry — even sites, like ending a feed, whose data the widget doesn't
/// currently render. The blanket invariant ("any mutation refreshes the
/// widget") is cheaper to keep true than a curated list of "mutations the
/// widget happens to care about today": the cost of a call site that's
/// occasionally redundant is one extra reload request, while the cost of a
/// curated list is that it silently drifts out of date every time someone
/// adds a widget row without rediscovering which sites matter.
enum WidgetRefresh {
    static func entriesChanged() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

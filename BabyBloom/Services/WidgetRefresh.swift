import WidgetKit

/// Ask the widget for a new timeline after the app changes what it shows.
///
/// Without this, an entry logged in the app reaches the widget only on its own
/// ~15-minute cadence, so a parent who has just logged a feed sees the old
/// countdown — the one case where the staleness is obvious and looks broken.
/// A named call site is deliberate: the next person adding an entry type gets
/// a symbol to grep for. `WidgetCenter` is therefore called from HERE and
/// nowhere else — a raw `reloadAllTimelines()` elsewhere makes that grep lie.
///
/// The three entry points all do the same thing and are meant to; they exist
/// so each call site says WHY it is reloading, which a single `entriesChanged`
/// could not do honestly at the language or profile sites.
///
/// `entriesChanged` is called on every create, delete, and timer-stop for a
/// feeding or sleep entry — even sites, like ending a feed, whose data the
/// widget doesn't currently render. The blanket invariant ("any mutation
/// refreshes the widget") is cheaper to keep true than a curated list of
/// "mutations the widget happens to care about today": the cost of a call site
/// that's occasionally redundant is one extra reload request, while the cost
/// of a curated list is that it silently drifts out of date every time someone
/// adds a widget row without rediscovering which sites matter.
enum WidgetRefresh {
    /// A feeding or sleep entry was created, deleted, or stopped.
    static func entriesChanged() {
        reload()
    }

    /// The baby was created or edited. The widget prints the name, so without
    /// this a freshly onboarded parent stares at the default name for up to
    /// fifteen minutes.
    static func profileChanged() {
        reload()
    }

    /// `setLanguage` mirrors the choice into the App Group, but the widget
    /// process only re-reads it when it builds its next timeline.
    static func languageChanged() {
        reload()
    }

    private static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

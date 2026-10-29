import Foundation

/// The Live Activity's two stored values. `UserDefaults.standard` is enough:
/// the Stop intent runs in the app process, and the extension reads nothing here.
enum LiveActivitySettings {
    static let enabledKey = "liveActivity.enabled"
    static let startedKey = "liveActivity.startedEntryIDs"

    /// ON by default (D5): an unset key means the user never turned it off.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Entries that already had an activity. An entry gets one start, so an
    /// activity the user swiped away does not come back on the next foreground;
    /// turning the switch on (or iOS re-enabling) clears it.
    static var startedEntryIDs: Set<UUID> {
        get {
            Set((UserDefaults.standard.stringArray(forKey: startedKey) ?? [])
                .compactMap(UUID.init(uuidString:)))
        }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: startedKey) }
    }
}

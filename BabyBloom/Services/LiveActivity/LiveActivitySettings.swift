import Foundation

/// The Live Activity's stored values. `UserDefaults.standard` is enough:
/// the Stop intent runs in the app process, and the extension reads nothing here.
enum LiveActivitySettings {
    static let enabledKey = "liveActivity.enabled"
    static let startedKey = "liveActivity.startedEntryIDs"
    static let startedBuildKey = "liveActivity.startedBuild"

    /// ON by default: an unset key means the user never turned it off.
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

    /// The build `startedEntryIDs` was written under. Unset in 1.3.0 and
    /// earlier, which counts as another build.
    static var startedBuild: String? {
        get { UserDefaults.standard.string(forKey: startedBuildKey) }
        set { UserDefaults.standard.set(newValue, forKey: startedBuildKey) }
    }

    /// Version and build number together, so a version bump that resets the
    /// build number still reads as another build.
    static var currentBuild: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

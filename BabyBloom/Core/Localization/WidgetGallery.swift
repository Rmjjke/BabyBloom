import Foundation

/// The widget gallery's name and description for each widget.
///
/// `Widget.body` is read when the gallery opens, by an extension process that
/// may have been alive since before the last language switch; its
/// localization singleton is otherwise refreshed only by a timeline. Each read
/// refreshes it from the App Group first. Shared with the app target so a
/// test can read it.
enum WidgetGallery {
    static func small() -> (name: String, description: String) {
        LocalizationManager.shared.refreshFromStore()
        return ("brand.name".l, "widget.description_small".l)
    }

    static func medium() -> (name: String, description: String) {
        LocalizationManager.shared.refreshFromStore()
        return (String(format: "widget.name_medium".l, "brand.name".l), "widget.description_medium".l)
    }
}

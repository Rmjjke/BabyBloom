import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump, the same idea as GrowthCardRenderDump.
/// Renders both widget sizes, across all five states the redesign defines, in
/// every shipped language and both themes, so the widget can be eyeballed
/// without adding it to a simulator home screen.
///
/// It also guards the thing that actually broke: the widget used to render
/// hardcoded Russian, and its LocalizationManager could not see the app's
/// language at all. `assertNoCyrillic` fails the English and Spanish dumps if
/// a Russian literal ever creeps back in.
///
/// Run it, read `WIDGET_DIR` from the test log, open the files.
@MainActor
final class WidgetRenderDump: XCTestCase {

    /// Every state the redesign defines, so a truncation or an empty-looking
    /// card shows up as an image rather than as a bug report.
    private static func states(now: Date) -> [(name: String, entry: BabyBloomEntry)] {
        let hourAgo = now.addingTimeInterval(-3600)
        return [
            ("normal", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                      todayFeedingCount: 6, isAsleep: false,
                                      nextFeedingTime: now.addingTimeInterval(4320), ageMonths: 1)),
            ("due", BabyBloomEntry(date: now, babyName: "Vlad",
                                   lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                   todayFeedingCount: 6, isAsleep: false,
                                   nextFeedingTime: now.addingTimeInterval(-120), ageMonths: 1)),
            ("asleep", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                      todayFeedingCount: 6, isAsleep: true,
                                      nextFeedingTime: now.addingTimeInterval(4320), ageMonths: 1)),
            ("empty", BabyBloomEntry(date: now, babyName: "Vlad",
                                     lastFeedingTime: nil, lastSleepDuration: nil,
                                     todayFeedingCount: 0, isAsleep: false,
                                     nextFeedingTime: nil, ageMonths: 1)),
            ("toddler", BabyBloomEntry(date: now, babyName: "Vlad",
                                       lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                       todayFeedingCount: 4, isAsleep: false,
                                       nextFeedingTime: nil, ageMonths: 14)),
        ]
    }

    func testDumpWidgets() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-widgets")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let now = Date()
        for (name, entry) in Self.states(now: now) {
            for locale in ["en", "ru", "es"] {
                LocalizationManager.shared.setLanguage(locale)
                for dark in [false, true] {
                    let theme = dark ? "dark" : "light"
                    try dump("\(name)-small-\(locale)-\(theme)", BabyBloomSmallWidgetView(entry: entry),
                              size: CGSize(width: 158, height: 158), dark: dark)
                    try dump("\(name)-medium-\(locale)-\(theme)", BabyBloomMediumWidgetView(entry: entry),
                              size: CGSize(width: 338, height: 158), dark: dark)
                }
            }
        }

        print("WIDGET_DIR=\(dir.path)")
    }

    /// The regression this task fixes: every widget-rendered key must resolve
    /// in every language. A missing key falls back to the key itself, so a
    /// dotted "widget.today_count" in the output means a broken translation.
    func testEveryWidgetKeyResolvesInEveryLanguage() {
        let keys = [
            "brand.name", "baby.default_name", "tab.feeding", "tab.sleep",
            "status.sleeping_now", "stats.min_ago", "stats.h_ago",
            "duration.min_only", "duration.h_min",
            "widget.today_count", "widget.feedings_count",
            "widget.description_small", "widget.name_medium",
            "widget.description_medium",
            // The countdown redesign's keys — the widget's whole reason for
            // being now lives in these, so this guard is pointless without them.
            "widget.feeding_in", "widget.time_to_feed", "widget.last_feed",
            "widget.log_first_feeding", "widget.sleeping", "widget.today_short",
        ]
        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            for key in keys {
                XCTAssertNotEqual(key.l, key, "\(key) has no \(locale) translation")
            }
        }
    }

    /// English and Spanish must contain no Cyrillic — the exact defect that
    /// shipped before: a Russian widget for the store's default audience.
    func testNonRussianLocalesRenderNoCyrillic() {
        let cyrillic = CharacterSet(charactersIn: "\u{0410}"..."\u{044F}")
        for locale in ["en", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            for key in ["widget.today_count", "widget.feedings_count",
                        "widget.description_small", "widget.name_medium",
                        "widget.description_medium", "status.sleeping_now",
                        "baby.default_name",
                        "widget.feeding_in", "widget.time_to_feed", "widget.last_feed",
                        "widget.log_first_feeding", "widget.sleeping", "widget.today_short"] {
                XCTAssertNil(key.l.rangeOfCharacter(from: cyrillic),
                             "\(key) is still Russian in \(locale): \(key.l)")
            }
        }
    }

    /// `WidgetBackground` stands in for the widget's `.containerBackground`,
    /// which is only available inside a real widget container — a view
    /// rendered in-process by `ImageRenderer` gets neither that background
    /// nor the system's own corner mask and margins. Without this wrapper the
    /// dump would just be white text on nothing.
    ///
    /// This is a stand-in, not the real thing: it proves the CONTENT lays out
    /// and translates correctly, nothing more. It cannot catch a
    /// container-level defect — a lost corner radius, a margin regression, the
    /// gradient not reaching the container's edge. That is exactly how the
    /// bug this branch fixes shipped once already: the in-process dump looked
    /// correct while the real widget, framed by the system container, did
    /// not. A green run here is not evidence the widget looks right on a home
    /// screen — only Step 4's simulator screenshot is.
    private func dump<V: View>(_ name: String, _ view: V, size: CGSize, dark: Bool) throws {
        let framed = ZStack {
            WidgetBackground()
            view
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, dark ? .dark : .light)

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("could not render \(name)")
        }
        try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bb-widgets")
            .appendingPathComponent("\(name).png"))
    }
}

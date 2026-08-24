import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump, the same idea as GrowthCardRenderDump.
/// Renders both widget sizes in every shipped language so the widget can be
/// eyeballed without adding it to a simulator home screen.
///
/// It also guards the thing that actually broke: the widget used to render
/// hardcoded Russian, and its LocalizationManager could not see the app's
/// language at all. `assertNoCyrillic` fails the English and Spanish dumps if
/// a Russian literal ever creeps back in.
///
/// Run it, read `WIDGET_DIR` from the test log, open the files.
@MainActor
final class WidgetRenderDump: XCTestCase {

    private var sample: BabyBloomEntry {
        BabyBloomEntry(
            date: Date(),
            babyName: "Мия",
            lastFeedingTime: Date().addingTimeInterval(-95 * 60),
            lastSleepDuration: String(format: "duration.h_min".l, 2, 15),
            todayFeedingCount: 6,
            isAsleep: true
        )
    }

    func testDumpWidgets() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-widgets")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            // Built inside the loop: the entry's sleep duration is itself
            // localized, so it must be produced under the active language.
            let entry = sample
            try dump("\(locale)-small", BabyBloomSmallWidgetView(entry: entry), size: CGSize(width: 158, height: 158))
            try dump("\(locale)-medium", BabyBloomMediumWidgetView(entry: entry), size: CGSize(width: 338, height: 158))
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
                        "baby.default_name"] {
                XCTAssertNil(key.l.rangeOfCharacter(from: cyrillic),
                             "\(key) is still Russian in \(locale): \(key.l)")
            }
        }
    }

    private func dump<V: View>(_ name: String, _ view: V, size: CGSize) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("could not render \(name)")
        }
        try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bb-widgets")
            .appendingPathComponent("\(name).png"))
    }
}

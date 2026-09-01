import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump, the same idea as GrowthCardRenderDump.
/// Renders both widget sizes, across all five states the redesign defines, in
/// every shipped language and both themes, so the widget can be eyeballed
/// without adding it to a simulator home screen.
///
/// It also guards the things that actually broke: the widget used to render
/// hardcoded Russian, and its LocalizationManager could not see the app's
/// language at all — `testNonRussianLocalesRenderNoCyrillic` fails the English
/// and Spanish dumps if a Russian literal creeps back in. That guard reads
/// JSON keys only, so `testWidgetViewsFormatDatesInTheAppLanguage` covers the
/// half it structurally cannot see: the countdown, which SwiftUI formats from
/// the environment rather than from the table.
///
/// Run it, read `WIDGET_DIR` from the test log, open the files.
@MainActor
final class WidgetRenderDump: XCTestCase {

    /// Every state the redesign defines, so a truncation or an empty-looking
    /// card shows up as an image rather than as a bug report.
    ///
    /// Built per language, not once: the sleep duration is a formatted string
    /// in real life too, so a fixture that hardcoded one language's wording
    /// would put Russian in the English dump and look like the defect this
    /// file exists to catch.
    private static func states(now: Date) -> [(name: String, entry: BabyBloomEntry)] {
        let hourAgo = now.addingTimeInterval(-3600)
        let sleepStart = now.addingTimeInterval(-3780)
        let napLength = String(format: "duration.h_min".l, 1, 3)
        return [
            ("normal", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, sleepStartTime: sleepStart,
                                      lastSleepDuration: napLength,
                                      todayFeedingCount: 6, isAsleep: false,
                                      nextFeedingTime: now.addingTimeInterval(4320))),
            ("due", BabyBloomEntry(date: now, babyName: "Vlad",
                                   lastFeedingTime: hourAgo, sleepStartTime: sleepStart,
                                   lastSleepDuration: napLength,
                                   todayFeedingCount: 6, isAsleep: false,
                                   nextFeedingTime: now.addingTimeInterval(-120))),
            ("asleep", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, sleepStartTime: sleepStart,
                                      lastSleepDuration: napLength,
                                      todayFeedingCount: 6, isAsleep: true,
                                      nextFeedingTime: now.addingTimeInterval(4320))),
            ("empty", BabyBloomEntry(date: now, babyName: "Vlad",
                                     lastFeedingTime: nil, sleepStartTime: nil,
                                     lastSleepDuration: nil,
                                     todayFeedingCount: 0, isAsleep: false,
                                     nextFeedingTime: nil)),
            ("toddler", BabyBloomEntry(date: now, babyName: "Vlad",
                                       lastFeedingTime: hourAgo, sleepStartTime: sleepStart,
                                       lastSleepDuration: napLength,
                                       todayFeedingCount: 4, isAsleep: false,
                                       nextFeedingTime: nil)),
        ]
    }

    private static let smallSize = CGSize(width: 158, height: 158)
    private static let mediumSize = CGSize(width: 338, height: 158)

    func testDumpWidgets() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-widgets")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let now = Date()
        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            for (name, entry) in Self.states(now: now) {
                for dark in [false, true] {
                    let theme = dark ? "dark" : "light"
                    try dump("\(name)-small-\(locale)-\(theme)", BabyBloomSmallWidgetView(entry: entry),
                              size: Self.smallSize, dark: dark)
                    try dump("\(name)-medium-\(locale)-\(theme)", BabyBloomMediumWidgetView(entry: entry),
                              size: Self.mediumSize, dark: dark)
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
            "widget.overdue_by",
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
                        "widget.overdue_by",
                        "widget.log_first_feeding", "widget.sleeping", "widget.today_short"] {
                XCTAssertNil(key.l.rangeOfCharacter(from: cyrillic),
                             "\(key) is still Russian in \(locale): \(key.l)")
            }
        }
    }

    /// The countdown is not a JSON key, so the Cyrillic guard above cannot see
    /// it: `Text(_:style:)` is formatted by SwiftUI from `\.locale`, which
    /// nothing in a widget process sets. A Russian widget therefore read
    /// "Кормление через" over an English "1 hr, 11 min".
    ///
    /// The check: render each view under two DIFFERENT ambient locales. A view
    /// that pins its own locale is immune to what sits above it, so the two
    /// renders must be byte-identical; a view that has lost the pin formats the
    /// hero twice in two languages and they diverge. The control render — the
    /// same date-styled `Text` with no pin — proves the renderer honours the
    /// ambient locale at all, so an identical pair means "pinned", not
    /// "ImageRenderer ignores locale".
    ///
    /// It does NOT check that the pinned locale is applied to a widget by
    /// WidgetKit, nor that the Russian wording is idiomatic; and it reads the
    /// pinned VALUE at the seam (`WidgetCopy.formattingLocale`) rather than
    /// out of the rendered glyphs.
    func testWidgetViewsFormatDatesInTheAppLanguage() throws {
        let russian = Locale(identifier: "ru_RU")
        let spanish = Locale(identifier: "es_419")
        let now = Date()
        // 30 s off a whole minute: `.relative` re-reads `Date()` on every
        // render, and a pair straddling a tick would differ for a reason that
        // has nothing to do with locale.
        let due = now.addingTimeInterval(72 * 60 + 30)
        let entry = BabyBloomEntry(date: now, babyName: "Vlad",
                                   lastFeedingTime: now.addingTimeInterval(-3600),
                                   sleepStartTime: nil, lastSleepDuration: nil,
                                   todayFeedingCount: 6, isAsleep: false,
                                   nextFeedingTime: due)

        let control = CGSize(width: 200, height: 40)
        XCTAssertNotEqual(try render(Text(due, style: .relative), size: control, ambient: russian),
                          try render(Text(due, style: .relative), size: control, ambient: spanish),
                          "the renderer ignores the ambient locale — this test proves nothing")

        for (language, identifier) in [("en", "en_US"), ("ru", "ru_RU"), ("es", "es_419")] {
            LocalizationManager.shared.setLanguage(language)
            XCTAssertEqual(WidgetCopy.formattingLocale.identifier, identifier,
                           "\(language) formats system output through the wrong locale")

            let views: [(String, AnyView, CGSize)] = [
                ("small", AnyView(BabyBloomSmallWidgetView(entry: entry)), Self.smallSize),
                ("medium", AnyView(BabyBloomMediumWidgetView(entry: entry)), Self.mediumSize),
            ]
            for (name, view, size) in views {
                XCTAssertEqual(try render(view, size: size, ambient: russian),
                               try render(view, size: size, ambient: spanish),
                               "\(name) in \(language) formats dates from the ambient locale, "
                               + "not the app's — the countdown will render in the wrong language")
            }
        }
    }

    /// `WidgetBackground` stands in for the widget's `.containerBackground`,
    /// which is only available inside a real widget container — a view
    /// rendered in-process by `ImageRenderer` gets neither that background
    /// nor the system's own corner mask and margins. Without this wrapper the
    /// dump would just be white text on nothing. The 11 pt inset stands in for
    /// the container's content margins, which the system applies and this
    /// process does not; it is an approximation of a system metric, so treat
    /// truncation seen at exactly the edge as a hint, not a verdict.
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
            view.padding(11)
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

    /// Same framing as `dump`, with an ambient locale forced from OUTSIDE the
    /// view — which is what makes a missing in-view locale pin observable.
    private func render<V: View>(_ view: V, size: CGSize, ambient: Locale) throws -> Data {
        let framed = ZStack {
            WidgetBackground()
            view.padding(11)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.locale, ambient)

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else {
            throw XCTSkip("ImageRenderer produced no image")
        }
        return data
    }
}

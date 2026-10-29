import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump for the design review, like
/// WidgetRenderDump. Renders the Live Activity's Lock Screen view and Dynamic
/// Island pieces in every state the design note draws (running per title,
/// Saved, stale), in every language, light and dark, at the default and the
/// largest text size.
///
/// The Island is mocked as a black capsule around the real region views; the
/// system's own framing is only seen on the simulator (Task 9's live look).
/// Run it, read `LIVE_ACTIVITY_DIR` from the test log, open the files.
@MainActor
final class LiveActivityRenderDump: XCTestCase {

    private let start = Date().addingTimeInterval(-(14 * 60 + 32))

    private func attributes(_ kind: TimerKind) -> TimerActivityAttributes {
        TimerActivityAttributes(entryID: UUID(), kind: kind, startTime: start)
    }

    private var states: [(name: String, kind: TimerKind, state: TimerActivityAttributes.ContentState, stale: Bool)] {
        [("running-left", .feeding, .init(title: .breastLeft, endedAt: nil), false),
         ("running-bottle", .feeding, .init(title: .bottle, endedAt: nil), false),
         ("running-nap", .sleep, .init(title: .nap, endedAt: nil), false),
         ("running-night", .sleep, .init(title: .night, endedAt: nil), false),
         ("saved", .feeding, .init(title: .breastRight, endedAt: Date()), false),
         ("stale", .sleep, .init(title: .night, endedAt: nil), true)]
    }

    func testDumpLiveActivity() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-live-activity")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let previous = LocalizationManager.shared.language.rawValue
        defer { LocalizationManager.shared.setLanguage(previous) }

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            for item in states {
                let attrs = attributes(item.kind)
                for size in [DynamicTypeSize.large, .accessibility5] {
                    let sizeName = size == .large ? "default" : "ax5"
                    for dark in [false, true] {
                        let lock = TimerLockScreenView(attributes: attrs, state: item.state, isStale: item.stale)
                            .frame(width: 360)
                            .background(Color("BBSurface"))
                        try write(lock, dark: dark, size: size, to: dir,
                                  "lock-\(item.name)-\(locale)-\(sizeName)-\(dark ? "dark" : "light")")
                    }
                    try write(island(attrs, item.state, item.stale), dark: true, size: size, to: dir,
                              "island-\(item.name)-\(locale)-\(sizeName)")
                }
            }
        }
        print("LIVE_ACTIVITY_DIR=\(dir.path)")
    }

    /// Compact (leading · camera · trailing), minimal, and the expanded layout.
    private func island(_ attrs: TimerActivityAttributes, _ state: TimerActivityAttributes.ContentState,
                        _ stale: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                TimerIslandCompactLeading(kind: attrs.kind, title: state.title)
                Spacer().frame(width: 126)
                TimerIslandCompactTrailing(startTime: attrs.startTime, isStale: stale)
            }
            .padding(.horizontal, 14).frame(height: 37).background(Capsule().fill(.black))

            TimerIslandMinimal(kind: attrs.kind, title: state.title)
                .frame(width: 37, height: 37).background(Circle().fill(.black))

            VStack(spacing: 10) {
                HStack {
                    TimerIslandExpandedLeading(kind: attrs.kind, title: state.title)
                    Spacer()
                    TimerIslandExpandedTrailing(startTime: attrs.startTime, isStale: stale)
                }
                TimerIslandExpandedBottom(attributes: attrs, state: state, isStale: stale)
            }
            .padding(18).frame(width: 370)
            .background(RoundedRectangle(cornerRadius: 44).fill(.black))
        }
        .padding(12)
        .background(Color.gray.opacity(0.3))
    }

    private func write<V: View>(_ view: V, dark: Bool, size: DynamicTypeSize,
                                to dir: URL, _ name: String) throws {
        let framed = view
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, WidgetCopy.formattingLocale)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { return XCTFail("could not render \(name)") }
        try data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

import XCTest
import SwiftUI
@testable import BabyBloom

/// The weekly card's open state belongs to its week. The Dashboard keeps one
/// card view across Monday 00:00 and hands it the new week's summary, so each
/// test hosts one card and swaps its summary the same way, then reads the card
/// as VoiceOver finds it.
@MainActor
final class WeeklyCardWeekStateTests: XCTestCase {

    /// Not private: the macro's generated extension could not see it.
    @MainActor @Observable
    final class Source {
        var summary: WeeklySummary
        init(_ summary: WeeklySummary) { self.summary = summary }
    }

    private struct Host: View {
        let source: Source
        let startExpanded: Bool
        var body: some View {
            WeeklySummaryCard(summary: source.summary, startExpanded: startExpanded, onAddWeighing: {})
                .frame(width: 402)
        }
    }

    private let calendar = WeeklySummary.calendar
    private let defaultsKeys = ["weekly.hiddenWeek", "weekly.viewedWeek"]

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    /// Feeds, night sleeps and two weighings over the week from `monday` and
    /// the week before it, summed up as of `now`.
    private func summary(monday: Date, now: Date, feedsADay: Int = 8) throws -> WeeklySummary {
        var feeds: [Date] = []
        var sleeps: [(start: Date, end: Date)] = []
        for offset in -7..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            feeds += (0..<feedsADay).map { calendar.date(byAdding: .hour, value: 1 + $0 * 3, to: day)! }
            let night = calendar.date(byAdding: .hour, value: 21, to: day)!
            sleeps.append((start: night, end: night.addingTimeInterval(7 * 3600)))
        }
        let weighings = [(0, 4.5), (6, 4.68)].map { offset, kg in
            WeightMeasurement(date: calendar.date(byAdding: .day, value: offset, to: monday)!, weightKg: kg)
        }
        let birth = calendar.date(byAdding: .day, value: -60, to: monday)!
        let input = WeeklySummary.Input(feeds: feeds, sleeps: sleeps, otherEntries: [],
                                        measurements: weighings, birthDate: birth,
                                        correctedBirthDate: birth, birthWeightKg: 3.4, isMale: false)
        let summary = try XCTUnwrap(WeeklySummary.make(now: now, input: input))
        XCTAssertEqual(summary.week.start, monday, "the fixture's week")
        return summary
    }

    /// Last week as of Wednesday 28 Oct: 19–25 Oct.
    private func weekA(feedsADay: Int = 8) throws -> WeeklySummary {
        try summary(monday: date(10, 19), now: date(10, 28, 12), feedsADay: feedsADay)
    }

    /// The next one, as of Wednesday 4 Nov: 26 Oct – 1 Nov.
    private func weekB() throws -> WeeklySummary {
        try summary(monday: date(10, 26), now: date(11, 4, 12))
    }

    // MARK: Cases

    func testANewWeekOpensCollapsedAfterTheLastWasLeftOpen() throws {
        try withCleanDefaults {
            let b = try weekB()
            let source = Source(try weekA())
            let card = try host(source, startExpanded: true, viewed: "2026-10-19")
            XCTAssertEqual(headerValue(card), "weekly.a11y_expanded".l, "startExpanded opens it")

            source.summary = b
            settle()
            XCTAssertEqual(headerValue(card), "weekly.a11y_collapsed".l)
            XCTAssertEqual(readout(card), try freshReadout(b), "the new week's card as it first opens")
        }
    }

    func testWithinAWeekTheCardStaysAsTheParentLeftIt() throws {
        try withCleanDefaults {
            let source = Source(try weekA())
            let card = try host(source, startExpanded: true, viewed: "2026-10-19")
            let before = readout(card)

            source.summary = try weekA(feedsADay: 7)
            settle()
            XCTAssertNotEqual(readout(card), before, "the new figures reached the card")
            XCTAssertEqual(headerValue(card), "weekly.a11y_expanded".l)
        }
    }

    func testACardHiddenWhileOpenComesBackCollapsedWithTheNewWeek() throws {
        try withCleanDefaults {
            UserDefaults.standard.set("2026-10-19", forKey: "weekly.hiddenWeek")
            let b = try weekB()
            let source = Source(try weekA())
            let card = try host(source, startExpanded: true, viewed: "2026-10-26")
            XCTAssertNil(headerValue(card), "hidden for its week")

            source.summary = b
            settle()
            XCTAssertEqual(headerValue(card), "weekly.a11y_collapsed".l)
            XCTAssertEqual(readout(card), try freshReadout(b))
        }
    }

    // MARK: Hosting

    private var windows: [UIWindow] = []

    /// `viewed` marks the week the card first appears with as already counted,
    /// so no analytics event leaves a test.
    private func host(_ source: Source, startExpanded: Bool, viewed: String) throws -> UIView {
        try Self.enableAccessibility()
        UserDefaults.standard.set(viewed, forKey: "weekly.viewedWeek")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 1400)
        let controller = UIHostingController(rootView: Host(source: source, startExpanded: startExpanded))
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        settle()
        return controller.view
    }

    /// The readout of week B's card built from scratch, collapsed.
    private func freshReadout(_ summary: WeeklySummary) throws -> [String] {
        windows.forEach { $0.isHidden = true }
        let card = try host(Source(summary), startExpanded: false, viewed: "2026-10-26")
        return readout(card)
    }

    /// SwiftUI builds a hosted view's accessibility elements only while an
    /// assistive client is on. A simulator that ran a UI test driver since it
    /// booted has one; a freshly booted one does not, and the card would read
    /// as empty. Turning it on for the test process is what VoiceOver does. It
    /// stays on for the rest of the run, the state every test already runs in
    /// on a simulator that has had a UI test driver.
    private static func enableAccessibility() throws {
        let library = try XCTUnwrap(dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
                                    "libAccessibility did not load: the card's elements cannot be read")
        let symbol = try XCTUnwrap(dlsym(library, "_AXSApplicationAccessibilitySetEnabled"),
                                   "_AXSApplicationAccessibilitySetEnabled is gone from libAccessibility")
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    /// Restores the two keys the card stores, and drops the windows.
    private func withCleanDefaults(_ body: () throws -> Void) throws {
        let saved = defaultsKeys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(defaultsKeys, saved) {
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
            windows.forEach { $0.isHidden = true }
            windows = []
        }
        UserDefaults.standard.removeObject(forKey: "weekly.hiddenWeek")
        try body()
    }

    // MARK: Reading

    /// Every accessibility element's label and value, in tree order.
    private func readout(_ root: UIView) -> [String] {
        var seen = Set<ObjectIdentifier>()
        var out: [String] = []
        collect(root, seen: &seen, into: &out)
        return out
    }

    /// The header button's value (expanded / collapsed); nil with no card.
    private func headerValue(_ root: UIView) -> String? {
        let title = "weekly.title".l + ", "
        return readout(root).first { $0.hasPrefix(title) }?.components(separatedBy: " | ").last
    }

    private func collect(_ root: NSObject, seen: inout Set<ObjectIdentifier>, into out: inout [String]) {
        guard seen.insert(ObjectIdentifier(root)).inserted else { return }
        if root.isAccessibilityElement {
            out.append((root.accessibilityLabel ?? "") + " | " + (root.accessibilityValue ?? ""))
        }
        for child in children(of: root) { collect(child, seen: &seen, into: &out) }
    }

    private func children(of root: NSObject) -> [NSObject] {
        var out: [NSObject] = []
        if let elements = root.accessibilityElements {
            out += elements.compactMap { $0 as? NSObject }
        } else {
            let count = root.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                for i in 0..<count {
                    if let element = root.accessibilityElement(at: i) as? NSObject { out.append(element) }
                }
            }
        }
        if let view = root as? UIView { out += view.subviews }
        return out
    }
}

import XCTest
import SwiftUI
@testable import BabyBloom

/// The weekly chart's bars as VoiceOver finds them: Sleep's day reads in the
/// words every duration uses, a count reads as its number.
@MainActor
final class WeeklyBarChartVoiceOverTests: XCTestCase {

    /// 2 h 5 min, as Sleep plots it: the day's seconds over 3600.
    private let sleepHours = 7500.0 / 3600

    override func tearDown() {
        windows.forEach { $0.isHidden = true }
        windows = []
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// Up to today the day's hours; a future day plots 0, as no sleep is in it.
    private func plotted(_ hours: Double) -> (Date) -> Double {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return { $0 > todayStart ? 0 : hours }
    }

    func testSleepsBarReadsTheDayAsADuration() throws {
        let expected: [(SupportedLanguage, String)] = [
            (.en, "2\u{00A0}h\u{00A0}5\u{00A0}min"),
            (.ru, "2\u{00A0}ч\u{00A0}5\u{00A0}мин"),
            (.es, "2\u{00A0}h\u{00A0}5\u{00A0}min"),
        ]
        for (language, words) in expected {
            LocalizationManager.shared.setLanguage(language)
            let chart = try host(BBWeeklyBarChart(
                valueFor: plotted(sleepHours),
                color: .blue,
                voiceOverValue: SleepView.chartVoiceOverValue(hours:)
            ))
            print("BAR_READOUT \(language):", readout(chart))
            XCTAssertEqual(try bar(chart, on: Date()).value, words, "\(language)")
            if let tomorrow = futureDayThisWeek() {
                XCTAssertEqual(try bar(chart, on: tomorrow).value, "0", "a future day reads as before")
            }
        }
    }

    func testSleepsDayIsFlooredToWholeMinutesLikeTheTotalTile() {
        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(SleepView.chartVoiceOverValue(hours: 0), DurationText.minutes(0), "a day with no sleep")
        XCTAssertEqual(SleepView.chartVoiceOverValue(hours: 59.0 / 3600), DurationText.minutes(0))
        XCTAssertEqual(SleepView.chartVoiceOverValue(hours: 7380.0 / 3600), DurationText.minutes(123),
                       "7380 s over 3600 and back must not drop a minute")
    }

    /// Feeding and Diapers pass no writer: their bars read the count.
    func testACountsBarKeepsReadingItsNumber() throws {
        LocalizationManager.shared.setLanguage(.ru)
        let chart = try host(BBWeeklyBarChart(valueFor: plotted(3), color: .blue))
        print("BAR_READOUT count:", readout(chart))
        XCTAssertEqual(try bar(chart, on: Date()).value, "3")
    }

    // MARK: Hosting

    private var windows: [UIWindow] = []

    private func host(_ chart: BBWeeklyBarChart) throws -> UIView {
        try Self.enableAccessibility()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 400)
        let controller = UIHostingController(rootView: chart.frame(width: 370))
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        return controller.view
    }

    /// SwiftUI builds a hosted view's accessibility elements only while an
    /// assistive client is on; a freshly booted simulator has none.
    private static func enableAccessibility() throws {
        let library = try XCTUnwrap(dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
                                    "libAccessibility did not load: the chart's elements cannot be read")
        let symbol = try XCTUnwrap(dlsym(library, "_AXSApplicationAccessibilitySetEnabled"),
                                   "_AXSApplicationAccessibilitySetEnabled is gone from libAccessibility")
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }

    /// Tomorrow when it is still in the chart's week (Monday first); nil on Sunday.
    private func futureDayThisWeek() -> Date? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        return calendar.component(.weekday, from: tomorrow) == 2 ? nil : tomorrow
    }

    // MARK: Reading

    private struct Element { let label: String; let value: String }

    /// The bar whose label is the day's weekday as the axis writes it.
    private func bar(_ root: UIView, on date: Date) throws -> Element {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.language.locale
        formatter.dateFormat = "EEE"
        let day = String(formatter.string(from: date).prefix(2)).capitalized
        return try XCTUnwrap(elements(root).first { $0.label == day },
                             "no bar for \(day) in \(readout(root))")
    }

    private func readout(_ root: UIView) -> [String] {
        elements(root).map { "\($0.label) | \($0.value)" }
    }

    private func elements(_ root: UIView) -> [Element] {
        var seen = Set<ObjectIdentifier>()
        var out: [Element] = []
        collect(root, seen: &seen, into: &out)
        return out
    }

    private func collect(_ root: NSObject, seen: inout Set<ObjectIdentifier>, into out: inout [Element]) {
        guard seen.insert(ObjectIdentifier(root)).inserted else { return }
        if root.isAccessibilityElement {
            out.append(Element(label: root.accessibilityLabel ?? "", value: root.accessibilityValue ?? ""))
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

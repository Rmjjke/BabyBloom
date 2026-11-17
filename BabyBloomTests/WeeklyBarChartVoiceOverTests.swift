import XCTest
import SwiftUI
@testable import BabyBloom

/// The weekly chart's bars as VoiceOver finds them: Sleep's day reads in the
/// words every duration uses, a count reads as its number, and a day still to
/// come reads nothing.
@MainActor
final class WeeklyBarChartVoiceOverTests: XCTestCase {

    /// 2 h 5 min, as Sleep plots it: the day's seconds over 3600.
    private let sleepHours = 7500.0 / 3600
    private let accessibility = HostedAccessibility()

    override func tearDown() {
        accessibility.close()
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
            for day in daysUpToToday() {
                XCTAssertEqual(try XCTUnwrap(bar(chart, on: day), "no bar for \(day) in \(readout(chart))").value,
                               words, "\(language)")
            }
            assertFutureDaysAreSilent(chart, "\(language)")
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
        for language in [SupportedLanguage.en, .ru] {
            LocalizationManager.shared.setLanguage(language)
            let chart = try host(BBWeeklyBarChart(valueFor: plotted(3), color: .blue))
            print("BAR_READOUT count \(language):", readout(chart))
            for day in daysUpToToday() {
                XCTAssertEqual(try XCTUnwrap(bar(chart, on: day), "no bar for \(day) in \(readout(chart))").value,
                               "3", "\(language)")
            }
            assertFutureDaysAreSilent(chart, "\(language) count")
        }
    }

    // MARK: Days

    private func host(_ chart: BBWeeklyBarChart) throws -> UIView {
        let root = try accessibility.host(chart.frame(width: 370), size: CGSize(width: 402, height: 400))
        for descriptor in accessibility.chartDescriptors(root) {
            print("BAR_AUDIO_GRAPH \(LocalizationManager.shared.language): \(descriptor.readout)")
        }
        return root
    }

    /// The chart's week, Monday first, as `BBWeeklyBarChart` lays it out.
    private func week() -> [Date] {
        let calendar = LocalizationManager.shared.language.calendar
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }

    private func daysUpToToday() -> [Date] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return week().filter { $0 <= todayStart }
    }

    /// No element at all for a day still to come: it shows no bar and no
    /// number, so it says nothing (Sunday has none to check).
    private func assertFutureDaysAreSilent(_ chart: UIView, _ context: String,
                                           file: StaticString = #filePath, line: UInt = #line) {
        let todayStart = Calendar.current.startOfDay(for: Date())
        for day in week() where day > todayStart {
            XCTAssertNil(bar(chart, on: day), "\(context): a future day reads nothing, in \(readout(chart))",
                         file: file, line: line)
        }
    }

    // MARK: Reading

    /// The bar whose label is the day's weekday as the axis writes it.
    private func bar(_ root: UIView, on date: Date) -> HostedAccessibility.Element? {
        let day = LocaleDates.shortWeekday(date, locale: LocalizationManager.shared.language.locale)
        return accessibility.elements(root).first { $0.label == day }
    }

    private func readout(_ root: UIView) -> [String] {
        accessibility.elements(root).map { "\($0.label) | \($0.value)" }
    }
}

import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite: the weekly card in every state the design note
/// names (S1–S6), collapsed and expanded, en/ru/es, light/dark, default and
/// AX2, for the Designer's review. Run it, read `WEEKLY_DIR` from the log.
@MainActor
final class WeeklySummaryRenderDump: XCTestCase {

    private let calendar = WeeklySummary.calendar
    /// Wednesday 28 Oct 2026: last week is 19–25 Oct.
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))!

    private func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func input(days: [Int], previous: Bool, weights: [(Date, Double)],
                       birth: Date? = nil) -> WeeklySummary.Input {
        var feeds: [Date] = []
        var sleeps: [(start: Date, end: Date)] = []
        for day in days {
            feeds += (0..<8).map { at(day, 1 + $0 * 3) }
            sleeps.append((start: at(day, 21), end: at(day, 21).addingTimeInterval(7 * 3600)))
            sleeps.append((start: at(day, 13), end: at(day, 13).addingTimeInterval(1.5 * 3600)))
        }
        if previous {
            for day in 12...18 {
                feeds += (0..<7).map { at(day, 1 + $0 * 3) }
                sleeps.append((start: at(day, 21), end: at(day, 21).addingTimeInterval(7.5 * 3600)))
            }
        }
        let birthDate = birth ?? at(1, 0).addingTimeInterval(-40 * 86_400)
        return WeeklySummary.Input(feeds: feeds, sleeps: sleeps, otherEntries: [],
                                   measurements: weights.map { WeightMeasurement(date: $0.0, weightKg: $0.1) },
                                   birthDate: birthDate, correctedBirthDate: birthDate,
                                   birthWeightKg: 3.4, isMale: false)
    }

    private var states: [(String, WeeklySummary)] {
        let pair = [(at(12, 10), 4.32), (at(19, 10), 4.5), (at(25, 10), 4.68)]
        let all = Array(19...25)
        let cases: [(String, WeeklySummary.Input)] = [
            ("s1-normal", input(days: all, previous: true, weights: pair)),
            ("s2-first-week", input(days: all, previous: false, weights: pair)),
            ("s3-gaps", input(days: [19, 20, 22, 23], previous: true, weights: pair)),
            ("s5-newborn", input(days: all, previous: false, weights: [(at(15, 10), 3.4), (at(23, 10), 3.3)],
                                 birth: at(15, 0))),
            ("s6-no-pair", input(days: all, previous: true, weights: [])),
        ]
        return cases.map { ($0.0, WeeklySummary.make(now: now, input: $0.1)!) }
    }

    func testDumpWeeklyCard() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-weekly")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for language in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(language)
            for (name, summary) in states {
                for expanded in [false, true] {
                    for dark in [false, true] {
                        for ax in [false, true] {
                            let card = WeeklySummaryCard(summary: summary, startExpanded: expanded,
                                                         onAddWeighing: {})
                                .padding(16)
                                .frame(width: 402)
                                .background(BBTheme.Colors.background)
                                .environment(\.colorScheme, dark ? .dark : .light)
                                .environment(\.dynamicTypeSize, ax ? .accessibility2 : .large)
                            let renderer = ImageRenderer(content: card)
                            renderer.scale = 2
                            guard let data = renderer.uiImage?.pngData() else {
                                return XCTFail("no image for \(name)")
                            }
                            let file = "\(name)-\(expanded ? "open" : "closed")-\(language)"
                                + "-\(dark ? "dark" : "light")\(ax ? "-ax2" : "").png"
                            try data.write(to: dir.appendingPathComponent(file))
                        }
                    }
                }
            }
        }
        print("WEEKLY_DIR=\(dir.path)")
    }
}

import XCTest
@testable import BabyBloom

/// One written form for a span of time across the app, the tiles and the
/// export; counts that read as words.
@MainActor
final class DurationFormatsTests: XCTestCase {

    private let nbsp = "\u{00A0}"

    private func feeding(seconds: TimeInterval, volume: Double? = nil) -> FeedingEntry {
        let start = Date(timeIntervalSinceNow: -7200)
        let entry = FeedingEntry(startTime: start, type: .formula, side: nil, volumeML: volume)
        entry.endTime = start.addingTimeInterval(seconds)
        return entry
    }

    func testMinutesReadAsMinutesHoursOrBothAndStayGlued() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(DurationText.minutes(0), "0\(nbsp)min")
        XCTAssertEqual(DurationText.minutes(45), "45\(nbsp)min")
        XCTAssertEqual(DurationText.minutes(60), "1\(nbsp)h")
        XCTAssertEqual(DurationText.minutes(75), "1\(nbsp)h\(nbsp)15\(nbsp)min")
        XCTAssertEqual(DurationText.minutes(-5), "0\(nbsp)min", "a clock skew never prints a negative span")

        LocalizationManager.shared.setLanguage(.ru)
        defer { LocalizationManager.shared.setLanguage(.en) }
        XCTAssertEqual(DurationText.minutes(45), "45\(nbsp)мин")
        XCTAssertEqual(DurationText.minutes(120), "2\(nbsp)ч")
        XCTAssertEqual(DurationText.minutes(645), "10\(nbsp)ч\(nbsp)45\(nbsp)мин")
    }

    /// Seconds only under a minute; from one minute a feed reads like a sleep.
    func testFeedDurationDropsSecondsFromOneMinute() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(feeding(seconds: 45).durationFormatted, String(format: "duration.sec".l, 45))
        XCTAssertEqual(feeding(seconds: 15 * 60 + 30).durationFormatted, String(format: "duration.min_only".l, 15))
        XCTAssertEqual(feeding(seconds: 3600).durationFormatted, String(format: "duration.h_only".l, 1))
        XCTAssertEqual(feeding(seconds: 75 * 60 + 20).durationFormatted, String(format: "duration.h_min".l, 1, 15))

        let start = Date(timeIntervalSinceNow: -7200)
        let sleep = SleepEntry(startTime: start, type: .nap)
        sleep.endTime = start.addingTimeInterval(75 * 60 + 20)
        XCTAssertEqual(sleep.durationFormatted, feeding(seconds: 75 * 60 + 20).durationFormatted,
                       "a feed and a sleep of one length read the same")
    }

    /// A count reads its two numbers; sleep reads two durations from the one
    /// writer, so 2 h 55 min is never «2 of 14 h» beside a tile saying
    /// «2 h 55 min».
    func testProgressReadsACountAsNumbersAndSleepAsTwoDurations() {
        let sleep = { (hours: Double, target: Double) in
            BBProgressCard.valueText(current: hours, target: target, measure: .hours)
        }
        defer { LocalizationManager.shared.setLanguage(.en) }

        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(BBProgressCard.valueText(current: 0, target: 6, measure: .count), "0 of 6")
        XCTAssertEqual(sleep(175.0 / 60, 14), "2\(nbsp)h\(nbsp)55\(nbsp)min of 14\(nbsp)h")
        XCTAssertEqual(sleep(0, 16), "0\(nbsp)min of 16\(nbsp)h")
        XCTAssertEqual(sleep(0.75, 16), "45\(nbsp)min of 16\(nbsp)h")
        XCTAssertEqual(sleep(16 + 20.0 / 60, 16), "16\(nbsp)h\(nbsp)20\(nbsp)min of 16\(nbsp)h",
                       "past the target the line reads as it is")
        XCTAssertEqual(sleep(10799.6 / 3600, 14), "3\(nbsp)h of 14\(nbsp)h",
                       "seconds round before the minutes floor, as the Sleep tile does")
        XCTAssertEqual(sleep(10790.0 / 3600, 14), "2\(nbsp)h\(nbsp)59\(nbsp)min of 14\(nbsp)h",
                       "a part minute is not rounded up")

        LocalizationManager.shared.setLanguage(.ru)
        XCTAssertEqual(BBProgressCard.valueText(current: 0, target: 6, measure: .count), "0 из 6")
        XCTAssertEqual(sleep(175.0 / 60, 14), "2\(nbsp)ч\(nbsp)55\(nbsp)мин из 14\(nbsp)ч")
        XCTAssertEqual(sleep(0, 16), "0\(nbsp)мин из 16\(nbsp)ч")

        LocalizationManager.shared.setLanguage(.es)
        XCTAssertEqual(BBProgressCard.valueText(current: 0, target: 6, measure: .count), "0 de 6")
        XCTAssertEqual(sleep(175.0 / 60, 14), "2\(nbsp)h\(nbsp)55\(nbsp)min de 14\(nbsp)h")
    }

    func testTileValueCutsFiguresFromWords() {
        let runs = BBStatCard.valueRuns("1\(nbsp)ч\(nbsp)15\(nbsp)мин")
        XCTAssertEqual(runs, [
            .init(text: "1", isWord: false),
            .init(text: "\(nbsp)ч\(nbsp)", isWord: true),
            .init(text: "15", isWord: false),
            .init(text: "\(nbsp)мин", isWord: true),
        ])
        XCTAssertEqual(BBStatCard.valueRuns("—"), [.init(text: "—", isWord: false)])
        XCTAssertEqual(BBStatCard.valueRuns("3,2"), [.init(text: "3,2", isWord: false)])
        XCTAssertEqual(String(BBStatCard.valueText("1\(nbsp)ч").characters), "1\(nbsp)ч",
                       "styling never changes the text")
    }

    func testExportFileNameKeepsTheNameAsTyped() {
        XCTAssertEqual(ExportGenerator.fileSlug("Mia Rose"), "Mia_Rose")
        XCTAssertEqual(ExportGenerator.fileSlug("  Mia/Ann  "), "MiaAnn")
    }

    func testExportWritesFeedAndSleepTotalsInHoursAndMinutes() {
        LocalizationManager.shared.setLanguage(.en)
        let start = Date(timeIntervalSinceNow: -7200)
        let sleep = SleepEntry(startTime: start, type: .nap)
        sleep.endTime = start.addingTimeInterval(90 * 60)
        let out = ExportGenerator.buildHTML(
            baby: nil, feedings: [feeding(seconds: 75 * 60 + 20, volume: 120)], sleeps: [sleep],
            diapers: [], growths: [], events: [],
            categories: [.feeding, .sleep], range: .all)

        let feed = DurationText.minutes(75), sleepTotal = DurationText.minutes(90)
        XCTAssertEqual(feed, "1\(nbsp)h\(nbsp)15\(nbsp)min")
        XCTAssertTrue(out.contains("<span class=\"val\">\(feed)</span>"), "feeding total")
        XCTAssertTrue(out.contains("<span class=\"val\">\(sleepTotal)</span>"), "sleep total")
        XCTAssertFalse(out.contains("75\(nbsp)min"), "a feed past an hour reads in h and min")
        XCTAssertFalse(out.contains("1.5\(nbsp)h"), "the sleep total is no longer a decimal of hours")
    }
}

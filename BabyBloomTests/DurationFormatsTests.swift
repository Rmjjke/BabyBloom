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

    func testProgressReadsAsWordsWithTheUnitOnlyForAMeasuredTarget() {
        LocalizationManager.shared.setLanguage(.en)
        XCTAssertEqual(BBProgressCard.valueText(current: 0, target: 6, unit: nil), "0 of 6")
        XCTAssertEqual(BBProgressCard.valueText(current: 10.7, target: 14, unit: "unit.h"), "10 of 14\(nbsp)h")

        LocalizationManager.shared.setLanguage(.ru)
        defer { LocalizationManager.shared.setLanguage(.en) }
        XCTAssertEqual(BBProgressCard.valueText(current: 0, target: 6, unit: nil), "0 из 6")
        XCTAssertEqual(BBProgressCard.valueText(current: 10, target: 14, unit: "unit.h"), "10 из 14\(nbsp)ч")
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

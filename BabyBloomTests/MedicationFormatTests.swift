import XCTest
@testable import BabyBloom

/// The words of the medication screens. Clock parts come from the same
/// `appTimeOfDay` / `appDayMonth` helpers the code uses: the time formatter
/// puts a narrow no-break space before AM/PM, so no time is typed literally.
@MainActor
final class MedicationFormatTests: XCTestCase {

    private typealias F = MedicationFormat

    private var previousLanguage: SupportedLanguage = .fallback

    override func setUp() async throws {
        try await super.setUp()
        previousLanguage = LocalizationManager.shared.language
        LocalizationManager.shared.setLanguage("en")
    }

    override func tearDown() async throws {
        LocalizationManager.shared.setLanguage(previousLanguage)
        try await super.tearDown()
    }

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func d(_ day: Int, _ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day,
                                      hour: hour, minute: minute, second: second))!
    }

    private let nb = "\u{00A0}"

    // MARK: duration

    func testDurationUnderAnHourIsMinutes() {
        XCTAssertEqual(F.duration(minutes: 0), "0\u{00A0}min")
        XCTAssertEqual(F.duration(minutes: 45), "45\u{00A0}min")
    }

    func testDurationOfWholeHoursDropsTheMinutes() {
        XCTAssertEqual(F.duration(minutes: 60), "1\u{00A0}h")
        XCTAssertEqual(F.duration(minutes: 360), "6\u{00A0}h")
    }

    func testDurationWithHoursAndMinutesKeepsBoth() {
        XCTAssertEqual(F.duration(minutes: 90), "1\u{00A0}h\u{00A0}30\u{00A0}min")
    }

    func testANegativeDurationReadsAsZero() {
        XCTAssertEqual(F.duration(minutes: -5), F.duration(minutes: 0))
    }

    // MARK: age

    func testAgeUnderAMinuteIsNil() {
        XCTAssertNil(F.age(59))
    }

    func testAgeFromAMinuteIsADuration() {
        XCTAssertEqual(F.age(60), "1\u{00A0}min")
        XCTAssertEqual(F.age(80 * 60), "1\u{00A0}h\u{00A0}20\u{00A0}min")
        XCTAssertEqual(F.age(47 * 3600 + 59 * 60), "47\u{00A0}h\u{00A0}59\u{00A0}min")
    }

    func testAgeCountsDaysFromFortyEightHours() {
        XCTAssertEqual(F.age(48 * 3600), "2\u{00A0}days")
        XCTAssertEqual(F.age(73 * 3600), "3\u{00A0}days")
    }

    func testAgeInDaysUsesTheRussianPluralForms() {
        LocalizationManager.shared.setLanguage("ru")
        XCTAssertEqual(F.age(48 * 3600), "2\u{00A0}дня")
        XCTAssertEqual(F.age(5 * 24 * 3600), "5\u{00A0}дней")
    }

    // MARK: when

    func testWhenOnTheSameDayIsJustTheTime() {
        let now = d(10, 12)
        let date = d(10, 9, 30)
        XCTAssertEqual(F.when(date, now: now, calendar: cal), date.appTimeOfDay)
    }

    func testWhenOnThePreviousDayAddsYesterday() {
        let date = d(9, 20, 15)
        XCTAssertEqual(F.when(date, now: d(10, 12), calendar: cal), "\(date.appTimeOfDay) yesterday")
    }

    func testMinutesApartAcrossMidnightStillCountAsYesterday() {
        let date = d(9, 23, 50)
        XCTAssertEqual(F.when(date, now: d(10, 0, 5), calendar: cal), "\(date.appTimeOfDay) yesterday")
    }

    func testWhenOnTheNextDayAddsTomorrow() {
        let date = d(11, 3)
        XCTAssertEqual(F.when(date, now: d(10, 22), calendar: cal), "\(date.appTimeOfDay) tomorrow")
    }

    func testWhenTwoDaysAwayNamesTheDate() {
        let date = d(12, 8)
        XCTAssertEqual(F.when(date, now: d(10, 12), calendar: cal),
                       "\(date.appTimeOfDay) on \(date.appDayMonth)")
    }

    func testRussianTomorrowPutsTheDayWordFirst() {
        LocalizationManager.shared.setLanguage("ru")
        let date = d(11, 3)
        XCTAssertEqual(F.when(date, now: d(10, 22), calendar: cal), "завтра, \(date.appTimeOfDay)")
    }

    // MARK: doseDay

    func testDoseDayNamesTodayAndYesterday() {
        let now = d(10, 12)
        XCTAssertEqual(F.doseDay(d(10, 8), now: now, calendar: cal), "Today")
        XCTAssertEqual(F.doseDay(d(9, 8), now: now, calendar: cal), "Yesterday")
    }

    func testAnOlderDoseDayIsTheDateGluedWithNoBreakSpaces() {
        let date = d(7, 8)
        let day = F.doseDay(date, now: d(10, 12), calendar: cal)
        XCTAssertEqual(day, date.appDayMonth.replacingOccurrences(of: " ", with: "\u{00A0}"))
        XCTAssertFalse(day.contains(" "))
    }

    // MARK: doseCount

    func testEnglishDoseCount() {
        XCTAssertEqual(F.doseCount(1), "1\u{00A0}dose")
        XCTAssertEqual(F.doseCount(3), "3\u{00A0}doses")
    }

    func testRussianDoseCountFollowsOneFewMany() {
        LocalizationManager.shared.setLanguage("ru")
        XCTAssertEqual(F.doseCount(1), "1\u{00A0}доза")
        XCTAssertEqual(F.doseCount(3), "3\u{00A0}дозы")
        XCTAssertEqual(F.doseCount(5), "5\u{00A0}доз")
        XCTAssertEqual(F.doseCount(21), "21\u{00A0}доза")
    }

    // MARK: meta

    func testMetaJoinsTheDoseTextAndTheInterval() {
        XCTAssertEqual(F.meta(doseText: "2.5 ml", intervalMinutes: 360), "2.5 ml\u{00A0}· interval 6\u{00A0}h")
    }

    func testMetaWithoutADoseTextIsTheIntervalAlone() {
        for text in [nil, "", "   "] as [String?] {
            XCTAssertEqual(F.meta(doseText: text, intervalMinutes: 360), "Interval: 6\u{00A0}h")
        }
    }

    // MARK: lines

    private func lines(_ status: MedicineStatus, interval: Int = 360, max: Int? = nil,
                       last24: Int = 0, total: Int = 0, now: Date) -> MedicationLines {
        F.lines(status: status, intervalMinutes: interval, maxPer24h: max,
                dosesInLast24Hours: last24, doseCount: total, now: now, calendar: cal)
    }

    func testAnEndedCourseHasNoStatusLine() {
        let ended = d(8, 18)
        let result = lines(.ended(ended), total: 14, now: d(10, 12))
        XCTAssertNil(result.primary)
        // A no-break space before the dot, as in every other dotted line.
        XCTAssertEqual(result.secondary, "Ended \(ended.appDayMonth)\u{00A0}· 14\u{00A0}doses")
        XCTAssertNil(result.count)
    }

    func testNoDoseWithoutAMaximumShowsTheIntervalOnly() {
        let result = lines(.noDose, now: d(10, 12))
        XCTAssertEqual(result.primary, "No doses logged yet")
        XCTAssertEqual(result.secondary, "Interval: 6\u{00A0}h")
        XCTAssertNil(result.count)
    }

    func testNoDoseWithAMaximumShowsNoCountYet() {
        let result = lines(.noDose, max: 4, last24: 0, now: d(10, 12))
        XCTAssertEqual(result.primary, "No doses logged yet")
        XCTAssertNil(result.count)
    }

    func testWaitingNamesTheEarliestTimeAndTheLastDoseWithItsAge() {
        let now = d(10, 12)
        let last = now.addingTimeInterval(-80 * 60)
        let until = last.addingTimeInterval(6 * 3600)
        let result = lines(.waiting(lastDose: last, until: until), now: now)
        XCTAssertEqual(result.primary, "Next dose not before \(until.appTimeOfDay)")
        XCTAssertEqual(result.secondary,
                       "Last dose at \(last.appTimeOfDay)\u{00A0}· 1\u{00A0}h\u{00A0}20\u{00A0}min ago")
        XCTAssertNil(result.count)
    }

    func testAFreshDoseReadsJustNow() {
        let now = d(10, 12)
        let last = now.addingTimeInterval(-30)
        let result = lines(.waiting(lastDose: last, until: last.addingTimeInterval(6 * 3600)), now: now)
        XCTAssertTrue(result.secondary.hasSuffix("\u{00A0}· just now"), result.secondary)
    }

    func testWaitingUntilTomorrowCarriesTheDayWord() {
        let now = d(10, 22)
        let last = d(10, 21)
        let until = d(11, 3)
        let result = lines(.waiting(lastDose: last, until: until), now: now)
        XCTAssertEqual(result.primary, "Next dose not before \(until.appTimeOfDay) tomorrow")
    }

    func testAllowedStatesThePassedIntervalAndTheAge() {
        let now = d(10, 12)
        let last = now.addingTimeInterval(-(8 * 3600 + 5 * 60))
        let result = lines(.allowed(lastDose: last), interval: 360, now: now)
        XCTAssertEqual(result.primary, "Last dose at \(last.appTimeOfDay)\u{00A0}· the 6\u{00A0}h interval has passed")
        XCTAssertEqual(result.secondary, "8\u{00A0}h\u{00A0}5\u{00A0}min ago")
    }

    func testAMaximumOnAWaitingCourseGivesTheCountLine() {
        let now = d(10, 12)
        let last = now.addingTimeInterval(-3600)
        let result = lines(.waiting(lastDose: last, until: last.addingTimeInterval(6 * 3600)),
                           max: 4, last24: 2, now: now)
        XCTAssertEqual(result.count, "Last 24\u{00A0}hours: 2\u{00A0}doses of the 4 you set")
    }

    // MARK: ordering

    func testByNameIsCaseInsensitive() {
        let list = ["paracetamol", "Ibuprofen", "amoxicillin"].map { Medicine(name: $0, intervalMinutes: 360) }
        XCTAssertEqual(F.byName(list).map(\.name), ["amoxicillin", "Ibuprofen", "paracetamol"])
    }

    func testEqualNamesKeepTheEarlierCourseFirst() {
        let earlier = Medicine(name: "Vitamin D", intervalMinutes: 1440)
        let later = Medicine(name: "Vitamin D", intervalMinutes: 1440)
        earlier.createdAt = d(1, 8)
        later.createdAt = d(5, 8)
        XCTAssertTrue(F.byName([later, earlier]).first === earlier)
    }

    func testByEndPutsTheLatestEndFirst() {
        let a = Medicine(name: "A", intervalMinutes: 360)
        let b = Medicine(name: "B", intervalMinutes: 360)
        let c = Medicine(name: "C", intervalMinutes: 360)
        a.endedAt = d(2, 8)
        b.endedAt = d(9, 8)
        c.endedAt = d(5, 8)
        XCTAssertEqual(F.byEnd([a, b, c]).map(\.name), ["B", "C", "A"])
    }

    // MARK: spoken

    func testSpokenSkipsEmptyPartsAndJoinsTheRest() {
        XCTAssertEqual(F.spoken([nil, "Paracetamol", "", "Next dose not before 3 PM", nil]),
                       "Paracetamol. Next dose not before 3 PM")
    }
}

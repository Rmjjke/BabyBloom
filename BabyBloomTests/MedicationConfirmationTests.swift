import XCTest
import SwiftData
@testable import BabyBloom

/// The calm confirmation a dose gets. Times and counts in the expected text
/// come from the same formatters the code uses, so no-break spaces and the
/// clock style match; one title is typed out to pin its key.
@MainActor
final class MedicationConfirmationTests: XCTestCase {

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

    private func d(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func when(_ date: Date, now: Date) -> String {
        F.when(date, now: now, calendar: cal)
    }

    /// The pure path: a schedule, a dose time, the words.
    private func confirm(interval: Int, max: Int?, doses: [Date], now: Date, at time: Date) -> DoseConfirmation? {
        let schedule = MedicineSchedule(intervalMinutes: interval, maxDosesPer24h: max,
                                        doseTimes: doses, now: now)
        return F.confirmation(name: "Paracetamol", check: schedule.check(time), intervalMinutes: interval,
                              nextAfterSave: schedule.nextAllowed(adding: time), now: now, calendar: cal)
    }

    private func schedule(interval: Int, max: Int?, doses: [Date], now: Date) -> MedicineSchedule {
        MedicineSchedule(intervalMinutes: interval, maxDosesPer24h: max, doseTimes: doses, now: now)
    }

    private func lines(_ text: String?) -> [String] {
        (text ?? "").components(separatedBy: "\n")
    }

    // MARK: Which variant

    /// The shape of the app's seed: before this dose both limits end at
    /// 14:00. With it, the interval ends at 16:00 and the maximum at 20:00,
    /// so the alert names the 24 hours and the time the screen then shows.
    func testTheSeedsFifthDoseNamesTheTwentyFourHoursAndTheTimeAfterTheSave() {
        let now = d(10, 10)
        let doses = [d(10, 8), d(10, 2), d(9, 20), d(9, 14)]
        let result = confirm(interval: 360, max: 4, doses: doses, now: now, at: now)
        XCTAssertEqual(result?.title, "With this dose, 5\u{00A0}doses in 24\u{00A0}hours")
        XCTAssertEqual(result?.message,
                       "Paracetamol\nYour maximum in 24\u{00A0}hours: 4\nIf you save, next dose not before \(when(d(10, 20), now: now))")
    }

    /// Both limits end at midnight once the dose is saved: the interval
    /// variant, with that time.
    func testATieOnceSavedNamesTheInterval() {
        let now = d(10, 9)
        let result = confirm(interval: 960, max: 2, doses: [d(9, 20), d(10, 0)], now: now, at: d(10, 8))
        XCTAssertEqual(result?.title,
                       String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 960)))
        XCTAssertEqual(lines(result?.message).last,
                       "If you save, next dose not before \(when(d(11, 0), now: now))")
    }

    func testAForwardDoseKeepsItsNextTime() {
        let now = d(10, 10)
        let doses = [d(10, 8), d(10, 2), d(9, 20), d(9, 14)]
        let result = confirm(interval: 360, max: 4, doses: doses, now: now, at: now)
        XCTAssertEqual(lines(result?.message).count, 3)
        XCTAssertTrue(lines(result?.message).last?.hasPrefix("If you save") == true)
    }

    func testAMaximumThatEndsLaterNamesTheTwentyFourHours() {
        let now = d(10, 10)
        let doses = [d(10, 0), d(10, 8)]
        let result = confirm(interval: 360, max: 2, doses: doses, now: now, at: now)
        let next = schedule(interval: 360, max: 2, doses: doses, now: now).nextAllowed(adding: now)
        XCTAssertEqual(result?.title, String(format: "medication.alert_max_title_fmt".l, F.doseCount(3)))
        XCTAssertEqual(result?.message,
                       String(format: "medication.alert_max_message_fmt".l, "Paracetamol", 2,
                              when(d(11, 8), now: now)))
        // The time in the alert is the one the medication's screen shows
        // once this dose is saved.
        XCTAssertEqual(next, d(11, 8))
    }

    func testTheMaximumAloneNamesTheTwentyFourHours() {
        let now = d(10, 12, 30)
        let doses = [d(10, 0), d(10, 4), d(10, 8)]
        let result = confirm(interval: 240, max: 3, doses: doses, now: now, at: d(10, 12))
        let next = schedule(interval: 240, max: 3, doses: doses, now: now).nextAllowed(adding: d(10, 12))
        XCTAssertEqual(result?.title, String(format: "medication.alert_max_title_fmt".l, F.doseCount(4)))
        XCTAssertEqual(result?.message,
                       String(format: "medication.alert_max_message_fmt".l, "Paracetamol", 3,
                              when(d(11, 4), now: now)))
        XCTAssertEqual(next, d(11, 4))
    }

    func testADosePutBeforeALoggedOneNamesTheLoggedDose() {
        let now = d(10, 17)
        let result = confirm(interval: 360, max: nil, doses: [d(10, 16)], now: now, at: d(10, 14))
        XCTAssertEqual(result?.title,
                       String(format: "medication.alert_after_title_fmt".l, F.duration(minutes: 360)))
        XCTAssertEqual(result?.message,
                       "Paracetamol\nLogged dose at \(when(d(10, 16), now: now))\nInterval: \(F.duration(minutes: 360))")
    }

    func testTheIntervalVariantWithoutAMaximum() {
        let now = d(10, 10)
        let result = confirm(interval: 360, max: nil, doses: [d(10, 8)], now: now, at: now)
        XCTAssertEqual(result?.title,
                       String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 360)))
        XCTAssertEqual(result?.message,
                       String(format: "medication.alert_before_message_fmt".l, "Paracetamol",
                              when(d(10, 8), now: now), when(d(10, 16), now: now)))
    }

    // MARK: Back-dated doses and the next line

    /// The later dose still sets the screen's time after the save, so that is
    /// the time named, though the earlier dose's interval has passed.
    func testABackDatedDoseBetweenTwoNamesTheEarlierDoseAndTheScreensTime() {
        let now = d(10, 17)
        let result = confirm(interval: 360, max: nil, doses: [d(10, 8), d(10, 16)], now: now, at: d(10, 10))
        XCTAssertEqual(result?.title,
                       String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 360)))
        XCTAssertEqual(result?.message,
                       "Paracetamol\nLast dose at \(when(d(10, 8), now: now))\nIf you save, next dose not before \(when(d(10, 22), now: now))")
    }

    func testADoseLoggedAfterTheFactDropsAPassedNextTime() {
        let now = d(10, 17)
        let result = confirm(interval: 360, max: nil, doses: [d(10, 8)], now: now, at: d(10, 10))
        XCTAssertNotNil(result)
        XCTAssertEqual(lines(result?.message).count, 2)
        XCTAssertFalse(lines(result?.message).contains { $0.hasPrefix("If you save") })
    }

    func testABackDatedDoseOverTheMaximumNamesTheScreensTime() {
        let now = d(10, 21)
        let doses = [d(10, 0), d(10, 6), d(10, 20)]
        let result = confirm(interval: 360, max: 3, doses: doses, now: now, at: d(10, 12, 30))
        let before = schedule(interval: 360, max: 3, doses: doses, now: now)
        XCTAssertEqual(before.nextAllowed, d(11, 2))
        // Counted, the 12:30 dose moves the 24 hours on to 06:00.
        XCTAssertEqual(before.nextAllowed(adding: d(10, 12, 30)), d(11, 6))
        XCTAssertEqual(result?.title, String(format: "medication.alert_max_title_fmt".l, F.doseCount(4)))
        XCTAssertEqual(result?.message,
                       String(format: "medication.alert_max_message_fmt".l, "Paracetamol", 3,
                              when(d(11, 6), now: now)))
    }

    /// The three cases the rule was set on, in every language: 08:00 then
    /// 10:00 every 6 h names 16:00; 00:00 and 08:00 with at most 2, then
    /// 10:00, names 08:00 tomorrow; 00:00 and 07:00 with at most 3, then
    /// 08:00, reaches the maximum without passing it, so the interval variant
    /// names midnight, the time the maximum sets.
    func testTheAlertNamesTheTimeAfterTheSaveInEveryLanguage() {
        let now = d(10, 10)
        for code in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(code)
            let interval = confirm(interval: 360, max: nil, doses: [d(10, 8)], now: now, at: now)
            XCTAssertEqual(lines(interval?.message).last,
                           lines(String(format: "medication.alert_before_message_fmt".l, "Paracetamol",
                                        when(d(10, 8), now: now), when(d(10, 16), now: now))).last, code)
            // The clock follows the app's language: 12-hour in en and es.
            XCTAssertTrue(lines(interval?.message).last?.contains(code == "ru" ? "16:00" : "4:00") == true,
                          "\(code): \(interval?.message ?? "nil")")

            let daily = confirm(interval: 360, max: 2, doses: [d(10, 0), d(10, 8)], now: now, at: now)
            XCTAssertEqual(lines(daily?.message).last,
                           lines(String(format: "medication.alert_max_message_fmt".l, "Paracetamol", 2,
                                        when(d(11, 8), now: now))).last, code)
            XCTAssertTrue(lines(daily?.message).last?.contains("8:00") == true,
                          "\(code): \(daily?.message ?? "nil")")
            XCTAssertTrue(lines(daily?.message).last?.contains(when(d(11, 8), now: now)) == true, code)

            let reached = confirm(interval: 360, max: 3, doses: [d(10, 0), d(10, 7)], now: d(10, 9), at: d(10, 8))
            XCTAssertEqual(reached?.title,
                           String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 360)), code)
            XCTAssertEqual(reached?.message,
                           String(format: "medication.alert_before_message_fmt".l, "Paracetamol",
                                  when(d(10, 7), now: d(10, 9)), when(d(11, 0), now: d(10, 9))), code)
        }
    }

    /// The time after the save is never earlier than the one before it, so
    /// the alert can only err towards waiting.
    func testTheTimeAfterTheSaveIsNeverEarlierThanBefore() {
        let now = d(10, 23)
        let cases: [(interval: Int, max: Int?, doses: [Date], at: Date)] = [
            (360, nil, [d(10, 8)], d(10, 10)),
            (360, nil, [d(10, 8), d(10, 16)], d(10, 10)),
            (360, 4, [d(10, 8), d(10, 2), d(9, 20), d(9, 14)], d(10, 10)),
            (240, 3, [d(10, 0), d(10, 4), d(10, 8)], d(10, 12)),
            (360, 3, [d(10, 0), d(10, 6), d(10, 20)], d(10, 12, 30)),
            (480, 2, [d(10, 22)], d(10, 21)),
        ]
        for item in cases {
            let before = schedule(interval: item.interval, max: item.max, doses: item.doses, now: now)
            let after = before.nextAllowed(adding: item.at)
            XCTAssertNotNil(after)
            if let pre = before.nextAllowed, let after { XCTAssertGreaterThanOrEqual(after, pre) }
            if case .earlier(_, let intervalEnds) = before.check(item.at).neighbour, let after {
                XCTAssertGreaterThanOrEqual(after, intervalEnds)
            }
        }
    }

    /// The drop rule removes the last line, so the time must be the last
    /// line in every language.
    func testTheNextTimeIsTheLastLineInEveryLanguage() {
        for code in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(code)
            for key in ["medication.alert_before_message_fmt", "medication.alert_max_message_fmt"] {
                let parts = key.l.components(separatedBy: "\n")
                XCTAssertTrue(parts.last?.contains("%3$@") == true, "\(code) \(key): \(key.l)")
                XCTAssertFalse(parts.dropLast().contains { $0.contains("%3$@") }, "\(code) \(key): \(key.l)")
            }
        }
    }

    // MARK: On time

    func testADoseExactlyOneIntervalLaterNeedsNothing() {
        let now = d(10, 16)
        XCTAssertNil(confirm(interval: 360, max: nil, doses: [d(10, 8)], now: now, at: d(10, 14)))
    }

    func testADoseSevenHoursLaterNeedsNothing() {
        let now = d(10, 16)
        XCTAssertNil(confirm(interval: 360, max: nil, doses: [d(10, 8)], now: now, at: d(10, 15)))
    }

    func testTheFirstDoseNeedsNothing() {
        let now = d(10, 10)
        XCTAssertNil(confirm(interval: 360, max: 4, doses: [], now: now, at: now))
    }

    // MARK: Through the medicine

    private func medicine(_ context: ModelContext, doses: [Date] = []) -> Medicine {
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
        context.insert(medicine)
        for time in doses {
            context.insert(CustomEvent.dose(of: medicine, at: time))
        }
        return medicine
    }

    func testAnotherMedicinesDoseDoesNotCount() throws {
        let context = try makeContext()
        let ours = medicine(context)
        let other = medicine(context, doses: [d(10, 9)])
        XCTAssertNil(ours.confirmation(for: d(10, 10), now: d(10, 12)))
        // Control: had the dose counted, it would ask.
        XCTAssertNotNil(other.confirmation(for: d(10, 10), now: d(10, 12)))
    }

    func testAFreeTextEventWithTheSameNameDoesNotCount() throws {
        let context = try makeContext()
        let ours = medicine(context)
        let free = CustomEvent(time: d(10, 9), type: .medication)
        free.medicationName = ours.name
        context.insert(free)
        XCTAssertNil(ours.confirmation(for: d(10, 10), now: d(10, 12)))
        // Control: a linked dose at the same time, on a twin of the name, asks.
        let twin = medicine(context, doses: [d(10, 9)])
        XCTAssertNotNil(twin.confirmation(for: d(10, 10), now: d(10, 12)))
    }

    func testAnEndedCourseNeverAsks() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8)])
        ours.endedAt = d(10, 9)
        XCTAssertNil(ours.confirmation(for: d(10, 9), now: d(10, 12)))
    }

    func testEditingADoseAtItsOwnTimeNeverAsks() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8), d(10, 9)])
        let edited = try XCTUnwrap(ours.doseEvents.first { $0.time == d(10, 9) })
        XCTAssertNil(ours.confirmation(for: edited.time, now: d(10, 12), editing: edited,
                                        loggedTime: edited.time))
    }

    func testAnEditMovedOnAnotherDeviceStillComparesWithTheSheetsTime() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8), d(10, 9)])
        let edited = try XCTUnwrap(ours.doseEvents.first { $0.time == d(10, 9) })
        edited.time = d(10, 9, 30) // moved elsewhere while the sheet was open
        XCTAssertNil(ours.confirmation(for: d(10, 9), now: d(10, 12), editing: edited,
                                       loggedTime: d(10, 9)))
    }

    func testMovingADoseLeavesTheEditedOneOutAndNamesTheOther() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8), d(10, 9)])
        let edited = try XCTUnwrap(ours.doseEvents.first { $0.time == d(10, 9) })
        let now = d(10, 12)
        let result = ours.confirmation(for: d(10, 9, 30), now: now, editing: edited,
                                       loggedTime: edited.time)
        // Unlike the pure tests, this path uses the device calendar.
        let current = Calendar.current
        XCTAssertEqual(result?.title,
                       String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 360)))
        XCTAssertEqual(result?.message,
                       String(format: "medication.alert_before_message_fmt".l, "Paracetamol",
                              F.when(d(10, 8), now: now, calendar: current),
                              F.when(d(10, 15, 30), now: now, calendar: current)))
    }

    func testANewDoseTwoHoursAfterALinkedDoseAsks() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8)])
        let result = try XCTUnwrap(ours.confirmation(for: d(10, 10), now: d(10, 12)))
        XCTAssertEqual(result.title,
                       String(format: "medication.alert_before_title_fmt".l, F.duration(minutes: 360)))
        XCTAssertTrue(result.message.hasPrefix("Paracetamol\n"), result.message)
    }

    func testTheAlertsTimeIsTheOneTheScreenShowsAfterTheSave() throws {
        let context = try makeContext()
        let ours = medicine(context, doses: [d(10, 8)])
        let now = d(10, 10)
        let result = try XCTUnwrap(ours.confirmation(for: now, now: now))
        context.insert(CustomEvent.dose(of: ours, at: now))
        guard case .waiting(_, let until) = ours.status(now: now) else {
            return XCTFail("expected a waiting status, got \(ours.status(now: now))")
        }
        XCTAssertEqual(until, d(10, 16))
        XCTAssertTrue(result.message.hasSuffix(F.when(until, now: now, calendar: .current)), result.message)
    }
}

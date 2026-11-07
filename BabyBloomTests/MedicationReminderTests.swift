import XCTest
import SwiftData
import UserNotifications
@testable import BabyBloom

/// The medication reminder: which requests the plan wants, their words, and
/// the reconcile that makes the notification centre hold exactly those.
@MainActor
final class MedicationReminderTests: XCTestCase {

    private typealias F = MedicationFormat
    private typealias Plan = MedicationReminderPlan

    private var previousLanguage: SupportedLanguage = .fallback
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() async throws {
        try await super.setUp()
        previousLanguage = LocalizationManager.shared.language
        LocalizationManager.shared.setLanguage("en")
        suiteName = "MedicationReminderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
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

    private func course(_ id: UUID = UUID(), name: String = "Paracetamol", on: Bool = true,
                        ended: Bool = false, interval: Int = 360, max: Int? = nil,
                        doses: [Date], now: Date) -> Plan.Course {
        Plan.Course(id: id, name: name, isOn: on, isEnded: ended,
                    schedule: MedicineSchedule(intervalMinutes: interval, maxDosesPer24h: max,
                                               doseTimes: doses, now: now))
    }

    // MARK: The plan

    func testASwitchedOnCourseWantsOneRequestAtItsNextAllowedTime() {
        let id = UUID()
        let reminders = Plan.reminders(for: [course(id, doses: [d(10, 2), d(10, 8)], now: d(10, 10))])
        XCTAssertEqual(reminders, [Plan.Reminder(identifier: "bb.med.\(id.uuidString)", name: "Paracetamol",
                                                 lastDose: d(10, 8), fireDate: d(10, 14))])
    }

    func testTheMaximumSetsTheTimeWhenItEndsAfterTheInterval() {
        let reminders = Plan.reminders(for: [course(max: 2, doses: [d(10, 0), d(10, 8)], now: d(10, 10))])
        XCTAssertEqual(reminders.map(\.fireDate), [d(11, 0)])
        XCTAssertEqual(reminders.map(\.lastDose), [d(10, 8)])
    }

    func testNothingIsWantedWithTheSwitchOff() {
        XCTAssertTrue(Plan.reminders(for: [course(on: false, doses: [d(10, 8)], now: d(10, 10))]).isEmpty)
    }

    func testNothingIsWantedForAnEndedCourse() {
        XCTAssertTrue(Plan.reminders(for: [course(ended: true, doses: [d(10, 8)], now: d(10, 10))]).isEmpty)
    }

    func testNothingIsWantedBeforeTheFirstDose() {
        XCTAssertTrue(Plan.reminders(for: [course(doses: [], now: d(10, 10))]).isEmpty)
    }

    func testNothingIsWantedOnceTheTimeHasCome() {
        XCTAssertTrue(Plan.reminders(for: [course(doses: [d(10, 8)], now: d(10, 14))]).isEmpty, "exactly at the time")
        XCTAssertTrue(Plan.reminders(for: [course(doses: [d(10, 8)], now: d(10, 15))]).isEmpty, "after it")
    }

    func testCoursesAreIndependent() {
        let a = UUID(), b = UUID(), c = UUID()
        let reminders = Plan.reminders(for: [
            course(a, name: "Paracetamol", doses: [d(10, 8)], now: d(10, 10)),
            course(b, name: "Ibuprofen", on: false, interval: 480, doses: [d(10, 9)], now: d(10, 10)),
            course(c, name: "Vitamin D", interval: 1440, doses: [d(9, 20)], now: d(10, 10)),
        ])
        XCTAssertEqual(reminders.map(\.identifier), [Plan.identifier(for: a), Plan.identifier(for: c)])
        XCTAssertEqual(reminders.map(\.fireDate), [d(10, 14), d(10, 20)])
    }

    func testStaleNamesOnlyMedicationRequestsThePlanDoesNotWant() {
        let id = UUID()
        let wanted = Plan.reminders(for: [course(id, doses: [d(10, 8)], now: d(10, 10))])
        let pending = [Plan.identifier(for: id), "bb.med.\(UUID().uuidString)",
                       "bb.engage.weekly_summary", "bb.feeding.reminder"]
        XCTAssertEqual(Plan.stale(pending: pending, wanted: wanted), [pending[1]])
        XCTAssertEqual(Plan.stale(pending: pending, wanted: []), Array(pending.prefix(2)))
    }

    func testTheSwitchKeyIsPerMedication() {
        let a = UUID(), b = UUID()
        XCTAssertNotEqual(Plan.switchKey(for: a), Plan.switchKey(for: b))
        XCTAssertFalse(defaults.bool(forKey: Plan.switchKey(for: a)), "off until turned on")
    }

    // MARK: The words

    func testTheBodyStatesTheTimeSinceTheDoseItCountsFrom() {
        let words = F.reminder(name: "Paracetamol", lastDose: d(10, 8), fireDate: d(10, 14), calendar: cal)
        XCTAssertEqual(words.title, "Paracetamol")
        XCTAssertEqual(words.body,
                       "It has been 6\u{00A0}h since the last logged dose (\(F.when(d(10, 8), now: d(10, 14), calendar: cal))).")
    }

    /// Scheduled at 23:00 for 04:00, a 22:00 dose reads as yesterday's.
    func testTheDayWordIsCountedAgainstTheMomentItFires() {
        let words = F.reminder(name: "Paracetamol", lastDose: d(10, 22), fireDate: d(11, 4), calendar: cal)
        XCTAssertTrue(words.body.contains(F.when(d(10, 22), now: d(11, 4), calendar: cal)), words.body)
        XCTAssertTrue(words.body.contains("yesterday"), words.body)
    }

    func testAMaximumThatHoldsTheReminderBackStatesTheRealTimeSince() {
        let words = F.reminder(name: "Paracetamol", lastDose: d(10, 14), fireDate: d(10, 22, 30), calendar: cal)
        XCTAssertTrue(words.body.contains(F.duration(minutes: 510)), words.body)
    }

    /// The clocks go back at 03:00 on 25 Oct 2026 in Berlin: a 01:30 dose
    /// every 6 h fires six real hours later, at 06:30 on the wall clock.
    func testTheNightTheClocksGoBackCountsRealHours() {
        let dose = cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 1, minute: 30))!
        let fire = try! XCTUnwrap(Plan.reminders(for: [course(doses: [dose], now: dose)]).first?.fireDate)
        XCTAssertEqual(fire.timeIntervalSince(dose), 6 * 3600)
        XCTAssertEqual(cal.component(.hour, from: fire), 6)
        let words = F.reminder(name: "Paracetamol", lastDose: dose, fireDate: fire, calendar: cal)
        XCTAssertTrue(words.body.contains(F.duration(minutes: 360)), words.body)
        XCTAssertTrue(words.body.contains(F.when(dose, now: fire, calendar: cal)), words.body)
        XCTAssertFalse(words.body.contains("yesterday"), words.body)
    }

    /// Dose times carry seconds; the time since rounds to the nearest minute.
    func testTheTimeSinceRoundsToTheMinute() {
        let words = F.reminder(name: "Paracetamol", lastDose: d(10, 14).addingTimeInterval(40),
                               fireDate: d(10, 22, 30).addingTimeInterval(10), calendar: cal)
        XCTAssertTrue(words.body.contains(F.duration(minutes: 510)), words.body)
    }

    func testTheWordsInEveryLanguageHaveNoEmojiAndNoLeftoverFormat() {
        for code in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(code)
            let words = F.reminder(name: "Ибупрофен 100%", lastDose: d(10, 8), fireDate: d(10, 14), calendar: cal)
            XCTAssertEqual(words.title, "Ибупрофен 100%", code)
            XCTAssertEqual(words.body,
                           String(format: "notification.medication_body_fmt".l, F.duration(minutes: 360),
                                  F.when(d(10, 8), now: d(10, 14), calendar: cal)), code)
            XCTAssertTrue(words.body.contains(F.duration(minutes: 360)), "\(code): \(words.body)")
            XCTAssertFalse(words.body.contains("%"), "\(code): \(words.body)")
            let emoji = (words.title + words.body).unicodeScalars.filter(\.properties.isEmojiPresentation)
            XCTAssertTrue(emoji.isEmpty, "\(code): \(words.body)")
        }
    }

    // MARK: The reconcile

    func testTheReconcileRemovesAStaleRequestAndAddsTheWantedOne() async {
        let id = UUID()
        let gone = "bb.med.\(UUID().uuidString)"
        let center = FakeReminderCenter(pending: [gone, "bb.engage.weekly_summary"])
        let sync = MedicationReminderSync(center: center, defaults: defaults)
        let wanted = Plan.reminders(for: [course(id, doses: [d(10, 8)], now: d(10, 10))])

        await sync.apply(wanted, now: d(10, 10))

        let words = F.reminder(name: "Paracetamol", lastDose: d(10, 8), fireDate: d(10, 14))
        let removed = await center.removed
        let added = await center.added
        let pending = await center.pending
        XCTAssertEqual(removed, [gone])
        XCTAssertEqual(added, [ScheduledReminder(identifier: Plan.identifier(for: id), title: words.title,
                                                 body: words.body, delay: 4 * 3600)])
        XCTAssertEqual(Set(pending), ["bb.engage.weekly_summary", Plan.identifier(for: id)])
    }

    func testSwitchingOffLeavesNoMedicationRequest() async {
        let id = UUID()
        let center = FakeReminderCenter(pending: [Plan.identifier(for: id)])
        let sync = MedicationReminderSync(center: center, defaults: defaults)
        let wanted = Plan.reminders(for: [course(id, on: false, doses: [d(10, 8)], now: d(10, 10))])

        await sync.apply(wanted, now: d(10, 10))

        let removed = await center.removed
        let added = await center.added
        XCTAssertEqual(removed, [Plan.identifier(for: id)])
        XCTAssertTrue(added.isEmpty)
    }

    func testAPassWithNothingToTakeDownRemovesNothing() async {
        let center = FakeReminderCenter(pending: ["bb.feeding.reminder"])
        let sync = MedicationReminderSync(center: center, defaults: defaults)

        await sync.apply([], now: d(10, 10))

        let removeCalls = await center.removeCalls
        let pending = await center.pending
        XCTAssertEqual(removeCalls, 0)
        XCTAssertEqual(pending, ["bb.feeding.reminder"])
    }

    func testCoursesReadEachSwitchFromThisDevicesDefaults() throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        let on = Medicine(name: "Paracetamol", intervalMinutes: 360)
        let off = Medicine(name: "Ibuprofen", intervalMinutes: 480)
        let ended = Medicine(name: "Amoxicillin", intervalMinutes: 480)
        ended.endedAt = d(10, 9)
        for medicine in [on, off, ended] {
            context.insert(medicine)
            context.insert(CustomEvent.dose(of: medicine, at: d(10, 8)))
        }
        defaults.set(true, forKey: Plan.switchKey(for: on.id))
        defaults.set(true, forKey: Plan.switchKey(for: ended.id))

        let courses = MedicationReminderSync.courses(in: context, now: d(10, 10), defaults: defaults)

        XCTAssertEqual(Set(courses.filter(\.isOn).map(\.id)), [on.id, ended.id])
        XCTAssertEqual(Plan.reminders(for: courses).map(\.identifier), [Plan.identifier(for: on.id)])
        XCTAssertEqual(Plan.reminders(for: courses).map(\.fireDate), [d(10, 14)])
    }

    /// The wiring the design rests on: a save in the store starts a pass, with
    /// no call from the surface that saved.
    func testASaveInTheStoreStartsAPass() async throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        let center = FakeReminderCenter(pending: [])
        let sync = MedicationReminderSync(center: center, defaults: defaults, context: { context })
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
        context.insert(medicine)
        defaults.set(true, forKey: Plan.switchKey(for: medicine.id))
        sync.start()
        // The start pass sees no dose and wants nothing.
        try await Task.sleep(for: .milliseconds(300))
        let beforeSave = await center.added
        XCTAssertTrue(beforeSave.isEmpty)

        context.insert(CustomEvent.dose(of: medicine, at: AppClock.now.addingTimeInterval(-3600)))
        try context.save()

        var added: [ScheduledReminder] = []
        for _ in 0..<40 where added.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
            added = await center.added
        }
        XCTAssertEqual(added.map(\.identifier), [Plan.identifier(for: medicine.id)])
        XCTAssertEqual(added.first?.delay ?? 0, 5 * 3600, accuracy: 5)
    }

    // MARK: Permission

    func testThePermissionStatesTheSwitchDraws() {
        XCTAssertEqual(NotificationPermission.state(of: .notDetermined), .notAsked)
        XCTAssertEqual(NotificationPermission.state(of: .denied), .denied)
        for status: UNAuthorizationStatus in [.authorized, .provisional, .ephemeral] {
            XCTAssertEqual(NotificationPermission.state(of: status), .allowed)
        }
    }
}

/// Holds pending ids the way the notification centre does: an add with a
/// known id replaces it.
private actor FakeReminderCenter: ReminderCenter {
    private(set) var pending: [String]
    private(set) var added: [ScheduledReminder] = []
    private(set) var removed: [String] = []
    private(set) var removeCalls = 0

    init(pending: [String]) {
        self.pending = pending
    }

    func pendingIdentifiers() -> [String] { pending }

    func add(_ reminder: ScheduledReminder) {
        added.append(reminder)
        if !pending.contains(reminder.identifier) { pending.append(reminder.identifier) }
    }

    func remove(_ identifiers: [String]) {
        removeCalls += 1
        removed += identifiers
        pending.removeAll { identifiers.contains($0) }
    }
}

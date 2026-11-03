import XCTest
import SwiftData
@testable import BabyBloom

/// Which medications Home's card shows.
@MainActor
final class MedicationHomeTests: XCTestCase {

    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func d(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)])
        context = ModelContext(container)
    }

    private func medicine(_ name: String, doses: [Date], endedAt: Date? = nil) -> Medicine {
        let medicine = Medicine(name: name, intervalMinutes: 360)
        medicine.endedAt = endedAt
        context.insert(medicine)
        for time in doses { context.insert(CustomEvent.dose(of: medicine, at: time)) }
        return medicine
    }

    func testARunningCourseWithADoseUnderADayOldShows() {
        let paracetamol = medicine("Paracetamol", doses: [d(10, 8)])
        XCTAssertEqual(Medicine.onHome([paracetamol], now: d(10, 10)).map(\.name), ["Paracetamol"])
    }

    func testTheCardKeepsItsMedicationAfterTheInterval() {
        let paracetamol = medicine("Paracetamol", doses: [d(10, 8)])
        XCTAssertEqual(Medicine.onHome([paracetamol], now: d(10, 20)).count, 1, "the 6 h interval has passed")
    }

    func testADoseADayOldLeavesHome() {
        let paracetamol = medicine("Paracetamol", doses: [d(10, 8)])
        XCTAssertEqual(Medicine.onHome([paracetamol], now: d(11, 7, 59)).count, 1)
        XCTAssertTrue(Medicine.onHome([paracetamol], now: d(11, 8)).isEmpty, "exactly a day")
    }

    func testACourseWithNoDoseYetDoesNotShow() {
        XCTAssertTrue(Medicine.onHome([medicine("Ibuprofen", doses: [])], now: d(10, 10)).isEmpty)
    }

    func testAnEndedCourseDoesNotShow() {
        let ended = medicine("Amoxicillin", doses: [d(10, 8)], endedAt: d(10, 9))
        XCTAssertTrue(Medicine.onHome([ended], now: d(10, 10)).isEmpty)
    }

    /// A dose later than now (a skewed clock elsewhere) has not happened.
    func testAFutureDoseDoesNotPutACourseOnHome() {
        let skewed = medicine("Paracetamol", doses: [d(9, 6), d(10, 12)])
        XCTAssertTrue(Medicine.onHome([skewed], now: d(10, 10)).isEmpty)
    }

    func testTwoCoursesShowByName() {
        let shown = Medicine.onHome([medicine("paracetamol", doses: [d(10, 8)]),
                                     medicine("Ibuprofen", doses: [d(10, 9)]),
                                     medicine("Vitamin D", doses: [d(9, 8)])],
                                    now: d(10, 10))
        XCTAssertEqual(shown.map(\.name), ["Ibuprofen", "paracetamol"])
    }
}

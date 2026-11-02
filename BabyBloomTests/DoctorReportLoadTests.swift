import XCTest
import SwiftData
@testable import BabyBloom

/// `Input.load` is the share button's only way to the store, so it must read
/// exactly the rows `Input.window(periodStart:)` promises.
@MainActor
final class DoctorReportLoadTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private var periodStart: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 8))!
    }

    private func hours(_ offset: Double) -> Date { periodStart.addingTimeInterval(offset * 3600) }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)])
        return (container, ModelContext(container))
    }

    func testTheWindowReadsFeedsAndDiapersFromTheStartAndSleepsFrom36HoursBefore() {
        let window = DoctorReportSummary.Input.window(periodStart: periodStart)
        XCTAssertEqual(window.from, periodStart)
        XCTAssertEqual(window.sleepsFrom, hours(-36))
    }

    func testLoadReturnsOnlyTheRowsTheWindowPromises() throws {
        let (container, context) = try makeContext()

        let baby = Baby(name: "Mia", birthDate: hours(-24 * 40), gender: .female, feedingType: .breast)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        for offset in [-1.0, 0, 1] {
            context.insert(FeedingEntry(startTime: hours(offset), type: .breast))
            context.insert(DiaperEntry(time: hours(offset), type: .wet))
        }

        // A night that crossed the start counts by its part inside; one from
        // 40 h back is beyond any sleep a baby has, so it is not read.
        let crossing = SleepEntry(startTime: hours(-10), type: .night)
        crossing.endTime = hours(1)
        let stale = SleepEntry(startTime: hours(-40), type: .night)
        stale.endTime = hours(-39)
        context.insert(crossing)
        context.insert(stale)

        // Growth is read whole: the change base may be older than the window.
        for offset in [-24.0 * 30, -24, 48] {
            context.insert(GrowthEntry(date: hours(offset), weightKg: 4.0))
        }
        try context.save()

        let input = DoctorReportSummary.Input.load(baby: baby, periodStart: periodStart, in: context)

        XCTAssertEqual(input.feeds.map(\.start).sorted(), [hours(0), hours(1)])
        XCTAssertEqual(input.diapers.map(\.time).sorted(), [hours(0), hours(1)])
        XCTAssertEqual(input.sleeps.map(\.start), [hours(-10)])
        XCTAssertEqual(input.sleeps.first?.end, hours(1))
        XCTAssertEqual(input.growth.map(\.date).sorted(), [hours(-24 * 30), hours(-24), hours(48)])
        XCTAssertEqual(input.birthDate, baby.birthDate)
        XCTAssertEqual(input.birthWeightKg, 3.4)
        XCTAssertFalse(input.isMale)
        // Held to the end: a context does not keep its store alive.
        withExtendedLifetime(container) {}
    }
}

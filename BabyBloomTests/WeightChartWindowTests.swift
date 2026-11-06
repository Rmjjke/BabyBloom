import XCTest
@testable import BabyBloom

/// The x window the Growth screen's weight chart and the report's chart share.
///
/// Two drawings read it, so a slipped bound shows the parent one stretch of
/// the corridor and the doctor another. Berlin's calendar, as the report's
/// tests use: the window counts whole calendar days.
final class WeightChartWindowTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private var birth: Date { date(2026, 6, 1, hour: 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func age(_ days: Int, from base: Date? = nil) -> Date {
        calendar.date(byAdding: .day, value: days, to: base ?? birth)!
    }

    private func window(_ dates: [Date], from base: Date? = nil) -> WeightChartWindow? {
        WeightChartWindow(measurements: dates.map { WeightMeasurement(date: $0, weightKg: 4) },
                          correctedBirthDate: base ?? birth, calendar: calendar)
    }

    // MARK: - Width

    /// One weighing is four weeks wide, centred on it, with ages as dates.
    func testOneWeighingOpensFourWeeksAroundIt() throws {
        let window = try XCTUnwrap(window([age(42)]))
        XCTAssertEqual(window.lowAgeDays, 28)
        XCTAssertEqual(window.highAgeDays, 56)
        XCTAssertEqual(window.domain, age(28)...age(56))
        XCTAssertEqual(window.date(atAgeDays: 10), age(10))
    }

    /// A weighing on the due date never opens empty space before it: no band
    /// can be drawn there.
    func testAWeighingAtBirthStartsTheWindow() throws {
        let window = try XCTUnwrap(window([age(0)]))
        XCTAssertEqual(window.lowAgeDays, 0)
        XCTAssertEqual(window.highAgeDays, 28)
    }

    /// Weighings before the due date carry negative ages and stay on the axis.
    func testWeighingsBeforeTheDueDateStayOnTheAxis() throws {
        let window = try XCTUnwrap(window([age(-20), age(-10)]))
        XCTAssertEqual(window.lowAgeDays, -20)
        XCTAssertEqual(window.highAgeDays, 8)
    }

    /// A history longer than four weeks spans exactly its weighings.
    func testALongHistorySpansItsWeighings() throws {
        let window = try XCTUnwrap(window([age(3), age(40), age(90)]))
        XCTAssertEqual(window.lowAgeDays, 3)
        XCTAssertEqual(window.highAgeDays, 90)
        XCTAssertEqual(window.spanDays, 87)
    }

    // MARK: - Edges

    /// An afternoon weighing on the last day is past that day's whole age:
    /// the window takes one more day so the point never sits outside it.
    func testAnAfternoonWeighingOnTheLastDayStaysInside() throws {
        let morningBirth = date(2026, 6, 1, hour: 8)
        let last = age(40, from: morningBirth).addingTimeInterval(9 * 3600)
        let window = try XCTUnwrap(window([morningBirth, last], from: morningBirth))
        XCTAssertEqual(window.highAgeDays, 41)
        XCTAssertGreaterThanOrEqual(window.domain.upperBound, last)
        XCTAssertEqual(window.domain.lowerBound, morningBirth)
    }

    /// A weighing earlier in the day than the corrected birth's hour widens the
    /// domain to it rather than falling off the start.
    func testAnEarlyWeighingOnTheFirstDayWidensTheDomain() throws {
        let first = age(-1).addingTimeInterval(-3 * 3600)
        let window = try XCTUnwrap(window([first, age(30)]))
        XCTAssertEqual(window.lowAgeDays, -1)
        XCTAssertEqual(window.domain.lowerBound, first)
    }

    func testNoWeighingHasNoWindow() {
        XCTAssertNil(window([]))
    }
}

import XCTest
@testable import BabyBloom

/// What the report's weight-for-age chart draws, before any drawing: when it
/// exists, the curves across its window, the y axis and the month labels.
///
/// A chart in a document for the doctor that shows curves past the tables, or
/// a point clipped off the axis, says something false about the baby; these
/// pin the rules that keep it from doing so.
final class WeightForAgeChartTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private var birth: Date { date(2026, 6, 1) }

    /// Weighings at the given ages, each on the girls' median.
    private func weighings(_ ages: [Int], from base: Date) -> [WeightMeasurement] {
        ages.map { days in
            let clamped = min(max(days, 0), WHOGrowthStandard.maxAgeDays)
            return WeightMeasurement(date: calendar.date(byAdding: .day, value: days, to: base)!,
                                     weightKg: WHOGrowthStandard.weight(atZ: 0, ageDays: clamped, isMale: false)!)
        }
    }

    private func makeChart(_ ages: [Int], from base: Date? = nil, isMale: Bool = false) -> WeightForAgeChart? {
        WeightForAgeChart(weighings: weighings(ages, from: base ?? birth), correctedBirthDate: base ?? birth,
                          isMale: isMale, calendar: calendar)
    }

    // MARK: - When it exists

    /// One weighing is a dot, not a line: no chart.
    func testOneWeighingHasNoChart() {
        XCTAssertNil(makeChart([42]))
        XCTAssertNotNil(makeChart([42, 56]))
    }

    /// One weighing logged twice at the same moment is still one dot.
    func testTwoWeighingsAtOneMomentHaveNoChart() {
        XCTAssertNil(makeChart([42, 42]))
        XCTAssertNotNil(makeChart([42, 42, 56]))
    }

    /// A window wholly before the due date, or wholly past the tables, has no
    /// curve to draw the child against.
    func testAWindowTheTablesDoNotCoverHasNoChart() {
        XCTAssertNil(makeChart([-40, -30]))
        XCTAssertNil(makeChart([800, 810]))
    }

    // MARK: - Curves

    /// The chart takes the Growth screen's window and samples the curves
    /// daily across it.
    func testTheCurvesCoverTheScreensWindowDaily() throws {
        let points = weighings([42, 56], from: birth)
        let chart = try XCTUnwrap(makeChart([42, 56]))
        XCTAssertEqual(chart.window, WeightChartWindow(measurements: points, correctedBirthDate: birth,
                                                       calendar: calendar))
        XCTAssertEqual(chart.curves, WHOCorridor.samples(fromAgeDays: 35, toAgeDays: 63, isMale: false,
                                                         maxSamples: 29))
        XCTAssertEqual(chart.curves.map(\.ageDays), Array(35...63))
        XCTAssertEqual(chart.points, points)
    }

    /// Two years of history still sample every day: the first weeks' bend
    /// would otherwise print as corners.
    func testALongHistoryIsSampledEveryDay() throws {
        XCTAssertEqual(try XCTUnwrap(makeChart([0, 700])).curves.map(\.ageDays), Array(0...700))
    }

    func testTheCurvesFollowTheBabysSex() throws {
        let boy = try XCTUnwrap(makeChart([42, 56], isMale: true))
        let girl = try XCTUnwrap(makeChart([42, 56]))
        XCTAssertEqual(boy.curves, WHOCorridor.samples(fromAgeDays: 35, toAgeDays: 63, isMale: true, maxSamples: 29))
        XCTAssertNotEqual(boy.curves, girl.curves)
    }

    /// Near two years the window runs past the tables; the curves stop at
    /// their last day, the axis does not.
    func testTheCurvesStopAtTheEndOfTheTables() throws {
        let chart = try XCTUnwrap(makeChart([715, 725]))
        XCTAssertEqual(chart.curves.last?.ageDays, WHOGrowthStandard.maxAgeDays)
        XCTAssertEqual(chart.window.highAgeDays, 734)
    }

    // MARK: - Y axis

    /// Whole kilograms around the curves and the child, so neither is
    /// clipped, labelled at both ends.
    func testTheAxisSpansTheCurvesAndTheChildInWholeKilograms() throws {
        for ages in [[42, 56], [0, 30], [0, 200], [0, 365], [100, 400], [0, 600], [300, 700], [0, 700]] {
            let chart = try XCTUnwrap(makeChart(ages), "\(ages)")
            let kgs = chart.curves.flatMap { [$0.low, $0.high] } + chart.points.map(\.weightKg)
            let lowest = try XCTUnwrap(kgs.min())
            let highest = try XCTUnwrap(kgs.max())
            let span = chart.kgRange.upperBound - chart.kgRange.lowerBound
            XCTAssertEqual(chart.kgRange.lowerBound, Int(lowest.rounded(.down)), "\(ages)")
            XCTAssertGreaterThanOrEqual(Double(chart.kgRange.upperBound), highest, "\(ages)")
            XCTAssertLessThan(Double(chart.kgRange.upperBound) - highest, 2, "\(ages)")
            XCTAssertEqual(span % chart.kgStep, 0, "\(ages): the top gridline goes unlabelled")
            XCTAssertEqual(chart.kgStep, span <= 6 ? 1 : 2, "\(ages)")
        }
    }

    /// Every kilogram on a short axis; every second one once it is long.
    func testTheStepWidensOnALongAxis() throws {
        XCTAssertEqual(try XCTUnwrap(makeChart([42, 56])).kgStep, 1)
        XCTAssertEqual(try XCTUnwrap(makeChart([0, 600])).kgStep, 2)
    }

    // MARK: - X labels

    /// The window's start, then whole months of corrected age.
    func testTheAxisIsLabelledAtItsStartAndByMonths() throws {
        XCTAssertEqual(try XCTUnwrap(makeChart([42, 56])).ticks, [date(2026, 7, 6), date(2026, 8, 1)])
    }

    /// Months count from the corrected birth each time: a baby due on the
    /// 31st turns two months on 31 March, not on the 28th.
    func testMonthsCountFromTheCorrectedBirthEachTime() throws {
        let due = date(2026, 1, 31)
        XCTAssertEqual(try XCTUnwrap(makeChart([40, 85], from: due)).ticks, [date(2026, 3, 12), date(2026, 3, 31)])
    }

    /// A month mark two days after the start would print over its label.
    func testAMonthTooNearTheStartIsNotLabelled() throws {
        XCTAssertEqual(try XCTUnwrap(makeChart([28, 60])).ticks, [date(2026, 6, 29)])
    }

    /// Twenty months fit no axis: every second one goes until six or fewer
    /// are left.
    func testALongAxisKeepsAtMostSixMonths() throws {
        let chart = try XCTUnwrap(makeChart([0, 700]))
        let months = [4, 8, 12, 16, 20].map { calendar.date(byAdding: .month, value: $0, to: birth)! }
        XCTAssertEqual(chart.ticks, [chart.window.domain.lowerBound] + months)
    }

    func testEveryLabelSitsInsideTheAxisOnAWholeMonth() throws {
        for ages in [[0, 30], [10, 95], [0, 200], [100, 400], [0, 700], [-20, 10]] {
            let chart = try XCTUnwrap(makeChart(ages), "\(ages)")
            let domain = chart.window.domain
            let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
            XCTAssertEqual(chart.ticks.first, domain.lowerBound, "\(ages)")
            XCTAssertEqual(chart.ticks, chart.ticks.sorted(), "\(ages)")
            XCTAssertEqual(Set(chart.ticks).count, chart.ticks.count, "\(ages)")
            let marks = chart.ticks.dropFirst()
            XCTAssertLessThanOrEqual(marks.count, WeightForAgeChart.maximumMonthMarks, "\(ages)")
            for mark in marks {
                XCTAssertTrue(domain.contains(mark), "\(ages): \(mark)")
                XCTAssertGreaterThanOrEqual(mark.timeIntervalSince(domain.lowerBound),
                                            span * WeightForAgeChart.minimumTickOffset, "\(ages): \(mark)")
                let months = calendar.dateComponents([.month], from: birth, to: mark).month ?? 0
                XCTAssertEqual(calendar.date(byAdding: .month, value: months, to: birth), mark, "\(ages): \(mark)")
            }
        }
    }
}

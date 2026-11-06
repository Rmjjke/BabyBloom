import Foundation

/// What the pediatrician report's weight-for-age chart draws, worked out with
/// no drawing in it: the Growth screen's x window, the child's weighings, the
/// WHO 3rd, 50th and 97th curves across that window, a y axis in whole
/// kilograms and the dates the x axis is labelled at.
///
/// It exists only when the report's weight percentile shows a figure and two
/// weighings or more are known at different times, so the PDF never prints an
/// empty chart, a single dot, or curves under a baby the tables do not cover.
struct WeightForAgeChart: Equatable {
    let window: WeightChartWindow
    /// Every known weighing, oldest first — the screen chart's points.
    let points: [WeightMeasurement]
    /// One sample a day across the window, clamped to the tables.
    let curves: [WHOCorridor.Sample]
    /// The y axis, whole kilograms, labelled every `kgStep`; it spans the
    /// curves and the child, so neither is clipped.
    let kgRange: ClosedRange<Int>
    let kgStep: Int
    /// Where the x axis may be labelled: the window's start, then whole months
    /// of corrected age — the doctor reads the axis by months. The renderer
    /// keeps the ones whose labels fit in its font.
    let ticks: [Date]

    /// More month labels than this crowd the 473 pt axis.
    static let maximumMonthMarks = 6
    /// A month mark nearer the start than this share of the axis would sit on
    /// the start's label.
    static let minimumTickOffset = 0.15

    /// - Parameter weighings: every known weighing, oldest first.
    init?(weighings: [WeightMeasurement], correctedBirthDate: Date, isMale: Bool,
          calendar: Calendar = .current) {
        // One weighing logged twice is still one dot.
        guard Set(weighings.map(\.date)).count >= 2,
              let window = WeightChartWindow(measurements: weighings, correctedBirthDate: correctedBirthDate,
                                             calendar: calendar)
        else { return nil }
        // Daily, as the tables are: the curves bend hardest in the first
        // weeks, and a coarser step draws that bend as corners.
        let curves = WHOCorridor.samples(fromAgeDays: window.lowAgeDays, toAgeDays: window.highAgeDays,
                                         isMale: isMale, maxSamples: window.spanDays + 1)
        guard curves.count >= 2 else { return nil }

        let kgs = curves.flatMap { [$0.low, $0.high] } + weighings.map(\.weightKg)
        let bottom = Int((kgs.min() ?? 0).rounded(.down))
        var top = Int((kgs.max() ?? 0).rounded(.up))
        if top == bottom { top += 1 }
        let step = top - bottom <= 6 ? 1 : 2
        // A label at both ends of the axis: an odd range at step 2 would
        // leave the top gridline unlabelled.
        if step == 2 && (top - bottom) % 2 == 1 { top += 1 }

        self.window = window
        points = weighings
        self.curves = curves
        kgRange = bottom...top
        kgStep = step
        ticks = [window.domain.lowerBound] + Self.monthMarks(in: window, calendar: calendar)
    }

    /// Whole months of corrected age inside the axis, counted from the corrected
    /// birth each time (never month after month), so a 31st does not drift to
    /// the 28th. Past `maximumMonthMarks` every second one goes, until they fit.
    private static func monthMarks(in window: WeightChartWindow, calendar: Calendar) -> [Date] {
        let start = window.domain.lowerBound
        let end = window.domain.upperBound
        let span = end.timeIntervalSince(start)
        var month = (calendar.dateComponents([.month], from: window.correctedBirthDate, to: start).month ?? 0) - 1
        var marks: [Date] = []
        while let mark = calendar.date(byAdding: .month, value: month, to: window.correctedBirthDate), mark <= end {
            if mark > start && mark.timeIntervalSince(start) >= span * minimumTickOffset { marks.append(mark) }
            month += 1
        }
        while marks.count > maximumMonthMarks {
            marks = stride(from: 0, to: marks.count, by: 2).map { marks[$0] }
        }
        return marks
    }
}

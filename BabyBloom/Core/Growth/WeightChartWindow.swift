import Foundation

/// The stretch of age a weight-for-age chart spans: whole days from the
/// corrected birth, and the dates that frame the x axis.
///
/// The Growth screen's chart and the pediatrician report's chart both take
/// their x window from here, so the report shows the same stretch of the
/// corridor the parent sees on the screen.
struct WeightChartWindow: Equatable {

    /// The narrowest window a chart will draw. A single weighing — which is
    /// every fresh install that answered the measurements page — would
    /// otherwise be a zero-width axis; four weeks around it shows the point
    /// sitting in the corridor, which is the whole reason one point is now
    /// worth charting at all.
    static let minimumSpanDays = 28

    let correctedBirthDate: Date
    /// The window's first and last age, in whole days from the corrected birth.
    let lowAgeDays: Int
    let highAgeDays: Int
    /// The x axis: the window's ages as dates, widened to the first and the
    /// last weighing so neither ever falls off an edge.
    let domain: ClosedRange<Date>
    private let calendar: Calendar

    var spanDays: Int { highAgeDays - lowAgeDays }

    func date(atAgeDays days: Int) -> Date {
        Self.date(atAgeDays: days, from: correctedBirthDate, calendar: calendar)
    }

    /// - Parameter measurements: oldest first. Empty → nil.
    init?(measurements: [WeightMeasurement], correctedBirthDate: Date, calendar: Calendar = .current) {
        guard let first = measurements.first, let last = measurements.last else { return nil }
        func date(_ days: Int) -> Date { Self.date(atAgeDays: days, from: correctedBirthDate, calendar: calendar) }
        let ages = measurements.map {
            calendar.dateComponents([.day], from: correctedBirthDate, to: $0.date).day ?? 0
        }
        var low = ages.min() ?? 0
        var high = ages.max() ?? 0
        // Whole days floor the time of day away; without the extra day the band
        // would stop short of an afternoon weighing on the last day.
        if date(high) < last.date { high += 1 }
        if high - low < Self.minimumSpanDays {
            // Centred on the data, then pulled back so the window never opens
            // empty space BEFORE the due date: no band can be drawn there and
            // no weighing sits there, so a fresh install's single birth point
            // would otherwise be pinned to the middle of a half-blank chart.
            // The floor is `min(low, 0)`, not 0 — a preterm baby's pre-due-date
            // weighings carry negative ages and must stay on the axis.
            let middle = (low + high) / 2
            low = max(middle - Self.minimumSpanDays / 2, min(low, 0))
            high = low + Self.minimumSpanDays
        }
        self.correctedBirthDate = correctedBirthDate
        self.calendar = calendar
        lowAgeDays = low
        highAgeDays = high
        domain = min(date(low), first.date)...max(date(high), last.date)
    }

    private static func date(atAgeDays days: Int, from base: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: base) ?? base
    }
}

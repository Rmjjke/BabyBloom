import Foundation

/// A single weighing, stripped of storage concerns.
///
/// The growth maths works on this rather than on `GrowthEntry` so it stays pure
/// — no SwiftData, no model context, trivially constructible in tests.
struct WeightMeasurement: Equatable {
    let date: Date
    let weightKg: Double
}

extension Array where Element == GrowthEntry {
    /// The entries that actually carry a weight, oldest first.
    ///
    /// Height-only and head-only entries are legitimate — the sheet lets a parent
    /// record just one — and they must not turn into gaps or zeroes downstream.
    var weightMeasurements: [WeightMeasurement] {
        compactMap { entry in
            guard let kg = entry.weightKg, kg > 0 else { return nil }
            return WeightMeasurement(date: entry.date, weightKg: kg)
        }
        .sorted { $0.date < $1.date }
    }

    /// The newest entry that actually carries a weight.
    ///
    /// Not `first` (or `last`) of the raw array: a height-only entry recorded
    /// this morning is newer than every weighing and says nothing about weight.
    /// Reading the raw newest entry produced both halves of the same defect —
    /// the Dashboard's stat card printing "0.00 kg" from a coalesced nil, and
    /// the Growth screen's percentile card disappearing entirely.
    var latestWeighing: WeightMeasurement? { weightMeasurements.last }
}

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
}

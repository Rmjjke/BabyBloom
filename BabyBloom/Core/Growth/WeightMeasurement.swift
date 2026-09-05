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
    /// How far ahead of this device's clock a weighing may be dated and still
    /// count as evidence.
    ///
    /// A day, and not zero, because a legitimate row can sit slightly ahead of
    /// `now`: `AddGrowthSheet` stamps the chosen DAY with the clock at the
    /// moment the sheet opened, and a row synced from a phone whose clock runs
    /// fast arrives ahead by that skew. A zero tolerance would drop those.
    static var futureDateTolerance: TimeInterval { 24 * 3600 }

    /// The entries that actually carry a weight and a date that has happened,
    /// oldest first.
    ///
    /// Height-only and head-only entries are legitimate — the sheet lets a parent
    /// record just one — and they must not turn into gaps or zeroes downstream.
    ///
    /// **A weighing dated into the future is not evidence about the present.**
    /// `AddGrowthSheet`'s picker cannot produce one any more, but rows entered
    /// before that bound existed, and rows synced from a device with a wrong
    /// clock, still arrive here — and they are worse than useless, because they
    /// sort to the end of the history and become the newest half of every pair.
    /// The reported case was a September-17 weighing entered in early
    /// September: it paired with the weighing before it over an interval that
    /// had not elapsed, understating the real gain by the days still to come —
    /// the one direction `WeightVelocity.measure` documents as unsafe, since it
    /// can turn a healthy `.within` into `.below` and fire `growthGainLow` off
    /// arithmetic about the future.
    ///
    /// Filtered at THIS boundary rather than in each analysis: every consumer
    /// of the growth engine reads its measurements through this accessor, so
    /// one rule covers the cards, the notifications and the Dashboard at once.
    ///
    /// **The row is not deleted, and not hidden from the parent** — the
    /// measurement history still lists it, which is what lets them notice the
    /// wrong date and fix it. It simply carries no verdict until its date
    /// arrives, at which point it starts counting at the next re-render —
    /// nothing schedules one, because this is recomputed per body evaluation
    /// rather than cached behind a timer.
    var weightMeasurements: [WeightMeasurement] {
        let horizon = Date().addingTimeInterval(Self.futureDateTolerance)
        return compactMap { entry in
            guard let kg = entry.weightKg, kg > 0, entry.date <= horizon else { return nil }
            return WeightMeasurement(date: entry.date, weightKg: kg)
        }
        .sorted { $0.date < $1.date }
    }

    /// The newest entry that actually carries a weight, and a date that has
    /// happened.
    ///
    /// Not `first` (or `last`) of the raw array: a height-only entry recorded
    /// this morning is newer than every weighing and says nothing about weight.
    /// Reading the raw newest entry produced both halves of the same defect —
    /// the Dashboard's stat card printing "0.00 kg" from a coalesced nil, and
    /// the Growth screen's percentile card disappearing entirely.
    ///
    /// It inherits `weightMeasurements`' future-date rule too, which matters
    /// because this is the Dashboard's weight headline and the figure the
    /// percentile card is scored from: a row dated next week must not become
    /// the number the whole screen is built on.
    var latestWeighing: WeightMeasurement? { weightMeasurements.last }
}

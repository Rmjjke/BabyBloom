import XCTest
@testable import BabyBloom

/// The sampler both corridor drawings read — the Growth screen's weight chart
/// and onboarding's showcase sketch.
///
/// Nothing asserts on a drawing, so these are the only checks standing between
/// a slipped bound and a picture that says something false about a baby. The
/// two clamps in particular are clinical rules wearing geometry: the band may
/// not start before age 0, and it may not continue past the tables.
final class WHOCorridorTests: XCTestCase {

    // MARK: - Shape

    /// The corridor can never cross itself, at any age the tables cover.
    func testTheBandKeepsItsOrderAcrossTheWholeTable() {
        for isMale in [true, false] {
            let samples = WHOCorridor.samples(fromAgeDays: 0,
                                              toAgeDays: WHOGrowthStandard.maxAgeDays,
                                              isMale: isMale, maxSamples: 200)
            XCTAssertFalse(samples.isEmpty)
            for sample in samples {
                XCTAssertLessThan(sample.low, sample.mid, "day \(sample.ageDays), male=\(isMale)")
                XCTAssertLessThan(sample.mid, sample.high, "day \(sample.ageDays), male=\(isMale)")
            }
        }
    }

    /// Babies get heavier. Every band in the corridor rises with age — a
    /// sampler that returned them out of order, or interpolated backwards,
    /// would draw a corridor sloping the wrong way and nothing else would
    /// notice.
    func testEveryBandRisesWithAge() {
        for isMale in [true, false] {
            let samples = WHOCorridor.samples(fromAgeDays: 0,
                                              toAgeDays: WHOGrowthStandard.maxAgeDays,
                                              isMale: isMale, maxSamples: 120)
            for (previous, next) in zip(samples, samples.dropFirst()) {
                XCTAssertLessThan(previous.ageDays, next.ageDays)
                XCTAssertLessThan(previous.low, next.low, "low, day \(next.ageDays)")
                XCTAssertLessThan(previous.mid, next.mid, "mid, day \(next.ageDays)")
                XCTAssertLessThan(previous.high, next.high, "high, day \(next.ageDays)")
            }
        }
    }

    /// The 3rd and 97th are the same bounds `percentileTint` calls `beyond`, so
    /// a point drawn outside the band and a reading labelled "< 3rd" describe
    /// one baby. Checked through the percentile function rather than restated.
    func testTheBandEdgesAreTheThirdAndNinetySeventhCentiles() throws {
        let sample = try XCTUnwrap(
            WHOCorridor.samples(fromAgeDays: 90, toAgeDays: 90, isMale: true).first)
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: sample.low, ageDays: 90, isMale: true), 3)
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: sample.mid, ageDays: 90, isMale: true), 50)
        XCTAssertEqual(WHOGrowthStandard.percentile(weightKg: sample.high, ageDays: 90, isMale: true), 97)
    }

    // MARK: - The two clamps

    /// A preterm baby weighed before its corrected due date carries a NEGATIVE
    /// corrected age. The band must start at 0 and leave those points bare,
    /// rather than extrapolate the term newborn curve backwards and paint "far
    /// below normal" under a baby in intensive care.
    func testTheBandNeverStartsBeforeAgeZero() {
        let samples = WHOCorridor.samples(fromAgeDays: -70, toAgeDays: 30, isMale: true)
        XCTAssertEqual(samples.first?.ageDays, 0)
        XCTAssertFalse(samples.contains { $0.ageDays < 0 })
    }

    /// Past two years the tables run out; the band stops rather than reusing
    /// the last row — the same refusal `percentile` makes.
    func testTheBandStopsAtTheEndOfTheTables() {
        let samples = WHOCorridor.samples(fromAgeDays: 700, toAgeDays: 900, isMale: false)
        XCTAssertEqual(samples.last?.ageDays, WHOGrowthStandard.maxAgeDays)
        XCTAssertFalse(samples.contains { $0.ageDays > WHOGrowthStandard.maxAgeDays })
    }

    /// A window entirely outside the tables draws nothing at all, on either
    /// side. Empty, not a single clamped sample — one sample would render as a
    /// degenerate sliver of band under points it says nothing about.
    func testAWindowOutsideTheTablesYieldsNothing() {
        XCTAssertTrue(WHOCorridor.samples(fromAgeDays: 800, toAgeDays: 900, isMale: true).isEmpty)
        XCTAssertTrue(WHOCorridor.samples(fromAgeDays: -100, toAgeDays: -1, isMale: true).isEmpty)
    }

    // MARK: - Sampling

    /// The far edge is where the eye lands, so it is always sampled even when
    /// the step does not divide the span.
    func testTheWindowsEdgesAreAlwaysSampled() {
        let samples = WHOCorridor.samples(fromAgeDays: 5, toAgeDays: 197, isMale: true, maxSamples: 7)
        XCTAssertEqual(samples.first?.ageDays, 5)
        XCTAssertEqual(samples.last?.ageDays, 197)
    }

    /// A two-year window must not cost two years of samples to draw.
    func testTheSampleCountIsBounded() {
        let samples = WHOCorridor.samples(fromAgeDays: 0, toAgeDays: 730, isMale: true, maxSamples: 40)
        XCTAssertLessThanOrEqual(samples.count, 41)
        XCTAssertGreaterThan(samples.count, 10)
    }

    /// A single day is a legitimate window — a chart with one weighing narrows
    /// to very little before its minimum span widens it.
    func testASingleDayWindowStillSamples() {
        let samples = WHOCorridor.samples(fromAgeDays: 42, toAgeDays: 42, isMale: false)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.ageDays, 42)
    }
}

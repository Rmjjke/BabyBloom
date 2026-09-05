import XCTest
@testable import BabyBloom

/// The capture brief's one hard requirement: nothing on the Growth screen may
/// render red, because the app ships in the Medical category and a red "below
/// normal" verdict in a storefront screenshot reads as a diagnosis.
///
/// That requirement is invisible in the fixture itself — it lives in six weights
/// and in the WHO tables they are scored against — so these tests are the only
/// thing standing between a tweaked figure and a red card going to review.
final class ShowcaseGrowthTests: XCTestCase {

    /// The fixture's weighings as the Growth screen sees them: dated back from
    /// today, exactly as `SeedScenario.seedShowcase` places them.
    private func measurements(now: Date) -> (birth: Date, points: [WeightMeasurement]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let birth = calendar.date(byAdding: .day, value: -SeedScenario.showcaseAgeDays, to: today)!
        let points = SeedScenario.showcaseWeighings.map { weighing in
            WeightMeasurement(
                date: calendar.date(byAdding: .day,
                                    value: -(SeedScenario.showcaseAgeDays - weighing.ageDays),
                                    to: today)!,
                weightKg: weighing.weightKg
            )
        }
        return (birth, points)
    }

    // MARK: - The percentile card

    func testLatestWeightIsNotInARedPercentileBand() {
        let (birth, points) = measurements(now: Date())
        let latest = points.last!
        let ageDays = Calendar.current.dateComponents([.day], from: birth, to: latest.date).day!

        let percentile = WHOGrowthStandard.percentile(weightKg: latest.weightKg,
                                                      ageDays: ageDays,
                                                      isMale: SeedScenario.showcaseIsMale)
        XCTAssertNotNil(percentile, "A weighing the tables cannot score renders the out-of-range card.")
        // `.beyond` is the tier the brief rules out; it is returned below the
        // 3rd centile. Asserting on the tier rather than on a number keeps this
        // test honest if the band edges are ever retuned.
        XCTAssertEqual(WHOGrowthStandard.percentileTint(percentile!), .typical,
                       "The 2-month weight must land in the typical tier, not at an edge and not beyond one.")
    }

    func testEveryWeighingIsScorableAndAboveTheThirdCentile() {
        let (birth, points) = measurements(now: Date())
        for point in points {
            let ageDays = Calendar.current.dateComponents([.day], from: birth, to: point.date).day!
            guard let percentile = WHOGrowthStandard.percentile(weightKg: point.weightKg,
                                                               ageDays: ageDays,
                                                               isMale: SeedScenario.showcaseIsMale) else {
                return XCTFail("Day \(ageDays) at \(point.weightKg) kg is outside the WHO tables.")
            }
            // The chart plots all six, so a single dip under the 3rd centile
            // would show even though only the latest drives the card.
            XCTAssertGreaterThanOrEqual(percentile, 3,
                                        "Day \(ageDays) sits at the \(percentile) centile.")
        }
    }

    // MARK: - The weight-gain card

    func testLatestGainSitsInsideTheReferenceBand() {
        let (birth, points) = measurements(now: Date())
        let reading = WeightVelocity.latest(measurements: points,
                                            correctedBirthDate: birth,
                                            isMale: SeedScenario.showcaseIsMale)
        XCTAssertEqual(reading?.band, .within,
                       "`.below` renders the card in the accent colour and reads as a warning.")
    }

    /// The brief proposed 4.80 kg at six weeks. This is why the fixture says
    /// 4.70 — and it fails the moment someone "restores" the brief's figure.
    func testTheBriefsOwnSixWeekWeightWouldHaveFallenBelowTheBand() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let birth = calendar.date(byAdding: .day, value: -SeedScenario.showcaseAgeDays, to: today)!
        let asBriefed = [
            WeightMeasurement(date: calendar.date(byAdding: .day, value: -20, to: today)!, weightKg: 4.80),
            WeightMeasurement(date: calendar.date(byAdding: .day, value: -2, to: today)!, weightKg: 5.20),
        ]
        let reading = WeightVelocity.latest(measurements: asBriefed,
                                            correctedBirthDate: birth,
                                            isMale: SeedScenario.showcaseIsMale)
        XCTAssertEqual(reading?.band, .below,
                       "If this ever passes as `.within`, the fixture may go back to 4.80.")
    }

    // MARK: - The centile-trend card

    func testTrendIsStable() {
        let (birth, points) = measurements(now: Date())
        let birthPercentile = WHOGrowthStandard.percentile(weightKg: points[0].weightKg,
                                                          ageDays: 0,
                                                          isMale: SeedScenario.showcaseIsMale)
        let assessment = GrowthTrend.assess(measurements: points,
                                            correctedBirthDate: birth,
                                            isMale: SeedScenario.showcaseIsMale,
                                            birthPercentile: birthPercentile)
        XCTAssertEqual(assessment, .stable,
                       "A sustained drop would put a fall in centile spaces on the screen.")
    }

    // MARK: - The newborn card

    func testTheNewbornCardDoesNotRender() {
        // It is the only card on the screen that draws red flag rows, and it is
        // suppressed by age alone — which is part of why the fixture is two
        // months old rather than two weeks.
        XCTAssertGreaterThan(SeedScenario.showcaseAgeDays,
                             NewbornWeightLoss.observationWindowDays,
                             "Inside the observation window the newborn card takes the screen.")
    }

    // MARK: - The curve's shape

    func testTheCurveDipsAndThenRecoversPastBirthWeight() {
        let weights = SeedScenario.showcaseWeighings.map(\.weightKg)
        let birthWeight = weights[0]
        XCTAssertLessThan(weights[1], birthWeight, "Day 4 is the physiological dip.")
        XCTAssertGreaterThan(weights[2], birthWeight, "Day 10 is back past birth weight.")
        XCTAssertEqual(weights, weights.enumerated().map { index, weight in
            index <= 1 ? weight : max(weight, weights[index - 1])
        }, "After the dip the curve only climbs.")
    }

    func testTheLatestWeighingCarriesEveryMeasurement() {
        // The stat cards read the latest entry and show an em dash for a nil.
        let latest = SeedScenario.showcaseWeighings.last!
        XCTAssertNotNil(latest.heightCm)
        XCTAssertNotNil(latest.headCm)
    }
}

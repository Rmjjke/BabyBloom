import XCTest
@testable import BabyBloom

final class DashboardGrowthSummaryTests: XCTestCase {

    /// Builds an assessment with the three signals set independently, which is
    /// exactly what the rule under test needs and what `assess` cannot give:
    /// through the real entry point the signals move together with the fixture.
    private func assessment(gain: FeedingAdequacy.Signal,
                            feeding: FeedingAdequacy.Signal,
                            nappies: FeedingAdequacy.Signal) -> FeedingAdequacy.Assessment {
        FeedingAdequacy.Assessment(
            windowDays: 7,
            gain: gain,
            feedingsPerDay: 5,
            feedingReference: 7...9,
            feeding: feeding,
            wetNappiesPerDay: 4,
            wetNappyMinimum: 6,
            nappies: nappies
        )
    }

    // MARK: - The rule: gain is the only trigger

    func testFeedingAndNappySignalsNeverReachTheFreeLine() {
        // Both secondary signals below the reference, gain inside it. The
        // Dashboard must still say the calm word — DECISIONS 2026-08-25. A
        // multi-signal summary would invent a problem out of two logging gaps.
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 4.2,
            assessment: assessment(gain: .within, feeding: .below, nappies: .below),
            band: .within,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .summary(weightKg: 4.2, gain: .word(.within)))
    }

    func testGainBelowTheReferenceIsCarriedThrough() {
        // The converse: when gain itself is below, the word must not be
        // softened away either. Calm is not the same as silent.
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 4.2,
            assessment: assessment(gain: .below, feeding: .within, nappies: .within),
            band: .below,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .summary(weightKg: 4.2, gain: .word(.below)))
    }

    /// The build-11 contradiction, in one assertion: `FeedingAdequacy` collapses
    /// an above-reference gain into `Signal.within` — deliberately, because that
    /// collapse IS the breakdown gate (DECISIONS 2026-08-25) — and the Dashboard
    /// used to print the collapsed word, so a `+10267 g/week` gain read "within
    /// the reference" in green while the Growth screen said "above" it. The gate
    /// is untouched; the word is not the gate's to decide.
    func testGainAboveTheReferenceIsNotCalledWithinIt() {
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 8.8,
            assessment: assessment(gain: .within, feeding: .within, nappies: .within),
            band: .above,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .summary(weightKg: 8.8, gain: .word(.above)))
    }

    /// The pinning half of the same rule: a gain that really is inside the band
    /// still reads as inside it. `.above` must split off ONLY when the band says
    /// above — not whenever a band happens to be present.
    func testGainInsideTheBandKeepsTheCalmWord() {
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 4.2,
            assessment: assessment(gain: .within, feeding: .within, nappies: .within),
            band: .within,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .summary(weightKg: 4.2, gain: .word(.within)))
    }

    // MARK: - The states that are not verdicts

    func testNoWeighingsInvitesInsteadOfShowingAnEmptyState() {
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: nil,
            assessment: nil,
            band: nil,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .invitation)
    }

    func testOneWeighingAsksForAnotherRatherThanGuessing() {
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 3.5,
            assessment: nil,
            band: nil,
            withinReferenceAge: true
        )
        XCTAssertEqual(summary, .summary(weightKg: 3.5, gain: .needsAnotherWeighing))
    }

    func testPastTheReferenceAgeTheSectionSaysNothingAboutGain() {
        // Past six months the feature does not apply, and "not enough data"
        // would be a lie: there is plenty of data, the reference simply ends.
        let summary = DashboardGrowthSummary.free(
            latestWeightKg: 8.1,
            assessment: assessment(gain: .below, feeding: .below, nappies: .below),
            band: .below,
            withinReferenceAge: false
        )
        XCTAssertEqual(summary, .summary(weightKg: 8.1, gain: .unavailable))
    }
}

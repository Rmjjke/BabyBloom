import XCTest
@testable import BabyBloom

/// The rule that decides whether the showcase page shows a parent a clinical
/// figure about their newborn or an invitation to weigh.
///
/// It is untestable through the UI — reaching that page means walking eleven
/// onboarding pages in a simulator — which is exactly why it lives outside the
/// view, next to `OnboardingBabyBuilder` and for the same reason.
final class OnboardingGrowthPreviewTests: XCTestCase {

    private let calendar = Calendar.current

    private func daysAgo(_ days: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now)!
    }

    // MARK: - The real reading

    /// A term boy born at 3.45 kg is the page's ordinary case, and the figure
    /// has to be the one `WHOGrowthStandard` gives for day 0 — not for today.
    func testATermBirthWeightIsScoredAtDayZero() throws {
        let now = Date()
        let birth = daysAgo(30, from: now)
        let state = OnboardingGrowthPreview.state(
            birthWeightKg: 3.45, birthDate: birth,
            gestationalWeeks: nil, isMale: true, now: now
        )
        guard case let .reading(reading, kg) = state else {
            return XCTFail("expected a reading, got \(state)")
        }
        XCTAssertEqual(kg, 3.45)
        let expected = try XCTUnwrap(
            WHOGrowthStandard.percentile(weightKg: 3.45, ageDays: 0, isMale: true))
        XCTAssertEqual(reading.percentile, expected)
        XCTAssertFalse(reading.isBeyondChart)
    }

    /// The same weight is a different percentile for a girl — proof the sex
    /// actually reaches the tables rather than being dropped on the way.
    func testSexChangesTheFigure() throws {
        let now = Date()
        let birth = daysAgo(3, from: now)
        func percentile(isMale: Bool) throws -> Double {
            let state = OnboardingGrowthPreview.state(
                birthWeightKg: 3.45, birthDate: birth,
                gestationalWeeks: nil, isMale: isMale, now: now)
            guard case let .reading(reading, _) = state else {
                throw XCTSkip("expected a reading")
            }
            return reading.percentile
        }
        XCTAssertNotEqual(try percentile(isMale: true), try percentile(isMale: false))
    }

    /// The card must still be able to say "beyond the chart" — the calm rule is
    /// about the COLOUR, and withholding the reading itself would be a lie.
    func testAnExtremeBirthWeightStillProducesAReading() throws {
        let now = Date()
        let state = OnboardingGrowthPreview.state(
            birthWeightKg: 1.6, birthDate: daysAgo(1, from: now),
            gestationalWeeks: nil, isMale: true, now: now
        )
        guard case let .reading(reading, _) = state else {
            return XCTFail("expected a reading, got \(state)")
        }
        XCTAssertLessThan(reading.percentile, 3)
    }

    // MARK: - The invitation

    /// «Не помню точно». nil is an ANSWER, and the page must not invent 3.5 kg
    /// any more than `OnboardingBabyBuilder` invents a first entry.
    func testNoBirthWeightIsTheInvitation() {
        XCTAssertEqual(
            OnboardingGrowthPreview.state(birthWeightKg: nil, birthDate: Date(),
                                          gestationalWeeks: nil, isMale: false),
            .invitation)
    }

    /// A baby born ten weeks early, weighed on its actual birth day. WHO
    /// weight-for-age starts at term, so there is no honest number — the Growth
    /// screen refuses it too, and here the refusal reads as the invitation
    /// rather than as a card with "0.4th percentile" on it.
    func testAPretermBirthBeforeTheDueDateIsTheInvitation() {
        let now = Date()
        let state = OnboardingGrowthPreview.state(
            birthWeightKg: 1.4, birthDate: daysAgo(5, from: now),
            gestationalWeeks: 30, isMale: true, now: now
        )
        XCTAssertEqual(state, .invitation)
    }

    /// Late preterm is not preterm enough to correct at all (the 37-week
    /// threshold), so the reading stands — the invitation must not swallow
    /// every baby whose parent ticked "born early".
    func testALateBirthStillScores() {
        let now = Date()
        let state = OnboardingGrowthPreview.state(
            birthWeightKg: 3.0, birthDate: daysAgo(10, from: now),
            gestationalWeeks: 38, isMale: false, now: now
        )
        guard case .reading = state else {
            return XCTFail("expected a reading, got \(state)")
        }
    }

    // MARK: - The shared corrected-birth-date rule

    /// The page must derive the corrected date through `Baby`'s own function,
    /// not a second copy of the 40-week arithmetic. Pinned here because the
    /// static form exists for this call site.
    func testCorrectedBirthDateMatchesTheStoredRule() {
        let now = Date()
        let birth = daysAgo(20, from: now)
        let baby = Baby(name: "Mia", birthDate: birth, gender: .female, feedingType: .breast)
        baby.gestationalWeeks = 32
        XCTAssertEqual(
            Baby.correctedBirthDate(birthDate: birth, gestationalWeeks: 32, now: now),
            baby.correctedBirthDate)
        XCTAssertEqual(
            Baby.correctedBirthDate(birthDate: birth, gestationalWeeks: nil, now: now),
            birth)
    }
}

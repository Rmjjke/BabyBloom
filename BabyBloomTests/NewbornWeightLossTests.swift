import XCTest
@testable import BabyBloom

/// The first two weeks are the highest-anxiety window in the whole app, and the
/// only place where the app says something close to "see a doctor". Both the
/// false negatives and the false positives here matter.
final class NewbornWeightLossTests: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -15, to: Date())!

    /// A weighing `day` days after birth.
    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    private func analyse(
        birthWeight: Double? = 3.5,
        _ measurements: [WeightMeasurement],
        onDay day: Int
    ) -> NewbornWeightLoss.Status? {
        NewbornWeightLoss.analyse(
            birthWeightKg: birthWeight,
            birthDate: birth,
            measurements: measurements,
            now: Calendar.current.date(byAdding: .day, value: day, to: birth)!
        )
    }

    // MARK: - Applicability

    func testNoBirthWeightMeansNoAnalysis() {
        XCTAssertNil(analyse(birthWeight: nil, [at(3, 3.2)], onDay: 3))
        XCTAssertNil(analyse(birthWeight: 0, [at(3, 3.2)], onDay: 3))
    }

    func testWindowClosesAfterThreeWeeks() {
        XCTAssertNotNil(analyse([at(3, 3.2)], onDay: 21))
        XCTAssertNil(analyse([at(3, 3.2)], onDay: 22))
    }

    func testNoMeasurementsYetIsStillAValidState() throws {
        let status = try XCTUnwrap(analyse([], onDay: 4))
        XCTAssertNil(status.latest)
        XCTAssertNil(status.percentOfBirthWeight)
        XCTAssertTrue(status.flags.isEmpty, "absence of data is not a red flag")
    }

    // MARK: - Normal course

    /// 7% down on day 3 is textbook physiology, not a problem.
    func testTypicalLossRaisesNoFlags() throws {
        let status = try XCTUnwrap(analyse([at(1, 3.36), at(3, 3.255)], onDay: 3))
        XCTAssertEqual(try XCTUnwrap(status.percentOfBirthWeight), 93.0, accuracy: 0.1)
        XCTAssertTrue(status.flags.isEmpty)
        XCTAssertFalse(status.hasRegained)
    }

    func testRegainIsDetectedAndClearsTheWindow() throws {
        let status = try XCTUnwrap(analyse([at(3, 3.25), at(9, 3.52)], onDay: 10))
        XCTAssertTrue(status.hasRegained)
        XCTAssertEqual(status.regainedOn, at(9, 3.52).date)
        XCTAssertTrue(status.flags.isEmpty)
    }

    /// The dip's bottom is what a parent wants to see they are past, so it must
    /// survive later, heavier weighings.
    func testNadirIsTheLowestWeighingNotTheLatest() throws {
        let status = try XCTUnwrap(analyse([at(2, 3.3), at(4, 3.2), at(6, 3.4)], onDay: 6))
        XCTAssertEqual(status.nadir, at(4, 3.2))
        XCTAssertEqual(try XCTUnwrap(status.latest).weightKg, 3.4)
    }

    // MARK: - Flags

    func testLossBeyondTenPercentIsFlagged() throws {
        // 3.10 kg from 3.5 kg is an 11.4% loss.
        let status = try XCTUnwrap(analyse([at(3, 3.10)], onDay: 3))
        XCTAssertEqual(status.flags, [.lossExceeds10Percent])
    }

    /// Exactly 10% is the boundary of the normal range, not past it.
    func testExactlyTenPercentIsNotFlagged() throws {
        let status = try XCTUnwrap(analyse([at(3, 3.15)], onDay: 3))
        XCTAssertTrue(status.flags.isEmpty)
    }

    func testNotRegainedByDayFourteenIsFlagged() throws {
        let status = try XCTUnwrap(analyse([at(3, 3.2), at(14, 3.45)], onDay: 14))
        XCTAssertEqual(status.flags, [.notRegainedByDay14])
    }

    func testRegainedInTimeMeansNoDeadlineFlag() throws {
        let status = try XCTUnwrap(analyse([at(3, 3.2), at(12, 3.55)], onDay: 15))
        XCTAssertTrue(status.flags.isEmpty)
    }

    /// A day-0 weighing equal to birth weight is the birth weight, not a regain.
    func testBirthDayWeighingIsNotARegain() throws {
        let status = try XCTUnwrap(analyse([at(0, 3.5), at(3, 3.2)], onDay: 14))
        XCTAssertFalse(status.hasRegained)
        XCTAssertEqual(status.flags, [.notRegainedByDay14])
    }

    func testBothFlagsCanFireTogether() throws {
        let status = try XCTUnwrap(analyse([at(14, 3.05)], onDay: 15))
        XCTAssertEqual(status.flags, [.lossExceeds10Percent, .notRegainedByDay14])
    }

    // MARK: - Bad data

    func testMeasurementsBeforeBirthAreIgnored() throws {
        let beforeBirth = WeightMeasurement(
            date: Calendar.current.date(byAdding: .day, value: -2, to: birth)!,
            weightKg: 1.0
        )
        let status = try XCTUnwrap(analyse([beforeBirth, at(3, 3.3)], onDay: 3))
        XCTAssertEqual(status.nadir, at(3, 3.3), "a pre-birth row must not become the nadir")
        XCTAssertTrue(status.flags.isEmpty)
    }

    // MARK: - Prematurity

    /// Deliberate asymmetry with the rest of Core/Growth: the physiological drop
    /// follows delivery, so it is counted from the real birth date even for a
    /// baby born at 32 weeks.
    func testPrematurityDoesNotShiftThisWindow() throws {
        let baby = Baby(name: "Test", birthDate: birth, gender: .female, feedingType: .breast)
        baby.gestationalWeeks = 32
        baby.birthWeightKg = 3.5
        XCTAssertEqual(baby.correctedAgeDays, 0, "corrected age is zero this early")

        let status = try XCTUnwrap(analyse([at(3, 3.1)], onDay: 3))
        XCTAssertEqual(status.dayOfLife, 3, "day of life, not corrected age")
        XCTAssertEqual(status.flags, [.lossExceeds10Percent])
    }
}

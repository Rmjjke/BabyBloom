import XCTest
@testable import BabyBloom

private typealias Dose = DoctorReportSummary.Input.Dose

/// The report's medications: what falls in the period, and how doses group.
final class MedicationReportSummaryTests: XCTestCase {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()

    private func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func medications(_ doses: [Dose], start: Date? = nil, now: Date? = nil) -> [DoctorReportSummary.Medication] {
        let input = DoctorReportSummary.Input(doses: doses, birthDate: at(1, 12), correctedBirthDate: at(1, 12),
                                              birthWeightKg: nil, isMale: false)
        return DoctorReportSummary.make(input: input, periodStart: start ?? at(10, 0), now: now ?? at(20, 12),
                                        startsAtVisit: true, calendar: calendar).medications
    }

    private let paracetamol = UUID()

    private func dose(_ day: Int, _ hour: Int, name: String? = "Paracetamol", dose doseText: String? = nil,
                      linked: Bool = true, medicineName: String = "Paracetamol") -> Dose {
        Dose(time: at(day, hour), name: name, doseText: doseText,
             medicineID: linked ? paracetamol : nil, medicineName: linked ? medicineName : nil)
    }

    func testOnlyDosesInThePeriodCount() {
        let result = medications([dose(9, 23), dose(10, 0), dose(15, 8), dose(20, 11), dose(20, 13)])
        XCTAssertEqual(result.map(\.count), [3], "before the start and after now are out")
        XCTAssertEqual(result.first?.first, at(10, 0))
        XCTAssertEqual(result.first?.last, at(20, 11))
    }

    func testNoDoseMeansNoSection() {
        XCTAssertTrue(medications([]).isEmpty)
        XCTAssertTrue(medications([dose(5, 8)]).isEmpty)
    }

    func testAMedicinesDosesGroupUnderItsCurrentNameWithTheLatestDoseText() {
        let result = medications([dose(11, 8, name: "Paracetmol", dose: "100 mg"),
                                  dose(14, 8, name: "Paracetamol", dose: "120 mg (5 ml)", medicineName: "Paracetamol")])
        XCTAssertEqual(result, [DoctorReportSummary.Medication(name: "Paracetamol", doseText: "120 mg (5 ml)",
                                                               count: 2, first: at(11, 8), last: at(14, 8))])
    }

    func testOlderEventsGroupByTheirTrimmedNameWhateverTheCase() {
        let result = medications([dose(11, 8, name: "  saline drops ", linked: false),
                                  dose(12, 8, name: "Saline Drops", dose: "2 drops", linked: false)])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Saline Drops")
        XCTAssertEqual(result.first?.count, 2)
        XCTAssertEqual(result.first?.doseText, "2 drops")
    }

    /// The same name typed on an older event is not merged into the medicine.
    func testAnOlderEventIsNotMergedIntoAMedicineOfTheSameName() {
        let result = medications([dose(11, 8), dose(12, 8, linked: false)])
        XCTAssertEqual(result.map(\.name), ["Paracetamol", "Paracetamol"])
        XCTAssertEqual(result.map(\.count), [1, 1])
    }

    func testEventsWithNoNameShareOneLastLineWithNoDoseText() {
        let result = medications([dose(11, 8, name: nil, dose: "5 ml", linked: false),
                                  dose(12, 8, name: "   ", linked: false),
                                  dose(13, 8, name: "Vitamin D", linked: false),
                                  dose(14, 8)])
        XCTAssertEqual(result.map(\.name), ["Paracetamol", "Vitamin D", nil])
        XCTAssertEqual(result.last?.count, 2)
        XCTAssertNil(result.last?.doseText)
    }

    func testLinesAreByNameWhateverTheCase() {
        let result = medications([dose(11, 8, name: "vitamin D", linked: false),
                                  dose(12, 8, name: "Amoxicillin", linked: false),
                                  dose(13, 8)])
        XCTAssertEqual(result.map(\.name), ["Amoxicillin", "Paracetamol", "vitamin D"])
    }
}

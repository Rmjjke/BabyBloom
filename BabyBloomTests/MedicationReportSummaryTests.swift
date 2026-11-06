import XCTest
@testable import BabyBloom

private typealias Dose = DoctorReportSummary.Input.Dose
private typealias DoseText = DoctorReportSummary.Medication.DoseText

/// The report's medications: what falls in the period, how doses group into
/// lines, and how a line's doses group by their dose text.
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

    func testAMedicinesDosesGroupUnderItsCurrentName() {
        let result = medications([dose(11, 8, name: "Paracetmol", dose: "120 mg (5 ml)"),
                                  dose(14, 8, name: "Paracetamol", dose: "120 mg (5 ml)", medicineName: "Paracetamol")])
        XCTAssertEqual(result, [DoctorReportSummary.Medication(
            name: "Paracetamol", texts: [DoseText(text: "120 mg (5 ml)", count: 2, first: at(11, 8), last: at(14, 8))],
            count: 2, first: at(11, 8), last: at(14, 8))])
        XCTAssertEqual(result.first?.doseText, "120 mg (5 ml)", "one text: the line reads as one")
    }

    /// A changed dose is stated with what each text counts, in order of first
    /// use, never the latest text beside the whole count.
    func testAChangedDoseStatesEachTextInOrderOfFirstUse() {
        let result = medications([dose(11, 8, dose: "2.5 ml"), dose(12, 8, dose: " 2.5 ML "),
                                  dose(13, 8, dose: "5 ml"), dose(14, 8, dose: "2.5 mL")])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.count, 4)
        XCTAssertEqual(result.first?.texts, [
            DoseText(text: "2.5 mL", count: 3, first: at(11, 8), last: at(14, 8)),
            DoseText(text: "5 ml", count: 1, first: at(13, 8), last: at(13, 8)),
        ], "trimmed and case-insensitive, under the latest spelling")
        XCTAssertNil(result.first?.doseText, "no one text stands for the line")
    }

    func testDosesWithoutATextBesideTextedOnesAreTheirOwnGroup() {
        let result = medications([dose(11, 8), dose(12, 8, dose: "5 ml"), dose(13, 8, dose: "  ")])
        XCTAssertEqual(result.first?.texts, [
            DoseText(text: nil, count: 2, first: at(11, 8), last: at(13, 8)),
            DoseText(text: "5 ml", count: 1, first: at(12, 8), last: at(12, 8)),
        ])
    }

    func testALineWithNoTextAtAllHasOneEmptyGroup() {
        let result = medications([dose(11, 8), dose(12, 8)])
        XCTAssertEqual(result.first?.texts, [DoseText(text: nil, count: 2, first: at(11, 8), last: at(12, 8))])
        XCTAssertNil(result.first?.doseText)
    }

    func testOlderEventsGroupByTheirTrimmedNameWhateverTheCase() {
        let result = medications([dose(11, 8, name: "  saline drops ", dose: "2 drops", linked: false),
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

    /// The nameless line follows the same dose-text rule and drops no text it has.
    func testEventsWithNoNameShareOneLastLineAndKeepTheirTexts() {
        let result = medications([dose(11, 8, name: nil, dose: "5 ml", linked: false),
                                  dose(12, 8, name: "   ", linked: false),
                                  dose(13, 8, name: "Vitamin D", linked: false),
                                  dose(14, 8)])
        XCTAssertEqual(result.map(\.name), ["Paracetamol", "Vitamin D", nil])
        XCTAssertEqual(result.last?.count, 2)
        XCTAssertEqual(result.last?.texts, [
            DoseText(text: "5 ml", count: 1, first: at(11, 8), last: at(11, 8)),
            DoseText(text: nil, count: 1, first: at(12, 8), last: at(12, 8)),
        ])
    }

    func testLinesAreByNameWhateverTheCase() {
        let result = medications([dose(11, 8, name: "vitamin D", linked: false),
                                  dose(12, 8, name: "Amoxicillin", linked: false),
                                  dose(13, 8)])
        XCTAssertEqual(result.map(\.name), ["Amoxicillin", "Paracetamol", "vitamin D"])
    }
}

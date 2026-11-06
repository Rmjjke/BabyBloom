import XCTest
@testable import BabyBloom

/// The medication form's Save rule and how it reads and writes a medicine.
final class MedicationFormInputTests: XCTestCase {

    private func valid() -> MedicationFormInput {
        var input = MedicationFormInput()
        input.name = "Paracetamol"
        input.interval = .chip(hours: 6)
        return input
    }

    // MARK: canSave

    func testAFreshFormCannotBeSaved() {
        XCTAssertFalse(MedicationFormInput().canSave)
    }

    func testAnEmptyNameKeepsSaveOff() {
        var input = valid()
        input.name = "  "
        XCTAssertFalse(input.canSave)
    }

    func testWithoutAnIntervalSaveStaysOff() {
        var input = valid()
        input.interval = .none
        XCTAssertFalse(input.canSave)
    }

    func testAChipIntervalAllowsSave() {
        XCTAssertTrue(valid().canSave)
    }

    func testTheOtherIntervalIsBoundedByTheMedicineRange() {
        var input = valid()
        let cases: [(Int, Int, Bool)] = [(0, 0, false), (0, 15, true), (48, 0, true), (48, 15, false)]
        for (hours, minutes, expected) in cases {
            input.interval = .other(hours: hours, minutes: minutes)
            XCTAssertEqual(input.canSave, expected, "\(hours) h \(minutes) min")
        }
    }

    func testTheMaximumFieldRule() {
        var input = valid()
        let cases: [(String, Bool)] = [("", true), (" 4 ", true), ("0", false), ("25", false),
                                       ("abc", false), ("24", true), ("1", true)]
        for (text, expected) in cases {
            input.maximumText = text
            XCTAssertEqual(input.canSave, expected, "maximum '\(text)'")
        }
    }

    func testFortyEightHoursTakesNoMinutes() {
        var input = valid()
        input.setOther(hours: 47, minutes: 45)
        XCTAssertEqual(input.interval, .other(hours: 47, minutes: 45))
        input.setOther(hours: 48, minutes: 45)
        XCTAssertEqual(input.interval, .other(hours: 48, minutes: 0))
        XCTAssertTrue(input.canSave)
        XCTAssertEqual(input.otherMinuteChoices(hours: 48), [0])
    }

    func testAMinutesValueOffTheQuartersStaysOnTheWheel() {
        let medicine = Medicine(name: "Ibuprofen", intervalMinutes: 5 * 60 + 20)
        var input = MedicationFormInput(medicine)
        XCTAssertEqual(input.interval, .other(hours: 5, minutes: 20))
        input.setOther(hours: 7, minutes: 30)
        XCTAssertEqual(input.otherMinuteChoices(hours: 7), [0, 15, 20, 30, 45])
        XCTAssertEqual(MedicationFormInput().otherMinuteChoices(hours: 7), [0, 15, 30, 45])
    }

    func testTheMaximumFieldKeepsTwoDigits() {
        XCTAssertEqual(MedicationFormInput.maximumDigits("4 doses"), "4")
        XCTAssertEqual(MedicationFormInput.maximumDigits("125"), "12")
        XCTAssertEqual(MedicationFormInput.maximumDigits("٤"), "")
        XCTAssertEqual(MedicationFormInput.maximumDigits(""), "")
    }

    // MARK: maximum and interval

    func testMaximumDistinguishesNotSetFromInvalid() {
        var input = MedicationFormInput()
        XCTAssertEqual(input.maximum, .notSet)
        input.maximumText = "4"
        XCTAssertEqual(input.maximum, .value(4))
        input.maximumText = "0"
        XCTAssertEqual(input.maximum, .invalid)
    }

    func testIntervalMinutes() {
        var input = MedicationFormInput()
        input.interval = .chip(hours: 4)
        XCTAssertEqual(input.intervalMinutes, 240)
        input.interval = .other(hours: 1, minutes: 30)
        XCTAssertEqual(input.intervalMinutes, 90)
        input.interval = .other(hours: 0, minutes: 0)
        XCTAssertNil(input.intervalMinutes)
    }

    // MARK: init(medicine)

    func testAnIntervalOnAChipSelectsThatChip() {
        XCTAssertEqual(MedicationFormInput(Medicine(name: "A", intervalMinutes: 360)).interval, .chip(hours: 6))
        XCTAssertEqual(MedicationFormInput(Medicine(name: "A", intervalMinutes: 1440)).interval, .chip(hours: 24))
    }

    func testAnyOtherIntervalOpensOtherWithItsValue() {
        XCTAssertEqual(MedicationFormInput(Medicine(name: "A", intervalMinutes: 90)).interval,
                       .other(hours: 1, minutes: 30))
        XCTAssertEqual(MedicationFormInput(Medicine(name: "A", intervalMinutes: 2880)).interval,
                       .other(hours: 48, minutes: 0))
        // 5 h is a whole number of hours but not a chip.
        XCTAssertEqual(MedicationFormInput(Medicine(name: "A", intervalMinutes: 300)).interval,
                       .other(hours: 5, minutes: 0))
    }

    func testTheMaximumAndOptionalTextsComeFromTheMedicine() {
        let medicine = Medicine(name: "A", intervalMinutes: 360)
        var input = MedicationFormInput(medicine)
        XCTAssertEqual(input.maximumText, "")
        XCTAssertEqual(input.doseText, "")
        XCTAssertEqual(input.note, "")

        medicine.maxDosesPer24h = 4
        input = MedicationFormInput(medicine)
        XCTAssertEqual(input.maximumText, "4")
    }

    // MARK: apply

    func testApplyTrimsTheTextAndStoresEmptyOnesAsNil() {
        var input = valid()
        input.name = "  Calpol \n"
        input.doseText = " 5 ml "
        input.note = "  with food "
        let medicine = Medicine(name: "Old", intervalMinutes: 60)
        input.apply(to: medicine)
        XCTAssertEqual(medicine.name, "Calpol")
        XCTAssertEqual(medicine.intervalMinutes, 360)
        XCTAssertEqual(medicine.doseText, "5 ml")
        XCTAssertEqual(medicine.note, "with food")

        input.doseText = "   "
        input.note = ""
        input.apply(to: medicine)
        XCTAssertNil(medicine.doseText)
        XCTAssertNil(medicine.note)
    }

    func testApplyWritesOrClearsTheMaximum() {
        var input = valid()
        let medicine = Medicine(name: "A", intervalMinutes: 60)
        input.maximumText = "4"
        input.apply(to: medicine)
        XCTAssertEqual(medicine.maxDosesPer24h, 4)

        input.maximumText = ""
        input.apply(to: medicine)
        XCTAssertNil(medicine.maxDosesPer24h)
    }

    func testApplyDoesNothingWhenTheIntervalIsInvalid() {
        var input = valid()
        input.interval = .other(hours: 0, minutes: 0)
        let medicine = Medicine(name: "Keep", intervalMinutes: 90, doseText: "1 ml")
        input.apply(to: medicine)
        XCTAssertEqual(medicine.name, "Keep")
        XCTAssertEqual(medicine.intervalMinutes, 90)
        XCTAssertEqual(medicine.doseText, "1 ml")
    }

    // MARK: wheels and chips

    func testTheChipAndWheelValues() {
        XCTAssertEqual(MedicationFormInput.chipHours, [4, 6, 8, 12, 24])
        XCTAssertEqual(MedicationFormInput.otherHours, Array(0...48))
        XCTAssertEqual(MedicationFormInput.otherMinutes, [0, 15, 30, 45])
    }
}

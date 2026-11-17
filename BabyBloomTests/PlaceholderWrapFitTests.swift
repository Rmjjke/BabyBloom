import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// A placeholder that is a field's only label is drawn whole: the seven
/// fields of `bbPlaceholderLabel` (the medication form's name, dose, maximum
/// and note, the diaper note, the event's medication name and the doctor
/// question) in every shipped language and both pseudo-languages, on a 402-pt
/// phone and a 320-pt one, empty, focused, and again after a typed character
/// is deleted. A typed character hides the placeholder and gives the field
/// back its own height.
///
/// A vertical field draws its placeholder as a label clipped to the field's
/// height, so a cut placeholder is a label whose text needs more height than
/// it has. The fonts scale by the device's content size, which a test cannot
/// move: each case runs at its own size and skips at any other.
@MainActor
final class PlaceholderWrapFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let widths: [CGFloat] = [402, 320]

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    /// Run with the simulator at Large (`content_size large`).
    func testThePlaceholdersAreWholeAtLarge() throws {
        try requireSize(.large)
        try assertWhole(size: "Large", reserved: 1)
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testThePlaceholdersAreWholeAtAX2() throws {
        try requireSize(.accessibilityLarge)
        try assertWhole(size: "AX2", reserved: 2)
    }

    /// `reserved` is the lines a field keeps with text in it.
    private func assertWhole(size: String, reserved: Int) throws {
        for language in FitLanguage.all {
            language.apply()
            let locale = language.environmentLocale
            for width in widths {
                let place = "\(language) \(size) \(Int(width))"
                try assertFields(["medication.field_name_placeholder", "medication.field_dose_placeholder",
                                  "medication.field_max_placeholder", "form.notes_optional"],
                                 in: "\(place) medication", width: width, reserved: reserved) {
                    MedicationFormSheet(medicine: nil).environment(\.locale, locale)
                }
                try assertFields(["form.notes_optional"], in: "\(place) diaper", width: width, reserved: reserved) {
                    AddDiaperSheet().environment(\.locale, locale)
                }
                try assertFields(["form.medication_name"], in: "\(place) event", width: width, reserved: reserved) {
                    AddEventSheet(type: .medication).environment(\.locale, locale)
                }
                try assertFields(["question.placeholder"], in: "\(place) question", width: width, reserved: reserved) {
                    QuestionSheet(question: nil, baby: nil, onDelete: { _ in }).environment(\.locale, locale)
                }
            }
        }
    }

    private func assertFields<V: View>(_ keys: [String], in name: String, width: CGFloat, reserved: Int,
                                       sheet: () -> V) throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        // Tall, so every field is laid out without a scroll.
        let root = try accessibility.host(sheet().modelContainer(container).environment(SubscriptionManager()),
                                          size: CGSize(width: width, height: 1800))
        defer { accessibility.close() }
        settle()
        let elements = accessibility.elements(root, automation: true)
        for key in keys {
            let placeholder = key.l
            let field = "\(name) \(key)"
            guard let (textView, label) = placeholderLabel(placeholder, in: root) else {
                XCTFail("\(field): no field draws «\(placeholder)»")
                continue
            }
            // The measuring copies are hidden: the field alone carries the name.
            let named = elements.filter { $0.label == placeholder || $0.value == placeholder }
            XCTAssertEqual(named.count, 1, "\(field): «\(placeholder)» is read \(named.count) times: \(named)")

            assertWhole(label, "\(field) empty")
            XCTAssertTrue(textView.becomeFirstResponder(), "\(field): the field took no focus")
            settle()
            assertWhole(label, "\(field) focused")

            // A digit: the maximum takes nothing else.
            textView.insertText("2")
            settle()
            let lineHeight = label.font.lineHeight
            XCTAssertTrue(label.isHidden || label.alpha == 0 || label.window == nil,
                          "\(field): the placeholder stays over a typed character")
            XCTAssertLessThanOrEqual(textView.bounds.height, (lineHeight * CGFloat(reserved)).rounded(.up) + 1,
                                     "\(field): with a character the field is \(points(textView.bounds.height)) high, "
                                     + "\(reserved) line(s) of \(points(lineHeight))")

            textView.deleteBackward()
            settle()
            if let (_, again) = placeholderLabel(placeholder, in: root) {
                assertWhole(again, "\(field) cleared")
            } else {
                XCTFail("\(field): the placeholder did not come back once the field was cleared")
            }
            textView.resignFirstResponder()
            settle()
        }
    }

    private func assertWhole(_ label: UILabel, _ name: String) {
        let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
        XCTAssertLessThanOrEqual(needed, label.bounds.height + 0.5,
                                 "\(name): «\(label.text ?? "")» needs \(points(needed)) in \(points(label.bounds.height))")
    }

    /// The label a vertical field draws its placeholder with, and the field.
    private func placeholderLabel(_ text: String, in root: UIView) -> (UITextView, UILabel)? {
        func walk(_ view: UIView) -> (UITextView, UILabel)? {
            if let textView = view as? UITextView,
               let label = textView.subviews.compactMap({ $0 as? UILabel }).first(where: { labelText($0) == text }) {
                return (textView, label)
            }
            for subview in view.subviews {
                if let found = walk(subview) { return found }
            }
            return nil
        }
        return walk(root)
    }

    private func labelText(_ label: UILabel) -> String {
        label.text ?? label.attributedText?.string ?? ""
    }

    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

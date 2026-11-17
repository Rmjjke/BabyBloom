import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import BabyBloom

/// With the number pad up, a maximum the form cannot take shows its range
/// hint above the pad, in every shipped form and language: the pad has no key
/// to hide it, and the hint is the only place that says why Save went off.
///
/// Runs against the simulator's own keyboard; with a hardware keyboard
/// connected no pad rises and the test skips.
@MainActor
final class MedicationFormKeyboardTests: XCTestCase {

    private let accessibility = HostedAccessibility()

    override func tearDown() {
        // A failed check leaves the pad up for the next test otherwise.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    func testTheRangeHintStaysAboveTheNumberPad() throws {
        let store = try Store()
        let values = ["0", "25", "41"]
        var index = 0
        for language in [SupportedLanguage.en, .ru, .es] {
            FitLanguage.real(language).apply()
            for form in Form.allCases {
                let value = values[index % values.count]
                index += 1
                let name = "\(form)-\(language.rawValue)-\(value)"
                let root = try host(form, store)
                let keyboard = try focusMaximum(root, name)
                type(value, in: root)
                try checkHintAbove(keyboard, in: root, name)
                XCTAssertEqual(footerSaves(root).map(\.description), [],
                               "\(name): the pinned Save is on screen with the pad up")
                capture(name)
                endEditing()
                accessibility.close()
            }
        }
    }

    /// Back in the field with the hint already shown, scrolled off: the pad's
    /// rise brings the field and its hint up together.
    func testRefocusingBringsTheHintUpWithTheField() throws {
        let store = try Store()
        FitLanguage.real(.en).apply()
        for form in Form.allCases {
            let name = "\(form)-refocus"
            let root = try host(form, store)
            _ = try focusMaximum(root, name)
            type("0", in: root)
            endEditing()
            XCTAssertEqual(footerSaves(root).count, 1, "\(name): the pinned Save did not come back with the pad down")
            let scroll = try XCTUnwrap(subviews(of: UIScrollView.self, in: root).first, "\(name): no scroll view")
            scroll.setContentOffset(.zero, animated: false)
            settle(0.3)
            let keyboard = try focusMaximum(root, name)
            try checkHintAbove(keyboard, in: root, name)
            capture(name)
            endEditing()
            accessibility.close()
        }
    }

    // MARK: - The forms

    private enum Form: String, CaseIterable, CustomStringConvertible {
        case new, edit
        var description: String { rawValue }
    }

    @MainActor
    private struct Store {
        let container: ModelContainer
        let medicine: Medicine
        let subscriptions = SubscriptionManager()

        init() throws {
            container = try ModelContainer(
                for: AppSchema.schema,
                configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            let baby = Baby(name: "Mia", birthDate: Date().addingTimeInterval(-60 * 86_400),
                            gender: .female, feedingType: .breast)
            medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
            container.mainContext.insert(baby)
            container.mainContext.insert(medicine)
            try container.mainContext.save()
        }
    }

    /// The form presented as the app presents it, a sheet at its large
    /// detent, in a key window the size of the screen: the keyboard's frame and
    /// the window's share one coordinate space. Returns the window, which holds
    /// the presented sheet.
    private func host(_ form: Form, _ store: Store) throws -> UIView {
        let sheet = switch form {
        case .new: MedicationFormSheet(medicine: nil)
        case .edit: MedicationFormSheet(medicine: store.medicine, onDelete: {})
        }
        let presenter = Color.clear.sheet(isPresented: .constant(true)) {
            sheet.modelContainer(store.container).environment(store.subscriptions)
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let root = try accessibility.host(presenter, size: scene.screen.bounds.size)
        let window = try XCTUnwrap(root.window, "no window")
        window.makeKey()
        settle(0.8)
        return window
    }

    // MARK: - The keyboard

    /// Focuses the maximum field and waits for the pad; returns its frame.
    private func focusMaximum(_ root: UIView, _ name: String) throws -> CGRect {
        // The form's text views top to bottom: name, dose, maximum, note.
        let fields = subviews(of: UITextView.self, in: root)
            .sorted { $0.convert($0.bounds, to: nil).minY < $1.convert($1.bounds, to: nil).minY }
        XCTAssertEqual(fields.count, 4, "\(name): the form's text fields changed")
        let field = try XCTUnwrap(fields.count > 2 ? fields[2] : nil, "\(name): no maximum field")
        var frame: CGRect?
        let token = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { note in
            frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        }
        defer { NotificationCenter.default.removeObserver(token) }
        XCTAssertTrue(field.becomeFirstResponder(), "\(name): the maximum field took no focus")
        let deadline = Date().addingTimeInterval(4)
        while frame == nil, Date() < deadline { settle(0.1) }
        // Past the system's scroll of the field into view and the form's own
        // reveal after it.
        settle(1.0)
        guard let frame, frame.height > 100, frame.minY < root.bounds.maxY else {
            throw XCTSkip("no on-screen keyboard rose (a hardware keyboard is connected?)")
        }
        return frame
    }

    private func type(_ value: String, in root: UIView) {
        guard let field = subviews(of: UITextView.self, in: root).first(where: \.isFirstResponder) else {
            return XCTFail("nothing focused to type \(value) into")
        }
        field.selectAll(nil)
        field.insertText(value)
        settle(0.8)
    }

    private func endEditing() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        settle(0.8)
    }

    // MARK: - Reading

    private func checkHintAbove(_ keyboard: CGRect, in root: UIView, _ name: String) throws {
        let elements = accessibility.elements(root)
        let hint = try XCTUnwrap(elements.first { $0.label == "medication.field_max_range_hint".l },
                                 "\(name): no range hint")
        let focused = try XCTUnwrap(subviews(of: UITextView.self, in: root).first(where: \.isFirstResponder),
                                    "\(name): the maximum field lost focus")
        let field = focused.convert(focused.bounds, to: nil)
        let scroll = try XCTUnwrap(subviews(of: UIScrollView.self, in: root).first, "\(name): no scroll view")
        let visibleTop = scroll.convert(scroll.bounds, to: nil).minY + scroll.adjustedContentInset.top
        print("KEYBOARD \(name) pad y \(Int(keyboard.minY)) | field \(field) | hint \(hint.frame) | top \(visibleTop)")
        XCTAssertLessThanOrEqual(hint.frame.maxY, keyboard.minY + 0.5,
                                 "\(name): the hint ends at \(hint.frame.maxY), under the pad from \(keyboard.minY)")
        XCTAssertGreaterThanOrEqual(field.minY, visibleTop - 0.5,
                                    "\(name): the field starts at \(field.minY), above the visible top \(visibleTop)")
    }

    private func footerSaves(_ root: UIView) -> [HostedAccessibility.Element] {
        let height = root.bounds.height
        return accessibility.elements(root).filter { $0.label == "button.save".l && $0.frame.minY > height / 2 }
    }

    private func subviews<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
        var out: [T] = []
        func walk(_ view: UIView) {
            if let match = view as? T { out.append(match) }
            view.subviews.forEach(walk)
        }
        walk(root)
        return out
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// With BB_CAPTURE set, holds the screen still for a screenshot taken from
    /// outside: the pad is drawn by another process, beyond a window snapshot.
    private func capture(_ name: String) {
        guard ProcessInfo.processInfo.environment["BB_CAPTURE"] != nil else { return }
        print("SHOT \(name)")
        settle(2.5)
    }
}

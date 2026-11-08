import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import BabyBloom

/// Every entry sheet's pinned footer Save leaves while the keyboard is up and
/// comes back when it is down; the bar's Save stays throughout. Pinned, the
/// footer rode up on the keyboard over the next field, and a tap aimed at the
/// field saved the form.
@MainActor
final class SheetFooterKeyboardTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    /// iPhone 17.
    private let screen = CGSize(width: 402, height: 874)

    override func tearDown() {
        accessibility.close()
        super.tearDown()
    }

    func testEveryPinnedFooterLeavesWhileTheKeyboardIsUp() throws {
        let store = try Store()
        let sheets: [(name: String, view: AnyView)] = [
            ("New Medication", AnyView(MedicationFormSheet(medicine: nil))),
            ("Edit Medication", AnyView(MedicationFormSheet(medicine: store.medicine, onDelete: {}))),
            ("Log Dose", AnyView(DoseSheet(choosingFrom: [store.medicine]))),
            ("Diaper", AnyView(AddDiaperSheet())),
            ("Event", AnyView(AddEventSheet())),
            ("Feeding", AnyView(AddFeedingSheet())),
            ("Sleep", AnyView(AddSleepSheet())),
            ("Baby profile", AnyView(BabyProfileEditSheet(baby: store.baby))),
        ]
        for sheet in sheets {
            let root = try host(sheet.view, store)
            XCTAssertEqual(footerSaves(root).count, 1, "\(sheet.name): no footer Save before the keyboard")
            XCTAssertEqual(barSaves(root).count, 1, "\(sheet.name): no bar Save before the keyboard")

            post(UIResponder.keyboardWillShowNotification, .up, in: root)
            XCTAssertEqual(footerSaves(root).map(\.description), [],
                           "\(sheet.name): the footer Save stays as the keyboard rises")
            XCTAssertEqual(barSaves(root).count, 1, "\(sheet.name): the bar Save left with the keyboard")
            post(UIResponder.keyboardDidShowNotification, .up, in: root)
            XCTAssertEqual(footerSaves(root).map(\.description), [],
                           "\(sheet.name): the footer Save is back with the keyboard up")

            post(UIResponder.keyboardWillHideNotification, .down, in: root)
            XCTAssertEqual(footerSaves(root).map(\.description), [],
                           "\(sheet.name): the footer Save is back while the keyboard is still sliding down")
            post(UIResponder.keyboardDidHideNotification, .down, in: root)
            XCTAssertEqual(footerSaves(root).count, 1, "\(sheet.name): the footer Save did not come back")
            accessibility.close()
        }
    }

    /// An iPad with a hardware keyboard shows only a short bar for a focused
    /// field; the form keeps its room, so the footer stays.
    func testTheBarOverAHardwareKeyboardLeavesTheFooter() throws {
        let store = try Store()
        let root = try host(AnyView(MedicationFormSheet(medicine: nil)), store)
        post(UIResponder.keyboardWillShowNotification, .hardwareBar, in: root)
        post(UIResponder.keyboardDidShowNotification, .hardwareBar, in: root)
        XCTAssertEqual(footerSaves(root).count, 1, "the footer Save left for a hardware keyboard's bar")
    }

    func testOnlyTheKeyboardsPartOnTheScreenCounts() {
        let portrait = CGRect(x: 0, y: 0, width: 402, height: 874)
        let landscape = CGRect(x: 0, y: 0, width: 874, height: 402)
        // On-screen keyboards, upright and an iPhone's in landscape.
        XCTAssertTrue(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 538, width: 402, height: 336), screen: portrait))
        XCTAssertTrue(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 242, width: 874, height: 160), screen: landscape))
        // A hardware keyboard's bar, as its own frame or as a whole keyboard's
        // frame mostly below the edge.
        XCTAssertFalse(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 819, width: 402, height: 55), screen: portrait))
        XCTAssertFalse(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 819, width: 402, height: 336), screen: portrait))
        // A keyboard gone below the edge.
        XCTAssertFalse(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 874, width: 402, height: 336), screen: portrait))
        // No screen known: the whole frame.
        XCTAssertTrue(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 538, width: 402, height: 336), screen: nil))
        XCTAssertFalse(BBSheetKeyboard.isTall(end: CGRect(x: 0, y: 819, width: 402, height: 55), screen: nil))
    }

    // MARK: - Hosting

    /// An in-memory store with a baby and a medication, and the subscription
    /// state the app root hands every screen.
    @MainActor
    private struct Store {
        let container: ModelContainer
        let baby: Baby
        let medicine: Medicine
        let subscriptions = SubscriptionManager()

        init() throws {
            container = try ModelContainer(
                for: AppSchema.schema,
                configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
            baby = Baby(name: "Mia", birthDate: Date().addingTimeInterval(-60 * 86_400),
                        gender: .female, feedingType: .breast)
            medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
            container.mainContext.insert(baby)
            container.mainContext.insert(medicine)
            try container.mainContext.save()
        }
    }

    private func host(_ view: AnyView, _ store: Store) throws -> UIView {
        try accessibility.host(view.modelContainer(store.container).environment(store.subscriptions), size: screen)
    }

    // MARK: - Reading

    /// The sheet's confirm word: Save, or Start Feeding while the feed's timer is on.
    private func isConfirm(_ element: HostedAccessibility.Element) -> Bool {
        element.label == "button.save".l || element.label == "button.start_feeding".l
    }

    private func footerSaves(_ root: UIView) -> [HostedAccessibility.Element] {
        accessibility.elements(root).filter { isConfirm($0) && $0.frame.minY > screen.height / 2 }
    }

    private func barSaves(_ root: UIView) -> [HostedAccessibility.Element] {
        accessibility.elements(root).filter { isConfirm($0) && $0.frame.maxY < screen.height / 4 }
    }

    // MARK: - The keyboard

    private enum Keyboard {
        /// A 336-pt on-screen keyboard.
        case up
        /// A hardware keyboard's 55-pt bar, sent as a whole keyboard's frame
        /// mostly below the screen's edge.
        case hardwareBar
        /// Below the screen's edge.
        case down
    }

    /// The keyboard's notification as the system sends it: the screen as its
    /// object, the end frame in that screen's coordinates. Then a moment for
    /// the sheet to settle.
    private func post(_ name: Notification.Name, _ keyboard: Keyboard, in root: UIView) {
        let screen = root.window?.windowScene?.screen
        let bounds = screen?.bounds ?? CGRect(origin: .zero, size: self.screen)
        let height: CGFloat = 336
        let top: CGFloat = switch keyboard {
        case .up: bounds.maxY - height
        case .hardwareBar: bounds.maxY - 55
        case .down: bounds.maxY
        }
        NotificationCenter.default.post(name: name, object: screen, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: top, width: bounds.width, height: height)),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0,
            UIResponder.keyboardAnimationCurveUserInfoKey: UIView.AnimationCurve.easeInOut.rawValue,
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }
}

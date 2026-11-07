import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import BabyBloom

/// Every entry sheet's pinned footer Save leaves while the keyboard is up and
/// comes back when it goes down; the bar's Save stays throughout. Pinned, the
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
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let baby = Baby(name: "Mia", birthDate: Date().addingTimeInterval(-60 * 86_400),
                        gender: .female, feedingType: .breast)
        let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360, doseText: "2.5 ml")
        container.mainContext.insert(baby)
        container.mainContext.insert(medicine)
        try container.mainContext.save()
        let subscriptions = SubscriptionManager()

        let sheets: [(name: String, view: AnyView)] = [
            ("New Medication", AnyView(MedicationFormSheet(medicine: nil))),
            ("Edit Medication", AnyView(MedicationFormSheet(medicine: medicine, onDelete: {}))),
            ("Log Dose", AnyView(DoseSheet(choosingFrom: [medicine]))),
            ("Diaper", AnyView(AddDiaperSheet())),
            ("Event", AnyView(AddEventSheet())),
            ("Feeding", AnyView(AddFeedingSheet())),
            ("Sleep", AnyView(AddSleepSheet())),
            ("Baby profile", AnyView(BabyProfileEditSheet(baby: baby))),
        ]
        for sheet in sheets {
            // The app root hands every screen the store; a sheet hosted alone needs it too.
            let root = try accessibility.host(
                sheet.view.modelContainer(container).environment(subscriptions), size: screen)
            XCTAssertEqual(footerSaves(root).count, 1, "\(sheet.name): no footer Save before the keyboard")
            XCTAssertEqual(barSaves(root).count, 1, "\(sheet.name): no bar Save before the keyboard")

            post(UIResponder.keyboardWillShowNotification)
            XCTAssertEqual(footerSaves(root).map(\.description), [],
                           "\(sheet.name): the footer Save stays while the keyboard is up")
            XCTAssertEqual(barSaves(root).count, 1, "\(sheet.name): the bar Save left with the keyboard up")

            post(UIResponder.keyboardWillHideNotification)
            XCTAssertEqual(footerSaves(root).count, 1, "\(sheet.name): the footer Save did not come back")
            accessibility.close()
        }
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

    /// The keyboard's notification as the system sends it, a 336-pt keyboard
    /// rising or leaving, and a moment for the sheet to settle.
    private func post(_ name: Notification.Name) {
        let up = name == UIResponder.keyboardWillShowNotification
        let height: CGFloat = 336
        let end = CGRect(x: 0, y: up ? screen.height - height : screen.height, width: screen.width, height: height)
        NotificationCenter.default.post(name: name, object: nil, userInfo: [
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: end),
            UIResponder.keyboardAnimationDurationUserInfoKey: 0.0,
            UIResponder.keyboardAnimationCurveUserInfoKey: UIView.AnimationCurve.easeInOut.rawValue,
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }
}

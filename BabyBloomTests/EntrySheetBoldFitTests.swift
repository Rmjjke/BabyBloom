import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The entry sheets keep every element inside a 320-pt screen (an SE with
/// Display Zoom) at AX2, with Bold Text on and off. Add Sleep and Add Diaper
/// carry a date-and-time picker, whose ru date with Bold Text once outgrew
/// the screen; the others are held to the same rule, and so is Edit Profile's
/// birth-date picker.
///
/// The fonts scale by the device's content size, which a test cannot move:
/// the case runs with the simulator at AX2 and skips otherwise.
@MainActor
final class EntrySheetBoldFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testTheSheetsFitAtAX2() throws {
        try requireSize(.accessibilityLarge)
        for language in [SupportedLanguage.en, .ru, .es] {
            for bold in [false, true] {
                LocalizationManager.shared.setLanguage(language)
                let label = "\(language.rawValue)\(bold ? " bold" : "")"
                // The app sets the locale at its root: the date pickers
                // read it from there.
                let locale = language.environmentLocale
                try assertFits("sleep \(label)", bold: bold) { _ in AddSleepSheet().environment(\.locale, locale) }
                try assertFits("diaper \(label)", bold: bold) { _ in AddDiaperSheet().environment(\.locale, locale) }
                try assertFits("feeding \(label)", bold: bold) { _ in AddFeedingSheet().environment(\.locale, locale) }
                try assertFits("growth \(label)", bold: bold) { _ in AddGrowthSheet().environment(\.locale, locale) }
                try assertFits("event \(label)", bold: bold) { _ in AddEventSheet().environment(\.locale, locale) }
                try assertFits("medication \(label)", bold: bold) { _ in
                    MedicationFormSheet(medicine: nil).environment(\.locale, locale)
                }
                try assertFits("dose \(label)", bold: bold) { _ in
                    DoseSheet(choosingFrom: [Medicine(name: "Paracetamol", intervalMinutes: 360)])
                        .environment(\.locale, locale)
                }
                try assertFits("profile \(label)", bold: bold) { baby in
                    BabyProfileEditSheet(baby: baby).environment(\.locale, locale)
                }
            }
        }
    }

    /// The sheet is built for the baby in its store. Born 28 September: ru
    /// «28 сент. 2026 г.» is about the widest date the pickers show.
    private func assertFits<V: View>(_ name: String, bold: Bool, sheet: (Baby) -> V) throws {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let birth = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
        let baby = Baby(name: "Mia", birthDate: birth, gender: .female, feedingType: .breast)
        container.mainContext.insert(baby)
        try container.mainContext.save()
        // The app root hands every screen the subscription state.
        let root = try accessibility.host(sheet(baby).modelContainer(container).environment(SubscriptionManager()),
                                          size: screen, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        let scrolls = scrollViews(in: root)
        accessibility.close()
        XCTAssertGreaterThan(elements.count, 5, "\(name): the sheet did not draw")
        XCTAssertFalse(scrolls.isEmpty, "\(name): the sheet has no scroll")
        for scroll in scrolls {
            XCTAssertLessThanOrEqual(scroll.frame.maxX, screen.width + 0.5, "\(name): the sheet's scroll is wider than the screen")
        }
        for element in elements {
            XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(name): \(element) is past the left edge")
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(name): \(element) is past the right edge")
        }
    }

    /// In window coordinates.
    private func scrollViews(in root: UIView) -> [(frame: CGRect, contentSize: CGSize)] {
        var out: [(CGRect, CGSize)] = []
        func walk(_ view: UIView) {
            if let scroll = view as? UIScrollView {
                out.append((scroll.convert(scroll.bounds, to: nil), scroll.contentSize))
            }
            view.subviews.forEach(walk)
        }
        walk(root)
        return out
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The entry sheets keep every element inside a 320-pt screen (an SE with
/// Display Zoom) at AX2, with Bold Text on and off. Add Sleep and Add Diaper
/// carry a date-and-time picker, whose ru date with Bold Text once outgrew
/// the screen; the others are held to the same rule, and so is Edit Profile's
/// birth-date picker. Every shipped language runs, and both pseudo-languages.
///
/// The fonts scale by the device's content size, which a test cannot move:
/// the case runs with the simulator at AX2 and skips otherwise.
@MainActor
final class EntrySheetBoldFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)

    /// Sheets a language is known to push past the screen, keyed
    /// "<sheet> AX2", plus " bold" with Bold Text ("sleep AX2 bold"); the
    /// sheets are sleep, diaper, feeding, growth, event, medication, dose
    /// and profile.
    private static let knownMisses: [KnownMiss] = []

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testTheSheetsFitAtAX2() throws {
        try requireSize(.accessibilityLarge)
        for language in FitLanguage.all {
            for bold in [false, true] {
                language.apply()
                // The app sets the locale at its root: the date pickers
                // read it from there.
                let locale = language.environmentLocale
                try assertFits("sleep", language, bold: bold) { _ in AddSleepSheet().environment(\.locale, locale) }
                try assertFits("diaper", language, bold: bold) { _ in AddDiaperSheet().environment(\.locale, locale) }
                try assertFits("feeding", language, bold: bold) { _ in AddFeedingSheet().environment(\.locale, locale) }
                try assertFits("growth", language, bold: bold) { _ in AddGrowthSheet().environment(\.locale, locale) }
                try assertFits("event", language, bold: bold) { _ in AddEventSheet().environment(\.locale, locale) }
                try assertFits("medication", language, bold: bold) { _ in
                    MedicationFormSheet(medicine: nil).environment(\.locale, locale)
                }
                try assertFits("dose", language, bold: bold) { _ in
                    DoseSheet(choosingFrom: [Medicine(name: "Paracetamol", intervalMinutes: 360)])
                        .environment(\.locale, locale)
                }
                try assertFits("profile", language, bold: bold) { baby in
                    BabyProfileEditSheet(baby: baby).environment(\.locale, locale)
                }
            }
        }
    }

    /// The sheet is built for the baby in its store. Born 28 September: ru
    /// «28 сент. 2026 г.» is about the widest date the pickers show.
    private func assertFits<V: View>(_ sheetName: String, _ language: FitLanguage, bold: Bool,
                                     sheet: (Baby) -> V) throws {
        let key = "\(sheetName) AX2\(bold ? " bold" : "")"
        let name = "\(language) \(key)"
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
        let room = String(format: "%.1f", screen.width)
        var misses: [String] = []
        for scroll in scrolls where scroll.frame.maxX > screen.width + 0.5 {
            misses.append("the sheet's scroll right edge \(points(scroll.frame.maxX)) in \(room)")
        }
        for element in elements {
            if element.frame.minX < -0.5 {
                misses.append("\(element) left edge \(points(element.frame.minX)) in \(room)")
            }
            if element.frame.maxX > screen.width + 0.5 {
                misses.append("\(element) right edge \(points(element.frame.maxX)) in \(room)")
            }
        }
        if KnownMiss.listed(Self.knownMisses, language, key) {
            XCTAssertFalse(misses.isEmpty, "\(name) fits now: remove its known-miss row")
        } else {
            for miss in misses { XCTFail("\(name): \(miss)") }
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
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

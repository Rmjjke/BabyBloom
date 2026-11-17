import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The entry sheets keep every element inside a 320-pt screen (an SE with
/// Display Zoom) at AX2, with Bold Text on and off. Add Sleep, Add Diaper,
/// Add Event and Log Dose carry a date-and-time picker, whose ru date with
/// Bold Text once outgrew the screen, and the pt-BR date with the time beside
/// it after that; the others are held to the same rule, and so is Edit
/// Profile's birth-date picker. Every shipped language runs, and both
/// pseudo-languages.
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
                try assertFits("dose", language, bold: bold) { baby in
                    // A medication outside any store reads as deleted: the
                    // sheet would draw its title alone, with no time row.
                    let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
                    baby.modelContext?.insert(medicine)
                    return DoseSheet(choosingFrom: [medicine]).environment(\.locale, locale)
                }
                try assertFits("profile", language, bold: bold) { baby in
                    BabyProfileEditSheet(baby: baby).environment(\.locale, locale)
                }
            }
        }
    }

    /// Where the date and time buttons miss the card even after the text-size
    /// steps (pt-BR «12 de nov. de 2026» with Bold Text), the time goes under
    /// the date at its leading edge, each button whole on the screen. Where
    /// the pair fits, as en does at AX2, the system picker may wrap its own
    /// time under the date at the trailing edge: that is the pair, not this.
    func testTheTimeGoesUnderTheDateWhereThePairMisses() throws {
        try requireSize(.accessibilityLarge)
        let language = FitLanguage.real(.ptBR)
        language.apply()
        let root = try accessibility.host(AddSleepSheet().environment(\.locale, language.environmentLocale)
                                            .modelContainer(try storeWithBaby()).environment(SubscriptionManager()),
                                          size: screen, bold: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        accessibility.close()
        func first(_ pattern: String) -> HostedAccessibility.Element? {
            elements.first { "\($0.label) \($0.value)".range(of: pattern, options: .regularExpression) != nil }
        }
        // The start time is the first picker on the sheet.
        let date = try XCTUnwrap(first(#"\d{4}"#), "no date button among \(elements)")
        let time = try XCTUnwrap(first(#"\d{1,2}:\d{2}"#), "no time button among \(elements)")
        XCTAssertGreaterThanOrEqual(time.frame.minY, date.frame.maxY - 0.5, "the time \(time) is not under the date \(date)")
        XCTAssertEqual(time.frame.minX, date.frame.minX, accuracy: 0.5, "the time \(time) does not start under the date \(date)")
        for button in [date, time] {
            XCTAssertTrue(button.frame.minX >= -0.5 && button.frame.maxX <= screen.width + 0.5, "\(button) leaves the screen")
        }
    }

    private func storeWithBaby() throws -> ModelContainer {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        container.mainContext.insert(Baby(name: "Mia", birthDate: Date().addingTimeInterval(-30 * 86_400),
                                          gender: .female, feedingType: .breast))
        try container.mainContext.save()
        return container
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
        // Never saved: a save posts SwiftData's did-save notification to every
        // live query observer, the earlier sheets' among them. The sheets'
        // queries read the pending insert all the same.
        container.mainContext.autosaveEnabled = false
        container.mainContext.insert(baby)
        // The sheet's view graph goes before its store: left to the test's
        // autorelease pool, every torn-down sheet went at the test's end, long
        // after its store, and the heap broke there.
        let (elements, scrolls) = try autoreleasepool {
            // The app root hands every screen the subscription state.
            let root = try accessibility.host(sheet(baby).modelContainer(container).environment(SubscriptionManager()),
                                              size: screen, bold: bold)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            let read = (accessibility.elements(root, automation: true), scrollViews(in: root))
            accessibility.close()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            return read
        }
        withExtendedLifetime(container) {}
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

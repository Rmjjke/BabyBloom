import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The entry sheets keep every element inside a 320-pt screen (an SE with
/// Display Zoom) at AX2, with Bold Text on and off. Add Sleep, Add Diaper,
/// Add Event and Log Dose carry a date-and-time picker, whose ru date with
/// Bold Text once outgrew the screen, and the pt-BR date with the time beside
/// it after that; stacked, the date and the time start at the label's edge.
/// The others are held to the same rule, and so is Edit
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

    /// Where the time goes under the date, the date's button and the time's
    /// start at the label's leading edge, the card's content edge. pt-BR
    /// stacks them because «12 de nov. de 2026» and the time miss the card
    /// together; there the date once showed its short form at the trailing
    /// end of a frame measured for the full one, 11 to 16 pt in. en stacks them
    /// because at accessibility sizes the system wraps its own pair and sets
    /// the time at the trailing edge, 104 pt in. The buttons' grey is read
    /// from the drawn sheet: a picker's frame can start where its button
    /// does not.
    func testTheDateAndTheTimeStartAtTheLabelsEdge() throws {
        try requireSize(.accessibilityLarge)
        let ptBR = FitLanguage.real(.ptBR)
        try assertPillsStartAtTheEdge("sleep", ptBR, count: 4) { _ in AddSleepSheet() }
        try assertPillsStartAtTheEdge("diaper", ptBR, count: 2) { _ in AddDiaperSheet() }
        try assertPillsStartAtTheEdge("event", ptBR, count: 2) { _ in AddEventSheet() }
        try assertPillsStartAtTheEdge("dose", ptBR, count: 2) {
            // A medication outside any store reads as deleted: the sheet
            // would draw its title alone, with no time row.
            let medicine = Medicine(name: "Paracetamol", intervalMinutes: 360)
            $0.mainContext.insert(medicine)
            return DoseSheet(choosingFrom: [medicine])
        }
        try assertPillsStartAtTheEdge("sleep", .real(.en), count: 4) { _ in AddSleepSheet() }
    }

    /// Every date and time button on the sheet, with Bold Text, starts within
    /// a point of the card's content edge, one under the other.
    private func assertPillsStartAtTheEdge<V: View>(_ sheetName: String, _ language: FitLanguage, count: Int,
                                                    sheet: (ModelContainer) -> V) throws {
        let name = "\(language) \(sheetName) AX2 bold"
        language.apply()
        let container = try storeWithBaby()
        // Tall, so the rows under the fold are drawn too.
        let root = try accessibility.host(sheet(container).environment(\.locale, language.environmentLocale)
                                            .environment(\.colorScheme, .light)
                                            .modelContainer(container).environment(SubscriptionManager()),
                                          size: CGSize(width: screen.width, height: 1400), bold: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard  // 8 bits a channel, as firstFillX reads them
        let image = UIGraphicsImageRenderer(bounds: root.bounds, format: format).image { _ in
            root.drawHierarchy(in: root.bounds, afterScreenUpdates: true)
        }
        accessibility.close()
        // A picker shows as nested elements on its button's text; the
        // outermost one is the picker's frame.
        let matches = elements.filter {
            "\($0.label) \($0.value)".range(of: #"\d{4}|\d{1,2}:\d{2}"#, options: .regularExpression) != nil
        }
        var pickers: [CGRect] = []
        for frame in matches.map(\.frame) where !pickers.contains(frame)
            && !matches.contains(where: { $0.frame != frame && $0.frame.contains(frame) }) {
            pickers.append(frame)
        }
        pickers.sort { $0.minY < $1.minY }
        XCTAssertEqual(pickers.count, count, "\(name): the date and time buttons among \(elements)")
        let edge = BBTheme.Spacing.md * 2  // the screen's margin and the card's
        for (index, picker) in pickers.enumerated() {
            let fill = try XCTUnwrap(firstFillX(image, from: edge - 8, to: picker.maxX, atY: picker.midY),
                                     "\(name): no button drawn in \(picker)")
            XCTAssertEqual(fill, edge, accuracy: 1, "\(name): the button in \(picker) starts at \(fill), the label at \(edge)")
            XCTAssertLessThanOrEqual(picker.maxX, screen.width - edge + 0.5, "\(name): \(picker) passes the card")
            if index > 0 {
                XCTAssertGreaterThanOrEqual(picker.minY, pickers[index - 1].maxY - 0.5,
                                            "\(name): \(picker) is beside \(pickers[index - 1]), not under it")
            }
        }
    }

    /// The first column from `minX` on the row at `y` that differs from the
    /// ground at `minX`: where a button's grey starts on the card.
    private func firstFillX(_ image: UIImage, from minX: CGFloat, to maxX: CGFloat, atY y: CGFloat) -> CGFloat? {
        guard let cg = image.cgImage, cg.bitsPerComponent == 8,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return nil }
        let perPixel = cg.bitsPerPixel / 8
        let row = bytes + Int(y) * cg.bytesPerRow
        let ground = row + Int(minX) * perPixel
        for x in Int(minX)..<min(Int(maxX), cg.width) {
            let pixel = row + x * perPixel
            if (0..<3).contains(where: { abs(Int(pixel[$0]) - Int(ground[$0])) > 6 }) { return CGFloat(x) }
        }
        return nil
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

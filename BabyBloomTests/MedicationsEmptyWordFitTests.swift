import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The empty Medications screen breaks its heading and its empty-state title
/// between words only, on a 320-pt screen (an SE with Display Zoom) at AX2,
/// with Bold Text on and off, in every shipped language and both
/// pseudo-languages.
///
/// The fonts scale by the device's content size, which a test cannot move:
/// the case runs with the simulator at AX2 and skips otherwise. A hosted
/// window's Bold Text reaches the empty-state title but not the heading's
/// bold faces, which the system's Bold Text sets heavier; the heading's
/// steps are pinned in `BBScreenTitleFitTests`.
@MainActor
final class MedicationsEmptyWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)
    /// The empty state's card on 320: the content's 16-pt margins, then the
    /// card's 32-pt padding a side.
    private let emptyLine: CGFloat = 320 - 2 * 16 - 2 * 32
    /// The empty-state title's steps, as `EmptyStateView` takes them.
    private let steps: [UIContentSizeCategory?] = [nil, .accessibilityMedium, .extraExtraExtraLarge]
    /// The heading's room: the content's 16-pt margins, less what the
    /// heading keeps free beside its widest word.
    private let headingRoom: CGFloat = 320 - 2 * 16 - BBScreenTitleFit.spare

    /// Places a language is known not to fit, keyed by what missed and
    /// "AX2", plus " bold" with Bold Text: "medication.title AX2" (the
    /// heading), "medication.empty_title AX2 bold" (the empty-state title),
    /// "edges AX2" (any element past the screen's edges).
    private static let knownMisses: [KnownMiss] = [
        KnownMiss(.pseudo(.enXA), "medication.title AX2", width: 311.2, room: 280.0),
        KnownMiss(.pseudo(.enXA), "medication.title AX2 bold", width: 311.2, room: 280.0),
    ]

    /// One in-memory store for the whole case, never saved: a save posts
    /// SwiftData's did-save notification to every live query observer, and a
    /// hosted query an earlier test left behind traps on it once its own
    /// store is gone. The baby is a pending insert, which the list's query
    /// reads all the same.
    private var container: ModelContainer?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        // Autosave would save the insert at the next run-loop turn.
        container.mainContext.autosaveEnabled = false
        container.mainContext.insert(Baby(name: "Mia", birthDate: Date().addingTimeInterval(-90 * 86_400),
                                          gender: .female, feedingType: .breast))
        self.container = container
    }

    override func tearDown() {
        accessibility.close()
        // The closed windows' views let go of the store before it goes.
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        container = nil
        FitLanguage.restore()
        super.tearDown()
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testEveryWordIsWholeAtAX2() throws {
        try requireSize(.accessibilityLarge)
        for language in FitLanguage.all {
            for bold in [false, true] {
                language.apply()
                let qualifier = "AX2\(bold ? " bold" : "")"
                let label = "\(language) \(qualifier)"
                let elements = try emptyList(language: language, bold: bold)
                var edgeMisses: [String] = []
                for element in elements {
                    if element.frame.minX < -0.5 {
                        edgeMisses.append("\(element) left edge \(points(element.frame.minX)) in \(points(screen.width))")
                    }
                    if element.frame.maxX > screen.width + 0.5 {
                        edgeMisses.append("\(element) right edge \(points(element.frame.maxX)) in \(points(screen.width))")
                    }
                }
                check(language, "edges \(qualifier)", misses: edgeMisses)

                // The heading's last step is title3: a unit wider than that
                // breaks. A one-unit title, whole, sets one line in whichever style.
                let title = "medication.title".l
                let heading = try XCTUnwrap(elements.filter { $0.label == title }.max { $0.frame.width < $1.frame.width },
                                            "\(label): «\(title)» is not in \(elements)")
                let smallest = BBScreenTitleFit.font(.title3, size: .accessibility2, boldText: bold)
                let headingUnit = FitMeasure.widestUnit(title, uiFont: smallest)
                var headingMisses: [String] = []
                if headingUnit > headingRoom {
                    headingMisses.append("widest unit \(points(headingUnit)) in \(points(headingRoom))")
                } else if title.lineBreakUnits.count == 1 && heading.frame.height >= 1.5 * smallest.lineHeight {
                    headingMisses.append("widest unit \(points(headingUnit)) in \(points(headingRoom)) "
                                         + "sets more than one line: \(heading)")
                }
                check(language, "medication.title \(qualifier)", misses: headingMisses)

                // The first step whose widest unit fits the card's line, laid
                // out as plain text at that line.
                let emptyTitle = "medication.empty_title".l
                let drawn = try XCTUnwrap(elements.first { $0.label == emptyTitle },
                                          "\(label): «\(emptyTitle)» is not in \(elements)")
                let fonts = steps.map(emptyTitleFont)
                let widest = fonts.map { FitMeasure.widestUnit(emptyTitle, font: $0, bold: bold) }
                let step = widest.firstIndex { $0 <= emptyLine } ?? steps.count - 1
                let expected = plainSize(emptyTitle, fonts[step], bold: bold)
                var emptyMisses: [String] = []
                // Past the last step nothing is left to shrink: the unit breaks.
                if widest[step] > emptyLine || drawn.frame.width + 0.5 < widest[step] {
                    emptyMisses.append("widest unit \(points(widest[step])) in \(points(emptyLine)), "
                                       + "drawn \(points(drawn.frame.width))")
                }
                check(language, "medication.empty_title \(qualifier)", misses: emptyMisses)
                XCTAssertEqual(drawn.frame.height, expected.height, accuracy: 1,
                               "\(label): «\(emptyTitle)» is not set at step \(step)")
            }
        }
    }

    /// Fails on every miss, unless the key is listed: then on none left.
    private func check(_ language: FitLanguage, _ key: String, misses: [String]) {
        if KnownMiss.listed(Self.knownMisses, language, key) {
            XCTAssertFalse(misses.isEmpty, "\(language) \(key) fits now: remove its known-miss row")
        } else {
            for miss in misses { XCTFail("\(language) \(key): \(miss)") }
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private func emptyTitleFont(_ cap: UIContentSizeCategory?) -> Font {
        let size = BBTheme.Typography.scaledPointSize(18, relativeTo: .body)
        let capped = cap.map { min(size, BBTheme.Typography.scaledPointSize(18, relativeTo: .body, for: $0)) } ?? size
        return .system(size: capped, weight: .semibold, design: .rounded)
    }

    /// The list with no medicines, in its navigation stack, read once settled.
    private func emptyList(language: FitLanguage, bold: Bool) throws -> [HostedAccessibility.Element] {
        let container = try XCTUnwrap(self.container)
        // The app sets the locale at its root.
        let view = NavigationStack { MedicationsListView() }
            .environment(\.locale, language.environmentLocale)
            .modelContainer(container)
        let root = try accessibility.host(view, size: screen, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        accessibility.close()
        return elements
    }

    private func plainSize(_ text: String, _ font: Font, bold: Bool) -> CGSize {
        let view = Text(text).font(font).environment(\.legibilityWeight, bold ? .bold : .regular)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: emptyLine, height: .greatestFiniteMagnitude))
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

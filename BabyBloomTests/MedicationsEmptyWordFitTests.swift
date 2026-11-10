import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The empty Medications screen breaks its heading and its empty-state title
/// between words only, on a 320-pt screen (an SE with Display Zoom) at AX2,
/// with Bold Text on and off.
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

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testEveryWordIsWholeAtAX2() throws {
        try requireSize(.accessibilityLarge)
        for language in [SupportedLanguage.en, .ru, .es] {
            for bold in [false, true] {
                LocalizationManager.shared.setLanguage(language)
                let label = "\(language.rawValue)\(bold ? " bold" : "")"
                let elements = try emptyList(language: language, bold: bold)
                for element in elements {
                    XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(label): \(element) is past the left edge")
                    XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(label): \(element) is past the right edge")
                }

                // One word: whole, it sets one line in whichever style.
                let title = "medication.title".l
                let heading = try XCTUnwrap(elements.filter { $0.label == title }.max { $0.frame.width < $1.frame.width },
                                            "\(label): «\(title)» is not in \(elements)")
                let smallest = BBScreenTitleFit.font(.title3, size: .accessibility2, boldText: bold).lineHeight
                XCTAssertLessThan(heading.frame.height, 1.5 * smallest,
                                  "\(label): «\(title)» sets more than one line: \(heading)")

                // The first step whose widest word fits the card's line, laid
                // out as plain text at that line.
                let emptyTitle = "medication.empty_title".l
                let drawn = try XCTUnwrap(elements.first { $0.label == emptyTitle },
                                          "\(label): «\(emptyTitle)» is not in \(elements)")
                let fonts = steps.map(emptyTitleFont)
                let words = emptyTitle.split(separator: " ").map(String.init)
                let widest = fonts.map { font in words.map { wordWidth($0, font, bold: bold) }.max() ?? 0 }
                let step = widest.firstIndex { $0 <= emptyLine } ?? steps.count - 1
                let expected = plainSize(emptyTitle, fonts[step], bold: bold)
                XCTAssertGreaterThanOrEqual(drawn.frame.width + 0.5, widest[step],
                                            "\(label): «\(emptyTitle)» breaks a word at \(drawn.frame.width)")
                XCTAssertEqual(drawn.frame.height, expected.height, accuracy: 1,
                               "\(label): «\(emptyTitle)» is not set at step \(step)")
            }
        }
    }

    private func emptyTitleFont(_ cap: UIContentSizeCategory?) -> Font {
        let size = BBTheme.Typography.scaledPointSize(18, relativeTo: .body)
        let capped = cap.map { min(size, BBTheme.Typography.scaledPointSize(18, relativeTo: .body, for: $0)) } ?? size
        return .system(size: capped, weight: .semibold, design: .rounded)
    }

    /// The list with no medicines, in its navigation stack, read once settled.
    private func emptyList(language: SupportedLanguage, bold: Bool) throws -> [HostedAccessibility.Element] {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        container.mainContext.insert(Baby(name: "Mia", birthDate: Date().addingTimeInterval(-90 * 86_400),
                                          gender: .female, feedingType: .breast))
        try container.mainContext.save()
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

    private func wordWidth(_ word: String, _ font: Font, bold: Bool) -> CGFloat {
        let view = Text(word).font(font).fixedSize().environment(\.legibilityWeight, bold ? .bold : .regular)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
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

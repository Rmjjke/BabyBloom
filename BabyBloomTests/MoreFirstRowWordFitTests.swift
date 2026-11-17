import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The first row of the More tab, the baby's avatar over a name and the
/// settings subtitle, breaks its texts between words only, on a 320-pt screen
/// (an SE with Display Zoom) at every text size. The avatar stands beside the
/// texts while their widest word fits the column it leaves, else on a line of
/// its own above them, where the texts take the row's whole width. Every
/// shipped language runs, and both pseudo-languages.
///
/// The fonts scale by the device's content size, which a test cannot move:
/// each size's case runs with the simulator at that size and skips otherwise.
@MainActor
final class MoreFirstRowWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)
    /// Beside, the texts start past the 44-pt avatar (x 84); under it, at the
    /// row's leading edge (x 32).
    private let besideMinX: CGFloat = 60

    /// Places a language is known not to fit, keyed by what missed, the baby's
    /// name, the size (Large, AX1, AX2) and " bold" with Bold Text:
    /// "profile.settings_subtitle with Mia AX2 bold", "name Александра AX2",
    /// "edges with Mia AX1" (any element past the screen's edges).
    private static let knownMisses: [KnownMiss] = []

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    /// Run with the simulator at Large (the default).
    func testEveryWordIsWholeAtLarge() throws {
        try requireSize(.large)
        try assertRow(at: .large)
    }

    /// Run with the simulator at AX1 (`content_size accessibility-medium`).
    func testEveryWordIsWholeAtAX1() throws {
        try requireSize(.accessibilityMedium)
        try assertRow(at: .accessibilityMedium)
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testEveryWordIsWholeAtAX2() throws {
        try requireSize(.accessibilityLarge)
        try assertRow(at: .accessibilityLarge)
    }

    /// «Александра» is the long name; «Mia» leaves the subtitle alone to decide.
    private func assertRow(at size: UIContentSizeCategory) throws {
        for babyName in ["Александра", "Mia"] {
            for language in FitLanguage.all {
                var regularName: (drawn: CGFloat, measured: CGFloat)?
                for bold in [false, true] {
                    language.apply()
                    let qualifier = "\(sizeName(size))\(bold ? " bold" : "")"
                    let label = "\(language) \(babyName) \(qualifier)"
                    let subtitle = "profile.settings_subtitle".l
                    let elements = try moreTab(babyName: babyName, bold: bold, language: language,
                                               key: "edges with \(babyName) \(qualifier)")
                    let nameText = try XCTUnwrap(elements.first { $0.label == babyName },
                                                 "\(label): «\(babyName)» is not in \(elements)")
                    let subtitleText = try XCTUnwrap(elements.first { $0.label == subtitle },
                                                     "\(label): «\(subtitle)» is not in \(elements)")
                    let nameWord = widestWord(babyName, nameFont, bold: bold)
                    let subtitleWord = widestWord(subtitle, subtitleFont, bold: bold)
                    print("MORE_ROW \(label): name x \(nameText.frame.minX) w \(nameText.frame.width) "
                          + "for «\(nameWord.0)» \(nameWord.1); subtitle w \(subtitleText.frame.width) "
                          + "for «\(subtitleWord.0)» \(subtitleWord.1)")

                    if let regularName {
                        // Bold Text reaches both the hosted tab and the measure;
                        // a miss would only compare regular widths with regular.
                        XCTAssertGreaterThan(nameText.frame.width, regularName.drawn,
                                             "\(label): the name is drawn no wider than without Bold Text")
                        XCTAssertGreaterThan(nameWord.1, regularName.measured,
                                             "\(label): the name measures no wider than without Bold Text")
                    } else {
                        regularName = (nameText.frame.width, nameWord.1)
                    }
                    check(language, "name \(babyName) \(qualifier)", unit: nameWord, drawn: nameText.frame.width)
                    check(language, "profile.settings_subtitle with \(babyName) \(qualifier)",
                          unit: subtitleWord, drawn: subtitleText.frame.width)
                    // VoiceOver reads the row once, the hidden one-word-a-line
                    // copy of the texts never.
                    XCTAssertEqual(elements.filter { $0.label == "\(babyName), \(subtitle)" }.count, 1,
                                   "\(label): the row does not read as the name and the subtitle once: \(elements)")
                    XCTAssertFalse(elements.contains { $0.label.contains("\n") },
                                   "\(label): the one-word-a-line copy reads: \(elements)")
                    XCTAssertEqual(nameText.frame.minX, subtitleText.frame.minX, accuracy: 0.5,
                                   "\(label): the name and the subtitle do not share their leading edge")
                    if let stacked = expectedStacked(babyName, language: language, bold: bold, size: size) {
                        let beside = nameText.frame.minX > besideMinX
                        XCTAssertEqual(beside, !stacked,
                                       "\(label): the texts are \(beside ? "beside" : "under") the avatar at x \(nameText.frame.minX)")
                    }
                }
            }
        }
    }

    /// nil where a word lands within a few points of the column beside the
    /// avatar (about 168 at AX2): there only the words are checked. At Large
    /// and AX1 the texts keep beside. At AX2 «Александра» (180, in Bold Text
    /// 193) misses the column, and so do the bold ru «уведомления,» (175) and
    /// es «notificaciones,» (174); en «notifications,» (155 in Bold) fits.
    private func expectedStacked(_ babyName: String, language: FitLanguage, bold: Bool,
                                 size: UIContentSizeCategory) -> Bool? {
        let pinned: [FitLanguage] = [.real(.en), .real(.ru), .real(.es)]
        // Only «Александра» at AX2 misses whatever the language; the other
        // languages' shape is not pinned, their words are held whole.
        guard pinned.contains(language) else {
            return size == .accessibilityLarge && babyName == "Александра" ? true : nil
        }
        switch size {
        case .large: return false
        case .accessibilityMedium: return bold ? nil : false
        case .accessibilityLarge:
            if babyName == "Александра" { return true }
            switch language {
            case .real(.en): return false
            default: return bold ? true : nil
            }
        default: return nil
        }
    }

    // MARK: - The tab

    /// The More tab with one baby, read once it has settled.
    private func moreTab(babyName: String, bold: Bool, language: FitLanguage,
                         key: String) throws -> [HostedAccessibility.Element] {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let baby = Baby(name: babyName, birthDate: Date().addingTimeInterval(-90 * 86_400),
                        gender: .female, feedingType: .breast)
        container.mainContext.insert(baby)
        try container.mainContext.save()
        let root = try accessibility.host(MoreView().modelContainer(container), size: screen, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        accessibility.close()
        var misses: [String] = []
        for element in elements {
            if element.frame.minX < -0.5 {
                misses.append("\(element) left edge \(points(element.frame.minX)) in \(points(screen.width))")
            }
            if element.frame.maxX > screen.width + 0.5 {
                misses.append("\(element) right edge \(points(element.frame.maxX)) in \(points(screen.width))")
            }
        }
        if KnownMiss.listed(Self.knownMisses, language, key) {
            XCTAssertFalse(misses.isEmpty, "\(language) \(key) fits now: remove its known-miss row")
        } else {
            for miss in misses { XCTFail("\(language) \(key): \(miss)") }
        }
        return elements
    }

    /// A text drawn narrower than its widest unit has broken it.
    private func check(_ language: FitLanguage, _ key: String, unit: (String, CGFloat), drawn: CGFloat) {
        let broken = drawn + 0.5 < unit.1
        if KnownMiss.listed(Self.knownMisses, language, key) {
            XCTAssertTrue(broken, "\(language) \(key) fits now: remove its known-miss row")
        } else {
            XCTAssertFalse(broken, "\(language) \(key): widest unit «\(unit.0)» \(points(unit.1)) in \(points(drawn))")
        }
    }

    private func sizeName(_ size: UIContentSizeCategory) -> String {
        switch size {
        case .accessibilityMedium: "AX1"
        case .accessibilityLarge: "AX2"
        case .large: "Large"
        default: size.rawValue
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    private var nameFont: Font { BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded) }
    private var subtitleFont: Font { BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded) }

    /// The widest piece a line cannot break inside, and its width.
    private func widestWord(_ text: String, _ font: Font, bold: Bool) -> (String, CGFloat) {
        text.lineBreakUnits
            .map { ($0, FitMeasure.wordWidth($0, font: font, bold: bold)) }
            .max { $0.1 < $1.1 } ?? ("", 0)
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

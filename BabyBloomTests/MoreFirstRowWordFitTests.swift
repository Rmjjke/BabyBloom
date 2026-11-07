import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// The first row of the More tab, the baby's avatar over a name and the
/// settings subtitle, breaks its texts between words only, on a 320-pt screen
/// (an SE with Display Zoom) at every text size. The avatar stands beside the
/// texts while their widest word fits the column it leaves, else on a line of
/// its own above them, where the texts take the row's whole width.
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

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
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
            for language in [SupportedLanguage.en, .ru, .es] {
                var regularName: (drawn: CGFloat, measured: CGFloat)?
                for bold in [false, true] {
                    LocalizationManager.shared.setLanguage(language)
                    let label = "\(babyName) \(language.rawValue)\(bold ? " bold" : "") \(size.rawValue)"
                    let subtitle = "profile.settings_subtitle".l
                    let elements = try moreTab(babyName: babyName, bold: bold)
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
                    XCTAssertGreaterThanOrEqual(nameText.frame.width + 0.5, nameWord.1,
                                                "\(label): «\(nameWord.0)» (\(nameWord.1)) is broken at \(nameText.frame.width)")
                    XCTAssertGreaterThanOrEqual(subtitleText.frame.width + 0.5, subtitleWord.1,
                                                "\(label): «\(subtitleWord.0)» (\(subtitleWord.1)) is broken at \(subtitleText.frame.width)")
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
    private func expectedStacked(_ babyName: String, language: SupportedLanguage, bold: Bool,
                                 size: UIContentSizeCategory) -> Bool? {
        switch size {
        case .large: return false
        case .accessibilityMedium: return bold ? nil : false
        case .accessibilityLarge:
            if babyName == "Александра" { return true }
            switch language {
            case .en: return false
            default: return bold ? true : nil
            }
        default: return nil
        }
    }

    // MARK: - The tab

    /// The More tab with one baby, read once it has settled.
    private func moreTab(babyName: String, bold: Bool) throws -> [HostedAccessibility.Element] {
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
        for element in elements {
            XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(element) is past the left edge")
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(element) is past the right edge")
        }
        return elements
    }

    private var nameFont: Font { BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded) }
    private var subtitleFont: Font { BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded) }

    /// Words part at plain spaces, as they wrap.
    private func widestWord(_ text: String, _ font: Font, bold: Bool) -> (String, CGFloat) {
        text.split(separator: " ")
            .map { (String($0), wordWidth(String($0), font, bold: bold)) }
            .max { $0.1 < $1.1 } ?? ("", 0)
    }

    private func wordWidth(_ word: String, _ font: Font, bold: Bool) -> CGFloat {
        let view = Text(word).font(font).fixedSize().environment(\.legibilityWeight, bold ? .bold : .regular)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

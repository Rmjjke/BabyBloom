import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import BabyBloom

/// More's rows below the first and Settings' baby row break their words
/// between words only, on a 320-pt screen (an SE with Display Zoom) at every
/// text size, with and without Bold Text. A More row keeps the system Label
/// while its title's widest word fits beside the icon, else sets the icon on a
/// line of its own above the title; a word wider than the whole row is set at
/// a smaller size, never broken. The baby row keeps the avatar beside the name
/// and the age while their words fit there, else on a line of its own above.
///
/// The fonts scale by the device's content size, which a test cannot move:
/// each size's case runs with the simulator at that size and skips otherwise.
@MainActor
final class MoreSettingsRowsWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private let screen = CGSize(width: 320, height: 568)
    /// Beside, the baby's name starts past the 56-pt avatar (x 104); under,
    /// at the row's leading edge (x 32).
    private let besideMinX: CGFloat = 60
    /// A row's content starts about this far below its top (the List's own
    /// inset); a More title under its icon starts an icon's line further down.
    private let rowInset: CGFloat = 12
    /// What a More title gets under its icon at AX2 on 320 pt: x 32–250.
    private let underRoomAtAX2: CGFloat = 218
    private let rowKeys = ["nav.growth", "report.title", "nav.recent_activity", "nav.events", "medication.title"]

    override func tearDown() {
        accessibility.close()
        LocalizationManager.shared.setLanguage(.en)
        super.tearDown()
    }

    /// Run with the simulator at Large (the default).
    func testEveryWordIsWholeAtLarge() throws {
        try requireSize(.large)
        try assertMoreRows(at: .large)
        try assertBabyRow(at: .large)
    }

    /// Run with the simulator at xxxLarge (`content_size extra-extra-extra-large`).
    func testEveryWordIsWholeAtXXXLarge() throws {
        try requireSize(.extraExtraExtraLarge)
        try assertMoreRows(at: .extraExtraExtraLarge)
        try assertBabyRow(at: .extraExtraExtraLarge)
    }

    /// Run with the simulator at AX1 (`content_size accessibility-medium`).
    func testEveryWordIsWholeAtAX1() throws {
        try requireSize(.accessibilityMedium)
        try assertMoreRows(at: .accessibilityMedium)
        try assertBabyRow(at: .accessibilityMedium)
    }

    /// Run with the simulator at AX2 (`content_size accessibility-large`).
    func testEveryWordIsWholeAtAX2() throws {
        try requireSize(.accessibilityLarge)
        try assertMoreRows(at: .accessibilityLarge)
        try assertBabyRow(at: .accessibilityLarge)
    }

    // MARK: - More

    /// The system Label reads as one element whose frame holds the icon as
    /// well, so a row beside its icon is told by its top, level with the
    /// row's, and its words by its lines: a one-word title beside the icon is
    /// one line, or the word broke. A title under its icon reads alone.
    private func assertMoreRows(at size: UIContentSizeCategory) throws {
        for language in [SupportedLanguage.en, .ru, .es] {
            var regularEvents: CGFloat?
            for bold in [false, true] {
                LocalizationManager.shared.setLanguage(language)
                let run = "\(language.rawValue)\(bold ? " bold" : "") \(size.rawValue)"
                let (spoken, drawn) = try moreTab(bold: bold)
                let line = lineHeight(.body, bold: bold)
                var beside: [(title: String, word: CGFloat)] = []
                var under: [(title: String, word: CGFloat)] = []
                for key in rowKeys {
                    let title = key.l
                    let word = widestWord(title, .body, bold: bold)
                    // VoiceOver reads each row once, the hidden one-word-a-line
                    // copy never.
                    let rows = spoken.filter { $0.label == title }
                    XCTAssertEqual(rows.count, 1, "\(run): «\(title)» does not read once: \(spoken)")
                    let row = try XCTUnwrap(rows.first, "\(run): «\(title)» is not in \(spoken)")
                    let text = try XCTUnwrap(drawn.filter { $0.label == title }.min { $0.frame.width < $1.frame.width },
                                             "\(run): «\(title)» is not in \(drawn)")
                    let drop = text.frame.minY - row.frame.minY
                    let isBeside = drop < rowInset + line / 2
                    print("MORE_ROWS \(run) «\(title)»: x \(text.frame.minX) w \(text.frame.width) "
                          + "h \(text.frame.height) drop \(drop) for «\(word.0)» \(word.1)")
                    if isBeside {
                        // A word broken beside the icon takes a line of its
                        // own: no more lines than words, and a one-word title
                        // on one.
                        let words = title.split(separator: " ").count
                        XCTAssertLessThan(text.frame.height, (CGFloat(words) + 0.5) * line,
                                          "\(run): «\(title)» beside its icon takes \(text.frame.height) for \(words) "
                                          + "word(s) of \(line) a line")
                        beside.append((title, word.1))
                    } else if size == .accessibilityLarge, word.1 > underRoomAtAX2 {
                        // Wider than the whole row at the reader's size: set at
                        // the AX1 size, one line, whole.
                        let stepped = wordWidth(word.0, .body, bold: bold, at: .accessibility1)
                        XCTAssertGreaterThanOrEqual(text.frame.width + 0.5, stepped,
                                                    "\(run): «\(word.0)» (\(stepped) at AX1) is broken at \(text.frame.width)")
                        XCTAssertLessThan(text.frame.height, line,
                                          "\(run): «\(title)» is not one line under the reader's size")
                        under.append((title, word.1))
                    } else {
                        XCTAssertGreaterThanOrEqual(text.frame.width + 0.5, word.1,
                                                    "\(run): «\(word.0)» (\(word.1)) is broken at \(text.frame.width)")
                        under.append((title, word.1))
                    }
                    if size == .accessibilityLarge, word.1 > underRoomAtAX2 {
                        XCTAssertFalse(isBeside, "\(run): «\(title)» stays beside its icon")
                    }
                    if let expected = expectedUnder(key, language: language, bold: bold, size: size) {
                        XCTAssertEqual(!isBeside, expected,
                                       "\(run): «\(title)» is \(isBeside ? "beside" : "under") its icon, \(drop) below the row's top")
                    }
                    if key == "nav.events" {
                        // Bold Text reaches the hosted tab: a miss would only
                        // compare regular widths with regular. The shortest
                        // title stays one line beside its icon either way.
                        if let regularEvents {
                            XCTAssertGreaterThan(text.frame.width, regularEvents,
                                                 "\(run): «\(title)» is drawn no wider than without Bold Text")
                        } else {
                            regularEvents = text.frame.width
                        }
                    }
                }
                // Every row has the same room beside its icon, so a row under
                // its icon holds a wider word than any row beside one.
                if let widestBeside = beside.max(by: { $0.word < $1.word }),
                   let narrowestUnder = under.min(by: { $0.word < $1.word }) {
                    XCTAssertGreaterThan(narrowestUnder.word, widestBeside.word,
                                         "\(run): «\(narrowestUnder.title)» goes under its icon while the wider "
                                         + "«\(widestBeside.title)» stays beside")
                }
                XCTAssertFalse(spoken.contains { $0.label.contains("\n") },
                               "\(run): a one-word-a-line copy reads: \(spoken)")
            }
        }
    }

    /// nil where the widest word lands within a few points of the room beside
    /// the icon: there only the words and the order are checked. Below the
    /// accessibility sizes every title fits beside (at xxxLarge the widest,
    /// es «Medicamentos», is 147 pt, 155 in Bold Text). At AX2 the room is
    /// 158.5 pt: en «pediatrician» (165.5) and «Medications» (173.7) and es
    /// «Crecimiento» (171.1) and «Medicamentos» (210.3) miss it; ru
    /// «Лекарства» (158.7) sits on its edge and misses it in Bold Text
    /// (167.5), where «Недавние» (156.1) still fits.
    private func expectedUnder(_ key: String, language: SupportedLanguage, bold: Bool,
                               size: UIContentSizeCategory) -> Bool? {
        switch size {
        case .large, .extraExtraExtraLarge: return false
        case .accessibilityLarge:
            switch (language, key) {
            case (.en, "report.title"), (.en, "medication.title"),
                 (.es, "nav.growth"), (.es, "medication.title"): return true
            case (.ru, "medication.title"): return bold ? true : nil
            default: return false
            }
        default: return nil
        }
    }

    /// The More tab with one baby: what VoiceOver reads, and every element
    /// with its own frame as UI tests see them.
    private func moreTab(bold: Bool) throws -> (spoken: [HostedAccessibility.Element],
                                                drawn: [HostedAccessibility.Element]) {
        let container = try container(babyName: "Mia")
        // Tall enough for every row to stand in the tree at AX2 at once; the
        // width alone decides where the words wrap.
        let tall = CGSize(width: screen.width, height: 1600)
        let root = try accessibility.host(MoreView().modelContainer(container), size: tall, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let spoken = accessibility.elements(root)
        let drawn = accessibility.elements(root, automation: true)
        accessibility.close()
        assertOnScreen(drawn)
        return (spoken, drawn)
    }

    // MARK: - Settings

    /// «Александра» is the long name; «Mia» leaves the age alone to decide.
    private func assertBabyRow(at size: UIContentSizeCategory) throws {
        for babyName in ["Александра", "Mia"] {
            for language in [SupportedLanguage.en, .ru, .es] {
                for bold in [false, true] {
                    LocalizationManager.shared.setLanguage(language)
                    let run = "\(babyName) \(language.rawValue)\(bold ? " bold" : "") \(size.rawValue)"
                    let (age, elements) = try settings(babyName: babyName, bold: bold)
                    let nameText = try XCTUnwrap(elements.filter { $0.label == babyName }.min { $0.frame.width < $1.frame.width },
                                                 "\(run): «\(babyName)» is not in \(elements)")
                    let ageText = try XCTUnwrap(elements.filter { $0.label == age }.min { $0.frame.width < $1.frame.width },
                                                "\(run): «\(age)» is not in \(elements)")
                    let nameWord = widestWord(babyName, nameFont, bold: bold)
                    let ageWord = widestWord(age, ageFont, bold: bold)
                    print("BABY_ROW \(run): name x \(nameText.frame.minX) w \(nameText.frame.width) "
                          + "for «\(nameWord.0)» \(nameWord.1); age w \(ageText.frame.width) for «\(ageWord.0)» \(ageWord.1)")
                    XCTAssertGreaterThanOrEqual(nameText.frame.width + 0.5, nameWord.1,
                                                "\(run): «\(nameWord.0)» (\(nameWord.1)) is broken at \(nameText.frame.width)")
                    XCTAssertGreaterThanOrEqual(ageText.frame.width + 0.5, ageWord.1,
                                                "\(run): «\(ageWord.0)» (\(ageWord.1)) is broken at \(ageText.frame.width)")
                    XCTAssertEqual(nameText.frame.minX, ageText.frame.minX, accuracy: 0.5,
                                   "\(run): the name and the age do not share their leading edge")
                    if let stacked = expectedBabyUnder(babyName, size: size) {
                        let beside = nameText.frame.minX > besideMinX
                        XCTAssertEqual(beside, !stacked,
                                       "\(run): the texts are \(beside ? "beside" : "under") the avatar at x \(nameText.frame.minX)")
                    }
                }
            }
        }
    }

    /// nil where the texts land near the column beside the avatar. From
    /// xxxLarge «Александра» (150 pt there, 161 in Bold Text) misses the
    /// 120 pt beside the avatar; «Mia» and its age fit there below the
    /// accessibility sizes.
    private func expectedBabyUnder(_ babyName: String, size: UIContentSizeCategory) -> Bool? {
        switch size {
        case .large: return false
        case .extraExtraExtraLarge: return babyName != "Mia"
        default: return babyName == "Mia" ? nil : true
        }
    }

    /// Settings with one baby, read once it has settled, and the baby's age
    /// as the row draws it.
    private func settings(babyName: String, bold: Bool) throws -> (age: String, elements: [HostedAccessibility.Element]) {
        let container = try container(babyName: babyName)
        let baby = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<Baby>()).first)
        let view = NavigationStack { ProfileView() }
            .environment(SubscriptionManager())
            .modelContainer(container)
        let root = try accessibility.host(view, size: screen, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        accessibility.close()
        assertOnScreen(elements)
        return (baby.ageDescription, elements)
    }

    private var nameFont: Font { BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded) }
    private var ageFont: Font { BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded) }

    // MARK: - Helpers

    private func container(babyName: String) throws -> ModelContainer {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)])
        let baby = Baby(name: babyName, birthDate: Date().addingTimeInterval(-90 * 86_400),
                        gender: .female, feedingType: .breast)
        container.mainContext.insert(baby)
        try container.mainContext.save()
        return container
    }

    private func assertOnScreen(_ elements: [HostedAccessibility.Element]) {
        for element in elements {
            XCTAssertGreaterThanOrEqual(element.frame.minX, -0.5, "\(element) is past the left edge")
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.width + 0.5, "\(element) is past the right edge")
        }
    }

    /// Words part at plain spaces, as they wrap; a no-break space keeps a
    /// number with its unit.
    private func widestWord(_ text: String, _ font: Font, bold: Bool) -> (String, CGFloat) {
        text.split(separator: " ")
            .map { (String($0), wordWidth(String($0), font, bold: bold)) }
            .max { $0.1 < $1.1 } ?? ("", 0)
    }

    /// `size` sets a text size other than the device's; it moves text-style
    /// fonts such as `.body` only.
    private func wordWidth(_ word: String, _ font: Font, bold: Bool, at size: DynamicTypeSize? = nil) -> CGFloat {
        measure(Text(word), font, bold: bold, at: size).width
    }

    private func lineHeight(_ font: Font, bold: Bool) -> CGFloat {
        measure(Text("M"), font, bold: bold, at: nil).height
    }

    private func measure(_ text: Text, _ font: Font, bold: Bool, at size: DynamicTypeSize?) -> CGSize {
        let device = DynamicTypeSize(UIApplication.shared.preferredContentSizeCategory) ?? .large
        let view = text.font(font).fixedSize()
            .environment(\.legibilityWeight, bold ? .bold : .regular)
            .environment(\.dynamicTypeSize, size ?? device)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
    }

    private func requireSize(_ size: UIContentSizeCategory) throws {
        let current = UIApplication.shared.preferredContentSizeCategory
        try XCTSkipUnless(current == size, "the case is measured at \(size.rawValue); the device is at \(current.rawValue)")
    }
}

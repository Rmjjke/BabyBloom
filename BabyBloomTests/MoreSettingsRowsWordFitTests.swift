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
/// Every shipped language runs, and both pseudo-languages.
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
    /// The languages whose row shapes were read off the simulator and pinned.
    private let pinned: [FitLanguage] = [.real(.en), .real(.ru), .real(.es)]

    /// Places a language is known not to fit, keyed by what missed, the size
    /// (Large, xxxLarge, AX1, AX2) and " bold" with Bold Text: a More row by
    /// its title's key ("medication.title AX2 bold", a break no line shows as
    /// "medication.title unseen break AX2"), Settings' baby row as
    /// "name Александра AX1" or "age with Mia AX2", and any element past the
    /// screen's edges as "more edges AX2" or "settings edges with Mia AX2".
    private static let knownMisses: [KnownMiss] = [
        KnownMiss(.pseudo(.enXA), "medication.title AX2", width: 223.7, room: 183.7),
        KnownMiss(.pseudo(.enXA), "medication.title AX2 bold", width: 237.7, room: 194.3),
        KnownMiss(.pseudo(.enXA), "medication.title AX1 bold", width: 237.7, room: 194.3),
        // Under its icon at AX2 the title is set at the AX1 size: its widest
        // unit there is exactly the row's width, and the line still wraps.
        KnownMiss(.pseudo(.enXA), "report.title AX2", width: 198.3, room: 198.3),
        KnownMiss(.pseudo(.enXA), "report.title AX2 bold", width: 212.0, room: 212.0),
    ]

    /// Each key checked in a run, with its misses: a key is judged once,
    /// against its known-miss row, after every place it shows was read.
    private var checked: [FitLanguage: [String: [String]]] = [:]

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
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
        // Every row has the same room beside its icon in every language, so
        // a word drawn whole there shows that room for the rest of the size.
        var roomShown: CGFloat = 0
        var unseenBreaks: [(language: FitLanguage, key: String, title: String, word: String, width: CGFloat)] = []
        for language in FitLanguage.all {
            var regularEvents: CGFloat?
            for bold in [false, true] {
                language.apply()
                let qualifier = "\(sizeName(size))\(bold ? " bold" : "")"
                let run = "\(language) \(qualifier)"
                let (spoken, drawn) = try moreTab(bold: bold, language: language, key: "more edges \(qualifier)")
                let line = lineHeight(.body, bold: bold)
                var beside: [(title: String, word: CGFloat)] = []
                var under: [(title: String, word: CGFloat)] = []
                for key in rowKeys {
                    let title = key.l
                    let fitKey = "\(key) \(qualifier)"
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
                    var miss: String?
                    if isBeside {
                        // Beside, the title has at least its widest word's
                        // room, so it takes no more lines than it does at
                        // exactly that room. A broken word takes a line more,
                        // which a count of words can miss: «Para el / pedia /
                        // tra» is three lines for three words.
                        let whole = height(title, .body, bold: bold, width: word.1 + 0.5)
                        let lines = (whole / line).rounded()
                        if text.frame.height >= (lines + 0.5) * line {
                            miss = "widest unit «\(word.0)» \(points(word.1)) in \(points(text.frame.width)) beside "
                                + "its icon: \(points(text.frame.height)) tall for \(lines) line(s) of \(points(line))"
                        } else if size == .accessibilityLarge, word.1 > underRoomAtAX2 {
                            miss = "widest unit «\(word.0)» \(points(word.1)) in \(points(underRoomAtAX2)) "
                                + "stays beside its icon"
                        }
                        // Where the broken word's tail joins the next word's
                        // line («Недавни / е записи»), the lines cannot tell:
                        // that word is held to the room another shows.
                        if height(title, .body, bold: bold, width: word.1 - 1) > whole {
                            roomShown = max(roomShown, word.1)
                        } else {
                            // Its own key: a row listed for the line check
                            // must not hide this one.
                            unseenBreaks.append((language, "\(key) unseen break \(qualifier)", title, word.0, word.1))
                        }
                        beside.append((title, word.1))
                    } else if size == .accessibilityLarge, word.1 > underRoomAtAX2 {
                        // Wider than the whole row at the reader's size: set at
                        // the AX1 size, one line, whole.
                        let stepped = wordWidth(word.0, .body, bold: bold, at: .accessibility1)
                        if text.frame.width + 0.5 < stepped {
                            miss = "widest unit «\(word.0)» \(points(stepped)) at AX1 in \(points(text.frame.width))"
                        } else if text.frame.height >= line {
                            miss = "widest unit «\(word.0)» \(points(stepped)) at AX1 in \(points(text.frame.width)): "
                                + "not one line under the reader's size"
                        }
                        under.append((title, word.1))
                    } else {
                        if text.frame.width + 0.5 < word.1 {
                            miss = "widest unit «\(word.0)» \(points(word.1)) in \(points(text.frame.width))"
                        }
                        under.append((title, word.1))
                    }
                    record(language, fitKey, miss)
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
        for unseen in unseenBreaks where unseen.width > roomShown + 0.5 {
            record(unseen.language, unseen.key,
                   "a broken «\(unseen.word)» (\(points(unseen.width))) would not add a line to «\(unseen.title)», "
                   + "and no unit as wide is drawn whole beside an icon at this size: widest unit "
                   + "\(points(unseen.width)) in \(points(roomShown))")
        }
        assertRecorded()
    }

    /// nil where the widest word lands within a few points of the room beside
    /// the icon: there only the words and the order are checked. Below the
    /// accessibility sizes every title fits beside (at xxxLarge the widest,
    /// es «Medicamentos», is 147 pt, 155 in Bold Text). At AX2 the room is
    /// 158.5 pt: en «pediatrician» (165.5) and «Medications» (173.7) and es
    /// «Crecimiento» (171.1) and «Medicamentos» (210.3) miss it; ru
    /// «Лекарства» (158.7) sits on its edge and misses it in Bold Text
    /// (167.5), where «Недавние» (156.1) still fits.
    private func expectedUnder(_ key: String, language: FitLanguage, bold: Bool,
                               size: UIContentSizeCategory) -> Bool? {
        // The other languages' shape is not pinned: their words are held
        // whole, and a unit wider than the row under its icon goes under.
        guard pinned.contains(language) else { return nil }
        switch size {
        case .large, .extraExtraExtraLarge: return false
        case .accessibilityLarge:
            switch (language, key) {
            case (.real(.en), "report.title"), (.real(.en), "medication.title"),
                 (.real(.es), "nav.growth"), (.real(.es), "medication.title"): return true
            case (.real(.ru), "medication.title"): return bold ? true : nil
            default: return false
            }
        default: return nil
        }
    }

    /// The More tab with one baby: what VoiceOver reads, and every element
    /// with its own frame as UI tests see them.
    private func moreTab(bold: Bool, language: FitLanguage,
                         key: String) throws -> (spoken: [HostedAccessibility.Element],
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
        recordOnScreen(drawn, language, key)
        return (spoken, drawn)
    }

    // MARK: - Settings

    /// «Александра» is the long name; «Mia» leaves the age alone to decide.
    private func assertBabyRow(at size: UIContentSizeCategory) throws {
        for babyName in ["Александра", "Mia"] {
            for language in FitLanguage.all {
                for bold in [false, true] {
                    language.apply()
                    let qualifier = "\(sizeName(size))\(bold ? " bold" : "")"
                    let run = "\(language) \(babyName) \(qualifier)"
                    let (age, elements) = try settings(babyName: babyName, bold: bold, language: language,
                                                       key: "settings edges with \(babyName) \(qualifier)")
                    let nameText = try XCTUnwrap(elements.filter { $0.label == babyName }.min { $0.frame.width < $1.frame.width },
                                                 "\(run): «\(babyName)» is not in \(elements)")
                    let ageText = try XCTUnwrap(elements.filter { $0.label == age }.min { $0.frame.width < $1.frame.width },
                                                "\(run): «\(age)» is not in \(elements)")
                    let nameWord = widestWord(babyName, nameFont, bold: bold)
                    let ageWord = widestWord(age, ageFont, bold: bold)
                    print("BABY_ROW \(run): name x \(nameText.frame.minX) w \(nameText.frame.width) "
                          + "for «\(nameWord.0)» \(nameWord.1); age w \(ageText.frame.width) for «\(ageWord.0)» \(ageWord.1)")
                    record(language, "name \(babyName) \(qualifier)",
                           nameText.frame.width + 0.5 < nameWord.1
                               ? "widest unit «\(nameWord.0)» \(points(nameWord.1)) in \(points(nameText.frame.width))" : nil)
                    record(language, "age with \(babyName) \(qualifier)",
                           ageText.frame.width + 0.5 < ageWord.1
                               ? "widest unit «\(ageWord.0)» \(points(ageWord.1)) in \(points(ageText.frame.width))" : nil)
                    XCTAssertEqual(nameText.frame.minX, ageText.frame.minX, accuracy: 0.5,
                                   "\(run): the name and the age do not share their leading edge")
                    if let stacked = expectedBabyUnder(babyName, language: language, size: size) {
                        let beside = nameText.frame.minX > besideMinX
                        XCTAssertEqual(beside, !stacked,
                                       "\(run): the texts are \(beside ? "beside" : "under") the avatar at x \(nameText.frame.minX)")
                    }
                }
            }
        }
        assertRecorded()
    }

    /// nil where the texts land near the column beside the avatar. From
    /// xxxLarge «Александра» (150 pt there, 161 in Bold Text) misses the
    /// 120 pt beside the avatar; «Mia» and its age fit there below the
    /// accessibility sizes.
    private func expectedBabyUnder(_ babyName: String, language: FitLanguage, size: UIContentSizeCategory) -> Bool? {
        // «Александра» alone misses the column from xxxLarge in any language;
        // the other languages' ages are not pinned, their words are held whole.
        guard pinned.contains(language) else {
            return babyName == "Mia" || size == .large ? nil : true
        }
        switch size {
        case .large: return false
        case .extraExtraExtraLarge: return babyName != "Mia"
        default: return babyName == "Mia" ? nil : true
        }
    }

    /// Settings with one baby, read once it has settled, and the baby's age
    /// as the row draws it.
    private func settings(babyName: String, bold: Bool, language: FitLanguage,
                          key: String) throws -> (age: String, elements: [HostedAccessibility.Element]) {
        let container = try container(babyName: babyName)
        let baby = try XCTUnwrap(try container.mainContext.fetch(FetchDescriptor<Baby>()).first)
        let view = NavigationStack { ProfileView() }
            .environment(SubscriptionManager())
            .modelContainer(container)
        let root = try accessibility.host(view, size: screen, bold: bold)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let elements = accessibility.elements(root, automation: true)
        accessibility.close()
        recordOnScreen(elements, language, key)
        return (baby.ageDescription, elements)
    }

    private var nameFont: Font { BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded) }
    private var ageFont: Font { BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded) }

    // MARK: - Helpers

    private func container(babyName: String) throws -> ModelContainer {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let baby = Baby(name: babyName, birthDate: Date().addingTimeInterval(-90 * 86_400),
                        gender: .female, feedingType: .breast)
        container.mainContext.insert(baby)
        try container.mainContext.save()
        return container
    }

    private func recordOnScreen(_ elements: [HostedAccessibility.Element], _ language: FitLanguage, _ key: String) {
        record(language, key, nil)
        for element in elements {
            if element.frame.minX < -0.5 {
                record(language, key, "\(element) left edge \(points(element.frame.minX)) in \(points(screen.width))")
            }
            if element.frame.maxX > screen.width + 0.5 {
                record(language, key, "\(element) right edge \(points(element.frame.maxX)) in \(points(screen.width))")
            }
        }
    }

    /// Notes that `key` was checked, with a miss when there was one.
    private func record(_ language: FitLanguage, _ key: String, _ miss: String?) {
        checked[language, default: [:]][key, default: []].append(contentsOf: miss.map { [$0] } ?? [])
    }

    /// Fails on every miss of an unlisted key, and on a listed key that no
    /// longer misses anywhere.
    private func assertRecorded() {
        for (language, keys) in checked {
            for (key, misses) in keys {
                if KnownMiss.listed(Self.knownMisses, language, key) {
                    XCTAssertFalse(misses.isEmpty, "\(language) \(key) fits now: remove its known-miss row")
                } else {
                    for miss in misses { XCTFail("\(language) \(key): \(miss)") }
                }
            }
        }
        checked = [:]
    }

    private func sizeName(_ size: UIContentSizeCategory) -> String {
        switch size {
        case .large: "Large"
        case .extraExtraExtraLarge: "xxxLarge"
        case .accessibilityMedium: "AX1"
        case .accessibilityLarge: "AX2"
        default: size.rawValue
        }
    }

    private func points(_ value: CGFloat) -> String {
        String(format: "%.1f", value)
    }

    /// The pieces a line cannot break inside; a no-break space keeps a
    /// number with its unit. Measured at the device's size, as below.
    private func widestWord(_ text: String, _ font: Font, bold: Bool) -> (String, CGFloat) {
        text.lineBreakUnits
            .map { ($0, wordWidth($0, font, bold: bold)) }
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

    /// The text wrapped at `width`; narrower than a word, it breaks the word.
    private func height(_ text: String, _ font: Font, bold: Bool, width: CGFloat) -> CGFloat {
        let device = DynamicTypeSize(UIApplication.shared.preferredContentSizeCategory) ?? .large
        let view = Text(text).font(font)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: width)
            .environment(\.legibilityWeight, bold ? .bold : .regular)
            .environment(\.dynamicTypeSize, device)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
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

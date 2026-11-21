import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// The weekly card's gain notes and their weighing button keep every word
/// whole in a 320-pt phone's card (256 pt), in every language, at AX2, the
/// app's text-size cap (where Finnish left its final period alone on a line).
/// The words are set at AX2 through the font's test seam and the glyph by the
/// environment, whatever size the simulator runs.
///
/// A text laid out narrower than its widest word has broken that word. The
/// notes stand side by side in one window per language and are read from the
/// accessibility tree.
@MainActor
final class WeeklyGainNoteWordFitTests: XCTestCase {

    private let accessibility = HostedAccessibility()
    private static let room: CGFloat = 256
    private static let gap: CGFloat = 64
    private static let category = UIContentSizeCategory.accessibilityLarge

    /// Each note, and whether its next step is a weighing.
    private static let notes: [(key: String, asksForWeighing: Bool)] = [
        ("weekly.gain_newborn", false),
        ("weekly.gain_next_monday", false),
        ("weekly.gain_needs_weighing", true),
        ("weekly.gain_needs_second", true),
        ("weekly.gain_needs_two", true),
    ]

    override func tearDown() {
        accessibility.close()
        FitLanguage.restore()
        super.tearDown()
    }

    func testEveryGainNoteKeepsWordsWholeOnA320PhoneAtAX2() throws {
        var misses: [String] = []
        for language in FitLanguage.all {
            language.apply()
            try autoreleasepool { misses += try judge(language) }
        }
        XCTAssert(misses.isEmpty, "\(misses.count) misses at AX2:\n" + misses.joined(separator: "\n"))
    }

    private func judge(_ language: FitLanguage) throws -> [String] {
        defer { accessibility.close() }
        let notes = Self.notes
        let column = Self.room + Self.gap
        let scene = HStack(alignment: .top, spacing: Self.gap) {
            ForEach(notes.indices, id: \.self) { index in
                WeeklyGainNote(text: notes[index].key.l, onAddWeighing: notes[index].asksForWeighing ? {} : nil,
                                category: Self.category)
                    .frame(width: Self.room, alignment: .leading)
            }
        }
        .padding(.leading, Self.gap / 2)
        .frame(width: column * CGFloat(notes.count), height: 1600, alignment: .topLeading)
        .environment(\.dynamicTypeSize, .accessibility2)
        .appLanguageEnvironment(language.base)
        let root = try accessibility.host(scene, size: CGSize(width: column * CGFloat(notes.count), height: 1600))
        let elements = accessibility.elements(root)

        let body = BBTheme.Typography.scaled(16, relativeTo: .callout, weight: .regular, for: Self.category)
        let button = BBTheme.Typography.scaled(16, relativeTo: .callout, weight: .semibold, for: Self.category)
        var misses: [String] = []
        for (index, note) in notes.enumerated() {
            let span = CGFloat(index) * column ..< CGFloat(index + 1) * column
            let inColumn = elements.filter { span.contains($0.frame.midX) }
            var texts = [(note.key.l, body, note.key)]
            if note.asksForWeighing { texts.append(("growth.add_weighing".l, button, "growth.add_weighing")) }
            for (text, font, key) in texts {
                guard let element = inColumn.first(where: { $0.label == text }) else {
                    misses.append("\(language) \(key): not drawn")
                    continue
                }
                // A word that holds a hyphen may break after it: its parts
                // are what must stay whole.
                let widest = text.lineBreakUnits
                    .flatMap { $0.replacingOccurrences(of: "-", with: "-\n").split(separator: "\n").map(String.init) }
                    .map { ($0, FitMeasure.wordWidth($0, font: font, locale: language.environmentLocale)) }
                    .max { $0.1 < $1.1 } ?? ("", 0)
                if element.frame.width + 0.5 < widest.1 {
                    misses.append(String(format: "%@ %@: «%@» %.1f in %.1f", "\(language)", key, widest.0,
                                         widest.1, element.frame.width))
                }
            }
        }
        return misses
    }
}

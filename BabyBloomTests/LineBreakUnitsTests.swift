import XCTest
@testable import BabyBloom

/// The unbreakable pieces a widest-word measure reads: unchanged for the
/// scripts that write spaces, line-break runs for Chinese and Japanese.
final class LineBreakUnitsTests: XCTestCase {

    /// Every shipped value parts exactly as the plain-space split did, so no
    /// en, ru or es measure moves.
    func testShippedLanguagesPartAtSpacesAsBefore() throws {
        for language in SupportedLanguage.available {
            let table = try PseudoLanguageTests.json(language.rawValue)
            for (key, value) in table {
                XCTAssertEqual(value.lineBreakUnits,
                               value.split(separator: " ").map(String.init), "\(language.rawValue) \(key)")
            }
        }
    }

    func testANoBreakSpaceKeepsItsPair() {
        XCTAssertEqual("12\u{00A0}times a day".lineBreakUnits,
                       ["12\u{00A0}times", "a", "day"])
    }

    func testJapaneseBreaksInsideASentence() {
        let units = "今日は赤ちゃんがよく眠りました。".lineBreakUnits
        XCTAssertGreaterThan(units.count, 1)
        XCTAssertEqual(units.joined(), "今日は赤ちゃんがよく眠りました。")
    }

    /// Between characters, as Core Text wraps Japanese, never by dictionary
    /// phrase ("今日" / "赤ちゃん"), which would measure wider than any line
    /// the screen draws. A small kana stays with the character before it.
    func testJapaneseBreaksBetweenCharactersLikeTheScreen() {
        XCTAssertEqual("今日は赤ちゃん".lineBreakUnits, ["今", "日", "は", "赤", "ちゃ", "ん"])
    }

    /// Kinsoku: no piece starts with a closing mark or small kana, none ends
    /// with an opening bracket.
    func testNoPieceBreaksAKinsokuRule() throws {
        let english = try PseudoLanguageTests.json("en")
        let samples = ["「ちょっと待って」、と言った。", "ミルク（１２０ｍｌ）を飲んだ！"]
            + PseudoLanguage.table(from: english, .jaXB).values
        for text in samples {
            let units = text.lineBreakUnits
            XCTAssertEqual(units.joined(), text.replacingOccurrences(of: " ", with: ""))
            for unit in units.dropFirst() {
                XCTAssertFalse("、。，．：；？！」』）ゃゅょっー）".contains(unit.first!), "\(text): \(unit)")
            }
            for unit in units.dropLast() {
                XCTAssertFalse("「『（（".contains(unit.last!), "\(text): \(unit)")
            }
        }
    }

    func testJaXBIsNotOneWord() {
        let units = PseudoLanguage.jaXB.transform("Log a feed").lineBreakUnits
        XCTAssertGreaterThan(units.count, 1)
    }
}

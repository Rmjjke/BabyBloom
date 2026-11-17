import Foundation

extension String {
    /// The pieces a line can never break inside, in order: what a
    /// widest-word measure must measure.
    ///
    /// Words part at plain spaces, as before, and a no-break space keeps a
    /// number with its unit. A piece holding Chinese or Japanese characters,
    /// which put no spaces between words, is cut further at the line-break
    /// opportunities of the Unicode rules, so a Japanese sentence is not
    /// measured as one unbreakable word. Other scripts are never handed to the
    /// line breaker: it would also cut "e-mail" at the hyphen, and their
    /// measures are pinned.
    var lineBreakUnits: [String] {
        split(separator: " ").flatMap { piece -> [String] in
            let text = String(piece)
            return text.unicodeScalars.contains(where: Self.isCJK) ? Self.lineBreakPieces(text) : [text]
        }
    }

    /// Han, kana, CJK punctuation and the full-width forms.
    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF: true
        default: false
        }
    }

    /// No line starts with these (kinsoku): closing marks, small kana, the
    /// prolonged sound mark.
    private static let noLineStart = Set("、。，．・：；？！ー」』）】〕〉》ゝゞぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ々）］｝")
    /// No line ends with these: opening brackets.
    private static let noLineEnd = Set("「『（【〔〈《（［｛")

    /// The tokenizer's locale is fixed, not the app's: under "ja" it segments
    /// by dictionary phrases, while Core Text wraps Japanese between any two
    /// characters the kinsoku rules allow. The plain Unicode breaks are the
    /// ones the screen shows.
    private static let breakLocale = Locale(identifier: "en")

    private static func lineBreakPieces(_ text: String) -> [String] {
        let cf = text as CFString
        let length = CFStringGetLength(cf)
        let tokenizer = CFStringTokenizerCreate(nil, cf, CFRange(location: 0, length: length),
                                                kCFStringTokenizerUnitLineBreak, breakLocale as CFLocale)
        // Cut at every token start rather than keep the tokens themselves, so
        // nothing between two tokens is lost.
        var cuts: [Int] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let start = CFStringTokenizerGetCurrentTokenRange(tokenizer).location
            if start > 0 { cuts.append(start) }
        }
        let utf16 = Array(text.utf16)
        var pieces: [String] = []
        var from = 0
        for cut in cuts + [length] where cut > from {
            pieces.append(String(decoding: utf16[from..<cut], as: UTF16.self))
            from = cut
        }
        // The line breaker already keeps most of these together; the glue
        // makes it hold for every OS version the measure runs on.
        var glued: [String] = []
        for piece in pieces {
            if let last = glued.last,
               piece.first.map(noLineStart.contains) == true || last.last.map(noLineEnd.contains) == true {
                glued[glued.count - 1] = last + piece
            } else {
                glued.append(piece)
            }
        }
        return glued
    }
}

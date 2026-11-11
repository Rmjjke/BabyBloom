import Foundation

/// Two made-up languages built from English, so layouts meet long Latin text
/// and a script without spaces before any real translation exists.
///
/// They are never `SupportedLanguage` cases: a case would reach the language
/// picker, the plural table, the widget's exhaustive switches and the lint's
/// list of complete languages. A debug simulator build turns one on with
/// `-BBPseudoLanguage en-XA|ja-XB`; tests build the same tables directly.
enum PseudoLanguage: String, CaseIterable, Sendable {
    /// About 40 % longer per word, accented, bracketed: stands in for German
    /// or Finnish, whose long compounds are what break a widest-word fit.
    case enXA = "en-XA"
    /// Full-width, no spaces, in corner brackets: stands in for Japanese, so
    /// line breaking, kinsoku and the CJK typesetting paths run.
    case jaXB = "ja-XB"

    /// The real language behind the plural rule, the locale and typesetting.
    var base: SupportedLanguage {
        switch self {
        case .enXA: .en
        case .jaXB: .ja
        }
    }

    /// Every value of `english` through `transform`. Plural families keep their
    /// keys, so ja-XB (rule: other only) reads English's `.other` templates.
    static func table(from english: [String: String], _ language: PseudoLanguage) -> [String: String] {
        english.mapValues(language.transform)
    }

    /// One value in this language. Format specifiers and `{token}`s pass
    /// through byte-equal, so arguments and the brand still fill in.
    func transform(_ value: String) -> String {
        var out = ""
        for (text, isProtected) in Self.spans(value) {
            out += isProtected ? text : rewrite(text)
        }
        switch self {
        case .enXA: return "[" + out + "]"
        case .jaXB: return "「" + out + "」"
        }
    }

    private func rewrite(_ text: String) -> String {
        switch self {
        case .enXA: return Self.lengthenedWords(text)
        case .jaXB: return Self.fullWidth(text)
        }
    }

    // MARK: Spans

    /// `%@`, `%d`, `%1$@`, `%.1f`, `%lld`, `%%` and `{brand}`-style tokens.
    /// The same specifier grammar as the localization lint, without the
    /// space flag: "10% over" is prose, not a `% o`.
    private static let protectedPattern = try! NSRegularExpression(
        pattern: #"%(?:%|(?:\d+\$)?[-+0#']*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j|L)?[@dDiuUxXoOfFeEgGaAcCsSp])|\{[A-Za-z_]+\}"#
    )

    /// `value` cut into runs, each marked protected or not, in order.
    static func spans(_ value: String) -> [(String, Bool)] {
        let ns = value as NSString
        var result: [(String, Bool)] = []
        var cursor = 0
        for match in protectedPattern.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                result.append((ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor)), false))
            }
            result.append((ns.substring(with: match.range), true))
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { result.append((ns.substring(from: cursor), false)) }
        return result
    }

    // MARK: en-XA

    private static let accents: [Character: Character] = [
        "a": "á", "e": "é", "i": "í", "o": "ö", "u": "ü", "y": "ý", "c": "ç", "n": "ñ", "s": "š", "z": "ž",
        "A": "Å", "E": "É", "I": "Í", "O": "Ö", "U": "Ü", "Y": "Ý", "C": "Ç", "N": "Ñ", "S": "Š", "Z": "Ž",
    ]
    private static let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y", "A", "E", "I", "O", "U", "Y"]

    /// Each run of ASCII letters grows by ⌈0.4 × its length⌉ letters, by
    /// doubling its vowels in turn (its letters when it has none), then the
    /// letters take accents. The word grows, not the line, because a long word
    /// is what breaks a widest-word fit.
    private static func lengthenedWords(_ text: String) -> String {
        var out = ""
        var word: [Character] = []
        func flush() {
            guard !word.isEmpty else { return }
            out += String(lengthened(word).map { accents[$0] ?? $0 })
            word.removeAll()
        }
        for ch in text {
            if ch.isASCII && ch.isLetter { word.append(ch) } else { flush(); out.append(ch) }
        }
        flush()
        return out
    }

    private static func lengthened(_ word: [Character]) -> [Character] {
        let extra = Int((Double(word.count) * 0.4).rounded(.up))
        var slots = word.indices.filter { vowels.contains(word[$0]) }
        if slots.isEmpty { slots = Array(word.indices) }
        var copies = [Int](repeating: 1, count: word.count)
        for n in 0..<extra { copies[slots[n % slots.count]] += 1 }
        return word.indices.flatMap { Array(repeating: word[$0], count: copies[$0]) }
    }

    // MARK: ja-XB

    /// Printable ASCII to its full-width form (U+FF01…FF5E), plain spaces
    /// dropped. A no-break space stays: it still glues a number to its word.
    private static func fullWidth(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x20: continue
            case 0x21...0x7E: scalars.append(Unicode.Scalar(scalar.value + 0xFEE0)!)
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }
}

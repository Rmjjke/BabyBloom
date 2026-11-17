import Foundation

extension String {
    /// A no-break space after every digit that a space follows: «7 ч 42 мин»
    /// keeps each number on its unit's line, and the break between the parts
    /// stays (DECISIONS 2026-11-06). Here, not in Core/Formatting, because the
    /// widget compiles Core/Localization and shares the duration keys.
    var gluingNumbersToUnits: String {
        replacingOccurrences(of: #"(\d) "#, with: "$1\u{00A0}", options: .regularExpression)
    }

    /// A word joiner between a digit and the Han, kana or Hangul counter that
    /// follows it: ja «11月3日», ko «11월 2일» and zh-Hant «2026年11月» never
    /// break after the number. Japanese and Chinese break between any two
    /// ideographs, so a formatter's «11月» could end a line at «11». The breaks
    /// after a counter, after a range's dash and between 年 and the month stay.
    /// Applying it twice changes nothing: a joined digit is followed by the
    /// joiner.
    var gluingNumbersToCounters: String {
        replacingOccurrences(of: #"(\d)(?=[\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}])"#,
                             with: "$1\u{2060}", options: .regularExpression)
    }
}

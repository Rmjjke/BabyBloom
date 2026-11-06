import Foundation

extension String {
    /// A no-break space after every digit that a space follows: «7 ч 42 мин»
    /// keeps each number on its unit's line, and the break between the parts
    /// stays (DECISIONS 2026-11-06). Here, not in Core/Formatting, because the
    /// widget compiles Core/Localization and shares the duration keys.
    var gluingNumbersToUnits: String {
        replacingOccurrences(of: #"(\d) "#, with: "$1\u{00A0}", options: .regularExpression)
    }
}

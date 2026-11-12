import Foundation

/// A number and its unit as one template per language, so the translation
/// places the unit and the space: a language may write none, as Japanese,
/// Korean and Chinese do, or put the unit first. A digit that a space follows
/// is glued to it, so a number-first pair never breaks across lines.
enum Units {
    static func kg(_ number: String) -> String { format("unit.kg_fmt".l, number) }
    static func g(_ number: String) -> String { format("unit.g_fmt".l, number) }
    static func cm(_ number: String) -> String { format("unit.cm_fmt".l, number) }
    static func ml(_ number: String) -> String { format("unit.ml_fmt".l, number) }

    static func format(_ template: String, _ number: String) -> String {
        String(format: template, number).gluingNumbersToUnits
    }
}

import Foundation

/// The CLDR plural categories. A language uses a subset; `.other` is in every
/// language and is the fallback for a category a family leaves out.
enum PluralCategory: String, CaseIterable, Sendable {
    case zero, one, two, few, many, other
}

/// The CLDR operands of a number as it is shown: n (absolute value), i (integer
/// digits), v (count of visible fraction digits), f (visible fraction digits as
/// an integer), t (f without trailing zeros). "1.0" and "1" differ: v = 1 makes
/// Russian read «1,0 коридора», not «1,0 коридор».
struct PluralOperands: Equatable, Sendable {
    let n: Double
    let i: Int
    let v: Int
    let f: Int
    let t: Int

    init(_ value: Int) {
        let magnitude = value.magnitude
        n = Double(magnitude)
        i = Int(magnitude)
        v = 0
        f = 0
        t = 0
    }

    /// The operands of `value` shown with `fractionDigits` digits. The digits
    /// come from the same rounding `Double.appDecimal` applies, so 0.96 shown as
    /// «1,0» is the 1.0 row, never the 0.96 row.
    init(_ value: Double, fractionDigits: Int) {
        self.init(posix: Self.posixString(value, fractionDigits: fractionDigits))
    }

    /// Reads "21", "1.0", "1.50" (a period, Latin digits).
    init(posix text: String) {
        let parts = text.trimmingCharacters(in: CharacterSet(charactersIn: "-")).split(separator: ".", omittingEmptySubsequences: false)
        let integer = parts.first.map(String.init) ?? "0"
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        let trimmed = String(fraction.reversed().drop { $0 == "0" }.reversed())
        i = Int(integer) ?? 0
        v = fraction.count
        f = Int(fraction) ?? 0
        t = Int(trimmed) ?? 0
        n = Double("\(integer).\(fraction.isEmpty ? "0" : fraction)") ?? Double(i)
    }

    /// The digits `appDecimal` shows, written in POSIX form. Same style, digit
    /// counts and (default) rounding mode; only the locale differs, and no
    /// shipped language writes other than Latin digits.
    static func posixString(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSNumber) ?? String(format: "%.\(fractionDigits)f", value)
    }
}

extension SupportedLanguage {
    /// The CLDR cardinal rule of the language (unicode.org/cldr plurals.xml).
    /// The exponent operand e is always 0 here: the app never shows compact
    /// numbers ("1,2 млн"), so the rules drop it.
    func pluralCategory(_ x: PluralOperands) -> PluralCategory {
        switch self {
        case .en, .de, .sv, .fi:
            return x.i == 1 && x.v == 0 ? .one : .other
        case .ptPT:
            if x.i == 1 && x.v == 0 { return .one }
            return Self.isWholeMillions(x) ? .many : .other
        case .es:
            if x.n == 1 { return .one }
            return Self.isWholeMillions(x) ? .many : .other
        case .fr, .ptBR:
            // 0 takes the singular: «0 dose», «0 dia».
            if x.i == 0 || x.i == 1 { return .one }
            return Self.isWholeMillions(x) ? .many : .other
        case .nb:
            return x.n == 1 ? .one : .other
        case .da:
            // «1,5 dag»: a fraction with i = 0 or 1 is singular in Danish.
            return x.n == 1 || (x.t != 0 && (x.i == 0 || x.i == 1)) ? .one : .other
        case .ru, .uk:
            // Any visible fraction is .other: «1,5 дня», «1,0 коридора».
            guard x.v == 0 else { return .other }
            let mod10 = x.i % 10, mod100 = x.i % 100
            if mod10 == 1 && mod100 != 11 { return .one }
            if (2...4).contains(mod10) && !(12...14).contains(mod100) { return .few }
            return .many
        case .ja, .ko, .zhHant:
            return .other
        }
    }

    /// Every category the language's rule can select, `.other` included.
    var pluralCategories: Set<PluralCategory> {
        switch self {
        case .en, .de, .sv, .fi, .nb, .da: return [.one, .other]
        case .es, .fr, .ptBR, .ptPT: return [.one, .many, .other]
        case .ru, .uk: return [.one, .few, .many, .other]
        case .ja, .ko, .zhHant: return [.other]
        }
    }

    private static func isWholeMillions(_ x: PluralOperands) -> Bool {
        x.v == 0 && x.i != 0 && x.i % 1_000_000 == 0
    }
}

/// Every counted phrase the app shows: a family of keys `<name>.<category>`,
/// each value a whole template with its number inside (`%d⍽день`). Code passes
/// the bare number and never adds a space or a word of its own. A family whose
/// sentence holds more than the counted number (`arguments`) is read through
/// `template(_:)` and filled by its caller.
enum PluralFamily: String, CaseIterable, Sendable {
    case ageDays = "age.days"
    case ageWeeks = "age.weeks"
    case ageMonths = "age.months"
    case durationDays = "duration.days"
    case premiumCtaTrial = "premium.cta_trial"
    case velocityInterval = "velocity.interval"
    case historyFreeWindow = "history.free_window"
    case trendDrop = "trend.drop"
    case medicationDoseCount = "medication.dose_count"
    case questionCount = "question.count"
    /// «0 of the 4 you set»: the category follows the prescribed number, the
    /// second argument; the first is the dose count, already a phrase.
    case medicationCount24h = "medication.count_24h"

    /// What the template's one argument is: an Int (`%d`), or a decimal shown
    /// with this many fraction digits and passed as text (`%@`).
    enum Kind: Equatable, Sendable {
        case integer
        case decimal(fractionDigits: Int)
    }

    var kind: Kind {
        switch self {
        case .trendDrop: return .decimal(fractionDigits: 1)
        default: return .integer
        }
    }

    /// The arguments every value of the family takes, as the language lint
    /// writes them: position and conversion.
    var arguments: [String] {
        switch self {
        case .medicationCount24h: return ["1@", "2d"]
        default: return kind == .integer ? ["1d"] : ["1@"]
        }
    }

    /// The template the language's rule picks for `count`, unfilled.
    func template(_ count: Int) -> String {
        LocalizationManager.shared.pluralTemplate(self, PluralOperands(count))
    }

    func key(_ category: PluralCategory) -> String { "\(rawValue).\(category.rawValue)" }

    /// "21 день", "3 days": the family's template for `count`, filled.
    func text(_ count: Int) -> String {
        String(format: template(count), count)
    }

    /// "1,5": the decimal as `appDecimal` shows it, in the template its
    /// operands select.
    func text(_ value: Double) -> String {
        guard case .decimal(let digits) = kind else { return text(Int(value.rounded())) }
        let shown = value.appDecimal(digits)
        let template = LocalizationManager.shared.pluralTemplate(self, PluralOperands(value, fractionDigits: digits))
        return String(format: template, shown)
    }
}

extension LocalizationManager {
    /// The language's category, else its `.other` (a category the copy leaves
    /// out on purpose: Spanish `.many` is whole millions, which no day count
    /// reaches), else English's category for the same number, else English's
    /// `.other`, else the key — what a missing string looks like elsewhere.
    static func pluralTemplate(_ family: PluralFamily, _ operands: PluralOperands, language: SupportedLanguage,
                               in table: [String: String], english: [String: String]) -> String {
        if let value = table[family.key(language.pluralCategory(operands))] ?? table[family.key(.other)] {
            return value
        }
        return english[family.key(SupportedLanguage.en.pluralCategory(operands))]
            ?? english[family.key(.other)]
            ?? family.key(.other)
    }
}

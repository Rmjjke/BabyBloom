import Foundation

/// One argument of a printf-style format: its position (1-based) and its
/// conversion ("@", "d", "ld"…).
struct FormatArgument: Equatable, Sendable {
    let position: Int
    let conversion: String
}

/// A localized format cut at one of its arguments, so a screen or the PDF can
/// set that value in its own style while the word order stays the
/// translator's: «Since 28 Oct: **+320 g**» in English and «**+320 g** desde
/// el 28 oct.» read right from the same code.
///
/// The cut follows the argument's number, not its place in the text, so a
/// translation that swaps `%1$@` and `%2$@` still bolds the right value. The
/// other arguments are filled first, and `%%` comes out as one percent sign.
struct FormatSplit: Equatable, Sendable {
    /// The text before the value.
    let head: String
    /// The text after it, with the value itself wherever the format repeats it.
    let tail: String

    /// nil when the format has no argument at `position`, or fewer `filling`
    /// values than its other arguments.
    /// - Parameters:
    ///   - position: the styled argument's number (1-based).
    ///   - value: the styled value, written into the tail where the format
    ///     uses the same argument again.
    ///   - others: the other arguments, in their numbers' order.
    init?(_ format: String, at position: Int = 1, value: String = "", filling others: [any CVarArg] = []) {
        let arguments = Self.arguments(in: format)
        guard arguments.contains(where: { $0.position == position }) else { return nil }
        let count = arguments.map(\.position).max() ?? 0
        guard others.count >= count - 1 else { return nil }

        // Every specifier written with its number, the styled one as a string,
        // so String(format:) puts the marker exactly where the translator did.
        var positional = ""
        var cursor = format.startIndex
        var sequential = 0
        for match in Self.specifiers(in: format) {
            positional += format[cursor..<match.range.lowerBound]
            cursor = match.range.upperBound
            guard let conversion = match.conversion else {
                positional += "%%"
                continue
            }
            let number = match.number ?? { sequential += 1; return sequential }()
            positional += number == position ? "%\(number)$@" : "%\(number)$\(match.flags)\(conversion)"
        }
        positional += format[cursor...]

        // A filler is text the user may have typed (a name): the marker is
        // taken out of it so the cut lands only at the styled argument.
        var values: [any CVarArg] = []
        var rest = others.map { ($0 as? String)?.replacingOccurrences(of: Self.marker, with: "") ?? $0 }
            .makeIterator()
        for number in 1...count {
            if number == position {
                values.append(Self.marker)
            } else if let next = rest.next() {
                values.append(next)
            }
        }
        let parts = String(format: positional, arguments: values).components(separatedBy: Self.marker)
        guard parts.count > 1 else { return nil }
        head = parts[0]
        tail = parts.dropFirst().joined(separator: value)
    }

    /// Every argument the format takes, by number, each once: `%@ at %@` and
    /// `%2$@ — %1$@` both take 1 and 2.
    static func arguments(in format: String) -> [FormatArgument] {
        var sequential = 0
        var seen: [Int: String] = [:]
        for match in specifiers(in: format) {
            guard let conversion = match.conversion else { continue }
            let number = match.number ?? { sequential += 1; return sequential }()
            if seen[number] == nil { seen[number] = conversion }
        }
        return seen.keys.sorted().map { FormatArgument(position: $0, conversion: seen[$0] ?? "") }
    }

    // MARK: - Scanning

    /// A private-use character no copy contains.
    private static let marker = "\u{E000}"

    private struct Specifier {
        let range: Range<String.Index>
        /// The `n$` number, nil for an unnumbered specifier.
        let number: Int?
        let flags: String
        /// nil for `%%`.
        let conversion: String?
    }

    /// `%%`, or `%` [n$] [flags] [width] [.precision] [length] conversion —
    /// the subset of printf that Foundation formats. No space flag, as the
    /// language lint reads it: «10% of» is text, not `% o`.
    private static let pattern = try! NSRegularExpression(
        pattern: #"%(?:%|(?:([1-9][0-9]*)\$)?([-+#0']*[0-9]*(?:\.[0-9]+)?)((?:hh|h|ll|l|q|z|t|j|L)?[@dDiuUxXoOeEfFgGaAcCsSp]))"#)

    private static func specifiers(in format: String) -> [Specifier] {
        let range = NSRange(format.startIndex..., in: format)
        return pattern.matches(in: format, range: range).compactMap { match in
            guard let whole = Range(match.range, in: format) else { return nil }
            func group(_ index: Int) -> String? {
                Range(match.range(at: index), in: format).map { String(format[$0]) }
            }
            return Specifier(range: whole, number: group(1).flatMap { Int($0) },
                             flags: group(2) ?? "", conversion: group(3))
        }
    }
}

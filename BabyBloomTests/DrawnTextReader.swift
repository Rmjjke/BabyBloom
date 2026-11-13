import UIKit
import Vision

/// Reads the lines of text a hosted view actually drew, from a render of it.
///
/// SwiftUI gives no way to read a text's line breaks without changing them:
/// a custom `TextRenderer` or a `Text.LayoutKey` reader moves the text off
/// its plain drawing path, and inside a system `Label` at the accessibility
/// sizes the lines then break elsewhere. Text recognition on the plain
/// render sees what the reader sees, a drawn hyphen and a word cut without
/// one alike.
enum DrawnTextReader {
    struct Line: CustomStringConvertible {
        let text: String
        /// In the rendered view's points, origin top left.
        let frame: CGRect
        var description: String { String(format: "«%@» y %.0f x %.0f", text, frame.minY, frame.minX) }
    }

    /// The view as drawn, at `scale` pixels a point. The view must stay under
    /// 8192 px a side at the screen's scale, or it draws all black.
    @MainActor
    static func render(_ view: UIView, scale: CGFloat) -> CGImage? {
        view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }.cgImage
    }

    /// The recognised lines of `rect` (in points) of an image rendered at
    /// `scale`, top to bottom, framed in that rect's own points. A tall column
    /// is read in bands cut where no text is: the recogniser shrinks a tall
    /// image and then misses short lines.
    static func lines(in image: CGImage, rect: CGRect, scale: CGFloat, languages: [String]) throws -> [Line] {
        let pixels = CGRect(x: rect.minX * scale, y: rect.minY * scale,
                            width: rect.width * scale, height: rect.height * scale).integral
        guard let crop = image.cropping(to: pixels) else { return [] }
        var result: [Line] = []
        for band in bands(of: crop, maxHeight: Int(1200 * scale), slack: Int(300 * scale)) {
            guard let piece = crop.cropping(to: CGRect(x: 0, y: band.lowerBound, width: crop.width, height: band.count)) else { continue }
            let top = CGFloat(band.lowerBound) / scale
            result += try recognise(piece, scale: scale, languages: languages).map {
                Line(text: $0.text, frame: $0.frame.offsetBy(dx: 0, dy: top))
            }
        }
        return result
    }

    /// `lines(in:rect:…)` for each of `rects`, read side by side: each read
    /// takes a while and they share nothing.
    static func lines(in image: CGImage, rects: [CGRect], scale: CGFloat, languages: [String]) throws -> [[Line]] {
        let results = Results(count: rects.count)
        DispatchQueue.concurrentPerform(iterations: rects.count) { index in
            // A worker thread's pool drains late: each read's crops and
            // recognition buffers go with the read.
            autoreleasepool {
                results.set(index, Result { try lines(in: image, rect: rects[index], scale: scale, languages: languages) })
            }
        }
        return try results.values.map { try $0!.get() }
    }

    private final class Results: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var values: [Result<[Line], Error>?]
        init(count: Int) { values = Array(repeating: nil, count: count) }
        func set(_ index: Int, _ value: Result<[Line], Error>) { lock.withLock { values[index] = value } }
    }

    private static func recognise(_ image: CGImage, scale: CGFloat, languages: [String]) throws -> [Line] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Correction would mend the very cuts the reader is there to see.
        request.usesLanguageCorrection = false
        // The language's own model goes first: it reads that alphabet best.
        request.recognitionLanguages = languages
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        let size = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return (request.results ?? []).compactMap { observation -> Line? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            let frame = CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                               width: box.width * size.width, height: box.height * size.height)
            return Line(text: text, frame: frame)
        }
        .sorted { abs($0.frame.midY - $1.frame.midY) > 4 ? $0.frame.midY < $1.frame.midY : $0.frame.minX < $1.frame.minX }
    }

    /// Pixel rows of `image` in bands up to `maxHeight`, each cut at the
    /// quietest row of its last `slack` rows: a gap between lines.
    private static func bands(of image: CGImage, maxHeight: Int, slack: Int) -> [Range<Int>] {
        let width = image.width, height = image.height
        var gray = [UInt8](repeating: 0, count: width * height)
        let drawn = gray.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return [0..<height] }
        let spread = (0..<height).map { row -> Int in
            let line = gray[(row * width)..<((row + 1) * width)]
            return Int(line.max()!) - Int(line.min()!)
        }
        // Rows below the last drawn one are left out, and so is a band with
        // nothing drawn: each read costs the same, text or none.
        guard let last = spread.lastIndex(where: { $0 > 0 }) else { return [] }
        let end = min(height, last + 2)
        var result: [Range<Int>] = []
        var start = 0
        while start < end {
            var cut = end
            if end - start > maxHeight {
                let window = (start + maxHeight - slack)..<(start + maxHeight)
                cut = window.min { spread[$0] < spread[$1] }!
            }
            if spread[start..<cut].contains(where: { $0 > 0 }) { result.append(start..<cut) }
            start = cut
        }
        return result
    }
}

/// Whether a known text was drawn with every word whole, judged on the lines
/// text recognition read from a render.
///
/// The text's letters and digits are aligned with the drawn ones, so a word
/// the recogniser split or merged, a missed accent or a stray icon read as a
/// letter costs one edit and no more. Each line end inside the aligned run
/// then maps to a place in the text: between two words, or after a hyphen or
/// slash the text already has, is a wrap; anywhere else the line cut a word,
/// with a drawn hyphen or without.
struct DrawnWordJudge {
    enum Script { case words, cjk }

    private(set) var lines: [DrawnTextReader.Line]
    private let script: Script
    /// The column's letters line after line, 0 where a judged text was found.
    private var stream: [UInt32] = []
    private var lineOfChar: [Int] = []
    private var lineStarts: [Int] = []

    init(lines: [DrawnTextReader.Line], script: Script) {
        self.lines = lines
        self.script = script
        for (index, line) in lines.enumerated() {
            lineStarts.append(stream.count)
            let letters = Self.skeleton(line.text)
            stream += letters
            lineOfChar += Array(repeating: index, count: letters.count)
        }
    }

    /// nil when `text` is drawn whole; else what is wrong. A found text is
    /// taken out of the column, so a text drawn twice is judged twice.
    mutating func judge(_ text: String) -> String? {
        let source = Source(text)
        guard source.letters.count > 1 else { return nil }
        guard !stream.isEmpty else { return "«\(text)» not drawn" }
        let match = align(source)
        let n = source.letters.count
        let tolerance = script == .cjk ? (n + 3) / 4 : (n + 7) / 8
        guard match.cost <= tolerance else { return "«\(text)» not drawn (closest costs \(match.cost))" }
        defer { for index in match.start..<match.end { stream[index] = 0 } }

        let touched = Set(lineOfChar[match.start..<match.end])
        // A text that ends in an ellipsis of its own draws one on its last line.
        let ownEllipsis = text.hasSuffix("…") || text.hasSuffix("...") ? lineOfChar[match.end - 1] : nil
        for index in touched.sorted() where index != ownEllipsis {
            let drawn = lines[index].text.trimmingCharacters(in: .whitespaces)
            if drawn.hasSuffix("…") || drawn.hasSuffix("...") { return "«\(text)» cut short: «\(drawn)»" }
        }
        for start in lineStarts where start > match.start && start < match.end {
            let line = lineOfChar[start]
            switch script {
            case .words:
                let position = match.sourceBefore[start - match.start]
                guard position > 0, position < source.letters.count, !source.breaks.contains(position) else { continue }
                return "«\(text)» breaks «\(source.word(at: position))» at a line end: «\(lines[line - 1].text)» / «\(lines[line].text)»"
            case .cjk:
                let before = lines[line - 1].text.trimmingCharacters(in: .whitespaces)
                let after = lines[line].text.trimmingCharacters(in: .whitespaces)
                if let last = before.unicodeScalars.last, let first = after.unicodeScalars.first,
                   last.properties.numericType != nil, Self.isCJK(first) {
                    return "«\(text)» splits a number from its counter: «\(before)» / «\(after)»"
                }
            }
        }
        return nil
    }

    // MARK: Text

    private struct Source {
        let letters: [UInt32]
        /// The places a line may end: between two words, after a hyphen, dash
        /// or slash the text has, and on either side of a range's tilde
        /// (Korean 10월~11월 may end a line after the counter).
        let breaks: Set<Int>
        private let words: [(range: Range<Int>, text: String)]

        init(_ text: String) {
            var letters: [UInt32] = []
            var breaks: Set<Int> = []
            var words: [(Range<Int>, String)] = []
            for word in text.split(whereSeparator: { $0.isWhitespace }) {
                let start = letters.count
                for piece in word.split(omittingEmptySubsequences: false, whereSeparator: { "-‐–—/~～〜".contains($0) }) {
                    letters += DrawnWordJudge.skeleton(String(piece))
                    breaks.insert(letters.count)
                }
                if letters.count > start { words.append((start..<letters.count, String(word))) }
            }
            self.letters = letters
            self.breaks = breaks
            self.words = words
        }

        func word(at position: Int) -> String {
            words.first { $0.range.contains(position) }?.text ?? "?"
        }
    }

    /// Letters and digits only, case and width folded; accents folded in the
    /// alphabets that carry them, where the recogniser may miss one; a
    /// Cyrillic letter read as its Latin look-alike (ВОЗ as BO3) is the same.
    static func skeleton(_ text: String) -> [UInt32] {
        var result: [UInt32] = []
        for character in text.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil) {
            let plain = character.unicodeScalars.allSatisfy { $0.value < 0x0530 }
                ? String(character).folding(options: .diacriticInsensitive, locale: nil)
                : String(character)
            for scalar in plain.unicodeScalars where scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                result.append(lookAlike[scalar]?.value ?? scalar.value)
            }
        }
        return result
    }

    private static let lookAlike: [Unicode.Scalar: Unicode.Scalar] = Dictionary(uniqueKeysWithValues: zip(
        "авезікмнорстухє".unicodeScalars, "abe3ikmhopctyxe".unicodeScalars))

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x1100...0x11FF, 0x3040...0x30FF, 0x3130...0x318F, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF:
            true
        default:
            false
        }
    }

    // MARK: Alignment

    private struct Match {
        let cost: Int
        let start: Int
        let end: Int
        /// For each drawn letter from `start`, how many of the text's letters
        /// come before it.
        let sourceBefore: [Int]
    }

    /// The cheapest run of the column that spells the whole text: a missing,
    /// extra or misread letter costs one. The whole column, not the lines
    /// around a word the text shares: a later line may repeat that word.
    /// A whole drawn line inside the run also costs one: a switch or a week
    /// button beside a two-line title reads as a line between its lines. A
    /// line that holds a piece of the text costs less matched than skipped,
    /// so a cut word is still seen.
    private func align(_ source: Source) -> Match {
        let s = source.letters, t = stream
        let n = s.count, m = t.count
        var cost = [Int32](repeating: 0, count: (n + 1) * (m + 1))
        func at(_ i: Int, _ j: Int) -> Int { i * (m + 1) + j }
        // For the end of each drawn line with letters, where that line starts.
        var lineStartAtEnd = [Int](repeating: -1, count: m + 1)
        for (index, start) in lineStarts.enumerated() {
            let end = index + 1 < lineStarts.count ? lineStarts[index + 1] : m
            if end > start { lineStartAtEnd[end] = start }
        }
        for i in 1...n { cost[at(i, 0)] = Int32(i) }
        if m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let diagonal = cost[at(i - 1, j - 1)] + (s[i - 1] == t[j - 1] ? 0 : 1)
                    var best = min(diagonal, cost[at(i - 1, j)] + 1, cost[at(i, j - 1)] + 1)
                    if lineStartAtEnd[j] >= 0 { best = min(best, cost[at(i, lineStartAtEnd[j])] + 1) }
                    cost[at(i, j)] = best
                }
            }
        }
        var end = 0
        for j in 0...m where cost[at(n, j)] < cost[at(n, end)] { end = j }
        var before = [Int](repeating: 0, count: m)
        var i = n, j = end
        while i > 0 {
            if j > 0, cost[at(i, j)] == cost[at(i - 1, j - 1)] + (s[i - 1] == t[j - 1] ? 0 : 1) {
                before[j - 1] = i - 1; i -= 1; j -= 1
            } else if cost[at(i, j)] == cost[at(i - 1, j)] + 1 {
                i -= 1
            } else if lineStartAtEnd[j] >= 0, cost[at(i, j)] == cost[at(i, lineStartAtEnd[j])] + 1 {
                for k in lineStartAtEnd[j]..<j { before[k] = i }
                j = lineStartAtEnd[j]
            } else {
                before[j - 1] = i; j -= 1
            }
        }
        return Match(cost: Int(cost[at(n, end)]), start: j, end: end,
                     sourceBefore: Array(before[j..<end]))
    }
}

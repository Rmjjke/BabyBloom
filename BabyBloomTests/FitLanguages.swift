import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// A language a fit test runs in: a shipped one, or a debug pseudo-language
/// standing in for the long Latin and the space-less scripts not translated yet.
enum FitLanguage: Hashable, CustomStringConvertible {
    case real(SupportedLanguage)
    case pseudo(PseudoLanguage)

    /// Every shipped language (a new JSON joins by itself) and both pseudo ones.
    static var all: [FitLanguage] {
        SupportedLanguage.available.map(FitLanguage.real) + PseudoLanguage.allCases.map(FitLanguage.pseudo)
    }

    var description: String {
        switch self {
        case .real(let language): language.rawValue
        case .pseudo(let language): language.rawValue
        }
    }

    /// The language that typesets and picks plural forms.
    var base: SupportedLanguage {
        switch self {
        case .real(let language): language
        case .pseudo(let language): language.base
        }
    }

    /// The locale the app sets at its root in this language.
    var environmentLocale: Locale { base.environmentLocale }

    /// The language and pseudo-language before the first `apply()` since the
    /// last `restore()`.
    @MainActor private static var before: (language: SupportedLanguage, pseudo: PseudoLanguage?)?

    /// Makes `.l` read this language. A pseudo-language overrides whatever
    /// language is stored, so a real one clears it first.
    @MainActor func apply() {
        let manager = LocalizationManager.shared
        if Self.before == nil { Self.before = (manager.language, manager.pseudo) }
        switch self {
        case .real(let language):
            manager.setPseudo(nil)
            manager.setLanguage(language)
        case .pseudo(let language):
            manager.setPseudo(language)
        }
    }

    /// Back to the language and pseudo-language the first `apply()` found, so
    /// a test leaves the stored language as it was. Nothing applied, nothing
    /// to undo.
    @MainActor static func restore() {
        guard let before else { return }
        LocalizationManager.shared.setPseudo(before.pseudo)
        LocalizationManager.shared.setLanguage(before.language)
        Self.before = nil
    }
}

/// A place where a language's text is known not to fit yet: kept so the gate
/// stays green while any new miss fails. Each row names its width and the room
/// it missed, so the long-strings design pass can judge it and remove it.
struct KnownMiss: Hashable, CustomStringConvertible {
    let language: FitLanguage
    /// The string key, or the key and a qualifier ("tab.more on iPad").
    let key: String
    /// The measured width and the room, in pt, when the row was written.
    let width: CGFloat
    let room: CGFloat

    init(_ language: FitLanguage, _ key: String, width: CGFloat, room: CGFloat) {
        self.language = language
        self.key = key
        self.width = width
        self.room = room
    }

    var description: String { "\(language) \(key): \(width) in \(room)" }

    static func == (lhs: KnownMiss, rhs: KnownMiss) -> Bool {
        lhs.language == rhs.language && lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(language)
        hasher.combine(key)
    }

    /// Whether `table` lists a miss for this language and key.
    static func listed(_ table: [KnownMiss], _ language: FitLanguage, _ key: String) -> Bool {
        table.contains { $0.language == language && $0.key == key }
    }
}

/// Text widths as SwiftUI sets them.
@MainActor
enum FitMeasure {
    /// One run of text on one line, at `font`, with Bold Text on or off.
    static func wordWidth(_ text: String, font: Font, bold: Bool = false, locale: Locale? = nil) -> CGFloat {
        let view = Text(text).font(font).fixedSize()
            .environment(\.legibilityWeight, bold ? .bold : .regular)
            .environment(\.locale, locale ?? LocalizationManager.shared.language.environmentLocale)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)).width
    }

    /// The widest piece a line cannot break inside: a word, or a line-break
    /// unit of a script without spaces.
    static func widestUnit(_ text: String, font: Font, bold: Bool = false, locale: Locale? = nil) -> CGFloat {
        text.lineBreakUnits.map { wordWidth($0, font: font, bold: bold, locale: locale) }.max() ?? 0
    }

    /// The widest unit as UIKit sets it, for places drawn by UIKit or Core Text
    /// (the tab bar, segmented controls, PDFs).
    nonisolated static func widestUnit(_ text: String, uiFont: UIFont) -> CGFloat {
        text.lineBreakUnits.map { ($0 as NSString).size(withAttributes: [.font: uiFont]).width }.max() ?? 0
    }
}

import SwiftUI

extension View {
    /// Hands the app language to everything SwiftUI renders itself: the locale
    /// date pickers and `Text(_:style:)` format through, the Gregorian calendar
    /// they count in, and the typesetting language that picks the glyph forms
    /// of characters Japanese and Chinese share. Without the last one a name
    /// typed in a Japanese app on an English phone draws 骨 and 直 in the
    /// device's preferred CJK forms.
    ///
    /// Every root applies it: the app's window, each widget family and each
    /// Live Activity region — the system renders those apart from one another,
    /// so none inherits it from the others.
    func appLanguageEnvironment(_ language: SupportedLanguage) -> some View {
        environment(\.locale, language.environmentLocale)
            .environment(\.calendar, language.environmentCalendar)
            .typesettingLanguage(language.typesettingLanguage)
    }

    /// Draws a text the app lays out by measuring its whole words with no
    /// hyphenation. Under its own language's typesetting the system
    /// hyphenates a word that fits a line alone, whenever the line before
    /// leaves room for a part of it (uk «користу-ються» in a 256-pt column),
    /// so a layout chosen because every word fits still drew a broken one.
    /// The undetermined language «zxx» breaks such text between words only.
    ///
    /// Korean takes it too: its words are spaced, and its own typesetting
    /// breaks a word between syllables («쓰이 / 는지»). Japanese and Chinese
    /// keep the app's typesetting: it picks their glyph forms and breaks
    /// their lines at phrases, which zxx would trade for breaks at any
    /// character.
    func wordFitTypesetting() -> some View {
        modifier(WordFitTypesetting())
    }
}

private struct WordFitTypesetting: ViewModifier {
    @Environment(\.locale) private var locale

    func body(content: Content) -> some View {
        content.typesettingLanguage(Locale.Language(identifier: "zxx"), isEnabled: !Self.keepsOwnTypesetting(locale))
    }

    static func keepsOwnTypesetting(_ locale: Locale) -> Bool {
        switch locale.language.languageCode {
        case .japanese?, .chinese?: true
        default: false
        }
    }
}

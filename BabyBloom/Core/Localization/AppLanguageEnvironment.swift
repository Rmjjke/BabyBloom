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
}

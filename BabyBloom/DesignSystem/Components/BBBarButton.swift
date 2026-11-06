import SwiftUI

/// What a sheet bar's button does. Each case owns its glyph and the word
/// VoiceOver reads, so every sheet bar draws and speaks alike.
enum BBBarAction {
    case cancel, close, save, edit
    /// The confirm of a sheet that starts a feed's timer instead of saving a
    /// finished entry: the tap saves and starts it, so the glyph is ▶, not ✓.
    case startFeeding

    var glyph: String {
        switch self {
        case .cancel, .close: "xmark"
        case .save: "checkmark"
        case .edit: "pencil"
        case .startFeeding: "play.fill"
        }
    }

    /// The app's own word, in the app's language: a glyph or a button role
    /// would be read in the device's language, which the parent may not use
    /// in the app.
    var word: String {
        switch self {
        case .cancel: "button.cancel".l
        case .close: "button.close".l
        case .save: "button.save".l
        case .edit: "button.edit".l
        case .startFeeding: "button.start_feeding".l
        }
    }

    /// The sheet's confirm, drawn as the prominent button.
    var confirms: Bool { self == .save || self == .startFeeding }
}

/// A bar's button as a glyph: × for Cancel and Close, ✓ for Save, ▶ for a
/// confirm that starts a feed, a pencil for Edit, the pushed medication
/// screen's too. Words in the bar left a title 49 pt at Large on a 320-pt
/// phone in ru, so every title was cut; glyphs leave it 174 pt in every
/// language. On iOS 26 the bar draws each glyph in a glass circle and the
/// confirm is the prominent one, a primary fill with an on-primary glyph;
/// before iOS 26 the glyphs stand bare, the confirm and Edit in the primary
/// ink.
struct BBBarButton: View {
    private let action: BBBarAction
    private let perform: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    init(_ action: BBBarAction, perform: @escaping () -> Void) {
        self.action = action
        self.perform = perform
    }

    var body: some View {
        button
            .accessibilityLabel(action.word)
    }

    @ViewBuilder private var button: some View {
        if action.confirms, #available(iOS 26.0, *) {
            Button(action: perform) {
                Image(systemName: action.glyph)
                    .foregroundStyle(BBTheme.Colors.onPrimary)
            }
            .buttonStyle(.glassProminent)
            .tint(BBTheme.Colors.primary)
        } else {
            Button(action: perform) {
                Image(systemName: action.glyph)
                    // An explicit ink overrides the disabled dimming, so a
                    // disabled Save takes the secondary ink itself.
                    .foregroundStyle(ink)
            }
        }
    }

    private var ink: Color {
        switch action {
        case .cancel, .close: BBTheme.Colors.textSecondary
        case .save, .edit, .startFeeding:
            isEnabled ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary
        }
    }
}

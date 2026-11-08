import SwiftUI
import UIKit

/// A sheet's big action pinned under its form, on the page's ground, gone
/// while the keyboard is up. Pinned, it rode up on the keyboard and lay over
/// the field below the one being typed in, so a tap aimed at that field saved
/// the form. While typing, the bar's confirm saves; the footer is back once
/// the keyboard is down.
///
/// The keyboard's own notifications, not the sheet's focus: they cover every
/// text field a sheet has or gains later, with nothing to wire per field.
/// The footer starts as if the keyboard were down, so one first built while
/// the keyboard is already up shows until the keyboard next moves; no sheet
/// builds one then.
struct BBSheetFooter<Content: View>: View {
    private let content: Content
    @State private var keyboardUp = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        // A stack, not a Group: modifiers on a Group go to its children, so
        // with the footer gone nothing would hear the keyboard go down.
        VStack(spacing: 0) {
            if !keyboardUp {
                content
                    .padding(.horizontal, BBTheme.Spacing.md)
                    .padding(.top, BBTheme.Spacing.sm)
                    .padding(.bottom, BBTheme.Spacing.xs)
                    .background(BBTheme.Colors.background)
            }
        }
        // Gone as the keyboard starts to rise, back only once it is all the
        // way down: through either slide the form is as short as with the
        // keyboard up, and the footer would lie over the next field again.
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            if BBSheetKeyboard.isTall(note) { keyboardUp = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { note in
            keyboardUp = BBSheetKeyboard.isTall(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification)) { _ in
            keyboardUp = false
        }
    }
}

/// Whether the keyboard leaves a sheet's form too short for its pinned footer.
enum BBSheetKeyboard {
    /// The bar an iPad shows over a hardware keyboard stands about 55–70 pt and
    /// leaves the footer in place; every on-screen keyboard, an iPhone's in
    /// landscape included, stands 160 pt or more.
    static let tallerThan: CGFloat = 100

    /// The show and hide notifications carry the keyboard's screen as their
    /// object and its end frame in that screen's coordinates.
    @MainActor
    static func isTall(_ note: Notification) -> Bool {
        guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return false }
        return isTall(end: end, screen: (note.object as? UIScreen)?.bounds)
    }

    /// Only the part of the frame on the screen counts, so a keyboard frame
    /// reported mostly below the edge counts by what shows. With no screen
    /// known, the whole frame counts.
    static func isTall(end: CGRect, screen: CGRect?) -> Bool {
        let onScreen = screen.map { end.intersection($0).height } ?? end.height
        return onScreen > tallerThan
    }
}

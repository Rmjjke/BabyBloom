import SwiftUI
import UIKit

/// A sheet's big action pinned under its form, on the page's ground, gone
/// while the keyboard is up. Pinned, it rode up on the keyboard and lay over
/// the field below the one being typed in, so a tap aimed at that field saved
/// the form. While typing, the bar's confirm saves; the footer is back once
/// the keyboard goes down.
///
/// The keyboard's own notifications, not the sheet's focus: they cover every
/// text field a sheet has or gains later, with nothing to wire per field.
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
    }
}

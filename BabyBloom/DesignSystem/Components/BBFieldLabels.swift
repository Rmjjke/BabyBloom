import SwiftUI

/// A picker with its label above it, at every size: beside the date and time
/// buttons the label broke mid-word as the text grew («Врем / я» at xxxLarge
/// on a 402-pt phone), and at Large on a 320-pt screen ru «Время» and en
/// «Time» had no room beside the widest date. One shape, not a fit: a row
/// that fits by its date would jump while the parent picks one.
///
/// The closure builds the picker with the label it is handed. The visible
/// label is hidden from VoiceOver and the picker keeps its own, so the label
/// is read once.
struct BBLabeledPicker<Content: View>: View {
    private let label: String
    private let picker: Content

    init(_ label: String, @ViewBuilder picker: (String) -> Content) {
        self.label = label
        self.picker = picker(label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            Text(label)
                .accessibilityHidden(true)
            picker
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// For a vertical text field whose placeholder is its only visible label.
    ///
    /// A placeholder wraps only into lines the field already has, and only in
    /// a point-size font: with one line, or in a text-style font such as
    /// `.body`, it ended in «…» at accessibility sizes. So the font is the body
    /// size scaled up to the app's cap, and at accessibility sizes the field
    /// keeps two lines. `maxLines` is the most lines below those sizes, one
    /// more above them; nil lets the field grow.
    func bbPlaceholderLabel(design: Font.Design = .rounded, maxLines: Int? = 3) -> some View {
        modifier(BBPlaceholderLabel(design: design, maxLines: maxLines))
    }
}

private struct BBPlaceholderLabel: ViewModifier {
    let design: Font.Design
    let maxLines: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        let reserved = dynamicTypeSize.isAccessibilitySize ? 2 : 1
        let sized = content
            .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular, design: design))
        if let maxLines {
            sized.lineLimit(reserved...max(reserved, maxLines + reserved - 1))
        } else {
            sized.lineLimit(reserved...)
        }
    }
}

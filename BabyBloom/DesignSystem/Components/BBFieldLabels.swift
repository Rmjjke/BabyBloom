import SwiftUI

/// A picker with its label above it, at every size: beside the date and time
/// buttons the label broke mid-word as the text grew («Врем / я» at xxxLarge
/// on a 402-pt phone), and at Large on a 320-pt screen ru «Время» and en
/// «Time» had no room beside the widest date. One shape, not a fit: a row
/// that fits by its date would jump while the parent picks one. Only the
/// picker itself steps down a text size where its date misses the width.
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
            BBFitsByTextSize { picker }
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// BBLabeledPicker for a date-and-time picker, whose compact style sets the
/// date and time buttons side by side. Where the pair misses the width after
/// the text-size steps, the time goes under the date, each button whole: at
/// AX2 with Bold Text the Brazilian «12 de nov. de 2026» and the time
/// outgrew a 320-pt sheet's card even at xxLarge.
///
/// The closure builds the picker for the components it is handed: both for
/// the pair, then `.date` and `.hourAndMinute` for the stacked buttons, on
/// one selection, so each edits its own half of the same moment.
struct BBLabeledDateTimePicker<Picker: View>: View {
    private let label: String
    private let picker: (String, DatePickerComponents) -> Picker

    init(_ label: String,
         @ViewBuilder picker: @escaping (_ label: String, _ components: DatePickerComponents) -> Picker) {
        self.label = label
        self.picker = picker
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            Text(label)
                .accessibilityHidden(true)
            let pair = picker(label, [.date, .hourAndMinute])
            // The stacked shape comes last: a nested ViewThatFits offers its
            // first child's width, so earlier it would win only by that.
            ViewThatFits(in: .horizontal) {
                pair
                pair.dynamicTypeSize(...DynamicTypeSize.accessibility1)
                pair.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                pair.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    BBFitsByTextSize { picker(label, .date) }
                    BBFitsByTextSize { picker(label, .hourAndMinute) }
                }
            }
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A control that never wraps or shrinks, such as a compact date picker's
/// date button, steps down a text size while it misses the width, as
/// BBScreenHeading does; where it fits it keeps the user's size. At AX2 with
/// Bold Text ru «10 нояб. 2026 г.» outgrew a 320-pt sheet's card and widened
/// the whole sheet past the screen.
struct BBFitsByTextSize<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        // Ranges, so a step never sets a size above the user's.
        ViewThatFits(in: .horizontal) {
            content
            content.dynamicTypeSize(...DynamicTypeSize.accessibility1)
            content.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            content.dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
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

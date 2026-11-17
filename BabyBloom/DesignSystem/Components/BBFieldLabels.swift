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
/// outgrew a 320-pt sheet's card even at xxLarge. At accessibility sizes the
/// time always goes under the date: there the system wraps its own pair and
/// sets the time at the trailing edge (en at AX2, 104 pt in from the label).
/// Stacked, each button starts at the label's leading edge.
///
/// The closure builds the picker for the components it is handed: both for
/// the pair, then `.date` and `.hourAndMinute` for the stacked buttons, on
/// one selection, so each edits its own half of the same moment.
struct BBLabeledDateTimePicker<Picker: View>: View {
    private let label: String
    private let picker: (String, DatePickerComponents) -> Picker
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            let stacked = VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                BBFitsByTextSize(hugging: true) { picker(label, .date) }
                BBFitsByTextSize(hugging: true) { picker(label, .hourAndMinute) }
            }
            if dynamicTypeSize.isAccessibilitySize {
                stacked.labelsHidden()
            } else {
                // The stacked shape comes last: a nested ViewThatFits offers
                // its first child's width, so earlier it would win only by that.
                ViewThatFits(in: .horizontal) {
                    pair
                    pair.dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    stacked
                }
                .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A control that never wraps or shrinks, such as a compact date picker's
/// date button, steps down a text size while it misses the width, as
/// BBScreenHeading does; where it fits it keeps the user's size. At AX2 with
/// Bold Text ru «10 нояб. 2026 г.» outgrew a 320-pt sheet's card and widened
/// the whole sheet past the screen.
///
/// `hugging` sizes each step to the control's own width. A compact date
/// picker handed less than its full date switches to the short one
/// («12/11/2026») but keeps the width it measured for the full one and draws
/// its button at the trailing end of it, away from the label's edge. Hugging,
/// the button shows the full date at the first size it fits and starts at
/// the leading edge; the last step is not hugged, so a date that misses
/// even at xxLarge shortens instead of passing the screen edge.
struct BBFitsByTextSize<Content: View>: View {
    private let hugging: Bool
    private let content: Content

    init(hugging: Bool = false, @ViewBuilder content: () -> Content) {
        self.hugging = hugging
        self.content = content()
    }

    var body: some View {
        // Ranges, so a step never sets a size above the user's.
        ViewThatFits(in: .horizontal) {
            step(content)
            step(content.dynamicTypeSize(...DynamicTypeSize.accessibility1))
            step(content.dynamicTypeSize(...DynamicTypeSize.xxxLarge))
            step(content.dynamicTypeSize(...DynamicTypeSize.xxLarge))
            if hugging {
                content.dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
        }
    }

    @ViewBuilder
    private func step(_ view: some View) -> some View {
        if hugging {
            view.fixedSize()
        } else {
            view
        }
    }
}

extension View {
    /// For a vertical text field whose placeholder is its only visible label:
    /// `placeholder` is the field's title, `text` its value.
    ///
    /// A vertical field sizes to its text, never its placeholder, and the
    /// placeholder wraps only into lines the field already has, so an empty
    /// field one line high cut a long placeholder with «…» (fr and ja at
    /// Large). While the field is empty it reserves the lines the placeholder
    /// takes at the field's width, measured with the same font; at the first
    /// character it sizes to the text again. The font is a point size, the
    /// body size scaled up to the app's cap: in a text-style font such as
    /// `.body` the placeholder never wrapped. At accessibility sizes the field
    /// keeps two lines even with text. `maxLines` is the most lines below
    /// those sizes, one more above them; nil lets the field grow.
    func bbPlaceholderLabel(_ placeholder: String, text: String,
                            design: Font.Design = .rounded, maxLines: Int? = 3) -> some View {
        modifier(BBPlaceholderLabel(placeholder: placeholder, isEmpty: text.isEmpty,
                                    design: design, maxLines: maxLines))
    }
}

private struct BBPlaceholderLabel: ViewModifier {
    let placeholder: String
    let isEmpty: Bool
    let design: Font.Design
    let maxLines: Int?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let font = BBTheme.Typography.scaled(17, relativeTo: .body, weight: .regular, design: design)
        // The measure sits outside the line limit: under it the one-line copy
        // also reserved the field's lines and the count never settled.
        return limited(content.font(font))
            .background(alignment: .topLeading) {
                if isEmpty { measure(font) }
            }
    }

    @ViewBuilder
    private func limited(_ field: some View) -> some View {
        let reserved = dynamicTypeSize.isAccessibilitySize ? 2 : 1
        let least = isEmpty ? max(reserved, placeholderLines) : reserved
        if let maxLines {
            field.lineLimit(least...max(least, maxLines + reserved - 1))
        } else {
            field.lineLimit(least...)
        }
    }

    /// The placeholder's lines at the field's width: its height whole over
    /// its height on one line. Hidden, so VoiceOver reads the field alone.
    private func measure(_ font: Font) -> some View {
        ZStack(alignment: .topLeading) {
            Text(placeholder)
                .lineLimit(1)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { oneLine = $0 }
            Text(placeholder)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { whole = $0 }
        }
        .font(font)
        .hidden()
        .accessibilityHidden(true)
    }

    @State private var oneLine: CGFloat = 0
    @State private var whole: CGFloat = 0

    private var placeholderLines: Int {
        oneLine > 0 ? max(1, Int((whole / oneLine).rounded())) : 1
    }
}

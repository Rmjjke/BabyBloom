import SwiftUI

/// A verdict's value with its tier as a mark, never as ink: the words in the
/// text colour, led by a dot in the tier tint. The tints are under 3:1 on the
/// light surfaces; a mark beside words that say the verdict needs no ratio.
///
/// The dot is drawn into the value's own run of text, so it stays on the first
/// line when the value wraps and sits right beside the first word under any
/// alignment. A word joiner keeps it from ending a line alone. It is 7/13 of
/// the value's size across with a 5/13 gap, both scaled with the value's text
/// style, and sits on the baseline, which puts its centre within a fifth of a
/// point of the x-height's middle.
///
/// An image inside a `Text` would be read by VoiceOver (a symbol by its name),
/// so the value carries its words as its label.
struct BBTierValue: View {
    let text: String
    /// The tier tint, or nil for no dot.
    let dot: Color?
    var ink: Color = BBTheme.Colors.textPrimary
    let size: CGFloat
    let style: UIFont.TextStyle

    // The drawing takes a resolved colour, not a style. Reading the whole
    // environment re-runs the body when the appearance changes, so the dot
    // follows a live switch between light and dark.
    @Environment(\.self) private var environment

    var body: some View {
        content
            .font(BBTheme.Typography.scaled(size, relativeTo: style, weight: .semibold))
            .accessibilityLabel(text)
    }

    private var content: Text {
        let words = Text(text).foregroundStyle(ink)
        guard let dot else { return words }
        let diameter = BBTheme.Typography.scaledPointSize(size * 7 / 13, relativeTo: style)
        let gap = BBTheme.Typography.scaledPointSize(size * 5 / 13, relativeTo: style)
        let tint = dot.resolve(in: environment)
        let mark = Image(size: CGSize(width: diameter + gap, height: diameter)) { context in
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)),
                         with: .color(Color(tint)))
        }
        return Text(mark) + Text("\u{2060}") + words
    }
}

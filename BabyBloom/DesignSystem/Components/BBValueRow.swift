import SwiftUI

/// A title and a trailing value on one row.
///
/// The value is the thing read at a glance («3.50 kg», «2/6», a badge), so it
/// is never squeezed: it keeps its one-line width and the title gives way,
/// wrapping only between words. When even that cannot hold — at the
/// accessibility sizes — the value moves under the title instead of cutting a
/// word in half beside it.
///
/// Two fits:
/// - `.bySize` (default): beside below the accessibility sizes, the title
///   wrapping as it must; under at them. Right where the title is a short label
///   and a wrapped one still reads as a label.
/// - `.byFit`: beside only while the title fits on ONE line next to the value;
///   otherwise under, at any size. Right where a wrapped title next to its value
///   would stand on broken words (a long title in a narrow window at Large).
///
/// `underSpacing` is the gap above a value under its title: xs 4, or 2 in a
/// Settings row, where it matches the hints under the switch titles.
///
/// Under its title the value lines up with the title's text. A title side that
/// leads with a glyph marks its text with `.alignmentGuide(.bbValueRowTitle)`;
/// without the mark the value starts at the title side's leading edge.
struct BBValueRow<Title: View, Value: View>: View {
    enum Shape { case bySize, byFit }

    private let shape: Shape
    private let underSpacing: CGFloat
    private let title: Title
    private let value: Value
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(shape: Shape = .bySize,
         underSpacing: CGFloat = BBTheme.Spacing.xs,
         @ViewBuilder title: () -> Title,
         @ViewBuilder value: () -> Value) {
        self.shape = shape
        self.underSpacing = underSpacing
        self.title = title()
        self.value = value()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            under
        } else if shape == .byFit {
            ViewThatFits(in: .horizontal) {
                beside(oneLine: true)
                under
            }
        } else {
            beside(oneLine: false)
        }
    }

    private func beside(oneLine: Bool) -> some View {
        HStack(alignment: .center) {
            // One line for `.byFit`'s first candidate: a wrapping title would
            // always "fit", so ViewThatFits would never pick the second.
            title.fixedSize(horizontal: oneLine, vertical: true)
            Spacer(minLength: BBTheme.Spacing.sm)
            value.fixedSize().layoutPriority(1)
        }
    }

    private var under: some View {
        VStack(alignment: .bbValueRowTitle, spacing: underSpacing) {
            title.fixedSize(horizontal: false, vertical: true)
            value
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension HorizontalAlignment {
    private enum ValueRowTitle: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.leading] }
    }

    /// Where a `BBValueRow`'s value starts when it stands under the title.
    static let bbValueRowTitle = HorizontalAlignment(ValueRowTitle.self)
}

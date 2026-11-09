import SwiftUI
import UIKit

// MARK: - Screen title

extension View {
    /// A screen's title, in the bar while it fits there and otherwise the
    /// content's first lines, `BBScreenHeading`, which the screen puts first
    /// in its scroll content. The two go together: the modifier alone leaves
    /// no title where the bar has none, the heading alone shows nothing (it
    /// draws only where this modifier says the bar cannot hold the title).
    ///
    /// The bar sets a large title on one line and cuts its tail («For the
    /// pediatr…» on a 320-pt phone at Large, «Medica…» in es there at AX1),
    /// so a title that misses the bar's line leaves it: the bar turns inline
    /// and holds a 17-pt title of its own, shown once the heading has
    /// scrolled away under it. The navigation title stays set throughout, so
    /// the next screen's back button and the app switcher still name it.
    func bbScreenTitle(_ title: String) -> some View {
        modifier(BBScreenTitle(title: title))
    }
}

/// Whether a screen's title fits the bar's large-title line, and in which
/// style the heading sets it where it does not. Pure, so the tests can walk
/// every width, size and language without a navigation bar.
enum BBScreenTitleFit {
    /// The heading's styles, largest first; each a step down when the
    /// widest word misses the heading's width.
    enum Style: CaseIterable {
        case largeTitle, title1, title2, title3

        var textStyle: UIFont.TextStyle {
            switch self {
            case .largeTitle: .largeTitle
            case .title1: .title1
            case .title2: .title2
            case .title3: .title3
            }
        }

        /// The SwiftUI face of `BBScreenTitleFit.font(self, …)`.
        var font: Font {
            switch self {
            case .largeTitle: .largeTitle.bold()
            case .title1: .title.bold()
            case .title2: .title2.bold()
            case .title3: .title3.bold()
            }
        }
    }

    /// What the heading keeps free beside its widest word: a measuring error,
    /// Bold Text and a later word are absorbed by it.
    static let spare = BBTheme.Spacing.sm

    /// The bar's room for its large title: the bar insets it 16 pt a side
    /// below 414 pt and 20 pt a side from there.
    static func barRoom(width: CGFloat) -> CGFloat {
        width - (width < 414 ? 32 : 40)
    }

    /// The face the bar sets a large title in (`.largeTitle`, bold) or the
    /// heading one of its steps in, at `size` capped at the app's ceiling.
    @MainActor
    static func font(_ style: Style, size: DynamicTypeSize, boldText: Bool) -> UIFont {
        let capped = min(size, BBTheme.Typography.maxDynamicTypeSize)
        let traits = UITraitCollection { traits in
            traits.preferredContentSizeCategory = UIContentSizeCategory(capped)
            traits.legibilityWeight = boldText ? .bold : .regular
        }
        let base = UIFont.preferredFont(forTextStyle: style.textStyle, compatibleWith: traits)
        let bold = base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor
        return UIFont(descriptor: bold, size: 0)
    }

    /// One line's width at the font's own tracking, as CoreText sets it.
    static func width(of text: String, in font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// The title fits the bar while its one line at the bar's font is no
    /// wider than the bar's room. The bar draws the title a little narrower
    /// than CoreText measures it (0.969 of it), so on a few titles this goes
    /// to the heading one size before the bar would cut: the safe side.
    /// No width yet (a first layout pass) keeps the bar's title.
    @MainActor
    static func fitsBar(_ title: String, width: CGFloat, size: DynamicTypeSize, boldText: Bool) -> Bool {
        guard width > 0 else { return true }
        return Self.width(of: title, in: font(.largeTitle, size: size, boldText: boldText)) <= barRoom(width: width)
    }

    /// The largest style whose widest word fits `width` with `spare` free;
    /// the smallest when none does. `BBScreenHeading` makes the same choice
    /// by layout, at its real width; this is that choice by arithmetic.
    @MainActor
    static func headingStyle(_ title: String, width: CGFloat, size: DynamicTypeSize, boldText: Bool) -> Style {
        let words = title.split(separator: " ").map(String.init)
        return Style.allCases.first { style in
            let font = font(style, size: size, boldText: boldText)
            let widest = words.map { Self.width(of: $0, in: font) }.max() ?? 0
            return widest + spare <= width
        } ?? .title3
    }
}

private struct BBScreenTitle: ViewModifier {
    let title: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headingScrolledAway = false

    func body(content: Content) -> some View {
        // The width arrives in the same pass as the content, so the bar never
        // shows one shape for a frame and then the other.
        GeometryReader { proxy in
            let inBar = BBScreenTitleFit.fitsBar(title, width: proxy.size.width,
                                                 size: dynamicTypeSize,
                                                 boldText: legibilityWeight == .bold)
            content
                .environment(\.bbScreenTitleInBar, inBar)
                .environment(\.bbScreenHeadingScrolledAway, { headingScrolledAway = $0 })
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(inBar ? .large : .inline)
                .toolbar {
                    if !inBar {
                        ToolbarItem(placement: .principal) { principal }
                    }
                }
        }
        // y = 0 is the bar's bottom edge: the heading has gone once its last
        // line is above it.
        .coordinateSpace(.named(BBScreenHeading.coordinateSpace))
    }

    /// Kept in the bar while hidden: an empty principal item let the system
    /// draw the navigation title there, cut. A fixed 17 pt, as the system's
    /// inline title, shrinking to 13 pt before its tail is cut.
    private var principal: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(13.0 / 17.0)
            .truncationMode(.tail)
            .accessibilityAddTraits(.isHeader)
            .opacity(headingScrolledAway ? 1 : 0)
            .accessibilityHidden(!headingScrolledAway)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: headingScrolledAway)
    }
}

/// The screen's title as its content's first lines wherever the bar cannot
/// hold it (`bbScreenTitle`); nothing, and no stack spacing, where it can.
/// Wraps between words, never inside one: it steps from `.largeTitle` down
/// to `.title1`, `.title2` and `.title3` while its widest word misses the
/// width. The system's Bold Text sets these faces heavier than a measure can
/// ask for (es «Medicamentos» in `.title2` at AX2: 290 pt against 288 on a
/// 320-pt screen), so `.title3` is the step the layout lands on there.
struct BBScreenHeading: View {
    nonisolated static let coordinateSpace = "bbScreenTitle"

    let title: String
    /// sm below the bar on the screens whose content starts flush at the top;
    /// 0 where the content's own padding already stands there.
    var topPadding: CGFloat = BBTheme.Spacing.sm
    /// md on the screens that pad each block rather than the whole stack.
    var horizontalPadding: CGFloat = 0

    @Environment(\.bbScreenTitleInBar) private var inBar
    @Environment(\.bbScreenHeadingScrolledAway) private var reportScrolledAway

    var body: some View {
        if !inBar {
            ViewThatFits(in: .horizontal) {
                styled(.largeTitle)
                styled(.title1)
                styled(.title2)
                styled(.title3)
            }
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.frame(in: .named(BBScreenHeading.coordinateSpace)).maxY <= 0
            } action: { scrolledAway in
                reportScrolledAway?(scrolledAway)
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
        }
    }

    /// Ideal width: the widest word with `spare` free, so `ViewThatFits`
    /// takes the first style whose words all fit; a width it gets reaches
    /// the text untouched.
    private func styled(_ style: BBScreenTitleFit.Style) -> some View {
        WidestWordIdeal(spare: BBScreenTitleFit.spare) {
            Text(title.oneWordALine).font(style.font).hidden().accessibilityHidden(true)
            Text(title).font(style.font)
        }
    }
}

/// Tells the bar's own title when the heading has scrolled under the bar.
typealias BBScreenHeadingScrolledAway = @MainActor @Sendable (Bool) -> Void

private struct BBScreenTitleInBarKey: EnvironmentKey {
    /// A heading outside `bbScreenTitle` draws nothing: the bar is assumed to
    /// hold the title.
    static let defaultValue = true
}

private struct BBScreenHeadingScrolledAwayKey: EnvironmentKey {
    static let defaultValue: BBScreenHeadingScrolledAway? = nil
}

extension EnvironmentValues {
    var bbScreenTitleInBar: Bool {
        get { self[BBScreenTitleInBarKey.self] }
        set { self[BBScreenTitleInBarKey.self] = newValue }
    }

    var bbScreenHeadingScrolledAway: BBScreenHeadingScrolledAway? {
        get { self[BBScreenHeadingScrolledAwayKey.self] }
        set { self[BBScreenHeadingScrolledAwayKey.self] = newValue }
    }
}

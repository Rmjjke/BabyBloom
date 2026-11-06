import SwiftUI

// MARK: - Stat Card
struct BBStatCard: View {
    let title: String
    let value: String
    /// A unit key drawn beside the value (kg, cm). A count has none, and a
    /// duration carries its unit words inside the value («1 ч 15 мин»).
    var unit: String = ""
    let icon: String
    let color: Color
    var trend: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) {
                cardContent
            }
            // Whole card (min 110pt) is the tap target — the 36pt icon is
            // decorative; contentShape guarantees the full frame is hittable.
            .contentShape(Rectangle())
            .buttonStyle(BBScaleButtonStyle())
        } else {
            cardContent
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            if let trend {
                // The trend («59 мин назад») stands beside the plate while each of
                // its words fits the room there, wrapping between words; else it
                // takes its own line under the plate. In two columns on a 320-pt
                // screen that room is about 32 pt of text at Large, and «59 мин»,
                // «13 дней» and even «назад» broke inside a word.
                ViewThatFits(in: .horizontal) {
                    HStack {
                        plate
                        Spacer()
                        trendCapsule(trend)
                        marks
                    }
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        HStack {
                            plate
                            Spacer()
                            marks
                        }
                        trendCapsule(trend)
                    }
                }
            } else {
                HStack {
                    plate
                    Spacer()
                    marks
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(Self.valueText(value))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit.l)
                            .font(Self.wordFont)
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                    }
                }
                Text(title.l)
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .bbCardTonal(color)
    }

    private var plate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.22))
                .frame(width: 36, height: 36)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func trendCapsule(_ trend: String) -> some View {
        WordWrappingText(text: trend)
            .font(BBTheme.Typography.scaled(12, relativeTo: .body, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(BBTheme.Colors.success.opacity(0.12))
            .cornerRadius(8)
    }

    @ViewBuilder
    private var marks: some View {
        if action != nil {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.5))
        }
    }

    private static var wordFont: Font {
        BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded)
    }

    struct ValueRun: Equatable {
        let text: String
        let isWord: Bool
    }

    /// The value cut into figures (digits, separators, a dash) and the words
    /// between them; letters and spaces are words.
    static func valueRuns(_ value: String) -> [ValueRun] {
        var runs: [ValueRun] = []
        for character in value {
            let isWord = character.isLetter || character.isWhitespace
            if let last = runs.last, last.isWord == isWord {
                runs[runs.count - 1] = ValueRun(text: last.text + String(character), isWord: isWord)
            } else {
                runs.append(ValueRun(text: String(character), isWord: isWord))
            }
        }
        return runs
    }

    /// Figures at the metric size, words at the unit's size. One Text, so a
    /// long «10 ч 45 мин» scales down as one line instead of wrapping.
    static func valueText(_ value: String) -> AttributedString {
        valueRuns(value).reduce(into: AttributedString()) { text, run in
            var part = AttributedString(run.text)
            part.font = run.isWord
                ? wordFont
                : BBTheme.Typography.scaled(28, relativeTo: .title2, weight: .semibold, design: .rounded).monospacedDigit()
            part.foregroundColor = run.isWord ? BBTheme.Colors.textSecondary : BBTheme.Colors.textPrimary
            text += part
        }
    }
}

/// Text whose ideal width is its widest word. Offered less than its one line,
/// it wraps as any text does, and `ViewThatFits` keeps a row only while every
/// word fits it, so the text breaks between words and never inside one. Words
/// part at plain spaces; a no-break space keeps a number with its unit.
private struct WordWrappingText: View {
    let text: String

    var body: some View {
        WidestWordIdeal {
            Text(text.split(separator: " ").joined(separator: "\n")).hidden()
            Text(text)
        }
    }
}

/// Lays out its second subview; the first, one word a line, only sets the
/// ideal width. Every other proposal reaches the text unchanged, so a stack
/// still sizes it as plain text.
private struct WidestWordIdeal: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews[0].sizeThatFits(.unspecified).width
        return subviews[1].sizeThatFits(ProposedViewSize(width: width, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: .zero)
        subviews[1].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

// MARK: - Tile Columns
/// A tile or grid row's column count at each text size, stated in one place.
///
/// A row keeps a count only while its widest en, ru or es word fits the
/// column (the tile less its side padding) at a 320-pt width with 8 pt to
/// spare, checked at every text size; from the first size where it misses,
/// the row takes fewer. 320 pt is Display Zoom on the smaller phones and iPad
/// Slide Over, and a word never breaks at any width. The spare absorbs a
/// measuring error, a later word and Bold Text.
///
/// One shape per text size at every width, never a count that follows the
/// width: `ViewThatFits` compares a row's whole width, not its narrowest
/// column, and one sheet would take two shapes at one text size. Home's
/// quick actions, the one exception, measure theirs in `DashboardView`.
struct BBTileColumns {
    /// `.large` and every smaller size.
    let large: Int
    let xLarge: Int
    let xxLarge: Int
    let xxxLarge: Int
    /// Every accessibility size; scaled type stops growing at AX2.
    let accessibility: Int

    func count(at size: DynamicTypeSize) -> Int {
        if size.isAccessibilitySize { return accessibility }
        switch size {
        case .xLarge: return xLarge
        case .xxLarge: return xxLarge
        case .xxxLarge: return xxxLarge
        default: return large
        }
    }
}

// MARK: - Stat Grid
/// Two stat cards a row; one from xxLarge, where in half a 320-pt screen the
/// grown title «Measurements» keeps 7.2 pt (100.8 in 108), under the 8-pt
/// spare. The icon plate stays 36 pt.
struct BBStatGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let columns = BBTileColumns(large: 2, xLarge: 2, xxLarge: 1, xxxLarge: 1, accessibility: 1)

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                 count: columns.count(at: dynamicTypeSize)),
                  spacing: BBTheme.Spacing.md) {
            content()
        }
    }
}

// MARK: - Event Row Card
struct BBEventRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let time: String
    var trailing: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            if dynamicTypeSize.isAccessibilitySize {
                // The time goes under the text: beside the grown time a long
                // word (a medication's name) had room for a few letters and
                // broke mid-word.
                VStack(alignment: .leading, spacing: 2) {
                    texts
                    (timeText + Text(verbatim: "  ") + trailingText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    texts
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    timeText
                    if trailing != nil { trailingText }
                }
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
    }

    // Verbatim: every caller passes text already localized, and a note or a
    // medication name is shown as typed, never looked up. The second line and
    // the time scale too, so a name and dose do not stay small under a grown
    // title.
    @ViewBuilder
    private var texts: some View {
        Text(verbatim: title)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
        if !subtitle.isEmpty {
            Text(verbatim: subtitle)
                .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
    }

    private var timeText: Text {
        Text(verbatim: time)
            .font(BBTheme.Typography.scaled(13, relativeTo: .footnote, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
    }

    private var trailingText: Text {
        Text(verbatim: trailing ?? "")
            .font(BBTheme.Typography.scaled(12, relativeTo: .caption1, weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
    }
}

// MARK: - Progress Card
/// A count against its target, in the category's colour at every count. There
/// is no over-the-target state: a count above its reference is never styled
/// as an alarm (DECISIONS 2026-09-05), and red stays on deletes.
struct BBProgressCard: View {
    let title: String
    let current: Double
    let target: Double
    /// A unit key for a measured target («10 of 14 h»); nil for a count
    /// («0 of 6»).
    var unit: String? = nil
    let color: Color
    let icon: String

    private var progress: Double { min(current / max(target, 1), 1.0) }

    /// Not glued: the key holds the unit to its number, and the words between
    /// the two numbers may wrap at the accessibility sizes.
    static func valueText(current: Double, target: Double, unit: String?) -> String {
        guard let unit else { return String(format: "progress.of_fmt".l, Int(current), Int(target)) }
        return String(format: "progress.of_unit_fmt".l, Int(current), Int(target), unit.l)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            // The glyph and the title make the title side; at the
            // accessibility sizes the figure goes under the title's text.
            BBValueRow {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                    Text(title.l)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .alignmentGuide(.bbValueRowTitle) { $0[.leading] }
                }
            } value: {
                Text(Self.valueText(current: current, target: target, unit: unit))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.22))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
    }
}

// MARK: - Section Header
struct BBSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "button.all"

    var body: some View {
        HStack {
            BBTheme.Typography.title3(title.l)
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionTitle.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Swipe to Delete Row
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    // Defaults keep every history list as it was; the doctor report reuses
    // the row with its own action («Back to the list»).
    var title: String = "button.delete"
    var systemImage: String = "trash.fill"
    var tint: Color = .red
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    private let deleteWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed on swipe
            Button {
                withAnimation(.spring(response: 0.3)) {
                    onDelete()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                    // Scales with Dynamic Type inside the fixed-width button; a
                    // long label («Back to the list») shrinks before it clips.
                    Text(title.l)
                        .font(BBTheme.Typography.scaled(11, relativeTo: .caption2, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                    .fill(tint)
            )
            .opacity(offset < -12 ? 1 : 0)

            content()
                .offset(x: offset)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: offset)
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onChanged { value in
                    // Only respond to predominantly horizontal swipes
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < 0 {
                        offset = max(value.translation.width, -deleteWidth)
                    } else if offset < 0 {
                        offset = min(0, offset + value.translation.width)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        offset = value.translation.width < -(deleteWidth / 2) ? -deleteWidth : 0
                    }
                }
        )
    }
}

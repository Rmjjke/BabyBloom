import SwiftUI

// MARK: - Stat Card
struct BBStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var trend: String? = nil
    var overLimit: Bool = false
    var action: (() -> Void)? = nil

    private var displayColor: Color { overLimit ? .red.opacity(0.85) : color }

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
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(displayColor.opacity(0.22))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(displayColor)
                }
                Spacer()
                if let trend {
                    Text(trend)
                        .font(BBTheme.Typography.scaled(12, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(BBTheme.Colors.success.opacity(0.12))
                        .cornerRadius(8)
                }
                if overLimit {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.85))
                }
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.5))
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    BBTheme.Typography.metric(value)
                        .foregroundStyle(overLimit ? .red.opacity(0.85) : BBTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(unit.l)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                Text(title.l)
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .bbCardTonal(displayColor)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                .stroke(overLimit ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Stat Grid
/// Two stat cards a row; one at accessibility sizes, where the grown title
/// and unit («Measurements», «Подгузников») no longer fit half a 375-pt
/// screen. The icon plate stays 36 pt.
struct BBStatGrid<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()),
                                 count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
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
struct BBProgressCard: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    let icon: String
    var overLimit: Bool = false

    private var progress: Double { min(current / max(target, 1), 1.0) }
    private var displayColor: Color { overLimit ? .red.opacity(0.75) : color }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(displayColor)
                Text(title.l)
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Text("\(Int(current))/\(Int(target)) \(unit.l)".gluingNumbersToUnits)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(overLimit ? .red.opacity(0.75) : BBTheme.Colors.textSecondary)
                if overLimit {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.75))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(displayColor.opacity(0.22))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [displayColor, displayColor.opacity(0.7)],
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
        .background(overLimit ? Color.red.opacity(0.06) : BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                .stroke(overLimit ? Color.red.opacity(0.25) : Color.clear, lineWidth: 1.5)
        )
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

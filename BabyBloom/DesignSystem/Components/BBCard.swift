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

    private var displayColor: Color { overLimit ? .red.opacity(0.85) : color }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(displayColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(displayColor)
                }
                Spacer()
                if let trend {
                    Text(trend)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.success)
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
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(overLimit ? .red.opacity(0.85) : BBTheme.Colors.textPrimary)
                    Text(unit.l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                Text(title.l)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .bbCard()
        .overlay(
            RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                .stroke(overLimit ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
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

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title.l)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle.l)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(time)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Text("\(Int(current))/\(Int(target)) \(unit.l)")
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
                        .fill(displayColor.opacity(0.15))
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
            Text(title.l)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionTitle.l)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
    }
}

// MARK: - Swipe to Delete Row
struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
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
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("button.delete".l)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(width: deleteWidth)
                .frame(maxHeight: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                    .fill(Color.red)
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

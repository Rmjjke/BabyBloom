import SwiftUI

// MARK: - Stat Card
struct BBStatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    var trend: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
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
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(unit)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                Text(title)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .bbCard()
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
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
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

    private var progress: Double { min(current / max(target, 1), 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Text("\(Int(current))/\(Int(target)) \(unit)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
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
    var actionTitle: String = "Все"

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            if let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
    }
}

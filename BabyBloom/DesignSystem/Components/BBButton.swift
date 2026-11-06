import SwiftUI

// MARK: - Primary Button
struct BBPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isLoading: Bool = false

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: BBTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(BBTheme.Colors.onPrimary)
                        .scaleEffect(0.9)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .default))
                    }
                    Text(title)
                        .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                }
            }
            // The dark primary is light, so the label takes BBOnPrimary, not
            // white (under 3:1 there). The end stop at 0.9 rather than 0.8 lets
            // the page show through less, so a long label still reads at
            // 4.5:1 or more where the gradient is faintest, in both modes.
            .foregroundStyle(BBTheme.Colors.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BBTheme.Spacing.sm)
            .frame(minHeight: 56)
            .background(
                LinearGradient(
                    colors: [BBTheme.Colors.primary, BBTheme.Colors.primary.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.button)
        }
        .buttonStyle(BBScaleButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Secondary Button
struct BBSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: BBTheme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .default))
                }
                Text(title)
                    .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, BBTheme.Spacing.sm)
            .frame(minHeight: 56)
            // Over the surface, so the primary words keep 4.5:1 wherever the
            // button is placed, the bare background included.
            .background(BBTheme.Colors.primary.opacity(0.1))
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: BBTheme.Radius.lg)
                    .stroke(BBTheme.Colors.primary.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(BBScaleButtonStyle())
    }
}

// MARK: - Quick Action Button (for Dashboard)
struct BBQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    /// Draws a small padlock on the icon. The gate has to be visible BEFORE the
    /// tap — a button that looks free and answers with a paywall is a
    /// bait-and-switch.
    var locked: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: BBTheme.Spacing.xs) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.22))
                            .frame(width: 60, height: 60)
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(color)
                    }
                    if locked {
                        LockBadge()
                    }
                }
                Text(title)
                    .font(BBTheme.Typography.scaled(12, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BBScaleButtonStyle())
        .bbLockedAccessibility(locked)
    }
}

// MARK: - Icon Button
struct BBIconButton: View {
    let icon: String
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(icon: String, color: Color = BBTheme.Colors.primary, size: CGFloat = 48, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(BBScaleButtonStyle())
    }
}

// MARK: - Scale Button Style (haptic)
struct BBScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BBScaleButtonContent(configuration: configuration)
    }
}

private struct BBScaleButtonContent: View {
    let configuration: ButtonStyleConfiguration
    @State private var wasPressed = false

    var body: some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { newValue in
                if newValue && !wasPressed {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred(intensity: 0.7)
                }
                wasPressed = newValue
            }
    }
}

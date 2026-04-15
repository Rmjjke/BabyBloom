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
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [BBTheme.Colors.primary, BBTheme.Colors.primary.opacity(0.8)],
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
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(BBTheme.Colors.primary.opacity(0.1))
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: BBTheme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(BBScaleButtonStyle())
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

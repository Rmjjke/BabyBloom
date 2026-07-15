import SwiftUI

/// Labelled measurement slider used across the growth and onboarding screens.
struct BBMeasureSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String
    let color: Color
    let minLabel: String
    let maxLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Text(display)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            Slider(value: $value, in: range, step: step)
                .tint(color)
            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
    }
}

/// Optional measurement block: a title + hint with a toggle that reveals a
/// slider when enabled. Used for the "head circumference (optional)" input.
struct BBOptionalMeasureToggle: View {
    let title: String
    let hint: String
    @Binding var isOn: Bool
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: String
    let minLabel: String
    let maxLabel: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(hint)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(color)
            }
            if isOn {
                HStack {
                    Spacer()
                    Text(display)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                Slider(value: $value, in: range, step: step)
                    .tint(color)
                HStack {
                    Text(minLabel)
                    Spacer()
                    Text(maxLabel)
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
        .animation(.easeInOut(duration: 0.25), value: isOn)
    }
}

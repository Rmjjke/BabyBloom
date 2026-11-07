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
            // The figure under the title at the accessibility sizes.
            BBValueRow {
                Text(title)
                    .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            } value: {
                Text(display)
                    .font(BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }
            Slider(value: $value, in: range, step: step)
                .tint(color)
            HStack {
                Text(minLabel)
                Spacer()
                Text(maxLabel)
            }
            .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
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

    private var toggle: some View {
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .tint(color)
    }

    private func labels(_ titleText: some View, _ hintText: some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            titleText
                .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            hintText
                .font(BBTheme.Typography.scaled(12, relativeTo: .body, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            // Beside the switch while every word of the title and the hint
            // fits beside it; else the switch goes under them at the title's
            // x, so a long word («Окружность» on a 320-pt screen at the
            // accessibility sizes) is never broken. Decided by the fit alone:
            // where the words fit, the larger sizes keep the beside form.
            ViewThatFits(in: .horizontal) {
                HStack {
                    labels(WordWrappingText(text: title), WordWrappingText(text: hint))
                    Spacer()
                    toggle
                }
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    labels(Text(title), Text(hint))
                    toggle
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isOn {
                HStack {
                    Spacer()
                    Text(display)
                        .font(BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                Slider(value: $value, in: range, step: step)
                    .tint(color)
                HStack {
                    Text(minLabel)
                    Spacer()
                    Text(maxLabel)
                }
                .font(BBTheme.Typography.scaled(11, relativeTo: .body, weight: .medium, design: .rounded))
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

import SwiftUI

// MARK: - Page 4: Growth measurements

struct GrowthPage: View {
    @Binding var weightKg: Double
    @Binding var heightCm: Double
    @Binding var headCm: Double
    @Binding var includeHead: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.lg) {
                    Text("📏")
                        .font(.system(size: 64))
                        .padding(.top, BBTheme.Spacing.md)

                    VStack(spacing: BBTheme.Spacing.sm) {
                        Text("onboarding.growth_title".l)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                        Text("onboarding.growth_hint".l)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    BBMeasureSlider(
                        title: "form.weight_kg".l,
                        value: $weightKg,
                        range: 1.0...20.0, step: 0.1,
                        display: String(format: "%.1f \("unit.kg".l)", weightKg),
                        color: BBTheme.Colors.growth,
                        minLabel: "1 \("unit.kg".l)",
                        maxLabel: "20 \("unit.kg".l)"
                    )

                    BBMeasureSlider(
                        title: "form.height_cm".l,
                        value: $heightCm,
                        range: 30.0...130.0, step: 0.5,
                        display: String(format: "%.0f \("unit.cm".l)", heightCm),
                        color: BBTheme.Colors.primary,
                        minLabel: "30 \("unit.cm".l)",
                        maxLabel: "130 \("unit.cm".l)"
                    )

                    BBOptionalMeasureToggle(
                        title: "form.head_cm".l,
                        hint: "onboarding.growth_head_optional".l,
                        isOn: $includeHead,
                        value: $headCm,
                        range: 25.0...55.0, step: 0.5,
                        display: String(format: "%.1f \("unit.cm".l)", headCm),
                        minLabel: "25 \("unit.cm".l)",
                        maxLabel: "55 \("unit.cm".l)",
                        color: BBTheme.Colors.accent
                    )

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 20)
            }
        }
    }

}

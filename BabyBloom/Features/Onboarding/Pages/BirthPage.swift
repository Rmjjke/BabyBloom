import SwiftUI

// MARK: - Page 2: Birth + Gender

struct BirthPage: View {
    @Binding var birthDate: Date
    @Binding var gender: Baby.Gender
    /// Birth weight and prematurity live here rather than on the growth page on
    /// purpose: they are facts about the birth, and a page away from the "weight
    /// today" slider they cannot be mistaken for it.
    @Binding var birthWeightKg: Double
    @Binding var recordsBirthWeight: Bool
    @Binding var gestationalWeeks: Double
    @Binding var wasBornEarly: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.xl) {
                    onboardingHeroIcon("calendar", color: BBTheme.Colors.primary)
                        .padding(.top, BBTheme.Spacing.md)

                    VStack(spacing: BBTheme.Spacing.sm) {
                        BBTheme.Typography.title1("onboarding.birth_title".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                        Text("onboarding.birth_hint".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Gender
                    HStack(spacing: BBTheme.Spacing.md) {
                        ForEach(Baby.Gender.allCases, id: \.self) { g in
                            Button {
                                withAnimation(.spring(response: 0.3)) { gender = g }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: g == .female ? "figure.stand.dress" : "figure.stand")
                                        .font(.system(size: 34))
                                        .foregroundStyle(gender == g ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
                                    Text(g.displayName.l)
                                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                                        .foregroundStyle(gender == g ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BBTheme.Spacing.md)
                                .background(gender == g ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                        .strokeBorder(gender == g ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                                )
                                .bbShadow(BBTheme.Shadow.card)
                            }
                            .buttonStyle(BBScaleButtonStyle())
                        }
                    }

                    // Date picker (compact)
                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                        DatePicker("onboarding.birth_label".l,
                                   selection: $birthDate,
                                   in: ...Date(),
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(BBTheme.Colors.primary)
                    }
                    .padding(BBTheme.Spacing.sm)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)

                    // Both optional and both off by default. A parent who does not
                    // know the birth weight must be able to walk past this without
                    // a made-up number being stored — the newborn screen would then
                    // measure a real baby against fiction.
                    BBOptionalMeasureToggle(
                        title: "form.birth_weight_kg".l,
                        hint: "form.birth_weight_hint".l,
                        isOn: $recordsBirthWeight,
                        value: $birthWeightKg,
                        range: 0.5...6.0, step: 0.05,
                        display: String(format: "%.2f \("unit.kg".l)", birthWeightKg),
                        minLabel: "0.5 \("unit.kg".l)",
                        maxLabel: "6 \("unit.kg".l)",
                        color: BBTheme.Colors.growth
                    )

                    BBOptionalMeasureToggle(
                        title: "form.preterm".l,
                        hint: "form.preterm_hint".l,
                        isOn: $wasBornEarly,
                        value: $gestationalWeeks,
                        range: 22...36, step: 1,
                        display: "\(Int(gestationalWeeks)) \("unit.weeks_short".l)",
                        minLabel: "22 \("unit.weeks_short".l)",
                        maxLabel: "36 \("unit.weeks_short".l)",
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

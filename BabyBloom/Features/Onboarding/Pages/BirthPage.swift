import SwiftUI

// MARK: - Birth + gender (page 3 of 11)

struct BirthPage: View {
    @Binding var birthDate: Date
    @Binding var gender: Baby.Gender
    /// Prematurity lives here because it is a fact about the birth. Birth
    /// weight used to sit beside it, as an optional toggle, back when the next
    /// page asked for the weight TODAY; that page now asks for the measurements
    /// at birth, so the same number is collected once, there.
    @Binding var gestationalWeeks: Double
    @Binding var wasBornEarly: Bool
    let onBack: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("onboarding.birth_hint".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .regular, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Gender: one column at accessibility sizes. On a 320-pt
                    // screen half the row keeps «Мальчик» 13.5 pt at AX2 and
                    // 4.6 with Bold Text, under the 8-pt spare; below them two
                    // hold, with 38 pt to spare at xxxLarge in Bold.
                    let genderColumns = BBTileColumns(large: 2, xLarge: 2, xxLarge: 2, xxxLarge: 2, accessibility: 1)
                    if genderColumns.count(at: dynamicTypeSize) == 1 {
                        VStack(spacing: BBTheme.Spacing.md) {
                            genderTiles
                        }
                    } else {
                        HStack(spacing: BBTheme.Spacing.md) {
                            genderTiles
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

                    // Off by default: a parent who does not know the gestational
                    // age must be able to walk past this without a made-up
                    // number being stored — corrected age would then measure a
                    // real baby against fiction.
                    BBOptionalMeasureToggle(
                        title: "form.preterm".l,
                        hint: "form.preterm_hint".l,
                        isOn: $wasBornEarly,
                        value: $gestationalWeeks,
                        range: 22...36, step: 1,
                        display: "\(Int(gestationalWeeks))\u{00A0}\("unit.weeks_short".l)",
                        minLabel: "22\u{00A0}\("unit.weeks_short".l)",
                        maxLabel: "36\u{00A0}\("unit.weeks_short".l)",
                        color: BBTheme.Colors.accent
                    )

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 20)
            }
        }
    }

    private var genderTiles: some View {
        ForEach(Baby.Gender.allCases, id: \.self) { g in
            Button {
                withAnimation(.spring(response: 0.3)) { gender = g }
            } label: {
                VStack(spacing: 8) {
                    // The figure grows with its word: it stands over it, not
                    // in a plate.
                    Image(systemName: g == .female ? "figure.stand.dress" : "figure.stand")
                        .font(BBTheme.Typography.scaled(34, relativeTo: .body, weight: .regular, design: .default))
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
}

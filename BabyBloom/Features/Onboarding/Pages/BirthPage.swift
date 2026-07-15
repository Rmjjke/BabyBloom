import SwiftUI

// MARK: - Page 2: Birth + Gender

struct BirthPage: View {
    @Binding var birthDate: Date
    @Binding var gender: Baby.Gender
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            ScrollView(showsIndicators: false) {
                VStack(spacing: BBTheme.Spacing.xl) {
                    Text("📅")
                        .font(.system(size: 64))
                        .padding(.top, BBTheme.Spacing.md)

                    VStack(spacing: BBTheme.Spacing.sm) {
                        Text("onboarding.birth_title".l)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                        Text("onboarding.birth_hint".l)
                            .font(.system(size: 14, design: .rounded))
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
                                    Text(g == .female ? "👧" : "👦")
                                        .font(.system(size: 38))
                                    Text(g.displayName.l)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(gender == g ? .white : BBTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, BBTheme.Spacing.md)
                                .background(gender == g ? BBTheme.Colors.primary : BBTheme.Colors.surface)
                                .cornerRadius(BBTheme.Radius.md)
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

                    Spacer(minLength: BBTheme.Spacing.xl)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 20)
            }
        }
    }
}

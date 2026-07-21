import SwiftUI

// MARK: - Page 3: Feeding Type

struct FeedingPage: View {
    @Binding var feedingType: Baby.FeedingType
    let babyName: String
    let onBack: () -> Void

    private var displayName: String {
        babyName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "baby.default_name".l
            : babyName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                Text("🤱")
                    .font(.system(size: 64))

                VStack(spacing: BBTheme.Spacing.sm) {
                    BBTheme.Typography.title1("onboarding.feeding_title".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("onboarding.feeding_hint".l)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }

                VStack(spacing: BBTheme.Spacing.md) {
                    ForEach(Baby.FeedingType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.spring(response: 0.3)) { feedingType = type }
                        } label: {
                            HStack(spacing: BBTheme.Spacing.md) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(BBTheme.Colors.primary)
                                    .frame(width: 46, height: 46)
                                    .background(feedingType == type ? BBTheme.Colors.primary.opacity(0.22) : BBTheme.Colors.primary.opacity(0.1))
                                    .cornerRadius(12)

                                Text(type.displayName.l)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(feedingType == type ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                                Spacer()
                                if feedingType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BBTheme.Colors.primary)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(BBTheme.Spacing.md)
                            .background(feedingType == type ? BBTheme.Colors.primary.opacity(0.12) : BBTheme.Colors.surface)
                            .cornerRadius(BBTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                                    .strokeBorder(feedingType == type ? BBTheme.Colors.primary : Color.clear, lineWidth: 1.5)
                            )
                            .bbShadow(BBTheme.Shadow.card)
                        }
                        .buttonStyle(BBScaleButtonStyle())
                    }
                }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()
            Spacer()
        }
    }
}

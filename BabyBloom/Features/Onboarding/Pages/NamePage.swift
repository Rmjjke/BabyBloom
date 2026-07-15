import SwiftUI

// MARK: - Page 1: Name

struct NamePage: View {
    @Binding var name: String
    let onBack: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            backButton(action: onBack)

            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                Text("🍼")
                    .font(.system(size: 72))

                VStack(spacing: BBTheme.Spacing.sm) {
                    Text("onboarding.name_title".l)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("onboarding.name_hint".l)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                TextField("onboarding.name_placeholder".l, text: $name)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(BBTheme.Spacing.md)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.md)
                    .bbShadow(BBTheme.Shadow.card)
                    .focused($focused)
                    .submitLabel(.done)
                    .onAppear { focused = true }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()
            Spacer()
        }
    }
}

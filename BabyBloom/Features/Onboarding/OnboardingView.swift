import SwiftUI
import SwiftData

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0
    @State private var babyName = ""
    @State private var birthDate = Date()
    @State private var gender: Baby.Gender = .female
    @State private var feedingType: Baby.FeedingType = .breast
    @State private var isCreating = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [BBTheme.Colors.background, BBTheme.Colors.primary.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? BBTheme.Colors.primary : BBTheme.Colors.primary.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.top, 20)

                // Pages
                TabView(selection: $currentPage) {
                    OnboardingWelcomePage()
                        .tag(0)
                    OnboardingNamePage(name: $babyName)
                        .tag(1)
                    OnboardingBirthPage(birthDate: $birthDate, gender: $gender)
                        .tag(2)
                    OnboardingFeedingPage(feedingType: $feedingType)
                        .tag(3)
                    OnboardingReadyPage(babyName: babyName)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Bottom actions
                VStack(spacing: BBTheme.Spacing.sm) {
                    if currentPage < totalPages - 1 {
                        BBPrimaryButton(
                            nextButtonTitle,
                            icon: "arrow.right"
                        ) {
                            withAnimation { advance() }
                        }
                        .disabled(!canAdvance)
                        .opacity(canAdvance ? 1 : 0.5)

                        if currentPage > 0 {
                            Button("Назад") {
                                withAnimation { currentPage -= 1 }
                            }
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    } else {
                        BBPrimaryButton("Начать", icon: "sparkles", isLoading: isCreating) {
                            createBabyAndFinish()
                        }
                    }
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 40)
            }
        }
    }

    private var nextButtonTitle: String {
        switch currentPage {
        case 0: return "Начать"
        case 1: return "Далее"
        case 2: return "Далее"
        case 3: return "Почти готово"
        default: return "Далее"
        }
    }

    private var canAdvance: Bool {
        switch currentPage {
        case 1: return !babyName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func advance() {
        if currentPage < totalPages - 1 {
            currentPage += 1
        }
    }

    private func createBabyAndFinish() {
        isCreating = true
        let name = babyName.trimmingCharacters(in: .whitespaces)
        let baby = Baby(
            name: name.isEmpty ? "Малыш" : name,
            birthDate: birthDate,
            gender: gender,
            feedingType: feedingType
        )
        modelContext.insert(baby)
        try? modelContext.save()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            onComplete()
        }
    }
}

// MARK: - Welcome Page
private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            Spacer()

            // Logo / Hero
            ZStack {
                Circle()
                    .fill(BBTheme.Colors.primary.opacity(0.12))
                    .frame(width: 160, height: 160)
                Circle()
                    .fill(BBTheme.Colors.accent.opacity(0.2))
                    .frame(width: 120, height: 120)
                Text("🌸")
                    .font(.system(size: 72))
            }

            VStack(spacing: BBTheme.Spacing.md) {
                Text("BabyBloom")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)

                Text("Ваш умный помощник\nв уходе за малышом")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Трекинг кормления, сна и развития ребёнка в одном приложении")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BBTheme.Spacing.xl)
            }

            // Feature pills
            VStack(spacing: BBTheme.Spacing.sm) {
                OnboardingFeatureRow(icon: "heart.fill", color: BBTheme.Colors.feeding, text: "Трекинг кормления")
                OnboardingFeatureRow(icon: "moon.fill", color: BBTheme.Colors.sleep, text: "Контроль сна")
                OnboardingFeatureRow(icon: "chart.line.uptrend.xyaxis", color: BBTheme.Colors.growth, text: "График роста по ВОЗ")
            }
            .padding(.horizontal, BBTheme.Spacing.xl)

            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .cornerRadius(8)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.md)
        .padding(.vertical, BBTheme.Spacing.sm)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
    }
}

// MARK: - Name Page
private struct OnboardingNamePage: View {
    @Binding var name: String
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            Spacer()

            Text("🍼")
                .font(.system(size: 64))

            VStack(spacing: BBTheme.Spacing.sm) {
                Text("Как зовут малыша?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("Это поможет персонализировать приложение")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Имя ребёнка", text: $name)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(BBTheme.Spacing.md)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .bbShadow(BBTheme.Shadow.card)
                .focused($isFocused)
                .submitLabel(.done)
                .onAppear { isFocused = true }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }
}

// MARK: - Birth Date & Gender Page
private struct OnboardingBirthPage: View {
    @Binding var birthDate: Date
    @Binding var gender: Baby.Gender

    var body: some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            Spacer()

            Text("📅")
                .font(.system(size: 64))

            VStack(spacing: BBTheme.Spacing.sm) {
                Text("Дата рождения и пол")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("Для расчёта перцентилей роста по ВОЗ")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            // Gender selector
            HStack(spacing: BBTheme.Spacing.md) {
                ForEach(Baby.Gender.allCases, id: \.self) { g in
                    Button {
                        withAnimation(.spring(response: 0.3)) { gender = g }
                    } label: {
                        VStack(spacing: 6) {
                            Text(g == .female ? "👧" : "👦")
                                .font(.system(size: 36))
                            Text(g.displayName)
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

            // Date picker
            DatePicker("Дата рождения", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(BBTheme.Colors.primary)
                .padding(BBTheme.Spacing.sm)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .bbShadow(BBTheme.Shadow.card)

            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }
}

// MARK: - Feeding Type Page
private struct OnboardingFeedingPage: View {
    @Binding var feedingType: Baby.FeedingType

    var body: some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            Spacer()

            Text("🤱")
                .font(.system(size: 64))

            VStack(spacing: BBTheme.Spacing.sm) {
                Text("Тип вскармливания")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Text("Для персонализированных советов")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }

            VStack(spacing: BBTheme.Spacing.md) {
                ForEach(Baby.FeedingType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(.spring(response: 0.3)) { feedingType = type }
                    } label: {
                        HStack {
                            Image(systemName: type.icon)
                                .font(.system(size: 22))
                                .foregroundStyle(feedingType == type ? .white : BBTheme.Colors.primary)
                                .frame(width: 44, height: 44)
                                .background(feedingType == type ? .white.opacity(0.25) : BBTheme.Colors.primary.opacity(0.1))
                                .cornerRadius(12)

                            Text(type.displayName)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(feedingType == type ? .white : BBTheme.Colors.textPrimary)

                            Spacer()

                            if feedingType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(BBTheme.Spacing.md)
                        .background(feedingType == type ? BBTheme.Colors.primary : BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)
                    }
                    .buttonStyle(BBScaleButtonStyle())
                }
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }
}

// MARK: - Ready Page
private struct OnboardingReadyPage: View {
    let babyName: String

    var body: some View {
        VStack(spacing: BBTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(BBTheme.Colors.success.opacity(0.2))
                    .frame(width: 140, height: 140)
                Text("✨")
                    .font(.system(size: 72))
            }

            VStack(spacing: BBTheme.Spacing.sm) {
                Text("Всё готово!")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.primary)

                Text("Добро пожаловать в BabyBloom\(babyName.isEmpty ? "" : ", \(babyName) ждёт вас")!")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Начинайте фиксировать события нажатием одной кнопки на главном экране.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BBTheme.Spacing.md)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, BBTheme.Spacing.lg)
    }
}

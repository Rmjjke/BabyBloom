import SwiftUI
import SwiftData

// MARK: - Root

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var page = 0
    @State private var babyName = ""
    @State private var birthDate = Date()
    @State private var gender: Baby.Gender = .female
    @State private var feedingType: Baby.FeedingType = .breast
    @State private var isCreating = false

    // Quiz pages: 1, 2, 3  →  progress 0.30, 0.65, 1.0 (Goal Gradient Effect)
    private let quizPages: [Int] = [1, 2, 3]
    private func quizProgress(for p: Int) -> Double {
        switch p { case 1: return 0.30; case 2: return 0.65; case 3: return 1.0; default: return 0 }
    }

    var body: some View {
        ZStack {
            BBTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Progress bar — visible only during quiz
                if quizPages.contains(page) {
                    progressBar
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                // Pages
                Group {
                    switch page {
                    case 0: WelcomePage(onStart: next)
                    case 1: NamePage(name: $babyName, onBack: back)
                    case 2: BirthPage(birthDate: $birthDate, gender: $gender, onBack: back)
                    case 3: FeedingPage(feedingType: $feedingType, babyName: babyName, onBack: back)
                    case 4: FactPage(onContinue: next)
                    case 5: GeneratingPage(babyName: babyName, onDone: next)
                    case 6: PremiumPage(babyName: babyName,
                                        onTrial:   { createAndFinish() },
                                        onSkip:    { createAndFinish() })
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(page)

                // Bottom nav — quiz pages only
                if quizPages.contains(page) {
                    bottomNav
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: Progress bar
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(BBTheme.Colors.primary.opacity(0.12)).frame(height: 4)
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [BBTheme.Colors.primary, BBTheme.Colors.accent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * quizProgress(for: page), height: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: page)
            }
        }
        .frame(height: 4)
        .padding(.bottom, 8)
    }

    // MARK: Bottom nav
    private var bottomNav: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            BBPrimaryButton("button.next".l, icon: "arrow.right") {
                withAnimation(.easeInOut(duration: 0.3)) { next() }
            }
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
        }
    }

    private var canAdvance: Bool {
        page == 1 ? !babyName.trimmingCharacters(in: .whitespaces).isEmpty : true
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
    }

    private func back() {
        withAnimation(.easeInOut(duration: 0.3)) { page -= 1 }
    }

    private func createAndFinish() {
        guard !isCreating else { return }
        isCreating = true
        let name = babyName.trimmingCharacters(in: .whitespaces)
        let baby = Baby(
            name: name.isEmpty ? "baby.default_name".l : name,
            birthDate: birthDate,
            gender: gender,
            feedingType: feedingType
        )
        modelContext.insert(baby)
        try? modelContext.save()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            onComplete()
        }
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    let onStart: () -> Void
    @State private var appear = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero
                ZStack {
                    // Background blobs
                    Circle()
                        .fill(Color(hex: "#6B5EA8").opacity(0.12))
                        .frame(width: 340, height: 340)
                        .offset(x: 40, y: -20)
                        .blur(radius: 30)
                    Circle()
                        .fill(Color(hex: "#E8A0BF").opacity(0.18))
                        .frame(width: 220, height: 220)
                        .offset(x: -60, y: 60)
                        .blur(radius: 20)

                    VStack(spacing: BBTheme.Spacing.md) {
                        // Logo mark
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#9B8FD8"), Color(hex: "#6B5EA8")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 96, height: 96)
                                .bbShadow(BBTheme.Shadow.button)
                            Text("🌸")
                                .font(.system(size: 48))
                        }
                        .scaleEffect(appear ? 1 : 0.6)
                        .opacity(appear ? 1 : 0)

                        VStack(spacing: 6) {
                            Text("BabyBloom")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.primary)
                                .offset(y: appear ? 0 : 20)
                                .opacity(appear ? 1 : 0)

                            Text("onboarding.tagline".l)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .offset(y: appear ? 0 : 20)
                                .opacity(appear ? 1 : 0)
                        }
                    }
                }
                .frame(height: 320)

                // Feature cards
                VStack(spacing: BBTheme.Spacing.sm) {
                    WelcomeFeatureCard(icon: "heart.fill",
                                       color: BBTheme.Colors.feeding,
                                       title: "onboarding.feature.feeding".l,
                                       delay: 0.15)
                    WelcomeFeatureCard(icon: "moon.fill",
                                       color: BBTheme.Colors.sleep,
                                       title: "onboarding.feature.sleep".l,
                                       delay: 0.25)
                    WelcomeFeatureCard(icon: "chart.line.uptrend.xyaxis",
                                       color: BBTheme.Colors.growth,
                                       title: "onboarding.feature.growth".l,
                                       delay: 0.35)
                    WelcomeFeatureCard(icon: "drop.fill",
                                       color: BBTheme.Colors.diaper,
                                       title: "nav.diapers".l,
                                       delay: 0.45)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, BBTheme.Spacing.lg)

                // Social proof
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#F5C518"))
                    }
                    Text("onboarding.social_proof".l)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
                .opacity(appear ? 1 : 0)

                // CTA
                BBPrimaryButton("button.start".l, icon: "arrow.right") {
                    onStart()
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.bottom, 40)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                appear = true
            }
        }
    }
}

private struct WelcomeFeatureCard: View {
    let icon: String
    let color: Color
    let title: String
    let delay: Double
    @State private var appear = false

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .cornerRadius(12)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(color.opacity(0.7))
                .font(.system(size: 18))
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
        .offset(x: appear ? 0 : 30)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 1: Name

private struct NamePage: View {
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

// MARK: - Page 2: Birth + Gender

private struct BirthPage: View {
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

// MARK: - Page 3: Feeding Type

private struct FeedingPage: View {
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
                    Text("onboarding.feeding_title".l)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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
                                    .foregroundStyle(feedingType == type ? .white : BBTheme.Colors.primary)
                                    .frame(width: 46, height: 46)
                                    .background(feedingType == type ? .white.opacity(0.22) : BBTheme.Colors.primary.opacity(0.1))
                                    .cornerRadius(12)

                                Text(type.displayName.l)
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(feedingType == type ? .white : BBTheme.Colors.textPrimary)
                                Spacer()
                                if feedingType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 20))
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
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page 4: Fact / Delight

private struct FactPage: View {
    let onContinue: () -> Void
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                // Illustration card
                ZStack {
                    RoundedRectangle(cornerRadius: BBTheme.Radius.xl)
                        .fill(
                            LinearGradient(
                                colors: [BBTheme.Colors.primary.opacity(0.15), BBTheme.Colors.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 200)
                    VStack(spacing: BBTheme.Spacing.md) {
                        Text("🍼")
                            .font(.system(size: 72))
                            .rotationEffect(.degrees(appear ? 0 : -15))
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Circle()
                                    .fill(BBTheme.Colors.primary.opacity(0.3 + Double(i) * 0.14))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(appear ? 1 : 0.3)
                                    .animation(.spring(response: 0.4).delay(Double(i) * 0.07), value: appear)
                            }
                        }
                    }
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .scaleEffect(appear ? 1 : 0.9)
                .opacity(appear ? 1 : 0)

                VStack(spacing: BBTheme.Spacing.md) {
                    Text("onboarding.fact.title".l)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(BBTheme.Radius.pill)

                    Text("onboarding.fact.body".l)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: appear ? 0 : 20)
                .opacity(appear ? 1 : 0)
            }

            Spacer()

            BBPrimaryButton("onboarding.fact.cta".l, icon: "wand.and.stars") {
                onContinue()
            }
            .padding(.horizontal, BBTheme.Spacing.lg)
            .padding(.bottom, 40)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 5: Generating

private struct GeneratingPage: View {
    let babyName: String
    let onDone: () -> Void

    @State private var completedSteps: Set<Int> = []
    @State private var showDone = false

    private let steps: [(key: String, icon: String)] = [
        ("onboarding.gen.step1", "heart.fill"),
        ("onboarding.gen.step2", "chart.line.uptrend.xyaxis"),
        ("onboarding.gen.step3", "moon.fill"),
        ("onboarding.gen.step4", "bell.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: BBTheme.Spacing.xl) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(BBTheme.Colors.primary.opacity(0.12), lineWidth: 6)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: showDone ? 1 : CGFloat(completedSteps.count) / CGFloat(steps.count))
                        .stroke(
                            LinearGradient(colors: [BBTheme.Colors.primary, BBTheme.Colors.accent],
                                            startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: completedSteps.count)
                    Text("🌸").font(.system(size: 44))
                }

                VStack(spacing: BBTheme.Spacing.sm) {
                    let name = babyName.trimmingCharacters(in: .whitespaces)
                    Text(name.isEmpty ? "onboarding.gen.title".l : String(format: "onboarding.gen.title".l.replacingOccurrences(of: "…", with: " \(name)…")))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(completedSteps.contains(i) ? BBTheme.Colors.primary : BBTheme.Colors.primary.opacity(0.1))
                                        .frame(width: 28, height: 28)
                                    if completedSteps.contains(i) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Image(systemName: step.icon)
                                            .font(.system(size: 11))
                                            .foregroundStyle(BBTheme.Colors.primary.opacity(0.5))
                                    }
                                }
                                .animation(.spring(response: 0.4), value: completedSteps.contains(i))

                                Text(step.key.l)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(completedSteps.contains(i) ? BBTheme.Colors.textPrimary : BBTheme.Colors.textSecondary)
                                    .animation(.easeIn, value: completedSteps.contains(i))
                            }
                            .opacity(i <= completedSteps.count ? 1 : 0.3)
                        }
                    }
                    .padding(BBTheme.Spacing.lg)
                    .background(BBTheme.Colors.surface)
                    .cornerRadius(BBTheme.Radius.lg)
                    .bbShadow(BBTheme.Shadow.card)
                }
            }
            .padding(.horizontal, BBTheme.Spacing.lg)

            Spacer()
            Spacer()
        }
        .task {
            for i in 0..<steps.count {
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation { completedSteps.insert(i) }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation { showDone = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            onDone()
        }
    }
}

// MARK: - Page 6: Premium

private struct PremiumPage: View {
    let babyName: String
    let onTrial: () -> Void
    let onSkip: () -> Void
    @State private var appear = false

    private let features: [(icon: String, text: String)] = [
        ("infinity", "onboarding.premium.f1"),
        ("bell.badge.fill", "onboarding.premium.f2"),
        ("square.and.arrow.up.fill", "onboarding.premium.f3"),
        ("person.2.fill", "onboarding.premium.f4"),
        ("chart.bar.fill", "onboarding.premium.f5"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Hero gradient header
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "#6B5EA8"), Color(hex: "#9B8FD8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea(edges: .top)

                    VStack(spacing: BBTheme.Spacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 36)
                            .scaleEffect(appear ? 1 : 0.7)

                        Text("onboarding.premium.title".l)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("onboarding.premium.headline".l)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BBTheme.Spacing.xl)
                            .padding(.bottom, 32)
                    }
                    .offset(y: appear ? 0 : 20)
                }
                .frame(height: 240)
                .cornerRadius(BBTheme.Radius.xl, corners: [.bottomLeft, .bottomRight])
                .opacity(appear ? 1 : 0)

                // Features list
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { i, feat in
                        HStack(spacing: BBTheme.Spacing.md) {
                            Image(systemName: feat.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(BBTheme.Colors.primary)
                                .frame(width: 36, height: 36)
                                .background(BBTheme.Colors.primary.opacity(0.1))
                                .cornerRadius(10)
                            Text(feat.text.l)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BBTheme.Colors.primary)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, BBTheme.Spacing.md)

                        if i < features.count - 1 {
                            Divider().padding(.horizontal, BBTheme.Spacing.md)
                        }
                    }
                }
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.lg)
                .bbShadow(BBTheme.Shadow.card)
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.top, BBTheme.Spacing.xl)
                .offset(y: appear ? 0 : 30)
                .opacity(appear ? 1 : 0)

                // Trial badge
                Text("onboarding.premium.badge".l)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, BBTheme.Spacing.md)
                    .opacity(appear ? 1 : 0)

                // CTAs
                VStack(spacing: BBTheme.Spacing.sm) {
                    BBPrimaryButton("onboarding.premium.trial".l, icon: "sparkles") {
                        onTrial()
                    }

                    Button("onboarding.premium.skip".l) {
                        onSkip()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .padding(.horizontal, BBTheme.Spacing.lg)
                .padding(.vertical, BBTheme.Spacing.xl)
                .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Helpers

private func backButton(action: @escaping () -> Void) -> some View {
    HStack {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("button.back".l)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(.leading, BBTheme.Spacing.lg)
        .padding(.top, 12)
        Spacer()
    }
}

// Corner radius helper for specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

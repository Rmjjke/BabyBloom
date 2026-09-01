import SwiftUI
import SwiftData

// MARK: - Root

struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store
    @State private var step: OnboardingStep = .welcome
    @State private var babyName = ""
    @State private var birthDate = Date()
    @State private var gender: Baby.Gender = .female
    @State private var feedingType: Baby.FeedingType = .breast
    @State private var growthWeightKg: Double = 3.5
    @State private var growthHeightCm: Double = 50.0
    @State private var growthHeadCm: Double = 34.0
    @State private var growthIncludeHead: Bool = false
    @State private var birthWeightKg: Double = 3.4
    @State private var recordsBirthWeight: Bool = false
    @State private var gestationalWeeks: Double = 34
    @State private var wasBornEarly: Bool = false
    @State private var isCreating = false

    var body: some View {
        ZStack {
            // One ground for the whole flow: the pages slide over it, so the
            // backdrop is continuous instead of restarting per page.
            OnboardingBackground()

            VStack(spacing: 0) {

                // Progress bar — visible only during quiz
                if step.isQuiz {
                    progressBar
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                // Pages
                Group {
                    switch step {
                    case .welcome: WelcomePage(onStart: next)
                    case .name: NamePage(name: $babyName, onBack: back)
                    case .birth: BirthPage(birthDate: $birthDate, gender: $gender,
                                           birthWeightKg: $birthWeightKg,
                                           recordsBirthWeight: $recordsBirthWeight,
                                           gestationalWeeks: $gestationalWeeks,
                                           wasBornEarly: $wasBornEarly,
                                           onBack: back)
                    case .feeding: FeedingPage(feedingType: $feedingType, babyName: babyName, onBack: back)
                    case .growth: GrowthPage(weightKg: $growthWeightKg, heightCm: $growthHeightCm,
                                             headCm: $growthHeadCm, includeHead: $growthIncludeHead,
                                             onBack: back)
                    case .fact: FactPage(babyName: babyName, birthDate: birthDate,
                                         feedingType: feedingType, onContinue: next)
                    case .generating: GeneratingPage(babyName: babyName, birthDate: birthDate, onDone: next)
                    case .notifications: NotificationsPage(babyName: babyName, onContinue: next)
                    case .widgets: WidgetShowcasePage(babyName: babyName, onContinue: next)
                    case .premium: PremiumPage(onPurchased: { createAndFinish() },
                                               onSkip:      { createAndFinish() })
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)

                // Bottom nav — quiz pages only
                if step.isQuiz {
                    bottomNav
                        .padding(.horizontal, BBTheme.Spacing.lg)
                        .padding(.bottom, 36)
                }
            }
        }
        // Prices must be on screen by page 10. Loading starts with page 1 so a
        // slow network spends onboarding time, not paywall time. PlanPickerSection
        // also calls loadProducts() on its own .task; the double call is
        // deliberate and idempotent (SubscriptionManager is safe to reload).
        .task { await store.loadProducts() }
    }

    // MARK: Progress bar
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(BBTheme.Colors.primary.opacity(0.12)).frame(height: 4)
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: [BBTheme.Colors.primary, BBTheme.Colors.accent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * step.quizProgress, height: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
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
        step == .name ? !babyName.trimmingCharacters(in: .whitespaces).isEmpty : true
    }

    private func next() {
        guard let nextStep = step.next else { return }
        withAnimation(.easeInOut(duration: 0.3)) { step = nextStep }
    }

    private func back() {
        guard let previousStep = step.previous else { return }
        withAnimation(.easeInOut(duration: 0.3)) { step = previousStep }
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
        // Left nil when the parent did not record them — nil means "unknown"
        // everywhere downstream, and every growth feature degrades to still
        // being useful without them.
        baby.birthWeightKg = recordsBirthWeight ? birthWeightKg : nil
        baby.gestationalWeeks = wasBornEarly ? Int(gestationalWeeks) : nil
        modelContext.insert(baby)
        let growth = GrowthEntry(
            date: Date(),
            weightKg: growthWeightKg,
            heightCm: growthHeightCm,
            headCircumferenceCm: growthIncludeHead ? growthHeadCm : nil
        )
        growth.baby = baby
        modelContext.insert(growth)
        try? modelContext.save()
        // The widget is already on the home screen for some parents; without
        // this it keeps showing the default name until its own cadence.
        WidgetRefresh.profileChanged()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            onComplete()
        }
    }
}

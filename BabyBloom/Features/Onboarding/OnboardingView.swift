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
    /// The measurements page's opt-out. True by default: most parents have the
    /// discharge record to hand, and defaulting to "unknown" would bury the
    /// question the page exists to ask.
    @State private var knowsBirthMeasurements: Bool = true
    @State private var gestationalWeeks: Double = 34
    @State private var wasBornEarly: Bool = false
    @State private var isCreating = false
    /// Set only by the loader's own completion, so the paywall can say it was
    /// reached THROUGH Generating. The e2e walks assert this rather than the
    /// loader, which is too short-lived to catch (DECISIONS 2026-09-22).
    @State private var generatingFinished = false

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
                                           gestationalWeeks: $gestationalWeeks,
                                           wasBornEarly: $wasBornEarly,
                                           onBack: back)
                    case .feeding: FeedingPage(feedingType: $feedingType, babyName: babyName, onBack: back)
                    case .growth: GrowthPage(weightKg: $growthWeightKg, heightCm: $growthHeightCm,
                                             headCm: $growthHeadCm, includeHead: $growthIncludeHead,
                                             knowsMeasurements: $knowsBirthMeasurements,
                                             onBack: back)
                    case .fact: FactPage(babyName: babyName, birthDate: birthDate,
                                         feedingType: feedingType, onContinue: next)
                    case .growthShowcase:
                        // The measurements page's opt-out is what nil means
                        // here — see `OnboardingGrowthPreview`. Same expression
                        // as `createAndFinish`'s, and for the same reason: an
                        // invented 3.5 kg must not become a percentile either.
                        GrowthShowcasePage(babyName: babyName, birthDate: birthDate,
                                           gender: gender,
                                           birthWeightKg: knowsBirthMeasurements ? growthWeightKg : nil,
                                           gestationalWeeks: wasBornEarly ? Int(gestationalWeeks) : nil,
                                           onContinue: next)
                    case .notifications: NotificationsPage(babyName: babyName, onContinue: next)
                    case .widgets: WidgetShowcasePage(babyName: babyName, onContinue: next)
                    case .generating: GeneratingPage(babyName: babyName, birthDate: birthDate,
                                                     onDone: { generatingFinished = true; next() })
                    case .premium: PremiumPage(onPurchased: { createAndFinish() },
                                               onSkip:      { createAndFinish() })
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(generatingFinished
                                                 ? "onboarding.premium.afterGenerating"
                                                 : "onboarding.premium")
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
        // Every page change goes through `step`, forward or back, so this is
        // the funnel's single choke point; `initial` reports the welcome page.
        .onChange(of: step, initial: true) { _, page in
            Analytics.shared.track(.onboardingPageViewed(.init(page)))
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
        Analytics.shared.track(.onboardingCompleted(birthMeasurementsKnown: knowsBirthMeasurements))
        let created = OnboardingBabyBuilder.build(
            name: babyName,
            birthDate: birthDate,
            gender: gender,
            feedingType: feedingType,
            measurements: knowsBirthMeasurements
                ? .init(weightKg: growthWeightKg,
                        heightCm: growthHeightCm,
                        headCircumferenceCm: growthIncludeHead ? growthHeadCm : nil)
                : nil,
            gestationalWeeks: wasBornEarly ? Int(gestationalWeeks) : nil
        )
        modelContext.insert(created.baby)
        // Absent when the parent answered "I don't remember" — the app then
        // starts with an empty history, which every growth surface already
        // handles as its ordinary first-run state.
        if let firstEntry = created.firstEntry { modelContext.insert(firstEntry) }
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

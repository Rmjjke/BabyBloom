import SwiftUI
import SwiftData

@main
struct BabyBloomApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Branded splash plays on every cold launch (not persisted). E2E flows
    // launch with `-BBSkipSplash true` to skip its ~5s; iOS folds launch
    // arguments into UserDefaults' argument domain, which is also how those
    // flows drive `hasCompletedOnboarding`, `appLanguage` and `appAppearance`
    // — those need no hook because @AppStorage already reads that domain.
    @State private var showingSplash = !UserDefaults.standard.bool(forKey: "BBSkipSplash")
    @AppStorage("appLanguage") private var appLanguage = LocalizationManager.deviceDefault
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system.rawValue

    @Environment(\.scenePhase) private var scenePhase
    @State private var subscriptionManager = SubscriptionManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Baby.self,
            FeedingEntry.self,
            SleepEntry.self,
            DiaperEntry.self,
            GrowthEntry.self,
            CustomEvent.self
        ])
        let config = ModelConfiguration(schema: schema,
                                        groupContainer: .identifier("group.com.nenita.app"),
                                        cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if showingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showingSplash = false
                        }
                    }
                } else if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    // No permission request here any more: onboarding asks on
                    // its own notifications page, where the ask is motivated.
                    // Firing it from this closure put the system dialog on top
                    // of the Dashboard the instant onboarding ended.
                    OnboardingView(onComplete: { hasCompletedOnboarding = true })
                }
            }
            .id(appLanguage)
            // Applied at the root so the splash, onboarding and main UI all
            // follow the same choice. Must not be re-declared further down the
            // tree: an inner `.preferredColorScheme(nil)` would win and cancel
            // the user's pick.
            .preferredColorScheme(AppAppearance.from(appAppearance).colorScheme)
            // Dynamic Type: allow growth up to AX2 (a sensible ceiling for MVP —
            // full AX5 would demand deeper per-screen relayout). Below this, the
            // scaled Typography and growth-safe layouts do the work.
            // The ceiling comes from BBTheme so this modifier and the font cap in
            // `Typography.scaledPointSize` are the same number. This modifier alone
            // only ever set the environment; it never constrained the fonts.
            .dynamicTypeSize(...BBTheme.Typography.maxDynamicTypeSize)
            .environment(subscriptionManager)
            .onAppear {
                LocalizationManager.shared.setLanguage(appLanguage)
                // Simulator-only, and only when launched with
                // `-BBSeedScenario <name>`. Runs before the adoption pass so
                // the pass sees the seeded data — which is already linked to
                // its Baby, so it finds nothing to adopt.
                SeedScenario.seedIfRequested(in: sharedModelContainer.mainContext)
                // Entries created before they were linked to their Baby still
                // have a nil owner, which makes Baby's cascade rules inert.
                // Runs at most once per install and is a no-op afterwards.
                OrphanedEntryAdoption.runIfNeeded(in: sharedModelContainer.mainContext)
            }
            .onChange(of: appLanguage) { _, newValue in
                LocalizationManager.shared.setLanguage(newValue)
                WidgetRefresh.languageChanged()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.onAppForegrounded()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

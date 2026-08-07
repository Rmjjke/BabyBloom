import SwiftUI
import SwiftData

@main
struct BabyBloomApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Branded splash plays on every cold launch (not persisted).
    @State private var showingSplash = true
    @AppStorage("appLanguage") private var appLanguage = LocalizationManager.deviceDefault

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
                                        groupContainer: .identifier("group.com.babybloom.app"),
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
                        .preferredColorScheme(nil)
                } else {
                    OnboardingView(onComplete: {
                        hasCompletedOnboarding = true
                        NotificationManager.shared.requestPermission()
                    })
                    .preferredColorScheme(nil)
                }
            }
            .id(appLanguage)
            // Dynamic Type: allow growth up to AX2 (a sensible ceiling for MVP —
            // full AX5 would demand deeper per-screen relayout). Below this, the
            // scaled Typography and growth-safe layouts do the work.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .environment(subscriptionManager)
            .onAppear {
                LocalizationManager.shared.setLanguage(appLanguage)
            }
            .onChange(of: appLanguage) { _, newValue in
                LocalizationManager.shared.setLanguage(newValue)
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

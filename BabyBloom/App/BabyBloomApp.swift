import SwiftUI
import SwiftData

@main
struct BabyBloomApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasShownSplash") private var hasShownSplash = false
    @AppStorage("appLanguage") private var appLanguage = "ru"

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
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasShownSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasShownSplash = true
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

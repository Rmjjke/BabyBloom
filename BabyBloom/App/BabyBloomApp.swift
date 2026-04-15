import SwiftUI
import SwiftData

@main
struct BabyBloomApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasShownSplash") private var hasShownSplash = false
    @AppStorage("appLanguage") private var appLanguage = "ru"
    @State private var showSplash = false

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
                if showSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showSplash = false
                            hasShownSplash = true
                        }
                    }
                } else if hasCompletedOnboarding {
                    MainTabView()
                        .preferredColorScheme(nil)
                } else {
                    OnboardingView(onComplete: {
                        hasCompletedOnboarding = true
                    })
                    .preferredColorScheme(nil)
                }
            }
            .id(appLanguage)
            .onAppear {
                LocalizationManager.shared.setLanguage(appLanguage)
                // Show splash only on very first launch
                if !hasShownSplash {
                    showSplash = true
                }
            }
            .onChange(of: appLanguage) { _, newValue in
                LocalizationManager.shared.setLanguage(newValue)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

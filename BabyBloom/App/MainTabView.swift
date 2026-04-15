import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @Query private var babies: [Baby]

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("tab.home".l, systemImage: "house.fill")
                }
                .tag(Tab.dashboard)

            FeedingView()
                .tabItem {
                    Label("tab.feeding".l, systemImage: "heart.fill")
                }
                .tag(Tab.feeding)

            SleepView()
                .tabItem {
                    Label("tab.sleep".l, systemImage: "moon.fill")
                }
                .tag(Tab.sleep)

            GrowthView()
                .tabItem {
                    Label("tab.growth".l, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.growth)

            MoreView()
                .tabItem {
                    Label("tab.more".l, systemImage: "ellipsis.circle.fill")
                }
                .tag(Tab.more)
        }
        .tint(BBTheme.Colors.primary)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    enum Tab: String, CaseIterable {
        case dashboard, feeding, sleep, growth, more
    }
}

// MARK: - More Tab
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: DiaperView()) {
                    Label("nav.diapers".l, systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(BBTheme.Colors.diaper)
                }
                NavigationLink(destination: EventsView()) {
                    Label("nav.events".l, systemImage: "star.fill")
                        .foregroundStyle(BBTheme.Colors.events)
                }
                NavigationLink(destination: SettingsView()) {
                    Label("nav.settings".l, systemImage: "gearshape.fill")
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("tab.more".l)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("appLanguage") private var appLanguage = "ru"

    var body: some View {
        List {
            Section {
                HStack {
                    Label("settings.language".l, systemImage: "globe")
                    Spacer()
                    Picker("", selection: $appLanguage) {
                        Text("🇷🇺 Рус").tag("ru")
                        Text("🇬🇧 Eng").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            } header: {
                Text("settings.language".l)
            }

            Section("settings.notifications".l) {
                Label("settings.reminders".l, systemImage: "bell.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }
            Section("settings.data".l) {
                Label("settings.export".l, systemImage: "arrow.up.doc.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Label("settings.icloud".l, systemImage: "icloud.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }
            Section("settings.app_section".l) {
                Label("settings.about".l, systemImage: "info.circle.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Label("settings.premium".l, systemImage: "star.fill")
                    .foregroundStyle(BBTheme.Colors.primary)
            }
        }
        .navigationTitle("nav.settings".l)
    }
}

import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    @Query private var babies: [Baby]

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Главная", systemImage: "house.fill")
                }
                .tag(Tab.dashboard)

            FeedingView()
                .tabItem {
                    Label("Кормление", systemImage: "heart.fill")
                }
                .tag(Tab.feeding)

            SleepView()
                .tabItem {
                    Label("Сон", systemImage: "moon.fill")
                }
                .tag(Tab.sleep)

            GrowthView()
                .tabItem {
                    Label("Рост", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.growth)

            MoreView()
                .tabItem {
                    Label("Ещё", systemImage: "ellipsis.circle.fill")
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

// MARK: - More Tab (placeholder for Diaper, Events, Settings)
struct MoreView: View {
    @State private var showDiaper = false
    @State private var showEvents = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(destination: DiaperView()) {
                    Label("Подгузники", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(BBTheme.Colors.diaper)
                }
                NavigationLink(destination: EventsView()) {
                    Label("События", systemImage: "star.fill")
                        .foregroundStyle(BBTheme.Colors.events)
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Настройки", systemImage: "gearshape.fill")
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            .navigationTitle("Ещё")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        List {
            Section("Уведомления") {
                Label("Настроить напоминания", systemImage: "bell.fill")
            }
            Section("Данные") {
                Label("Экспорт данных", systemImage: "arrow.up.doc.fill")
                Label("Синхронизация iCloud", systemImage: "icloud.fill")
            }
            Section("Приложение") {
                Label("О приложении", systemImage: "info.circle.fill")
                Label("BabyBloom Premium", systemImage: "star.fill")
            }
        }
        .navigationTitle("Настройки")
    }
}

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
    @Environment(SubscriptionManager.self) private var store
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var showProfileEdit = false

    private var baby: Baby? { babies.first }

    @ViewBuilder
    private var exportDestination: some View {
        if store.isPremium {
            ExportView()
        } else {
            PaywallView()
        }
    }

    var body: some View {
        List {
            // ── Baby profile card ─────────────────────────────────────
            if let baby {
                Section {
                    Button {
                        showProfileEdit = true
                    } label: {
                        HStack(spacing: BBTheme.Spacing.md) {
                            BabyAvatarView(photoData: baby.photoData,
                                           gender: baby.gender,
                                           size: 56)
                                .overlay(Circle().stroke(BBTheme.Colors.primary.opacity(0.15), lineWidth: 1.5))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(baby.name)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                                Text(baby.ageDescription)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(BBTheme.Colors.primary.opacity(0.7))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("settings.profile".l)
                }
            }

            // ── Language ──────────────────────────────────────────────
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
                NavigationLink(destination: exportDestination) {
                    Label("settings.export".l, systemImage: "arrow.up.doc.fill")
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                Label("settings.icloud".l, systemImage: "icloud.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }

            Section("settings.app_section".l) {
                Label("settings.about".l, systemImage: "info.circle.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)

                NavigationLink(destination: PaywallView()) {
                    HStack {
                        Label("settings.premium".l, systemImage: "crown.fill")
                            .foregroundStyle(BBTheme.Colors.primary)
                        Spacer()
                        if store.isPremium {
                            Text("premium.active_badge".l)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(BBTheme.Colors.primary)
                                .cornerRadius(BBTheme.Radius.pill)
                        }
                    }
                }
            }
        }
        .navigationTitle("nav.settings".l)
        .task { await store.refreshEntitlements() }
        .sheet(isPresented: $showProfileEdit) {
            if let baby {
                BabyProfileEditSheet(baby: baby)
            }
        }
    }
}

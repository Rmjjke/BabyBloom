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

            DiaperView()
                .tabItem {
                    Label("tab.diapers".l, systemImage: "drop.fill")
                }
                .tag(Tab.diapers)

            MoreView()
                .tabItem {
                    Label("tab.more".l, systemImage: "ellipsis.circle.fill")
                }
                .tag(Tab.more)
        }
        .tint(BBTheme.Colors.primary)
        // Tab bar appearance is left to the system (D6): the default translucent
        // bar reads correctly in light/dark and is ready for Liquid Glass. No
        // UITabBarAppearance opaque override.
    }

    enum Tab: String, CaseIterable {
        case dashboard, feeding, sleep, diapers, more
    }
}

// MARK: - More Tab
struct MoreView: View {
    @Query(sort: \Baby.createdAt) private var babies: [Baby]

    private var baby: Baby? { babies.first }

    var body: some View {
        NavigationStack {
            List {
                // One destination for both the baby's details and the app
                // settings. The subtitle spells out what moved in here so the
                // settings do not become undiscoverable.
                NavigationLink(destination: ProfileView()) {
                    HStack(spacing: BBTheme.Spacing.sm) {
                        BabyAvatarView(photoData: baby?.photoData,
                                       gender: baby?.gender,
                                       size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(baby?.name ?? "nav.profile".l)
                                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Text("profile.settings_subtitle".l)
                                .font(BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                NavigationLink(destination: GrowthView()) {
                    Label {
                        Text("nav.growth".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(BBTheme.Colors.growth)
                    }
                }
                NavigationLink(destination: EventsView()) {
                    Label {
                        Text("nav.events".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(BBTheme.Colors.events)
                    }
                }
            }
            .navigationTitle("tab.more".l)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Profile View
// The baby's details and the app settings on one screen (they used to be two
// separate entries in the More tab).
struct ProfileView: View {
    @AppStorage("appLanguage") private var appLanguage = LocalizationManager.deviceDefault
    @Environment(SubscriptionManager.self) private var store
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @State private var showPaywall = false
    @State private var showProfileEdit = false

    private var baby: Baby? { babies.first }

    var body: some View {
        List {
            // ── Baby ──────────────────────────────────────────────────
            if let baby {
                Section {
                    Button {
                        showProfileEdit = true
                    } label: {
                        HStack(spacing: BBTheme.Spacing.md) {
                            BabyAvatarView(photoData: baby.photoData,
                                           gender: baby.gender,
                                           size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(baby.name)
                                    .font(BBTheme.Typography.scaled(20, relativeTo: .title3, weight: .semibold, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                                Text(baby.ageDescription)
                                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                                    .foregroundStyle(BBTheme.Colors.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            // ── Language ──────────────────────────────────────────────
            Section {
                HStack {
                    Label("settings.language".l, systemImage: "globe")
                    Spacer()
                    // Update the localization dictionary BEFORE @AppStorage
                    // triggers the view-tree rebuild — otherwise views rebuilt
                    // by .id(appLanguage) (incl. UIKit-cached tab bar items)
                    // read `.l` from the previous language's dictionary.
                    Picker("", selection: Binding(
                        get: { appLanguage },
                        set: { newValue in
                            LocalizationManager.shared.setLanguage(newValue)
                            appLanguage = newValue
                        }
                    )) {
                        Text("Рус").tag("ru")
                        Text("Eng").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            } header: {
                Text("settings.language".l)
            }

            Section("settings.notifications".l) {
                Label("settings.reminders".l, systemImage: "bell.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }

            Section("settings.data".l) {
                if store.isPremium {
                    NavigationLink(destination: ExportView()) {
                        Label("settings.export".l, systemImage: "arrow.up.doc.fill")
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("settings.export".l, systemImage: "arrow.up.doc.fill")
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    }
                }
                Label("settings.icloud".l, systemImage: "icloud.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }

            Section("settings.app_section".l) {
                Label("settings.about".l, systemImage: "info.circle.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)

                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Label("settings.premium".l, systemImage: "laurel.leading")
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
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
                    }
                }
            }
        }
        .navigationTitle("nav.profile".l)
        .task { await store.refreshEntitlements() }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showProfileEdit) {
            if let baby {
                BabyProfileEditSheet(baby: baby)
            }
        }
    }
}

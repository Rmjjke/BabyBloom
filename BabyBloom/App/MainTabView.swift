import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab: Tab = .dashboard
    /// Set by the app root's `onOpenURL`; taken and cleared here.
    @Binding var pendingDestination: DeepLink.Destination?
    @Query private var babies: [Baby]

    var body: some View {
        // The identifiers sit on each tab's CONTENT, not inside .tabItem —
        // SwiftUI drops an identifier set inside that closure. Only the
        // selected tab's content is in the accessibility tree, so e2e flows
        // use these to assert WHICH tab is open without depending on the
        // localized labels ("Feeding" also appears on the Dashboard).
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("tab.home".l, systemImage: "house.fill")
                }
                .accessibilityIdentifier("tab_home")
                .tag(Tab.dashboard)

            FeedingView()
                .tabItem {
                    Label("tab.feeding".l, systemImage: "heart.fill")
                }
                .accessibilityIdentifier("tab_feeding")
                .tag(Tab.feeding)

            SleepView()
                .tabItem {
                    Label("tab.sleep".l, systemImage: "moon.fill")
                }
                .accessibilityIdentifier("tab_sleep")
                .tag(Tab.sleep)

            DiaperView()
                .tabItem {
                    Label("tab.diapers".l, systemImage: "drop.fill")
                }
                .accessibilityIdentifier("tab_diapers")
                .tag(Tab.diapers)

            MoreView()
                .tabItem {
                    Label("tab.more".l, systemImage: "ellipsis.circle.fill")
                }
                .accessibilityIdentifier("tab_more")
                .tag(Tab.more)
        }
        .tint(BBTheme.Colors.primary)
        // Here and not at the app root: onboarding must never see a live
        // trigger, and everything that saves an entry lives under this view.
        .reviewPromptHost()
        // onAppear takes a link that came during the splash, onChange one
        // that comes while the tabs are already up.
        .onAppear(perform: openPendingDestination)
        .onChange(of: pendingDestination) { openPendingDestination() }
        // Tab bar appearance is left to the system (D6): the default translucent
        // bar reads correctly in light/dark and is ready for Liquid Glass. No
        // UITabBarAppearance opaque override.
    }

    private func openPendingDestination() {
        guard let destination = pendingDestination else { return }
        selectedTab = Tab(destination)
        pendingDestination = nil
    }

    enum Tab: String, CaseIterable {
        case dashboard, feeding, sleep, diapers, more

        init(_ destination: DeepLink.Destination) {
            switch destination {
            case .home: self = .dashboard
            case .feeding: self = .feeding
            case .sleep: self = .sleep
            case .diapers: self = .diapers
            }
        }
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
                NavigationLink(destination: RecentActivityView()) {
                    Label {
                        Text("nav.recent_activity".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(BBTheme.Colors.primary)
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
    @AppStorage("appAppearance") private var appAppearance = AppAppearance.system.rawValue
    /// Read-only here: the toggle writes through `Analytics.setEnabled`, which
    /// also tells the SDK. Same key, same default ON.
    @AppStorage(Analytics.enabledKey) private var analyticsEnabled = true
    /// The user's choice only. iOS can veto it (`systemEnabled`), and that veto
    /// is shown, never written into this key.
    @AppStorage(LiveActivitySettings.enabledKey) private var liveActivityEnabled = true
    /// D26: mutes the Monday notification only; the Dashboard card stays.
    @AppStorage(WeeklyNotificationPlan.enabledKey) private var weeklyNotificationEnabled = true
    @State private var liveActivity = LiveActivitySync.shared
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
            // A pushed list rather than a segmented control: the segments only
            // fit two languages, and the shipped set grows. The row reads
            // "Language  ›  Español" like the system Settings app; every option
            // is written in its own language (SupportedLanguage.endonym).
            Section {
                // Update the localization dictionary BEFORE @AppStorage
                // triggers the view-tree rebuild — otherwise views rebuilt
                // by .id(appLanguage) (incl. UIKit-cached tab bar items)
                // read `.l` from the previous language's dictionary.
                Picker(selection: Binding(
                    get: { appLanguage },
                    set: { newValue in
                        LocalizationManager.shared.setLanguage(newValue)
                        appLanguage = newValue
                    }
                )) {
                    ForEach(SupportedLanguage.allCases) { language in
                        Text(language.endonym).tag(language.rawValue)
                    }
                } label: {
                    Label("settings.language".l, systemImage: "globe")
                }
                .pickerStyle(.navigationLink)
            }

            // ── Appearance ────────────────────────────────────────────
            // Full-width segmented control: three localized labels do not fit
            // next to an inline row label.
            Section("settings.appearance".l) {
                Picker("settings.appearance".l, selection: $appAppearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Label(option.labelKey.l, systemImage: option.symbolName)
                            .tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("settings.notifications".l) {
                Label("settings.reminders".l, systemImage: "bell.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Toggle(isOn: Binding(
                    get: { weeklyNotificationEnabled },
                    set: { isOn in
                        weeklyNotificationEnabled = isOn
                        NotificationManager.shared.rescheduleWeeklySummary()
                    })) {
                    Label("settings.notify_weekly".l, systemImage: "calendar")
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                .tint(BBTheme.Colors.primary)
                .accessibilityIdentifier("settings.notify_weekly")
                // No Live Activities on iPad: no switch rather than a dead one.
                if UIDevice.current.userInterfaceIdiom != .pad {
                    Toggle(isOn: Binding(
                        get: { liveActivityEnabled && liveActivity.systemEnabled },
                        set: { isOn in
                            liveActivityEnabled = isOn
                            liveActivity.switchChanged()
                        })) {
                        // One Label around both lines: a Label nested in a
                        // VStack put its icon on a row of its own (live, iOS 26).
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.live_activity".l)
                                    .foregroundStyle(BBTheme.Colors.textPrimary)
                                Text(liveActivity.systemEnabled
                                     ? "settings.live_activity_hint".l
                                     : "settings.live_activity_off_in_ios".l)
                                    .font(.footnote)
                                    .foregroundStyle(BBTheme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "lock.rectangle.stack.fill")
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                        }
                    }
                    .disabled(!liveActivity.systemEnabled)
                    .accessibilityIdentifier("settings.live_activity")
                }
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
                Toggle(isOn: Binding(get: { analyticsEnabled },
                                     set: { Analytics.shared.setEnabled($0) })) {
                    Label("settings.analytics".l, systemImage: "chart.bar.xaxis")
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                .tint(BBTheme.Colors.primary)
            }

            Section("settings.app_section".l) {
                Label("settings.about".l, systemImage: "info.circle.fill")
                    .foregroundStyle(BBTheme.Colors.textPrimary)

                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        // A Label needs an SF Symbol, so BrandMark cannot serve
                        // here; crown carries the premium reading the retired
                        // wreath glyph used to.
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
            PaywallView(source: .settings)
        }
        .sheet(isPresented: $showProfileEdit) {
            if let baby {
                BabyProfileEditSheet(baby: baby)
            }
        }
    }
}

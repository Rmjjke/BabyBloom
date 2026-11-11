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
        .background(TabBarIdentifiers().frame(width: 0, height: 0))
        // Here and not at the app root: onboarding must never see a live
        // trigger, and everything that saves an entry lives under this view.
        .reviewPromptHost()
        // onAppear takes a link that came during the splash, onChange one
        // that comes while the tabs are already up.
        .onAppear(perform: openPendingDestination)
        .onChange(of: pendingDestination) { openPendingDestination() }
        // Tab bar appearance is left to the system: the default translucent
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
                    MoreProfileRowLabel(baby: baby)
                        .padding(.vertical, 4)
                }
                .accessibilityIdentifier("more.profile")
                NavigationLink(destination: GrowthView()) {
                    ListTitleRowLabel(title: "nav.growth".l,
                                      systemImage: "chart.line.uptrend.xyaxis",
                                      iconColor: BBTheme.Colors.growth)
                }
                .accessibilityIdentifier("more.growth")
                // Right after Growth: the report reads growth first.
                NavigationLink(destination: DoctorReportView()) {
                    ListTitleRowLabel(title: "report.title".l,
                                      systemImage: "stethoscope",
                                      iconColor: BBTheme.Colors.primary)
                }
                .accessibilityHint("report.a11y_hint".l)
                .accessibilityIdentifier("more.doctor_report")
                NavigationLink(destination: RecentActivityView()) {
                    ListTitleRowLabel(title: "nav.recent_activity".l,
                                      systemImage: "clock.arrow.circlepath",
                                      iconColor: BBTheme.Colors.primary)
                }
                .accessibilityIdentifier("more.recent_activity")
                NavigationLink(destination: EventsView()) {
                    ListTitleRowLabel(title: "nav.events".l,
                                      systemImage: "star.fill",
                                      iconColor: BBTheme.Colors.events)
                }
                .accessibilityIdentifier("more.events")
                NavigationLink(destination: MedicationsListView()) {
                    ListTitleRowLabel(title: "medication.title".l,
                                      systemImage: "pills.fill",
                                      iconColor: BBTheme.Colors.primary)
                }
                .accessibilityHint("medication.a11y_hint".l)
                .accessibilityIdentifier("more.medications")
            }
            .navigationTitle("tab.more".l)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// More's first row: the baby's avatar beside the name and the settings
/// subtitle while their widest word fits the column the avatar leaves, else
/// the avatar on a line of its own above them, where the texts take the row's
/// whole width; the system chevron stays trailing either way. Beside the
/// 44-pt avatar on a 320-pt screen at AX2 the column split «Алекса|ндра», and
/// in Bold Text «уведомления,» and «notificaciones,» as well. The List draws a
/// NavigationLink's chevron out of the label's reach (Settings' baby row draws
/// its own and lifts it to the avatar's line); stacked, the texts still keep
/// about 220 pt beside it there, more than any of their words take.
private struct MoreProfileRowLabel: View {
    let baby: Baby?

    var body: some View {
        let name = baby?.name ?? "nav.profile".l
        let subtitle = "profile.settings_subtitle".l
        ViewThatFits(in: .horizontal) {
            HStack(spacing: BBTheme.Spacing.sm) {
                avatar
                WidestWordIdeal {
                    // The same texts one word a line: their ideal width is the
                    // narrowest the drawn texts keep every word whole at.
                    texts(name: name.oneWordALine, subtitle: subtitle.oneWordALine)
                        .hidden()
                        .accessibilityHidden(true)
                    texts(name: name, subtitle: subtitle)
                }
            }
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                avatar
                texts(name: name, subtitle: subtitle)
            }
        }
    }

    private var avatar: some View {
        BabyAvatarView(photoData: baby?.photoData, gender: baby?.gender, size: 44)
    }

    private func texts(name: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(BBTheme.Typography.scaled(17, relativeTo: .body, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Text(subtitle)
                .font(BBTheme.Typography.scaled(13, relativeTo: .caption1, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
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
    /// Mutes the Monday notification only; the Dashboard card stays.
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
                        SettingsBabyRowLabel(baby: baby)
                            .padding(.vertical, 6)
                    }
                }
            }
            // ── Language ──────────────────────────────────────────────
            // A pushed list rather than a segmented control: the segments only
            // fit two languages, and the shipped set grows. The row reads
            // "Language  ›  Español" like the system Settings app; every option
            // is written in its own language (SupportedLanguage.endonym), the
            // current one on top. Only languages whose file ships are listed.
            Section {
                // Update the localization dictionary BEFORE @AppStorage
                // triggers the view-tree rebuild — otherwise views rebuilt
                // by .id(appLanguage) (incl. UIKit-cached tab bar items)
                // read `.l` from the previous language's dictionary.
                Picker(selection: Binding(
                    get: { LocalizationManager.effective(appLanguage).rawValue },
                    set: { newValue in
                        LocalizationManager.shared.setLanguage(newValue)
                        appLanguage = newValue
                    }
                )) {
                    ForEach(SupportedLanguage.pickerOrder(current: LocalizationManager.effective(appLanguage),
                                                          available: SupportedLanguage.available)) { language in
                        Text(language.endonym).tag(language.rawValue)
                            .accessibilityIdentifier("settings.language.\(language.rawValue)")
                    }
                } label: {
                    Label("settings.language".l, systemImage: "globe")
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("settings.language")
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
                .accessibilityIdentifier("settings.appearance")
            }

            Section("settings.notifications".l) {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("settings.reminders".l, systemImage: "bell.fill")
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                .accessibilityIdentifier("settings.reminders")
                SettingsSwitchRow(title: "settings.notify_weekly".l,
                                  hint: "settings.notify_weekly_hint".l,
                                  systemImage: "calendar",
                                  isOn: Binding(
                                      get: { weeklyNotificationEnabled },
                                      set: { isOn in
                                          weeklyNotificationEnabled = isOn
                                          NotificationManager.shared.rescheduleWeeklySummary()
                                      }))
                .tint(BBTheme.Colors.primary)
                .accessibilityIdentifier("settings.notify_weekly")
                // No Live Activities on iPad: no switch rather than a dead one.
                if UIDevice.current.userInterfaceIdiom != .pad {
                    SettingsSwitchRow(title: "settings.live_activity".l,
                                      hint: liveActivity.systemEnabled
                                          ? "settings.live_activity_hint".l
                                          : "settings.live_activity_off_in_ios".l,
                                      systemImage: "lock.rectangle.stack.fill",
                                      isOn: Binding(
                                          get: { liveActivityEnabled && liveActivity.systemEnabled },
                                          set: { isOn in
                                              liveActivityEnabled = isOn
                                              liveActivity.switchChanged()
                                          }))
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
                    // The gate visible before the tap: a free tap lands on the paywall.
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label("settings.export".l, systemImage: "arrow.up.doc.fill")
                                .foregroundStyle(BBTheme.Colors.textPrimary)
                            Spacer()
                            LockBadge()
                        }
                    }
                    .bbLockedAccessibility(true)
                    .accessibilityIdentifier("settings.export")
                }
                SettingsSwitchRow(title: "settings.analytics".l,
                                  hint: "settings.analytics_hint".l,
                                  systemImage: "chart.bar.xaxis",
                                  isOn: Binding(get: { analyticsEnabled },
                                                set: { Analytics.shared.setEnabled($0) }))
                .tint(BBTheme.Colors.primary)
            }

            Section("settings.app_section".l) {
                NavigationLink(destination: AboutView()) {
                    Label("settings.about".l, systemImage: "info.circle.fill")
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                }
                .accessibilityIdentifier("settings.about")

                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        // A Label needs an SF Symbol, so BrandMark cannot serve
                        // here; crown carries the premium reading the retired
                        // wreath glyph used to. At the accessibility sizes the
                        // badge goes under the title; the chevron stays trailing.
                        Label {
                            BBValueRow(underSpacing: 2) {
                                Text("settings.premium".l)
                            } value: {
                                if store.isPremium {
                                    Text("premium.active_badge".l)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(BBTheme.Colors.onPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(BBTheme.Colors.primary)
                                        .cornerRadius(BBTheme.Radius.pill)
                                }
                            }
                        } icon: {
                            Image(systemName: "crown.fill")
                        }
                        .foregroundStyle(BBTheme.Colors.primary)
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


// SwiftUI drops an identifier set inside .tabItem; UIKit copies the bar
// item's own identifier to the tab bar button, so set it there. Order matches
// the TabView above. Layout passes re-run it because the bar can be rebuilt
// (language change); it is idempotent.
private struct TabBarIdentifiers: UIViewControllerRepresentable {
    private static let ids = ["tabbar.home", "tabbar.feeding", "tabbar.sleep", "tabbar.diapers", "tabbar.more"]

    final class Probe: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            apply()
        }
        private static func tabBarController(in controller: UIViewController) -> UITabBarController? {
            if let tab = controller as? UITabBarController { return tab }
            for child in controller.children {
                if let found = tabBarController(in: child) { return found }
            }
            return controller.presentedViewController.flatMap { tabBarController(in: $0) }
        }

        private func apply() {
            guard let root = view.window?.rootViewController,
                  let items = Self.tabBarController(in: root)?.tabBar.items else { return }
            for (item, id) in zip(items, TabBarIdentifiers.ids) where item.accessibilityIdentifier != id {
                item.accessibilityIdentifier = id
            }
        }
    }

    func makeUIViewController(context: Context) -> Probe { Probe() }
    func updateUIViewController(_ controller: Probe, context: Context) {}
}

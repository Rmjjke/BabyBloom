import Foundation
import OSLog
import WidgetKit

/// The analytics facade: the only analytics type a view or a service touches.
/// Call sites hand it a typed `AnalyticsEvent`; which SDK (if any) receives the
/// payload is decided once, at first use, by `makeShared()`.
///
/// It is a no-op — no SDK constructed, nothing sent, nothing written — whenever
/// the API key is empty, on the simulator, or in a Debug build, which covers
/// every fresh clone and every test run. The parent's «Статистика
/// использования» setting (default on) is honoured at launch and on every change.
@MainActor
final class Analytics {

    static let shared = makeShared()

    nonisolated static let enabledKey = "analytics.enabled"
    nonisolated static let firstEntryKindsKey = "analytics.firstEntryKinds"
    nonisolated static let widgetReportedKey = "analytics.widgetInstalledReported"
    nonisolated static let widgetProbeDayKey = "analytics.widgetProbeDay"
    nonisolated static let dailyActivityDayKey = "analytics.dailyActivityDay"
    nonisolated static let pendingPurchasesKey = "analytics.pendingPurchasePlans"
    nonisolated static let historyLockDaysKey = "analytics.historyLockDays"

    /// Counts one local day's entries per kind; nil when there is no baby yet.
    typealias DayCounter = @MainActor (DateInterval) -> AnalyticsEvent.DayCounts?

    /// Internal so tests can assert which backend a build ended up with.
    let backend: AnalyticsBackend
    private let defaults: UserDefaults
    private let channel: AnalyticsEvent.BuildChannel
    private let calendar: Calendar
    private let clock: () -> Date
    private let widgetProbe: @MainActor () async -> Bool
    /// Set by `start`: the facade knows no model context of its own.
    private var countDay: DayCounter?
    /// Whether the backend has been told the stored opt-out yet.
    private var backendPrepared = false
    private static let log = Logger(subsystem: "com.nenita.app", category: "Analytics")

    init(backend: AnalyticsBackend,
         defaults: UserDefaults = .standard,
         channel: AnalyticsEvent.BuildChannel = .current,
         calendar: Calendar = .autoupdatingCurrent,
         clock: @escaping () -> Date = Date.init,
         widgetProbe: @escaping @MainActor () async -> Bool = Analytics.hasInstalledWidget) {
        self.backend = backend
        self.defaults = defaults
        self.channel = channel
        self.calendar = calendar
        self.clock = clock
        self.widgetProbe = widgetProbe
    }

    /// A build that can never send keeps no analytics state either, so the
    /// test host — which runs the real app — leaves `UserDefaults` untouched.
    private var isInert: Bool { backend is NoopAnalyticsBackend }

    // MARK: - Opt-out

    /// Default ON: absent means the parent has never turned it off.
    var isEnabled: Bool { defaults.object(forKey: Self.enabledKey) as? Bool ?? true }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey)
        backendPrepared = true
        backend.setOptedOut(!enabled)
    }

    /// Idempotent, and run before the first send whichever comes first: the
    /// app root's `start` and a child view's first event have no guaranteed
    /// order on the launch frame.
    private func prepareBackend() {
        guard !backendPrepared else { return }
        backendPrepared = true
        backend.setOptedOut(!isEnabled)
    }

    // MARK: - Launch

    func start(hasCompletedOnboarding: Bool, countDay: @escaping DayCounter) {
        guard !isInert else { return }
        self.countDay = countDay
        // Written on the first launch that has analytics. An install that was
        // already past onboarding has logged entries this code never saw, so
        // its next feed is not its first: every kind counts as already seen.
        if defaults.object(forKey: Self.firstEntryKindsKey) == nil {
            let seen = hasCompletedOnboarding ? AnalyticsEvent.EntryKind.allCases.map(\.rawValue) : []
            defaults.set(seen, forKey: Self.firstEntryKindsKey)
        }
        prepareBackend()
        // The foregrounding that should report yesterday can land before this
        // call on a cold launch; running the check here too closes that gap.
        reportPreviousDayIfDue()
    }

    // MARK: - Sending

    /// True only when the event actually reached a live backend. The
    /// once-only markers below are spent on that answer, so a backend retired
    /// by an opt-out earlier in this session — the setting back on, the SDK
    /// not until next launch — burns none of them.
    @discardableResult
    func track(_ event: AnalyticsEvent) -> Bool {
        guard isEnabled else { return false }
        prepareBackend()
        guard backend.canSend else { return false }
        backend.send(event.payload(channel: channel))
        return true
    }

    /// `first_entry`, the first time this install logs that kind — and nothing
    /// for any later entry, which `daily_activity` covers in aggregate.
    /// While the parent has opted OUT the kind is still marked seen, so
    /// turning analytics back on cannot report an old habit as a first; while
    /// the backend merely cannot send, it is not.
    func noteEntrySaved(_ kind: AnalyticsEvent.EntryKind) {
        guard !isInert else { return }
        var seen = Set(defaults.stringArray(forKey: Self.firstEntryKindsKey) ?? [])
        guard !seen.contains(kind.rawValue) else { return }
        if isEnabled, !track(.firstEntry(kind)) { return }
        seen.insert(kind.rawValue)
        defaults.set(seen.sorted(), forKey: Self.firstEntryKindsKey)
    }

    /// `history_lock_shown`, at most once per surface per local day — the
    /// footer appears on every visit to a capped list.
    func noteHistoryLockShown(_ surface: AnalyticsEvent.HistorySurface) {
        guard !isInert else { return }
        let today = calendar.startOfDay(for: clock())
        var days = defaults.dictionary(forKey: Self.historyLockDaysKey) as? [String: Date] ?? [:]
        guard days[surface.rawValue] != today, track(.historyLockShown(surface)) else { return }
        days[surface.rawValue] = today
        defaults.set(days, forKey: Self.historyLockDaysKey)
    }

    /// Every foregrounding: yesterday's aggregate if today has not sent it,
    /// and the widget check if it has not run today.
    func appBecameActive() async {
        guard !isInert else { return }
        reportPreviousDayIfDue()
        await checkWidgetIfDue()
    }

    // MARK: - Daily activity

    /// `daily_activity` for the PREVIOUS local day, once per day, at the first
    /// foregrounding of a new one — stamped at NOON of the day it reports and
    /// outside any session, so neither its time nor a session id gives away
    /// the first open after midnight, which is often the first night feed.
    ///
    /// The day marker moves when the report goes out; when there is nothing to
    /// report (no baby); and when the parent has opted out — an opted-out day
    /// is never back-filled after an opt-in. It does NOT move while the
    /// backend merely cannot send. The first launch only sets it: there is no
    /// earlier day to speak for. A marker in the FUTURE (the clock moved back,
    /// or `-BBAnalyticsDayOffset`) is pulled back to today without sending.
    private func reportPreviousDayIfDue() {
        guard let countDay else { return }
        let today = calendar.startOfDay(for: clock())
        let stored = defaults.object(forKey: Self.dailyActivityDayKey) as? Date
        guard let lastDay = stored, lastDay < today else {
            // First launch, already handled today, or a marker in the future.
            if stored != today { defaults.set(today, forKey: Self.dailyActivityDayKey) }
            return
        }
        guard isEnabled,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let counts = countDay(DateInterval(start: yesterday, end: today)) else {
            defaults.set(today, forKey: Self.dailyActivityDayKey)
            return
        }
        // Noon by the calendar, not start + 12 h: a DST day is 23 or 25 hours.
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday) ?? yesterday
        if track(.dailyActivity(AnalyticsEvent.DailyActivity(counts, reportedAt: noon))) {
            defaults.set(today, forKey: Self.dailyActivityDayKey)
        }
    }

    // MARK: - Widget

    /// `widget_installed`, once per install. WidgetKit is asked at most once a
    /// local day; skipped while opted out, so a later opt-in still reports a
    /// widget added in the meantime.
    private func checkWidgetIfDue() async {
        guard isEnabled, !defaults.bool(forKey: Self.widgetReportedKey) else { return }
        prepareBackend()
        guard backend.canSend else { return }
        let today = calendar.startOfDay(for: clock())
        if let lastProbe = defaults.object(forKey: Self.widgetProbeDayKey) as? Date, lastProbe >= today {
            // A probe day in the future is pulled back to today, unprobed.
            if lastProbe > today { defaults.set(today, forKey: Self.widgetProbeDayKey) }
            return
        }
        defaults.set(today, forKey: Self.widgetProbeDayKey)
        guard await widgetProbe() else { return }
        // Re-read after the await: the setting may have moved while WidgetKit
        // answered.
        guard !defaults.bool(forKey: Self.widgetReportedKey), track(.widgetInstalled) else { return }
        defaults.set(true, forKey: Self.widgetReportedKey)
    }

    /// The completion-handler form: the async `currentConfigurations()` is
    /// iOS 18+, and this app supports 17.
    static func hasInstalledWidget() async -> Bool {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                continuation.resume(returning: !((try? result.get()) ?? []).isEmpty)
            }
        }
    }

    // MARK: - Ask to Buy

    /// A `.pending` purchase (Ask to Buy, SCA) that is approved later never
    /// comes back through `Product.purchase()` — only through
    /// `Transaction.updates`, possibly in another launch. Remembered here so
    /// that approval can still report `purchase_result(success)`.
    /// Remembered with WHEN it went pending, so a later transaction can be
    /// told apart from an old one.
    func notePendingPurchase(_ plan: AnalyticsEvent.Plan) {
        guard !isInert else { return }
        var pending = defaults.dictionary(forKey: Self.pendingPurchasesKey) as? [String: Date] ?? [:]
        pending[plan.rawValue] = clock()
        defaults.set(pending, forKey: Self.pendingPurchasesKey)
    }

    /// A new purchase attempt or a restore supersedes an old pending one: a
    /// declined Ask to Buy leaves no transaction, and its marker must not
    /// claim the next one.
    func clearPendingPurchases() {
        guard !isInert else { return }
        defaults.removeObject(forKey: Self.pendingPurchasesKey)
    }

    /// Once per pending plan, and only for the parent's OWN purchase made
    /// after the plan went pending — not a family-shared entitlement, not an
    /// older transaction redelivered. The marker is spent only when the report
    /// actually goes out; a transaction `Transaction.updates` redelivers after
    /// that finds nothing.
    func resolvePendingPurchase(productID: String, purchaseDate: Date, isOwnPurchase: Bool) {
        guard !isInert, isOwnPurchase, let plan = AnalyticsEvent.Plan(productID: productID) else { return }
        var pending = defaults.dictionary(forKey: Self.pendingPurchasesKey) as? [String: Date] ?? [:]
        guard let notedAt = pending[plan.rawValue], purchaseDate >= notedAt,
              track(.purchaseResult(plan, .success)) else { return }
        pending[plan.rawValue] = nil
        defaults.set(pending, forKey: Self.pendingPurchasesKey)
    }
}

// MARK: - Choosing the backend

extension Analytics {

    enum Decision: Equatable {
        case noop(NoopReason)
        case amplitude
        case spy
    }

    enum NoopReason: String {
        case noAPIKey   = "no API key"
        case simulator  = "simulator"
        case debugBuild = "Debug build"
    }

    /// Pure, so the no-op rules are unit-tested rather than trusted. The key is
    /// passed as a Bool on purpose: nothing here can log it.
    ///
    /// The spy still needs a key, so an evidence run also proves the key
    /// travels from the xcconfig into Info.plist.
    nonisolated static func decide(hasAPIKey: Bool, isSimulator: Bool,
                                   isDebug: Bool, spyRequested: Bool) -> Decision {
        guard hasAPIKey else { return .noop(.noAPIKey) }
        if isSimulator { return spyRequested ? .spy : .noop(.simulator) }
        if isDebug { return .noop(.debugBuild) }
        return .amplitude
    }

    private static func makeShared() -> Analytics {
        // Injected as $(AMPLITUDE_API_KEY) from Config/App.xcconfig, which
        // optionally includes the gitignored Config/Secrets.xcconfig.
        let apiKey = (Bundle.main.object(forInfoDictionaryKey: "AmplitudeAPIKey") as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let decision = decide(hasAPIKey: !apiKey.isEmpty, isSimulator: isSimulatorBuild,
                              isDebug: isDebugBuild, spyRequested: spyRequested)
        let backend: AnalyticsBackend
        switch decision {
        case .amplitude:
            backend = AmplitudeAnalyticsBackend(apiKey: apiKey)
        case .spy:
            #if targetEnvironment(simulator)
            backend = localSDKRequested
                ? AmplitudeAnalyticsBackend(apiKey: apiKey, serverURL: "http://127.0.0.1:9/2/httpapi")
                : LoggingAnalyticsBackend()
            #else
            backend = NoopAnalyticsBackend() // unreachable: `decide` gates `.spy` on the simulator
            #endif
        case .noop(let reason):
            log.debug("Analytics is a no-op: \(reason.rawValue, privacy: .public).")
            backend = NoopAnalyticsBackend()
        }
        let offset = dayOffset
        return Analytics(backend: backend, clock: { Date().addingTimeInterval(offset * 86_400) })
    }

    private static var isSimulatorBuild: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// `-BBAnalyticsSpy true` or `-BBAnalyticsLocalSDK true`: simulator-only,
    /// like the other test hooks.
    private static var spyRequested: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: "BBAnalyticsSpy") || localSDKRequested
        #else
        return false
        #endif
    }

    /// `-BBAnalyticsLocalSDK true`: the REAL Amplitude backend, uploading to a
    /// dead local port, so the SDK's own queue on disk shows what it would send
    /// — device id, event id, session id, time — while no event leaves the
    /// simulator. (Constructing the SDK still fetches Amplitude's remote config
    /// with whatever key the build carries: use a dummy one.)
    private static var localSDKRequested: Bool {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.bool(forKey: "BBAnalyticsLocalSDK")
        #else
        return false
        #endif
    }

    /// `-BBAnalyticsDayOffset N`: simulator-only. Moves the facade's clock N
    /// days ahead so a walk can cross midnight on demand and show
    /// `daily_activity`; nothing else in the app sees the shifted clock.
    private static var dayOffset: Double {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.double(forKey: "BBAnalyticsDayOffset")
        #else
        return 0
        #endif
    }
}

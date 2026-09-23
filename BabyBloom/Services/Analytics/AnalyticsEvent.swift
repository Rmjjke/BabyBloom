import Foundation

// MARK: - Values

/// A string property value meant to come only from one of the app's own
/// String enums, whose raw values are literals fixed at compile time — so a
/// token cannot carry what a parent typed. The protocol cannot enforce "enum"
/// (a struct could conform); what pins every token value that actually goes
/// out is the allow-list in `AnalyticsEventTests`.
protocol AnalyticsToken: RawRepresentable, CaseIterable, Sendable where RawValue == String {}

/// What an analytics property may hold: a Bool, an Int, or a token.
///
/// There is deliberately no way to build one from an arbitrary `String` — the
/// initializer is private and the three factories below are the only doors.
/// That is what keeps a baby's name or a note out of a payload without every
/// call site remembering to. It is not the whole guarantee: `.int` takes any
/// Int, so which numbers are sent is decided by the closed `AnalyticsEvent`
/// enum and pinned by the allow-list test (only `seconds_visible` is an Int).
struct AnalyticsValue: Equatable, Sendable {
    enum Storage: Equatable, Sendable {
        case bool(Bool)
        case int(Int)
        case token(String)
    }

    let storage: Storage

    private init(_ storage: Storage) { self.storage = storage }

    static func bool(_ value: Bool) -> AnalyticsValue { AnalyticsValue(.bool(value)) }
    static func int(_ value: Int) -> AnalyticsValue { AnalyticsValue(.int(value)) }
    static func token<T: AnalyticsToken>(_ value: T) -> AnalyticsValue { AnalyticsValue(.token(value.rawValue)) }

    /// The plain value a backend SDK takes.
    var bridged: Any {
        switch storage {
        case .bool(let value):  return value
        case .int(let value):   return value
        case .token(let value): return value
        }
    }
}

/// One event as a backend receives it. Built only by `AnalyticsEvent.payload`
/// (the initializer is fileprivate), so a backend can forward nothing that did
/// not start life as a typed case below.
struct AnalyticsPayload: Equatable, Sendable {
    let name: String
    let properties: [String: AnalyticsValue]
    /// The event's own time when it must not be "now" — `daily_activity` is
    /// stamped at noon of the day it reports, never at the moment of sending.
    let timestamp: Date?
    /// Sent outside any session, so no session id carries a time either.
    let outsideSession: Bool

    fileprivate init(name: String, properties: [String: AnalyticsValue],
                     timestamp: Date? = nil, outsideSession: Bool = false) {
        self.name = name
        self.properties = properties
        self.timestamp = timestamp
        self.outsideSession = outsideSession
    }
}

// MARK: - Events

/// Every analytics event the app can send, and nothing else.
///
/// The vocabulary is behaviour only — which page, which plan, how it ended,
/// whether a day was used at all. Deliberately NOT one event per logged entry:
/// an event stamped with its own time under a persistent id would let the
/// backend rebuild a baby's care timeline (DECISIONS 2026-09-23). Adding a
/// case forces a name and a property mapping in the two switches below, and
/// `AnalyticsEventTests` holds an independent copy of the allow-list that has
/// to be edited on purpose.
enum AnalyticsEvent: Equatable, Sendable {
    case onboardingPageViewed(OnboardingPage)
    case onboardingCompleted(birthMeasurementsKnown: Bool)
    case paywallShown(PaywallSource)
    case planSelected(Plan)
    case purchaseResult(Plan, PurchaseOutcome)
    case restoreResult(RestoreOutcome)
    case paywallClosedX(secondsVisible: Int)
    case firstEntry(EntryKind)
    case dailyActivity(DailyActivity)
    case notificationPermission(granted: Bool)
    case widgetInstalled
    case historyLockShown(HistorySurface)
    case reviewPromptRequested

    /// Seconds since `shownAt`, never negative (a clock change must not send
    /// nonsense).
    static func paywallClosedX(since shownAt: Date, now: Date = Date()) -> AnalyticsEvent {
        .paywallClosedX(secondsVisible: max(0, Int(now.timeIntervalSince(shownAt))))
    }

    enum Name: String, CaseIterable, Sendable {
        case onboardingPageViewed   = "onboarding_page_viewed"
        case onboardingCompleted    = "onboarding_completed"
        case paywallShown           = "paywall_shown"
        case planSelected           = "plan_selected"
        case purchaseResult         = "purchase_result"
        case restoreResult          = "restore_result"
        case paywallClosedX         = "paywall_closed_x"
        case firstEntry             = "first_entry"
        case dailyActivity          = "daily_activity"
        case notificationPermission = "notification_permission"
        case widgetInstalled        = "widget_installed"
        case historyLockShown       = "history_lock_shown"
        case reviewPromptRequested  = "review_prompt_requested"
    }

    enum Key: String, CaseIterable, Sendable {
        case page
        case birthMeasurementsKnown = "birth_measurements_known"
        case source
        case plan
        case result
        case secondsVisible = "seconds_visible"
        case kind
        case granted
        case surface
        // `daily_activity`: whether each kind was logged at all, and one
        // bucketed total across kinds.
        case feeding, sleep, diaper, growth, event, total
        /// Added by the facade to every event, never by a case.
        case buildChannel = "build_channel"
    }

    var name: Name {
        switch self {
        case .onboardingPageViewed:   return .onboardingPageViewed
        case .onboardingCompleted:    return .onboardingCompleted
        case .paywallShown:           return .paywallShown
        case .planSelected:           return .planSelected
        case .purchaseResult:         return .purchaseResult
        case .restoreResult:          return .restoreResult
        case .paywallClosedX:         return .paywallClosedX
        case .firstEntry:             return .firstEntry
        case .dailyActivity:          return .dailyActivity
        case .notificationPermission: return .notificationPermission
        case .widgetInstalled:        return .widgetInstalled
        case .historyLockShown:       return .historyLockShown
        case .reviewPromptRequested:  return .reviewPromptRequested
        }
    }

    var properties: [Key: AnalyticsValue] {
        switch self {
        case .onboardingPageViewed(let page):
            return [.page: .token(page)]
        case .onboardingCompleted(let known):
            return [.birthMeasurementsKnown: .bool(known)]
        case .paywallShown(let source):
            return [.source: .token(source)]
        case .planSelected(let plan):
            return [.plan: .token(plan)]
        case .purchaseResult(let plan, let outcome):
            return [.plan: .token(plan), .result: .token(outcome)]
        case .restoreResult(let outcome):
            return [.result: .token(outcome)]
        case .paywallClosedX(let seconds):
            return [.secondsVisible: .int(seconds)]
        case .firstEntry(let kind):
            return [.kind: .token(kind)]
        case .dailyActivity(let day):
            return [.feeding: .bool(day.feeding), .sleep: .bool(day.sleep),
                    .diaper: .bool(day.diaper), .growth: .bool(day.growth),
                    .event: .bool(day.event), .total: .token(day.total)]
        case .notificationPermission(let granted):
            return [.granted: .bool(granted)]
        case .historyLockShown(let surface):
            return [.surface: .token(surface)]
        case .widgetInstalled, .reviewPromptRequested:
            return [:]
        }
    }

    /// The one place a payload is made: the case's own properties plus the
    /// build channel, which every event carries so TestFlight traffic can be
    /// filtered out of App Store numbers.
    func payload(channel: BuildChannel) -> AnalyticsPayload {
        var properties = Dictionary(uniqueKeysWithValues: properties.map { ($0.key.rawValue, $0.value) })
        properties[Key.buildChannel.rawValue] = .token(channel)
        if case .dailyActivity(let day) = self {
            return AnalyticsPayload(name: name.rawValue, properties: properties,
                                    timestamp: day.reportedAt, outsideSession: true)
        }
        return AnalyticsPayload(name: name.rawValue, properties: properties)
    }
}

// MARK: - Tokens

extension AnalyticsEvent {

    /// Stable ids for the onboarding pages, decoupled from `OnboardingStep` so
    /// renaming a case in code does not split a funnel in the dashboard.
    enum OnboardingPage: String, AnalyticsToken {
        case welcome, name, birth, feeding, growth, fact
        case growthShowcase = "growth_showcase"
        case notifications, widgets, generating, premium

        /// Exhaustive on purpose: a new onboarding page does not compile until
        /// it has an analytics id.
        init(_ step: OnboardingStep) {
            switch step {
            case .welcome:        self = .welcome
            case .name:           self = .name
            case .birth:          self = .birth
            case .feeding:        self = .feeding
            case .growth:         self = .growth
            case .fact:           self = .fact
            case .growthShowcase: self = .growthShowcase
            case .notifications:  self = .notifications
            case .widgets:        self = .widgets
            case .generating:     self = .generating
            case .premium:        self = .premium
            }
        }
    }

    /// Where a paywall was opened from. Every presentation site names one, so a
    /// conversion can be traced to the surface that sold it.
    enum PaywallSource: String, AnalyticsToken, Identifiable {
        case onboarding
        case settings
        case historyLock = "history_lock"
        case lockedCard  = "locked_card"
        case events

        var id: String { rawValue }
    }

    enum Plan: String, AnalyticsToken {
        case weekly, monthly, yearly

        init?(productID: String) {
            switch productID {
            case SubscriptionManager.weeklyID:  self = .weekly
            case SubscriptionManager.monthlyID: self = .monthly
            case SubscriptionManager.yearlyID:  self = .yearly
            default: return nil
            }
        }
    }

    /// `alreadySubscribed` is StoreKit's `.userCancelled` for an Apple ID that
    /// already owns a plan ("You are currently subscribed") — not a parent who
    /// backed out.
    enum PurchaseOutcome: String, AnalyticsToken {
        case success, cancelled, failed, pending
        case alreadySubscribed = "already_subscribed"
    }

    /// `cancelled` is a fourth outcome beside found / not found / failed: a
    /// parent backing out of the Apple Account sheet did not have a restore
    /// fail, and counting it as one would overstate StoreKit errors.
    enum RestoreOutcome: String, AnalyticsToken {
        case found
        case notFound = "not_found"
        case failed
        case cancelled
    }

    enum EntryKind: String, AnalyticsToken {
        case feeding, sleep, diaper, growth, event
    }

    /// One local day's raw counts, as the store reports them. Never sent:
    /// `DailyActivity` reduces it before anything leaves the facade.
    struct DayCounts: Equatable, Sendable {
        var feeding = 0, sleep = 0, diaper = 0, growth = 0, event = 0
        var total: Int { feeding + sleep + diaper + growth + event }
    }

    /// All entries of a day, coarsened on purpose. The edges avoid the
    /// clinical ones: the old per-kind 4-7 | 8+ feeding edge sat exactly on
    /// the 8-12 feeds a day guideline.
    enum TotalBucket: String, AnalyticsToken {
        case zero         = "0"
        case oneToFive    = "1-5"
        case sixToFifteen = "6-15"
        case sixteenPlus  = "16+"

        init(count: Int) {
            switch count {
            case ..<1:   self = .zero
            case 1...5:  self = .oneToFive
            case 6...15: self = .sixToFifteen
            default:     self = .sixteenPlus
            }
        }
    }

    /// What `daily_activity` says about a day: whether each kind was logged
    /// at all, and one bucketed total — no per-kind count. `reportedAt` is
    /// noon of that day and travels as the event's time, not as a property.
    struct DailyActivity: Equatable, Sendable {
        var feeding: Bool, sleep: Bool, diaper: Bool, growth: Bool, event: Bool
        var total: TotalBucket
        var reportedAt: Date

        init(_ counts: DayCounts, reportedAt: Date) {
            feeding = counts.feeding > 0
            sleep = counts.sleep > 0
            diaper = counts.diaper > 0
            growth = counts.growth > 0
            event = counts.event > 0
            total = TotalBucket(count: counts.total)
            self.reportedAt = reportedAt
        }
    }

    /// The five list surfaces that render `BBLockedHistoryFooter`.
    enum HistorySurface: String, AnalyticsToken {
        case feeding, sleep, diaper, events
        case recentActivity = "recent_activity"
    }

    /// Where the running binary came from, so only real App Store traffic
    /// reads as `appstore`. The same checks, in the same order, as
    /// AmplitudeCore's own `AppEnvironment`: synchronous and StoreKit-free,
    /// which `AppTransaction` (async, may reach the network) is not.
    enum BuildChannel: String, AnalyticsToken {
        case appstore, testflight, development, simulator

        static var current: BuildChannel {
            #if targetEnvironment(simulator)
            let isSimulator = true
            #else
            let isSimulator = false
            #endif
            return detect(isSimulator: isSimulator,
                          hasEmbeddedProfile: Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil,
                          receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent)
        }

        /// Development, ad-hoc and enterprise builds — a Release build run
        /// from Xcode or handed to QA included — embed a provisioning profile;
        /// App Store and TestFlight installs do not. Of those two, TestFlight's
        /// receipt is the sandbox one.
        static func detect(isSimulator: Bool, hasEmbeddedProfile: Bool, receiptName: String?) -> BuildChannel {
            if isSimulator { return .simulator }
            if hasEmbeddedProfile { return .development }
            return receiptName == "sandboxReceipt" ? .testflight : .appstore
        }
    }
}

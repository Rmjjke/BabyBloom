import Foundation
import AmplitudeSwift

/// The Amplitude backend — the ONLY file in the app that imports the SDK.
///
/// Every option below was read from the SDK source (Amplitude-Swift 1.19.0,
/// AmplitudeCore 1.5.2), not from memory; re-read them on any version bump.
@MainActor
final class AmplitudeAnalyticsBackend: AnalyticsBackend {

    nonisolated static let wipePendingKey = "analytics.amplitudeWipePending"

    private let apiKey: String
    private let defaults: UserDefaults
    /// nil in every shipped build. Only the simulator's `-BBAnalyticsLocalSDK`
    /// hook sets it, to a dead local address, so the real SDK can be watched
    /// queueing events it can never upload.
    private let serverURL: String?
    /// Built lazily, and never for a parent who has opted out: constructing the
    /// SDK's `Configuration` alone fires a remote-config request, so "off"
    /// means the SDK is not even created until the parent turns it back on.
    private var amplitude: Amplitude?
    /// Set once an opt-out has wiped this instance. The live SDK still holds a
    /// session id and an event counter in memory that no public API resets, so
    /// a re-opt-in in the same process could let the two periods be joined:
    /// the instance stays opted out, and a fresh one is built next launch.
    private var retired = false

    init(apiKey: String, defaults: UserDefaults = .standard, serverURL: String? = nil) {
        self.apiKey = apiKey
        self.defaults = defaults
        self.serverURL = serverURL
    }

    /// For tests: an opted-out launch must leave this false.
    var hasConstructedSDK: Bool { amplitude != nil }

    var canSend: Bool {
        guard let amplitude, !retired else { return false }
        return !amplitude.optOut
    }

    func setOptedOut(_ optedOut: Bool) {
        if optedOut {
            guard let amplitude, !retired else { return }
            // The retired instance lives on until the process exits, and its
            // session bookkeeping — which runs on every foregrounding even
            // with session events off — writes the old event counter, session
            // id and last-event time back into the storage cleared below. So
            // the wipe is ALSO owed to the next SDK: persisted first, then
            // done again in `make()` before that SDK reads a byte.
            defaults.set(true, forKey: Self.wipePendingKey)
            // `optOut` first, so nothing new is queued; then the queue and
            // every stored id go, and `reset()` mints a new random device id.
            amplitude.optOut = true
            amplitude.configuration.storageProvider.reset()
            amplitude.configuration.identifyStorageProvider.reset()
            amplitude.reset()
            retired = true
        } else if amplitude == nil {
            amplitude = make()
        }
        // Back on after an opt-out in this process: nothing until next launch.
    }

    func send(_ payload: AnalyticsPayload) {
        guard canSend, let amplitude else { return }
        var options: EventOptions?
        if payload.timestamp != nil || payload.outsideSession {
            // sessionId -1 is the SDK's "no session": it skips session
            // bookkeeping for this event and sends no session id.
            options = EventOptions(timestamp: payload.timestamp.map { Int64($0.timeIntervalSince1970 * 1_000) },
                                   sessionId: payload.outsideSession ? -1 : nil)
        }
        amplitude.track(eventType: payload.name,
                        eventProperties: payload.properties.mapValues(\.bridged),
                        options: options)
    }

    private func make() -> Amplitude {
        let tracking = TrackingOptions()
            // Without this the SDK asks the server to geolocate the request's
            // IP ("$remote"). The city/DMA/region calls after it name those
            // server-side fields for intent; this SDK version never reads them.
            .disableTrackIpAddress()
            .disableTrackCity()
            .disableTrackDMA()
            .disableTrackRegion()
            // With no "$remote", the SDK fills `country` itself from the
            // locale's region code; that goes too. `language` stays.
            .disableTrackCountry()
            .disableTrackCarrier()
            // The device id becomes a random per-install UUID instead of the
            // IDFV, which is shared by every app from the same developer
            // account and would let this app's events be joined with the
            // owner's other Amplitude project.
            .disableTrackIDFV()

        let configuration = Configuration(
            apiKey: apiKey,
            serverZone: .US,
            serverUrl: serverURL,
            trackingOptions: tracking,
            // The only public switch for the SDK's internal IDFA field. The
            // SDK never reads the IDFA or an ADID itself (no AdSupport code);
            // this keeps it that way if one is ever passed in by mistake.
            enableCoppaControl: true,
            // Uploads what is queued when the app goes to the background.
            flushEventsOnClose: true,
            // Nothing automatic. Session start/end would be the one intraday
            // timeline left — in a newborn tracker, app opens track night
            // feeds — and `daily_activity` already marks active days for DAU
            // and retention. Screen views, element interactions (which read
            // on-screen text, names included), app lifecycles and network
            // tracking stay off too; this SDK has no deep-link autocapture.
            autocapture: [],
            // No legacy Amplitude-iOS store ever existed in this app.
            migrateLegacyData: false,
            // Without this, Amplitude's dashboard could switch any of the
            // above on remotely, bypassing the line above.
            enableAutoCaptureRemoteConfig: false,
            // SDK self-telemetry. Note AmplitudeCore still subscribes to a
            // remote "diagnostics" key that can re-enable it server-side; see
            // ARCHITECTURE.md › Analytics.
            enableDiagnostics: false
        )
        // The wipe owed by an opt-out: BEFORE the SDK is constructed, so it
        // starts with no device id, no event counter and no session.
        if defaults.bool(forKey: Self.wipePendingKey) {
            configuration.storageProvider.reset()
            configuration.identifyStorageProvider.reset()
            defaults.removeObject(forKey: Self.wipePendingKey)
        }
        return Amplitude(configuration: configuration)
    }
}

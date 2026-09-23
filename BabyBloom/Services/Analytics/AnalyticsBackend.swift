import Foundation

/// Where analytics payloads go. One file per backend: moving off Amplitude
/// means writing one new conformer and changing one line in
/// `Analytics.makeShared()` — no call site knows which backend is behind the
/// facade.
@MainActor
protocol AnalyticsBackend: AnyObject {
    /// Called at launch with the stored choice, and again whenever the parent
    /// flips the setting. `true` stops new events and discards what is queued
    /// and the ids behind it; an upload already in flight cannot be recalled.
    func setOptedOut(_ optedOut: Bool)
    func send(_ payload: AnalyticsPayload)
    /// Whether a payload handed over now would actually go out. False for a
    /// backend retired by an opt-out this session, even after the setting is
    /// turned back on — the facade then spends no once-only marker.
    var canSend: Bool { get }
}

/// The backend of every build that must not send: no API key, the simulator,
/// a Debug build — and therefore every test run.
final class NoopAnalyticsBackend: AnalyticsBackend {
    func setOptedOut(_ optedOut: Bool) {}
    func send(_ payload: AnalyticsPayload) {}
    var canSend: Bool { false }
}

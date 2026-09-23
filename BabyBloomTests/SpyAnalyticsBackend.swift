import Foundation
@testable import BabyBloom

/// Records what a facade would have sent. Shared by every test that needs an
/// isolated `Analytics` instead of the app's own.
@MainActor
final class SpyAnalyticsBackend: AnalyticsBackend {
    private(set) var sent: [AnalyticsPayload] = []
    private(set) var optOutCalls: [Bool] = []
    /// False plays a backend retired by an opt-out earlier in the session.
    var canSend = true
    func setOptedOut(_ optedOut: Bool) { optOutCalls.append(optedOut) }
    func send(_ payload: AnalyticsPayload) { sent.append(payload) }
    var names: [String] { sent.map(\.name) }
}

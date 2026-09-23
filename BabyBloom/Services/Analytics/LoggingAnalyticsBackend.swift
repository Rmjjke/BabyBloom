#if targetEnvironment(simulator)
import Foundation
import OSLog

/// Simulator-only spy behind `-BBAnalyticsSpy true`: writes each payload to
/// the unified log instead of sending it, so a scripted walk can prove which
/// events a flow emits without any network. Compiled out of every device
/// build, like the other test hooks (DECISIONS 2026-08-26).
///
/// Payload values are logged `.public` on purpose — they are typed tokens,
/// Bools and Ints by construction, which is exactly what the log proves.
final class LoggingAnalyticsBackend: AnalyticsBackend {

    private static let log = Logger(subsystem: "com.nenita.app", category: "Analytics")

    var canSend: Bool { true }

    func setOptedOut(_ optedOut: Bool) {
        Self.log.notice("Analytics spy: optedOut=\(optedOut, privacy: .public)")
    }

    func send(_ payload: AnalyticsPayload) {
        var fields = payload.properties
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(String(describing: $0.value.bridged))" }
        if let timestamp = payload.timestamp {
            fields.append("time=\(Date.ISO8601FormatStyle(timeZone: .current).format(timestamp))")
        }
        if payload.outsideSession { fields.append("session=none") }
        let line = fields.joined(separator: " ")
        Self.log.notice("Analytics spy event: \(payload.name, privacy: .public) \(line, privacy: .public)")
    }
}
#endif

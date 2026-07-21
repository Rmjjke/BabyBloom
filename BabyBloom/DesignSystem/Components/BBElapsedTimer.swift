import SwiftUI

/// Live-updating elapsed-time label. Owns the per-second `Timer.publish`
/// and formatting shared by the feeding, sleep and dashboard timer cards.
struct BBElapsedTimer: View {
    let startTime: Date
    var font: Font = .system(size: 36, weight: .semibold, design: .rounded).monospacedDigit()
    var color: Color
    /// When `true`, values of an hour or more render as `HH:MM:SS` (sleep cards).
    var showsHours: Bool = false

    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatted)
            .font(font)
            .foregroundStyle(color)
            .onReceive(timer) { _ in elapsed = Date().timeIntervalSince(startTime) }
            .onAppear { elapsed = Date().timeIntervalSince(startTime) }
    }

    private var formatted: String {
        let total = Int(elapsed)
        let hours = total / 3600
        if showsHours && hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, total % 3600 / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

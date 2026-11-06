import SwiftUI

/// Live-updating elapsed-time label (Home's running-timer card). Its face and
/// formatting are shared with the Feeding and Sleep cards' `BBTimerCardHeader`,
/// which keeps its own clock.
struct BBElapsedTimer: View {
    let startTime: Date
    var font: Font = BBElapsedTimer.defaultFont
    var color: Color
    /// When `true`, values of an hour or more render as `HH:MM:SS` (sleep cards).
    var showsHours: Bool = false

    @State private var elapsed: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    static var defaultFont: Font {
        BBTheme.Typography.scaled(36, relativeTo: .largeTitle, weight: .semibold, design: .rounded).monospacedDigit()
    }

    var body: some View {
        Self.face(Self.formatted(elapsed, showsHours: showsHours), font: font, color: color)
            .onReceive(timer) { _ in elapsed = Date().timeIntervalSince(startTime) }
            .onAppear { elapsed = Date().timeIntervalSince(startTime) }
    }

    /// The digits as every timer card draws them.
    static func face(_ text: String, font: Font = defaultFont, color: Color) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    static func formatted(_ elapsed: TimeInterval, showsHours: Bool) -> String {
        let total = Int(elapsed)
        let hours = total / 3600
        if showsHours && hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, total % 3600 / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// A timer card's top: what is running (a small coloured label over the
/// title) beside the elapsed time while the two fit one line, else above it.
/// The timer's width follows the elapsed time as well as the text size (hours
/// on a sleep past an hour, three-digit minutes on a feed past 100), so the
/// fit picks the shape, not the size: beside wide digits the title's column
/// broke «Дневной» on a 320-pt screen and «Сцеженное» at AX2. Always stacked
/// at accessibility sizes, whatever the width, as the Feeding card was: the
/// fit would set a short title beside its timer and a long one above it, and
/// at the largest text the running cards keep one shape.
struct BBTimerCardHeader: View {
    let label: String
    let title: String
    let color: Color
    let startTime: Date
    var showsHours: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // One clock for both shapes: each fit check reads the digits on screen.
        TimelineView(.periodic(from: startTime, by: 1)) { context in
            let digits = BBElapsedTimer.formatted(context.date.timeIntervalSince(startTime),
                                                  showsHours: showsHours)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    stacked(digits)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            titleColumn
                            Spacer()
                            BBElapsedTimer.face(digits, color: color)
                        }
                        stacked(digits)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stacked(_ digits: String) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            titleColumn
            BBElapsedTimer.face(digits, color: color)
        }
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(color)
            BBTheme.Typography.title3(title)
                .foregroundStyle(BBTheme.Colors.textPrimary)
        }
    }
}

import SwiftUI

/// The digits every running-timer card draws and how they read; the clock
/// that moves them lives in `BBTimerFit`.
enum BBElapsedTimer {
    static var defaultFont: Font {
        BBTheme.Typography.scaled(36, relativeTo: .largeTitle, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// The digits as every timer card draws them.
    static func face(_ text: String, font: Font = defaultFont, color: Color) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// When `showsHours` is `true`, values of an hour or more render as
    /// `HH:MM:SS` (sleep cards); otherwise the minutes run on past 59.
    static func formatted(_ elapsed: TimeInterval, showsHours: Bool) -> String {
        let total = Int(elapsed)
        let hours = total / 3600
        if showsHours && hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, total % 3600 / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// A running timer with what is running beside it while the two fit one line,
/// else above it. The timer's width follows the elapsed time as well as the
/// text size (hours on a sleep past an hour, three-digit minutes on a feed past
/// 100), so the fit picks the shape, not the size: beside wide digits the
/// words' column broke «Дневной» on a 320-pt screen and «Сцеженное» at AX2 on
/// the Feeding and Sleep cards, and «Кормление» on Home's card. Always stacked
/// at accessibility sizes, whatever the width: the fit would set a short title
/// beside its timer and a long one above it, and at the largest text the
/// running cards keep one shape.
struct BBTimerFit<Content: View>: View {
    let startTime: Date
    var showsHours: Bool = false
    var font: Font = BBElapsedTimer.defaultFont
    let color: Color
    /// The gap on each side of the spacer in the one-line shape; `nil` takes
    /// the stack's default.
    var spacing: CGFloat? = nil
    @ViewBuilder let content: () -> Content
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
                        HStack(spacing: spacing) {
                            content()
                            Spacer()
                            BBElapsedTimer.face(digits, font: font, color: color)
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
            content()
            BBElapsedTimer.face(digits, font: font, color: color)
        }
    }
}

/// The Feeding and Sleep cards' top: a small coloured label over the title,
/// beside the elapsed time or above it as `BBTimerFit` decides.
struct BBTimerCardHeader: View {
    let label: String
    let title: String
    let color: Color
    let startTime: Date
    var showsHours: Bool = false

    var body: some View {
        BBTimerFit(startTime: startTime, showsHours: showsHours, color: color) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(color)
                BBTheme.Typography.title3(title)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
            }
        }
    }
}

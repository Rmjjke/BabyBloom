import SwiftUI
import Charts

// MARK: - History Filter

enum HistoryFilter: String, CaseIterable {
    case day   = "filter.day"
    case week  = "filter.week"
    case month = "filter.month"
    case year  = "filter.year"

    /// The earliest date that falls within this filter period (start of that day).
    func startDate() -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch self {
        case .day:   return today
        case .week:  return cal.date(byAdding: .day,   value: -6,  to: today)!
        case .month: return cal.date(byAdding: .month, value: -1,  to: today)!
        case .year:  return cal.date(byAdding: .year,  value: -1,  to: today)!
        }
    }
}

// MARK: - Filter Picker

struct BBHistoryFilterPicker: View {
    @Binding var selected: HistoryFilter

    var body: some View {
        HStack(spacing: 2) {
            ForEach(HistoryFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selected = filter
                    }
                } label: {
                    Text(filter.rawValue.l)
                        .font(.system(size: 13, weight: selected == filter ? .semibold : .medium, design: .rounded))
                        .foregroundStyle(selected == filter ? .white : BBTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Group {
                                if selected == filter {
                                    RoundedRectangle(cornerRadius: 10).fill(BBTheme.Colors.primary)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(BBTheme.Colors.primary.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - Weekly Bar Chart

///
/// Weekly bar chart built on Apple's **Swift Charts** framework.
///
/// Public API is unchanged from the previous hand-rolled version — `valueFor`,
/// `color` and the optional `formatValue` — so Feeding / Sleep / Diaper call
/// sites need no edits.
///
/// **Performance.** The old version exposed `days` and `maxVal` as *computed*
/// properties. SwiftUI evaluated `body` and each of those on every render, and
/// `maxVal` re-derived `days` in turn — so `valueFor` (an O(N) filter over all
/// entries) ran 7 × (several evaluations) = several passes of O(7·N) per render.
/// Now the 7-day dataset is materialised **once** at the top of `body`
/// (`let week = makeDays()`), and `maxVal` / the max-bar index are derived from
/// that single array — one O(7·N) pass per render.
struct BBWeeklyBarChart: View {

    private struct Day: Identifiable {
        let date: Date
        let value: Double
        let shortLabel: String
        let dayNumber: String
        let isToday: Bool
        let isFuture: Bool
        var id: Date { date }
    }

    let valueFor: (Date) -> Double
    let color: Color
    var formatValue: (Double) -> String = { v in
        v == floor(v) ? "\(Int(v))" : String(format: "%.1f", v)
    }

    @State private var weekOffset = 0   // 0 = current week, -1 = last week, …

    private var canGoForward: Bool { weekOffset < 0 }
    private let chartHeight: CGFloat = 150

    private func mondayOf(_ date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)   // 1=Sun … 7=Sat
        let daysFromMonday = (weekday - 2 + 7) % 7          // Mon=0 … Sun=6
        return cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: date))!
    }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let monday = mondayOf(Date())
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    /// Materialise the 7-day dataset **once**. Runs `valueFor` exactly 7× and
    /// reuses a single `DateFormatter` for weekday abbreviations.
    private func makeDays() -> [Day] {
        let cal  = Calendar.current
        let f    = DateFormatter()
        f.locale = LocalizationManager.shared.language.locale
        f.dateFormat = "EEE"
        let todayStart = cal.startOfDay(for: Date())
        return weekDays.map { date in
            Day(date: date,
                value: valueFor(date),
                shortLabel: String(f.string(from: date).prefix(2)).capitalized,
                dayNumber: "\(cal.component(.day, from: date))",
                isToday: cal.isDateInToday(date),
                isFuture: date > todayStart)
        }
    }

    private var monthTitle: String {
        let first = weekDays.first!
        let last  = weekDays.last!
        let cal   = Calendar.current
        let f     = DateFormatter()
        f.locale  = LocalizationManager.shared.language.locale
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            f.dateFormat = "LLLL yyyy"
            return f.string(from: first).capitalized
        } else {
            f.dateFormat = "LLL"
            let m1 = f.string(from: first).capitalized
            let m2 = f.string(from: last).capitalized
            f.dateFormat = "yyyy"
            return "\(m1) – \(m2) \(f.string(from: last))"
        }
    }

    /// Bar fill: today at full saturation, other days slightly muted; both fade
    /// top→bottom to `opacity(0.35)` of their base. Future (empty) days get a
    /// whisper-soft wash so the slot reads as "no data yet".
    private func barGradient(for day: Day) -> LinearGradient {
        let top: Color
        let bottom: Color
        if day.isFuture {
            top = color.opacity(0.10); bottom = color.opacity(0.05)
        } else if day.isToday {
            top = color; bottom = color.opacity(0.35)
        } else {
            top = color.opacity(0.5); bottom = color.opacity(0.175)
        }
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // Compute the 7-day dataset ONCE per render (see doc comment above).
        let week    = makeDays()
        let maxVal  = week.map(\.value).max() ?? 0
        let maxID   = maxVal > 0 ? week.first(where: { $0.value == maxVal })?.id : nil
        let yUpper  = max(maxVal * 1.18, 1)              // headroom for the annotation
        let todayLabel = week.first(where: { $0.isToday })?.shortLabel

        VStack(spacing: BBTheme.Spacing.sm) {

            // Month header + navigation
            HStack(spacing: BBTheme.Spacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .frame(width: 28, height: 28)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .cornerRadius(8)
                        .frame(width: 44, height: 44)      // ≥44pt tap zone (visual stays 28)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("chart_prev_week")
                .accessibilityLabel("chart.previous_week".l)

                Spacer()

                Text(monthTitle)
                    .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                    .id(monthTitle)   // triggers transition on week change

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { weekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canGoForward ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(canGoForward ? BBTheme.Colors.primary.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        .frame(width: 44, height: 44)      // ≥44pt tap zone (visual stays 28)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("chart_next_week")
                .accessibilityLabel("chart.next_week".l)
                .disabled(!canGoForward)
            }

            // Swift Charts bar chart
            Chart(week) { day in
                BarMark(
                    x: .value("chart.axis.day".l, day.shortLabel),
                    y: .value("chart.axis.value".l, day.value),
                    width: .ratio(0.55)
                )
                .cornerRadius(4)
                .foregroundStyle(barGradient(for: day))
                .annotation(position: .top, spacing: 4) {
                    // Value label ONLY over the tallest bar of the week.
                    if day.id == maxID {
                        Text(formatValue(day.value))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(color)
                    }
                }
            }
            .chartXScale(domain: week.map(\.shortLabel))     // preserve Mon→Sun order
            .chartYScale(domain: 0...yUpper)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                        .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.06))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            let isToday = (label == todayLabel)
                            Text(label)
                                .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isToday ? color : BBTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .frame(height: chartHeight)
            .animation(.easeOut(duration: 0.35), value: weekOffset)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.width < 0 {
                        withAnimation(.easeInOut(duration: 0.2)) { weekOffset -= 1 }
                    } else if value.translation.width > 0, canGoForward {
                        withAnimation(.easeInOut(duration: 0.2)) { weekOffset += 1 }
                    }
                }
        )
    }
}

// MARK: - Delete History Button

struct BBDeleteHistoryButton: View {
    let onDelete: () -> Void
    @State private var showConfirm = false

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            Label("button.delete_history".l, systemImage: "trash")
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(BBTheme.Spacing.md)
                .background(Color.red.opacity(0.06))
                .cornerRadius(BBTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        }
        .alert("button.delete_history".l, isPresented: $showConfirm) {
            Button("button.delete".l, role: .destructive) { onDelete() }
            Button("button.cancel".l, role: .cancel) {}
        } message: {
            Text("confirm.delete_message".l)
        }
    }
}

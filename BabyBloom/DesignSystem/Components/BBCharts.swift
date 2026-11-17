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
        let cal = LocalizationManager.shared.language.calendar
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
                        .foregroundStyle(selected == filter ? BBTheme.Colors.onPrimary : BBTheme.Colors.textSecondary)
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
/// (`let week = makeDays()`), and `maxVal` is derived from that single array —
/// one O(7·N) pass per render.
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
        v == floor(v) ? "\(Int(v))" : v.appDecimal(1)
    }
    /// What VoiceOver reads as a bar's value up to today. nil leaves Swift
    /// Charts reading the plotted number, which for a count is its own words;
    /// a duration plotted in hours would read as «2,08».
    var voiceOverValue: ((Double) -> String)? = nil

    /// The week shown first, counted from the current one (-1 = last week):
    /// a past month opens straight away, without stepping back to it.
    var startingWeekOffset = 0
    @State private var weekStep = 0   // the reader's steps from the first week
    private var weekOffset: Int { startingWeekOffset + weekStep }   // 0 = current week

    private var canGoForward: Bool { weekOffset < 0 }
    private let chartHeight: CGFloat = 150

    /// The app's calendar starts every week on Monday, in every language.
    private var weekDays: [Date] {
        let cal = LocalizationManager.shared.language.calendar
        let monday = cal.dateInterval(of: .weekOfYear, for: Date())!.start
        let weekStart = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    /// Materialise the 7-day dataset **once**: runs `valueFor` exactly 7×.
    private func makeDays() -> [Day] {
        let language = LocalizationManager.shared.language
        let cal = language.calendar
        let todayStart = cal.startOfDay(for: Date())
        return weekDays.map { date in
            Day(date: date,
                value: valueFor(date),
                shortLabel: LocaleDates.shortWeekday(date, locale: language.locale),
                dayNumber: "\(cal.component(.day, from: date))",
                isToday: cal.isDateInToday(date),
                isFuture: date > todayStart)
        }
    }

    private var monthTitle: String {
        LocaleDates.monthTitle(weekDays.first!, weekDays.last!,
                               locale: LocalizationManager.shared.language.locale)
            .gluingNumbersToCounters
    }

    /// Every title the header can show around this week's year, one word a
    /// line: each month alone and each week across two months, December into
    /// the next January included. The header picks its layout on the widest
    /// of them, so it never changes between two weeks.
    private var everyMonthTitleProbe: String {
        let locale = LocalizationManager.shared.language.locale
        let cal = SupportedLanguage.gregorian(locale: locale)
        let year = cal.component(.year, from: weekDays.first!)
        let starts = (1...13).compactMap { cal.date(from: DateComponents(year: year, month: $0, day: 1)) }
        var titles: [String] = []
        for (start, next) in zip(starts, starts.dropFirst()) {
            titles.append(LocaleDates.monthTitle(start, start, locale: locale))
            let lastDay = cal.date(byAdding: .day, value: -1, to: next)!
            titles.append(LocaleDates.monthTitle(lastDay, next, locale: locale))
        }
        return titles.map { $0.gluingNumbersToCounters.oneWordALine }.joined(separator: "\n")
    }

    /// Even digits: a year then measures the same in every title, so the
    /// probe of one year holds for all.
    private var monthTitleFont: Font {
        BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded).monospacedDigit()
    }

    /// The month title between the week buttons while the widest word of any
    /// month title fits there (fi «Marraskuu 2026» missed on a 320-pt screen
    /// at AX2), else on a line of its own above them. Its words wrap, never
    /// break; the buttons keep their 44-pt tap zones in both.
    private var monthHeader: some View {
        let probe = everyMonthTitleProbe
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: BBTheme.Spacing.sm) {
                previousWeekButton
                Spacer(minLength: 0)
                monthTitleText(probe: probe)
                Spacer(minLength: 0)
                nextWeekButton
            }
            VStack(spacing: BBTheme.Spacing.xs) {
                monthTitleText(probe: probe)
                    .frame(maxWidth: .infinity)
                HStack {
                    previousWeekButton
                    Spacer()
                    nextWeekButton
                }
            }
        }
        .wordFitTypesetting()
    }

    private func monthTitleText(probe: String) -> some View {
        // The ideal is the probe's, not this title's: the header's layout
        // must not change from one week to the next.
        WidestWordIdeal(holdsIdeal: true) {
            Text(probe).font(monthTitleFont).hidden().accessibilityHidden(true)
            Text(monthTitle).font(monthTitleFont).multilineTextAlignment(.center)
        }
        .foregroundStyle(BBTheme.Colors.textPrimary)
        .id(monthTitle)   // triggers transition on week change
    }

    private var previousWeekButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { weekStep -= 1 }
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
    }

    private var nextWeekButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { weekStep += 1 }
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
        let yUpper  = max(maxVal * 1.18, 1)              // headroom for the tallest bar's value
        let todayLabel = week.first(where: { $0.isToday })?.shortLabel

        VStack(spacing: BBTheme.Spacing.sm) {

            monthHeader

            // Swift Charts bar chart
            Chart(week) { day in
                BarMark(
                    x: .value("chart.axis.day".l, day.shortLabel),
                    y: .value("chart.axis.value".l, day.value),
                    width: .ratio(0.55)
                )
                .cornerRadius(4)
                .foregroundStyle(barGradient(for: day))
                .spokenValue(day.isFuture ? nil : voiceOverValue?(day.value))
                // A future day shows no bar and no number; it would read «0».
                .accessibilityHidden(day.isFuture)
                .annotation(position: .top, spacing: 4) {
                    // Each day up to today states its value, «0» included, so
                    // the chart needs no axis numbers; a future day has none
                    // yet. Hidden from VoiceOver: the bar already speaks its
                    // day and value, and the label would say the value twice.
                    if !day.isFuture {
                        Text(formatValue(day.value))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(day.isToday ? BBTheme.Colors.textPrimary : BBTheme.Colors.textSecondary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .chartXScale(domain: week.map(\.shortLabel))     // preserve Mon→Sun order
            .chartYScale(domain: 0...yUpper)
            .chartYAxis {
                // Grid lines only: every bar carries its value above it.
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.06))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            let isToday = (label == todayLabel)
                            Text(label)
                                .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isToday ? BBTheme.Colors.textPrimary : BBTheme.Colors.textSecondary)
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
                        withAnimation(.easeInOut(duration: 0.2)) { weekStep -= 1 }
                    } else if value.translation.width > 0, canGoForward {
                        withAnimation(.easeInOut(duration: 0.2)) { weekStep += 1 }
                    }
                }
        )
    }
}

private extension ChartContent {
    /// The mark's VoiceOver value when one is given; else Swift Charts' own.
    @ChartContentBuilder
    func spokenValue(_ text: String?) -> some ChartContent {
        if let text {
            accessibilityValue(Text(text))
        } else {
            self
        }
    }
}

// MARK: - Delete History Button

struct BBDeleteHistoryButton: View {
    /// What the button actually reaches, which decides whether the
    /// confirmation may speak of "the selected period".
    ///
    /// Only `BBHistorySection` has a `BBHistoryFilterPicker` above it, so only
    /// there does a period exist to refer to. `EventsView`'s button wipes the
    /// whole event history, and telling that parent their records will go "in
    /// the selected period" names a scope they never chose and reads as a
    /// subset — an under-warning on an irreversible action.
    enum Scope { case selectedPeriod, everything }

    var scope: Scope = .selectedPeriod
    /// Whether the range also holds rows that are not on screen — because the
    /// free history window is hiding them, or because a row cap is. The plain
    /// confirmation would be a half-truth then: a parent who cannot see those
    /// rows has no way to know the button reaches them.
    var deletesHiddenRows = false
    /// For a list that shows rows this button does not delete (Events lists
    /// pediatrician visits it keeps): "All records" would overstate the wipe.
    /// nil keeps the shared texts every other screen uses.
    var messageKey: String? = nil
    var hiddenMessageKey: String? = nil
    let onDelete: () -> Void
    @State private var showConfirm = false

    private var confirmationMessage: String {
        guard deletesHiddenRows else { return (messageKey ?? "confirm.delete_message").l }
        if let hiddenMessageKey { return hiddenMessageKey.l }
        switch scope {
        case .selectedPeriod: return "confirm.delete_message_hidden".l
        case .everything:     return "confirm.delete_message_all".l
        }
    }

    var body: some View {
        Button {
            showConfirm = true
        } label: {
            // No red wash under the red words: it took them from 3.25:1 to
            // 3.01:1. The stroke alone draws the button, and the content shape
            // keeps all of it tappable now that nothing fills it.
            Label("button.delete_history".l, systemImage: "trash")
                .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(BBTheme.Spacing.md)
                .overlay(
                    RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: BBTheme.Radius.md))
        }
        .alert("button.delete_history".l, isPresented: $showConfirm) {
            Button("button.delete".l, role: .destructive) { onDelete() }
            Button("button.cancel".l, role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }
}

import SwiftUI

/// Last week on the Dashboard (design note m1-weekly-summary; D8, D17–D19).
/// Collapsed: three value rows; the header row expands it to the week before,
/// the per-day bars and the longest sleep. × hides it until next Monday.
struct WeeklySummaryCard: View {
    let summary: WeeklySummary
    let onAddWeighing: () -> Void

    /// The Monday of the week the parent hid, "2026-10-19"; local to this
    /// device on purpose (note § 6), so it needs no sync.
    @AppStorage("weekly.hiddenWeek") private var hiddenWeek = ""
    /// The week `weekly_summary_viewed` was last sent for: once a week, not
    /// once per Dashboard visit.
    @AppStorage("weekly.viewedWeek") private var viewedWeek = ""
    @State private var expanded: Bool

    /// `startExpanded` is for the render dump; the Dashboard opens it collapsed
    /// (DECISION 2026-10-29: a notification tap lands collapsed too).
    init(summary: WeeklySummary, startExpanded: Bool = false, onAddWeighing: @escaping () -> Void) {
        self.summary = summary
        self.onAddWeighing = onAddWeighing
        _expanded = State(initialValue: startExpanded)
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The Monday as a calendar date, not an instant: an instant shifts with
    /// the time zone, and a hidden card would come back after a flight.
    private var weekKey: String {
        let day = WeeklySummary.calendar.dateComponents([.year, .month, .day], from: summary.week.start)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    var body: some View {
        if hiddenWeek != weekKey {
            card
                .transition(.opacity)
                .onAppear {
                    // Marked only when the event went out: opting in mid-week
                    // still counts this week's view.
                    guard viewedWeek != weekKey, Analytics.shared.track(.weeklySummaryViewed) else { return }
                    viewedWeek = weekKey
                }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            header
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                feedsRow
                sleepRow
                gainRow
                if summary.previous == nil {
                    BBTheme.Typography.caption("weekly.first_week".l)
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if summary.current.daysWithEntries < 7 {
                    BBTheme.Typography.caption(String(format: "weekly.days_logged_fmt".l,
                                                      summary.current.daysWithEntries))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
            // iPad: the delta stays near its value (note § 4).
            .frame(maxWidth: 480, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bbCard()
        .accessibilityIdentifier("weekly.card")
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: BBTheme.Spacing.sm) {
            Button {
                // Reduce Motion: the rows appear in place, no height animation.
                if reduceMotion {
                    expanded.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
                }
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        BBTheme.Typography.title3("weekly.title".l)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                        BBTheme.Typography.caption(WeeklyFormat.range(summary.week))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .frame(width: 28, height: 28)
                }
                .frame(minHeight: 44, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("weekly.title".l + ", " + WeeklyFormat.range(summary.week))
            .accessibilityHint(expanded ? "weekly.a11y_collapse".l : "weekly.a11y_expand".l)
            .accessibilityIdentifier("weekly.expand")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { hiddenWeek = weekKey }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(BBTheme.Colors.textSecondary.opacity(0.10)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("weekly.a11y_hide".l)
            .accessibilityIdentifier("weekly.hide")
            .padding(.top, -8)
            .padding(.trailing, -8)
        }
    }

    // MARK: Rows

    private var feedsRow: some View {
        let current = summary.current.feedsPerDay
        let previous = summary.previous?.feedsPerDay
        return row(icon: "heart.fill", tint: BBTheme.Colors.feeding,
                   format: "weekly.feeds_fmt", value: current.map(WeeklyFormat.perDay),
                   delta: WeeklyFormat.feedsDelta(current, previous),
                   previous: previous.map(WeeklyFormat.perDay),
                   bars: summary.current.feedsByDay.map(Double.init))
    }

    private var sleepRow: some View {
        let current = summary.current.sleepPerDay
        let previous = summary.previous?.sleepPerDay
        return row(icon: "moon.fill", tint: BBTheme.Colors.sleep,
                   format: "weekly.sleep_fmt", value: current.map(WeeklyFormat.duration),
                   delta: WeeklyFormat.sleepDelta(current, previous),
                   previous: previous.map(WeeklyFormat.duration),
                   bars: summary.current.sleepByDay,
                   extra: summary.current.longestSleep.map {
                       String(format: "weekly.longest_sleep_fmt".l, WeeklyFormat.duration($0))
                   })
    }

    @ViewBuilder
    private var gainRow: some View {
        switch summary.gain {
        case .perWeek(let grams):
            row(icon: "scalemass.fill", tint: BBTheme.Colors.growth,
                format: "weekly.gain_fmt", value: WeeklySummary.signed(grams),
                delta: nil,
                previous: summary.previousGain.map {
                    String(format: "velocity.per_week_fmt".l, WeeklySummary.signed($0))
                },
                bars: nil)
        case .newborn:
            note(icon: "scalemass.fill", text: "weekly.gain_newborn".l)
        case .needsWeighing:
            VStack(alignment: .leading, spacing: 2) {
                note(icon: "scalemass.fill", text: "weekly.gain_needs_weighing".l)
                Button(action: onAddWeighing) {
                    Text("growth.add_weighing".l)
                        .font(BBTheme.Typography.scaled(16, relativeTo: .callout, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.leading, 23)
                .accessibilityIdentifier("weekly.add_weighing")
            }
        }
    }

    /// A value row. A nil value (nothing of that kind logged) leaves the row
    /// out rather than printing a zero that reads as a verdict.
    @ViewBuilder
    private func row(icon: String, tint: Color, format: String, value: String?,
                     delta: (up: Bool, text: String)?, previous: String?,
                     bars: [Double]?, extra: String? = nil) -> some View {
        if let value {
            VStack(alignment: .leading, spacing: 4) {
                let stacked = typeSize >= .accessibility1
                let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                                     : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    layout {
                        WeeklyFormat.labelled(format.l, value: value)
                            .foregroundStyle(BBTheme.Colors.textPrimary)
                            .lineLimit(stacked ? nil : 1)
                            .minimumScaleFactor(0.85)
                        if !stacked { Spacer(minLength: 0) }
                        if summary.previous != nil, let delta {
                            deltaView(delta)
                        }
                    }
                }
                // One VoiceOver stop per row, so the delta is read with the
                // value it belongs to.
                .accessibilityElement(children: .combine)
                if expanded {
                    VStack(alignment: .leading, spacing: 4) {
                        if let previous, summary.previous != nil || bars == nil {
                            BBTheme.Typography.caption(String(format: "weekly.previous_fmt".l, previous))
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                        if let bars { barsView(bars) }
                        if let extra {
                            BBTheme.Typography.caption(extra)
                                .foregroundStyle(BBTheme.Colors.textSecondary)
                        }
                    }
                    .padding(.leading, 23)
                    .transition(.opacity)
                }
            }
        }
    }

    private func note(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(BBTheme.Colors.growth)
                .accessibilityHidden(true)
            BBTheme.Typography.callout(text)
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Neutral by rule (P1, plan v2 review): never green or red.
    private func deltaView(_ delta: (up: Bool, text: String)) -> some View {
        HStack(spacing: 2) {
            Image(systemName: delta.up ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .semibold))
            BBTheme.Typography.caption(delta.text)
                .monospacedDigit()
        }
        .foregroundStyle(BBTheme.Colors.textSecondary)
    }

    /// Seven bars, Monday first; a day without entries is a faint stub.
    private func barsView(_ values: [Double]) -> some View {
        let top = max(values.max() ?? 0, 1)
        let letters = WeeklyFormat.weekdayLetters
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<7, id: \.self) { day in
                VStack(spacing: 2) {
                    let has = summary.current.dayHasEntries[day] && values[day] > 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(has ? BBTheme.Colors.primary : BBTheme.Colors.primary.opacity(0.15))
                        .frame(width: 6, height: has ? max(4, 28 * values[day] / top) : 2)
                        .frame(height: 28, alignment: .bottom)
                    BBTheme.Typography.caption(letters[day])
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                .frame(minWidth: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The card's number formats, all in the app's language.
enum WeeklyFormat {
    private static var locale: Locale { LocalizationManager.shared.language.locale }

    /// "20 – 26 Oct": the month once when both ends share it.
    static func range(_ week: WeeklySummary.Week) -> String {
        let calendar = WeeklySummary.calendar
        let last = calendar.date(byAdding: .day, value: -1, to: week.end)!
        let sameMonth = calendar.component(.month, from: week.start) == calendar.component(.month, from: last)
        let first = sameMonth
            ? week.start.formatted(.dateTime.day().locale(locale))
            : week.start.appDayMonth
        return String(format: "weekly.range_fmt".l, first, last.appDayMonth)
    }

    static func perDay(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60
            ? String(format: "duration.h_min".l, minutes / 60, minutes % 60)
            : String(format: "duration.min_only".l, minutes)
    }

    /// nil when there is nothing to compare or the shown values are equal.
    static func feedsDelta(_ current: Double?, _ previous: Double?) -> (up: Bool, text: String)? {
        guard let current, let previous else { return nil }
        let difference = (current * 10).rounded() / 10 - (previous * 10).rounded() / 10
        guard abs(difference) >= 0.05 else { return nil }
        return (difference > 0, perDay(abs(difference)))
    }

    static func sleepDelta(_ current: TimeInterval?, _ previous: TimeInterval?) -> (up: Bool, text: String)? {
        guard let current, let previous else { return nil }
        let difference = (current / 60).rounded() - (previous / 60).rounded()
        guard difference != 0 else { return nil }
        return (difference > 0, duration(abs(difference) * 60))
    }

    /// "Feeds a day: 7.4" as one Text, the value in the metric style: the
    /// format is split at its `%@`, so word order stays the translator's.
    static func labelled(_ format: String, value: String) -> Text {
        let parts = format.components(separatedBy: "%@")
        let label = BBTheme.Typography.scaled(16, relativeTo: .callout, weight: .regular)
        var text = Text(parts.first ?? "").font(label)
        if parts.count > 1 {
            text = text + BBTheme.Typography.metricSmall(value)
                + Text(parts.dropFirst().joined(separator: value)).font(label)
        } else {
            text = text + Text(" ") + BBTheme.Typography.metricSmall(value)
        }
        return text
    }

    /// M T W T F S S in the app's language, Monday first.
    static var weekdayLetters: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols   // Sunday first
        return Array(symbols[1...]) + [symbols[0]]
    }
}

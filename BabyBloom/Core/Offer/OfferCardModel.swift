import Foundation

/// What one offer card shows, built only from the person's own records.
///
/// Every string and number here is something the free app already shows the
/// parent: record counts, sleep totals, the weekly averages of the Home card,
/// a weighing's weight and date, a day count. Never a gain, a trend, a
/// percentile, a price or a count of offers — the card points at what Premium
/// adds without handing out a paid figure in passing.
struct OfferCardModel: Equatable {

    enum Visual: Equatable {
        case none
        /// Records per calendar day, oldest first, at most `maxBars`.
        case bars([Int])
        /// Fewer than two days with records in the bars' window: a single
        /// record never draws a chart, a line of text stands in its place.
        case thin
        case curve(Curve)
    }

    /// The WHO weight band for the baby's sex with the baby's own weighings
    /// on it, in corrected-age days.
    struct Curve: Equatable {
        struct Point: Equatable {
            let ageDays: Double
            let kg: Double
        }
        let band: [WHOCorridor.Sample]
        /// Oldest first; the last one is the newest and is drawn emphasised.
        let points: [Point]
        let ageDomain: ClosedRange<Double>
    }

    let content: OfferContent
    let title: String
    let body: String
    let visual: Visual
    /// Each stat as written on the card, in order; empty means no stats line.
    let stats: [String]
    /// The summary element's label: title, what the card shows, body.
    let accessibilityLabel: String

    static let maxBars = 7
    /// The curve runs this far past the newest weighing, so the newest dot
    /// never sits on the right edge.
    static let curveLeadDays = 14

    struct Input {
        /// Start of every feed, a running one included.
        var feeds: [Date] = []
        /// Every sleep by its start; `end` nil while it runs (it counts as a
        /// record, but has no length yet).
        var sleeps: [(start: Date, end: Date?)] = []
        var diapers: [Date] = []
        /// Custom events: they are records for the day counts, not bars.
        var events: [Date] = []
        /// Growth-entry dates, for the month report's "days with entries".
        var growthDates: [Date] = []
        /// Weighings with a weight, oldest first.
        var weighings: [WeightMeasurement] = []
        var babyName: String = ""
        var isMale: Bool = false
        var correctedBirthDate: Date
        var onboardingEndedAt: Date
        var now: Date
        var calendar: Calendar = .current
    }

    static func make(_ content: OfferContent, input: Input) -> OfferCardModel {
        let base = "offer.\(content.rawValue)"
        switch content {
        case .firstResultDays:
            let window = firstResultWindow(input)
            return daysCard(content, input: input, window: window,
                            title: "\(base).title".l, body: "\(base).body".l, thinBody: "\(base).body_thin".l)
        case .firstWeek:
            let today = input.calendar.startOfDay(for: input.now)
            let start = input.calendar.date(byAdding: .day, value: -(maxBars - 1), to: today) ?? today
            // first_week has no thin body: its sentence names no chart "like this".
            return daysCard(content, input: input, window: (start, maxBars),
                            title: "\(base).title".l, body: "\(base).body".l, thinBody: "\(base).body".l)
        case .firstResultPoint, .growthPoint:
            let name = input.babyName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = content == .firstResultPoint && !name.isEmpty
                ? String(format: "offer.first_result_point.title_fmt".l, name)
                : "offer.growth_point.title".l
            let body = "\(base).body".l
            return curveCard(content, input: input, title: title, body: body)
        case .historyEdge:
            let days = recordDays(input).count
            let title = PluralFamily.offerHistoryEdgeTitle.text(days)
            let body = PluralFamily.offerHistoryEdgeBody.text(HistoryWindow.freeDays)
            return OfferCardModel(content: content, title: title, body: body, visual: .none, stats: [],
                                  accessibilityLabel: summary(title, [], body))
        case .monthReport:
            let stats = monthStats(input)
            let title = "\(base).title".l
            let body = "\(base).body".l
            return OfferCardModel(content: content, title: title, body: body, visual: .none, stats: stats,
                                  accessibilityLabel: summary(title, stats, body))
        }
    }

    // MARK: - Days bars

    /// From the first day with a record after onboarding ended to today,
    /// capped to the last `maxBars` days.
    private static func firstResultWindow(_ input: Input) -> (start: Date, count: Int) {
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        let first = recordDates(input)
            .filter { $0 >= input.onboardingEndedAt && $0 <= input.now }
            .min()
            .map(calendar.startOfDay(for:)) ?? today
        let span = OfferRule.days(from: first, to: today, calendar: calendar) + 1
        let count = min(maxBars, max(1, span))
        let start = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
        return (start, count)
    }

    private static func daysCard(_ content: OfferContent, input: Input, window: (start: Date, count: Int),
                                 title: String, body: String, thinBody: String) -> OfferCardModel {
        let calendar = input.calendar
        let end = calendar.date(byAdding: .day, value: window.count, to: window.start) ?? input.now
        let inWindow = { (date: Date) in date >= window.start && date < end && date <= input.now }
        let index = { (date: Date) in OfferRule.days(from: window.start, to: date, calendar: calendar) }

        let feeds = input.feeds.filter(inWindow)
        let sleeps = input.sleeps.filter { inWindow($0.start) }
        let diapers = input.diapers.filter(inWindow)

        var bars = Array(repeating: 0, count: window.count)
        for date in feeds + sleeps.map(\.start) + diapers {
            let day = index(date)
            if bars.indices.contains(day) { bars[day] += 1 }
        }

        guard bars.filter({ $0 > 0 }).count >= 2 else {
            let thin = "offer.thin_data".l
            return OfferCardModel(content: content, title: title, body: thinBody, visual: .thin, stats: [],
                                  accessibilityLabel: summary(title, [thin], thinBody))
        }

        var stats: [String] = []
        if !feeds.isEmpty { stats.append(String(format: "offer.stat.feeds_fmt".l, count(feeds.count))) }
        if !sleeps.isEmpty {
            let total = sleeps.reduce(0) { sum, sleep in
                sum + max(0, (sleep.end ?? sleep.start).timeIntervalSince(sleep.start))
            }
            stats.append(String(format: "offer.stat.sleep_fmt".l, WeeklyFormat.duration(total)))
        }
        if !diapers.isEmpty { stats.append(String(format: "offer.stat.diapers_fmt".l, count(diapers.count))) }

        return OfferCardModel(content: content, title: title, body: body, visual: .bars(bars), stats: stats,
                              accessibilityLabel: summary(title, stats, body))
    }

    // MARK: - Mini curve

    private static func curveCard(_ content: OfferContent, input: Input, title: String, body: String) -> OfferCardModel {
        let weighings = input.weighings.filter { $0.date <= input.now }.sorted { $0.date < $1.date }
        guard let newest = weighings.last else {
            return OfferCardModel(content: content, title: title, body: body, visual: .none, stats: [],
                                  accessibilityLabel: summary(title, [], body))
        }
        let weight = ReportFormat.kg(newest.weightKg)
        let date = newest.date.appDayMonth
        let stats = [weight, date]
        let spoken = String(format: "offer.a11y.point_fmt".l, weight, date)

        let visual = curve(weighings: weighings, input: input).map(Visual.curve) ?? .none
        return OfferCardModel(content: content, title: title, body: body, visual: visual, stats: stats,
                              accessibilityLabel: summary(title, [spoken], body))
    }

    /// nil when the newest weighing has no WHO reference (before term or past
    /// the table): no band is drawn under a point the standard cannot judge.
    private static func curve(weighings: [WeightMeasurement], input: Input) -> Curve? {
        let age = { (date: Date) in
            WHOGrowthStandard.correctedAgeDaysIfBorn(on: date, correctedBirthDate: input.correctedBirthDate)
                .flatMap { $0 <= WHOGrowthStandard.maxAgeDays ? $0 : nil }
        }
        guard let newest = weighings.last, let newestAge = age(newest.date) else { return nil }
        // An older pre-term weighing has no reference either: left off the band.
        let points = weighings.compactMap { weighing in
            age(weighing.date).map { Curve.Point(ageDays: Double($0), kg: weighing.weightKg) }
        }
        let upper = newestAge + curveLeadDays
        let band = WHOCorridor.samples(fromAgeDays: 0, toAgeDays: upper, isMale: input.isMale)
        guard band.count >= 2 else { return nil }
        return Curve(band: band, points: points, ageDomain: 0...Double(upper))
    }

    // MARK: - Month report

    /// The Home weekly card's two averages, over the last 28 days: per day
    /// with entries, as the weekly card divides.
    private static func monthStats(_ input: Input) -> [String] {
        let calendar = input.calendar
        let today = calendar.startOfDay(for: input.now)
        guard let start = calendar.date(byAdding: .day, value: -(OfferRule.monthReportDays - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        let period = PeriodSummary.make(
            start: start, end: end,
            input: PeriodSummary.Input(
                feeds: input.feeds.filter { $0 <= input.now },
                sleeps: input.sleeps.compactMap { sleep in sleep.end.map { (start: sleep.start, end: $0) } },
                otherEntries: (input.diapers + input.growthDates + input.events).filter { $0 <= input.now }),
            calendar: calendar)
        guard period.daysWithEntries > 0 else { return [] }
        var stats: [String] = []
        if period.totalFeeds > 0 {
            let perDay = Double(period.totalFeeds) / Double(period.daysWithEntries)
            stats.append(String(format: "weekly.feeds_fmt".l, WeeklyFormat.perDay(perDay)))
        }
        if period.totalSleep > 0 {
            let perDay = period.totalSleep / Double(period.daysWithEntries)
            stats.append(String(format: "weekly.sleep_fmt".l, WeeklyFormat.duration(perDay)))
        }
        return stats
    }

    // MARK: - Helpers

    private static func recordDates(_ input: Input) -> [Date] {
        input.feeds + input.sleeps.map(\.start) + input.diapers + input.events
    }

    /// Distinct calendar days with a record, up to now.
    private static func recordDays(_ input: Input) -> Set<Date> {
        Set(recordDates(input).filter { $0 <= input.now }.map(input.calendar.startOfDay(for:)))
    }

    private static func count(_ value: Int) -> String {
        value.formatted(.number.locale(LocalizationManager.shared.language.locale))
    }

    private static func summary(_ title: String, _ shown: [String], _ body: String) -> String {
        ([title] + shown + [body]).joined(separator: ", ")
    }
}

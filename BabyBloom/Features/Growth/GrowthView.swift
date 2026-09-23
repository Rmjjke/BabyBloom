import SwiftUI
import SwiftData

struct GrowthView: View {
    @Query(sort: \GrowthEntry.date, order: .reverse) private var entries: [GrowthEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var store
    @State private var showAddSheet = false
    @State private var showPaywall = false

    private var baby: Baby? { babies.first }
    private var latest: GrowthEntry? { entries.first }

    /// Entries are queried globally rather than through `baby.growthEntries`:
    /// nothing in the app sets `entry.baby`, so that relationship is always
    /// empty and reading from it would silently blank every card here.
    private var measurements: [WeightMeasurement] { entries.weightMeasurements }

    // GrowthView is only ever a push destination, and there are now two routes
    // into it: the More tab's Growth row (D6 IA change) and the Dashboard's
    // Growth section header. Both callers own the NavigationStack, so this view
    // must NOT wrap one of its own — that would nest a stack inside a stack
    // (double nav bar) on either route. Title/toolbar attach to whichever
    // enclosing stack pushed it. (DiaperView, a top-level tab, keeps its own
    // NavigationStack for the opposite reason.)
    var body: some View {
        ScrollView {
            VStack(spacing: BBTheme.Spacing.lg) {

                // Latest measurements
                latestSection
                    .padding(.horizontal, BBTheme.Spacing.md)

                if let baby, let corrected = baby.correctedAgeDescription {
                    CorrectedAgeChip(description: corrected)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }

                // First weeks — the only block that outranks the chart, and only
                // while it applies. Free for everyone, flags included.
                if let baby, let status = newbornStatus(baby) {
                    ExplainerCard(explainer: .newborn) {
                        NewbornProgressCard(status: status)
                    }
                    .padding(.horizontal, BBTheme.Spacing.md)
                }

                // Weight chart. Keyed to WEIGHINGS rather than entries, and to
                // one rather than two: with the WHO corridor under it a single
                // point is worth drawing — it shows where the baby sits — and
                // that single point is what every fresh install has. Two
                // height-only entries used to satisfy the old gate and render
                // an empty frame.
                if let baby, !measurements.isEmpty {
                    chartSection(baby)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }

                // Percentile card. Keyed to the newest WEIGHING rather than the
                // newest entry: recording this morning's height used to make the
                // whole card vanish until the next time the baby was weighed.
                if let baby, let weighing = measurements.last {
                    percentileSection(baby: baby, weighing: weighing)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }

                if let baby {
                    weightGainSection(baby)
                        .padding(.horizontal, BBTheme.Spacing.md)
                    trendSection(baby)
                        .padding(.horizontal, BBTheme.Spacing.md)
                    // Below gain and trend deliberately: NewbornProgressCard —
                    // the free red flags — must stay the first thing a worried
                    // parent sees.
                    nutritionSection(baby)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }

                // History
                historySection
                    .padding(.horizontal, BBTheme.Spacing.md)

                WHOFootnote()
                    .padding(.horizontal, BBTheme.Spacing.md)
            }
            // Bottom clearance so the FAB never permanently covers the last row.
            .padding(.bottom, BBTheme.Spacing.xxl + BBTheme.Spacing.md)
        }
        // Every "not enough data" card on this screen offers the one action that
        // resolves it, and they all open the sheet the "+" opens — one
        // presentation, injected once, rather than a sheet per card.
        .environment(\.addWeighingAction, { showAddSheet = true })
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            BBFab { showAddSheet = true }
                .padding(.trailing, BBTheme.Spacing.md)
                .padding(.bottom, BBTheme.Spacing.md)
        }
        .navigationTitle("tab.growth".l)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
        }
        .entrySheet(isPresented: $showAddSheet) {
            AddGrowthSheet()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // Every path here is cancel-before-add, so re-deriving on each visit
        // costs nothing and keeps signals honest if data changed elsewhere.
        .task { refreshGrowthNotifications() }
    }

    // MARK: - Latest
    private var latestSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.current_stats") {
                showAddSheet = true
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BBTheme.Spacing.md) {
                // Weight comes from `measurements`, not from `latest`: that
                // accessor drops future-dated rows, and this card sits two
                // cards above the percentile — which already reads them — so a
                // raw newest entry printed 4.50 kg over a percentile scored on
                // 4.30. Height and head stay on `latest`: no filter applies to
                // them, and their "—" already covers a missing figure.
                BBStatCard(
                    title: "stat.weight",
                    value: measurements.last.map { String(format: "%.2f", $0.weightKg) } ?? "—",
                    unit: "unit.kg",
                    icon: "scalemass.fill",
                    color: BBTheme.Colors.growth,
                    action: { showAddSheet = true }
                )
                BBStatCard(
                    title: "stat.height",
                    value: latest.flatMap { $0.heightCm.map { String(format: "%.1f", $0) } } ?? "—",
                    unit: "unit.cm",
                    icon: "ruler.fill",
                    color: BBTheme.Colors.primary,
                    action: { showAddSheet = true }
                )
                BBStatCard(
                    title: "stat.head",
                    value: latest.flatMap { $0.headCircumferenceCm.map { String(format: "%.1f", $0) } } ?? "—",
                    unit: "unit.cm",
                    icon: "circle.dotted",
                    color: BBTheme.Colors.accent,
                    action: { showAddSheet = true }
                )
                BBStatCard(
                    title: "stat.measurements",
                    value: "\(entries.count)",
                    unit: "unit.times",
                    icon: "calendar",
                    color: BBTheme.Colors.diaper,
                    action: { showAddSheet = true }
                )
            }
        }
    }

    // MARK: - Chart
    private func chartSection(_ baby: Baby) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weight_chart")
            WeightChartView(measurements: measurements,
                            correctedBirthDate: baby.correctedBirthDate,
                            isMale: baby.gender == .male)
        }
    }

    // MARK: - Percentile
    @ViewBuilder
    private func percentileSection(baby: Baby, weighing: WeightMeasurement) -> some View {
        // Corrected age, not chronological: a baby born preterm has to be
        // measured against the reference for the age it would be at term. And
        // the age ON THE WEIGHING DATE, not today's — see
        // `WHOGrowthStandard.percentile(of:correctedBirthDate:isMale:)`.
        if let reading = WHOGrowthStandard.percentileReading(
            of: weighing,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male
        ) {
            percentileCard(percentile: reading.percentile,
                           badge: reading.badge,
                           months: monthsAtWeighing(baby: baby, weighing: weighing),
                           weighedOn: weighing.date)
        } else if WHOGrowthStandard.correctedAgeDaysIfBorn(
                    on: weighing.date,
                    correctedBirthDate: baby.correctedBirthDate) == nil {
            // A preterm baby before its due date. `PercentileOutOfRangeCard`
            // would say the WHO tables stop at 24 months, which is true and has
            // nothing to do with this baby — the tables have not STARTED yet.
            ExplainerCard(explainer: .percentile) {
                PercentileBeforeDueDateCard()
            }
        } else {
            // Past 24 months the card holds a sentence instead of a figure, and
            // that sentence is exactly the one a parent wants explained.
            ExplainerCard(explainer: .percentile) {
                PercentileOutOfRangeCard()
            }
        }
    }

    /// Corrected age in whole months on the day of the weighing — the age the
    /// percentile beside it was actually scored at.
    private func monthsAtWeighing(baby: Baby, weighing: WeightMeasurement) -> Int {
        max(0, Calendar.current.dateComponents([.month],
                                               from: baby.correctedBirthDate,
                                               to: weighing.date).month ?? 0)
    }

    // MARK: - Insight blocks

    private func newbornStatus(_ baby: Baby) -> NewbornWeightLoss.Status? {
        NewbornWeightLoss.analyse(
            birthWeightKg: baby.birthWeightKg,
            birthDate: baby.birthDate,
            measurements: measurements
        )
    }

    /// Why the gain verdict is being withheld, if it is. Read from the module
    /// that owns the rule, never re-derived from `newbornStatus` being non-nil
    /// — that would be a second definition one refactor away from drifting, and
    /// it would miss the stale-pair case entirely, which is precisely the case
    /// where `newbornStatus` IS nil.
    private func gainDeferral(_ baby: Baby) -> NewbornWeightLoss.GainDeferral? {
        NewbornWeightLoss.gainDeferral(birthWeightKg: baby.birthWeightKg,
                                       birthDate: baby.birthDate,
                                       measurements: measurements)
    }

    /// Premium. The number itself stays hidden for free users — the teaser says
    /// what it would tell them, which is honest without giving it away.
    @ViewBuilder
    private func weightGainSection(_ baby: Baby) -> some View {
        if store.isPremium {
            ExplainerCard(explainer: .gain) {
                WeightGainCard(
                    reading: WeightVelocity.latest(
                        measurements: measurements,
                        correctedBirthDate: baby.correctedBirthDate,
                        isMale: baby.gender == .male
                    ),
                    hasWeighing: !measurements.isEmpty,
                    deferral: gainDeferral(baby)
                )
            }
        } else {
            LockedInsightCard(
                title: "section.weight_gain".l,
                teaser: "premium.teaser_gain".l,
                explainer: .gain
            ) { showPaywall = true }
        }
    }

    /// Premium, same reasoning as the gain card.
    @ViewBuilder
    private func trendSection(_ baby: Baby) -> some View {
        if store.isPremium {
            ExplainerCard(explainer: .trend) {
                CentileTrendCard(assessment: GrowthTrend.assess(
                    measurements: measurements,
                    birthDate: baby.birthDate,
                    correctedBirthDate: baby.correctedBirthDate,
                    isMale: baby.gender == .male,
                    birthPercentile: birthPercentile(baby)
                ))
            }
        } else {
            LockedInsightCard(
                title: "section.trend".l,
                teaser: "premium.teaser_trend".l,
                explainer: .trend
            ) { showPaywall = true }
        }
    }

    /// Built from the same queries the rest of the screen uses, filtered in
    /// memory — the window is weeks, not years.
    private func adequacy(_ baby: Baby) -> FeedingAdequacy.Assessment? {
        FeedingAdequacy.assess(
            birthDate: baby.birthDate,
            birthWeightKg: baby.birthWeightKg,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male,
            measurements: measurements,
            feeds: feedings.map { FeedingAdequacy.Feed(date: $0.startTime, type: $0.type) },
            wetNappies: diapers.filter { $0.type == .wet || $0.type == .both }.map(\.time)
        )
    }

    /// Free summary, then the Premium breakdown — and the breakdown appears
    /// only when gain itself came in below the reference. Feeding and nappy
    /// signals never open it on their own.
    @ViewBuilder
    private func nutritionSection(_ baby: Baby) -> some View {
        // Two different nils. Past six months the feature does not apply and
        // NOTHING shows. Inside the range with fewer than two weighings, the
        // section shows its "weigh again" prompt — passing nil through is what
        // makes that state reachable at all.
        if baby.correctedAgeDays <= FeedingAdequacy.maxAgeDays {
            let assessment = adequacy(baby)
            // One reading for both cards: the section's gain WORD and the
            // breakdown's figure have to describe the same pair of weighings.
            let reading = WeightVelocity.latest(
                measurements: measurements,
                correctedBirthDate: baby.correctedBirthDate,
                isMale: baby.gender == .male
            )
            // Free for everyone, so no sell tap to protect: the whole card
            // opens the explainer in both states, including the "weigh again"
            // one — a parent with no data yet is exactly who needs to read how
            // to get some.
            ExplainerCard(explainer: .nutrition) {
                NutritionSection(assessment: assessment, band: reading?.band,
                                 hasWeighing: !measurements.isEmpty)
            }
            // The breakdown below is a different card with a different title,
            // and its locked tap stays a pure sell — the section's explainer
            // already covers what the three signals mean.
            if let assessment, assessment.warrantsBreakdown {
                if store.isPremium {
                    FeedingBreakdownCard(assessment: assessment, reading: reading)
                } else {
                    LockedInsightCard(
                        title: "breakdown.title".l,
                        teaser: "premium.teaser_nutrition".l
                    ) { showPaywall = true }
                }
            }
        }
    }

    /// Birth centile decides which NICE threshold applies. Left nil for a preterm
    /// baby: its birth weight cannot be read off a term chart, and `GrowthTrend`
    /// falls back to the middle rule for exactly this case.
    private func birthPercentile(_ baby: Baby) -> Double? {
        guard !baby.isPreterm, let birthWeight = baby.birthWeightKg else { return nil }
        return WHOGrowthStandard.percentile(
            weightKg: birthWeight,
            ageDays: 0,
            isMale: baby.gender == .male
        )
    }

    /// The whole card opens the explainer — the mechanics and the reasoning now
    /// live in `ExplainerCard`, which the gain, trend and nutrition cards share.
    ///
    /// The card itself is `PercentileCard`, shared with onboarding's showcase
    /// page so the two can never drift. The explainer wrapper stays HERE: it is
    /// what injects the "?" badge, and nothing in onboarding would open a sheet.
    private func percentileCard(percentile: Double, badge: String,
                                months: Int, weighedOn: Date) -> some View {
        ExplainerCard(explainer: .percentile) {
            // Both lines describe the WEIGHING. The age is the one the figure
            // was scored at, and the date says which weighing that was —
            // without it "1 month old" reads as a claim about today when the
            // last entry is three weeks back.
            PercentileCard(
                percentile: percentile,
                badge: badge,
                captionLines: [
                    String(format: "percentile.by_who_fmt".l, months, months.monthWord),
                    String(format: "percentile.as_of_fmt".l, weighedOn.appDayMonth),
                ]
            )
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.measurement_history")

            if entries.isEmpty {
                // The subtitle already says "add your first measurement" and had
                // nothing to press — the same defect as the cards above, so it
                // gets the same button. `EmptyStateView` is shared by four
                // screens and stays untouched; the CTA is stacked under it here,
                // centred to match the card's own alignment.
                VStack(spacing: BBTheme.Spacing.md) {
                    EmptyStateView(
                        icon: "ruler.fill",
                        color: BBTheme.Colors.growth,
                        title: "empty.no_measurements",
                        subtitle: "empty.measurements_hint"
                    )
                    AddWeighingButton()
                }
            } else {
                VStack(spacing: BBTheme.Spacing.sm) {
                    ForEach(entries) { entry in
                        SwipeToDeleteRow(onDelete: { delete(entry) }) {
                            GrowthEntryRow(entry: entry)
                        }
                    }
                }
            }
        }
    }

    private func delete(_ entry: GrowthEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
        refreshGrowthNotifications(excluding: entry)
    }

    /// Re-derives every growth notification from the surviving data. Deleting the
    /// weighing that raised a flag has to take the flag down with it — this app
    /// already had a bug class where a reminder outlived the entry behind it.
    private func refreshGrowthNotifications(excluding removed: GrowthEntry? = nil) {
        guard let baby else { return }
        let surviving = entries.filter { $0.id != removed?.id }
        NotificationManager.shared.onGrowthDataChanged(
            baby: baby,
            entries: surviving,
            isPremium: store.isPremium
        )
    }
}

// MARK: - Weight Chart

/// The baby's weighings over an AGE axis, on the WHO corridor.
///
/// **The axis is age in days, not the index of the entry**, and that change is
/// what makes the band mean anything: the corridor is a function of age, so
/// points spaced by the order they were recorded would sit over the wrong part
/// of it. It also fixes the old chart's own distortion — three weighings in one
/// week and a fourth three months later used to be drawn evenly spaced.
///
/// The corridor itself comes from `WHOCorridor`, the same sampler onboarding's
/// showcase sketch draws, so the preview a parent is shown in their third
/// minute is a picture of this chart (DECISIONS 2026-09-21).
///
/// Free for everyone. The percentile card beside it is free, and the showcase
/// page shows this corridor to every parent before they have paid anything —
/// putting it behind the paywall afterwards would make that page a bait.
struct WeightChartView: View {
    /// Already through the engine's door (`[GrowthEntry].weightMeasurements`),
    /// oldest first: weight-bearing and not dated into the future, so the chart
    /// plots exactly what the cards below it score.
    let measurements: [WeightMeasurement]
    /// What the age axis and the corridor are measured from — corrected, so a
    /// preterm baby's points sit against the reference for the age it would be
    /// at term.
    let correctedBirthDate: Date
    let isMale: Bool
    /// WEIGHT-for-age only. Nothing else on this screen is plotted today, but a
    /// caller that ever reuses this shell for height or head circumference must
    /// pass `false`: those are different tables, and drawing a weight corridor
    /// under a length is not an approximation, it is the wrong standard.
    var showsWHOCorridor: Bool = true

    /// Chart geometry in DATA space, computed once per body rather than per
    /// point — `place` is called for every sample of three curves plus every
    /// weighing, and reading a computed property there made it quadratic.
    private struct Frame {
        let ageRange: ClosedRange<Int>
        let weightRange: ClosedRange<Double>
        let samples: [WHOCorridor.Sample]
    }

    /// The narrowest window the chart will draw. A single weighing — which is
    /// every fresh install that answered the measurements page — would
    /// otherwise be a zero-width axis; four weeks around it shows the point
    /// sitting in the corridor, which is the whole reason one point is now
    /// worth charting at all.
    private static let minimumSpanDays = 28
    private static let inset: CGFloat = 6

    private var points: [(ageDays: Int, kg: Double)] {
        measurements.map {
            (Calendar.current.dateComponents([.day], from: correctedBirthDate, to: $0.date).day ?? 0,
             $0.weightKg)
        }
    }

    private func frame(for points: [(ageDays: Int, kg: Double)]) -> Frame? {
        guard let first = points.first else { return nil }
        var low = points.reduce(first.ageDays) { min($0, $1.ageDays) }
        var high = points.reduce(first.ageDays) { max($0, $1.ageDays) }
        if high - low < Self.minimumSpanDays {
            // Centred on the data, then pulled back so the window never opens
            // empty space BEFORE the due date: no band can be drawn there and
            // no weighing sits there, so a fresh install's single birth point
            // would otherwise be pinned to the middle of a half-blank chart.
            // The floor is `min(low, 0)`, not 0 — a preterm baby's pre-due-date
            // weighings carry negative ages and must stay on the axis.
            let middle = (low + high) / 2
            low = max(middle - Self.minimumSpanDays / 2, min(low, 0))
            high = low + Self.minimumSpanDays
        }
        let samples = showsWHOCorridor
            ? WHOCorridor.samples(fromAgeDays: low, toAgeDays: high, isMale: isMale)
            : []

        // The y window spans the baby AND the band, so the corridor is never
        // clipped and the baby's own line keeps its shape inside it.
        var minKg = points.reduce(first.kg) { min($0, $1.kg) }
        var maxKg = points.reduce(first.kg) { max($0, $1.kg) }
        for sample in samples {
            minKg = min(minKg, sample.low)
            maxKg = max(maxKg, sample.high)
        }
        let pad = max((maxKg - minKg) * 0.08, 0.05)
        return Frame(ageRange: low...high,
                     weightRange: (minKg - pad)...(maxKg + pad),
                     samples: samples)
    }

    private func place(ageDays: Int, kg: Double, in frame: Frame, size: CGSize) -> CGPoint {
        let ageSpan = CGFloat(max(frame.ageRange.upperBound - frame.ageRange.lowerBound, 1))
        let kgSpan = max(frame.weightRange.upperBound - frame.weightRange.lowerBound, 0.01)
        let usableWidth = max(size.width - Self.inset * 2, 1)
        return CGPoint(
            x: Self.inset + CGFloat(ageDays - frame.ageRange.lowerBound) / ageSpan * usableWidth,
            // Heavier sits higher.
            y: size.height - CGFloat((kg - frame.weightRange.lowerBound) / kgSpan) * size.height
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            let points = points
            if let frame = frame(for: points) {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // Grid lines
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(BBTheme.Colors.primary.opacity(0.08))
                                .frame(height: 1)
                                .offset(y: -CGFloat(i) * geo.size.height / 3)
                        }

                        if !frame.samples.isEmpty {
                            corridor(frame, size: geo.size)
                                .fill(BBTheme.Colors.growth.opacity(0.16))
                            curve(frame.samples.map { ($0.ageDays, $0.mid) }, frame, size: geo.size)
                                .stroke(BBTheme.Colors.growth.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }

                        curve(points.map { ($0.ageDays, $0.kg) }, frame, size: geo.size)
                            .stroke(BBTheme.Colors.growth,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        ForEach(points.indices, id: \.self) { index in
                            let dot = place(ageDays: points[index].ageDays, kg: points[index].kg,
                                            in: frame, size: geo.size)
                            Circle()
                                .fill(BBTheme.Colors.growth)
                                .overlay(Circle().stroke(BBTheme.Colors.surface, lineWidth: 2))
                                .frame(width: 9, height: 9)
                                .position(x: dot.x, y: dot.y)
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, BBTheme.Spacing.sm)
                // Decoration: the cards below state every verdict this picture
                // hints at, and a path description helps nobody.
                .accessibilityHidden(true)

                if !frame.samples.isEmpty {
                    WHOCorridorLegend()
                }
            }

            // The baby's lightest and heaviest, not the axis bounds — the axis
            // now spans the corridor too.
            HStack {
                Text(String(format: "%.2f \("unit.kg".l)", points.map(\.kg).min() ?? 0))
                Spacer()
                Text(String(format: "%.2f \("unit.kg".l)", points.map(\.kg).max() ?? 0))
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    private func curve(_ values: [(Int, Double)], _ frame: Frame, size: CGSize) -> Path {
        var path = Path()
        for (index, value) in values.enumerated() {
            let point = place(ageDays: value.0, kg: value.1, in: frame, size: size)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// The 3rd–97th band as one closed shape: the 97th out, the 3rd back.
    private func corridor(_ frame: Frame, size: CGSize) -> Path {
        var path = curve(frame.samples.map { ($0.ageDays, $0.high) }, frame, size: size)
        for sample in frame.samples.reversed() {
            path.addLine(to: place(ageDays: sample.ageDays, kg: sample.low, in: frame, size: size))
        }
        path.closeSubpath()
        return path
    }
}

/// One wording for the band, wherever it is drawn. The showcase page carries
/// the identical line, so the parent meets the same sentence twice.
struct WHOCorridorLegend: View {
    var body: some View {
        HStack(spacing: BBTheme.Spacing.xs) {
            RoundedRectangle(cornerRadius: 2)
                .fill(BBTheme.Colors.growth.opacity(0.28))
                .frame(width: 16, height: 8)
            Text("chart.who_corridor".l)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Growth Entry Row
struct GrowthEntryRow: View {
    let entry: GrowthEntry

    var body: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BBTheme.Colors.growth.opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BBTheme.Colors.growth)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: BBTheme.Spacing.md) {
                    if let w = entry.weightKg {
                        Label(String(format: "%.2f \("unit.kg".l)", w), systemImage: "scalemass")
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    }
                    if let h = entry.heightCm {
                        Label(String(format: "%.0f \("unit.cm".l)", h), systemImage: "ruler")
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .semibold, design: .rounded))
                    }
                }
                .foregroundStyle(BBTheme.Colors.textPrimary)

                if let head = entry.headCircumferenceCm {
                    Label(String(format: "growth.head_fmt".l, head), systemImage: "circle.dotted")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }

            Spacer()

            Text(entry.date.appDayMonth)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.md)
        .bbShadow(BBTheme.Shadow.card)
    }
}

// MARK: - Add Growth Sheet
struct AddGrowthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.reviewPrompt) private var reviewPrompt
    @Query(sort: \GrowthEntry.date, order: .reverse) private var growthEntries: [GrowthEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(SubscriptionManager.self) private var store
    @State private var weightKg: Double = 3.5
    @State private var heightCm: Double = 50.0
    @State private var headCm: Double = 34.0
    @State private var includeHead: Bool = false
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(BBTheme.Colors.growth)

                    BBMeasureSlider(
                        title: "form.weight_kg".l,
                        value: $weightKg,
                        range: 1.0...20.0, step: 0.1,
                        display: String(format: "%.1f \("unit.kg".l)", weightKg),
                        color: BBTheme.Colors.growth,
                        minLabel: "1 \("unit.kg".l)",
                        maxLabel: "20 \("unit.kg".l)"
                    )

                    BBMeasureSlider(
                        title: "form.height_cm".l,
                        value: $heightCm,
                        range: 30.0...130.0, step: 0.5,
                        display: String(format: "%.0f \("unit.cm".l)", heightCm),
                        color: BBTheme.Colors.primary,
                        minLabel: "30 \("unit.cm".l)",
                        maxLabel: "130 \("unit.cm".l)"
                    )

                    BBOptionalMeasureToggle(
                        title: "form.head_cm".l,
                        hint: "form.head_optional_hint".l,
                        isOn: $includeHead,
                        value: $headCm,
                        range: 25.0...55.0, step: 0.5,
                        display: String(format: "%.1f \("unit.cm".l)", headCm),
                        minLabel: "25 \("unit.cm".l)",
                        maxLabel: "55 \("unit.cm".l)",
                        color: BBTheme.Colors.accent
                    )

                    DatePicker("form.measurement_date".l, selection: $date,
                               in: dateRange, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                }
                .padding(BBTheme.Spacing.md)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("sheet.new_measurement".l)
            .navigationBarTitleDisplayMode(.inline)
            // A selection outside the picker's range renders as an empty field
            // and cannot be corrected by tapping it, so the seed is clamped
            // before it is ever shown rather than trusted to be in range.
            .onAppear {
                let range = dateRange
                date = min(max(date, range.lowerBound), range.upperBound)
                // The sheet opens on the baby's current numbers, not a newborn's:
                // a 6 kg baby offered the 3.5 kg default starts every weighing
                // with a long drag across the slider. Each field seeds from the
                // newest entry that actually has it — a height-only measurement
                // must not reset the weight back to factory. Clamped for the
                // same reason as the date above: a value outside the slider's
                // range must never be the value the slider shows.
                if let w = growthEntries.first(where: { $0.weightKg != nil })?.weightKg {
                    weightKg = min(max(w, 1.0), 20.0)
                }
                if let h = growthEntries.first(where: { $0.heightCm != nil })?.heightCm {
                    heightCm = min(max(h, 30.0), 130.0)
                }
                if let hc = growthEntries.first(where: { $0.headCircumferenceCm != nil })?.headCircumferenceCm {
                    headCm = min(max(hc, 25.0), 55.0)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }

    /// Birth to today. A weighing dated into the future is not a typo the app
    /// can absorb: it lands at the end of the history and becomes the newest
    /// half of every pair, so the gain, the nutrition window and the trend all
    /// describe an interval that has not happened yet — the build-13 report was
    /// a September-17 weighing entered in September, which took the gain card
    /// down to its "two measurements needed" hint.
    ///
    /// `min` against today keeps a birth date that has somehow drifted past it —
    /// clock skew, a synced row from a device set wrong — from forming an
    /// inverted range, which traps at runtime rather than misbehaving.
    private var dateRange: ClosedRange<Date> {
        let now = Date()
        let lower = babies.first.map { min($0.birthDate, now) } ?? .distantPast
        return lower...now
    }

    private func save() {
        let isFirst = growthEntries.isEmpty
        let entry = GrowthEntry(
            date: date,
            weightKg: weightKg,
            heightCm: heightCm,
            headCircumferenceCm: includeHead ? headCm : nil
        )
        entry.baby = babies.first
        modelContext.insert(entry)
        try? modelContext.save()
        if isFirst {
            NotificationManager.shared.onFirstGrowthEntrySaved()
        }
        if let baby = babies.first {
            // The @Query has not necessarily seen the insert yet, so the new
            // entry is passed in explicitly rather than waited for.
            NotificationManager.shared.onGrowthDataChanged(
                baby: baby,
                entries: growthEntries + [entry],
                isPremium: store.isPremium
            )
        }
        reviewPrompt.entrySaved()
        dismiss()
    }
}

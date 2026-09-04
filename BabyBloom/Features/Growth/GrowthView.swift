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
    @State private var showPercentileInfo = false
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
                    NewbornProgressCard(status: status)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }

                // Weight chart
                if entries.count >= 2 {
                    chartSection
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
        .sheet(isPresented: $showAddSheet) {
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
                BBStatCard(
                    title: "stat.weight",
                    value: latest.flatMap { $0.weightKg.map { String(format: "%.2f", $0) } } ?? "—",
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
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.weight_chart")
            WeightChartView(entries: Array(entries.reversed()))
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
        } else {
            PercentileOutOfRangeCard()
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

    /// Premium. The number itself stays hidden for free users — the teaser says
    /// what it would tell them, which is honest without giving it away.
    @ViewBuilder
    private func weightGainSection(_ baby: Baby) -> some View {
        if store.isPremium {
            WeightGainCard(reading: WeightVelocity.latest(
                measurements: measurements,
                correctedBirthDate: baby.correctedBirthDate,
                isMale: baby.gender == .male
            ))
        } else {
            LockedInsightCard(
                title: "section.weight_gain".l,
                teaser: "premium.teaser_gain".l
            ) { showPaywall = true }
        }
    }

    /// Premium, same reasoning as the gain card.
    @ViewBuilder
    private func trendSection(_ baby: Baby) -> some View {
        if store.isPremium {
            CentileTrendCard(assessment: GrowthTrend.assess(
                measurements: measurements,
                correctedBirthDate: baby.correctedBirthDate,
                isMale: baby.gender == .male,
                birthPercentile: birthPercentile(baby)
            ))
        } else {
            LockedInsightCard(
                title: "section.trend".l,
                teaser: "premium.teaser_trend".l
            ) { showPaywall = true }
        }
    }

    /// Built from the same queries the rest of the screen uses, filtered in
    /// memory — the window is weeks, not years.
    private func adequacy(_ baby: Baby) -> FeedingAdequacy.Assessment? {
        FeedingAdequacy.assess(
            birthDate: baby.birthDate,
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
            NutritionSection(assessment: assessment, band: reading?.band)
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

    /// The WHOLE card opens the explainer, not just the "?" glyph.
    ///
    /// A 20pt badge in the corner was the only way in, and the owner reported
    /// tapping the card and getting nothing (build-11 review). The badge stays
    /// as the AFFORDANCE — it is what tells a reader the explanation exists —
    /// but it is no longer a control of its own: a button inside a button gives
    /// two hit targets that do the same thing and one VoiceOver stop too many.
    private func percentileCard(percentile: Double, badge: String,
                                months: Int, weighedOn: Date) -> some View {
        let label = WHOGrowthStandard.percentileLabel(percentile)
        let color = Color(hex: WHOGrowthStandard.percentileColor(percentile))

        return Button {
            showPercentileInfo = true
        } label: {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            HStack {
                BBTheme.Typography.title3("section.who_percentiles".l)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(BBTheme.Colors.primary.opacity(0.7))
            }

            VStack(spacing: BBTheme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("percentile.weight".l)
                            .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                        BBTheme.Typography.metric(label)
                            .foregroundStyle(color)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 6)
                            .frame(width: 64, height: 64)
                        Circle()
                            .trim(from: 0, to: percentile / 100)
                            .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))
                        Text(badge)
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(color)
                    }
                }

                // Both lines describe the WEIGHING. The age is the one the
                // figure was scored at, and the date says which weighing that
                // was — without it "1 month old" reads as a claim about today
                // when the last entry is three weeks back.
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "percentile.by_who_fmt".l, months, months.monthWord))
                    Text(String(format: "percentile.as_of_fmt".l, weighedOn.appDayMonth))
                }
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.card)
            }
            // The header's Spacer is empty space, and empty space in a Button's
            // label is not hittable without this.
            .contentShape(Rectangle())
        }
        .buttonStyle(BBScaleButtonStyle())
        // The card reads out as one control. Without the hint VoiceOver
        // announces a wall of figures and then "Button", with nothing saying
        // what the button does.
        .accessibilityHint(Text("percentile.info_hint".l))
        .sheet(isPresented: $showPercentileInfo) {
            PercentileInfoSheet()
        }
    }

    // MARK: - History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.measurement_history")

            if entries.isEmpty {
                EmptyStateView(
                    icon: "ruler.fill",
                    color: BBTheme.Colors.growth,
                    title: "empty.no_measurements",
                    subtitle: "empty.measurements_hint"
                )
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
struct WeightChartView: View {
    let entries: [GrowthEntry]

    private var weights: [Double] {
        entries.compactMap { $0.weightKg }
    }

    private var minWeight: Double { weights.min() ?? 0 }
    private var maxWeight: Double { weights.max() ?? 1 }

    var body: some View {
        VStack {
            if weights.count >= 2 {
                GeometryReader { geo in
                    ZStack(alignment: .bottomLeading) {
                        // Grid lines
                        ForEach(0..<4) { i in
                            Rectangle()
                                .fill(BBTheme.Colors.primary.opacity(0.08))
                                .frame(height: 1)
                                .offset(y: -CGFloat(i) * geo.size.height / 3)
                        }

                        // Line
                        Path { path in
                            for (index, weight) in weights.enumerated() {
                                let x = CGFloat(index) / CGFloat(weights.count - 1) * geo.size.width
                                let normalised = (weight - minWeight) / max(maxWeight - minWeight, 0.01)
                                let y = geo.size.height - (normalised * geo.size.height * 0.8 + geo.size.height * 0.1)
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(BBTheme.Colors.growth, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        // Dots
                        ForEach(weights.indices, id: \.self) { index in
                            let x = CGFloat(index) / CGFloat(weights.count - 1) * geo.size.width
                            let normalised = (weights[index] - minWeight) / max(maxWeight - minWeight, 0.01)
                            let y = geo.size.height - (normalised * geo.size.height * 0.8 + geo.size.height * 0.1)
                            Circle()
                                .fill(BBTheme.Colors.growth)
                                .frame(width: 8, height: 8)
                                .offset(x: x - 4, y: y - 4)
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, BBTheme.Spacing.sm)
            }

            // Labels
            HStack {
                Text(String(format: "%.2f \("unit.kg".l)", minWeight))
                Spacer()
                Text(String(format: "%.2f \("unit.kg".l)", maxWeight))
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textSecondary)
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
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

// MARK: - Percentile Info Sheet
struct PercentileInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.lg) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 56))
                        .foregroundStyle(BBTheme.Colors.growth)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, BBTheme.Spacing.lg)

                    BBTheme.Typography.title2("percentile.info_title".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)

                    Text("percentile.info_body".l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                        .lineSpacing(4)

                    Spacer()
                }
                .padding(BBTheme.Spacing.lg)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.close".l) { dismiss() }
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Add Growth Sheet
struct AddGrowthSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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

                    DatePicker("form.measurement_date".l, selection: $date, displayedComponents: .date)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel".l) { dismiss() }.foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
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
        dismiss()
    }
}

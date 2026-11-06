import SwiftUI
import SwiftData

struct DashboardView: View {
    /// The tab selection, owned by MainTabView. The active-timer cards use it
    /// to jump to the screen that owns the timer — a card that shows a running
    /// timer but cannot take you to it reads as broken.
    @Binding var selectedTab: MainTabView.Tab

    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \SleepEntry.startTime, order: .reverse) private var sleeps: [SleepEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]
    @Query(sort: \GrowthEntry.date, order: .reverse) private var growthEntries: [GrowthEntry]
    /// Only for the weekly card's "days with entries": an event day counts.
    @Query private var events: [CustomEvent]

    @State private var showQuickFeedingSheet = false
    @State private var showQuickSleepSheet = false
    @State private var showQuickDiaperSheet = false
    @State private var showQuickEventSheet = false
    @State private var showQuickGrowthSheet = false
    @State private var showProfileEdit = false
    /// Which gate opened the paywall — the events quick action or the locked
    /// Growth teaser — so the sheet can report its source.
    @State private var paywallSource: AnalyticsEvent.PaywallSource?
    /// Drives the Growth push. A `@State` + `navigationDestination` rather than
    /// a `NavigationLink`, because the link is a Button — see `growthSection`.
    @State private var showGrowth = false

    /// Honours `-BBForcePremium`, so the paid half of the Growth section is
    /// reachable in e2e without a purchase (see the platform-run skill).
    @Environment(SubscriptionManager.self) private var store

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var baby: Baby? { babies.first }

    private var todayFeedings: [FeedingEntry] {
        feedings.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var todaySleeps: [SleepEntry] {
        sleeps.filter { Calendar.current.isDateInToday($0.startTime) }
    }

    private var todayDiapers: [DiaperEntry] {
        diapers.filter { Calendar.current.isDateInToday($0.time) }
    }

    private var totalSleepToday: Double {
        todaySleeps.filter { !$0.isActive }.reduce(0) { $0 + $1.duration / 3600 }
    }

    /// Free for everyone. `AppClock` so a test run can stand on any week.
    private var weeklySummary: WeeklySummary? {
        guard let baby else { return nil }
        return WeeklySummary.make(
            now: AppClock.now,
            input: WeeklySummary.Input(baby: baby, feeds: feedings, sleeps: sleeps, diapers: diapers,
                                       growth: growthEntries, events: events))
    }

    private var activeFeeding: FeedingEntry? {
        feedings.first(where: { $0.isActive })
    }

    private var activeSleep: SleepEntry? {
        sleeps.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.xl) {
                    headerSection
                    if activeFeeding != nil || activeSleep != nil {
                        activeTimersSection
                    }
                    // Under the timers, above last week.
                    MedicationHomeSection()
                    // Under the timers: a running timer outranks last week at
                    // 3 a.m. nil = nothing logged last week.
                    if let weeklySummary {
                        WeeklySummaryCard(summary: weeklySummary,
                                          onAddWeighing: { showQuickGrowthSheet = true })
                    }
                    quickActionsSection
                    statsSection
                    growthSection
                    progressSection
                }
                .padding(.horizontal, BBTheme.Spacing.md)
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
            // No navigation bar here, so nothing backs the status bar: scrolled
            // text drew under the clock. A strip as tall as the top
            // inset, shifted up by it, covers exactly that band (a zero-height
            // strip with ignoresSafeArea did not, live).
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    BBTheme.Colors.background
                        .frame(height: proxy.safeAreaInsets.top)
                        .offset(y: -proxy.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
            }
            .navigationBarHidden(true)
        }
        // `entrySheet`: a save inside any of these asks for the review prompt
        // only once the sheet is gone (see `ReviewPromptTrigger`).
        .entrySheet(isPresented: $showQuickFeedingSheet) { FeedingQuickSheet() }
        .entrySheet(isPresented: $showQuickSleepSheet)   { SleepQuickSheet() }
        .entrySheet(isPresented: $showQuickDiaperSheet)  { DiaperQuickSheet() }
        .entrySheet(isPresented: $showQuickEventSheet)   { AddEventSheet() }
        .entrySheet(isPresented: $showQuickGrowthSheet)  { AddGrowthSheet() }
        .sheet(item: $paywallSource) { PaywallView(source: $0) }
        .sheet(isPresented: $showProfileEdit) {
            if let baby {
                BabyProfileEditSheet(baby: baby)
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("dashboard.welcome".l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                if let baby {
                    BBTheme.Typography.title1(baby.name)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(baby.ageDescription)
                        .font(BBTheme.Typography.scaled(14, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(BBTheme.Colors.primary.opacity(0.1))
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.pill)
                } else {
                    BBTheme.Typography.title1("brand.name".l)
                        .foregroundStyle(BBTheme.Colors.primary)
                }
            }
            Spacer()
            // Without a baby there is nothing to edit, so show no control at all
            // rather than an avatar that silently ignores taps.
            if let baby {
                Button {
                    showProfileEdit = true
                } label: {
                    BabyAvatarView(photoData: baby.photoData,
                                   gender: baby.gender,
                                   size: 52)
                        .overlay(Circle().stroke(BBTheme.Colors.primary.opacity(0.15), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("nav.profile".l))
            }
        }
        .padding(.top, BBTheme.Spacing.md)
    }

    // MARK: - Active Timers
    private var activeTimersSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            if let feeding = activeFeeding {
                ActiveTimerCard(
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    title: "status.feeding_going".l,
                    subtitle: feeding.displayTitle,
                    startTime: feeding.startTime
                ) { selectedTab = .feeding }
            }
            if let sleep = activeSleep {
                ActiveTimerCard(
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    title: "status.baby_sleeping".l,
                    subtitle: sleep.type.displayName.l,
                    startTime: sleep.startTime,
                    // As the Sleep screen it opens reads it: «01:41:02», not «101:02».
                    showsHours: true
                ) { selectedTab = .sleep }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.quick_input")
            // One at accessibility sizes whatever fits: one shape at the
            // largest text, as the running cards above keep. Two would hold
            // ru «Подгузники» there by 5.9 pt, and not with Bold Text.
            QuickActionsLayout(counts: dynamicTypeSize.isAccessibilitySize ? [1] : [4, 2],
                               rowSpacing: BBTheme.Spacing.md) {
                BBQuickActionButton(icon: "heart.fill",      title: "tab.feeding".l, color: BBTheme.Colors.feeding) { showQuickFeedingSheet = true }
                BBQuickActionButton(icon: "moon.fill",       title: "tab.sleep".l,   color: BBTheme.Colors.sleep)   { showQuickSleepSheet = true }
                BBQuickActionButton(icon: "drop.fill",       title: "nav.diapers".l, color: BBTheme.Colors.diaper)  { showQuickDiaperSheet = true }
                // Creating an event is Premium; the padlock says so before the
                // tap. Viewing, editing and DELETING what is already recorded
                // stays free — recorded data is never held hostage.
                BBQuickActionButton(icon: "plus.circle.fill", title: "nav.events".l, color: BBTheme.Colors.events,
                                    locked: !store.isPremium) {
                    if store.isPremium { showQuickEventSheet = true } else { paywallSource = .events }
                }
            }
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.card)
        }
    }

    // MARK: - Stats Grid
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            BBSectionHeader(title: "section.today")
            BBStatGrid {
                BBStatCard(
                    title: "stat.feedings",
                    value: "\(todayFeedings.count)",
                    icon: "heart.fill",
                    color: BBTheme.Colors.feeding,
                    trend: lastFeedingText,
                    action: { showQuickFeedingSheet = true }
                )
                BBStatCard(
                    title: "stat.sleep",
                    // Back to whole seconds first: hours summed as a Double
                    // can land a hair under a whole minute.
                    value: DurationText.minutes(Int((totalSleepToday * 3600).rounded()) / 60),
                    icon: "moon.fill",
                    color: BBTheme.Colors.sleep,
                    action: { showQuickSleepSheet = true }
                )
                BBStatCard(
                    title: "stat.diapers",
                    value: "\(todayDiapers.count)",
                    icon: "drop.fill",
                    color: BBTheme.Colors.diaper,
                    action: { showQuickDiaperSheet = true }
                )
                // The newest WEIGHING, not the newest entry: a height-only entry
                // recorded today used to coalesce its nil weight into "0.00 kg".
                if let weightKg = latestWeighing?.weightKg {
                    BBStatCard(
                        title: "stat.weight",
                        value: weightKg.appDecimal(2),
                        unit: "unit.kg",
                        icon: "scalemass.fill",
                        color: BBTheme.Colors.growth,
                        action: { showQuickGrowthSheet = true }
                    )
                } else {
                    BBStatCard(
                        title: "tab.growth",
                        value: "—",
                        unit: "",
                        icon: "chart.line.uptrend.xyaxis",
                        color: BBTheme.Colors.growth,
                        action: { showQuickGrowthSheet = true }
                    )
                }
            }
        }
    }

    private var lastFeedingText: String? {
        guard let last = feedings.first else { return nil }
        return ReportFormat.ago(from: last.startTime, to: AppClock.now)
    }

    // MARK: - Growth

    /// The free half is deliberately word-shaped. The Growth screen's rule
    /// holds here too: weight gain is the only signal that speaks, and it
    /// speaks in `FeedingAdequacy`'s vocabulary, never in a number that alarms
    /// (DECISIONS 2026-08-25). Which of the free states applies is decided by
    /// `DashboardGrowthSummary`, where the rule is unit-tested.
    private var growthSection: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            // Header AND card are one tap target: the chevron promised a
            // destination that the data under it did not deliver, and a card
            // showing "two weighings needed" is exactly where a parent taps to
            // go and add one.
            //
            // A gesture, NOT a `NavigationLink` — the same trade `ExplainerCard`
            // documents, for the same reason. A link is a Button, and a Button
            // flattens its label into ONE accessibility element, which would
            // destroy the per-row structure `GrowthSummaryRow` builds on purpose
            // (label and value read as one statement, one stop per row — the rule
            // DECISIONS 2026-09-05 "One explainer pattern" records for
            // `NutritionSection`, which this card copies). The way in without
            // sight is the named action on the header title, which is an element
            // with certainty; nothing is attached to this container, because a
            // container is not an accessibility element.
            VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
                HStack {
                    BBTheme.Typography.title3("dashboard.growth.title".l)
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                        .accessibilityActions {
                            Button("dashboard.growth.open".l) { showGrowth = true }
                        }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BBTheme.Colors.textSecondary.opacity(0.4))
                        // Decoration: the named action above is the reachable
                        // way in, and an unlabelled glyph announces nothing.
                        .accessibilityHidden(true)
                }
                growthCard
            }
            // A header row's Spacer is empty space, and empty space does not
            // answer taps without this.
            .contentShape(Rectangle())
            .onTapGesture { showGrowth = true }
            .navigationDestination(isPresented: $showGrowth) { GrowthView() }

            // A permanent teaser, not a free-first-days window: a section that
            // vanished after two days would read as breakage, in the one domain
            // where the app must never frighten (DECISIONS 2026-09-01).
            if !store.isPremium {
                LockedInsightCard(
                    title: "dashboard.growth.locked_title".l,
                    teaser: "dashboard.growth.locked_teaser".l
                ) { paywallSource = .lockedCard }
            }
        }
    }

    private var growthCard: some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            switch growthSummary {
            case .invitation:
                // An invitation, not an empty state — the widget's rule. A
                // parent who has not weighed yet is doing nothing wrong.
                HintText(text: "dashboard.growth.empty".l)
            case let .summary(weightKg, gain):
                summary(weightKg: weightKg, gain: gain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    /// All the card's rows beside, or all under: one shape for the card, so the
    /// values do not jump between the right edge and the margin row to row.
    /// Under at every accessibility size; below them beside only where every
    /// word of every row keeps whole beside (`GrowthSummaryRow`).
    @ViewBuilder
    private func summary(weightKg: Double, gain: DashboardGrowthSummary.Gain) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            summaryRows(weightKg: weightKg, gain: gain, beside: false)
        } else {
            ViewThatFits(in: .horizontal) {
                summaryRows(weightKg: weightKg, gain: gain, beside: true)
                summaryRows(weightKg: weightKg, gain: gain, beside: false)
            }
        }
    }

    private func summaryRows(weightKg: Double, gain: DashboardGrowthSummary.Gain, beside: Bool) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            GrowthSummaryRow(label: "stat.weight".l, value: ReportFormat.kg(weightKg), beside: beside)
            gainRow(gain, beside: beside)
            if store.isPremium, let reading = latestPercentile {
                // `rowText` already rounds, clamps and — past the chart's
                // edge — drops the fake-precise number for the tail in
                // words, the same claim the Growth screen's figure makes
                // about the same weighing.
                GrowthSummaryRow(label: "percentile.weight".l,
                                 value: reading.rowText(format: "dashboard.growth.percentile_fmt".l),
                                 beside: beside)
            }
        }
    }

    @ViewBuilder
    private func gainRow(_ gain: DashboardGrowthSummary.Gain, beside: Bool) -> some View {
        switch gain {
        case .word(let word):
            GrowthSummaryRow(label: "nutrition.row_gain".l, value: gainValue(word),
                             ink: word.ink, dot: word.dot, beside: beside)
        case .needsAnotherWeighing:
            // Prose wraps between its words at any width, so its one line must
            // not count against the rows beside: the ideal width 0 leaves the
            // card's shape to the rows.
            HintText(text: "nutrition.need_weighing".l)
                .frame(idealWidth: 0, maxWidth: .infinity, alignment: .leading)
        case .unavailable:
            // Past the age the gain reference covers the section says nothing
            // about gain. "Not enough data" would be untrue.
            EmptyView()
        }
    }

    /// Premium prepends the figure to the same word the free line already
    /// shows, rather than replacing it: one vocabulary across the app, and the
    /// paid half reads as an addition instead of a different verdict.
    private func gainValue(_ word: StatusWord) -> String {
        let status = word.localizationKey.l
        // During the newborn window the figure is withheld from the paid line
        // too. The deferral says this reading is not the one to read yet;
        // printing the grams beside it would hand back exactly the number the
        // gate exists to keep out of a parent's hands this fortnight.
        guard word != .firstWeeks else { return status }
        guard store.isPremium, let reading = gainReading else { return status }
        let grams = Int(reading.gramsPerWeek.rounded())
        let signed = grams > 0 ? "+\(grams)" : "\(grams)"
        return String(format: "velocity.per_week_fmt".l, signed) + " · " + status
    }

    // MARK: - Growth derivations

    private var growthSummary: DashboardGrowthSummary.Free {
        DashboardGrowthSummary.free(
            latestWeightKg: latestWeightKg,
            assessment: adequacy,
            band: gainReading?.band,
            withinReferenceAge: (baby?.correctedAgeDays ?? 0) <= FeedingAdequacy.maxAgeDays
        )
    }

    /// The newest entry that actually carries a weight — a height-only entry
    /// is more recent but says nothing about weight.
    private var latestWeighing: WeightMeasurement? {
        growthEntries.latestWeighing
    }

    private var latestWeightKg: Double? { latestWeighing?.weightKg }

    /// Built exactly as `GrowthView` builds it, from the queries this screen
    /// already holds; the window is weeks, so filtering in memory is free.
    private var adequacy: FeedingAdequacy.Assessment? {
        guard let baby else { return nil }
        return FeedingAdequacy.assess(
            birthDate: baby.birthDate,
            birthWeightKg: baby.birthWeightKg,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male,
            measurements: growthEntries.weightMeasurements,
            feeds: feedings.map { FeedingAdequacy.Feed(date: $0.startTime, type: $0.type) },
            wetNappies: diapers.filter { $0.type == .wet || $0.type == .both }.map(\.time)
        )
    }

    private var gainReading: WeightVelocity.Reading? {
        guard let baby else { return nil }
        return WeightVelocity.latest(
            measurements: growthEntries.weightMeasurements,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male
        )
    }

    /// Corrected age at the WEIGHING, not chronological age today — the same
    /// rule, and now the same call, the Growth screen's percentile card uses.
    private var latestPercentile: WHOGrowthStandard.PercentileReading? {
        guard let baby, let weighing = latestWeighing else { return nil }
        return WHOGrowthStandard.percentileReading(
            of: weighing,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male
        )
    }

    // MARK: - Progress

    /// Targets come from the reference tables `FeedingAdequacy` already
    /// publishes, on CORRECTED age.
    ///
    /// They used to be inline literals read off chronological age — 10 feeds
    /// where the sourced band is 8–12 breast / 6–8 formula, 8 nappies where the
    /// sourced minimum is 6 — so the same screen could show a ring two thirds
    /// full above a Growth line saying the counts were within their reference.
    /// One table, one answer.
    private var progressSection: some View {
        VStack(spacing: BBTheme.Spacing.sm) {
            BBProgressCard(title: "tab.feeding", current: Double(todayFeedings.count), target: feedingTarget, color: BBTheme.Colors.feeding, icon: "heart.fill")
            BBProgressCard(title: "tab.sleep",   current: totalSleepToday, target: sleepTarget, unit: "unit.h", color: BBTheme.Colors.sleep, icon: "moon.fill")
            BBProgressCard(title: "progress.wet_nappies", current: Double(todayWetNappies), target: wetNappyTarget, color: BBTheme.Colors.diaper, icon: "drop.fill")
        }
    }

    /// The MIDPOINT of the feeding band; the nappy ring below takes its FLOOR.
    ///
    /// Not an inconsistency — the two tables are different shapes. The feeding
    /// reference is a band describing a normal day, and its lower bound is the
    /// edge below which `FeedingAdequacy` starts calling the count low; a ring
    /// filling there would read as "eight is all this baby needs", which none of
    /// the cited sources say. The nappy reference is a published minimum with no
    /// ceiling at all, so its floor IS the target and there is no midpoint to
    /// take.
    private var feedingTarget: Double {
        // `feedingBand`, not `feedingReference`: past six months the reference
        // stops applying, because feed frequency says little once solids start.
        // A ring is a daily nudge and no verdict reads it, so it keeps the last
        // row rather than vanishing — which is exactly the distinction the band
        // accessor exists for, and it leaves no unreachable branch here.
        let ageDays = min(baby?.correctedAgeDays ?? 0, FeedingAdequacy.maxAgeDays)
        let band = FeedingAdequacy.feedingBand(correctedAgeDays: ageDays, style: feedingStyle)
        return ((band.lowerBound + band.upperBound) / 2).rounded()
    }

    /// Derived from a BOUNDED RECENT window, not from today's entries and not
    /// from the lifetime log.
    ///
    /// Today's log is empty at breakfast and dominated by whatever happened
    /// since, so a style read off it flips as the day goes on — and with it the
    /// ring's denominator, which was observed swinging 9 → 10 → 7 between
    /// glances. The lifetime log has the opposite fault: a baby weaned onto
    /// bottles last month is still mostly breastfeeds by volume, and the ring
    /// would keep answering with a style the baby has left behind.
    ///
    /// So it takes the same window the Growth screen's answer is built on —
    /// `FeedingAdequacy.assess` derives its style from the feeds inside
    /// `window(for:)`, over the pair of weighings the gain is measured from
    /// (`WeightVelocity.pair(in:)`, which walks back past a tail too short to
    /// measure) — and the two surfaces agree by construction, through the same
    /// function rather than through two copies of one rule. Agreement is the
    /// point, not freshness: that window is as old as the pair it spans, so for
    /// a rarely-weighed baby it can be months behind. A ring that lagged
    /// differently from the section it sits under would be worse than one that
    /// lags with it. Before there are two weighings there is no such window,
    /// and a fortnight stands in — long enough to survive a quiet morning.
    private var feedingStyle: FeedingAdequacy.FeedingStyle {
        let fallback = DateInterval(start: Date().addingTimeInterval(-14 * 86_400), end: Date())
        let window = FeedingAdequacy.window(for: growthEntries.weightMeasurements) ?? fallback
        return FeedingAdequacy.style(of: feedings
            .filter { window.contains($0.startTime) }
            .map { FeedingAdequacy.Feed(date: $0.startTime, type: $0.type) })
    }

    /// Wet nappies, against the wet-nappy minimum — the reference is about wet
    /// nappies specifically, so counting every nappy against it would compare
    /// two different things and always flatter the total.
    ///
    /// **This ring and `DiaperView`'s norm card answer different questions and
    /// must not be "unified".** This one is wet nappies against a published
    /// clinical floor; that one is every nappy against a target the parent set
    /// themselves in the norm editor. Making either read the other's number
    /// would put a figure under a label that does not describe it.
    private var todayWetNappies: Int {
        todayDiapers.filter { $0.type == .wet || $0.type == .both }.count
    }

    /// POSTNATAL days, not corrected: the first-week ramp follows the birth,
    /// which is the rule `FeedingAdequacy` states for this table.
    private var wetNappyTarget: Double {
        guard let baby else { return FeedingAdequacy.wetNappyMinimum(postnatalDays: 0) }
        let postnatalDays = Calendar.current.dateComponents([.day], from: baby.birthDate, to: Date()).day ?? 0
        return FeedingAdequacy.wetNappyMinimum(postnatalDays: postnatalDays)
    }

    /// Still a literal, and deliberately marked as one: the app carries no
    /// sourced sleep-duration table, and inventing a reference to match the two
    /// beside it would be worse than admitting this one is a rule of thumb.
    /// The figures follow the usual AAP/NSF ranges for total sleep in 24 hours.
    ///
    /// CORRECTED age, changed with its neighbours: every reference in
    /// `Core/Growth` reads corrected age, and a preterm baby measured on
    /// chronological age is held to the wrong row of every table on this screen.
    /// A rule of thumb is no reason to keep the one age convention that differs.
    private var sleepTarget: Double {
        let ageMonths = baby?.correctedAgeMonths ?? 0
        return ageMonths < 1 ? 16 : (ageMonths < 3 ? 15 : 14)
    }
}

/// One line of Home's growth card: the label, and its value with the tier dot
/// when it is a verdict (`StatusWord`'s colours, as the Growth tab draws them).
///
/// Squeezed beside its label, either text can be proposed a width narrower
/// than its own longest word, and SwiftUI answers that by breaking INSIDE the
/// word — the defect `NutritionSection` documents. Same two layouts, same
/// reason: the card stands its rows beside only where every word keeps whole
/// (`SideBySideIdeal`), else the value goes under its label.
struct GrowthSummaryRow: View {
    let label: String
    let value: String
    var ink: Color = BBTheme.Colors.textPrimary
    var dot: Color?
    let beside: Bool

    var body: some View {
        if beside {
            // The hidden copies measure the two texts in their own fonts: whole,
            // and one word a line. With no icon column the stack's chrome is its
            // two gaps and the spacer's least length.
            SideBySideIdeal(chrome: 3 * BBTheme.Spacing.sm) {
                Group {
                    labelText(label)
                    labelText(label.oneWordALine)
                    valueText(value)
                        .multilineTextAlignment(.trailing)
                    valueText(value.oneWordALine)
                }
                .hidden()
                .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
                    labelText(label)
                    Spacer(minLength: BBTheme.Spacing.sm)
                    valueText(value)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        } else {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.xs) {
                labelText(label)
                valueText(value)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func labelText(_ text: String) -> some View {
        Text(text)
            .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func valueText(_ text: String) -> some View {
        BBTierValue(text: text, dot: dot, ink: ink, size: 13, style: .caption1)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Active Timer Card
struct ActiveTimerCard: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let startTime: Date
    /// Hours past an hour (sleep), else minutes past 59 (feeding).
    var showsHours: Bool = false
    /// Where the card takes you — the screen that owns this timer.
    let onTap: () -> Void

    var body: some View {
        // Same shape as BBStatCard: whole card is the hit target, contentShape
        // guarantees the full frame is hittable, and the shared scale style
        // gives the press the same haptic-and-shrink every other card has.
        Button(action: onTap) {
            cardContent
        }
        .contentShape(Rectangle())
        .buttonStyle(BBScaleButtonStyle())
    }

    private var cardContent: some View {
        HStack(spacing: BBTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.22))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            // The text beside the timer while both fit one line, else
            // above it. On a 320-pt screen at Large that is above at any
            // time; beside three-digit minutes ru «Кормление» broke there.
            BBTimerFit(startTime: startTime,
                       showsHours: showsHours,
                       font: BBTheme.Typography.scaled(22, relativeTo: .title2, weight: .semibold, design: .rounded).monospacedDigit(),
                       spacing: BBTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .semibold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(BBTheme.Typography.scaled(13, relativeTo: .body, weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
            }
        }
        .padding(BBTheme.Spacing.md)
        .background(color.opacity(0.08))
        .cornerRadius(BBTheme.Radius.md)
        .overlay(RoundedRectangle(cornerRadius: BBTheme.Radius.md).stroke(color.opacity(0.3), lineWidth: 1.5))
    }
}

// MARK: - Quick Actions Layout
/// Home's quick actions in equal columns: the first count in `counts` whose
/// column holds every action's word on one line, measured as drawn (in the
/// app's language, at the text size, with Bold Text), else the last count.
/// The one equal-column row whose count follows the width: a fixed two by two
/// moved everything below the card 94.7 pt down on every phone to save a
/// 320-pt one, where ru «Подгузники» (71.1 pt) misses a quarter (64), and no
/// padding or shorter word reaches 320, because the words name the screens.
/// Other equal-column rows keep one count per text size (`BBTileColumns`).
private struct QuickActionsLayout: Layout {
    let counts: [Int]
    let rowSpacing: CGFloat

    private func columnCount(width: CGFloat, subviews: Subviews) -> Int {
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return counts.first { widest <= width / CGFloat($0) } ?? counts.last ?? 1
    }

    /// The rows' heights at `width`, each its tallest action's.
    private func rowHeights(width: CGFloat, count: Int, subviews: Subviews) -> [CGFloat] {
        let column = ProposedViewSize(width: width / CGFloat(count), height: nil)
        return stride(from: 0, to: subviews.count, by: count).map { start in
            subviews[start..<min(start + count, subviews.count)]
                .map { $0.sizeThatFits(column).height }.max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
            ?? (subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0) * CGFloat(counts.first ?? 1)
        let heights = rowHeights(width: width, count: columnCount(width: width, subviews: subviews),
                                 subviews: subviews)
        return CGSize(width: width,
                      height: heights.reduce(0, +) + rowSpacing * CGFloat(max(heights.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = columnCount(width: bounds.width, subviews: subviews)
        let column = bounds.width / CGFloat(count)
        var top = bounds.minY
        for (row, height) in rowHeights(width: bounds.width, count: count, subviews: subviews).enumerated() {
            for index in row * count..<min((row + 1) * count, subviews.count) {
                // Centred in its cell, as a stack row and a grid cell set it.
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + column * (CGFloat(index - row * count) + 0.5), y: top + height / 2),
                    anchor: .center,
                    proposal: ProposedViewSize(width: column, height: nil))
            }
            top += height + rowSpacing
        }
    }
}

// MARK: - Quick Sheets
struct FeedingQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            FeedingView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { BBBarButton(.close) { dismiss() } } }
        }
    }
}

struct SleepQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            SleepView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { BBBarButton(.close) { dismiss() } } }
        }
    }
}

struct DiaperQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DiaperView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { BBBarButton(.close) { dismiss() } } }
        }
    }
}

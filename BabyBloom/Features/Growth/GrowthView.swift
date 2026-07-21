import SwiftUI
import SwiftData

struct GrowthView: View {
    @Query(sort: \GrowthEntry.date, order: .reverse) private var entries: [GrowthEntry]
    @Query(sort: \Baby.createdAt) private var babies: [Baby]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var showPercentileInfo = false

    private var baby: Baby? { babies.first }
    private var latest: GrowthEntry? { entries.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {

                    // Latest measurements
                    latestSection
                        .padding(.horizontal, BBTheme.Spacing.md)

                    // Weight chart
                    if entries.count >= 2 {
                        chartSection
                            .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // Percentile card
                    if let baby, let entry = latest, let weight = entry.weightKg {
                        percentileSection(baby: baby, weight: weight, entry: entry)
                            .padding(.horizontal, BBTheme.Spacing.md)
                    }

                    // History
                    historySection
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .background(BBTheme.Colors.background.ignoresSafeArea())
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
        }
        .sheet(isPresented: $showAddSheet) {
            AddGrowthSheet()
        }
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
    private func percentileSection(baby: Baby, weight: Double, entry: GrowthEntry) -> some View {
        let isMale = baby.gender == .male
        let months = baby.ageInMonths
        let percentile = WHOPercentile.weightPercentile(ageMonths: months, weightKg: weight, isMale: isMale)
        let label = WHOPercentile.percentileLabel(percentile)
        let color = Color(hex: WHOPercentile.percentileColor(percentile))

        return VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            HStack {
                BBTheme.Typography.title3("section.who_percentiles".l)
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                Button {
                    showPercentileInfo = true
                } label: {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(BBTheme.Colors.primary.opacity(0.7))
                }
                .sheet(isPresented: $showPercentileInfo) {
                    PercentileInfoSheet()
                }
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
                        Text("\(Int(percentile))")
                            .font(BBTheme.Typography.scaled(16, relativeTo: .body, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(color)
                    }
                }

                Text(String(format: "percentile.by_who_fmt".l, months, months.monthWord))
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
            }
            .padding(BBTheme.Spacing.md)
            .background(BBTheme.Colors.surface)
            .cornerRadius(BBTheme.Radius.lg)
            .bbShadow(BBTheme.Shadow.card)
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

            Text(entry.date.formatted(.dateTime.day().month()))
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
                    Text("📊")
                        .font(.system(size: 56))
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
    @State private var weightKg: Double = 3.5
    @State private var heightCm: Double = 50.0
    @State private var headCm: Double = 34.0
    @State private var includeHead: Bool = false
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    Text("📏")
                        .font(.system(size: 48))

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
        modelContext.insert(entry)
        try? modelContext.save()
        if isFirst {
            NotificationManager.shared.onFirstGrowthEntrySaved()
        }
        dismiss()
    }
}

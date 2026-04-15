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
                    color: BBTheme.Colors.growth
                )
                BBStatCard(
                    title: "stat.height",
                    value: latest.flatMap { $0.heightCm.map { String(format: "%.1f", $0) } } ?? "—",
                    unit: "unit.cm",
                    icon: "ruler.fill",
                    color: BBTheme.Colors.primary
                )
                BBStatCard(
                    title: "stat.head",
                    value: latest.flatMap { $0.headCircumferenceCm.map { String(format: "%.1f", $0) } } ?? "—",
                    unit: "unit.cm",
                    icon: "circle.dotted",
                    color: BBTheme.Colors.accent
                )
                BBStatCard(
                    title: "stat.measurements",
                    value: "\(entries.count)",
                    unit: "unit.times",
                    icon: "calendar",
                    color: BBTheme.Colors.diaper
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
                Text("section.who_percentiles".l)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                        Text(label)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
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
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
                    .fill(BBTheme.Colors.growth.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(BBTheme.Colors.growth)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: BBTheme.Spacing.md) {
                    if let w = entry.weightKg {
                        Label(String(format: "%.2f \("unit.kg".l)", w), systemImage: "scalemass")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    if let h = entry.heightCm {
                        Label(String(format: "%.0f \("unit.cm".l)", h), systemImage: "ruler")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
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

                    Text("percentile.info_title".l)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)

                    Text("percentile.info_body".l)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
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
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var headText = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BBTheme.Spacing.lg) {
                    Text("📏")
                        .font(.system(size: 48))

                    measureField(title: "form.weight_kg".l, placeholder: "form.weight_placeholder".l, text: $weightText)
                    measureField(title: "form.height_cm".l, placeholder: "form.height_placeholder".l, text: $heightText)
                    measureField(title: "form.head_cm".l, placeholder: "form.head_placeholder".l, text: $headText)

                    DatePicker("form.measurement_date".l, selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(BBTheme.Colors.primary)
                        .padding(BBTheme.Spacing.md)
                        .background(BBTheme.Colors.surface)
                        .cornerRadius(BBTheme.Radius.md)
                        .bbShadow(BBTheme.Shadow.card)

                    BBPrimaryButton("button.save".l, icon: "checkmark") { save() }
                        .disabled(weightText.isEmpty && heightText.isEmpty)
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

    private func measureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(BBTheme.Spacing.md)
                .background(BBTheme.Colors.surface)
                .cornerRadius(BBTheme.Radius.md)
                .bbShadow(BBTheme.Shadow.card)
        }
    }

    private func save() {
        let entry = GrowthEntry(
            date: date,
            weightKg: Double(weightText),
            heightCm: Double(heightText),
            headCircumferenceCm: Double(headText)
        )
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}

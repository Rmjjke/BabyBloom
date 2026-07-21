import SwiftUI
import SwiftData

// MARK: - Export View

struct ExportView: View {
    @Query(sort: \FeedingEntry.startTime,  order: .reverse) private var allFeedings: [FeedingEntry]
    @Query(sort: \SleepEntry.startTime,    order: .reverse) private var allSleeps: [SleepEntry]
    @Query(sort: \DiaperEntry.time,        order: .reverse) private var allDiapers: [DiaperEntry]
    @Query(sort: \GrowthEntry.date,        order: .reverse) private var allGrowths: [GrowthEntry]
    @Query(sort: \CustomEvent.time,        order: .reverse) private var allEvents: [CustomEvent]
    @Query(sort: \Baby.createdAt)                           private var babies: [Baby]

    @State private var selectedFormat: ExportFormat   = .pdf
    @State private var selectedRange: ExportDateRange = .month
    @State private var categories: Set<ExportCategory> = Set(ExportCategory.allCases)
    @State private var isExporting = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showEmptyAlert = false
    @State private var showWriteError = false

    private var baby: Baby? { babies.first }

    var body: some View {
        ScrollView {
            VStack(spacing: BBTheme.Spacing.lg) {

                // ── Format ──────────────────────────────────────────────
                sectionCard(title: "export.format".l) {
                    HStack(spacing: BBTheme.Spacing.sm) {
                        ForEach(ExportFormat.allCases, id: \.self) { fmt in
                            formatButton(fmt)
                        }
                    }
                }

                // ── Date range ──────────────────────────────────────────
                sectionCard(title: "export.date_range".l) {
                    VStack(spacing: BBTheme.Spacing.sm) {
                        ForEach(ExportDateRange.allCases, id: \.self) { range in
                            rangeRow(range)
                        }
                    }
                }

                // ── Categories ──────────────────────────────────────────
                sectionCard(title: "export.categories".l) {
                    VStack(spacing: 0) {
                        ForEach(Array(ExportCategory.allCases.enumerated()), id: \.offset) { i, cat in
                            categoryToggle(cat, isLast: i == ExportCategory.allCases.count - 1)
                        }
                    }
                }

                // ── Export button ───────────────────────────────────────
                BBPrimaryButton(
                    isExporting ? "export.generating".l : "export.button".l,
                    icon: isExporting ? nil : "square.and.arrow.up",
                    isLoading: isExporting
                ) {
                    generateExport()
                }
                .disabled(isExporting || categories.isEmpty)
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .padding(BBTheme.Spacing.md)
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("settings.export".l)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .alert("export.empty_title".l, isPresented: $showEmptyAlert) {
            Button("button.close".l, role: .cancel) {}
        } message: {
            Text("export.empty_body".l)
        }
        .alert("export.error_title".l, isPresented: $showWriteError) {
            Button("button.close".l, role: .cancel) {}
        } message: {
            Text("export.error_body".l)
        }
    }

    // MARK: - Format selector

    private func formatButton(_ fmt: ExportFormat) -> some View {
        let selected = selectedFormat == fmt
        return Button {
            withAnimation(.spring(response: 0.3)) { selectedFormat = fmt }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: fmt == .pdf ? "doc.richtext.fill" : "tablecells.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(selected ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
                Text(fmt == .pdf ? "PDF" : "CSV")
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? BBTheme.Colors.primary : BBTheme.Colors.textPrimary)
                Text(fmt == .pdf ? "export.format.pdf_desc".l : "export.format.csv_desc".l)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? BBTheme.Colors.primary.opacity(0.08) : BBTheme.Colors.background)
            .cornerRadius(BBTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: BBTheme.Radius.md)
                    .stroke(selected ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary.opacity(0.15),
                            lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(BBScaleButtonStyle())
    }

    // MARK: - Date range row

    private func rangeRow(_ range: ExportDateRange) -> some View {
        let selected = selectedRange == range
        return Button {
            withAnimation(.spring(response: 0.25)) { selectedRange = range }
        } label: {
            HStack {
                Text(range.rawValue.l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BBTheme.Colors.primary)
                } else {
                    Circle()
                        .stroke(BBTheme.Colors.textSecondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category toggle

    private func categoryToggle(_ cat: ExportCategory, isLast: Bool) -> some View {
        let isOn = categories.contains(cat)
        let count = recordCount(cat)
        let isEmpty = count == 0
        return Button {
            if isOn { categories.remove(cat) } else { categories.insert(cat) }
        } label: {
            HStack(spacing: BBTheme.Spacing.md) {
                Image(systemName: categoryIcon(cat))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BBTheme.Colors.primary)
                    .frame(width: 30, height: 30)
                    .background(BBTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
                Text(cat.rawValue.l)
                    .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                    .foregroundStyle(BBTheme.Colors.textPrimary)
                Spacer()
                if isEmpty {
                    Text("0")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)
                }
                Image(systemName: isOn && !isEmpty ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn && !isEmpty ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary.opacity(0.4))
            }
            .padding(.vertical, 10)
            .opacity(isEmpty ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        if !isLast {
            Divider()
        }
    }

    /// Number of records for a category within the currently selected range.
    private func recordCount(_ cat: ExportCategory) -> Int {
        let cutoff = selectedRange.startDate()
        func cnt<T>(_ items: [T], _ date: (T) -> Date) -> Int {
            guard let cutoff else { return items.count }
            return items.filter { date($0) >= cutoff }.count
        }
        switch cat {
        case .feeding: return cnt(allFeedings) { $0.startTime }
        case .sleep:   return cnt(allSleeps)   { $0.startTime }
        case .diapers: return cnt(allDiapers)  { $0.time }
        case .growth:  return cnt(allGrowths)  { $0.date }
        case .events:  return cnt(allEvents)   { $0.time }
        }
    }

    private func categoryIcon(_ cat: ExportCategory) -> String {
        switch cat {
        case .feeding: return "heart.fill"
        case .sleep:   return "moon.fill"
        case .diapers: return "drop.fill"
        case .growth:  return "ruler.fill"
        case .events:  return "star.fill"
        }
    }

    // MARK: - Section card helper

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BBTheme.Spacing.md) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textSecondary)
                .textCase(.uppercase)
            content()
        }
        .padding(BBTheme.Spacing.md)
        .background(BBTheme.Colors.surface)
        .cornerRadius(BBTheme.Radius.lg)
        .bbShadow(BBTheme.Shadow.card)
    }

    // MARK: - Export logic

    private func generateExport() {
        let cutoff = selectedRange.startDate()

        func filtered<T>(_ items: [T], date: (T) -> Date) -> [T] {
            guard let cutoff else { return items }
            return items.filter { date($0) >= cutoff }
        }

        let feedings = filtered(allFeedings) { $0.startTime }
        let sleeps   = filtered(allSleeps)   { $0.startTime }
        let diapers  = filtered(allDiapers)  { $0.time }
        let growths  = filtered(allGrowths)  { $0.date }
        let events   = filtered(allEvents)   { $0.time }

        let hasData = !feedings.isEmpty || !sleeps.isEmpty ||
                      !diapers.isEmpty  || !growths.isEmpty || !events.isEmpty
        guard hasData else { showEmptyAlert = true; return }

        // Only export categories that actually have records in this range.
        let cats = categories.filter { recordCount($0) > 0 }
        guard !cats.isEmpty else { showEmptyAlert = true; return }

        // Capture all values before leaving main actor
        let fmt        = selectedFormat
        let range      = selectedRange
        let babySnap   = baby
        let slug       = "\(babySlug())_\(rangeSlug())"

        // Wipe stale exports so we never re-share a previous file.
        ExportGenerator.cleanupExports()

        isExporting = true
        Task { @MainActor in
            var items: [Any] = []

            if fmt == .pdf {
                let data = ExportGenerator.pdfData(
                    baby: babySnap,
                    feedings: feedings, sleeps: sleeps,
                    diapers: diapers, growths: growths, events: events,
                    categories: cats, range: range
                )
                if let url = ExportGenerator.writeTempFile(name: "BabyBloom_\(slug).pdf", data: data) {
                    items.append(url)
                }
            } else {
                let files = ExportGenerator.csvString(
                    feedings: feedings, sleeps: sleeps,
                    diapers: diapers, growths: growths, events: events,
                    categories: cats
                )
                for (name, content) in files {
                    if let url = ExportGenerator.writeTempCSV(name: "\(slug)_\(name)", content: content) {
                        items.append(url)
                    }
                }
            }

            isExporting = false
            shareItems = items
            // Never hand the share sheet a URL to a file that failed to write.
            if items.isEmpty {
                showWriteError = true
            } else {
                showShareSheet = true
            }
        }
    }

    private func babySlug() -> String {
        (baby?.name ?? "baby").lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func rangeSlug() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Share Sheet Bridge

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

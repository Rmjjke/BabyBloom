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
    // Identifiable request drives `.sheet(item:)` so the share sheet is always
    // built with the freshly-generated files. `.sheet(isPresented:)` + a separate
    // @State could hand the sheet stale/empty items captured before the update.
    @State private var shareRequest: ShareRequest?
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
                    // Both tiles take the taller one's height.
                    .fixedSize(horizontal: false, vertical: true)
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
                .disabled(isExporting || exportable.isEmpty)
                // The primary button does not dim itself; without this a
                // disabled Export looks live and a tap silently does nothing.
                .opacity(exportable.isEmpty ? 0.5 : 1)
                .padding(.bottom, BBTheme.Spacing.xl)
            }
            .padding(BBTheme.Spacing.md)
        }
        .background(BBTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("settings.export".l)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $shareRequest) { request in
            ShareSheet(items: request.items)
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
            // sm a side inside the outline: the description's lines ran into it.
            .padding(.horizontal, BBTheme.Spacing.sm)
            // The row's full height (the HStack's fixedSize), the glyph on top.
            // minWidth 0 holds the tile to its share: a wrapped line can measure
            // a third of a point past its width, and without it the whole column
            // widened by that.
            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                        .stroke(BBTheme.Colors.textSecondary, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.vertical, 10)
            // A plain button takes taps only where it draws: without a shape the
            // Spacer's gap is dead, and a tap there silently keeps the old range.
            .contentShape(Rectangle())
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
                // At the accessibility sizes the «0» goes under the title.
                BBValueRow {
                    Text(cat.rawValue.l)
                        .font(BBTheme.Typography.scaled(15, relativeTo: .body, weight: .medium, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textPrimary)
                } value: {
                    if isEmpty {
                        Text("0")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(BBTheme.Colors.textSecondary)
                    }
                }
                Image(systemName: isOn && !isEmpty ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn && !isEmpty ? BBTheme.Colors.primary : BBTheme.Colors.textSecondary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
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

    private var exportable: Set<ExportCategory> {
        ExportSelection.exportable(ticked: categories, recordCount: recordCount)
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

        let cats = exportable
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
            // The render holds the main thread for seconds on a long export, and a
            // main-queue task can run before the button's new state reaches the screen.
            try? await Task.sleep(for: .milliseconds(100))
            var items: [Any] = []

            if fmt == .pdf {
                let data = ExportGenerator.pdfData(
                    baby: babySnap,
                    feedings: feedings, sleeps: sleeps,
                    diapers: diapers, growths: growths, events: events,
                    categories: cats, range: range
                )
                if let url = ExportGenerator.writeTempFile(name: "\("brand.name".l)_\(slug).pdf", data: data) {
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
            // Never hand the share sheet a URL to a file that failed to write.
            if items.isEmpty {
                showWriteError = true
            } else {
                shareRequest = ShareRequest(items: items)
            }
        }
    }

    private func babySlug() -> String {
        ExportGenerator.fileNamePart(baby?.name ?? "").lowercased().replacingOccurrences(of: " ", with: "_")
    }

    private func rangeSlug() -> String {
        // Part of a FILENAME, so it is pinned to en_US_POSIX like the CSV
        // columns: a device on a non-Gregorian calendar would otherwise stamp
        // an unrecognisable year onto the exported file.
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - What Export writes

/// The ticked categories that have records in the range: what the file holds,
/// and the one rule for the Export button. A 0-record category stays in the
/// set (its box draws empty and its row takes no tap), so "anything ticked"
/// alone would leave the button on with nothing to write.
enum ExportSelection {
    static func exportable(ticked: Set<ExportCategory>,
                           recordCount: (ExportCategory) -> Int) -> Set<ExportCategory> {
        ticked.filter { recordCount($0) > 0 }
    }
}

// MARK: - Share Sheet Bridge

/// Identifiable payload for `.sheet(item:)` — a fresh `id` per export guarantees the
/// share sheet is rebuilt with the newly-generated files.
struct ShareRequest: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

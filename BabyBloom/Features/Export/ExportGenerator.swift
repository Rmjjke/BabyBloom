import UIKit

// MARK: - Export Models

enum ExportFormat: String, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"
}

enum ExportDateRange: String, CaseIterable {
    case week       = "export.range.week"
    case month      = "export.range.month"
    case threeMonths = "export.range.three_months"
    case all        = "export.range.all"

    func startDate() -> Date? {
        let cal = Calendar.current
        switch self {
        case .week:        return cal.date(byAdding: .day,   value: -7,  to: Date())
        case .month:       return cal.date(byAdding: .month, value: -1,  to: Date())
        case .threeMonths: return cal.date(byAdding: .month, value: -3,  to: Date())
        case .all:         return nil
        }
    }
}

enum ExportCategory: String, CaseIterable {
    case feeding  = "export.cat.feeding"
    case sleep    = "export.cat.sleep"
    case diapers  = "export.cat.diapers"
    case growth   = "export.cat.growth"
    case events   = "export.cat.events"

    var fileName: String {
        switch self {
        case .feeding: return "feeding"
        case .sleep:   return "sleep"
        case .diapers: return "diapers"
        case .growth:  return "growth"
        case .events:  return "events"
        }
    }
}

// MARK: - Export Generator

struct ExportGenerator {

    // MARK: - CSV

    static func csvString(
        feedings: [FeedingEntry],
        sleeps: [SleepEntry],
        diapers: [DiaperEntry],
        growths: [GrowthEntry],
        events: [CustomEvent],
        categories: Set<ExportCategory>
    ) -> [(name: String, content: String)] {
        var files: [(String, String)] = []

        if categories.contains(.feeding) {
            files.append(("feeding.csv", feedingCSV(feedings)))
        }
        if categories.contains(.sleep) {
            files.append(("sleep.csv", sleepCSV(sleeps)))
        }
        if categories.contains(.diapers) {
            files.append(("diapers.csv", diaperCSV(diapers)))
        }
        if categories.contains(.growth) {
            files.append(("growth.csv", growthCSV(growths)))
        }
        if categories.contains(.events) {
            files.append(("events.csv", eventsCSV(events)))
        }
        return files
    }

    /// Escapes a single CSV field per RFC 4180: fields containing a comma,
    /// double-quote or newline are wrapped in quotes with inner quotes doubled.
    static func csvField(_ raw: String) -> String {
        if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
            return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return raw
    }

    /// Joins fields into one escaped CSV row.
    private static func csvRow(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    private static func feedingCSV(_ entries: [FeedingEntry]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.time".l, "export.csv.type".l,
                            "export.csv.side".l, "export.csv.volume_ml".l, "export.csv.duration_min".l])]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let type = e.type.displayName.l
            let side = e.side?.displayName.l ?? ""
            let vol  = e.volumeML.map { String(Int($0)) } ?? ""
            let dur  = String(Int(e.duration / 60))
            rows.append(csvRow([fmt.string(from: e.startTime), tfmt.string(from: e.startTime), type, side, vol, dur]))
        }
        return rows.joined(separator: "\n")
    }

    private static func sleepCSV(_ entries: [SleepEntry]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.start".l, "export.csv.end".l,
                            "export.csv.type".l, "export.csv.location".l, "export.csv.duration_h".l])]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let end = e.endTime.map { tfmt.string(from: $0) } ?? ""
            let loc = e.location?.displayName.l ?? ""
            let dur = String(format: "%.2f", e.duration / 3600)
            rows.append(csvRow([fmt.string(from: e.startTime), tfmt.string(from: e.startTime), end, e.type.displayName.l, loc, dur]))
        }
        return rows.joined(separator: "\n")
    }

    private static func diaperCSV(_ entries: [DiaperEntry]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.time".l, "export.csv.type".l,
                            "export.csv.stool_color".l, "export.csv.notes".l])]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let color = e.color?.displayName.l ?? ""
            let notes = e.notes ?? ""
            rows.append(csvRow([fmt.string(from: e.time), tfmt.string(from: e.time), e.type.displayName.l, color, notes]))
        }
        return rows.joined(separator: "\n")
    }

    private static func growthCSV(_ entries: [GrowthEntry]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.weight_kg".l,
                            "export.csv.height_cm".l, "export.csv.head_cm".l])]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        for e in entries {
            let w = e.weightKg.map { String(format: "%.2f", $0) } ?? ""
            let h = e.heightCm.map { String(format: "%.1f", $0) } ?? ""
            let hc = e.headCircumferenceCm.map { String(format: "%.1f", $0) } ?? ""
            rows.append(csvRow([fmt.string(from: e.date), w, h, hc]))
        }
        return rows.joined(separator: "\n")
    }

    private static func eventsCSV(_ entries: [CustomEvent]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.time".l,
                            "export.csv.type".l, "export.csv.notes".l])]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let notes = e.notes ?? ""
            rows.append(csvRow([fmt.string(from: e.time), tfmt.string(from: e.time), e.type.displayName.l, notes]))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - PDF

    static func pdfData(
        baby: Baby?,
        feedings: [FeedingEntry],
        sleeps: [SleepEntry],
        diapers: [DiaperEntry],
        growths: [GrowthEntry],
        events: [CustomEvent],
        categories: Set<ExportCategory>,
        range: ExportDateRange
    ) -> Data {
        let html = buildHTML(baby: baby, feedings: feedings, sleeps: sleeps,
                             diapers: diapers, growths: growths, events: events,
                             categories: categories, range: range)
        return renderPDF(from: html)
    }

    // MARK: - HTML Builder

    private static func buildHTML(
        baby: Baby?,
        feedings: [FeedingEntry],
        sleeps: [SleepEntry],
        diapers: [DiaperEntry],
        growths: [GrowthEntry],
        events: [CustomEvent],
        categories: Set<ExportCategory>,
        range: ExportDateRange
    ) -> String {
        let dateFmt = DateFormatter(); dateFmt.dateStyle = .medium; dateFmt.timeStyle = .none
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"

        let babyName = baby?.name ?? "Baby"
        let ageDesc  = baby?.ageDescription ?? ""
        let rangeLabel = range.rawValue.l
        let generatedDate = dateFmt.string(from: Date())

        // Summary stats
        let totalFeedMin = Int(feedings.filter { !$0.isActive }.reduce(0) { $0 + $1.duration } / 60)
        let totalSleepH  = String(format: "%.1f", sleeps.compactMap { $0.endTime != nil ? $0.duration : nil }.reduce(0, +) / 3600)
        let avgFeedPerDay = averagePerDay(
            count: feedings.count,
            range: range,
            earliest: feedings.map(\.startTime).min()
        )

        var sections = ""

        // Summary card
        sections += """
        <div class="card summary">
          <h2>📊 \("export.summary".l)</h2>
          <div class="stats-grid">
        """
        if categories.contains(.feeding) {
            sections += """
            <div class="stat"><span class="val">\(feedings.count)</span><span class="lbl">\("export.cat.feeding".l)</span></div>
            <div class="stat"><span class="val">\(totalFeedMin) min</span><span class="lbl">\("export.summary.total_time".l)</span></div>
            <div class="stat"><span class="val">\(String(format: "%.1f", avgFeedPerDay))/\("filter.day".l.lowercased())</span><span class="lbl">\("export.summary.avg".l)</span></div>
            """
        }
        if categories.contains(.sleep) {
            sections += """
            <div class="stat"><span class="val">\(sleeps.count)</span><span class="lbl">\("export.cat.sleep".l)</span></div>
            <div class="stat"><span class="val">\(totalSleepH) h</span><span class="lbl">\("export.summary.total_sleep".l)</span></div>
            """
        }
        if categories.contains(.diapers) {
            sections += "<div class=\"stat\"><span class=\"val\">\(diapers.count)</span><span class=\"lbl\">\("export.cat.diapers".l)</span></div>"
        }
        if categories.contains(.growth) {
            sections += "<div class=\"stat\"><span class=\"val\">\(growths.count)</span><span class=\"lbl\">\("export.cat.growth".l)</span></div>"
        }
        sections += "</div></div>"

        // Feeding table
        if categories.contains(.feeding) && !feedings.isEmpty {
            sections += tableSection(
                title: "🍼 \("export.cat.feeding".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.side".l, "export.col.volume".l, "export.col.duration".l],
                rows: feedings.map { e in
                    [dateFmt.string(from: e.startTime),
                     timeFmt.string(from: e.startTime),
                     e.type.displayName.l,
                     e.side?.displayName.l ?? "—",
                     e.volumeML.map { "\(Int($0)) ml" } ?? "—",
                     "\(Int(e.duration / 60)) min"]
                }
            )
        }

        // Sleep table
        if categories.contains(.sleep) && !sleeps.isEmpty {
            sections += tableSection(
                title: "😴 \("export.cat.sleep".l)",
                headers: ["export.col.date".l, "export.col.start".l, "export.col.end".l, "export.col.type".l, "export.col.duration".l],
                rows: sleeps.map { e in
                    [dateFmt.string(from: e.startTime),
                     timeFmt.string(from: e.startTime),
                     e.endTime.map { timeFmt.string(from: $0) } ?? "—",
                     e.type.displayName.l,
                     e.durationFormatted]
                }
            )
        }

        // Diapers table
        if categories.contains(.diapers) && !diapers.isEmpty {
            sections += tableSection(
                title: "🩲 \("export.cat.diapers".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.color".l, "export.col.notes".l],
                rows: diapers.map { e in
                    [dateFmt.string(from: e.time),
                     timeFmt.string(from: e.time),
                     e.type.displayName.l,
                     e.color?.displayName.l ?? "—",
                     e.notes ?? "—"]
                }
            )
        }

        // Growth table
        if categories.contains(.growth) && !growths.isEmpty {
            sections += tableSection(
                title: "📏 \("export.cat.growth".l)",
                headers: ["export.col.date".l, "export.col.weight".l, "export.col.height".l, "export.col.head".l],
                rows: growths.map { e in
                    [dateFmt.string(from: e.date),
                     e.weightKg.map { String(format: "%.2f kg", $0) } ?? "—",
                     e.heightCm.map { String(format: "%.1f cm", $0) } ?? "—",
                     e.headCircumferenceCm.map { String(format: "%.1f cm", $0) } ?? "—"]
                }
            )
        }

        // Events table
        if categories.contains(.events) && !events.isEmpty {
            sections += tableSection(
                title: "⭐ \("export.cat.events".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.notes".l],
                rows: events.map { e in
                    [dateFmt.string(from: e.time),
                     timeFmt.string(from: e.time),
                     e.type.displayName.l,
                     e.notes ?? "—"]
                }
            )
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
          body { font-family: -apple-system, Helvetica, Arial, sans-serif; margin: 0; padding: 24px; color: #1C1C1E; font-size: 12px; }
          .header { background: linear-gradient(135deg, #4E8073, #8FC9AC); color: white; padding: 24px; border-radius: 12px; margin-bottom: 20px; }
          .header h1 { margin: 0 0 4px; font-size: 22px; }
          .header p  { margin: 0; opacity: 0.85; font-size: 13px; }
          .meta { display: flex; gap: 16px; margin-top: 8px; }
          .meta span { background: rgba(255,255,255,0.2); padding: 3px 10px; border-radius: 20px; font-size: 11px; }
          .card { background: #F2F2F7; border-radius: 10px; padding: 16px; margin-bottom: 16px; }
          .card h2 { margin: 0 0 12px; font-size: 15px; color: #4E8073; }
          .stats-grid { display: flex; flex-wrap: wrap; gap: 10px; }
          .stat { background: white; border-radius: 8px; padding: 10px 14px; min-width: 80px; }
          .stat .val { display: block; font-size: 18px; font-weight: 700; color: #1C1C1E; }
          .stat .lbl { display: block; font-size: 10px; color: #8E8E93; margin-top: 2px; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 4px; }
          th { background: #4E8073; color: white; padding: 7px 10px; text-align: left; font-size: 11px; }
          th:first-child { border-radius: 6px 0 0 0; }
          th:last-child  { border-radius: 0 6px 0 0; }
          td { padding: 6px 10px; border-bottom: 1px solid #E5E5EA; font-size: 11px; }
          tr:last-child td { border-bottom: none; }
          tr:nth-child(even) td { background: #F9F9FB; }
          .footer { text-align: center; color: #8E8E93; font-size: 10px; margin-top: 24px; }
        </style>
        </head>
        <body>
          <div class="header">
            <h1>BabyBloom — \(htmlEscape(babyName))</h1>
            <p>\("export.pdf.subtitle".l)</p>
            <div class="meta">
              <span>📅 \(rangeLabel)</span>
              <span>🎂 \(ageDesc)</span>
              <span>🗓 \(generatedDate)</span>
            </div>
          </div>
          \(sections)
          <div class="footer">Generated by BabyBloom · \(generatedDate)</div>
        </body>
        </html>
        """
    }

    /// Escapes HTML-significant characters in user-supplied values. `&` must
    /// be replaced first so already-escaped entities aren't double-encoded.
    static func htmlEscape(_ raw: String) -> String {
        raw.replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Average number of entries per day. For a bounded `range` the span is the
    /// range length; for `.all` it is measured from the earliest entry so the
    /// figure isn't diluted by an arbitrary 30-day assumption.
    static func averagePerDay(count: Int, range: ExportDateRange, earliest: Date?, now: Date = Date()) -> Double {
        guard count > 0 else { return 0 }
        let start = range.startDate() ?? earliest
        guard let start else { return Double(count) }
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 1)
        return Double(count) / Double(days)
    }

    private static func tableSection(title: String, headers: [String], rows: [[String]]) -> String {
        let ths = headers.map { "<th>\(htmlEscape($0))</th>" }.joined()
        let trs = rows.map { row in
            "<tr>" + row.map { "<td>\(htmlEscape($0))</td>" }.joined() + "</tr>"
        }.joined()
        return """
        <div class="card">
          <h2>\(title)</h2>
          <table><thead><tr>\(ths)</tr></thead><tbody>\(trs)</tbody></table>
        </div>
        """
    }

    // MARK: - PDF Renderer

    private static func renderPDF(from html: String) -> Data {
        let formatter = UIMarkupTextPrintFormatter(markupText: html)
        let renderer  = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize     = CGSize(width: 595.2, height: 841.8)   // A4
        let margin: CGFloat = 36
        let printable    = CGRect(x: margin, y: margin,
                                  width: pageSize.width - margin * 2,
                                  height: pageSize.height - margin * 2)
        renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, CGRect(origin: .zero, size: pageSize), nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    // MARK: - Temp file helpers

    /// Dedicated subfolder for generated exports so we can wipe stale files
    /// without touching the rest of the temp directory.
    static func exportsDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
    }

    /// Removes previously generated export files. Call once before writing a
    /// new batch so old PDFs/CSVs don't linger or get re-shared.
    static func cleanupExports() {
        try? FileManager.default.removeItem(at: exportsDirectory())
    }

    /// Writes `data` into the exports folder. Returns nil on failure so callers
    /// never hand a URL to a file that doesn't exist.
    static func writeTempFile(name: String, data: Data) -> URL? {
        let dir = exportsDirectory()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: url)
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    static func writeTempCSV(name: String, content: String) -> URL? {
        guard let data = content.data(using: .utf8) else { return nil }
        return writeTempFile(name: name, data: data)
    }
}

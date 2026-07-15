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

    private static func feedingCSV(_ entries: [FeedingEntry]) -> String {
        var rows = ["Date,Time,Type,Side,Volume (ml),Duration (min)"]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let type = e.type.rawValue
            let side = e.side?.rawValue ?? ""
            let vol  = e.volumeML.map { String(Int($0)) } ?? ""
            let dur  = String(Int(e.duration / 60))
            rows.append("\(fmt.string(from: e.startTime)),\(tfmt.string(from: e.startTime)),\(type),\(side),\(vol),\(dur)")
        }
        return rows.joined(separator: "\n")
    }

    private static func sleepCSV(_ entries: [SleepEntry]) -> String {
        var rows = ["Date,Start,End,Type,Location,Duration (h)"]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let end = e.endTime.map { tfmt.string(from: $0) } ?? ""
            let loc = e.location?.rawValue ?? ""
            let dur = String(format: "%.2f", e.duration / 3600)
            rows.append("\(fmt.string(from: e.startTime)),\(tfmt.string(from: e.startTime)),\(end),\(e.type.rawValue),\(loc),\(dur)")
        }
        return rows.joined(separator: "\n")
    }

    private static func diaperCSV(_ entries: [DiaperEntry]) -> String {
        var rows = ["Date,Time,Type,Stool Color,Notes"]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let color = e.color?.rawValue ?? ""
            let notes = e.notes ?? ""
            rows.append("\(fmt.string(from: e.time)),\(tfmt.string(from: e.time)),\(e.type.rawValue),\(color),\"\(notes)\"")
        }
        return rows.joined(separator: "\n")
    }

    private static func growthCSV(_ entries: [GrowthEntry]) -> String {
        var rows = ["Date,Weight (kg),Height (cm),Head (cm)"]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        for e in entries {
            let w = e.weightKg.map { String(format: "%.2f", $0) } ?? ""
            let h = e.heightCm.map { String(format: "%.1f", $0) } ?? ""
            let hc = e.headCircumferenceCm.map { String(format: "%.1f", $0) } ?? ""
            rows.append("\(fmt.string(from: e.date)),\(w),\(h),\(hc)")
        }
        return rows.joined(separator: "\n")
    }

    private static func eventsCSV(_ entries: [CustomEvent]) -> String {
        var rows = ["Date,Time,Type,Notes"]
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let tfmt = DateFormatter(); tfmt.dateFormat = "HH:mm"
        for e in entries {
            let notes = e.notes ?? ""
            rows.append("\(fmt.string(from: e.time)),\(tfmt.string(from: e.time)),\(e.type.rawValue),\"\(notes)\"")
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
        let avgFeedPerDay: Double = {
            guard !feedings.isEmpty else { return 0 }
            let days = max(1, (range.startDate().map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 1 } ?? 30))
            return Double(feedings.count) / Double(days)
        }()

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
          .header { background: linear-gradient(135deg, #6B5EA8, #9B8FD8); color: white; padding: 24px; border-radius: 12px; margin-bottom: 20px; }
          .header h1 { margin: 0 0 4px; font-size: 22px; }
          .header p  { margin: 0; opacity: 0.85; font-size: 13px; }
          .meta { display: flex; gap: 16px; margin-top: 8px; }
          .meta span { background: rgba(255,255,255,0.2); padding: 3px 10px; border-radius: 20px; font-size: 11px; }
          .card { background: #F2F2F7; border-radius: 10px; padding: 16px; margin-bottom: 16px; }
          .card h2 { margin: 0 0 12px; font-size: 15px; color: #6B5EA8; }
          .stats-grid { display: flex; flex-wrap: wrap; gap: 10px; }
          .stat { background: white; border-radius: 8px; padding: 10px 14px; min-width: 80px; }
          .stat .val { display: block; font-size: 18px; font-weight: 700; color: #1C1C1E; }
          .stat .lbl { display: block; font-size: 10px; color: #8E8E93; margin-top: 2px; }
          table { width: 100%; border-collapse: collapse; margin-bottom: 4px; }
          th { background: #6B5EA8; color: white; padding: 7px 10px; text-align: left; font-size: 11px; }
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
            <h1>BabyBloom — \(babyName)</h1>
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

    private static func tableSection(title: String, headers: [String], rows: [[String]]) -> String {
        let ths = headers.map { "<th>\($0)</th>" }.joined()
        let trs = rows.map { row in
            "<tr>" + row.map { "<td>\($0)</td>" }.joined() + "</tr>"
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

    static func writeTempFile(name: String, data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    static func writeTempCSV(name: String, content: String) -> URL? {
        let data = content.data(using: .utf8) ?? Data()
        return writeTempFile(name: name, data: data)
    }
}

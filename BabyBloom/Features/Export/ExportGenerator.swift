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

    func startDate(now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .week:        return cal.date(byAdding: .day,   value: -7,  to: now)
        case .month:       return cal.date(byAdding: .month, value: -1,  to: now)
        case .threeMonths: return cal.date(byAdding: .month, value: -3,  to: now)
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

    // MARK: - Formatters (internal for @testable access)

    /// Machine-readable columns: a FIXED pattern must be pinned to
    /// `en_US_POSIX`, never left on the device locale. Unpinned, `yyyy-MM-dd`
    /// silently follows a non-Gregorian device calendar (Buddhist, Japanese)
    /// and writes years no spreadsheet will read back correctly.
    static func csvFormatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = pattern
        return f
    }

    /// Human-readable PDF text: follows the language the user picked in the
    /// app, NOT the device. Same rule BBCharts already applies to its axis
    /// labels — a Spanish user on a Russian phone must not get Russian dates
    /// inside an otherwise Spanish document. Its locale carries the device's
    /// 12/24-hour cycle, as on screen; clock times go through
    /// `documentTimeFormatter`.
    static func documentFormatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        let f = DateFormatter()
        f.locale = LocalizationManager.shared.language.environmentLocale
        configure(f)
        return f
    }

    /// Clock times in the PDF, on the same skeleton as `appTimeOfDay`, so the
    /// export prints what the screen shows. Not `timeStyle = .short`: a style
    /// keeps a 24-hour language 24-hour on a 12-hour phone (Russian printed
    /// 14:30 where the screen read 2:30 PM).
    static func documentTimeFormatter(in locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("jmm")
        return f
    }

    /// Joins fields into one escaped CSV row.
    private static func csvRow(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    // The numeric cells below use `String(format:)` on purpose: it always writes
    // a dot, so a comma decimal never lands inside a comma-separated file. The
    // unit lives in the column header, never in the cell.
    private static func feedingCSV(_ entries: [FeedingEntry]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.time".l, "export.csv.type".l,
                            "export.csv.side".l, "export.csv.volume_ml".l, "export.csv.duration_min".l])]
        let fmt = csvFormatter("yyyy-MM-dd")
        let tfmt = csvFormatter("HH:mm")
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
        let fmt = csvFormatter("yyyy-MM-dd")
        let tfmt = csvFormatter("HH:mm")
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
        let fmt = csvFormatter("yyyy-MM-dd")
        let tfmt = csvFormatter("HH:mm")
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
        let fmt = csvFormatter("yyyy-MM-dd")
        for e in entries {
            let w = e.weightKg.map { String(format: "%.2f", $0) } ?? ""
            let h = e.heightCm.map { String(format: "%.1f", $0) } ?? ""
            let hc = e.headCircumferenceCm.map { String(format: "%.1f", $0) } ?? ""
            rows.append(csvRow([fmt.string(from: e.date), w, h, hc]))
        }
        return rows.joined(separator: "\n")
    }

    private static func eventsCSV(_ entries: [CustomEvent]) -> String {
        var rows = [csvRow(["export.csv.date".l, "export.csv.time".l, "export.csv.type".l,
                            "export.csv.medication".l, "export.csv.dose".l, "export.csv.notes".l])]
        let fmt = csvFormatter("yyyy-MM-dd")
        let tfmt = csvFormatter("HH:mm")
        for e in entries {
            let notes = e.notes ?? ""
            // The name and dose as logged on the event, so a renamed or
            // deleted medicine leaves the record as it was.
            rows.append(csvRow([fmt.string(from: e.time), tfmt.string(from: e.time), e.type.displayName.l,
                                e.medicationName ?? "", e.medicationDose ?? "", notes]))
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
        PagedPDF.data(document(baby: baby, feedings: feedings, sleeps: sleeps,
                             diapers: diapers, growths: growths, events: events,
                             categories: categories, range: range))
    }

    // MARK: - HTML Builder

    /// Internal for @testable: the number format is pinned on the HTML itself.
    static func buildHTML(
        baby: Baby?,
        feedings: [FeedingEntry],
        sleeps: [SleepEntry],
        diapers: [DiaperEntry],
        growths: [GrowthEntry],
        events: [CustomEvent],
        categories: Set<ExportCategory>,
        range: ExportDateRange,
        hourCycle: Locale.HourCycle? = nil
    ) -> String {
        document(baby: baby, feedings: feedings, sleeps: sleeps,
                             diapers: diapers, growths: growths, events: events,
                             categories: categories, range: range, hourCycle: hourCycle).html
    }

    private static func document(
        baby: Baby?,
        feedings: [FeedingEntry],
        sleeps: [SleepEntry],
        diapers: [DiaperEntry],
        growths: [GrowthEntry],
        events: [CustomEvent],
        categories: Set<ExportCategory>,
        range: ExportDateRange,
        hourCycle: Locale.HourCycle? = nil
    ) -> PagedPDF.Document {
        let dateFmt = documentFormatter { $0.dateStyle = .medium; $0.timeStyle = .none }
        // nil is the device's cycle; tests pass one to read both clocks.
        let timeFmt = documentTimeFormatter(in: LocalizationManager.shared.language
            .environmentLocale(hourCycle: hourCycle ?? Locale.current.hourCycle))

        // A name of emoji alone prints nothing, and the title still needs one.
        let printedName = PagedPDF.withoutEmoji(baby?.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let babyName = PagedPDF.isBlank(printedName) ? "baby.default_name".l : printedName
        let ageDesc  = baby?.ageDescription ?? ""
        let rangeLabel = range.rawValue.l
        let generatedDate = dateFmt.string(from: Date())

        // Summary stats
        // A running feed is not a feed yet: the count, the total and the
        // average all leave it out, so the three tiles agree with each other.
        let finished = feedings.filter { !$0.isActive }
        let finishedFeeds = finished.count
        let totalFeedMin = Int(finished.reduce(0) { $0 + $1.duration } / 60)
        // Every figure below is prose, so it speaks the app language; the CSV
        // keeps its own invariant dot decimal.
        let totalSleepMin = Int(sleeps.compactMap { $0.endTime != nil ? $0.duration : nil }.reduce(0, +) / 60)
        let avgFeedPerDay = averagePerDay(
            dates: finished.map(\.startTime),
            range: range
        )

        // Summary card: tiles first. Events has no tile, so an export of
        // Events alone (a log of medicines only) prints no card at all
        // rather than an empty one.
        var tiles = ""
        // A count tile names what it counts, as the app's own tiles do: the
        // section's name beside a number read as one item or an amount.
        if categories.contains(.feeding) {
            tiles += """
            <div class="stat"><span class="val">\(finishedFeeds)</span><span class="lbl">\("stat.feedings".l)</span></div>
            <div class="stat"><span class="val">\(minutesText(totalFeedMin))</span><span class="lbl">\("export.summary.total_time".l)</span></div>
            """
            // No finished day, no rate: a half-lived today would print a figure
            // the report refuses to. The bare figure: its label says «a day».
            if let avgFeedPerDay {
                tiles += """
                <div class="stat"><span class="val">\(WeeklyFormat.perDay(avgFeedPerDay))</span><span class="lbl">\("export.summary.avg".l)</span></div>
                """
            }
        }
        if categories.contains(.sleep) {
            tiles += """
            <div class="stat"><span class="val">\(sleeps.count)</span><span class="lbl">\("stat.sleep_episodes".l)</span></div>
            <div class="stat"><span class="val">\(minutesText(totalSleepMin))</span><span class="lbl">\("export.summary.total_sleep".l)</span></div>
            """
        }
        if categories.contains(.diapers) {
            tiles += "<div class=\"stat\"><span class=\"val\">\(diapers.count)</span><span class=\"lbl\">\("stat.diapers".l)</span></div>"
        }
        if categories.contains(.growth) {
            tiles += "<div class=\"stat\"><span class=\"val\">\(growths.count)</span><span class=\"lbl\">\("stat.measurements".l)</span></div>"
        }
        let summary: [PagedPDF.Item] = tiles.isEmpty ? [] : [.block("""
            <div class="card summary">
              <h2>\("export.summary".l)</h2>
              <div class="stats-grid">\(tiles)</div></div>
            """)]

        var tables: [PagedPDF.Item] = []

        // Feeding table
        if categories.contains(.feeding) && !feedings.isEmpty {
            tables.append(tableSection(
                title: "\("export.cat.feeding".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.side".l, "export.col.volume".l, "export.col.duration".l],
                rows: feedings.map { e in
                    [dateFmt.string(from: e.startTime),
                     timeFmt.string(from: e.startTime),
                     e.type.displayName.l,
                     e.side?.displayName.l ?? "—",
                     e.volumeML.map { ReportFormat.ml($0) } ?? "—",
                     minutesText(Int(e.duration / 60))]
                }
            ))
        }

        // Sleep table
        if categories.contains(.sleep) && !sleeps.isEmpty {
            tables.append(tableSection(
                title: "\("export.cat.sleep".l)",
                headers: ["export.col.date".l, "export.col.start".l, "export.col.end".l, "export.col.type".l, "export.col.duration".l],
                rows: sleeps.map { e in
                    [dateFmt.string(from: e.startTime),
                     timeFmt.string(from: e.startTime),
                     e.endTime.map { timeFmt.string(from: $0) } ?? "—",
                     e.type.displayName.l,
                     e.durationFormatted]
                }
            ))
        }

        // Diapers table
        if categories.contains(.diapers) && !diapers.isEmpty {
            tables.append(tableSection(
                title: "\("export.cat.diapers".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.color".l, "export.col.notes".l],
                rows: diapers.map { e in
                    [dateFmt.string(from: e.time),
                     timeFmt.string(from: e.time),
                     e.type.displayName.l,
                     e.color?.displayName.l ?? "—",
                     noteCell(e.notes)]
                }
            ))
        }

        // Growth table
        if categories.contains(.growth) && !growths.isEmpty {
            tables.append(tableSection(
                title: "\("export.cat.growth".l)",
                headers: ["export.col.date".l, "export.col.weight".l, "export.col.height".l, "export.col.head".l],
                rows: growths.map { e in
                    [dateFmt.string(from: e.date),
                     e.weightKg.map { ReportFormat.kg($0) } ?? "—",
                     e.heightCm.map { ReportFormat.cm($0) } ?? "—",
                     e.headCircumferenceCm.map { ReportFormat.cm($0) } ?? "—"]
                }
            ))
        }

        // Events table
        if categories.contains(.events) && !events.isEmpty {
            tables.append(tableSection(
                title: "\("export.cat.events".l)",
                headers: ["export.col.date".l, "export.col.time".l, "export.col.type".l, "export.col.notes".l],
                rows: events.map { e in
                    [dateFmt.string(from: e.time),
                     timeFmt.string(from: e.time),
                     e.type.displayName.l,
                     noteCell(eventNote(e))]
                }
            ))
        }

        let head = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="UTF-8">
        <style>
          /* A record, not a poster: one solid header (white on the gradient's
             light end was under 3:1), no emoji in headings, and the secondary
             grey is BBTextSecondary (#8E8E93 on white was 3.3:1). */
          body { \(PagedPDF.cssType) margin: 0; padding: 24px; color: #1C1C1E; font-size: 12px; }
          .header { background: #6F5BA8; color: white; padding: 24px; border-radius: 12px; margin-bottom: 20px; }
          .header h1 { margin: 0 0 4px; font-size: 22px; }
          .header p  { margin: 0; font-size: 13px; }
          .meta { display: flex; gap: 16px; margin-top: 8px; }
          .meta span { font-size: 11px; }
          .card { background: #F2F2F7; border-radius: 10px; padding: 16px; margin-bottom: 16px; }
          .card h2 { margin: 0 0 12px; font-size: 15px; color: #6F5BA8; }
          .stats-grid { display: flex; flex-wrap: wrap; gap: 10px; }
          .stat { background: white; border-radius: 8px; padding: 10px 14px; min-width: 80px; }
          .stat .val { display: block; font-size: 18px; font-weight: 700; color: #1C1C1E; }
          .stat .lbl { display: block; font-size: 10px; color: #6B647C; margin-top: 2px; }
          table { width: 100%; table-layout: fixed; border-collapse: collapse; margin-bottom: 4px; }
          th { background: #6F5BA8; color: white; padding: 7px 10px; text-align: left; font-size: 11px; }
          th:first-child { border-radius: 6px 0 0 0; }
          th:last-child  { border-radius: 0 6px 0 0; }
          td { padding: 6px 10px; border-bottom: 1px solid #E5E5EA; font-size: 11px; word-wrap: break-word; }
          tr:last-child td { border-bottom: none; }
          tr:nth-child(even) td { background: #F9F9FB; }
          .footer { text-align: center; color: #6B647C; font-size: 10px; margin-top: 24px; }
        </style>
        </head>
        <body>
        """
        let header = """
          <div class="header">
            <h1>\(htmlEscape("brand.name".l)) — \(htmlEscape(babyName))</h1>
            <p>\("export.pdf.subtitle".l)</p>
            <div class="meta">
              <span>\(rangeLabel)</span>
              <span>\(ageDesc)</span>
              <span>\(generatedDate)</span>
            </div>
          </div>
        """
        let footer = "<div class=\"footer\">\(htmlEscape(String(format: "export.generated_by_fmt".l, "brand.name".l, generatedDate)))</div>"
        return PagedPDF.Document(head: head, items: [.block(header)] + summary + tables + [.block(footer)])
    }

    /// A user-supplied value ready for the PDF's HTML: HTML-significant characters
    /// escaped and no emoji (`PagedPDF.withoutEmoji`). `&` must be replaced first
    /// so already-escaped entities aren't double-encoded.
    static func htmlEscape(_ raw: String) -> String {
        PagedPDF.withoutEmoji(raw)
           .replacingOccurrences(of: "&", with: "&amp;")
           .replacingOccurrences(of: "<", with: "&lt;")
           .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// A name as part of a file name: no path separators or control characters,
    /// trimmed, at most 60 characters, and the default name when blank. It
    /// takes the name only, never a whole file name: cut to 60 there, a long
    /// name pushed the date and the extension out.
    static func fileNamePart(_ raw: String) -> String {
        // The joiners and the emoji tags are format characters too, but they
        // hold an emoji family or a regional flag together: without them a
        // family in the name was written as four separate people. The bidi
        // overrides stay out, as they could turn «.pdf» around in Files.
        var banned = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        banned.remove(charactersIn: "\u{200C}\u{200D}")
        banned.remove(charactersIn: Unicode.Scalar(0xE0020)!...Unicode.Scalar(0xE007F)!)
        let cleaned = String(String.UnicodeScalarView(raw.unicodeScalars.filter { !banned.contains($0) }))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "baby.default_name".l
            : String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces)
    }

    /// The file name `build` makes around `name`, within the 255 UTF-8 bytes a
    /// file name may take. Only the name gives way, from its end, so the date
    /// and the extension stay: 60 family emoji are 1,500 bytes, and a file
    /// named that long is never written.
    static func fileName(fitting name: String, _ build: (String) -> String) -> String {
        let budget = 255 - build("").utf8.count
        var kept = ""
        for character in name {
            guard kept.utf8.count + character.utf8.count <= budget else { break }
            kept.append(character)
        }
        kept = kept.trimmingCharacters(in: .whitespaces)
        return build(kept.isEmpty ? "baby.default_name".l : kept)
    }

    /// The day inside a file name, «2026-11-05»: digits only, whatever the app
    /// language or the phone's calendar.
    static func fileDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// «All entries – Mia – 2026-11-05.pdf»: it reads apart from the report's
    /// «Pediatrician report – Mia – 2026-11-05.pdf» in Files and Mail.
    static func pdfFileName(babyName: String, date: Date) -> String {
        let day = fileDate(date)
        return fileName(fitting: fileNamePart(babyName)) {
            String(format: "export.file_fmt".l, $0, day) + ".pdf"
        }
    }

    /// «Mia_Rose_2026-11-05_feeding.csv», `file` being the table's own name.
    static func csvFileName(babyName: String, date: Date, file: String) -> String {
        let day = fileDate(date)
        return fileName(fitting: fileSlug(babyName)) { "\($0)_\(day)_\(file)" }
    }

    /// The name inside the export's file names, as typed («Mia_Rose»): spaces
    /// become underscores, the case stays.
    static func fileSlug(_ raw: String) -> String {
        fileNamePart(raw).replacingOccurrences(of: " ", with: "_")
    }

    /// Whole minutes as the app writes a duration («45 min», «1 h 15 min»),
    /// glued so a cell never wraps «5 / min».
    private static func minutesText(_ minutes: Int) -> String {
        DurationText.minutes(minutes)
    }

    /// Entries per day over the FINISHED days `[start, startOfToday)`, divided
    /// by the days that have an entry of this kind: the pediatrician report's
    /// rule, so the export and the report never disagree. A half-lived today
    /// stays out, or opening the export mid-morning would drag the figure down.
    /// For `.all` the span starts on the earliest entry's day. A bounded range
    /// starts at «now minus a week» mid-day, so its first day is cut and
    /// starts at the next midnight instead. Nil without a finished day holding
    /// an entry.
    static func averagePerDay(dates: [Date], range: ExportDateRange, now: Date = Date(),
                              calendar: Calendar = .current) -> Double? {
        let start: Date
        if let bounded = range.startDate(now: now) {
            let day = calendar.startOfDay(for: bounded)
            start = day == bounded ? day : calendar.date(byAdding: .day, value: 1, to: day)!
        } else if let earliest = dates.min() {
            start = calendar.startOfDay(for: earliest)
        } else {
            return nil
        }
        let todayStart = calendar.startOfDay(for: now)
        guard start < todayStart else { return nil }
        let period = PeriodSummary.make(start: start, end: todayStart,
                                        input: PeriodSummary.Input(feeds: dates), calendar: calendar)
        guard period.daysWithEntries > 0 else { return nil }
        return Double(period.totalFeeds) / Double(period.daysWithEntries)
    }

    /// A medication's name and dose as logged, ahead of its note, in the one
    /// notes cell: the table keeps its columns.
    static func eventNote(_ event: CustomEvent) -> String? {
        guard event.type == .medication else { return event.notes }
        let text = MedicationFormat.eventRow(typeWord: "", isDose: false, name: event.medicationName,
                                             dose: event.medicationDose, note: event.notes).subtitle
        return text.isEmpty ? nil : text
    }

    /// A note the page can print, or the dash an absent one gets.
    private static func noteCell(_ notes: String?) -> String {
        guard let notes, !PagedPDF.isBlank(PagedPDF.withoutEmoji(notes)) else { return "—" }
        return notes
    }

    /// A card per table; a page the table continues on opens the card again, with the head.
    private static func tableSection(title: String, headers: [String], rows: [[String]]) -> PagedPDF.Item {
        let ths = headers.map { "<th>\(htmlEscape($0))</th>" }.joined()
        let table = "<table>\(columnWidths(headers: headers, rows: rows))<thead><tr>\(ths)</tr></thead><tbody>"
        return .rows(.init(
            opening: "<div class=\"card\"><h2>\(title)</h2>\(table)",
            continuation: { _ in "<div class=\"card\">\(table)" },
            closing: "</tbody></table></div>",
            rows: rows.map { row in "<tr>" + row.map { "<td>\(htmlEscape($0))</td>" }.joined() + "</tr>" }))
    }

    /// Every page prints its own table and would size its own columns, so the widths
    /// come from all the rows: each column's share follows its longest text. The cap
    /// keeps one long note from squeezing the rest; the note wraps instead.
    static func columnWidths(headers: [String], rows: [[String]]) -> String {
        let lengths = headers.indices.map { column in
            min(32, rows.map { $0[column].count }.reduce(headers[column].count, max)) + 3
        }
        let total = lengths.reduce(0, +)
        let columns = lengths.map { "<col style=\"width: \(String(format: "%.1f", Double($0) * 100 / Double(total)))%\">" }
        return "<colgroup>\(columns.joined())</colgroup>"
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

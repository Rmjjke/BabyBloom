import UIKit

/// The pediatrician report as a PDF (design m2-doctor-report § 5). A pure HTML
/// build over the SAME `DoctorReportSummary` and the SAME `ReportFormat` /
/// `WeeklyFormat` helpers and keys the screen's cards use, so the PDF cannot
/// disagree with the screen; `DoctorReportPDFTests` pins that as strings.
///
/// Its own template and renderer: the existing export keeps its layout (gradient
/// header, tints), none of which the report may carry.
enum DoctorReportPDF {

    // MARK: Colours

    // The PDF renderer cannot read the Asset Catalog, so these mirror the LIGHT
    // colorsets (CLAUDE.md theming). The page is always light, whatever the
    // phone's appearance. Contrast figures are in design § 5.
    private static let text = "#2D2837"        // BBTextPrimary
    private static let secondary = "#746D85"   // BBTextSecondary
    private static let primary = "#6F5BA8"     // BBPrimary: headings and the rule
    private static let tableFill = "#F6F3FB"   // BBBackground: table header fill
    private static let rowRule = "#E5E5EA"     // decorative

    private static func esc(_ raw: String) -> String { ExportGenerator.htmlEscape(raw) }

    // MARK: HTML

    static func html(summary: DoctorReportSummary, baby: Baby, openQuestions: [String],
                     periodStart: Date, now: Date) -> String {
        var body = header(summary: summary, baby: baby, periodStart: periodStart, now: now)
        body += growth(summary: summary, periodStart: periodStart, now: now)
        if summary.showsNewPeriodCard {
            // One line in place of three empty sections (design § 5, «visit today»).
            body += "<p class=\"muted\">\(esc("report.pdf.no_entries".l))</p>"
        } else {
            body += feeding(summary.feeding, periodStart: periodStart, isShort: summary.isShort)
            body += sleep(summary.sleep, periodStart: periodStart, isShort: summary.isShort, now: now)
            body += diapers(summary.diapers, periodStart: periodStart, isShort: summary.isShort)
        }
        body += questions(openQuestions)
        body += "<p class=\"foot\">\(esc("report.footnote".l))</p>"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // CSS sizes are px like the existing export; whether UIMarkupTextPrintFormatter
    // renders them at the design's point sizes is checked on the first real render
    // (design § 5), and the CSS is scaled, not the targets.
    private static var css: String {
        """
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; margin: 0; color: \(text); font-size: 11px; line-height: 1.45; background: #FFFFFF; }
        h1 { font-size: 18px; font-weight: 600; margin: 0 0 4px; color: \(text); }
        h2 { font-size: 13px; font-weight: 600; margin: 16px 0 6px; color: \(primary); page-break-after: avoid; }
        .name { font-size: 14px; font-weight: 600; margin: 0 0 6px; }
        .rule { border: 0; border-top: 1px solid \(primary); margin: 10px 0 0; }
        .sec { page-break-inside: avoid; }
        table.facts { width: 100%; border-collapse: collapse; }
        table.facts td { width: 50%; padding: 1px 12px 1px 0; vertical-align: top; }
        p { margin: 3px 0; }
        .muted, .sub { color: \(secondary); }
        b { font-weight: 600; }
        table.weighings { width: 100%; border-collapse: collapse; margin-top: 6px; }
        table.weighings thead { display: table-header-group; }
        table.weighings th { background: \(tableFill); color: \(text); text-align: left; font-weight: 600; padding: 4px 8px; }
        table.weighings td { padding: 4px 8px; border-bottom: 1px solid \(rowRule); }
        table.weighings tr { page-break-inside: avoid; }
        ol { margin: 3px 0; padding-left: 20px; }
        li { margin: 2px 0; }
        .foot { font-size: 10px; color: \(secondary); margin-top: 18px; }
        """
    }

    // MARK: Header

    private static func header(summary: DoctorReportSummary, baby: Baby,
                               periodStart: Date, now: Date) -> String {
        var cells: [String] = [
            String(format: "report.pdf.birth_fmt".l, fullDate(baby.birthDate)),
            String(format: "report.pdf.sex_fmt".l, baby.gender.displayName.l),
            String(format: "report.pdf.age_fmt".l, ageText(baby, now: now)),
        ]
        // The due date and corrected age only exist for a preterm baby.
        if baby.isPreterm {
            cells.append(String(format: "report.pdf.due_fmt".l, fullDate(baby.correctedBirthDate)))
        }

        var html = "<h1>\(esc("report.pdf.title".l))</h1>"
        if !baby.name.isEmpty { html += "<p class=\"name\">\(esc(baby.name))</p>" }
        html += twoColumns(cells.map { esc($0) })
        html += "<p>\(esc(String(format: "report.pdf.period_fmt".l, periodRange(periodStart, now: now), periodLength(summary))))</p>"
        html += "<p>\(esc(String(format: "report.pdf.date_fmt".l, fullDate(now))))</p>"
        html += "<hr class=\"rule\">"
        return html
    }

    /// The screen's age line: corrected age beside the real one for a preterm baby.
    private static func ageText(_ baby: Baby, now: Date) -> String {
        let age = Baby.describeAge(from: baby.birthDate, to: now)
        guard baby.isPreterm else { return age }
        return String(format: "report.age_corrected_fmt".l, age,
                      Baby.describeAge(from: baby.correctedBirthDate, to: now))
    }

    /// A date in a record read later always carries its year, unlike the screen's rows.
    private static func fullDate(_ date: Date) -> String { ReportFormat.glued(date.appDayMonthYear) }

    private static func periodRange(_ start: Date, now: Date) -> String {
        // A visit today: «2 Nov 2026», not «2 Nov – 2 Nov 2026».
        guard !Calendar.current.isDate(start, inSameDayAs: now) else { return fullDate(now) }
        return String(format: "weekly.range_fmt".l, ReportFormat.date(start, now: now), fullDate(now))
    }

    private static func periodLength(_ summary: DoctorReportSummary) -> String {
        summary.periodDays == 0
            ? "report.period_today".l
            : "\(summary.periodDays)\(ReportFormat.nbsp)\(summary.periodDays.dayWord)"
    }

    // MARK: Growth

    private static func growth(summary: DoctorReportSummary, periodStart: Date, now: Date) -> String {
        let growth = summary.growth
        var html = "<div class=\"sec\"><h2>\(esc("nav.growth".l))</h2>"
        if growth.latestWeight == nil {
            html += "<p class=\"muted\">\(esc("report.empty_growth".l))</p>"
        }
        var cells: [String] = []
        if let weight = growth.latestWeight {
            cells.append(row("report.weight_fmt", ReportFormat.kg(weight.value),
                             suffix: String(format: "percentile.as_of_fmt".l, ReportFormat.date(weight.date, now: now))))
            cells += percentile(growth.weightPercentile, format: "report.percentile_weight_fmt")
        }
        if let height = growth.latestHeight {
            cells.append(row("report.height_fmt", ReportFormat.cm(height.value),
                             suffix: ReportFormat.date(height.date, now: now)))
            cells += percentile(growth.heightPercentile, format: "report.percentile_height_fmt")
        }
        if let head = growth.latestHead {
            // The key carries its unit («Head: %@ cm»); glue it like ReportFormat does.
            cells.append(row("growth.head_fmt", head.value.appDecimal(1), suffix: ReportFormat.date(head.date, now: now),
                             glueUnit: true))
        }
        // A new period just began: the period rows go, the standing facts stay.
        if !summary.showsNewPeriodCard, let change = growth.change {
            let since = String(format: "report.change_since_fmt".l, ReportFormat.date(change.baseDate, now: now), "%@")
            cells.append(row(format: since, ReportFormat.grams(change.grams)))
        }
        html += twoColumns(cells)
        if let birth = atBirth(growth) { html += "<p class=\"sub\">\(esc(birth))</p>" }
        html += "</div>"

        if !summary.showsNewPeriodCard && !growth.weighings.isEmpty {
            html += weighingsTable(growth.weighings, now: now)
        }
        return html
    }

    private static func percentile(_ rowKind: DoctorReportSummary.PercentileRow, format: String) -> [String] {
        switch rowKind {
        case .reading(let reading):
            // The badge, never the clamped number: past the chart it reads «> 97».
            return [row(format, ReportFormat.glued(reading.badge))]
        case .beforeDueDate:
            return ["<span class=\"sub\">\(esc("percentile.before_due_date".l))</span>"]
        case .outOfRange:
            return ["<span class=\"sub\">\(esc("percentile.out_of_range".l))</span>"]
        case .none:
            return []
        }
    }

    private static func atBirth(_ growth: DoctorReportSummary.Growth) -> String? {
        let parts = [growth.atBirthWeightKg.map(ReportFormat.kg),
                     growth.atBirthHeightCm.map(ReportFormat.cm)].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return String(format: "report.at_birth_fmt".l, parts.joined(separator: ReportFormat.joiner))
    }

    /// Newest first, as the summary hands them. `thead` repeats on a page break.
    private static func weighingsTable(_ weighings: [DoctorReportSummary.Weighing], now: Date) -> String {
        let heads = ["export.col.date", "export.col.weight", "export.col.height", "export.col.head"]
            .map { "<th>\(esc($0.l))</th>" }.joined()
        let rows = weighings.map { weighing in
            let cells = [ReportFormat.date(weighing.date, now: now), ReportFormat.kg(weighing.weightKg),
                         weighing.heightCm.map(ReportFormat.cm) ?? "", weighing.headCm.map(ReportFormat.cm) ?? ""]
            return "<tr>" + cells.map { "<td>\(esc($0))</td>" }.joined() + "</tr>"
        }.joined()
        return "<p class=\"sub\">\(esc("report.weighings".l))</p><table class=\"weighings\"><thead><tr>\(heads)</tr></thead><tbody>\(rows)</tbody></table>"
    }

    // MARK: Feeding, sleep, diapers

    private static func feeding(_ feeding: DoctorReportSummary.Feeding?, periodStart: Date, isShort: Bool) -> String {
        guard let feeding else { return emptySection("tab.feeding", "report.empty_feeding_fmt", periodStart) }
        var cells: [String] = []
        if isShort {
            cells.append(row("report.feeds_count_fmt", "\(feeding.totalFeeds)"))
        } else if let perDay = feeding.feedsPerDay {
            cells.append(row("weekly.feeds_fmt", WeeklyFormat.perDay(perDay)))
        }
        if !feeding.byType.isEmpty {
            cells.append(row("report.feeds_by_type_fmt", ReportFormat.countList(feeding.byType.map {
                ReportFormat.countItem(name: $0.type == .breast ? "report.type_breast".l : $0.type.displayName.l,
                                       count: $0.count)
            })))
        }
        if let ml = feeding.bottleMLPerDay { cells.append(row("report.bottle_a_day_fmt", ReportFormat.ml(ml))) }
        if let average = feeding.breastfeedAverage {
            cells.append(row("report.breastfeed_avg_fmt", ReportFormat.duration(average)))
        }
        return section("tab.feeding", cells, days: feeding.days, isShort: isShort)
    }

    private static func sleep(_ sleep: DoctorReportSummary.Sleep?, periodStart: Date, isShort: Bool,
                              now: Date) -> String {
        guard let sleep else { return emptySection("tab.sleep", "report.empty_sleep_fmt", periodStart) }
        var cells: [String] = []
        if isShort {
            cells.append(row("report.sleep_total_fmt", ReportFormat.duration(sleep.total)))
        } else if let perDay = sleep.perDay {
            cells.append(row("weekly.sleep_fmt", ReportFormat.duration(perDay)))
        }
        if let longest = sleep.longest {
            cells.append(row("weekly.longest_sleep_fmt", ReportFormat.duration(longest),
                             suffix: sleep.longestStart.map { ReportFormat.date($0, now: now) }))
        }
        return section("tab.sleep", cells, days: sleep.days, isShort: isShort)
    }

    private static func diapers(_ diapers: DoctorReportSummary.Diapers?, periodStart: Date, isShort: Bool) -> String {
        guard let diapers else { return emptySection("tab.diapers", "report.empty_diapers_fmt", periodStart) }
        var cells: [String] = []
        if isShort {
            cells.append(row("report.wet_count_fmt", "\(diapers.wetCount)"))
            cells.append(row("report.dirty_count_fmt", "\(diapers.dirtyCount)"))
        } else {
            if let wet = diapers.wetPerDay { cells.append(row("report.wet_a_day_fmt", WeeklyFormat.perDay(wet))) }
            if let dirty = diapers.dirtyPerDay { cells.append(row("report.dirty_a_day_fmt", WeeklyFormat.perDay(dirty))) }
        }
        // Names and counts only: no swatch, no warning (plan v2 decision 9).
        if !diapers.colors.isEmpty {
            cells.append(row("report.stool_colors_fmt", ReportFormat.countList(diapers.colors.map {
                ReportFormat.countItem(name: $0.color.displayName.l, count: $0.count)
            })))
        }
        return section("tab.diapers", cells, days: diapers.days, isShort: isShort)
    }

    private static func section(_ titleKey: String, _ cells: [String],
                                days: DoctorReportSummary.Days, isShort: Bool) -> String {
        var html = "<div class=\"sec\"><h2>\(esc(titleKey.l))</h2>" + twoColumns(cells)
        // Short periods print raw counts and no days line (R3.3).
        if days.showsLine && !isShort {
            html += "<p class=\"sub\">\(esc(String(format: "report.days_logged_fmt".l, days.withEntries, days.counted)))</p>"
        }
        return html + "</div>"
    }

    private static func emptySection(_ titleKey: String, _ emptyKey: String, _ periodStart: Date) -> String {
        "<div class=\"sec\"><h2>\(esc(titleKey.l))</h2><p class=\"muted\">"
            + "\(esc(String(format: emptyKey.l, fullDate(periodStart))))</p></div>"
    }

    // MARK: Questions

    /// The OPEN questions at the moment of making the PDF, verbatim and numbered.
    /// Absent when none; asked questions and visit notes belong to a past visit.
    private static func questions(_ open: [String]) -> String {
        guard !open.isEmpty else { return "" }
        let items = open.map { "<li>\(esc($0))</li>" }.joined()
        return "<div class=\"sec\"><h2>\(esc("report.pdf.questions".l))</h2><ol>\(items)</ol></div>"
    }

    // MARK: Row building

    /// «label <b>value</b> tail», split at the `%@` exactly as the screen's
    /// `ReportRow` does, so the word order stays the translator's.
    private static func row(_ key: String, _ value: String, suffix: String? = nil, glueUnit: Bool = false) -> String {
        row(format: key.l, value, suffix: suffix, glueUnit: glueUnit)
    }

    private static func row(format: String, _ value: String, suffix: String? = nil, glueUnit: Bool = false) -> String {
        let parts = format.replacingOccurrences(of: "%d", with: "%@").components(separatedBy: "%@")
        let label = parts.first ?? ""
        var tail = parts.dropFirst().joined()
        if glueUnit { tail = tail.replacingOccurrences(of: " ", with: ReportFormat.nbsp) }
        var html = "\(esc(label))<b>\(esc(value))</b>\(esc(tail))"
        if let suffix { html += "<span class=\"sub\">\(esc(ReportFormat.joiner + suffix))</span>" }
        return html
    }

    /// Cells are already escaped. A table, not CSS columns or grid, which the
    /// print formatter's engine handles unreliably.
    private static func twoColumns(_ cells: [String]) -> String {
        guard !cells.isEmpty else { return "" }
        var rows = ""
        for index in stride(from: 0, to: cells.count, by: 2) {
            let right = index + 1 < cells.count ? cells[index + 1] : ""
            rows += "<tr><td>\(cells[index])</td><td>\(right)</td></tr>"
        }
        return "<table class=\"facts\">\(rows)</table>"
    }

    // MARK: PDF

    static func data(summary: DoctorReportSummary, baby: Baby, openQuestions: [String],
                     periodStart: Date, now: Date) -> Data {
        let html = html(summary: summary, baby: baby, openQuestions: openQuestions,
                        periodStart: periodStart, now: now)
        let footer = [ "brand.name".l, baby.name, periodRange(periodStart, now: now) ]
            .filter { !$0.isEmpty }.joined(separator: " · ")
        return render(html: html, footerLeft: footer)
    }

    /// «<report.pdf.file_fmt>.pdf», the name cleaned as every export's is.
    static func fileName(babyName: String, date: Date) -> String {
        let formatter = DateFormatter()
        // Digits only, whatever the app language or the phone's calendar.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let base = String(format: "report.pdf.file_fmt".l, ExportGenerator.fileNamePart(babyName),
                          formatter.string(from: date))
        return ExportGenerator.fileNamePart(base) + ".pdf"
    }

    /// Same page setup as `ExportGenerator.renderPDF` (A4, margins 36); its own
    /// renderer because the report needs a footer on every page.
    private static func render(html: String, footerLeft: String) -> Data {
        let renderer = ReportPageRenderer(footerLeft: footerLeft)
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)

        let pageSize = CGSize(width: 595.2, height: 841.8)
        let margin: CGFloat = 36
        let printable = CGRect(x: margin, y: margin,
                               width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)
        renderer.setValue(NSValue(cgRect: CGRect(origin: .zero, size: pageSize)), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, CGRect(origin: .zero, size: pageSize), nil)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        for page in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }

    /// Draws «<brand> · <name> · <period>» left and «Page N of M» right on every page.
    private final class ReportPageRenderer: UIPrintPageRenderer {
        private let footerLeft: String

        init(footerLeft: String) {
            self.footerLeft = footerLeft
            super.init()
            // Reserved inside the printable rect, so the body never runs under it.
            footerHeight = 24
        }

        override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
            // 9 pt page furniture in the secondary colour (design § 5).
            let font = UIFont.systemFont(ofSize: 9)
            let color = UIColor(hex: DoctorReportPDF.secondary)
            let left = NSMutableParagraphStyle()
            left.lineBreakMode = .byTruncatingTail
            let right = NSMutableParagraphStyle()
            right.alignment = .right

            let pageText = String(format: "report.pdf.page_fmt".l, pageIndex + 1, numberOfPages)
            let pageWidth: CGFloat = 80
            let line = CGRect(x: footerRect.minX, y: footerRect.midY - 6, width: footerRect.width, height: 12)
            (footerLeft as NSString).draw(
                in: CGRect(x: line.minX, y: line.minY, width: line.width - pageWidth - 8, height: line.height),
                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: left])
            (pageText as NSString).draw(
                in: CGRect(x: line.maxX - pageWidth, y: line.minY, width: pageWidth, height: line.height),
                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: right])
        }
    }
}

private extension UIColor {
    /// «#RRGGBB» → colour, for the PDF's hex constants.
    convenience init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}

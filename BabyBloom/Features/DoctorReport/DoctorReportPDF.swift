import UIKit

/// The pediatrician report as a PDF. A pure HTML
/// build over the SAME `DoctorReportSummary` and the SAME `ReportFormat` /
/// `WeeklyFormat` helpers and keys the screen's cards use, so the PDF cannot
/// disagree with the screen; `DoctorReportPDFTests` pins that as strings.
///
/// Its own template: the existing export keeps its layout (gradient header,
/// tints), none of which the report may carry. `PagedPDF` makes the pages.
enum DoctorReportPDF {

    // MARK: Colours

    // The PDF renderer cannot read the Asset Catalog, so these mirror the LIGHT
    // colorsets (CLAUDE.md theming). The page is always light, whatever the
    // phone's appearance.
    private static let text = "#2D2837"        // BBTextPrimary
    private static let secondary = "#6B647C"   // BBTextSecondary
    private static let primary = "#6F5BA8"     // BBPrimary: headings and the rule
    private static let tableFill = "#F6F3FB"   // BBBackground: table header fill
    private static let rowRule = "#E5E5EA"     // decorative

    private static func esc(_ raw: String) -> String { ExportGenerator.htmlEscape(raw) }

    // MARK: HTML

    /// The whole report as one document, unbroken.
    static func html(summary: DoctorReportSummary, baby: Baby, openQuestions: [String],
                     periodStart: Date, now: Date) -> String {
        document(summary: summary, baby: baby, openQuestions: openQuestions, periodStart: periodStart, now: now).html
    }

    private static func document(summary: DoctorReportSummary, baby: Baby, openQuestions: [String],
                                 periodStart: Date, now: Date) -> PagedPDF.Document {
        var items: [PagedPDF.Item] = [.block(header(summary: summary, baby: baby, periodStart: periodStart, now: now))]
        items += growth(summary: summary, periodStart: periodStart, now: now)
        if summary.showsNewPeriodCard {
            // One line in place of three empty sections: a visit started the
            // period and nothing was logged since.
            items.append(.block("<p class=\"muted\">\(esc("report.pdf.no_entries".l))</p>"))
        } else {
            items.append(.block(feeding(summary.feeding, periodStart: periodStart)))
            items.append(.block(sleep(summary.sleep, periodStart: periodStart, now: now)))
            items.append(.block(diapers(summary.diapers, periodStart: periodStart)))
            if let medications = medications(summary.medications, now: now) { items.append(medications) }
        }
        if let questions = questions(openQuestions) { items.append(questions) }
        // After the questions, which are what the visit is for; a block of its
        // own, so a short period keeps its one page.
        if let chart = weightChart(summary.growth.weightChart, now: now) { items.append(chart) }
        items.append(.block("<p class=\"foot\">\(esc("report.footnote".l))</p>"))

        let head = """
        <!DOCTYPE html>
        <html lang="\(LocalizationManager.shared.language.rawValue)">
        <head>
        <meta charset="utf-8">
        <style>
        \(css)
        </style>
        </head>
        <body>
        """
        return PagedPDF.Document(head: head, items: items)
    }

    // CSS sizes are px like the existing export; whether UIMarkupTextPrintFormatter
    // renders them at the design's point sizes is checked on the first real render,
    // and the CSS is scaled, not the targets.
    private static var css: String {
        """
        body { \(PagedPDF.cssType) margin: 0; color: \(text); font-size: 11px; line-height: 1.45; background: #FFFFFF; }
        h1 { font-size: 18px; font-weight: 600; margin: 0 0 4px; color: \(text); }
        h2 { font-size: 13px; font-weight: 600; margin: 16px 0 6px; color: \(primary); }
        .name { font-size: 14px; font-weight: 600; margin: 0 0 6px; }
        .rule { border: 0; border-top: 1px solid \(primary); margin: 10px 0 0; }
        table.facts { width: 100%; border-collapse: collapse; }
        table.facts td { width: 50%; padding: 1px 12px 1px 0; vertical-align: top; }
        p { margin: 3px 0; }
        .muted, .sub { color: \(secondary); }
        b { font-weight: 600; }
        table.weighings { width: 100%; table-layout: fixed; border-collapse: collapse; margin-top: 6px; }
        table.weighings th { background: \(tableFill); color: \(text); text-align: left; font-weight: 600; padding: 4px 8px; }
        table.weighings td { padding: 4px 8px; border-bottom: 1px solid \(rowRule); }
        ol { margin: 3px 0; padding-left: 20px; }
        li { margin: 2px 0; }
        .foot { font-size: 10px; color: \(secondary); margin-top: 18px; }
        .curves { font-size: 10px; font-weight: 400; color: \(secondary); }
        svg text { font-size: \(String(format: "%.3f", Double(Chart.labelSize)))px; fill: \(secondary); \(PagedPDF.cssType) }
        """
    }

    // MARK: Weight for age

    /// The chart's frame, in page points. The formatter lays the 523.2 pt
    /// printable width out as 612 CSS px, so the svg takes the whole width
    /// with a 523.2-wide viewBox — one user unit is one page point, x 0 the
    /// left margin — and a CSS height scaled by the same factor.
    private enum Chart {
        static let width: CGFloat = 523.2
        static let height: CGFloat = 111.5
        static let cssPerPoint: CGFloat = 612 / 523.2
        static let plotLeft: CGFloat = 28
        static let plotRight: CGFloat = 501
        static let plotTop: CGFloat = 6
        static let plotBottom: CGFloat = 96
        /// The heading's 10 px span in points: every label prints at its size.
        /// A label's size is set in user units, which are points here.
        static let labelSize: CGFloat = 10 / cssPerPoint
        /// Page x 60…541: the x labels never pass the y labels' column or the
        /// curve numbers.
        static let labelMin: CGFloat = 24
        static let labelMax: CGFloat = 505
        static let xLabelTop: CGFloat = 100
        static let tickLength: CGFloat = 3
        static let gap: CGFloat = 4
    }

    /// An x label of the chart, placed: the tick it names, its left edge and
    /// width in points from the left margin.
    struct ChartLabel: Equatable {
        let date: Date
        let text: String
        let left: CGFloat
        let width: CGFloat
    }

    /// Every chart label's font; the x labels are measured in it.
    static var chartLabelFont: UIFont { PagedPDF.font(ofSize: Chart.labelSize) }

    /// The x axis as printed: each date centred on its tick, then moved inside
    /// the label bounds rather than dropped — the window's first date is the
    /// one the doctor reads the line from. Labels that would touch take their
    /// ticks with them, so every tick drawn carries its date: first the month
    /// marks that would sit on the start's label, then every second mark,
    /// until the rest clear. Year-dated labels, twice as wide, are what need it.
    static func chartXLabels(_ chart: WeightForAgeChart, now: Date,
                             width: (String) -> CGFloat) -> [ChartLabel] {
        func place(_ tick: Date) -> ChartLabel {
            let text = ReportFormat.date(tick, now: now)
            let textWidth = width(text)
            let left = min(max(chartX(tick, chart) - textWidth / 2, Chart.labelMin), Chart.labelMax - textWidth)
            return ChartLabel(date: tick, text: text, left: left, width: textWidth)
        }
        func apart(_ before: ChartLabel, _ after: ChartLabel) -> Bool {
            after.left >= before.left + before.width + Chart.gap
        }
        guard let first = chart.ticks.first else { return [] }
        let start = place(first)
        var marks = Array(chart.ticks.dropFirst().map(place).drop { !apart(start, $0) })
        while !zip([start] + marks, marks).allSatisfy({ apart($0.0, $0.1) }) {
            marks = marks.count > 1 ? stride(from: 0, to: marks.count, by: 2).map { marks[$0] } : []
        }
        return [start] + marks
    }

    private static func chartX(_ date: Date, _ chart: WeightForAgeChart) -> CGFloat {
        let domain = chart.window.domain
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let share = span > 0 ? date.timeIntervalSince(domain.lowerBound) / span : 0
        return Chart.plotLeft + CGFloat(share) * (Chart.plotRight - Chart.plotLeft)
    }

    private static func chartY(_ kg: Double, _ chart: WeightForAgeChart) -> CGFloat {
        let range = chart.kgRange
        let share = (kg - Double(range.lowerBound)) / Double(range.upperBound - range.lowerBound)
        return Chart.plotBottom - CGFloat(share) * (Chart.plotBottom - Chart.plotTop)
    }

    /// The weight-for-age section: an inline svg, which the formatter draws as
    /// vectors with every label left as text.
    private static func weightChart(_ chart: WeightForAgeChart?, now: Date) -> PagedPDF.Item? {
        guard let chart else { return nil }
        let font = chartLabelFont
        // An svg label sits on its baseline: half the cap height below a line
        // centres the digits on it.
        let midCap = font.capHeight / 2
        func n(_ value: CGFloat) -> String { String(format: "%.2f", Double(value)) }
        func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ color: String) -> String {
            "<line x1=\"\(n(x1))\" y1=\"\(n(y1))\" x2=\"\(n(x2))\" y2=\"\(n(y2))\" stroke=\"\(color)\" stroke-width=\"0.5\"/>"
        }

        var svg = ""
        for kg in stride(from: chart.kgRange.lowerBound, through: chart.kgRange.upperBound, by: chart.kgStep) {
            let y = chartY(Double(kg), chart)
            svg += line(Chart.plotLeft, y, Chart.plotRight, y, rowRule)
            svg += "<text x=\"\(n(Chart.labelMin))\" y=\"\(n(y + midCap))\" text-anchor=\"end\">"
                + "\(esc(Units.kg("\(kg)")))</text>"
        }
        let width = { (text: String) in (text as NSString).size(withAttributes: [.font: font]).width }
        for label in chartXLabels(chart, now: now, width: width) {
            let x = chartX(label.date, chart)
            svg += line(x, Chart.plotBottom, x, Chart.plotBottom + Chart.tickLength, secondary)
            svg += "<text x=\"\(n(label.left))\" y=\"\(n(Chart.xLabelTop + font.ascender))\">\(esc(label.text))</text>"
        }

        let curves: [(KeyPath<WHOCorridor.Sample, Double>, String, String)] = [
            (\.low, "3", " stroke-width=\"0.75\" stroke-dasharray=\"3 2\""),
            (\.mid, "50", " stroke-width=\"1\""),
            (\.high, "97", " stroke-width=\"0.75\" stroke-dasharray=\"3 2\""),
        ]
        for (value, centile, stroke) in curves {
            let points = chart.curves.map {
                (chartX(chart.window.date(atAgeDays: $0.ageDays), chart), chartY($0[keyPath: value], chart))
            }
            svg += "<polyline points=\"\(points.map { "\(n($0.0)),\(n($0.1))" }.joined(separator: " "))\" "
                + "fill=\"none\" stroke=\"\(secondary)\"\(stroke)/>"
            if let end = points.last {
                svg += "<text x=\"\(n(end.0 + Chart.gap))\" y=\"\(n(end.1 + midCap))\">\(centile)</text>"
            }
        }

        // The child last, over the curves; the dots after the line, so no
        // stretch of line runs over a dot.
        let child = chart.points.map { (chartX($0.date, chart), chartY($0.weightKg, chart)) }
        svg += "<polyline points=\"\(child.map { "\(n($0.0)),\(n($0.1))" }.joined(separator: " "))\" fill=\"none\" "
            + "stroke=\"\(primary)\" stroke-width=\"1.5\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>"
        for (x, y) in child {
            svg += "<circle cx=\"\(n(x))\" cy=\"\(n(y))\" r=\"2.5\" fill=\"\(primary)\"/>"
        }

        let heading = "<h2>\(esc("report.pdf.chart_title".l))"
            + "<span class=\"curves\">\(esc(ReportFormat.joiner + "report.pdf.chart_curves".l))</span></h2>"
        let frame = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100%\" "
            + "height=\"\(n(Chart.height * Chart.cssPerPoint))\" viewBox=\"0 0 \(n(Chart.width)) \(n(Chart.height))\" "
            + "preserveAspectRatio=\"xMinYMin meet\" style=\"display:block\">"
        return .block("<div>\(heading)\(frame)\(svg)</svg></div>")
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
        if !PagedPDF.isBlank(esc(baby.name)) { html += "<p class=\"name\">\(esc(baby.name))</p>" }
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

    /// «Nov 2 – 20, 2026», with its year; a visit today is the one date.
    private static func periodRange(_ start: Date, now: Date) -> String {
        ReportFormat.rangeGlued(LocaleDates.dateRange(start, now, locale: LocalizationManager.shared.language.locale))
    }

    private static func periodLength(_ summary: DoctorReportSummary) -> String {
        ReportFormat.periodLength(days: summary.periodDays)
    }

    // MARK: Growth

    private static func growth(summary: DoctorReportSummary, periodStart: Date, now: Date) -> [PagedPDF.Item] {
        let growth = summary.growth
        var html = "<div><h2>\(esc("export.cat.growth".l))</h2>"
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
            // One sentence, as the screen: weight and height share it.
            if !growth.repeatsWeightNote {
                cells += percentile(growth.heightPercentile, format: "report.percentile_height_fmt")
            }
        }
        if let head = growth.latestHead {
            // The key carries its unit («Head: %@ cm»); glue it like ReportFormat does.
            cells.append(row("growth.head_fmt", head.value.appDecimal(1), suffix: ReportFormat.date(head.date, now: now),
                             glueUnit: true))
        }
        // A new period just began: the period rows go, the standing facts stay.
        if !summary.showsNewPeriodCard, let change = growth.change {
            cells.append(row(format: "report.change_since_fmt".l, at: 2,
                             filling: [ReportFormat.date(change.baseDate, now: now)], ReportFormat.grams(change.grams)))
        }
        html += twoColumns(cells)
        if let birth = atBirth(growth) { html += "<p class=\"sub\">\(esc(birth))</p>" }
        html += "</div>"

        var items: [PagedPDF.Item] = [.block(html)]
        if !summary.showsNewPeriodCard && !growth.weighings.isEmpty {
            items.append(weighingsTable(growth.weighings, now: now))
        }
        return items
    }

    private static func percentile(_ rowKind: DoctorReportSummary.PercentileRow, format: String) -> [String] {
        switch rowKind {
        case .reading(let reading):
            // The badge, never the clamped number: past the chart it reads «> 97».
            return [row(format, ReportFormat.glued(reading.badge))]
        case .beforeDueDate:
            // The doctor's wording; the screen keeps the parent's sentence.
            return ["<span class=\"sub\">\(esc("report.pdf.before_due_date".l))</span>"]
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

    /// Newest first, as the summary hands them; every page the table reaches prints
    /// its head. The columns are fixed, or each page would size its own.
    private static func weighingsTable(_ weighings: [DoctorReportSummary.Weighing], now: Date) -> PagedPDF.Item {
        let cells = weighings.map { weighing in
            [ReportFormat.date(weighing.date, now: now), ReportFormat.kg(weighing.weightKg),
             weighing.heightCm.map(ReportFormat.cm) ?? "", weighing.headCm.map(ReportFormat.cm) ?? ""]
        }
        let heads = weighingHeads.map(\.l)
        let columns = PDFColumns.colgroup(tableShares(heads: heads, rows: cells))
        let rows = cells.map { "<tr>" + $0.map { "<td>\(esc($0))</td>" }.joined() + "</tr>" }
        let table = "<table class=\"weighings\">\(columns)<thead><tr>\(headRow(heads))</tr></thead><tbody>"
        return .rows(.init(opening: "<p class=\"sub\">\(esc("report.weighings".l))</p>" + table,
                           continuation: { _ in table }, closing: "</tbody></table>", rows: rows))
    }

    static let weighingHeads = ["export.col.date", "export.col.weight", "export.col.height", "export.col.head"]
    static let medicationHeads = ["medication.report_col_name", "medication.report_col_dose",
                                  "medication.report_col_count", "medication.report_col_dates"]

    /// A report table's columns (`PDFColumns`): the full 612-px width, `th` and
    /// `td` padded 8 a side at 11 px, `th` at 600, which Helvetica Neue prints Bold.
    static func tableShares(heads: [String], rows: [[String]]) -> [CGFloat] {
        PDFColumns.shares(heads: heads, rows: rows, headFont: PagedPDF.font(ofSize: 11, bold: true),
                          cellFont: PagedPDF.font(ofSize: 11), width: 612, padding: 8)
    }

    private static func headRow(_ heads: [String]) -> String {
        heads.map { "<th>\(esc($0))</th>" }.joined()
    }

    /// Medications given in the period, a row each, names and dose text as
    /// written but for their emoji; every page the table reaches prints its
    /// head. Absent when none. The columns are fixed, or each page would size
    /// its own.
    private static func medications(_ medications: [DoctorReportSummary.Medication], now: Date) -> PagedPDF.Item? {
        guard !medications.isEmpty else { return nil }
        // A line whose dose changed takes a row per text with the name
        // repeated, so every row reads whole on whatever page it lands.
        let cells = medications.flatMap { medication -> [[String]] in
            let name = medication.name ?? "medication.report_without_name".l
            let lines = medication.texts.count > 1
                ? medication.texts.map { (MedicationFormat.reportDoseText($0.text), $0.count, $0.first, $0.last) }
                : [(medication.doseText ?? "", medication.count, medication.first, medication.last)]
            return lines.map { dose, count, first, last in
                [name, dose, "\(count)", ReportFormat.dayRange(first, last, now: now)]
            }
        }
        let heads = medicationHeads.map(\.l)
        let columns = PDFColumns.colgroup(tableShares(heads: heads, rows: cells))
        let rows = cells.map { "<tr>" + $0.map { "<td>\(esc($0))</td>" }.joined() + "</tr>" }
        let table = "<table class=\"weighings\">\(columns)<thead><tr>\(headRow(heads))</tr></thead><tbody>"
        // What was given is read as one list: a table that fits a page moves
        // to the next one whole, rather than leaving a row alone under a
        // repeated head.
        return .rows(.init(opening: "<div><h2>\(esc("medication.report_title".l))</h2>" + table,
                           continuation: { _ in "<div>" + table }, closing: "</tbody></table></div>", rows: rows,
                           keepsTogether: true))
    }

    // MARK: Feeding, sleep, diapers

    private static func feeding(_ feeding: DoctorReportSummary.Feeding?, periodStart: Date) -> String {
        guard let feeding else { return emptySection("export.cat.feeding", "report.empty_feeding_fmt", periodStart) }
        var cells: [String] = []
        if let perDay = feeding.feedsPerDay {
            cells.append(row("weekly.feeds_fmt", WeeklyFormat.perDay(perDay)))
        } else {
            cells.append(row("report.feeds_count_fmt", "\(feeding.totalFeeds)"))
        }
        if !feeding.byType.isEmpty {
            cells.append(row("report.feeds_by_type_fmt", ReportFormat.countList(feeding.byType.map {
                ReportFormat.countItem(name: $0.type.displayName.l, count: $0.count)
            })))
        }
        if let ml = feeding.bottleMLPerDay { cells.append(row("report.bottle_a_day_fmt", ReportFormat.ml(ml))) }
        if let typical = feeding.breastfeedMedian {
            cells.append(row("report.breastfeed_avg_fmt", ReportFormat.duration(typical)))
        }
        return section("export.cat.feeding", cells, days: feeding.days, averaged: feeding.averaged)
    }

    private static func sleep(_ sleep: DoctorReportSummary.Sleep?, periodStart: Date, now: Date) -> String {
        guard let sleep else { return emptySection("export.cat.sleep", "report.empty_sleep_fmt", periodStart) }
        var cells: [String] = []
        if let perDay = sleep.perDay {
            cells.append(row("weekly.sleep_fmt", ReportFormat.duration(perDay)))
        } else {
            cells.append(row("report.sleep_total_fmt", ReportFormat.duration(sleep.total)))
        }
        if let longest = sleep.longest {
            cells.append(row("weekly.longest_sleep_fmt", ReportFormat.duration(longest),
                             suffix: sleep.longestStart.map { ReportFormat.date($0, now: now) }))
        }
        return section("export.cat.sleep", cells, days: sleep.days, averaged: sleep.averaged)
    }

    private static func diapers(_ diapers: DoctorReportSummary.Diapers?, periodStart: Date) -> String {
        guard let diapers else { return emptySection("export.cat.diapers", "report.empty_diapers_fmt", periodStart) }
        var cells: [String] = []
        if let wet = diapers.wetPerDay, let dirty = diapers.dirtyPerDay {
            cells.append(row("report.wet_a_day_fmt", WeeklyFormat.perDay(wet)))
            cells.append(row("report.dirty_a_day_fmt", WeeklyFormat.perDay(dirty)))
        } else {
            cells.append(row("report.wet_count_fmt", "\(diapers.wetCount)"))
            cells.append(row("report.dirty_count_fmt", "\(diapers.dirtyCount)"))
        }
        // Names and counts only: no swatch, no warning.
        if !diapers.colors.isEmpty {
            cells.append(row("report.stool_colors_fmt", ReportFormat.countList(diapers.colors.map {
                ReportFormat.countItem(name: $0.color.displayName.l, count: $0.count)
            })))
        }
        return section("export.cat.diapers", cells, days: diapers.days, averaged: diapers.averaged)
    }

    private static func section(_ titleKey: String, _ cells: [String],
                                days: DoctorReportSummary.Days, averaged: Bool) -> String {
        var html = "<div><h2>\(esc(titleKey.l))</h2>" + twoColumns(cells)
        // The days line qualifies an average; raw counts take none.
        if days.showsLine && averaged {
            html += "<p class=\"sub\">\(esc(String(format: "report.days_logged_fmt".l, days.withEntries, days.counted)))</p>"
        }
        return html + "</div>"
    }

    private static func emptySection(_ titleKey: String, _ emptyKey: String, _ periodStart: Date) -> String {
        "<div><h2>\(esc(titleKey.l))</h2><p class=\"muted\">"
            + "\(esc(String(format: emptyKey.l, fullDate(periodStart))))</p></div>"
    }

    // MARK: Questions

    /// The OPEN questions at the moment of making the PDF, numbered, verbatim but for
    /// their emoji. Absent when none; asked questions and visit notes belong to a past
    /// visit. A section moves to the next page whole; only a list longer
    /// than a page breaks, between two questions, and the numbers carry on.
    private static func questions(_ open: [String]) -> PagedPDF.Item? {
        // A question of emoji alone has nothing the page can print.
        let printable = open.map(esc).filter { !PagedPDF.isBlank($0) }
        guard !printable.isEmpty else { return nil }
        return .rows(.init(opening: "<div><h2>\(esc("report.pdf.questions".l))</h2><ol>",
                           continuation: { "<div><ol start=\"\($0 + 1)\">" }, closing: "</ol></div>",
                           rows: printable.map { "<li>\($0)</li>" }, keepsTogether: true))
    }

    // MARK: Row building

    /// «label <b>value</b> tail», split at argument `position` exactly as the
    /// screen's `ReportRow` does, so the word order stays the translator's.
    private static func row(_ key: String, _ value: String, suffix: String? = nil, glueUnit: Bool = false) -> String {
        row(format: key.l, value, suffix: suffix, glueUnit: glueUnit)
    }

    static func row(format: String, at position: Int = 1, filling others: [any CVarArg] = [],
                    _ value: String, suffix: String? = nil, glueUnit: Bool = false) -> String {
        let split = FormatSplit(format, at: position, value: value, filling: others)
        let label = split?.head ?? format
        var tail = split?.tail ?? ""
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
        let document = document(summary: summary, baby: baby, openQuestions: openQuestions,
                                periodStart: periodStart, now: now)
        // UIKit draws this line, and in a PDF context it prints an emoji as a box too.
        let name = PagedPDF.withoutEmoji(baby.name).trimmingCharacters(in: .whitespaces)
        let footer = [ "brand.name".l, name, periodRange(periodStart, now: now) ]
            .filter { !PagedPDF.isBlank($0) }.joined(separator: ReportFormat.listSeparator)
        return PagedPDF.data(document, renderer: ReportPageRenderer(footerLeft: footer))
    }

    /// «<report.pdf.file_fmt>.pdf», named as every export's file is.
    static func fileName(babyName: String, date: Date) -> String {
        let day = ExportGenerator.fileDate(date)
        return ExportGenerator.fileName(fitting: ExportGenerator.fileNamePart(babyName)) {
            String(format: "report.pdf.file_fmt".l, $0, day) + ".pdf"
        }
    }

    /// Draws «<brand> · <name> · <period>» left and «Page N of M» right on every page.
    private final class ReportPageRenderer: UIPrintPageRenderer {
        private let footerLeft: String
        /// Once per render, not per page: it carries the whole fallback list.
        private let font = PagedPDF.font(ofSize: 9)
        private let language = PagedPDF.languageAttribute()

        init(footerLeft: String) {
            self.footerLeft = footerLeft
            super.init()
            // Reserved inside the printable rect, so the body never runs under it.
            footerHeight = 24
        }

        override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
            // 9 pt page furniture in the secondary colour.
            let color = UIColor(hex: DoctorReportPDF.secondary)
            let left = NSMutableParagraphStyle()
            left.lineBreakMode = .byTruncatingTail
            let right = NSMutableParagraphStyle()
            right.alignment = .right

            let pageText = String(format: "report.pdf.page_fmt".l, pageIndex + 1, numberOfPages)
            let pageWidth: CGFloat = 80
            // `footerRect` is cut from the paper, not the printable rect set by
            // KVC, so it runs to the page edges (seen on the first render): lay
            // the line out inside the margins, at the bottom of the reserved band.
            let area = printableRect
            let line = CGRect(x: area.minX, y: area.maxY - footerHeight / 2 - 6, width: area.width, height: 12)
            (footerLeft as NSString).draw(
                in: CGRect(x: line.minX, y: line.minY, width: line.width - pageWidth - 8, height: line.height),
                withAttributes: language.merging([.font: font, .foregroundColor: color, .paragraphStyle: left]) { $1 })
            (pageText as NSString).draw(
                in: CGRect(x: line.maxX - pageWidth, y: line.minY, width: pageWidth, height: line.height),
                withAttributes: language.merging([.font: font, .foregroundColor: color, .paragraphStyle: right]) { $1 })
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

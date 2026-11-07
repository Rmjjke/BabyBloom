import XCTest
import SwiftData
import PDFKit
import UIKit
@testable import BabyBloom

#if targetEnvironment(simulator)
/// Not an assertion suite — a visual dump. Writes the report PDF for each
/// doctor seed in all three languages through the share button's own path
/// (`Input.load` → `make` → `DoctorReportPDF.data`), so the pages can be
/// looked at without driving the app, and prints what the weight chart does
/// to each: the page count with and without it, whether page 1 stays the
/// same, how far it moves what follows, and its labels as the text layer
/// reads them.
///
/// Opt-in: `TEST_RUNNER_BB_DUMP=1 xcodebuild test -only-testing:…`; then read
/// `REPORT_PDF_DIR`, `REPORT_PAGES` and `REPORT_FIND` from the test log.
@MainActor
final class DoctorReportPDFRenderDump: XCTestCase {

    private struct Store {
        let container: ModelContainer
        let context: ModelContext
    }

    private func store(_ seed: (ModelContext) -> Void) throws -> Store {
        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let context = ModelContext(container)
        seed(context)
        try context.save()
        return Store(container: container, context: context)
    }

    func testDumpReportPDFs() throws {
        guard ProcessInfo.processInfo.environment["BB_DUMP"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BB_DUMP=1 to dump the report PDFs")
        }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-report-pdf")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let now = Date()
        defer { LocalizationManager.shared.setLanguage(.en) }

        let scenarios: [(name: String, seed: (ModelContext) -> Void)] = [
            ("doctorMonth", { SeedScenario.doctorMonth.seedDoctor(into: $0, now: now) }),
            ("shortHistory", { Self.seedShortHistory(into: $0, now: now) }),
            ("todayOnly", { SeedScenario.doctorVisitToday.seedDoctor(into: $0, now: now) }),
            ("novisit", { SeedScenario.doctorNoVisit.seedDoctor(into: $0, now: now) }),
            ("doses", { context in
                SeedScenario.doctorMonth.seedDoctor(into: context, now: now)
                Self.addDoses(into: context, now: now)
            }),
        ]
        for scenario in scenarios {
            let store = try store(scenario.seed)
            try dumpReports(scenario.name, store.context, now: now, dir: dir)
            withExtendedLifetime(store.container) {}
        }

        // The general export, a week of the doctorMonth store, in each
        // language: its own layout, numbers in the app language; and the name
        // each PDF's file takes.
        let month = try store { SeedScenario.doctorMonth.seedDoctor(into: $0, now: now) }
        let context = month.context
        let baby = try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first)
        let week = ExportDateRange.week.startDate(now: now) ?? now
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let export = ExportGenerator.pdfData(
                baby: baby,
                feedings: try context.fetch(FetchDescriptor<FeedingEntry>()).filter { $0.startTime >= week }
                    .sorted { $0.startTime > $1.startTime },
                sleeps: try context.fetch(FetchDescriptor<SleepEntry>()).filter { $0.startTime >= week }
                    .sorted { $0.startTime > $1.startTime },
                diapers: try context.fetch(FetchDescriptor<DiaperEntry>()).filter { $0.time >= week }
                    .sorted { $0.time > $1.time },
                growths: try context.fetch(FetchDescriptor<GrowthEntry>()).sorted { $0.date > $1.date },
                events: try context.fetch(FetchDescriptor<CustomEvent>()).filter { $0.time >= week },
                categories: Set(ExportCategory.allCases), range: .week)
            try export.write(to: dir.appendingPathComponent("export-\(language.rawValue).pdf"))
            for name in [baby.name, String(repeating: "Abcdefghij", count: 6)] {
                print("PDF_FILE_NAME \(language.rawValue) export=\(ExportGenerator.pdfFileName(babyName: name, date: now))"
                      + " report=\(DoctorReportPDF.fileName(babyName: name, date: now))")
            }
        }
        print("REPORT_PDF_DIR=\(dir.path)")
        withExtendedLifetime(month.container) {}
    }

    // MARK: Reports

    /// Each language's report with its chart, and the same summary with the
    /// chart taken out, so the two can be compared page by page.
    private func dumpReports(_ name: String, _ context: ModelContext, now: Date, dir: URL) throws {
        let baby = try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first)
        let visits = try context.fetch(FetchDescriptor<DoctorVisit>())
        let open = DoctorPeriod.openQuestions(try context.fetch(FetchDescriptor<DoctorQuestion>()))
        let periodStart = DoctorPeriod.start(visits: visits, birthDate: baby.birthDate)
        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            var summary = DoctorReportSummary.make(
                input: .load(baby: baby, periodStart: periodStart, in: context),
                periodStart: periodStart, now: now, startsAtVisit: !visits.isEmpty, calendar: .current)
            let hasChart = summary.growth.weightChart != nil
            let data = DoctorReportPDF.data(summary: summary, baby: baby, openQuestions: open.map(\.text),
                                            periodStart: periodStart, now: now)
            summary.growth.weightChart = nil
            let plain = DoctorReportPDF.data(summary: summary, baby: baby, openQuestions: open.map(\.text),
                                             periodStart: periodStart, now: now)
            try data.write(to: dir.appendingPathComponent("report-\(name)-\(language.rawValue).pdf"))
            if name == "doctorMonth" {
                try plain.write(to: dir.appendingPathComponent("report-\(name)-\(language.rawValue)-nochart.pdf"))
            }
            let with = try XCTUnwrap(PDFDocument(data: data))
            let without = try XCTUnwrap(PDFDocument(data: plain))
            let first = try XCTUnwrap(with.page(at: 0))
            let firstPlain = try XCTUnwrap(without.page(at: 0))
            print("REPORT_PAGES \(name) \(language.rawValue) chart=\(hasChart) pages=\(with.pageCount)"
                  + " without=\(without.pageCount)"
                  + " page1Text=\(bodyLines(first) == bodyLines(firstPlain) ? "same" : "differs")"
                  + " page1Pixels=\(bodyPixels(first) == bodyPixels(firstPlain) ? "same" : "differs")"
                  + " block=\(blockShift(with, without))")
            if with.pageCount > without.pageCount {
                // The section moved to a new page and took the closing line
                // with it: page 1 must lose that line alone, and above it
                // stay the same to the pixel.
                let gone = Set(bodyLines(firstPlain)).subtracting(bodyLines(first)).sorted()
                let added = Set(bodyLines(first)).subtracting(bodyLines(firstPlain)).sorted()
                let probe = String("report.footnote".l.prefix { $0 != "\u{A0}" && $0 != "\n" }.prefix(24))
                let closing = without.findString(probe, withOptions: []).last
                let top = closing.flatMap { sel in sel.pages.first.map { sel.bounds(for: $0).maxY } } ?? 60
                let above = bodyPixels(first, above: top + 1) == bodyPixels(firstPlain, above: top + 1)
                print("REPORT_P1DIFF \(name) \(language.rawValue) gone=\(gone) added=\(added)"
                      + String(format: " closingTop=%.1f", Double(top))
                      + " pixelsAboveClosing=\(above ? "same" : "differs")")
            }
            if name == "doctorMonth" || name == "shortHistory" {
                printChartBand(name, language, with)
            }
        }
    }

    /// Page 1's body: every line above the footer band, whose «Page 1 of N»
    /// changes with the page count.
    private func bodyLines(_ page: PDFPage) -> [String] {
        (page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine() ?? [])
            .filter { $0.bounds(for: page).minY >= 60 }
            .map { $0.string ?? "" }
    }

    /// The page drawn from `above` (PDF points from the bottom) to its top.
    private func bodyPixels(_ page: PDFPage, above: CGFloat = 60) -> Data? {
        let box = page.bounds(for: .mediaBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: box.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: box.size))
            let cg = context.cgContext
            cg.translateBy(x: 0, y: box.height)
            cg.scaleBy(x: 1, y: -1)
            cg.clip(to: CGRect(x: 0, y: above, width: box.width, height: box.height - above))
            page.draw(with: .mediaBox, to: cg)
        }
        return image.pngData()
    }

    /// How far the chart moves the closing line down, when both copies keep it
    /// on the same page.
    private func blockShift(_ with: PDFDocument, _ without: PDFDocument) -> String {
        let footnote = "report.footnote".l
        let probe = String(footnote.prefix { $0 != "\u{A0}" && $0 != "\n" }.prefix(24))
        guard !probe.isEmpty,
              let a = with.findString(probe, withOptions: []).last,
              let b = without.findString(probe, withOptions: []).last,
              let pageA = a.pages.first, let pageB = b.pages.first,
              with.index(for: pageA) == without.index(for: pageB) else { return "n/a" }
        return String(format: "%.1f", b.bounds(for: pageB).minY - a.bounds(for: pageA).minY)
    }

    /// The chart's heading and every text line in the 130 pt under it, with
    /// its bounds on the page and its face.
    private func printChartBand(_ name: String, _ language: SupportedLanguage, _ document: PDFDocument) {
        guard let heading = document.findString("report.pdf.chart_title".l, withOptions: []).first,
              let page = heading.pages.first else {
            print("REPORT_FIND \(name) \(language.rawValue) no chart heading")
            return
        }
        let top = heading.bounds(for: page).maxY
        let lines = (page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine() ?? [])
            .filter { ((top - 135)...top).contains($0.bounds(for: page).midY) }
        for line in lines {
            let bounds = line.bounds(for: page)
            let font = line.attributedString?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            let text = (line.string ?? "").replacingOccurrences(of: "\u{A0}", with: "·")
            print(String(format: "REPORT_FIND %@ %@ page=%d x=%.1f-%.1f y=%.1f-%.1f font=%@ %.2f «%@»",
                         name, language.rawValue, document.index(for: page) + 1,
                         bounds.minX, bounds.maxX, bounds.minY, bounds.maxY,
                         font?.fontName ?? "?", font?.pointSize ?? 0, text))
        }
    }

    // MARK: Seeds

    /// Born the day before yesterday, weighed at birth and yesterday, no visit
    /// yet: the shortest history that still draws a line.
    private static func seedShortHistory(into context: ModelContext, now: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func at(_ n: Int, _ hour: Int) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -n, to: today)!)!
        }
        let birth = at(2, 8)
        let baby = Baby(name: "Mia", birthDate: birth, gender: .female, feedingType: .mixed)
        baby.birthWeightKg = 3.4
        context.insert(baby)
        for (date, kg) in [(birth, 3.40), (at(1, 10), 3.32)] {
            let entry = GrowthEntry(date: date, weightKg: kg)
            entry.baby = baby
            context.insert(entry)
        }
        for n in 0...2 {
            for hour in stride(from: 1, to: 24, by: 3) where at(n, hour) > birth && at(n, hour) < now - 2 * 3600 {
                let feed = FeedingEntry(startTime: at(n, hour), type: .breast, side: hour % 2 == 0 ? .left : .right,
                                        volumeML: nil)
                feed.endTime = at(n, hour).addingTimeInterval(15 * 60)
                feed.baby = baby
                context.insert(feed)
                let sleep = SleepEntry(startTime: at(n, hour).addingTimeInterval(30 * 60), type: .nap)
                sleep.endTime = at(n, hour).addingTimeInterval(150 * 60)
                sleep.baby = baby
                context.insert(sleep)
                let diaper = DiaperEntry(time: at(n, hour).addingTimeInterval(20 * 60), type: .wet)
                diaper.baby = baby
                context.insert(diaper)
            }
        }
        for (text, created) in [("Is it fine that she sleeps on her tummy?", at(1, 21)),
                                ("How much vitamin D, and for how long?", at(1, 22)),
                                ("When are the next vaccinations?", at(2, 20))] {
            let question = DoctorQuestion(text: text)
            question.createdAt = created
            question.baby = baby
            context.insert(question)
        }
    }

    /// A course of vitamin D on the last three days, for the medications
    /// section under the chart's page.
    private static func addDoses(into context: ModelContext, now: Date) {
        guard let baby = try? context.fetch(FetchDescriptor<Baby>()).first else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        for n in 1...3 {
            let day = cal.date(byAdding: .day, value: -n, to: today)!
            let event = CustomEvent(time: cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)!, type: .medication)
            event.medicationName = "Vitamin D"
            event.medicationDose = "1 drop"
            event.baby = baby
            context.insert(event)
        }
    }
}
#endif

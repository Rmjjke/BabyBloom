import XCTest
import SwiftData
@testable import BabyBloom

#if targetEnvironment(simulator)
/// Not an assertion suite — a visual dump. Writes the report PDF for the
/// `doctorMonth` seed in all three languages through the share button's own
/// path (`Input.load` → `make` → `DoctorReportPDF.data`), so the page can be
/// looked at without driving the app.
///
/// Opt-in: `TEST_RUNNER_BB_DUMP=1 xcodebuild test -only-testing:…`; then read
/// `REPORT_PDF_DIR` from the test log.
@MainActor
final class DoctorReportPDFRenderDump: XCTestCase {

    func testDumpReportPDFs() throws {
        guard ProcessInfo.processInfo.environment["BB_DUMP"] == "1" else {
            throw XCTSkip("set TEST_RUNNER_BB_DUMP=1 to dump the report PDFs")
        }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-report-pdf")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let container = try ModelContainer(
            for: AppSchema.schema,
            configurations: [ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let now = Date()
        SeedScenario.doctorMonth.seedDoctor(into: context, now: now)
        try context.save()

        let baby = try XCTUnwrap(context.fetch(FetchDescriptor<Baby>()).first)
        let visits = try context.fetch(FetchDescriptor<DoctorVisit>())
        let open = DoctorPeriod.openQuestions(try context.fetch(FetchDescriptor<DoctorQuestion>()))
        let periodStart = DoctorPeriod.start(visits: visits, birthDate: baby.birthDate)
        defer { LocalizationManager.shared.setLanguage(.en) }

        for language in [SupportedLanguage.en, .ru, .es] {
            LocalizationManager.shared.setLanguage(language)
            let summary = DoctorReportSummary.make(
                input: .load(baby: baby, periodStart: periodStart, in: context),
                periodStart: periodStart, now: now, startsAtVisit: !visits.isEmpty, calendar: .current)
            let data = DoctorReportPDF.data(summary: summary, baby: baby, openQuestions: open.map(\.text),
                                            periodStart: periodStart, now: now)
            try data.write(to: dir.appendingPathComponent("report-\(language.rawValue).pdf"))
        }
        print("REPORT_PDF_DIR=\(dir.path)")
        withExtendedLifetime(container) {}
    }
}
#endif

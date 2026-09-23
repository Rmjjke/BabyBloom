import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump of `WeightChartView`, which nothing
/// else can check: the corridor is geometry, and geometry is read with eyes.
///
/// The shapes that matter are the ones a unit test cannot describe — a band
/// that stops where the preterm points begin, a single point sitting in a
/// corridor four weeks wide, a chart whose band has run out past two years.
///
/// Run it, read `CHART_DIR` from the test log, open the files.
@MainActor
final class WeightChartRenderDump: XCTestCase {

    /// Fixed so the dump's bytes do not move with the clock. Ages are built
    /// from this, never from `Date()`.
    private let birth = Date(timeIntervalSince1970: 1_700_000_000)

    private func at(_ ageDays: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: ageDays, to: birth)!,
                          weightKg: kg)
    }

    func testDumpWeightCharts() throws {
        // See NutritionRenderDump: this process runs suites that assert on
        // localized output, so the language this dump sets must not survive it.
        let originalLanguage = LocalizationManager.shared.language
        addTeardownBlock { LocalizationManager.shared.setLanguage(originalLanguage) }

        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-charts")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locale in ["en", "ru"] {
            LocalizationManager.shared.setLanguage(locale)

            // A healthy term course: birth, the dip, recovery, then a climb.
            // The line should sit comfortably inside the band.
            try dump(dir, "\(locale)-healthy", chart([
                at(0, 3.40), at(4, 3.20), at(12, 3.55), at(30, 4.35), at(60, 5.30), at(90, 6.10),
            ]))

            // Low gain: the same start, a line that drifts DOWN through the
            // band. It must still be drawn calmly — no red anywhere.
            try dump(dir, "\(locale)-low-gain", chart([
                at(0, 3.40), at(14, 3.45), at(45, 3.90), at(90, 4.40), at(140, 4.80),
            ]))

            // A fresh install: the birth measurement and nothing else. The
            // corridor is what makes one point worth charting.
            try dump(dir, "\(locale)-single-point", chart([at(0, 3.45)]))

            // The newborn window — a handful of points inside three weeks.
            try dump(dir, "\(locale)-newborn", chart([
                at(0, 3.50), at(3, 3.25), at(7, 3.30), at(14, 3.60), at(20, 3.95),
            ]))

            // Preterm, born ten weeks early: the first three weighings predate
            // the corrected due date and carry NEGATIVE ages. No band may be
            // drawn under them — it starts at the due date.
            try dump(dir, "\(locale)-preterm", chart(
                [at(-70, 1.40), at(-56, 1.75), at(-28, 2.55), at(0, 3.30), at(35, 4.60)],
                bornDaysEarly: 70))

            // Past the tables: every point is older than 24 months, so the
            // chart draws the baby's line and NO band at all.
            try dump(dir, "\(locale)-past-tables", chart([
                at(760, 12.40), at(800, 12.80), at(860, 13.30),
            ]))

            // The owner's report (2026-09-23): a long flat stretch, then two
            // weighings on one day. The readout and the date axis are what
            // make "when did it jump, and to what" answerable.
            try dump(dir, "\(locale)-same-day-jump", chart([
                at(0, 3.50), at(40, 4.60), at(46, 6.55), at(46, 7.70).later(hours: 3),
            ]))

            // Nearly two years: the tick labels carry a four-digit year, and
            // the widest of them must still clear the right edge.
            try dump(dir, "\(locale)-two-years", chart([
                at(0, 3.40), at(60, 5.30), at(180, 7.90), at(365, 9.60), at(540, 10.90), at(700, 12.00),
            ]))

            // The opt-out for a caller that ever reuses this shell for height.
            try dump(dir, "\(locale)-no-corridor",
                     chart([at(0, 3.40), at(30, 4.35), at(60, 5.30)], corridor: false))
        }

        // Dark, on the two shapes where the band's contrast is most at risk:
        // a line crossing it, and a chart that is almost all band.
        LocalizationManager.shared.setLanguage("ru")
        try dump(dir, "ru-low-gain-dark", chart([
            at(0, 3.40), at(14, 3.45), at(45, 3.90), at(90, 4.40), at(140, 4.80),
        ]), dark: true)
        try dump(dir, "ru-single-point-dark", chart([at(0, 3.45)]), dark: true)

        print("CHART_DIR=\(dir.path)")
    }

    /// `bornDaysEarly` moves the ACTUAL birth back from `birth`, which stays
    /// the corrected one the geometry is drawn from — the readout's age is
    /// chronological.
    private func chart(_ measurements: [WeightMeasurement],
                       corridor: Bool = true,
                       bornDaysEarly: Int = 0) -> some View {
        WeightChartView(measurements: measurements,
                        correctedBirthDate: birth,
                        birthDate: Calendar.current.date(byAdding: .day, value: -bornDaysEarly, to: birth)!,
                        isMale: true,
                        showsWHOCorridor: corridor)
    }

    private func dump<V: View>(_ dir: URL, _ name: String, _ view: V, dark: Bool = false) throws {
        let framed = view
            .frame(width: 340)
            .padding(16)
            .background(BBTheme.Colors.background)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("could not render \(name)")
        }
        try data.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

private extension WeightMeasurement {
    func later(hours: Int) -> WeightMeasurement {
        WeightMeasurement(date: date.addingTimeInterval(TimeInterval(hours * 3600)), weightKg: weightKg)
    }
}

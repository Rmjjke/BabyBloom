import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump, like `GrowthCardRenderDump`.
///
/// It renders `PercentileCard` in BOTH tones side by side, which is the only
/// way to see the one thing the onboarding tone is for: at the tails the band
/// label and the badge are identical and only the colour differs, so the
/// `-standard` and `-onboarding` pairs at p1 and p99 are the check that the
/// showcase page withholds the alarm without withholding the word.
///
/// The `-standard` files are also the extraction's evidence: they were produced
/// by a verbatim copy of `GrowthView`'s private card markup before the split
/// and by this shared view after it, and the PNGs compared byte-identical
/// (2026-09-21, `.desk/tasks/growth-showcase-page/docs/evidence/`).
///
/// Run it, read `PERCENTILE_DIR` from the test log, open the files.
@MainActor
final class PercentileCardRenderDump: XCTestCase {

    /// Fixed, not `Date()`: the caption prints it, and a dump whose bytes move
    /// with the clock cannot be compared against anything.
    private let weighedOn = Date(timeIntervalSince1970: 1_700_000_000)

    func testDumpPercentileCards() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-percentile")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            try dump(dir, "\(locale)-p40", growthScreenCard(percentile: 40, badge: "40", months: 1))
            try dump(dir, "\(locale)-p1", growthScreenCard(percentile: 1, badge: "< 3", months: 0))
            try dump(dir, "\(locale)-p99", growthScreenCard(percentile: 99, badge: "> 97", months: 6))
            try dump(dir, "\(locale)-p40-dark", growthScreenCard(percentile: 40, badge: "40", months: 1),
                     dark: true)

            try dump(dir, "\(locale)-onboarding-p40", showcaseCard(percentile: 40, badge: "40"))
            try dump(dir, "\(locale)-onboarding-p1", showcaseCard(percentile: 1, badge: "< 3"))
            try dump(dir, "\(locale)-onboarding-p99", showcaseCard(percentile: 99, badge: "> 97"))
            try dump(dir, "\(locale)-onboarding-p1-dark", showcaseCard(percentile: 1, badge: "< 3"),
                     dark: true)
        }

        print("PERCENTILE_DIR=\(dir.path)")
    }

    /// Exactly as `GrowthView` composes it — the `ExplainerCard` wrapper
    /// included, because that wrapper is what injects the "?" badge.
    private func growthScreenCard(percentile: Double, badge: String, months: Int) -> some View {
        ExplainerCard(explainer: .percentile) {
            PercentileCard(
                percentile: percentile,
                badge: badge,
                captionLines: [
                    String(format: "percentile.by_who_fmt".l, months, months.monthWord),
                    String(format: "percentile.as_of_fmt".l, weighedOn.appDayMonth),
                ]
            )
        }
    }

    /// Exactly as `GrowthShowcasePage` composes it: bare (so no badge), one
    /// caption line, and the neutral tone.
    private func showcaseCard(percentile: Double, badge: String) -> some View {
        PercentileCard(
            percentile: percentile,
            badge: badge,
            captionLines: [
                String(format: "onboarding.showcase.caption_fmt".l, "Mia",
                       String(format: "%.2f %@", 3.45, "unit.kg".l)),
            ],
            tone: .neutralOnly
        )
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

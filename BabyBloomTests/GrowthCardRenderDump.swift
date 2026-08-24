import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump. Renders every new growth card to PNG
/// so layout and text overflow can be eyeballed in all three locales without
/// driving the whole app through onboarding.
///
/// Run it, read `CARDS_DIR` from the test log, open the files.
@MainActor
final class GrowthCardRenderDump: XCTestCase {

    private let birth = Calendar.current.date(byAdding: .day, value: -15, to: Date())!

    private func at(_ day: Int, _ kg: Double) -> WeightMeasurement {
        WeightMeasurement(date: Calendar.current.date(byAdding: .day, value: day, to: birth)!, weightKg: kg)
    }

    func testDumpCards() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-cards")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            try dump("\(locale)-newborn-normal", newbornCard(day: 3, weight: 3.255))
            try dump("\(locale)-newborn-flagged", newbornCard(day: 15, weight: 3.05))
            try dump("\(locale)-gain-within", gainCard(gramsPerDay: 35))
            try dump("\(locale)-gain-below", gainCard(gramsPerDay: 12))
            try dump("\(locale)-trend-drop", CentileTrendCard(assessment: .sustainedDrop(spaces: 2.4)))
            try dump("\(locale)-locked", LockedInsightCard(
                title: "section.weight_gain".l, teaser: "premium.teaser_gain".l, onUnlock: {}))
        }

        // Dark mode on the densest card, where contrast problems would show first.
        LocalizationManager.shared.setLanguage("ru")
        try dump("ru-newborn-flagged-dark", newbornCard(day: 15, weight: 3.05), dark: true)

        print("CARDS_DIR=\(dir.path)")
    }

    // MARK: - Builders using the real analysis paths

    private func newbornCard(day: Int, weight: Double) -> some View {
        let status = NewbornWeightLoss.analyse(
            birthWeightKg: 3.5,
            birthDate: birth,
            measurements: [at(day, weight)],
            now: Calendar.current.date(byAdding: .day, value: day, to: birth)!
        )!
        return NewbornProgressCard(status: status)
    }

    private func gainCard(gramsPerDay: Double) -> some View {
        let start = at(0, 4.0)
        let end = WeightMeasurement(
            date: Calendar.current.date(byAdding: .day, value: 14, to: start.date)!,
            weightKg: 4.0 + gramsPerDay * 14 / 1000
        )
        return WeightGainCard(reading: WeightVelocity.measure(
            from: start, to: end, correctedBirthDate: birth, isMale: true))
    }

    private func dump<V: View>(_ name: String, _ view: V, dark: Bool = false) throws {
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
        try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bb-cards")
            .appendingPathComponent("\(name).png"))
    }
}

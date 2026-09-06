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
            // The empty states a fresh install actually lands on, WITH the CTA
            // the screen injects — three locales because the button's label and
            // the hint above it share a card width, and Russian is the longest.
            try dump("\(locale)-gain-needs-second", withCTA(WeightGainCard(reading: nil, hasWeighing: true, deferral: nil)))
            try dump("\(locale)-gain-needs-two", withCTA(WeightGainCard(reading: nil, hasWeighing: false, deferral: nil)))
            try dump("\(locale)-trend-insufficient", withCTA(CentileTrendCard(assessment: .insufficientData)))
            // Both nutrition wordings: with one weighing on file the two cards
            // above must ask for "one more", not for two.
            try dump("\(locale)-nutrition-needs-next",
                     withCTA(NutritionSection(assessment: nil, band: nil, hasWeighing: true)))
            try dump("\(locale)-nutrition-needs-two",
                     withCTA(NutritionSection(assessment: nil, band: nil, hasWeighing: false)))
            try dump("\(locale)-newborn-needs-weighing", withCTA(newbornCardNoWeighing()))
            // The same card with the action absent — the hint must sit flush
            // against the card's bottom padding, with no gap where the button
            // would have been.
            try dump("\(locale)-newborn-needs-weighing-no-cta", newbornCardNoWeighing())
            // The two deferral states. Both go through `withCTA`, so the dump
            // also shows that only the stale one draws a button — the in-window
            // one has no CTA even with the action available, because the
            // first-weeks card above it is the one doing the asking.
            try dump("\(locale)-gain-defer-now", withCTA(gainDeferralCard(.firstWeeksNow)))
            try dump("\(locale)-gain-defer-stale", withCTA(gainDeferralCard(.measuredInFirstWeeks)))
            try dump("\(locale)-trend-drop", CentileTrendCard(assessment: .sustainedDrop(spaces: 2.4)))
            // The two non-alarm trend states side by side: only `.stable` may
            // carry the green tick, and neither may look like the drop.
            try dump("\(locale)-trend-stable", CentileTrendCard(assessment: .stable))
            try dump("\(locale)-trend-crossing-up", CentileTrendCard(assessment: .crossingUp(spaces: 3.1)))
            try dump("\(locale)-locked", LockedInsightCard(
                title: "section.weight_gain".l, teaser: "premium.teaser_gain".l, onUnlock: {}))
            // The same card WITH an explainer behind it: the "?" is its own
            // control here, because the card's own tap sells. Beside the plain
            // `-locked` dump above it is also the check that a card with no
            // explainer draws no badge at all.
            try dump("\(locale)-locked-explained", LockedInsightCard(
                title: "section.weight_gain".l, teaser: "premium.teaser_gain".l,
                explainer: .gain, onUnlock: {}))
            // Wrapped the way `GrowthView` wraps it, so the badge it injects is
            // visible: this is the 24-months-and-over state, which no seed
            // scenario reaches — every fixture baby is weeks old.
            try dump("\(locale)-percentile-out-of-range",
                     ExplainerCard(explainer: .percentile) { PercentileOutOfRangeCard() })
        }

        // Dark mode on the densest card, where contrast problems would show first.
        LocalizationManager.shared.setLanguage("ru")
        try dump("ru-newborn-flagged-dark", newbornCard(day: 15, weight: 3.05), dark: true)
        // The stale deferral in dark too: it is the only card on this screen
        // whose body is a paragraph followed by a control, and the CTA's tint
        // is the one that has to hold in both schemes.
        try dump("ru-gain-defer-stale-dark", gainDeferralCard(.measuredInFirstWeeks), dark: true)

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

    /// Birth weight recorded, nothing weighed yet: the first empty state a fresh
    /// install can meet, and the one the CTA rule skipped until now.
    private func newbornCardNoWeighing() -> some View {
        let status = NewbornWeightLoss.analyse(
            birthWeightKg: 3.5,
            birthDate: birth,
            measurements: [],
            now: Calendar.current.date(byAdding: .day, value: 3, to: birth)!
        )!
        return NewbornProgressCard(status: status)
    }

    private func gainCard(gramsPerDay: Double) -> some View {
        let start = at(0, 4.0)
        let end = WeightMeasurement(
            date: Calendar.current.date(byAdding: .day, value: 14, to: start.date)!,
            weightKg: 4.0 + gramsPerDay * 14 / 1000
        )
        return WeightGainCard(
            reading: WeightVelocity.measure(from: start, to: end,
                                            correctedBirthDate: birth, isMale: true),
            hasWeighing: true,
            deferral: nil)
    }

    /// The two deferral states — the whole point of the newborn gate, and the
    /// states no fixture used to render. They differ in more than wording: only
    /// the stale one carries a CTA, and a dump is the cheapest way to see that
    /// the card still reads as one family with the verdict states above.
    ///
    /// `hasWeighing: true` throughout — a deferral outranks it, so the flag is
    /// unread here, and false would suggest these states are about an empty
    /// history when they are the opposite.
    private func gainDeferralCard(_ deferral: NewbornWeightLoss.GainDeferral) -> some View {
        WeightGainCard(reading: nil, hasWeighing: true, deferral: deferral)
    }

    /// Stands in for `GrowthView`, which is what sets the action an empty
    /// state's CTA draws itself from — without it these cards render exactly as
    /// they did before, hint and no button.
    private func withCTA<V: View>(_ view: V) -> some View {
        view.environment(\.addWeighingAction, {})
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

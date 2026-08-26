import XCTest
import SwiftUI
import UIKit
@testable import BabyBloom

/// Not an assertion suite in the usual sense — a visual dump, the same idea as
/// `GrowthCardRenderDump`. Renders both new surfaces in every shipped language
/// so wrapping, tone and colour can be eyeballed without driving the whole app.
///
/// Two departures from the sibling dump, both deliberate:
///
/// 1. **Every state is built through `FeedingAdequacy.assess`**, not by calling
///    the `Assessment` memberwise initializer with hand-picked fields. A dump
///    whose inputs are invented can happily render a combination the real code
///    can never produce, and then everyone believes a screenshot of a state
///    that does not exist. Building through `assess` means each image is
///    evidence the state is reachable. The `XCTAssertEqual`s beside each render
///    pin the signals the filename claims, so a file called `-calm` cannot
///    quietly become something else.
///
/// 2. **The three cards are also rendered STACKED**, in the order `GrowthView`
///    puts them. Three questions about this screen are cross-card and no
///    per-card render can answer them: whether `WeightGainCard` and
///    `FeedingBreakdownCard` print the same day count for the same weighings,
///    whether the two different "below" tints read as one design, and whether
///    the window labels agree in case and phrasing.
///
/// Run it, read `NUTRITION_DIR` from the test log, open the files. Each render
/// also prints its pixel size and a background sample, which is what makes the
/// dark-mode and Dynamic Type renders checkable rather than merely claimed.
///
/// **Dynamic Type cannot be overridden from inside this process.** Every font
/// on both surfaces comes from `BBTheme.Typography.scaled` or a literal
/// `.system(size:)`, and `scaled` is built on `UIFontMetrics.scaledValue(for:)`
/// — the form that takes no trait collection. Measured, not assumed: inside a
/// `UITraitCollection.performAsCurrent` block that had genuinely moved
/// `UITraitCollection.current` to `accessibilityLarge`, `scaledValue(for: 15)`
/// still returned `15.0`, while `scaledValue(for: 15, compatibleWith:)` on the
/// same trait collection returned `27.33`. So neither `.environment(\.dynamicTypeSize,)`
/// nor a current-trait override moves these fonts; only the DEVICE setting
/// does. This dump therefore takes the live device category as given and
/// stamps it into every filename, and the accessibility renders come from a
/// second run of the same test after:
///
///     xcrun simctl ui booted content_size accessibility-large
///
/// with `content_size large` restoring the default set.
///
/// That paragraph is about FONT SIZES. The environment value still matters for
/// LAYOUT: a view is free to branch on `dynamicTypeSize`, and
/// `NutritionSection`'s row does. So `dump` hands the live device category to
/// the environment as well — not to change any font, which it cannot, but so
/// that the branch and the text in the same image agree about what size this
/// is. Without it the renders were internally inconsistent: AX2 text laid out
/// by the default-size branch.
@MainActor
final class NutritionRenderDump: XCTestCase {

    // MARK: - Scenarios

    /// The inputs one state is generated from. Everything downstream — the
    /// weighings, the feed log, the nappy log — is derived from these, so a
    /// state is described in the terms a parent's data actually has.
    private struct Scenario {
        /// Days after birth of the EARLIER of the two weighings.
        let firstWeighingDay: Double
        /// Gap between the two weighings. Fractional on purpose in the `below`
        /// family: whole-day gaps make `WeightVelocity.intervalDays` (truncated)
        /// and `Assessment.windowDays` (rounded) agree by accident, which would
        /// make the stacked day-count check prove nothing.
        let gapDays: Double
        let startKg: Double
        let gramsPerDay: Double
        /// nil means the parent logged nothing of this kind — which must render
        /// as words, never as zero.
        let feedsPerDay: Double?
        let nappiesPerDay: Double?

        /// Gain within reference, feeds and nappies within reference. The
        /// common case, and the one whose whole job is reassurance.
        static let calm = Scenario(firstWeighingDay: 30, gapDays: 9, startKg: 4.0,
                                   gramsPerDay: 35, feedsPerDay: 8, nappiesPerDay: 7)

        /// The case the feature exists for: gain below, both context signals
        /// below too. 9.6 days so the two day-count roundings diverge (9 vs 10).
        static let below = Scenario(firstWeighingDay: 30, gapDays: 9.6, startKg: 4.0,
                                    gramsPerDay: 17, feedsPerDay: 5, nappiesPerDay: 4)

        /// A parent who logs feeds but not nappies. Honesty, not a zero.
        static let sparse = Scenario(firstWeighingDay: 30, gapDays: 9.6, startKg: 4.0,
                                     gramsPerDay: 17, feedsPerDay: 5, nappiesPerDay: nil)

        /// Gain below, nothing else logged at all — the breakdown's no-data line.
        static let noLogs = Scenario(firstWeighingDay: 30, gapDays: 9.6, startKg: 4.0,
                                     gramsPerDay: 17, feedsPerDay: nil, nappiesPerDay: nil)

        /// The fifth state, missing from the original matrix and found during
        /// the Task 6 review. Two weighings TWO days apart in the first week,
        /// which daily weighing makes ordinary: `FeedingAdequacy.window(for:)`
        /// accepts the pair (its floor is one day) while `WeightVelocity`
        /// rejects it (`minimumIntervalDays` is three). The full three-row
        /// section therefore renders with the GAIN row alone reading "not
        /// enough data" while feeds and nappies carry real figures — a
        /// different thing entirely from having fewer than two weighings.
        static let shortWindow = Scenario(firstWeighingDay: 4, gapDays: 2, startKg: 3.4,
                                          gramsPerDay: 30, feedsPerDay: 10, nappiesPerDay: 7)
    }

    // MARK: - Fixtures

    /// A fixed birth date, not `Date()` minus an offset: the images are compared
    /// against each other across runs, and June to July carries no DST
    /// transition in the zones this ever runs in, so day offsets stay whole.
    private let birth: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 1
        components.hour = 9
        return Calendar.current.date(from: components)!
    }()

    private lazy var directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("bb-nutrition")

    /// The device's Dynamic Type setting for this run. Read once, never
    /// overridden — see the type comment for why overriding is not possible.
    private let contentSize = UIApplication.shared.preferredContentSizeCategory

    /// Stamped into every filename, so an accessibility run can never be
    /// mistaken for the default one or overwrite it.
    private var sizeSuffix: String {
        switch contentSize {
        case .large:                            return ""
        case .accessibilityMedium:              return "-ax1"
        case .accessibilityLarge:               return "-ax2"
        case .accessibilityExtraLarge:          return "-ax3"
        case .accessibilityExtraExtraLarge:     return "-ax4"
        case .accessibilityExtraExtraExtraLarge: return "-ax5"
        default:                                return "-\(contentSize.rawValue)"
        }
    }

    private var isAccessibilitySize: Bool { contentSize.isAccessibilityCategory }

    // MARK: - The dump

    func testDumpNutritionSurfaces() throws {
        // Restored so this dump cannot leak a language into the suites that run
        // after it — several of them assert on localized output in this same
        // process. A teardown block rather than an override of `tearDown`:
        // XCTestCase's is nonisolated and this class is @MainActor, and the
        // block captures only the Sendable language value, never `self`.
        let originalLanguage = LocalizationManager.shared.language
        addTeardownBlock { LocalizationManager.shared.setLanguage(originalLanguage) }

        // A default pass wipes everything; an accessibility pass is a SECOND run
        // at a changed device setting and clears only its own suffix, so it
        // lands beside the default images instead of replacing them — while
        // still not leaving a stale file behind when the set it dumps changes.
        if isAccessibilitySize {
            let stale = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            for file in stale where file.hasSuffix("\(sizeSuffix).png") {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
            }
        } else {
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("NUTRITION_CONTENT_SIZE=\(contentSize.rawValue) suffix='\(sizeSuffix)'")

        // At an accessibility size only the densest states are worth the files:
        // the question there is layout under pressure, not copy.
        if isAccessibilitySize {
            for locale in ["en", "ru", "es"] {
                LocalizationManager.shared.setLanguage(locale)
                let below = try state(.below)
                let reading = try XCTUnwrap(velocity(.below))
                try dump("\(locale)-below", NutritionSection(assessment: below))
                // `HintText` is a literal `.system(size: 13)`, so this one is
                // here to SHOW whether the hint scales rather than to argue it.
                try dump("\(locale)-needs-weighing", NutritionSection(assessment: nil))
                // Also alone, so a layout fault seen in the stack can be told
                // apart from one the card has on its own.
                try dump("\(locale)-breakdown",
                         FeedingBreakdownCard(assessment: below, reading: reading))
                try dump("\(locale)-stacked", neighbourhood(assessment: below, reading: reading))
            }
            LocalizationManager.shared.setLanguage("es")
            let below = try state(.below)
            let reading = try XCTUnwrap(velocity(.below))
            try dump("es-stacked-dark", neighbourhood(assessment: below, reading: reading), dark: true)
            print("NUTRITION_DIR=\(directory.path)")
            return
        }

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)

            let calm = try state(.calm)
            XCTAssertEqual(calm.gain, .within, "\(locale)-calm must be the reassuring state")
            XCTAssertEqual(calm.feeding, .within)
            XCTAssertEqual(calm.nappies, .within)
            try dump("\(locale)-calm", NutritionSection(assessment: calm))

            let below = try state(.below)
            XCTAssertEqual(below.gain, .below, "\(locale)-below must be the state the feature exists for")
            XCTAssertEqual(below.feeding, .below)
            XCTAssertEqual(below.nappies, .below)
            XCTAssertTrue(below.warrantsBreakdown)
            try dump("\(locale)-below", NutritionSection(assessment: below))

            let sparse = try state(.sparse)
            XCTAssertEqual(sparse.feeding, .below)
            XCTAssertEqual(sparse.nappies, .notEnoughData, "\(locale)-sparse must have an unknown nappy signal")
            XCTAssertNil(sparse.wetNappiesPerDay, "an unlogged signal must carry no number to print")
            try dump("\(locale)-sparse", NutritionSection(assessment: sparse))

            // The fifth state: a window the adequacy module accepts and the
            // velocity module does not.
            let short = try state(.shortWindow)
            XCTAssertEqual(short.gain, .notEnoughData, "a two-day gap is below WeightVelocity.minimumIntervalDays")
            XCTAssertEqual(short.feeding, .within, "feeds must still carry a real figure")
            XCTAssertEqual(short.nappies, .within, "nappies must still carry a real figure")
            XCTAssertNil(velocity(.shortWindow), "the gain row's emptiness must come from the real code path")
            try dump("\(locale)-short-window", NutritionSection(assessment: short))

            // Fewer than two weighings: a different nil, and a different screen.
            XCTAssertNil(assessment(from: [WeightMeasurement(date: day(30), weightKg: 4.0)],
                                    feeds: [], nappies: [], now: day(30)))
            try dump("\(locale)-needs-weighing", NutritionSection(assessment: nil))

            // Premium half.
            let reading = try XCTUnwrap(velocity(.below))
            XCTAssertEqual(reading.band, .below)
            try dump("\(locale)-breakdown",
                     FeedingBreakdownCard(assessment: below, reading: reading))

            let noLogs = try state(.noLogs)
            XCTAssertNil(noLogs.feedingsPerDay)
            XCTAssertNil(noLogs.wetNappiesPerDay)
            try dump("\(locale)-breakdown-sparse",
                     FeedingBreakdownCard(assessment: noLogs, reading: reading))

            // The screen neighbourhood, in GrowthView's order. This is the only
            // image that can answer the cross-card questions.
            try dump("\(locale)-stacked", neighbourhood(assessment: below, reading: reading))
        }

        // Dark mode on the densest state, in the two longest languages.
        for locale in ["ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)
            let below = try state(.below)
            let reading = try XCTUnwrap(velocity(.below))
            try dump("\(locale)-stacked-dark",
                     neighbourhood(assessment: below, reading: reading),
                     dark: true)
        }

        // The calm neighbourhood, for the other half of the tint question. The
        // two "below" tints are one colour now that `WeightGainCard` uses the
        // token; the two "within" tints are not — that card's green is still
        // the literal `#6BBF6B` while `NutritionSection` uses `BBSuccess`
        // (#7FC7A4), a mint. Calm is the state most parents are in most days,
        // so the remaining mismatch belongs in a picture rather than in a
        // report as two hex codes.
        LocalizationManager.shared.setLanguage("en")
        let calm = try state(.calm)
        let calmReading = try XCTUnwrap(velocity(.calm))
        XCTAssertEqual(calmReading.band, .within, "the calm stack must be genuinely calm")
        XCTAssertEqual(calm.gain, .within)
        try dump("en-stacked-calm", neighbourhood(assessment: calm, reading: calmReading))

        print("NUTRITION_DIR=\(directory.path)")
    }

    // MARK: - Building states through the real analysis path

    private func day(_ offset: Double) -> Date {
        birth.addingTimeInterval(offset * 86_400)
    }

    private func weighings(_ scenario: Scenario) -> [WeightMeasurement] {
        let start = WeightMeasurement(date: day(scenario.firstWeighingDay),
                                      weightKg: scenario.startKg)
        let end = WeightMeasurement(
            date: day(scenario.firstWeighingDay + scenario.gapDays),
            weightKg: scenario.startKg + scenario.gramsPerDay * scenario.gapDays / 1000
        )
        return [start, end]
    }

    /// Events spread evenly across the window at the rate asked for, so the
    /// coverage gate sees a genuinely logged stretch rather than one busy day.
    /// A nil or zero rate produces an empty log, which is what makes
    /// `notEnoughData` arrive through the real gate.
    private func events(perDay: Double?, from start: Date, to end: Date) -> [Date] {
        guard let perDay, perDay > 0 else { return [] }
        let duration = end.timeIntervalSince(start)
        let count = Int((perDay * duration / 86_400).rounded())
        guard count > 0 else { return [] }
        let step = duration / Double(count + 1)
        return (1...count).map { start.addingTimeInterval(step * Double($0)) }
    }

    private func assessment(from measurements: [WeightMeasurement],
                            feeds: [FeedingAdequacy.Feed],
                            nappies: [Date],
                            now: Date) -> FeedingAdequacy.Assessment? {
        FeedingAdequacy.assess(
            birthDate: birth,
            correctedBirthDate: birth,
            isMale: true,
            measurements: measurements,
            feeds: feeds,
            wetNappies: nappies,
            now: now
        )
    }

    private func state(_ scenario: Scenario) throws -> FeedingAdequacy.Assessment {
        let measurements = weighings(scenario)
        let start = measurements[0].date
        let end = measurements[1].date
        let feeds = events(perDay: scenario.feedsPerDay, from: start, to: end)
            .map { FeedingAdequacy.Feed(date: $0, type: .breast) }
        let nappies = events(perDay: scenario.nappiesPerDay, from: start, to: end)
        return try XCTUnwrap(assessment(from: measurements, feeds: feeds,
                                        nappies: nappies, now: end))
    }

    private func velocity(_ scenario: Scenario) -> WeightVelocity.Reading? {
        WeightVelocity.latest(measurements: weighings(scenario),
                              correctedBirthDate: birth,
                              isMale: true)
    }

    // MARK: - Views

    /// The three cards in the order `GrowthView` lays them out, spaced as that
    /// screen spaces them. `CentileTrendCard` sits between the gain card and the
    /// nutrition section on the real screen and is left out here: it shares no
    /// figure with either neighbour, and its height would only push the cards
    /// this image exists to compare further apart.
    private func neighbourhood(assessment: FeedingAdequacy.Assessment,
                               reading: WeightVelocity.Reading?) -> some View {
        VStack(spacing: BBTheme.Spacing.lg) {
            WeightGainCard(reading: reading)
            NutritionSection(assessment: assessment)
            // Gated exactly as `GrowthView` gates it. Rendering it
            // unconditionally would put "Gain is below the reference" under a
            // calm gain figure — a screen the product cannot produce, and the
            // first thing this dump promises not to fake. It changes nothing
            // for the `below` stacks, where the gate is open.
            if assessment.warrantsBreakdown {
                FeedingBreakdownCard(assessment: assessment, reading: reading)
            }
        }
        // Asks the stack for its ideal height rather than letting the renderer
        // negotiate one. Without it, `ImageRenderer` measures this VStack a
        // touch short at an accessibility size and `InsightCard`'s title —
        // the one Text on either surface with no `fixedSize` of its own —
        // renders truncated to a single line with an ellipsis. Proved a dump
        // artefact and not a card fault three ways: the same card rendered
        // ALONE wraps correctly, the stack inside a 2000pt frame wraps
        // correctly, and this modifier makes it wrap at the very same total
        // image height (1197pt) the truncating render produced — so the room
        // for the second line was always there and only the negotiation was
        // wrong. Left as a note for whoever owns InsightCard: its title is one
        // compressing ancestor away from doing this for real.
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Rendering

    private func dump<V: View>(_ name: String, _ view: V, dark: Bool = false) throws {
        let content = view
            .frame(width: 340)
            .padding(16)
            // Mirrors the cap `BabyBloomApp` puts on the whole app. It changes
            // nothing on these two surfaces — every font here is a literal
            // `.system(size:)`, either written out or produced by
            // `BBTheme.Typography.scaled` — but rendering without it would be
            // rendering a different view tree than the one that ships.
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            // The device's category, handed to the environment explicitly, and
            // OUTSIDE the cap above so it flows into it exactly as the app's
            // does. This is not the faking the type comment warns about — the
            // fonts are already at this size, because `UIFontMetrics` reads the
            // application category directly. What it fixes is the opposite
            // problem: without it, `ImageRenderer` inherited `.large` from the
            // trait collection below while the text rendered at AX2, so the
            // tree was internally inconsistent and any view that BRANCHES on
            // `dynamicTypeSize` — `NutritionSection`'s row does — took the
            // small-size branch in an image full of accessibility-size text.
            // Measured, not assumed: with the device at AX2 and this line
            // absent, `ru-below-ax2` still rendered the side-by-side row; the
            // `trait=` field on the DUMP line below is the same reading in the
            // log.
            .environment(\.dynamicTypeSize, DynamicTypeSize(contentSize) ?? .large)

        // Asset colours resolve through the SwiftUI environment, which the
        // modifier above already sets; the trait override is belt and braces
        // for anything UIKit-backed inside the tree. The content size category
        // is carried across too, so nothing inside the render disagrees with
        // the device about how large the text is.
        let traits = UITraitCollection { mutable in
            mutable.userInterfaceStyle = dark ? .dark : .light
            mutable.preferredContentSizeCategory = contentSize
        }

        // Rendered in two passes. Left to its own ideal-size pass, a tall stack
        // at an accessibility size lands on a FRACTIONAL point height (1196.5),
        // and the renderer then fits the tree to the rounded-up context by
        // shrinking it about a percent: the background rect stops short of the
        // corners (the sample below came back 0,0,0,0) and the top and bottom
        // rows come back as uninitialized colour noise. Measuring first and
        // rendering into a whole-point frame removes both. Verified, not
        // assumed: the artefact reproduced identically at scale 1 and with
        // `proposedSize` set, and only the integer height cleared it.
        //
        // This is NOT what caused the title truncation described on
        // `neighbourhood` — that survived this fix and needed its own. Two
        // separate faults that happened to show up in the same image; saying so
        // because the obvious guess is that one caused the other.
        let width: CGFloat = 340 + 32
        var rendered: UIImage?
        var renderTrait = "unset"
        traits.performAsCurrent {
            renderTrait = UITraitCollection.current.preferredContentSizeCategory.rawValue
            let measured = ImageRenderer(content: framed(content, dark: dark))
            measured.scale = 2
            let height = (measured.uiImage?.size.height ?? 0).rounded(.up)

            let renderer = ImageRenderer(content: framed(
                content.frame(width: width, height: height, alignment: .top),
                dark: dark
            ))
            renderer.scale = 2
            rendered = renderer.uiImage
        }

        guard let image = rendered, let data = image.pngData() else {
            return XCTFail("could not render \(name)")
        }
        try data.write(to: directory.appendingPathComponent("\(name)\(sizeSuffix).png"))
        // `trait=` is the category the render actually ran under. It is printed
        // because it is the one thing about a Dynamic Type image that cannot be
        // checked by looking at it: a file named `-ax2` proves nothing on its
        // own, and this dump has already produced fake ones once.
        print("DUMP \(name)\(sizeSuffix) \(Int(image.size.width))x\(Int(image.size.height)) "
              + "bg=\(Self.sample(image)) trait=\(renderTrait)")
    }

    /// The background and the colour scheme, in that order: `.environment`
    /// propagates into everything it wraps, so setting the scheme OUTSIDE the
    /// background is what makes the background itself resolve dark. Setting it
    /// on the inner content instead leaves the surrounding rectangle light,
    /// which is exactly the bug this ordering was written to fix.
    private func framed<V: View>(_ content: V, dark: Bool) -> some View {
        content
            .background(BBTheme.Colors.background)
            .environment(\.colorScheme, dark ? .dark : .light)
    }

    /// The four raw bytes of a pixel two points inside the top-left corner —
    /// the padded background. Channel order depends on the bitmap layout and is
    /// deliberately not interpreted: light background is ~(246, 243, 251) and
    /// dark is ~(23, 20, 32), which any ordering separates at a glance. This is
    /// how "dark mode was rendered" stops being a claim and becomes a reading.
    private static func sample(_ image: UIImage) -> String {
        guard let cgImage = image.cgImage,
              let pixels = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(pixels) else { return "unreadable" }
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let offset = 4 * cgImage.bytesPerRow + 4 * bytesPerPixel
        guard offset + bytesPerPixel <= CFDataGetLength(pixels) else { return "out-of-range" }
        return (0..<bytesPerPixel).map { String(bytes[offset + $0]) }.joined(separator: ",")
    }
}

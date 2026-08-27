# Feeding ↔ Weight Link Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Answer "is my baby getting enough food?" for 0–6 months by reading weight gain against the WHO reference and presenting the feeding and wet-nappy logs for the same window as context.

**Architecture:** All maths lands in one new pure module, `BabyBloom/Core/Growth/FeedingAdequacy.swift`, with no SwiftData dependency — the same shape as the existing `WeightVelocity` and `NewbornWeightLoss`. It reuses `WeightVelocity` for the gain signal rather than recomputing anything. Two SwiftUI surfaces on the Growth screen consume it: a free summary section and a Premium breakdown card. A simulator-only seed hook makes the whole thing reachable from an authored e2e flow.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (+CloudKit), StoreKit 2, XcodeGen, XCTest, Maestro.

**Spec:** `docs/superpowers/specs/2026-08-25-feeding-weight-link-design.md` — read it before Task 1. It carries the medical constraints, which are requirements and not preferences.

## Global Constraints

- iOS 17.0+, Swift 6.0 (from `project.yml` — do not change).
- The Xcode project is GENERATED. After editing `project.yml`, run `xcodegen generate` AND verify the key actually took — XcodeGen silently ignores unknown or misplaced keys, and this project has been bitten twice.
- Every user-facing string is a key in `en.json` / `ru.json` / `es.json` used through `.l`. The three key sets must stay identical. After any localization edit, copy the files into `WidgetResources/Localization/` — a pre-build script fails the build on drift.
- Brand is per-locale (en → Bitty, ru → Ночка, es → Nenita). Never hardcode it; only `brand.name`.
- CloudKit: any new model field must be optional or carry a default; relationships optional with an inverse; no `.unique`.
- Build check after each task: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build build` → `** BUILD SUCCEEDED **`.
- Test command: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build test`.
- Maestro needs its environment exported first — see `.claude/skills/platform-run/SKILL.md`. Never chain `simctl install` and `maestro test` in one shell: the XCUITest driver dies.
- Commit after each task, messages in English: `feat:` / `fix:` / `refactor:` / `test:` / `docs:`.

## Medical Constraints (requirements, not preferences)

- **Weight is the only trigger.** `warrantsBreakdown` is true if and only if `gain == .below`. No combination of feeding or nappy signals may raise a concern on its own.
- **State and compare; never instruct.** "Feeds: 5 a day, reference 8–12" is allowed. "Feed more often" is a medical instruction and is forbidden in code, copy and comments.
- **No red flag behind the paywall.** `NewbornWeightLoss` and its card stay free and untouched by this plan.
- **Absence of data is never zero.** A signal without enough entries renders "not enough data", never "0 a day".
- Every reference number carries its source in a code comment.

## File Structure

| File | Responsibility |
|---|---|
| `BabyBloom/Core/Growth/FeedingAdequacy.swift` (new) | All adequacy maths: reference tables, window, counting, assembly. Pure, no SwiftData. |
| `BabyBloom/Core/Localization/Double+AppRate.swift` (new) | Renders a measured per-day rate in the app's language, one decimal only when the value is not whole. |
| `BabyBloom/Features/Growth/NutritionSection.swift` (new) | The free summary section — three status rows. |
| `BabyBloom/Features/Growth/FeedingBreakdownCard.swift` (new) | The Premium breakdown card. |
| `BabyBloom/Features/Growth/GrowthView.swift` (modify) | Queries feeds and nappies; composes the two new surfaces. |
| `BabyBloom/Core/Models/SeedScenario.swift` (new) | Simulator-only deterministic data seeding behind a launch argument. |
| `BabyBloom/App/BabyBloomApp.swift` (modify) | Calls the seeder at launch. |
| `BabyBloom/Resources/Localization/{en,ru,es}.json` (modify) | New keys, identical sets, copied to `WidgetResources/`. |
| `BabyBloomTests/FeedingAdequacyTests.swift` (new) | Unit tests for every rule in the module. |
| `BabyBloomTests/NutritionRenderDump.swift` (new) | Visual dump of both surfaces in three locales. |
| `.desk/tests/AC*-nutrition-*.yaml` (new) | Authored Maestro flows over the seeded scenarios. |

---

### Task 1: Reference tables

**Files:**
- Create: `BabyBloom/Core/Growth/FeedingAdequacy.swift`
- Test: `BabyBloomTests/FeedingAdequacyTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `FeedingAdequacy.Signal`, `FeedingAdequacy.FeedingStyle`, `FeedingAdequacy.Feed`, `FeedingAdequacy.maxAgeDays`, `FeedingAdequacy.feedingReference(correctedAgeDays:style:) -> ClosedRange<Double>?`, `FeedingAdequacy.wetNappyMinimum(postnatalDays:) -> Double`.

- [ ] **Step 1: Verify the reference numbers before writing them down**

The owner approved the spec with these tables flagged as not line-by-line verified. Confirm each boundary against a primary source (AAP feeding guidance; AAP/NHS newborn output guidance) and write the source into the code comment you produce in Step 3. If a number differs from the spec, use the verified number and note the change in the commit message — the spec's shape is settled, its exact boundaries were explicitly left open.

- [ ] **Step 2: Write the failing tests**

```swift
import XCTest
@testable import BabyBloom

final class FeedingAdequacyTests: XCTestCase {

    // MARK: - Feeding frequency reference

    func testFeedingReferenceNarrowsWithAge() {
        let newborn = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .breast)
        let older   = FeedingAdequacy.feedingReference(correctedAgeDays: 150, style: .breast)
        XCTAssertEqual(newborn, 8...12)
        XCTAssertEqual(older, 5...7)
    }

    func testFormulaFedBabiesAreHeldToALowerFrequency() {
        // A formula-fed newborn genuinely feeds less often; one table for both
        // would flag healthy babies.
        XCTAssertEqual(FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .formula), 6...8)
    }

    func testMixedFeedingUsesTheUnionOfBothBands() {
        // Neither table fully applies, so the stricter edge of each must not bite.
        let mixed = FeedingAdequacy.feedingReference(correctedAgeDays: 10, style: .mixed)
        XCTAssertEqual(mixed, 6...12)
    }

    func testFeedingReferenceIsNilPastSixMonths() {
        XCTAssertNil(FeedingAdequacy.feedingReference(correctedAgeDays: 200, style: .breast))
    }

    // MARK: - Wet nappy reference

    func testWetNappyMinimumRampsWithTheDayNumberInTheFirstDays() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 1), 1)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 3), 3)
    }

    func testWetNappyMinimumIsSixFromDayFive() {
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 5), 6)
        XCTAssertEqual(FeedingAdequacy.wetNappyMinimum(postnatalDays: 90), 6)
    }
}
```

- [ ] **Step 3: Run the tests and watch them fail**

Run: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build test 2>&1 | grep -E "error:|Executed"`
Expected: compile failure, `cannot find 'FeedingAdequacy' in scope`.

- [ ] **Step 4: Write the module skeleton and the tables**

```swift
import Foundation

/// Reads "is my baby getting enough food?" from the three signals a clinician
/// uses: weight gain, feeding frequency and wet nappies.
///
/// Pure by design — no SwiftData, no model context — like `WeightVelocity` and
/// `NewbornWeightLoss` beside it.
///
/// The medical spine of this module: **weight gain is the only trigger.**
/// Feeding and nappy counts are context. If gain sits within the reference
/// while feeds are few, the baby is getting enough and the app says nothing.
/// Never invent a problem out of secondary signs.
enum FeedingAdequacy {

    /// Where one signal sits against its reference.
    ///
    /// `notEnoughData` is a first-class outcome, not a failure: it is what an
    /// honest app reports when the parent has not logged enough to support a
    /// conclusion. It must never render as zero.
    enum Signal: Equatable {
        case below
        case within
        case notEnoughData
    }

    /// How the baby was actually fed over the window. Derived from the logged
    /// entries, NOT from `Baby.feedingType` — that profile answer is given once
    /// during onboarding and goes stale, and its `mixed` case maps to no
    /// reference column at all.
    enum FeedingStyle: Equatable {
        case breast
        case formula
        case mixed
    }

    /// One logged feed, stripped of storage concerns.
    struct Feed: Equatable {
        let date: Date
        let type: FeedingEntry.FeedingType

        init(date: Date, type: FeedingEntry.FeedingType) {
            self.date = date
            self.type = type
        }
    }

    /// The feature covers 0–6 months. Past it, milk stops being the only source
    /// of nutrition and feed frequency says little about intake, so the whole
    /// assessment is withheld rather than weakened.
    static let maxAgeDays = 183

    /// Feeds per 24h expected at this corrected age.
    ///
    /// Source: AAP feeding guidance for breastfed and formula-fed infants
    /// (verified in Task 1 Step 1 — record the citation you used here).
    /// Returns nil past `maxAgeDays`, where no reference applies.
    static func feedingReference(correctedAgeDays: Int,
                                 style: FeedingStyle) -> ClosedRange<Double>? {
        guard correctedAgeDays <= maxAgeDays else { return nil }

        let breast: ClosedRange<Double>
        let formula: ClosedRange<Double>
        switch correctedAgeDays {
        case ..<28:      breast = 8...12; formula = 6...8
        case 28..<120:   breast = 7...9;  formula = 5...7
        default:         breast = 5...7;  formula = 4...6
        }

        switch style {
        case .breast:  return breast
        case .formula: return formula
        // Neither column fully applies to a mixed-fed baby, so take the union
        // and let the stricter edge of each table go.
        case .mixed:   return min(breast.lowerBound, formula.lowerBound)
                            ...max(breast.upperBound, formula.upperBound)
        }
    }

    /// Wet nappies per 24h expected from a baby this many days after birth.
    ///
    /// Measured in POSTNATAL days, not corrected age: the first-week ramp is
    /// about the transition after birth, not about developmental maturity.
    ///
    /// Source: AAP / NHS newborn output guidance (verified in Task 1 Step 1 —
    /// record the citation you used here).
    static func wetNappyMinimum(postnatalDays: Int) -> Double {
        guard postnatalDays >= 5 else { return Double(max(1, postnatalDays)) }
        return 6
    }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build test 2>&1 | grep -E "error:|Executed [0-9]+ tests"`
Expected: `** TEST SUCCEEDED **`, count up by 6 from the previous run.

- [ ] **Step 6: Add the file to the project and verify the key took**

```bash
xcodegen generate
grep -c "FeedingAdequacy.swift" BabyBloom.xcodeproj/project.pbxproj   # must be > 0
```

`BabyBloom/Core/Growth/` is already inside the app target's scanned `sources`, so no `project.yml` edit is needed — the grep is the proof, not an assumption.

- [ ] **Step 7: Commit**

```bash
git add BabyBloom/Core/Growth/FeedingAdequacy.swift BabyBloomTests/FeedingAdequacyTests.swift
git commit -m "feat: feeding and nappy reference tables for adequacy"
```

---

### Task 2: Window, counting and feeding style

**Files:**
- Modify: `BabyBloom/Core/Growth/FeedingAdequacy.swift`
- Test: `BabyBloomTests/FeedingAdequacyTests.swift`

**Interfaces:**
- Consumes: `FeedingAdequacy.Feed`, `FeedingAdequacy.FeedingStyle` from Task 1.
- Produces: `FeedingAdequacy.window(for:) -> DateInterval?`, `FeedingAdequacy.style(of:) -> FeedingStyle`, `FeedingAdequacy.rate(of:in:) -> Double`, `FeedingAdequacy.hasEnoughCoverage(_:in:) -> Bool`.

- [ ] **Step 1: Write the failing tests**

```swift
    // MARK: - Window

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    func testWindowSpansTheTwoMostRecentWeighings() {
        let measurements = [
            WeightMeasurement(date: day(-30), weightKg: 3.4),
            WeightMeasurement(date: day(-9),  weightKg: 4.0),
            WeightMeasurement(date: day(0),   weightKg: 4.3),
        ]
        let window = FeedingAdequacy.window(for: measurements)
        // The older weighing is history; the assessment covers the latest gap.
        XCTAssertEqual(Calendar.current.dateComponents([.day],
                                                       from: try XCTUnwrap(window).start,
                                                       to: try XCTUnwrap(window).end).day, 9)
    }

    func testWindowIsNilWithFewerThanTwoWeighings() {
        XCTAssertNil(FeedingAdequacy.window(for: [WeightMeasurement(date: day(0), weightKg: 4.0)]))
        XCTAssertNil(FeedingAdequacy.window(for: []))
    }

    // MARK: - Feeding style from the logs

    func testStyleIsBreastWhenAlmostAllFeedsAreBreast() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 == 0 ? .formula : .breast) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .breast)
    }

    func testStyleIsFormulaWhenPumpedAndFormulaDominate() {
        // Pumped milk is given by bottle on a formula-like schedule, so it
        // counts with formula for frequency purposes.
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .formula : .pumped) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .formula)
    }

    func testStyleIsMixedWhenNeitherDominates() {
        let feeds = (0..<10).map { FeedingAdequacy.Feed(date: day(-$0), type: $0 < 5 ? .breast : .formula) }
        XCTAssertEqual(FeedingAdequacy.style(of: feeds), .mixed)
    }

    func testStyleOfNothingIsMixed() {
        // With no evidence, take the widest reference rather than guessing.
        XCTAssertEqual(FeedingAdequacy.style(of: []), .mixed)
    }

    // MARK: - Rate and coverage

    func testRateIsPerDayOverTheWindow() {
        let window = DateInterval(start: day(-10), end: day(0))
        let dates = (0..<20).map { day(-$0 / 2) }
        XCTAssertEqual(FeedingAdequacy.rate(of: dates, in: window), 2.0, accuracy: 0.01)
    }

    func testCoverageFailsWhenMostDaysHaveNoEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        // Ten entries, all on one day: plenty of records, almost no coverage.
        let clustered = Array(repeating: day(-1), count: 10)
        XCTAssertFalse(FeedingAdequacy.hasEnoughCoverage(clustered, in: window))
    }

    func testCoveragePassesWhenMostDaysHaveAnEntry() {
        let window = DateInterval(start: day(-10), end: day(0))
        let spread = (0...10).map { day(-$0) }
        XCTAssertTrue(FeedingAdequacy.hasEnoughCoverage(spread, in: window))
    }
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build test 2>&1 | grep -E "error:"`
Expected: `cannot find 'window' in scope` and siblings.

- [ ] **Step 3: Implement**

```swift
    // MARK: - Window

    /// The interval the assessment covers: between the two most recent
    /// weighings. Feeds and nappies are counted over this same window, so a
    /// "few feeds" figure can never sit beside a gain measured across a
    /// different week.
    static func window(for measurements: [WeightMeasurement]) -> DateInterval? {
        let sorted = measurements.sorted { $0.date < $1.date }
        guard sorted.count >= 2 else { return nil }
        let start = sorted[sorted.count - 2].date
        let end = sorted[sorted.count - 1].date
        guard end > start else { return nil }
        return DateInterval(start: start, end: end)
    }

    // MARK: - Feeding style

    /// The dominant feeding style over the window, from what was logged.
    ///
    /// Pumped milk is bottle-fed on a formula-like schedule, so it counts with
    /// formula for FREQUENCY purposes — this says nothing about what is in the
    /// bottle. Below the dominance threshold the baby is genuinely mixed-fed
    /// and gets the union reference; with no feeds at all, the same, because
    /// the widest band is the honest choice when there is no evidence.
    static func style(of feeds: [Feed]) -> FeedingStyle {
        guard !feeds.isEmpty else { return .mixed }
        let dominanceThreshold = 0.8
        let breastShare = Double(feeds.filter { $0.type == .breast }.count) / Double(feeds.count)
        if breastShare >= dominanceThreshold { return .breast }
        if (1 - breastShare) >= dominanceThreshold { return .formula }
        return .mixed
    }

    // MARK: - Counting

    /// Events per day over the window.
    static func rate(of dates: [Date], in window: DateInterval) -> Double {
        let days = max(1.0, window.duration / 86_400)
        let inside = dates.filter { window.contains($0) }.count
        return Double(inside) / days
    }

    /// Whether the logs cover enough of the window to support a conclusion.
    ///
    /// Counts DAYS WITH AT LEAST ONE ENTRY, not entries: ten records on a single
    /// day are a busy Tuesday, not a fortnight of evidence. Below half the days,
    /// the signal reports `notEnoughData`.
    static func hasEnoughCoverage(_ dates: [Date], in window: DateInterval) -> Bool {
        let calendar = Calendar.current
        let days = max(1, Int((window.duration / 86_400).rounded()))
        let covered = Set(dates.filter { window.contains($0) }.map { calendar.startOfDay(for: $0) })
        return Double(covered.count) / Double(days) >= 0.5
    }
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: the test command from Global Constraints.
Expected: `** TEST SUCCEEDED **`, count up by 9.

- [ ] **Step 5: Commit**

```bash
git add BabyBloom/Core/Growth/FeedingAdequacy.swift BabyBloomTests/FeedingAdequacyTests.swift
git commit -m "feat: window, rate, coverage and feeding style for adequacy"
```

---

### Task 3: The assessment

**Files:**
- Modify: `BabyBloom/Core/Growth/FeedingAdequacy.swift`
- Test: `BabyBloomTests/FeedingAdequacyTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–2, plus `WeightVelocity.measure(from:to:correctedBirthDate:isMale:)` and `WeightVelocity.Band`.
- Produces: `FeedingAdequacy.Assessment` (properties: `windowDays: Int`, `gain: Signal`, `feedingsPerDay: Double?`, `feedingReference: ClosedRange<Double>?`, `feeding: Signal`, `wetNappiesPerDay: Double?`, `wetNappyMinimum: Double?`, `nappies: Signal`, `warrantsBreakdown: Bool`) and `FeedingAdequacy.assess(birthDate:correctedBirthDate:isMale:measurements:feeds:wetNappies:now:) -> Assessment?`.

- [ ] **Step 1: Write the failing tests**

```swift
    // MARK: - Assembly

    private func measurements(gainGramsPerDay: Double, days: Int) -> [WeightMeasurement] {
        let start = 4.0
        return [
            WeightMeasurement(date: day(-days), weightKg: start),
            WeightMeasurement(date: day(0), weightKg: start + gainGramsPerDay * Double(days) / 1000),
        ]
    }

    private func feeds(perDay: Int, days: Int, type: FeedingEntry.FeedingType = .breast) -> [FeedingAdequacy.Feed] {
        (0..<days).flatMap { d in
            (0..<perDay).map { _ in FeedingAdequacy.Feed(date: day(-d), type: type) }
        }
    }

    private func nappies(perDay: Int, days: Int) -> [Date] {
        (0..<days).flatMap { d in (0..<perDay).map { _ in day(-d) } }
    }

    private func assess(gain: Double, feedsPerDay: Int, nappiesPerDay: Int,
                        days: Int = 9, ageDays: Int = 40) -> FeedingAdequacy.Assessment? {
        let birth = day(-ageDays)
        return FeedingAdequacy.assess(
            birthDate: birth,
            correctedBirthDate: birth,
            isMale: true,
            measurements: measurements(gainGramsPerDay: gain, days: days),
            feeds: feeds(perDay: feedsPerDay, days: days),
            wetNappies: nappies(perDay: nappiesPerDay, days: days),
            now: Date()
        )
    }

    /// THE medical rule of this feature.
    func testGainWithinReferenceNeverWarrantsABreakdownHoweverPoorTheOtherSignals() {
        // Healthy gain, almost no feeds logged, almost no nappies: the baby is
        // getting enough, and the app must say nothing.
        let assessment = try! XCTUnwrap(assess(gain: 30, feedsPerDay: 2, nappiesPerDay: 1))
        XCTAssertEqual(assessment.gain, .within)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }

    func testGainBelowReferenceWarrantsABreakdown() {
        let assessment = try! XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7))
        XCTAssertEqual(assessment.gain, .below)
        XCTAssertTrue(assessment.warrantsBreakdown)
    }

    func testSignalsReportBelowAgainstTheirReferences() {
        let assessment = try! XCTUnwrap(assess(gain: 5, feedsPerDay: 3, nappiesPerDay: 2))
        XCTAssertEqual(assessment.feeding, .below)
        XCTAssertEqual(assessment.nappies, .below)
        XCTAssertEqual(assessment.feedingsPerDay, 3, accuracy: 0.2)
        XCTAssertEqual(assessment.wetNappiesPerDay, 2, accuracy: 0.2)
    }

    /// An unlogged signal must never read as zero.
    func testUnloggedSignalsAreNotEnoughDataRatherThanZero() {
        let birth = day(-40)
        let assessment = try! XCTUnwrap(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: measurements(gainGramsPerDay: 5, days: 9),
            feeds: [], wetNappies: [], now: Date()
        ))
        XCTAssertEqual(assessment.feeding, .notEnoughData)
        XCTAssertEqual(assessment.nappies, .notEnoughData)
        XCTAssertNil(assessment.feedingsPerDay)
        XCTAssertNil(assessment.wetNappiesPerDay)
    }

    func testAssessmentIsNilPastSixMonths() {
        XCTAssertNil(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7, ageDays: 200))
    }

    func testAssessmentIsNilWithoutTwoWeighings() {
        let birth = day(-40)
        XCTAssertNil(FeedingAdequacy.assess(
            birthDate: birth, correctedBirthDate: birth, isMale: true,
            measurements: [WeightMeasurement(date: day(0), weightKg: 4.0)],
            feeds: [], wetNappies: [], now: Date()
        ))
    }

    /// A weighing gap under 3 days is noise, and WeightVelocity already refuses
    /// it. The assessment must degrade to notEnoughData, not to a false calm.
    func testShortWeighingGapLeavesGainUnknownAndCannotTrigger() {
        let assessment = try! XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 7, days: 2))
        XCTAssertEqual(assessment.gain, .notEnoughData)
        XCTAssertFalse(assessment.warrantsBreakdown)
    }

    /// The Diapers screen's editable target must not be able to change a
    /// clinical verdict — this asserts the assessment ignores it entirely.
    func testNappyVerdictIgnoresTheUserEditableDailyTarget() {
        UserDefaults.standard.set(2, forKey: "diaperDailyNorm")
        defer { UserDefaults.standard.removeObject(forKey: "diaperDailyNorm") }
        let assessment = try! XCTUnwrap(assess(gain: 5, feedsPerDay: 8, nappiesPerDay: 3))
        XCTAssertEqual(assessment.nappies, .below, "3 a day is below the clinical 6, whatever the user set")
    }
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: the test command from Global Constraints.
Expected: `cannot find 'assess' in scope`.

- [ ] **Step 3: Implement**

```swift
    // MARK: - Assessment

    struct Assessment: Equatable {
        /// Whole days between the two weighings the assessment covers.
        let windowDays: Int
        let gain: Signal
        /// nil when the signal is `notEnoughData` — never 0, which would read
        /// as "your baby fed zero times".
        let feedingsPerDay: Double?
        let feedingReference: ClosedRange<Double>?
        let feeding: Signal
        let wetNappiesPerDay: Double?
        let wetNappyMinimum: Double?
        let nappies: Signal

        /// The single gate for the breakdown card. Weight is the only trigger:
        /// see the module comment.
        var warrantsBreakdown: Bool { gain == .below }
    }

    /// nil when the feature does not apply at all: no second weighing to define
    /// a window, or a baby past six months.
    static func assess(
        birthDate: Date,
        correctedBirthDate: Date,
        isMale: Bool,
        measurements: [WeightMeasurement],
        feeds: [Feed],
        wetNappies: [Date],
        now: Date = Date()
    ) -> Assessment? {
        let calendar = Calendar.current
        let correctedAgeDays = calendar.dateComponents([.day], from: correctedBirthDate, to: now).day ?? 0
        guard correctedAgeDays <= maxAgeDays else { return nil }
        guard let window = window(for: measurements) else { return nil }

        let sorted = measurements.sorted { $0.date < $1.date }
        let reading = WeightVelocity.measure(
            from: sorted[sorted.count - 2],
            to: sorted[sorted.count - 1],
            correctedBirthDate: correctedBirthDate,
            isMale: isMale
        )
        let gain: Signal
        switch reading?.band {
        case .below:            gain = .below
        case .within, .above:   gain = .within
        case nil:               gain = .notEnoughData
        }

        let windowFeeds = feeds.filter { window.contains($0.date) }
        let feedingReference = feedingReference(correctedAgeDays: correctedAgeDays,
                                                style: style(of: windowFeeds))
        let feedingsPerDay: Double?
        let feedingSignal: Signal
        if hasEnoughCoverage(windowFeeds.map(\.date), in: window), let reference = feedingReference {
            let rate = rate(of: windowFeeds.map(\.date), in: window)
            feedingsPerDay = rate
            feedingSignal = rate < reference.lowerBound ? .below : .within
        } else {
            feedingsPerDay = nil
            feedingSignal = .notEnoughData
        }

        // POSTNATAL days, not corrected: the first-week ramp is about the
        // transition after birth.
        let postnatalDays = calendar.dateComponents([.day], from: birthDate, to: now).day ?? 0
        let minimum = wetNappyMinimum(postnatalDays: postnatalDays)
        let nappiesPerDay: Double?
        let nappySignal: Signal
        if hasEnoughCoverage(wetNappies, in: window) {
            let rate = rate(of: wetNappies, in: window)
            nappiesPerDay = rate
            nappySignal = rate < minimum ? .below : .within
        } else {
            nappiesPerDay = nil
            nappySignal = .notEnoughData
        }

        return Assessment(
            windowDays: max(1, Int((window.duration / 86_400).rounded())),
            gain: gain,
            feedingsPerDay: feedingsPerDay,
            feedingReference: feedingReference,
            feeding: feedingSignal,
            wetNappiesPerDay: nappiesPerDay,
            wetNappyMinimum: nappiesPerDay == nil ? nil : minimum,
            nappies: nappySignal
        )
    }
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: the test command from Global Constraints.
Expected: `** TEST SUCCEEDED **`, count up by 8.

- [ ] **Step 5: Commit**

```bash
git add BabyBloom/Core/Growth/FeedingAdequacy.swift BabyBloomTests/FeedingAdequacyTests.swift
git commit -m "feat: assemble the feeding adequacy assessment"
```

---

### Task 4: Localization keys

**Files:**
- Modify: `BabyBloom/Resources/Localization/en.json`, `ru.json`, `es.json`
- Modify (copy): `WidgetResources/Localization/en.json`, `ru.json`, `es.json`

**Interfaces:**
- Consumes: nothing.
- Produces: the keys every later task uses. Do this BEFORE the UI tasks so no view ships a raw key string.

The window copy declines the day-word through the project's existing
`Int.dayWord` (`age.day.one/few/many`), so Russian reads "за последние 9 дней"
and "за последние 2 дня" correctly. Formats therefore take `%d %@`.

- [ ] **Step 1: Add the keys**

```bash
python3 - <<'PY'
import json, collections
new = {
 "en": {
   "section.nutrition":        "Nutrition",
   "nutrition.window_fmt":     "over the last %d %@",
   "nutrition.row_gain":       "Weight gain",
   "nutrition.row_feeds":      "Feeds",
   "nutrition.row_nappies":    "Wet nappies",
   "nutrition.status_below":   "below the reference",
   "nutrition.status_within":  "within the reference",
   "nutrition.status_unknown": "not enough data",
   "nutrition.per_day_fmt":    "%.0f a day",
   "nutrition.need_weighing":  "Weigh your baby again to see this.",
   "breakdown.title":          "Gain is below the reference",
   "breakdown.gain_fmt":       "%d g/week over %d %@. The reference for this age is %d–%d g/week.",
   "breakdown.feeds_fmt":      "Feeds: %.0f a day, reference %.0f–%.0f.",
   "breakdown.nappies_fmt":    "Wet nappies: %.0f a day, reference %.0f or more.",
   "breakdown.no_data":        "Feeding and nappy logs for this period are too sparse to compare.",
   "breakdown.disclaimer":     "This is an observation, not a diagnosis. Worth discussing with your paediatrician.",
   "premium.teaser_nutrition": "See how this period's feeds and nappies compare with the references.",
 },
 "ru": {
   "section.nutrition":        "Питание",
   "nutrition.window_fmt":     "за последние %d %@",
   "nutrition.row_gain":       "Прибавка",
   "nutrition.row_feeds":      "Кормления",
   "nutrition.row_nappies":    "Мокрые подгузники",
   "nutrition.status_below":   "ниже ориентира",
   "nutrition.status_within":  "в ориентире",
   "nutrition.status_unknown": "данных мало",
   "nutrition.per_day_fmt":    "%.0f в сутки",
   "nutrition.need_weighing":  "Взвесьте малыша ещё раз, чтобы увидеть.",
   "breakdown.title":          "Прибавка ниже ориентира",
   "breakdown.gain_fmt":       "%d г/нед за %d %@. Ориентир для этого возраста — %d–%d г/нед.",
   "breakdown.feeds_fmt":      "Кормлений: %.0f в сутки, ориентир %.0f–%.0f.",
   "breakdown.nappies_fmt":    "Мокрых подгузников: %.0f в сутки, ориентир от %.0f.",
   "breakdown.no_data":        "Записей о кормлениях и подгузниках за этот период слишком мало для сравнения.",
   "breakdown.disclaimer":     "Это наблюдение, а не диагноз. Стоит обсудить с педиатром.",
   "premium.teaser_nutrition": "Посмотрите, как кормления и подгузники за этот период соотносятся с ориентирами.",
 },
 "es": {
   "section.nutrition":        "Nutrición",
   "nutrition.window_fmt":     "en los últimos %d %@",
   "nutrition.row_gain":       "Aumento de peso",
   "nutrition.row_feeds":      "Tomas",
   "nutrition.row_nappies":    "Pañales mojados",
   "nutrition.status_below":   "por debajo de la referencia",
   "nutrition.status_within":  "dentro de la referencia",
   "nutrition.status_unknown": "datos insuficientes",
   "nutrition.per_day_fmt":    "%.0f al día",
   "nutrition.need_weighing":  "Pesa a tu bebé otra vez para verlo.",
   "breakdown.title":          "El aumento está por debajo de la referencia",
   "breakdown.gain_fmt":       "%d g/semana en %d %@. La referencia para esta edad es %d–%d g/semana.",
   "breakdown.feeds_fmt":      "Tomas: %.0f al día, referencia %.0f–%.0f.",
   "breakdown.nappies_fmt":    "Pañales mojados: %.0f al día, referencia %.0f o más.",
   "breakdown.no_data":        "Hay muy pocos registros de tomas y pañales en este periodo para comparar.",
   "breakdown.disclaimer":     "Esto es una observación, no un diagnóstico. Conviene comentarlo con tu pediatra.",
   "premium.teaser_nutrition": "Mira cómo se comparan las tomas y los pañales de este periodo con las referencias.",
 },
}
for lang, adds in new.items():
    p = f"BabyBloom/Resources/Localization/{lang}.json"
    with open(p, encoding="utf-8") as f:
        d = json.load(f, object_pairs_hook=collections.OrderedDict)
    d.update(adds)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2); f.write("\n")
    print(lang, len(d))
PY
for f in en ru es; do cp "BabyBloom/Resources/Localization/$f.json" "WidgetResources/Localization/$f.json"; done
```

- [ ] **Step 2: Verify all three key sets are identical and the copies match**

```bash
python3 -c "
import json
sets = {l: set(json.load(open(f'BabyBloom/Resources/Localization/{l}.json'))) for l in ['en','ru','es']}
assert sets['en'] == sets['ru'] == sets['es'], sets['en'] ^ sets['ru'] | sets['en'] ^ sets['es']
print('key sets identical:', len(sets['en']))"
for f in en ru es; do cmp "BabyBloom/Resources/Localization/$f.json" "WidgetResources/Localization/$f.json" && echo "$f synced"; done
```

Expected: `key sets identical: <n>` and three `synced` lines.

- [ ] **Step 3: Build, so the pre-build sync guard runs**

Run the build command from Global Constraints.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add BabyBloom/Resources/Localization WidgetResources/Localization
git commit -m "feat: localization keys for the nutrition section and breakdown"
```

---

### Task 5: Free "Nutrition" section

**Files:**
- Create: `BabyBloom/Core/Localization/Double+AppRate.swift`
- Create: `BabyBloom/Features/Growth/NutritionSection.swift`
- Modify: `BabyBloom/Features/Growth/GrowthInsightCards.swift:6` and `:26` — drop `private` from `InsightCard` and `HintText` so the new files reuse them
- Test: covered visually in Task 7

**Interfaces:**
- Consumes: `FeedingAdequacy.Assessment`, `FeedingAdequacy.Signal`, `InsightCard`, `HintText`.
- Produces: `NutritionSection(assessment: FeedingAdequacy.Assessment?)`.

- [ ] **Step 1: Add the rate formatter**

The measured rate must never be rounded for display: the verdict beside it
compares the RAW value against a whole bound, so `%.0f` would print
"8 a day · below the reference" next to "reference 8–12" for a rate of 7.6.
That contradiction band sits immediately below every threshold — exactly the
near-miss population this feature describes. The keys therefore take `%@` for
measured values and `%d` for whole bounds, matching what `velocity.per_week_fmt`
and `velocity.expected_fmt` already do on this screen.

Create `BabyBloom/Core/Localization/Double+AppRate.swift`, beside the
`Date+AppLocale.swift` helpers that established this pattern:

```swift
import Foundation

extension Double {
    /// A measured per-day rate, rendered in the app's language.
    ///
    /// One decimal only when the value is not whole — "9 a day" reads better
    /// than "9.0 a day", while 7.6 must NOT become "8": the verdict beside it
    /// compares the raw value against a whole bound, and a rounded display
    /// would contradict its own status word.
    ///
    /// The decimal separator follows the app's chosen language, not the
    /// device — Russian and Spanish want "7,6".
    var appRate: String {
        let formatter = NumberFormatter()
        formatter.locale = LocalizationManager.shared.language.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: self as NSNumber) ?? String(format: "%.0f", self)
    }
}
```

- [ ] **Step 2: Make the two containers reusable**

In `GrowthInsightCards.swift`, change `private struct InsightCard` to `struct InsightCard` and `private struct HintText` to `struct HintText`. That file already holds ten views at 275 lines; the new surfaces get their own files rather than growing it further.

- [ ] **Step 3: Write the section**

```swift
import SwiftUI

/// The free half of the feeding–weight feature: three signals, plainly stated.
///
/// Most of the time all three read "within the reference" and this section's
/// job is reassurance. Status is carried by a WORD, with colour as
/// reinforcement only, so the row survives greyscale and VoiceOver.
struct NutritionSection: View {
    let assessment: FeedingAdequacy.Assessment?

    var body: some View {
        InsightCard(title: "section.nutrition".l) {
            if let assessment {
                VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                    Text(String(format: "nutrition.window_fmt".l,
                                assessment.windowDays, assessment.windowDays.dayWord))
                        .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                                        weight: .regular, design: .rounded))
                        .foregroundStyle(BBTheme.Colors.textSecondary)

                    // The gain row shows STATUS ONLY. Grams per week stay in the
                    // Premium WeightGainCard, where they already are.
                    row(icon: "chart.line.uptrend.xyaxis", tint: BBTheme.Colors.growth,
                        label: "nutrition.row_gain".l, value: nil, signal: assessment.gain)
                    row(icon: "heart.fill", tint: BBTheme.Colors.feeding,
                        label: "nutrition.row_feeds".l,
                        value: assessment.feedingsPerDay, signal: assessment.feeding)
                    row(icon: "drop.fill", tint: BBTheme.Colors.diaper,
                        label: "nutrition.row_nappies".l,
                        value: assessment.wetNappiesPerDay, signal: assessment.nappies)
                }
            } else {
                HintText(text: "nutrition.need_weighing".l)
            }
        }
    }

    @ViewBuilder
    private func row(icon: String, tint: Color, label: String,
                     value: Double?, signal: FeedingAdequacy.Signal) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: BBTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(label)
                .font(BBTheme.Typography.scaled(15, relativeTo: .body,
                                                weight: .medium, design: .rounded))
                .foregroundStyle(BBTheme.Colors.textPrimary)
            Spacer(minLength: BBTheme.Spacing.sm)
            Text(statusText(value: value, signal: signal))
                .font(BBTheme.Typography.scaled(13, relativeTo: .caption1,
                                                weight: .semibold, design: .rounded))
                .foregroundStyle(color(for: signal))
                .multilineTextAlignment(.trailing)
        }
    }

    /// A value is shown only when there IS one. `notEnoughData` must never
    /// render as "0 a day" — that would tell a parent their baby fed zero times
    /// when in truth they simply did not log.
    private func statusText(value: Double?, signal: FeedingAdequacy.Signal) -> String {
        let status: String
        switch signal {
        case .below:         status = "nutrition.status_below".l
        case .within:        status = "nutrition.status_within".l
        case .notEnoughData: return "nutrition.status_unknown".l
        }
        guard let value else { return status }
        return String(format: "nutrition.per_day_fmt".l, value.appRate) + " · " + status
    }

    private func color(for signal: FeedingAdequacy.Signal) -> Color {
        switch signal {
        case .below:         return BBTheme.Colors.accent
        case .within:        return BBTheme.Colors.success
        case .notEnoughData: return BBTheme.Colors.textSecondary
        }
    }
}
```

- [ ] **Step 4: Note on colour**

`below` uses `BBTheme.Colors.accent`, the warm peach accent — NOT a red. This
palette has no alarm colour on purpose, and the existing first-weeks flag card
does not use one either. Do not add one for this feature: the word carries the
status, and shouting contradicts the tone the medical constraints require.

- [ ] **Step 5: Build**

Run the build command from Global Constraints.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add BabyBloom/Core/Localization/Double+AppRate.swift \
        BabyBloom/Features/Growth/NutritionSection.swift \
        BabyBloom/Features/Growth/GrowthInsightCards.swift
git commit -m "feat: free nutrition summary section"
```

---

### Task 6: Premium breakdown card and Growth wiring

**Files:**
- Create: `BabyBloom/Features/Growth/FeedingBreakdownCard.swift`
- Modify: `BabyBloom/Features/Growth/GrowthView.swift`

**Interfaces:**
- Consumes: `FeedingAdequacy.Assessment`, `InsightCard`, `LockedInsightCard`, `NutritionSection`, `store.isPremium`.
- Produces: `FeedingBreakdownCard(assessment: FeedingAdequacy.Assessment, reading: WeightVelocity.Reading?)`.

- [ ] **Step 1: Write the card**

```swift
import SwiftUI

/// The Premium half: what the same window's feeds and nappies looked like when
/// gain came in below the reference.
///
/// It STATES and COMPARES. It never instructs — "feeds: 5 a day, reference
/// 8–12" is information a parent can take to a clinician; "feed more often" is
/// a medical instruction and is out of bounds for this app.
struct FeedingBreakdownCard: View {
    let assessment: FeedingAdequacy.Assessment
    let reading: WeightVelocity.Reading?

    var body: some View {
        InsightCard(title: "breakdown.title".l) {
            VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
                if let line = gainLine {
                    Text(line)
                }
                if let line = feedsLine {
                    Text(line)
                }
                if let line = nappiesLine {
                    Text(line)
                }
                if feedsLine == nil && nappiesLine == nil {
                    Text("breakdown.no_data".l)
                }
                Text("breakdown.disclaimer".l)
                    .foregroundStyle(BBTheme.Colors.textSecondary)
                    .padding(.top, 2)
            }
            .font(BBTheme.Typography.scaled(14, relativeTo: .body,
                                            weight: .regular, design: .rounded))
            .foregroundStyle(BBTheme.Colors.textPrimary)
        }
    }

    private var gainLine: String? {
        guard let reading, let expected = reading.expectedPerWeek else { return nil }
        return String(format: "breakdown.gain_fmt".l,
                      Int(reading.gramsPerWeek.rounded()),
                      assessment.windowDays,
                      assessment.windowDays.dayWord,
                      Int(expected.lowerBound.rounded()),
                      Int(expected.upperBound.rounded()))
    }

    private var feedsLine: String? {
        guard let perDay = assessment.feedingsPerDay,
              let reference = assessment.feedingReference else { return nil }
        // Measured value as a string, bounds as whole numbers — the same
        // split velocity.per_week_fmt / velocity.expected_fmt already use.
        return String(format: "breakdown.feeds_fmt".l,
                      perDay.appRate,
                      Int(reference.lowerBound.rounded()),
                      Int(reference.upperBound.rounded()))
    }

    private var nappiesLine: String? {
        guard let perDay = assessment.wetNappiesPerDay,
              let minimum = assessment.wetNappyMinimum else { return nil }
        return String(format: "breakdown.nappies_fmt".l,
                      perDay.appRate, Int(minimum.rounded()))
    }
}
```

- [ ] **Step 2: Add the queries GrowthView needs**

In `GrowthView.swift`, beside the existing `@Query` properties:

```swift
    @Query(sort: \FeedingEntry.startTime, order: .reverse) private var feedings: [FeedingEntry]
    @Query(sort: \DiaperEntry.time, order: .reverse) private var diapers: [DiaperEntry]
```

- [ ] **Step 3: Add the assessment and the two surfaces**

Add to `GrowthView`:

```swift
    /// Built from the same queries the rest of the screen uses, filtered in
    /// memory — the window is weeks, not years.
    private func adequacy(_ baby: Baby) -> FeedingAdequacy.Assessment? {
        FeedingAdequacy.assess(
            birthDate: baby.birthDate,
            correctedBirthDate: baby.correctedBirthDate,
            isMale: baby.gender == .male,
            measurements: measurements,
            feeds: feedings.map { FeedingAdequacy.Feed(date: $0.startTime, type: $0.type) },
            wetNappies: diapers.filter { $0.type == .wet || $0.type == .both }.map(\.time)
        )
    }

    /// Free summary, then the Premium breakdown — and the breakdown appears
    /// only when gain itself came in below the reference. Feeding and nappy
    /// signals never open it on their own.
    @ViewBuilder
    private func nutritionSection(_ baby: Baby) -> some View {
        // Two different nils. Past six months the feature does not apply and
        // NOTHING shows. Inside the range with fewer than two weighings, the
        // section shows its "weigh again" prompt — passing nil through is what
        // makes that state reachable at all.
        if baby.correctedAgeDays <= FeedingAdequacy.maxAgeDays {
            let assessment = adequacy(baby)
            NutritionSection(assessment: assessment)
            if let assessment, assessment.warrantsBreakdown {
                if store.isPremium {
                    FeedingBreakdownCard(
                        assessment: assessment,
                        reading: WeightVelocity.latest(
                            measurements: measurements,
                            correctedBirthDate: baby.correctedBirthDate,
                            isMale: baby.gender == .male
                        )
                    )
                } else {
                    LockedInsightCard(
                        title: "breakdown.title".l,
                        teaser: "premium.teaser_nutrition".l
                    ) { showPaywall = true }
                }
            }
        }
    }
```

- [ ] **Step 4: Place it in the body**

In the `ScrollView`'s `VStack`, immediately after the `weightGainSection(baby)` call:

```swift
                if let baby {
                    nutritionSection(baby)
                        .padding(.horizontal, BBTheme.Spacing.md)
                }
```

It sits below gain and trend deliberately: `NewbornProgressCard` — the free red flags — must stay the first thing a worried parent sees.

- [ ] **Step 5: Build and run the existing tests**

Run the build and test commands from Global Constraints.
Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **` with no change in count.

- [ ] **Step 6: Commit**

```bash
git add BabyBloom/Features/Growth/FeedingBreakdownCard.swift BabyBloom/Features/Growth/GrowthView.swift
git commit -m "feat: premium feeding breakdown card wired into Growth"
```

---

### Task 7: Render dump across locales

**Files:**
- Create: `BabyBloomTests/NutritionRenderDump.swift`

**Interfaces:**
- Consumes: `NutritionSection`, `FeedingBreakdownCard`, `FeedingAdequacy.Assessment`, `WeightVelocity.Reading`.
- Produces: PNGs under `bb-nutrition` in the simulator's tmp; path printed as `NUTRITION_DIR=`.

- [ ] **Step 1: Write the dump**

```swift
import XCTest
import SwiftUI
@testable import BabyBloom

/// Not an assertion suite — a visual dump, the same idea as
/// `GrowthCardRenderDump`. Renders both new surfaces in every shipped language
/// so wrapping and tone can be eyeballed without driving the whole app.
///
/// Run it, read `NUTRITION_DIR` from the test log, open the files.
@MainActor
final class NutritionRenderDump: XCTestCase {

    private func assessment(gain: FeedingAdequacy.Signal,
                            feeds: Double?, nappies: Double?) -> FeedingAdequacy.Assessment {
        FeedingAdequacy.Assessment(
            windowDays: 9,
            gain: gain,
            feedingsPerDay: feeds,
            feedingReference: feeds == nil ? nil : 8...12,
            feeding: feeds == nil ? .notEnoughData : (feeds! < 8 ? .below : .within),
            wetNappiesPerDay: nappies,
            wetNappyMinimum: nappies == nil ? nil : 6,
            nappies: nappies == nil ? .notEnoughData : (nappies! < 6 ? .below : .within)
        )
    }

    private let reading = WeightVelocity.Reading(
        gramsPerDay: 17, intervalDays: 9, expectedPerWeek: 155...241, band: .below
    )

    func testDumpNutritionSurfaces() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bb-nutrition")
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for locale in ["en", "ru", "es"] {
            LocalizationManager.shared.setLanguage(locale)

            // The common case: everything within reference. This is what most
            // parents see most days, and it must read calm.
            try dump("\(locale)-calm",
                     NutritionSection(assessment: assessment(gain: .within, feeds: 9, nappies: 7)))
            // The case the feature exists for.
            try dump("\(locale)-below",
                     NutritionSection(assessment: assessment(gain: .below, feeds: 5, nappies: 4)))
            // A parent who logs feeds but not nappies must see honesty, not a zero.
            try dump("\(locale)-sparse",
                     NutritionSection(assessment: assessment(gain: .below, feeds: 5, nappies: nil)))
            try dump("\(locale)-needs-weighing", NutritionSection(assessment: nil))
            try dump("\(locale)-breakdown",
                     FeedingBreakdownCard(assessment: assessment(gain: .below, feeds: 5, nappies: 4),
                                          reading: reading))
            try dump("\(locale)-breakdown-sparse",
                     FeedingBreakdownCard(assessment: assessment(gain: .below, feeds: nil, nappies: nil),
                                          reading: reading))
        }

        print("NUTRITION_DIR=\(dir.path)")
    }

    private func dump<V: View>(_ name: String, _ view: V) throws {
        let framed = view
            .frame(width: 340)
            .padding(16)
            .background(BBTheme.Colors.background)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else {
            return XCTFail("could not render \(name)")
        }
        try data.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("bb-nutrition")
            .appendingPathComponent("\(name).png"))
    }
}
```

If `WeightVelocity.Reading`'s memberwise initializer is not reachable from the
test target, add `init` explicitly to the struct in
`BabyBloom/Core/Growth/WeightVelocity.swift` rather than working around it in
the test.

- [ ] **Step 2: Run it and read the output**

Run the test command from Global Constraints, then:

```bash
grep NUTRITION_DIR <test output>
open "$(...)"   # 18 files: 6 per locale
```

- [ ] **Step 3: Check each one against the medical constraints**

For every file: no instruction verb ("feed more", "increase"), no diagnosis word, no "0 a day" anywhere a signal is unknown, and the `calm` variants genuinely read calm rather than alarming. A file that fails this is a copy bug — fix the localization, not the screenshot.

- [ ] **Step 4: Commit**

```bash
git add BabyBloomTests/NutritionRenderDump.swift
git commit -m "test: visual dump of the nutrition section and breakdown"
```

---

### Task 8: Seeded scenarios

**Files:**
- Create: `BabyBloom/Core/Models/SeedScenario.swift`
- Modify: `BabyBloom/App/BabyBloomApp.swift`
- Modify: `.desk/app-map.md`
- Modify: `.claude/skills/platform-run/SKILL.md`

**Interfaces:**
- Consumes: the SwiftData models.
- Produces: launch argument `-BBSeedScenario <lowGain|healthy|sparseLogs>`; `SeedScenario.seedIfRequested(in:)`.

- [ ] **Step 1: Write the seeder**

```swift
import Foundation
import SwiftData

/// Deterministic data for driving the app in tests. Simulator-only.
///
/// Delivered as a LAUNCH ARGUMENT rather than a stored default, so it survives
/// Maestro's `clearState` the same way `-BBSkipSplash` and
/// `-hasCompletedOnboarding` do.
///
/// Permanent scaffolding per `.desk/project.md` (`scaffolding: keep`): it lets
/// every later growth feature be verified in the real app instead of only in
/// unit tests.
enum SeedScenario: String {
    /// Gain below reference, feeds and nappies below theirs — the breakdown case.
    case lowGain
    /// Everything within reference — the calm case the parent usually sees.
    case healthy
    /// Gain below reference, nothing else logged — proves "not enough data"
    /// renders instead of zero.
    case sparseLogs

    #if targetEnvironment(simulator)
    /// Wipes existing data and seeds the requested scenario. No-op without the
    /// launch argument.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard let raw = UserDefaults.standard.string(forKey: "BBSeedScenario"),
              let scenario = SeedScenario(rawValue: raw) else { return }
        wipe(context)
        scenario.seed(into: context)
        try? context.save()
    }

    private static func wipe(_ context: ModelContext) {
        for baby in (try? context.fetch(FetchDescriptor<Baby>())) ?? [] { context.delete(baby) }
        for e in (try? context.fetch(FetchDescriptor<FeedingEntry>())) ?? [] { context.delete(e) }
        for e in (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? [] { context.delete(e) }
        for e in (try? context.fetch(FetchDescriptor<DiaperEntry>())) ?? [] { context.delete(e) }
        for e in (try? context.fetch(FetchDescriptor<GrowthEntry>())) ?? [] { context.delete(e) }
        for e in (try? context.fetch(FetchDescriptor<CustomEvent>())) ?? [] { context.delete(e) }
    }

    private func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ n: Int) -> Date { calendar.date(byAdding: .day, value: -n, to: now)! }

        // 40 days old: inside the 0-6 month range, past the newborn red-flag window.
        let baby = Baby(name: "Mia", birthDate: daysAgo(40), gender: .female, feedingType: .breast)
        baby.birthWeightKg = 3.4
        context.insert(baby)

        let windowDays = 9
        // 17 g/day is below the reference for this age; 32 g/day is inside it.
        let gramsPerDay: Double = (self == .healthy) ? 32 : 17
        let startKg = 4.0
        for (offset, kg) in [(windowDays, startKg),
                             (0, startKg + gramsPerDay * Double(windowDays) / 1000)] {
            let entry = GrowthEntry(date: daysAgo(offset), weightKg: kg,
                                    heightCm: 55, headCircumferenceCm: nil)
            entry.baby = baby
            context.insert(entry)
        }

        guard self != .sparseLogs else { return }

        let feedsPerDay = (self == .healthy) ? 9 : 5
        let nappiesPerDay = (self == .healthy) ? 7 : 4
        for day in 0...windowDays {
            for _ in 0..<feedsPerDay {
                let feed = FeedingEntry(startTime: daysAgo(day), type: .breast, side: .left, volumeML: nil)
                feed.endTime = daysAgo(day)
                feed.baby = baby
                context.insert(feed)
            }
            for _ in 0..<nappiesPerDay {
                let nappy = DiaperEntry(time: daysAgo(day), type: .wet)
                nappy.baby = baby
                context.insert(nappy)
            }
        }
    }
    #else
    /// Release builds carry no seeding path at all.
    @MainActor
    static func seedIfRequested(in context: ModelContext) {}
    #endif
}
```

- [ ] **Step 2: Call it at launch**

In `BabyBloomApp.swift`'s `.onAppear`, before the adoption call:

```swift
                SeedScenario.seedIfRequested(in: sharedModelContainer.mainContext)
```

- [ ] **Step 3: Verify by hand, as separate shell steps**

```bash
xcodegen generate && grep -c "SeedScenario.swift" BabyBloom.xcodeproj/project.pbxproj
# build, then:
xcrun simctl install booted .superpowers/build/Build/Products/Debug-iphonesimulator/BabyBloom.app
```

Then, as its OWN command:

```bash
xcrun simctl terminate booted com.nenita.app
xcrun simctl launch booted com.nenita.app -BBSkipSplash true -hasCompletedOnboarding true -appLanguage en -BBSeedScenario lowGain
```

Navigate to More → Growth and confirm the Nutrition section and the breakdown (or its locked placeholder) are on screen. Screenshot with `xcrun simctl io booted screenshot`.

- [ ] **Step 4: Record the hook where the next session will find it**

Add `-BBSeedScenario` to the launch-argument table in
`.claude/skills/platform-run/SKILL.md`, and to the entry-states section of
`.desk/app-map.md` with the three scenario names and what each produces.

- [ ] **Step 5: Commit**

```bash
git add BabyBloom/Core/Models/SeedScenario.swift BabyBloom/App/BabyBloomApp.swift \
        .desk/app-map.md .claude/skills/platform-run/SKILL.md
git commit -m "feat: simulator-only seeded scenarios for growth verification"
```

---

### Task 9: Authored e2e flows

**Files:**
- Create: `.desk/tests/AC1-nutrition-calm.yaml`, `.desk/tests/AC2-nutrition-breakdown.yaml`, `.desk/tests/AC3-nutrition-sparse.yaml`

**Interfaces:**
- Consumes: the seed hook from Task 8, the `tab_more` id, the app map's Growth path.
- Produces: three flows in the project's regression home.

- [ ] **Step 1: Read the app map before composing**

`.desk/app-map.md` carries the route (More tab → `nav.growth`) and the tap recipe for the tab bar (`childOf: {text: "Tab Bar"}`). Compose the whole flow from it; do not rediscover the navigation by trial.

- [ ] **Step 2: Write the breakdown flow**

```yaml
# The case the feature exists for: gain below reference, and the breakdown
# explaining it with the same window's feeds and nappies.
appId: com.nenita.app
tags: [regression]
---
- launchApp:
    clearState: true
    stopApp: true
    arguments:
      "-BBSkipSplash": "true"
      "-hasCompletedOnboarding": "true"
      "-appLanguage": "en"
      "-appAppearance": "light"
      "-BBSeedScenario": "lowGain"
- extendedWaitUntil:
    visible:
      id: "tab_home"
    timeout: 15000
- tapOn:
    text: "More"
    childOf:
      text: "Tab Bar"
- extendedWaitUntil:
    visible:
      id: "tab_more"
    timeout: 10000
- tapOn: "Growth"
- extendedWaitUntil:
    visible: "Nutrition"
    timeout: 10000
- scrollUntilVisible:
    element:
      text: "Gain is below the reference"
    direction: DOWN
- assertVisible: ".*below the reference.*"
```

- [ ] **Step 3: Write the calm flow**

Same as Step 2 up to the Growth screen, with `"-BBSeedScenario": "healthy"`, then:

```yaml
- extendedWaitUntil:
    visible: "Nutrition"
    timeout: 10000
- assertVisible: ".*within the reference.*"
- assertNotVisible: "Gain is below the reference"
```

- [ ] **Step 4: Write the sparse-logs flow**

Same as Step 2 with `"-BBSeedScenario": "sparseLogs"`, then:

```yaml
- extendedWaitUntil:
    visible: "Nutrition"
    timeout: 10000
- assertVisible: "not enough data"
- assertNotVisible: "0 a day"
```

That last assertion is the point of the scenario: an unlogged signal must never render as zero.

- [ ] **Step 5: Run each flow twice**

```bash
export JAVA_HOME="$HOME/.local/opt/jdk-21.0.12.1+1-jre/Contents/Home"
export PATH="$HOME/.maestro/bin:$JAVA_HOME/bin:$PATH"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true
maestro test .desk/tests/AC2-nutrition-breakdown.yaml
```

Authored means green TWICE in a row. The XCUITest driver is a known flake on this machine (`.desk/knowledge.md`) and gets one retry before a red run counts.

- [ ] **Step 6: Run the whole suite once**

```bash
maestro test .desk/tests/
```

Expected: every flow green, including the pre-existing `SMOKE-main-tabs`.

- [ ] **Step 7: Commit**

```bash
git add .desk/tests
git commit -m "test: e2e flows over the seeded nutrition scenarios"
```

---

## Done when

- All nine tasks are committed.
- `xcodebuild ... test` is green, with roughly 23 new unit tests plus the render dump.
- All four Maestro flows are twice-green.
- The 18 render-dump PNGs have been read and none breaks a medical constraint.
- The card's `verify:` block in `.desk/tasks/feeding-weight-link/brief.md` carries the evidence, and the PR quotes it.

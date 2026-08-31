# Widget Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the two home-screen widgets answer "how long until the next feed" at a glance, in the app's real palette, in both themes, filling their own container.

**Architecture:** The feeding-interval arithmetic moves out of `NotificationManager` into a pure `FeedingRhythm` type under `Core/`, which the widget target compiles alongside `Core/Models`. The timeline entry carries the *date* of the next feed rather than a formatted string, so WidgetKit renders a live countdown; a second timeline entry at that date flips the widget to its "due" wording without polling. The widget gets its own small colour catalog, guarded against drift by the same pre-build script that already guards the localization JSONs.

**Tech Stack:** Swift 6.0, SwiftUI, WidgetKit, SwiftData (read-only in the extension), XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-31-widget-redesign-design.md`

## Global Constraints

- Swift 6.0, iOS 17.0 deployment target, strict concurrency. A `static let` of a non-Sendable type does not compile; use a computed static.
- ALL user-facing strings go through the JSON `LocalizationManager` and the `.l` extension. `NSLocalizedString` is never used. Every new key must be added to all three of `BabyBloom/Resources/Localization/{en,ru,es}.json` AND copied to `WidgetResources/Localization/{en,ru,es}.json`, or the pre-build script fails the build.
- No colour is hardcoded in a view. Colours resolve through colorsets.
- Comment density ~1 per 6–10 lines, explaining *why*, never narrating the code.
- Every Dynamic Type scale goes through `BBTheme.Typography`; a bare `UIFontMetrics.scaledValue(for:)` is a defect. The widget is the documented exception: it uses explicit sizes with `minimumScaleFactor`, because widget canvases are fixed and small.
- The project is generated: after any `project.yml` edit run `xcodegen generate` and verify the generated project actually changed — XcodeGen ignores unknown keys silently.
- Written artifacts in English.
- Build: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build build`
- Test: same invocation with `test` instead of `build`.

---

### Task 1: Extract `FeedingRhythm` out of `NotificationManager`

The widget cannot import a `UNUserNotificationCenter`-bound service. The arithmetic becomes a pure type the widget target can compile, and `NotificationManager` delegates to it so notification behaviour is provably unchanged.

**Files:**
- Create: `BabyBloom/Core/Feeding/FeedingRhythm.swift`
- Modify: `BabyBloom/Services/NotificationManager.swift:465-482`
- Modify: `project.yml` (add `BabyBloom/Core/Feeding` to the widget target's sources)
- Test: `BabyBloomTests/FeedingRhythmTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `enum FeedingRhythm` with three static methods —
  `interval(ageMonths: Int) -> TimeInterval?`,
  `interval(ageMonths: Int, recentFeedings: [Date]) -> TimeInterval?`,
  `nextFeed(afterLastFeedingAt last: Date?, ageMonths: Int, recentFeedings: [Date]) -> Date?`.
  Task 4 calls `nextFeed`.

- [ ] **Step 1: Write the failing tests**

Create `BabyBloomTests/FeedingRhythmTests.swift`:

```swift
import XCTest
@testable import BabyBloom

/// The interval table is the same one the feeding reminder is scheduled on.
/// These pin it so the widget and the notification can never drift apart —
/// which is the whole reason the arithmetic was pulled out of
/// `NotificationManager` in the first place.
final class FeedingRhythmTests: XCTestCase {

    // MARK: - The age table

    func testAgeTableAtEveryBoundary() {
        let expected: [(months: Int, hours: Double?)] = [
            (0, 2.5), (1, 3.0), (2, 3.0), (3, 3.5), (5, 3.5),
            (6, 4.0), (8, 4.0), (9, 4.5), (11, 4.5),
        ]
        for row in expected {
            XCTAssertEqual(FeedingRhythm.interval(ageMonths: row.months),
                           row.hours.map { $0 * 3600 },
                           "age \(row.months) months")
        }
    }

    /// Not an edge case — a product decision. From a year old the app stops
    /// telling parents when to feed, and anything derived from this must stay
    /// silent too rather than invent a due time.
    func testTwelveMonthsAndOlderHasNoInterval() {
        XCTAssertNil(FeedingRhythm.interval(ageMonths: 12))
        XCTAssertNil(FeedingRhythm.interval(ageMonths: 24))
    }

    // MARK: - The adaptive interval

    func testThreeOrMoreFeedingsUseTheLoggedRhythmPlusGrace() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Three feedings, two 2-hour gaps.
        let times = [base, base.addingTimeInterval(7200), base.addingTimeInterval(14400)]
        // 120 minutes averaged + a 10-minute grace.
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       130 * 60)
    }

    func testFewerThanThreeFeedingsFallBackToTheAgeTable() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = [base, base.addingTimeInterval(7200)]
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       3.0 * 3600)
    }

    /// A gap longer than eight hours is a night, not a rhythm. Letting it into
    /// the average would push the next feed hours out and silence the widget
    /// for the whole morning.
    func testGapsOverEightHoursAreIgnored() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = [base,
                     base.addingTimeInterval(7200),        // +2h
                     base.addingTimeInterval(7200 + 36000)] // +10h — a night
        XCTAssertEqual(FeedingRhythm.interval(ageMonths: 1, recentFeedings: times),
                       130 * 60)
    }

    // MARK: - The date the widget renders

    func testNextFeedIsTheLastFeedingPlusTheInterval() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(FeedingRhythm.nextFeed(afterLastFeedingAt: last,
                                              ageMonths: 1,
                                              recentFeedings: []),
                       last.addingTimeInterval(3.0 * 3600))
    }

    /// Two distinct reasons to predict nothing, and the widget renders a
    /// different thing for each — so both must be reachable.
    func testNoPredictionWithoutAFeeding() {
        XCTAssertNil(FeedingRhythm.nextFeed(afterLastFeedingAt: nil,
                                            ageMonths: 1,
                                            recentFeedings: []))
    }

    func testNoPredictionFromTwelveMonths() {
        let last = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNil(FeedingRhythm.nextFeed(afterLastFeedingAt: last,
                                            ageMonths: 12,
                                            recentFeedings: []))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```
xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .superpowers/build \
  -only-testing:BabyBloomTests/FeedingRhythmTests test
```
Expected: BUILD FAILED, "cannot find 'FeedingRhythm' in scope".

- [ ] **Step 3: Write the implementation**

Create `BabyBloom/Core/Feeding/FeedingRhythm.swift`:

```swift
import Foundation

/// When the next feed is due — the one calculation the feeding reminder and
/// the widget must agree on.
///
/// Pure by design, like `Core/Growth` beside it: no SwiftData, no model
/// context, no UserNotifications. That is what lets the widget extension
/// compile it; it previously lived on `NotificationManager`, which the widget
/// target cannot import.
enum FeedingRhythm {

    /// A gap longer than this is a night's sleep rather than a feeding rhythm.
    private static let maxCredibleGapMinutes: Double = 480
    /// Added to a learned rhythm so the reminder lands just after the parent's
    /// own usual moment rather than exactly on it.
    private static let graceMinutes: Double = 10
    private static let fallbackAverageMinutes: Double = 120
    /// Only the last few feedings describe today's rhythm.
    private static let rhythmWindow = 7

    /// `nil` means reminders are off for this age group — from a year old the
    /// app deliberately stops telling parents when to feed.
    static func interval(ageMonths: Int) -> TimeInterval? {
        switch ageMonths {
        case 0:      return 2.5 * 3600   // 0–4 weeks: every ~2–3 h
        case 1...2:  return 3.0 * 3600
        case 3...5:  return 3.5 * 3600
        case 6...8:  return 4.0 * 3600
        case 9...11: return 4.5 * 3600
        default:     return nil          // 12+ months: parent-managed
        }
    }

    /// The age table until the parent has logged enough to describe their own
    /// rhythm, then their rhythm.
    static func interval(ageMonths: Int, recentFeedings: [Date]) -> TimeInterval? {
        guard interval(ageMonths: ageMonths) != nil else { return nil }
        guard recentFeedings.count >= 3 else { return interval(ageMonths: ageMonths) }
        return (averageGapMinutes(recentFeedings) + graceMinutes) * 60
    }

    /// The moment the widget counts down to. `nil` for two different reasons —
    /// nothing logged yet, and the 12+ month case above — and the widget shows
    /// something different for each.
    static func nextFeed(afterLastFeedingAt last: Date?,
                         ageMonths: Int,
                         recentFeedings: [Date]) -> Date? {
        guard let last,
              let interval = interval(ageMonths: ageMonths, recentFeedings: recentFeedings)
        else { return nil }
        return last.addingTimeInterval(interval)
    }

    static func averageGapMinutes(_ times: [Date]) -> Double {
        guard times.count >= 2 else { return fallbackAverageMinutes }
        let recent = times.sorted().suffix(rhythmWindow)
        let gaps = zip(recent, recent.dropFirst()).map {
            $1.timeIntervalSince($0) / 60
        }.filter { $0 > 0 && $0 < maxCredibleGapMinutes }
        guard !gaps.isEmpty else { return fallbackAverageMinutes }
        return gaps.reduce(0, +) / Double(gaps.count)
    }
}
```

- [ ] **Step 4: Point `NotificationManager` at it**

In `BabyBloom/Services/NotificationManager.swift`, replace the bodies of the three methods at lines 465–482 (keep the signatures — callers and existing tests use them):

```swift
    func feedingReminderInterval(ageMonths: Int, recentFeedingTimes: [Date]) -> TimeInterval? {
        FeedingRhythm.interval(ageMonths: ageMonths, recentFeedings: recentFeedingTimes)
    }

    /// Returns nil when reminders should be disabled for this age group.
    func feedingInterval(ageMonths: Int) -> TimeInterval? {
        FeedingRhythm.interval(ageMonths: ageMonths)
    }

    func calculateAverageIntervalMinutes(times: [Date]) -> Double {
        FeedingRhythm.averageGapMinutes(times)
    }
```

- [ ] **Step 5: Add the folder to the widget target**

In `project.yml`, inside the `BabyBloomWidget` target's `sources`, after the `BabyBloom/Core/Localization` entry:

```yaml
      # The next-feed arithmetic the widget counts down to. Pure, and shared
      # with the app so the widget and the feeding reminder cannot disagree.
      - path: BabyBloom/Core/Feeding
        excludes:
          - "**/.DS_Store"
```

Then run `xcodegen generate` and confirm the widget target gained the file:
```
grep -c "FeedingRhythm.swift" BabyBloom.xcodeproj/project.pbxproj
```
Expected: a count of 4 or more (one file reference plus a build-file entry per target that compiles it). A count of 0 means XcodeGen ignored the key — do not proceed.

- [ ] **Step 6: Run the full suite**

Run the full test invocation from Global Constraints.
Expected: `** TEST SUCCEEDED **`, 174 + 8 = 182 tests, 0 failures. `NotificationManagerTests` must pass **unchanged** — that is the evidence the extraction altered no notification behaviour.

- [ ] **Step 7: Commit**

```bash
git add BabyBloom/Core/Feeding/FeedingRhythm.swift \
        BabyBloom/Services/NotificationManager.swift \
        BabyBloomTests/FeedingRhythmTests.swift \
        project.yml BabyBloom.xcodeproj/project.pbxproj
git commit -m "refactor: extract FeedingRhythm so the widget can share the reminder's arithmetic"
```

---

### Task 2: Give the widget the brand palette, guarded against drift

The widget target bundles no Asset Catalog, which is why its gradient is two hex literals with no dark variant — and the literals match README's stale documentation rather than the shipped colorsets.

**Files:**
- Create: `WidgetResources/Colors.xcassets/Contents.json`
- Create: `WidgetResources/Colors.xcassets/{BBGradientStart,BBGradientEnd,BBAccent}.colorset/Contents.json`
- Modify: `project.yml` (widget target `sources`, and the pre-build script)
- Modify: `BabyBloomWidget/BabyBloomWidget.swift` (delete the `Color(hex:)` extension once nothing uses it — Task 3 removes the last use)

**Interfaces:**
- Consumes: nothing.
- Produces: the colorset names `BBGradientStart`, `BBGradientEnd`, `BBAccent` resolvable from the widget extension via `Color("BBGradientStart")`. Task 3 uses them.

- [ ] **Step 1: Copy the three colorsets**

```bash
mkdir -p WidgetResources/Colors.xcassets
cat > WidgetResources/Colors.xcassets/Contents.json <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
for c in BBGradientStart BBGradientEnd BBAccent; do
  mkdir -p "WidgetResources/Colors.xcassets/$c.colorset"
  cp "BabyBloom/Resources/Assets.xcassets/Colors/$c.colorset/Contents.json" \
     "WidgetResources/Colors.xcassets/$c.colorset/Contents.json"
done
```

- [ ] **Step 2: Declare the catalog on the widget target**

In `project.yml`, in the `BabyBloomWidget` target's `sources`, after the `WidgetResources/Localization` entry:

```yaml
      # Widget-side copy of the brand colorsets, kept in step with the app's
      # catalog by the pre-build script. It CANNOT simply reference
      # BabyBloom/Resources/Assets.xcassets: that path is inside the tree the
      # app target already scans, and XcodeGen then dedupes the file
      # references and ships an .appex with no Resources build phase at all —
      # the same trap the localization JSONs are laid out to avoid.
      - path: WidgetResources/Colors.xcassets
        buildPhase: resources
```

- [ ] **Step 3: Extend the pre-build guard**

In `project.yml`, in the app target's `preBuildScripts`, append to the existing script body, after the localization loop:

```bash
          # Same rule for the widget's copy of the brand colorsets.
          for c in BBGradientStart BBGradientEnd BBAccent; do
            app="BabyBloom/Resources/Assets.xcassets/Colors/$c.colorset/Contents.json"
            widget="WidgetResources/Colors.xcassets/$c.colorset/Contents.json"
            if ! cmp -s "$app" "$widget"; then
              echo "error: $widget is out of sync with $app. Run: cp \"$app\" \"$widget\""
              exit 1
            fi
          done
```

- [ ] **Step 4: Regenerate and verify the key took**

```bash
xcodegen generate
grep -c "Colors.xcassets" BabyBloom.xcodeproj/project.pbxproj
```
Expected: 1 or more. A count of 0 means XcodeGen ignored the entry — stop and fix `project.yml` rather than proceeding.

- [ ] **Step 5: Prove the guard actually fires**

```bash
printf '\n' >> WidgetResources/Colors.xcassets/BBAccent.colorset/Contents.json
xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .superpowers/build build 2>&1 | grep "is out of sync"
```
Expected: the error line naming `BBAccent.colorset`. A guard that never fires is not a guard — this step is why it is in the plan.

Then restore it:
```bash
cp BabyBloom/Resources/Assets.xcassets/Colors/BBAccent.colorset/Contents.json \
   WidgetResources/Colors.xcassets/BBAccent.colorset/Contents.json
```

- [ ] **Step 6: Build clean and commit**

Run the build from Global Constraints. Expected: `** BUILD SUCCEEDED **`.

```bash
git add WidgetResources/Colors.xcassets project.yml BabyBloom.xcodeproj/project.pbxproj
git commit -m "build: bundle the brand colorsets with the widget, guarded against drift"
```

---

### Task 3: Fix the container, adopt the palette, correct the documented palette

This is the task that removes the black frame from the owner's screenshot.

**Files:**
- Modify: `BabyBloomWidget/BabyBloomWidget.swift:113-155` (container background) and its `Color(hex:)` extension (delete)
- Modify: `BabyBloom/Features/Widget/WidgetViews.swift` (remove the inner `.background`, use colorsets)
- Modify: `README.md` (design-system table), `BabyBloom/DesignSystem/BBTheme.swift:4` (header comment), `CLAUDE.md` (theming section)
- Modify: `ARCHITECTURE.md`, `DECISIONS.md`

**Interfaces:**
- Consumes: the colorset names from Task 2.
- Produces: `WidgetBackground`, a `View` used by both widget configurations as their container background. Task 6's render dump does not use it (the dump renders views, not containers).

- [ ] **Step 1: Add the shared background**

In `BabyBloom/Features/Widget/WidgetViews.swift`, above `BabyBloomSmallWidgetView`:

```swift
/// The brand gradient, as the widget's CONTAINER background rather than a
/// background on the content.
///
/// It used to be `.background(...)` on the inner stack while the container
/// kept `.fill.tertiary`. The content sits inside the system's margins, so the
/// gradient rendered as a square-cornered rectangle with the container's own
/// near-black fill showing around it as a frame — the whole reason this
/// redesign started. Nothing in-process catches that: a view rendered outside
/// a widget container has neither margins nor a container background.
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color("BBGradientStart"), Color("BBGradientEnd")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
```

- [ ] **Step 2: Move it to the container**

In `BabyBloomWidget/BabyBloomWidget.swift`, in **both** widget configurations, replace `.containerBackground(.fill.tertiary, for: .widget)` with:

```swift
                    .containerBackground(for: .widget) { WidgetBackground() }
```

The iOS-17 availability check around it can go: the deployment target is 17.0, so the `else` branch was already dead.

- [ ] **Step 3: Remove the inner background and the hex extension**

In `WidgetViews.swift`, delete the `.background(LinearGradient(colors: [Color(hex: "#6B5EA8"), Color(hex: "#B08ED8")], ...))` modifier from the medium view. In `BabyBloomWidget.swift`, delete the whole `extension Color { init(hex:) }` block — Task 2's catalog replaces its only purpose.

- [ ] **Step 4: Build and check nothing else used `Color(hex:)`**

```bash
grep -rn "Color(hex:" --include=*.swift BabyBloomWidget/ BabyBloom/Features/Widget/
```
Expected: no output. Then run the build from Global Constraints; expected `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Correct the documented palette**

The catalog is the source of truth and three documents disagree with it.

In `README.md`, the design-system table becomes:

```markdown
| Элемент | Цвет |
|---------|------|
| Основной | Лавандово-фиолетовый `#6F5BA8` |
| Акцентный | Персиковый `#E8B49B` |
| Фоновый | Молочно-белый `#F7F3FF` |
| Успех | Мятный зелёный `#A8D5C2` |
```

In `BabyBloom/DesignSystem/BBTheme.swift` line 4, replace `// Soft botanical iOS — sage/mint palette, soft shadows, rounded cards.` with:

```swift
// Soft lavender iOS — lavender/peach palette, soft shadows, rounded cards.
```

In `CLAUDE.md`, replace the `sage/mint` phrase in the Theming section with `lavender/peach`.

Verify the hex values against the catalog before writing them:
```bash
python3 -c "
import json
for c in ['BBPrimary','BBAccent']:
    d=json.load(open(f'BabyBloom/Resources/Assets.xcassets/Colors/{c}.colorset/Contents.json'))
    for col in d['colors']:
        comp=col['color']['components']
        print(c, 'dark' if col.get('appearances') else 'light',
              '#%02X%02X%02X' % tuple(round(float(comp[k])*255) for k in ('red','green','blue')))
"
```

- [ ] **Step 6: Record the arrangement in the knowledge base**

Per the upkeep rule in `CLAUDE.md`, add to `ARCHITECTURE.md`, in the "Theming and typography" section:

```markdown
The widget extension bundles its own small catalog, `WidgetResources/Colors.xcassets`,
holding the brand colorsets it uses. It cannot share the app's catalog: that
path sits inside the tree the app target already scans, and XcodeGen then
dedupes the file references and ships an `.appex` with no Resources build
phase — the same trap the localization JSONs are laid out to avoid. The
pre-build script `cmp`s both copies and fails the build on drift.
```

And to `DECISIONS.md`, newest on top:

```markdown
## 2026-09-01 — The widget gets a second, guarded colour catalog

`WidgetResources/Colors.xcassets` duplicates the brand colorsets, and the
pre-build script fails the build when it drifts from the app's catalog.

**Why.** The widget extension bundled no catalog at all, so its gradient was
two hex literals with no dark variant — and the literals had been copied from
README's documented palette, which was itself wrong, rather than from the
shipped colorsets. Sharing the app's catalog is not available: its path is
inside the tree the app target scans, which is exactly the arrangement that
once made XcodeGen dedupe the references and ship an `.appex` with no
Resources build phase. A shared Swift constants file was rejected for putting
the palette back into source, against the 2026-07-21 decision.

**Consequence.** Re-theming stays a colorset edit, but it is now two colorset
edits plus the copy the error message spells out.
```

- [ ] **Step 7: Commit**

```bash
git add BabyBloomWidget/BabyBloomWidget.swift BabyBloom/Features/Widget/WidgetViews.swift \
        README.md CLAUDE.md BabyBloom/DesignSystem/BBTheme.swift \
        ARCHITECTURE.md DECISIONS.md
git commit -m "fix: let the widget fill its own container, in the real brand palette"
```

---

### Task 4: Count down to the next feed

**Files:**
- Modify: `BabyBloom/Features/Widget/WidgetViews.swift` (the entry type and both views)
- Modify: `BabyBloomWidget/BabyBloomWidget.swift` (`fetchEntry`, `getTimeline`)
- Modify: `BabyBloom/Resources/Localization/{en,ru,es}.json` and the three `WidgetResources/Localization/` copies
- Test: `BabyBloomTests/FeedingRhythmTests.swift` already covers the arithmetic; the rendering is covered in Task 6.

**Interfaces:**
- Consumes: `FeedingRhythm.nextFeed(afterLastFeedingAt:ageMonths:recentFeedings:)` from Task 1; `WidgetBackground` from Task 3.
- Produces: `BabyBloomEntry` gains `nextFeedingTime: Date?` and `ageMonths: Int`; `todayFeedingCount`, `lastFeedingTime`, `lastSleepDuration`, `isAsleep`, `babyName` are unchanged. Task 6's dump constructs this type directly.

- [ ] **Step 1: Add the localization keys**

Add to `BabyBloom/Resources/Localization/en.json`:

```json
  "widget.feeding_in": "Feeding in",
  "widget.time_to_feed": "Time to feed",
  "widget.last_feed": "Last feed",
  "widget.log_first_feeding": "Log the first feeding",
  "widget.sleeping": "Sleeping",
  "widget.today_short": "%d today"
```

`ru.json`:

```json
  "widget.feeding_in": "Кормление через",
  "widget.time_to_feed": "Пора кормить",
  "widget.last_feed": "Последнее кормление",
  "widget.log_first_feeding": "Запишите первое кормление",
  "widget.sleeping": "Спит",
  "widget.today_short": "%d сегодня"
```

`es.json`:

```json
  "widget.feeding_in": "Toma en",
  "widget.time_to_feed": "Hora de comer",
  "widget.last_feed": "Última toma",
  "widget.log_first_feeding": "Registra la primera toma",
  "widget.sleeping": "Durmiendo",
  "widget.today_short": "%d hoy"
```

Then sync the widget copies — the build fails otherwise:
```bash
for f in en ru es; do
  cp "BabyBloom/Resources/Localization/$f.json" "WidgetResources/Localization/$f.json"
done
```

- [ ] **Step 2: Widen the entry**

In `WidgetViews.swift`:

```swift
struct BabyBloomEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let lastFeedingTime: Date?
    let lastSleepDuration: String?
    let todayFeedingCount: Int
    let isAsleep: Bool
    /// When the next feed is due. `nil` for two different reasons, and the
    /// views render a different thing for each: nothing logged yet (the
    /// invitation), and 12+ months, where the app deliberately does not
    /// predict (elapsed time instead).
    let nextFeedingTime: Date?
    let ageMonths: Int

    var hasLoggedAFeeding: Bool { lastFeedingTime != nil }
}
```

- [ ] **Step 3: Fill it in the provider**

In `BabyBloomWidget.swift`'s `fetchEntry()`, after `let todayCount = ...`, add:

```swift
        // The same arithmetic the feeding reminder is scheduled on, so the
        // widget and the push cannot contradict each other.
        let recent = Array(feedings.prefix(7).map(\.startTime))
        let nextFeed = FeedingRhythm.nextFeed(afterLastFeedingAt: feedings.first?.startTime,
                                              ageMonths: baby.ageInMonths,
                                              recentFeedings: recent)
```

and pass `nextFeedingTime: nextFeed, ageMonths: baby.ageInMonths` into the returned `BabyBloomEntry`. Update `placeholderEntry()` with the same two fields (`nil` and `1`).

- [ ] **Step 4: Flip to "time to feed" without polling**

Replace the body of `getTimeline` in `BabyBloomWidget.swift`:

```swift
    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyBloomEntry>) -> Void) {
        // Before anything is read: this process outlives a language change.
        LocalizationManager.shared.refreshFromStore()
        let entry = Self.fetchEntry()
        // Roughly every 15 minutes to keep the underlying data fresh. The
        // countdown itself does NOT depend on this — `Text(_:style:)` is
        // re-rendered by the system every minute — but the wording has to
        // change the moment the feed falls due, so a second entry is placed
        // exactly there rather than polling for it.
        let refresh = Date().addingTimeInterval(15 * 60)
        var entries = [entry]
        if let due = entry.nextFeedingTime, due > entry.date, due < refresh {
            entries.append(BabyBloomEntry(date: due,
                                          babyName: entry.babyName,
                                          lastFeedingTime: entry.lastFeedingTime,
                                          lastSleepDuration: entry.lastSleepDuration,
                                          todayFeedingCount: entry.todayFeedingCount,
                                          isAsleep: entry.isAsleep,
                                          nextFeedingTime: entry.nextFeedingTime,
                                          ageMonths: entry.ageMonths))
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
```

- [ ] **Step 5: Rewrite the small view**

Replace `BabyBloomSmallWidgetView`'s body in `WidgetViews.swift`:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.hasLoggedAFeeding {
                Text(headline)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                hero
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(isDue ? Color("BBAccent") : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Label(String(format: "widget.today_short".l, entry.todayFeedingCount),
                          systemImage: "heart.fill")
                    if entry.isAsleep {
                        Image(systemName: "moon.fill")
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            } else {
                // The first day is not an error state. The name is what tells
                // the parent this widget is theirs and working.
                Text(entry.babyName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("widget.log_first_feeding".l)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
```

and add these to the same struct — they are shared with the medium view, so put them in a `WidgetCopy` enum at file scope instead of duplicating:

```swift
/// Wording shared by both sizes, so the two cannot describe the same state
/// differently.
enum WidgetCopy {
    static func headline(for entry: BabyBloomEntry) -> String {
        guard entry.nextFeedingTime != nil else { return "widget.last_feed".l }
        return "widget.feeding_in".l
    }

    /// True once the due moment has passed. The timeline places an entry
    /// exactly at that moment, so this flips without polling.
    static func isDue(_ entry: BabyBloomEntry) -> Bool {
        guard let next = entry.nextFeedingTime else { return false }
        return next <= entry.date
    }

    /// The countdown is rendered from a DATE, never a formatted string: the
    /// system re-renders `Text(_:style:)` every minute, so it stays right
    /// between the 15-minute timeline reloads.
    @ViewBuilder
    static func hero(for entry: BabyBloomEntry) -> some View {
        if let next = entry.nextFeedingTime, next > entry.date {
            Text(next, style: .relative)
        } else if entry.nextFeedingTime != nil {
            Text("widget.time_to_feed".l)
        } else if let last = entry.lastFeedingTime {
            // 12+ months: the app does not predict here, so neither do we.
            Text(last, style: .relative)
        } else {
            Text("—")
        }
    }
}
```

In the view, `headline` is `WidgetCopy.headline(for: entry)`, `hero` is `WidgetCopy.hero(for: entry)`, `isDue` is `WidgetCopy.isDue(entry)`.

- [ ] **Step 6: Rewrite the medium view**

Replace `BabyBloomMediumWidgetView`'s body:

```swift
    var body: some View {
        Group {
            if entry.hasLoggedAFeeding {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WidgetCopy.headline(for: entry))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        WidgetCopy.hero(for: entry)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetCopy.isDue(entry) ? Color("BBAccent") : .white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 0)
                        Text(entry.babyName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 14) {
                        statRow(icon: "heart.fill", title: "widget.last_feed".l,
                                value: entry.lastFeedingTime.map { relative($0) } ?? "—")
                        statRow(icon: "moon.fill",
                                title: entry.isAsleep ? "widget.sleeping".l : "tab.sleep".l,
                                value: entry.lastSleepDuration ?? "—")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // No split at all here: an invitation reads as one sentence,
                // and a half-empty two-column grid reads as a fault.
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.babyName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("widget.log_first_feeding".l)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
```

Keep the existing `widgetStatRow` helper, renamed `statRow`, and delete the `Rectangle()` divider.

- [ ] **Step 7: Build, then commit**

Run the build. Expected `** BUILD SUCCEEDED **`.

```bash
git add BabyBloom/Features/Widget/WidgetViews.swift BabyBloomWidget/BabyBloomWidget.swift \
        BabyBloom/Resources/Localization WidgetResources/Localization
git commit -m "feat: count down to the next feed on both widgets"
```

---

### Task 5: Refresh the widget when the app changes the data

**Files:**
- Create: `BabyBloom/Core/Feeding/WidgetRefresh.swift`
- Modify: `BabyBloom/Features/Feeding/FeedingView.swift:195,215,227,520`
- Modify: `BabyBloom/Features/Sleep/SleepView.swift:190,210,222,377`

**Interfaces:**
- Consumes: nothing.
- Produces: `WidgetRefresh.entriesChanged()`.

- [ ] **Step 1: Add the helper**

```swift
import WidgetKit

/// Ask the widget for a new timeline after the app changes what it shows.
///
/// Without this, an entry logged in the app reaches the widget only on its own
/// ~15-minute cadence, so a parent who has just logged a feed sees the old
/// countdown — the one case where the staleness is obvious and looks broken.
/// A named call site is deliberate: the next person adding an entry type gets
/// a symbol to grep for.
enum WidgetRefresh {
    static func entriesChanged() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

- [ ] **Step 2: Call it at all eight sites**

Add `WidgetRefresh.entriesChanged()` immediately after the save/delete at each of the eight lines listed under **Files**, and `import WidgetKit` is not needed in those views — the helper owns it.

- [ ] **Step 3: Verify no site was missed**

```bash
grep -c "WidgetRefresh.entriesChanged()" BabyBloom/Features/Feeding/FeedingView.swift
grep -c "WidgetRefresh.entriesChanged()" BabyBloom/Features/Sleep/SleepView.swift
```
Expected: `4` and `4`.

- [ ] **Step 4: Build and commit**

```bash
git add BabyBloom/Core/Feeding/WidgetRefresh.swift \
        BabyBloom/Features/Feeding/FeedingView.swift BabyBloom/Features/Sleep/SleepView.swift
git commit -m "feat: refresh the widget as soon as an entry is saved or deleted"
```

---

### Task 6: Render every state, then look at the real thing

**Files:**
- Modify: `BabyBloomTests/WidgetRenderDump.swift`
- Test evidence: `.desk/tasks/widget-redesign/docs/evidence/`

**Interfaces:**
- Consumes: `BabyBloomEntry` from Task 4.
- Produces: nothing downstream.

- [ ] **Step 1: Extend the dump with the five states**

Read the file first — it already renders both widget views per locale, and the new cases follow its existing shape. Add a fixture list:

```swift
    /// Every state the redesign defines, so a truncation or an empty-looking
    /// card shows up as an image rather than as a bug report.
    private static func states(now: Date) -> [(name: String, entry: BabyBloomEntry)] {
        let hourAgo = now.addingTimeInterval(-3600)
        return [
            ("normal", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                      todayFeedingCount: 6, isAsleep: false,
                                      nextFeedingTime: now.addingTimeInterval(4320), ageMonths: 1)),
            ("due", BabyBloomEntry(date: now, babyName: "Vlad",
                                   lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                   todayFeedingCount: 6, isAsleep: false,
                                   nextFeedingTime: now.addingTimeInterval(-120), ageMonths: 1)),
            ("asleep", BabyBloomEntry(date: now, babyName: "Vlad",
                                      lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                      todayFeedingCount: 6, isAsleep: true,
                                      nextFeedingTime: now.addingTimeInterval(4320), ageMonths: 1)),
            ("empty", BabyBloomEntry(date: now, babyName: "Vlad",
                                     lastFeedingTime: nil, lastSleepDuration: nil,
                                     todayFeedingCount: 0, isAsleep: false,
                                     nextFeedingTime: nil, ageMonths: 1)),
            ("toddler", BabyBloomEntry(date: now, babyName: "Vlad",
                                       lastFeedingTime: hourAgo, lastSleepDuration: "1 ч 3 мин",
                                       todayFeedingCount: 4, isAsleep: false,
                                       nextFeedingTime: nil, ageMonths: 14)),
        ]
    }
```

Render each state × both sizes × `en`/`ru`/`es` × light/dark, following the file's existing naming so the images sort together.

- [ ] **Step 2: Run the dump and look at every image**

```
xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .superpowers/build \
  -only-testing:BabyBloomTests/WidgetRenderDump test
```

60 images. Check each for: truncation (Russian and Spanish are the long ones), the accent tint appearing only in the `due` state, the invitation filling the medium widget rather than sitting in a half-empty grid.

- [ ] **Step 3: Run the full suite**

Expected: `** TEST SUCCEEDED **`, 0 failures.

- [ ] **Step 4: Put the widgets on a real home screen**

This is the acceptance evidence for AC1 and the only check that sees a widget container.

```bash
xcrun simctl install booted .superpowers/build/Build/Products/Debug-iphonesimulator/BabyBloom.app
xcrun simctl launch booted com.nenita.app -BBSkipSplash true -hasCompletedOnboarding true \
  -appLanguage ru -BBSeedScenario healthy
```

Then add both widgets to the simulator's home screen by hand (long-press → **+** → search the app name), and shoot both themes:

```bash
xcrun simctl ui booted appearance light
xcrun simctl io booted screenshot .desk/tasks/widget-redesign/docs/evidence/home-light.png
xcrun simctl ui booted appearance dark
xcrun simctl io booted screenshot .desk/tasks/widget-redesign/docs/evidence/home-dark.png
```

Confirm: the gradient reaches the widget's rounded corners with no frame around it, in **both** themes, and the dark shot's gradient is visibly the dark colorset rather than the light one.

- [ ] **Step 5: Commit the evidence reference and finish**

```bash
git add BabyBloomTests/WidgetRenderDump.swift
git commit -m "test: render every widget state across locales and themes"
```

Then open the PR per the project's rules, with the two home-screen screenshots attached.

---

## Self-Review

**Spec coverage.** Container defect → Task 3. `FeedingRhythm` → Task 1. Small and medium layouts and all five states → Task 4 (behaviour) and Task 6 (evidence). Staleness → Task 4 step 4. Reload on save → Task 5. Palette and the rejected alternatives → Task 2 and Task 3 step 6. Documentation corrections → Task 3 step 5. Testing → Tasks 1, 6.

**One spec refinement, made here rather than silently:** the spec said the timeline reloads every 15 minutes and the countdown rides on `Text(_:style:)`. That is true for the number but not for the wording — "Feeding in" has to become "Time to feed" at the due moment. Task 4 step 4 adds a second timeline entry at exactly that date instead of polling. The spec section "Staleness, and why the countdown stays honest" should gain that sentence.

**Type consistency.** `BabyBloomEntry` gains `nextFeedingTime` and `ageMonths` in Task 4 step 2 and is constructed with both in Task 4 step 3 (`fetchEntry`, `placeholderEntry`), Task 4 step 4 (the due entry) and Task 6 step 1 (the fixtures). `WidgetCopy.headline/isDue/hero` are defined once in Task 4 step 5 and used in both views. `WidgetBackground` is defined in Task 3 step 1 and used in Task 3 step 2. `FeedingRhythm.nextFeed(afterLastFeedingAt:ageMonths:recentFeedings:)` is defined in Task 1 step 3 and called in Task 4 step 3 with that exact label.

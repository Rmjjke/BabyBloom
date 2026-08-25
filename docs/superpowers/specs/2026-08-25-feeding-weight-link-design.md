# Feeding ↔ weight link — design

Status: approved in brainstorming 2026-08-25. Awaiting owner review before an
implementation plan is written.

## The question this answers

**"Is my baby getting enough food?"** — the most common fear of a newborn's
parent, and one the app already holds all the data to address without
guessing.

The app does not answer it by measuring intake. It answers it the way a
clinician does: weight gain is the evidence, and feeding and nappy logs are
the context that makes the gain figure meaningful.

## Scope decisions (settled with the owner, 2026-08-25)

| decision | value |
|---|---|
| Signals | Weight gain **+** feeding frequency **+** wet nappies |
| Age range | 0–6 months; the feature is absent outside it |
| Surfaces | A standing summary **and** a card that appears on deviation, both on Growth |
| Premium line | Summary free; the deviation breakdown is Premium |
| Notifications | **None** in this iteration |
| Live verification | A seeded-data launch hook, making e2e possible |

## Medical safety constraints

These extend, and do not replace, the constraints already binding this project
(`docs/superpowers/plans/2026-08-09-weight-gain.md`).

- **Weight is the only trigger.** Feeding and nappy counts never raise a
  concern on their own. If gain sits within the reference band while feeds are
  few, that means the baby is getting enough — and the app says nothing. The
  app must not manufacture a problem out of secondary signs.
- **State and compare; never instruct.** "You logged 5 feeds a day, the
  reference is 8–12" is information. "Feed more often" is a medical
  instruction and is forbidden.
- **No red flag behind the paywall.** The first-weeks flags
  (`NewbornWeightLoss`) stay free and untouched. What Premium buys here is the
  breakdown, not the warning.
- **Absence of data is never zero.** A parent who does not log nappies must
  read "not enough data", never "0 a day".
- Every number carries its source in a code comment, and every surface repeats
  that these are references, not a diagnosis.

## Domain core

New file `BabyBloom/Core/Growth/FeedingAdequacy.swift` — pure functions, no
SwiftData, alongside `WeightVelocity` and `NewbornWeightLoss`.

```swift
enum FeedingAdequacy {

    /// Where one signal sits against its reference. `notEnoughData` is a
    /// first-class outcome, not a failure: it is what an honest app says when
    /// the parent has not logged enough to support a conclusion.
    enum Signal: Equatable {
        case below
        case within
        case notEnoughData
    }

    struct Assessment: Equatable {
        /// The interval the whole assessment covers — set by the two most
        /// recent weighings, so every count below is comparable.
        let windowDays: Int
        let gain: Signal
        let feedingsPerDay: Double?
        let feedingReference: ClosedRange<Double>?
        let feeding: Signal
        let wetNappiesPerDay: Double?
        let wetNappyMinimum: Double?
        let nappies: Signal
        /// True only when `gain == .below`. The single gate for the card.
        var warrantsBreakdown: Bool { gain == .below }
    }

    static func assess(
        correctedBirthDate: Date,
        isMale: Bool,
        feedingStyle: Baby.FeedingType,
        measurements: [WeightMeasurement],
        feedings: [Date],
        wetNappies: [Date],
        now: Date
    ) -> Assessment?      // nil outside 0–6 months or with < 2 weighings
}
```

The window comes from the weighings, and feeds and nappies are counted **over
that same window**. Counting them over a different period would put a "few
feeds" figure next to a gain measured across another week entirely.

### Signal 1 — weight gain

Delegates to the existing `WeightVelocity.measure(...)`, mapping its
`Band.below` to `.below`, `.within`/`.above` to `.within`, and a nil reading
to `.notEnoughData`. No new weight maths.

### Signal 2 — feeding frequency

Feeds per day over the window, against a reference chosen by corrected age
**and feeding style** — a formula-fed newborn genuinely feeds less often than
a breastfed one, and holding both to one number would flag healthy babies.

| corrected age | breast | formula / pumped |
|---|---|---|
| 0–4 weeks | 8–12 | 6–8 |
| 1–3 months | 7–9 | 5–7 |
| 4–6 months | 5–7 | 4–6 |

Source: AAP feeding guidance for breastfed and formula-fed infants. **The
exact table needs one medical review pass before implementation** — the shape
is settled, the boundaries are not yet verified line by line.

### Signal 3 — wet nappies

Entries of type `.wet` or `.both`, per day over the window.

| age | minimum per day |
|---|---|
| days 0–4 | at least the day number (day 3 → 3) |
| day 5 onwards | 6 |

Source: AAP / NHS newborn output guidance. Same review caveat as above.

**The clinical reference is used, not the user's setting.**
`@AppStorage("diaperDailyNorm")` (default 8) is an editable tracking target
that belongs to the Diapers screen. A parent who sets it to 3 must not thereby
be told their baby is fine. The two numbers stay separate and the code
comments say why.

### Not enough data

A signal is `.notEnoughData` when fewer than half the days in the window carry
any entry of that kind. Weight falls back to `.notEnoughData` whenever
`WeightVelocity` returns nil — an interval under 3 days, or an age past its
tables.

### Deliberately out of scope

No estimate of milk taken at the breast. No weight prediction. No words like
"underweight" or "failure to thrive". No advice on what to change.

## Interface

### Free — "Nutrition" section on Growth

Placed after the existing growth cards. Three rows:

```
Nutrition                         over the last 9 days
──────────────────────────────────────────────────────
♥  Weight gain            below the reference
🍼 Feeds                  9 a day · within the reference
💧 Wet nappies            7 a day · within the reference
```

Status is carried by a **word**, with colour as reinforcement only, so the row
survives greyscale and VoiceOver. When all three read `within`, the section is
calm — reassurance is most of its job.

**Boundary with `WeightGainCard`.** The free row shows the gain *status* only,
never the figures; grams per week and the reference band stay Premium, where
they already are. Feed and nappy counts do show their numbers: they are not
behind the paywall today and there is no reason to put them there.

### Premium — the breakdown card

Appears only when `warrantsBreakdown` is true and the baby is 0–6 months.
Without a subscription its place is taken by the existing `LockedInsightCard`.

> **Gain is below the reference**
> 118 g/week over 9 days. The reference for this age is 155–241 g/week.
> Feeds: 5 a day, reference 8–12.
> Wet nappies: 4 a day, reference 6 or more.
> This is an observation, not a diagnosis. Worth discussing with your
> paediatrician.

### States

| condition | what shows |
|---|---|
| No baby, or fewer than 2 weighings | A prompt to weigh again |
| Older than 6 months | Nothing — the section is absent |
| A signal without data | "not enough data" on that row |
| Gain within reference | The summary only; no card, whatever the other signals say |

Preterm babies are assessed on corrected age (`Baby.correctedBirthDate`), the
same reference `WeightVelocity` already uses.

## Seeded data hook

A launch argument `-BBSeedScenario <name>` populates a deterministic dataset
so this feature — and every later growth feature — can be driven in the real
app.

- Permanent per `project.md` `scaffolding: keep`, gated with
  `#if targetEnvironment(simulator)` so it can never ship in a release build.
- Delivered as a launch argument, so it survives Maestro's `clearState`, like
  the existing `-BBSkipSplash` and `-hasCompletedOnboarding`.
- Scenarios for this feature: `lowGain` (gain below, feeds and nappies below),
  `healthy` (all within), `sparseLogs` (gain below, nothing else logged).
- Recorded in `.desk/app-map.md` as a navigation and state hook.

## Testing

- **Unit** — `FeedingAdequacy`: each signal at its boundaries, the
  not-enough-data rules, the "weight is the only trigger" rule, window
  alignment between the three counts, corrected age for preterm, and the
  clinical-versus-user nappy reference.
- **Render dump** — the section and the card in en/ru/es, following
  `GrowthCardRenderDump`.
- **e2e** — one authored Maestro flow per scenario, reaching Growth with
  seeded data and asserting the section and the card. Made possible by the
  hook above.

## Localization

New keys in `en/ru/es.json` with identical key sets, copies synced into
`WidgetResources/` (the pre-build script fails the build on drift). No widget
surface is touched. Copy carries no brand name except through `brand.name`.

## Open question for the owner

The two reference tables (feeding frequency, wet nappies) are shaped correctly
but their exact boundaries have not been verified against a primary source
line by line. Confirm them, or hand them to whoever reviews the medical copy,
before the plan is written.

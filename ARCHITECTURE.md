# Architecture

How this app is built and why it is built that way. The folder tree lives in
[README.md](README.md); this file covers the mechanisms you cannot infer from
it. Decisions and their reasons are in [DECISIONS.md](DECISIONS.md);
notification scheduling has its own reference in
[NOTIFICATIONS.md](NOTIFICATIONS.md).

Keep this file true. If a change here makes a paragraph below wrong, the
change is not finished until the paragraph is fixed.

---

## The product in one breath

A newborn tracker for the first two years: feeding, sleep, diapers, growth,
and a small set of events. Parents log a few taps a day; the app answers the
question underneath the logging — *is my baby all right?* — from the WHO
growth standards, and reminds them when a feed or a nap is due.

It ships as one app under three names, one per language: **Bitty** (en),
**Ночка** (ru), **Nenita** (es). Not three products — one binary whose brand
token is localized like any other string.

## Three targets, one store

| Target | What it is |
|---|---|
| `BabyBloom` | The app. iOS 17+, universal (iPhone + iPad). |
| `BabyBloomWidget` | WidgetKit extension. Reads the same store, writes nothing. |
| `BabyBloomTests` | XCTest bundle. Also compiles parts of the app source directly. |

The three meet at the App Group `group.com.nenita.app`, which is where the
SwiftData store physically lives. That single fact explains most of the
structure below.

## Domain model

Six `@Model` types in `BabyBloom/Core/Models/`: `Baby`, `FeedingEntry`,
`SleepEntry`, `DiaperEntry`, `GrowthEntry`, `CustomEvent`.

**Every stored property has a default value and every relationship is
optional.** That is not style — it is what CloudKit requires of a mirrored
SwiftData schema. A new non-optional property without a default will compile
and then fail at container creation, at launch, in `fatalError`.

`Baby` owns the five entry types with `deleteRule: .cascade` and an explicit
`inverse:`. Deleting the baby deletes its history.

**The app is single-baby by construction.** Onboarding creates exactly one
`Baby`; every screen reads `babies.first`; no `@Query` filters entries by
owner. Entries carry a `baby` link so the cascade rules mean something, but
nothing reads that link for scoping. Multi-baby support is therefore not a
model change — it is a change to every query in the app.

**What onboarding writes, and when.** Its measurements page asks for the
weight and height AT BIRTH — the discharge-record numbers — and
`OnboardingBabyBuilder.build` turns that one answer into two things:
`Baby.birthWeightKg`, filled whenever the parent knows it, and a first
`GrowthEntry` dated at `Baby.birthDate` rather than at the moment onboarding
finished. The builder is a pure function taking no model context, so both
rules are unit-testable; `createAndFinish` only inserts and saves what it
returns. The flow is ONE-WAY and runs once:
`BabyProfileEditSheet` writes `birthWeightKg` later without touching history,
because a correction to the profile is not a new weighing. The birth DATE is
the one field that does reach history, and it is what keeps the invariant above
true: the sheet buffers every field until Save (Cancel discards the lot), then
uses `BirthDateChange` to move the entries dated on the old birth DAY onto the
new birth date, to bound its picker at the day before the earliest
non-birth-day measurement (or today, whichever is earlier), and to clamp what
it stores to that same bound.

The page carries an «I don't remember» opt-out, and it produces a THIRD
outcome rather than a default: `birthWeightKg` stays nil **and no first
`GrowthEntry` is created at all**. A slider always holds a number, so without
it every parent who cannot find the discharge record would store an invented
3.5 kg as both the baseline the 10%-loss flag is measured against and the
first point on the chart. Nil is what turns the newborn instrument off — no
`NewbornProgressCard`, no gain deferral — which is also the state of every
install from before this feature, and the state a parent reaches by clearing
the field in their profile. All three are one code path, deliberately.

`OrphanedEntryAdoption` is a one-shot migration for entries created before
that link existed. Two things about it are load-bearing: it filters in memory
rather than expressing `baby == nil` as a `#Predicate` (SwiftData does not
handle nil to-one relationships dependably), and it refuses to burn its
"done" flag when no `Baby` exists yet — a fresh install still in onboarding
is the normal case, and marking it done there would strand those entries
forever.

## Persistence and sync

The app opens the container with `groupContainer: .identifier(...)` and
`cloudKitDatabase: .automatic`. Sync is silent and free: no sync code exists
in this repo, CloudKit mirrors the store.

The widget opens **the same store with `cloudKitDatabase: .none`**. A widget
extension must not drive sync — the app target owns it. Because the models
are CloudKit-compatible, `.none` reads the identical store with no schema
mismatch.

Two consequences worth knowing before you debug something:

- **The store survives an app uninstall.** It lives in the App Group
  container, not the app container. `xcrun simctl uninstall` does not give
  you a clean database; erasing the device does.
- **A simulator signed into a real Apple Account syncs for real.** Anything
  that wipes the store — the seed hooks below — reaches that account's
  private CloudKit database. Run seeded flows on a simulator with no account.

## Localization

Three languages: `en`, `ru`, `es` (`SupportedLanguage` in
`Core/Localization/LocalizationManager.swift`).

**`NSLocalizedString` is never called.** Every UI string resolves through a
JSON dictionary per language and the `.l` extension. The `.lproj/
Localizable.strings` files are gone; `{en,ru,es}.lproj/InfoPlist.strings` is
still live and is what makes the app icon's caption change per language.

The JSONs exist in **two physical locations**:

- `BabyBloom/Resources/Localization/{en,ru,es}.json` — the source of truth.
- `WidgetResources/Localization/{en,ru,es}.json` — a copy the widget target
  bundles. It must be a distinct path outside any other scanned source root,
  or XcodeGen dedupes the file references with the app target and the `.appex`
  ends up with no Resources build phase at all — the widget then renders raw
  i18n keys.

A pre-build script (`preBuildScripts` in `project.yml`) `cmp`s the two sets
and fails the build on drift. Do not disable it; sync instead:

    cp BabyBloom/Resources/Localization/$f.json WidgetResources/Localization/$f.json

**Language resolution order** (`LocalizationManager.storedLanguage`):
launch argument → App Group suite → this process's own `UserDefaults`
(legacy, so upgrading users keep their choice) → device default. The launch
argument must be read explicitly via `volatileDomain(forName:)`: the argument
domain's precedence applies only within `UserDefaults.standard`, and the App
Group is a separate store that would otherwise shadow it.

The widget process cannot see the app's `UserDefaults.standard` at all, which
is why the language travels through the App Group. It also outlives a language
change — iOS reuses the extension process — so the provider calls
`refreshFromStore()` before reading anything, and the app asks for a timeline
reload when the language changes rather than leaving the widget stale for up
to 15 minutes.

## Theming and typography

The palette is **entirely** in the Asset Catalog
(`Resources/Assets.xcassets/Colors/`), reached through `BBTheme.Colors`.
Never hardcode a colour in a view. Re-theming the app is: colorset edits, the
two splash PNGs, and the hex constants in `ExportGenerator` — the PDF renderer
cannot read the Asset Catalog, so it is the one place a colour is duplicated.

`BBTheme.Typography` is the D1 type scale. **Every Dynamic Type scale in the
app goes through `Typography.scaledPointSize`**, including layout metrics that
must track text size. A bare `UIFontMetrics.scaledValue(for:)` is a defect:
that form reads the *device* content size and ignores the SwiftUI environment,
so the app's ceiling walks straight past it. The ceiling itself
(`Typography.maxContentSizeCategory`, AX2) lives in exactly one constant, from
which `BabyBloomApp` derives its `.dynamicTypeSize` modifier — the two cannot
drift apart. See [DECISIONS.md](DECISIONS.md), 2026-08-28.

The widget extension bundles its own small catalog, `WidgetResources/Colors.xcassets`,
holding the brand colorsets it uses. It cannot share the app's catalog: that
path sits inside the tree the app target already scans, and XcodeGen then
dedupes the file references and ships an `.appex` with no Resources build
phase — the same trap the localization JSONs are laid out to avoid. The
pre-build script `cmp`s both copies and fails the build on drift.

## The growth engine

`BabyBloom/Core/Growth/` is pure domain logic — no SwiftData, no model
context, no SwiftUI. It works on `WeightMeasurement`, not on `GrowthEntry`,
which is what makes it trivially testable. Each file answers one clinical
question, and each carries its source in its header:

| File | Question |
|---|---|
| `WHOGrowthStandard` | How big is this baby? Weight-for-age percentile from published LMS coefficients (0–24 mo). |
| `WeightVelocity` | Is enough going on? Gain against WHO 1-month weight-velocity increments. |
| `GrowthTrend` | Is the baby holding its centile channel? Centile-space movement in EITHER direction — NICE faltering-growth thresholds for a fall, a flat two spaces for a rise. |
| `NewbornWeightLoss` | The first two weeks, measured against birth weight — where a percentile is the wrong and actively frightening instrument. |
| `FeedingAdequacy` | Is the baby getting enough food? Gain + feeds + wet nappies. |
| `StatusWord` | Which word does a parent read for one of those signals? |

`GrowthEntry` rows become `WeightMeasurement`s through one accessor,
`[GrowthEntry].weightMeasurements`, and that accessor is the engine's door:
it drops entries with no weight AND entries dated more than a day ahead of the
device clock, so a future-dated or clock-skewed row carries no verdict while
still showing in the measurement history (DECISIONS 2026-09-05).

**Which two weighings a verdict is measured over is one rule, in one place:**
`WeightVelocity.pair(in:)`. It takes the newest weighing and walks backwards
to the most recent earlier one at least `minimumIntervalDays` away, so a tail
of weighings too close together to measure is absorbed into a longer interval
instead of silencing the card. `WeightVelocity.latest` and `FeedingAdequacy
.window(for:)` call it; `consecutiveBelowReference` chains the same backwards
walk to find each interval's start. That shared walk is what keeps the three
day counts on the Growth screen describing one period
(see DECISIONS 2026-09-05). `GrowthTrend` is the exception and stays one: it
answers a months-long question and owns its own window rules.

**The newborn window outranks every gain verdict, through one predicate.**
`NewbornWeightLoss.gainDeferral(birthWeightKg:birthDate:measurements:now:)`
answers "is a gain verdict withheld, and why". A newborn's physiological dip
lands below every velocity reference, so while it returns non-nil no surface
may report a gain at all: `FeedingAdequacy.assess` returns
`Signal.deferredToNewbornWindow` (which `warrantsBreakdown` cannot fire on and
`StatusWord` renders as `.firstWeeks`), `GrowthView` hands the case itself to
`WeightGainCard`, and `NotificationManager.shouldRaiseGainSignal` refuses
`growthGainLow`. Three consult sites, one predicate — the gate lives where a
verdict is EMITTED, and deliberately not inside `WeightVelocity`, which is a
WHO increment table and knows nothing about birth weight.

It returns two cases, because they differ in what the parent can do:

- `.firstWeeksNow` — `windowActive` is true: a birth weight is on file and the
  baby is no older than `observationWindowDays`. This is also what puts
  `NewbornProgressCard` on screen (`analyse` is gated on the same predicate,
  so the card and the rule cannot disagree), and that card holds the verdict.
- `.measuredInFirstWeeks` — the window has closed, but the later endpoint of
  `WeightVelocity.pair(in:)` still lies inside it. Without this the verdict
  switched on the morning after the card vanished, off data that had not
  changed. The card says the weighings are from the first weeks and asks for a
  new one; a new weighing becomes the pair's later endpoint and ends the
  state, so it can never be permanent.

The LATER endpoint, never the earlier one. The WHO 0–4 week row is itself a
birth-to-one-month increment and already contains the dip, so a pair ending at
day 28 is the quantity that row was built from while a pair ending at day 10 is
its losing half measured against the whole. Gating on the earlier endpoint
instead would silence the gain card forever for a baby whose only two weighings
are birth and month one.

`WeightVelocity.consecutiveBelowReference` takes the window's end date as
`intervalsMustEndAfter` and stops the chain at an interval that ends inside it.
The deferral above covers only the NEWEST interval, which is all a card shows;
the notification chains further back, and an interval lying in the dip would
otherwise supply the second half of the "pattern" the count-2 rule exists to
demand independent evidence for.

With no birth weight there is no deferral: `NewbornProgressCard` is absent too,
so nothing would hold the verdict's place. That is the same state an install
from before this feature is in, and the same state «не помню точно» produces.

The medical spine of `FeedingAdequacy`: **weight gain is the only trigger.**
Feeds and nappy counts are context and never raise a concern on their own. If
gain sits within the reference the app says nothing, whatever the other two
say. Do not "improve" this into a multi-signal alarm.

That rule is why `FeedingAdequacy.Signal` has no `.above`: `assess` collapses a
gain above the reference onto `.within`, so the breakdown gate cannot fire on a
baby gaining fast. **The gate's vocabulary is not the parent's.** Every surface
that renders a `Signal` renders `StatusWord.of(signal, band:)` instead, which
takes the `WeightVelocity.Band` for the same pair of weighings and splits
`.above` back out. (`WeightGainCard` is not one of them: it renders the `Band`
directly and always did say "above the reference" — it was the surface the
build-11 contradiction was measured against.) Change the gate and the word
together only if you mean to; they are separate on purpose.

Single-value percentile cards score a weighing at the age the baby was **on the
day it was taken** (`WHOGrowthStandard.percentile(of:correctedBirthDate:isMale:)`),
never at today's age — the same rule `GrowthTrend` has always followed.

**Two kinds of weighing carry no CENTILE verdict, and both are still real data
in the history and on the chart.** `GrowthTrend` drops them from its scored set
and the per-measurement percentile entry points return nil:

- Inside `birth + NewbornWeightLoss.observationWindowDays`. The physiological
  dip is a one-to-two-space fall in centile terms, so the birth weighing
  becomes the trend's peak and ordinary catch-down reads as faltering growth.
  Same rule as the gain gate, on the other verdict over the same days —
  unconditional here, because dropping points degrades to `insufficientData`
  rather than leaving a verdict unheld. The cost is that the first trend
  verdict now lands near day 50 rather than day 28 — three scorable weighings
  spanning 28 days, starting no earlier than day 22.
- Before `correctedBirthDate`. `correctedAgeDays` clamps at zero;
  `correctedAgeDaysIfBorn` returns nil instead, because scoring a preterm
  baby's actual-birth weight against the term newborn curve is a category
  error, not a low percentile. `WeightVelocity` keeps the clamp on purpose —
  an increment table's newborn row is roughly right at catch-up rates.

`GrowthTrend.assess` therefore takes the CHRONOLOGICAL `birthDate` alongside
the corrected one; the newborn window follows delivery, not maturity.

`Baby` also carries corrected age for preterm babies, used everywhere except
newborn weight loss — the physiological drop follows delivery, so it is
counted from the actual birth.

Each verdict card on the Growth screen — first weeks, percentile (including its
out-of-range state), gain, centile trend, nutrition — carries a "?" badge and an
explainer sheet behind it. All five are one mechanism, in
`GrowthInsightCards.swift`: `GrowthExplainer` names the subject and resolves its
icon, tint and copy keys (`<card's own key family>.info_title` / `.info_body`),
and `ExplainerSheet` renders any of them.

How a card opens its explainer depends on what its own tap already does:

- **Unlocked** — the card is wrapped in `ExplainerCard`, which makes the WHOLE
  card open the sheet and *injects* the badge (`InfoBadge` draws only when the
  `hasExplainer` environment value says one is wrapping it, so a card rendered
  anywhere else cannot advertise an explainer that is not there). It is a
  `contentShape` + `onTapGesture`, deliberately **not** a `Button`: a Button
  flattens its label into one accessibility element and would destroy
  `NutritionSection`'s one-stop-per-row structure. Non-visual access is a named
  action (`explainer.action`) carried by `InsightCardTitle` — the card's title,
  an element that certainly exists and the place the "?" sits — which reaches
  the sheet through the closure `ExplainerCard` puts in the environment.
  Nothing is attached to the container itself.
- **Locked** — a `LockedInsightCard`'s tap sells Premium and keeps it. The badge
  is its own button there (`InfoBadgeRole.control`, a 44pt target held out of
  the layout by negative padding), and because that button is inside the sell
  Button's label it is invisible to VoiceOver, so the same named action is
  attached to the card. `sell()` refuses to run while the explainer sheet is up,
  which is what makes a double activation impossible rather than merely
  unobserved.

Every Growth-screen state held back by a missing WEIGHING names that and
offers the action that resolves it — first weeks, gain, centile trend and
nutrition through `HintWithAddWeighing` (hint + CTA), and the measurement
history's `EmptyStateView` with the same button stacked under it. States
missing feeds or nappies (the per-row "мало данных", the breakdown's no-data
line) carry no weighing CTA — their resolving action lives on other tabs. The CTA opens
the same `AddGrowthSheet` the "+" opens. The action travels the way the
explainer's does, through the environment (`\.addWeighingAction`, set once by
`GrowthView` for the whole screen), so `AddWeighingButton` draws itself ONLY
where something can answer it — a card rendered in a dump or a preview shows
the hint alone, and `HintWithAddWeighing` reads the same value so the stack
does not reserve a row for a button that will not be there. It is a real
`Button` inside `ExplainerCard`'s tap gesture: the child control answers the
tap first, so the CTA opens the sheet and the rest of the card still opens the
explainer, and unlike the "?" badge it is its own VoiceOver element. The gain
and nutrition cards take `hasWeighing` and ask for "one more weighing, N days
after the previous one" once anything is on file — phrased against the previous
weighing rather than the first, which keeps it true for two weighings taken on
the same day (nutrition's empty state covers that case too).

**The gain card's two newborn deferrals are not empty states, and only one of
them carries the CTA.** Both have plenty of data — see the gate above — so
neither reads `hasWeighing`, which the deferral outranks. `.firstWeeksNow` has
no button: `NewbornProgressCard` is on the same screen by the same condition,
it is the card holding the verdict, and its own empty state already asks for
the weighing. `.measuredInFirstWeeks` has one, through the same
`HintWithAddWeighing`, because that card is gone by then and a weighing is
literally what ends the state. No card on this screen shows two CTAs.

**The weight chart is drawn on an AGE axis, over the WHO corridor.**
`WeightChartView` (Swift Charts) takes `[WeightMeasurement]` — already through
the engine's door, so the chart plots exactly what the cards below it score —
plus `correctedBirthDate`, `birthDate` and the sex, and places each point at
its age from the corrected birth rather than at its index in the list. That is
what lets a band mean anything: the corridor is a function of age, and evenly
spaced points would sit over the wrong part of it. The time axis is LABELLED
in calendar dates (corrected birth + age, so the spacing is the same), the
weight axis in kg, and a readout above the plot states one weighing — weight,
date, chronological age at that date from `birthDate`. It shows the latest by
default; a tap selects the weighing nearest the tap in screen space, marked
with a rule, and any change to the measurements resets it to the latest
(DECISIONS 2026-09-23). `WHOCorridor.samples(fromAgeDays:toAgeDays:isMale:)` is the
shared sampler, pure and unit-tested, and it carries the two clinical clamps as
geometry: **the band starts at age 0**, never earlier — a preterm baby's
pre-due-date weighings keep their negative ages on the axis and get no band
beneath them, the drawing face of `correctedAgeDaysIfBorn` returning nil — and
**it stops at `maxAgeDays`**, past which the chart draws the line alone. The y
window spans the baby's weights *and* the band, so neither is clipped. One
weighing is enough to draw (the chart widens to a 28-day window around it),
which is what every fresh install has, and the corridor is free for everyone —
the showcase page promises it before anyone has paid.

`showsWHOCorridor` exists for a caller that ever reuses this shell for height
or head circumference: those are different tables, and a weight corridor under
a length is the wrong standard, not an approximation.

**The percentile card is `PercentileCard` (`Features/Growth/`), and it is
shared with onboarding.** `GrowthView` wraps it in the `ExplainerCard` above —
that wrapper is what injects the "?" — and passes two caption lines; the
onboarding showcase page renders it bare, with one caption line and
`tone: .neutralOnly`. The tone is the only behavioural difference: below the
3rd centile or above the 97th the tail takes the neutral `textPrimary` instead
of `BBAlert`, while the band LABEL is unchanged (DECISIONS 2026-09-21). It is
one view rather than two because a hand-copied card stating a clinical figure
is a drift this project has already paid for.

## Onboarding

Eleven pages, and **the enum's case order is the flow**: `OnboardingStep` —
welcome, name, birth, feeding, growth, fact, growthShowcase, notifications,
widgets, generating, premium. The first four after welcome are the quiz
(`isQuiz`, progress bar, shared bottom nav); the five info pages after `growth`
— fact, growthShowcase, notifications, widgets, generating, and not the paywall,
which sells rather than informs — are not, so inserting or reordering among them
touches neither `quizProgress` nor the nav (DECISIONS 2026-09-01).

Two of those pages show the REAL product rather than a picture of it.
`WidgetShowcasePage` renders `BabyBloomMediumWidgetView` with a constructed
entry. `GrowthShowcasePage` renders `PercentileCard` with the parent's own
answers: `OnboardingGrowthPreview.state(...)` — pure, unit-tested — scores the
birth weight at day 0 through the same
`WHOGrowthStandard.percentileReading(of:correctedBirthDate:isMale:)` the Growth
screen calls, and returns `.invitation` for the two cases with no honest
number (no birth measurement, and a preterm birth before the corrected due
date). The corridor drawing beside it samples `WHOCorridor` — the same sampler
the Growth screen's chart draws, with the same fill, the same median stroke and
the same `WHOCorridorLegend` underneath, so the parent recognises the real
chart when they reach it. Only the baby's forward line is illustrative: it is
dashed and labelled as a sketch, because it is the one thing the app cannot
know yet. Nothing on either page is seeded, saved or read back.

The loader-to-paywall hand-off is observable to tests: `GeneratingPage`'s
`onDone` sets `generatingFinished`, and the paywall's accessibility identifier
is `onboarding.premium.afterGenerating` only then (`onboarding.premium`
otherwise). The e2e walks assert that id rather than the ~5 s loader, which
Maestro cannot reliably catch (DECISIONS 2026-09-22).

## Premium

StoreKit 2, three auto-renewable products in one subscription group:
`com.nenita.app.premium.{weekly,monthly,yearly}`. `Nenita.storekit` is the
local test configuration and is wired into the scheme.

**No price, saving or trial length is written into the source.** The paywall
derives all three from `Product` — `displayPrice` and
`subscriptionInfo?.introductoryOffer`. That is what keeps 175 configured
territories correct and what stops the screen advertising a discount it does
not give.

`SubscriptionManager.isEntitled` is the StoreKit truth. `isPremium` is
computed on every access as `isEntitled || override` — not stored — because
`refreshEntitlements()` assigns unconditionally and runs repeatedly (see
below), which would clobber an override written once at init.
Entitlement is resolved by `BabyBloomApp` itself: a root-level `.task` runs
`refreshEntitlements()` during the splash on every launch, and the
`scenePhase == .active` branch re-runs it on every foregrounding — a lapsed
subscription produces NO transaction (it just drops out of
`currentEntitlements`), so `Transaction.updates` can never report expiry, and
without the foreground re-ask a suspended app would serve premium to a lapsed
subscriber until the next cold launch. Screens with skin in the game
(profile, both paywalls) still re-ask on appearance; all of these are
idempotent reads of the same source.
`restorePurchases` deliberately reports off `isEntitled`, so the override
cannot fake a restore. `hasResolvedEntitlements` says whether StoreKit has been
asked at all: before the first `refreshEntitlements()`, `isEntitled == false`
means "not asked", which is indistinguishable from "not subscribed". Anything
that BRANCHES on entitlement — sell or do not sell — must wait for it; anything
that merely gates a feature reads `isPremium` and lets the gate close itself
when the answer arrives.

**Two paywalls, one selling half.** `PlanPickerSection` is the plans, prices,
trial promise, CTA, restore and legal footer; `PaywallView` (settings, modal)
and `PremiumPage` (onboarding, page 11) compose it. The section has no
"purchased" callback: reacting to entitlement is the host's job, because
entitlement arrives from a purchase, from `restorePurchases()`, from
`Transaction.updates`, or from the user having subscribed before the screen
ever opened, and a callback on the purchase button covers only the first.
**Both hosts wait for `hasResolvedEntitlements` before showing either half** —
selling on an unresolved answer is the defect, and it is not specific to
onboarding. `PaywallView` then swaps the section for its active badge and
navigates nowhere; `PremiumPage` refreshes entitlements in its own `.task` and
calls `onPurchased()` from a single `advanceIfEntitled()` — on arrival and on
any later change to `isPremium` — so an already-subscribed user is never sold
to and never stranded. Neither screen shows an empty gap while it waits.

The advance rule itself is `SubscriptionManager.mayAdvanceOnEntitlement`, a
pure function, because what it encodes is a race: `restorePurchases()`
publishes `isEntitled` inside `refreshEntitlements()` and then awaits the
networked intro-offer lookup before assigning `restoreState`, so a host
watching only `restoreState` can slip through the gap and end onboarding
before "Purchases restored" is drawn. `isRestoring` spans the whole call and
closes it; `restoreState` covers the rest, while the alert is up. Both halves
are unit-tested without a simulator, which is the only way a race can be
pinned.

What is gated: three cards on the Growth screen — `WeightGainCard`,
`CentileTrendCard` and `FeedingBreakdownCard` — each falling back to a
`LockedInsightCard` built from the SAME title key, which is why an e2e
assertion on that title proves nothing without `-BBForcePremium`. Export,
gated at the navigation point in the settings list rather than inside
`ExportView`. The paid half of the Dashboard's Growth section, which falls
back to a `LockedInsightCard` of its own. And **creating** an event: the
Dashboard quick action, `EventsView`'s toolbar button and its four quick-add
tiles all route through `EventsView.addEvent(_:)` or the Dashboard's own
branch, and each wears a padlock badge so the gate is visible before the tap.
And **how far back the five activity lists read** — the free history window
below, the only gate that bounds something already recorded.

That badge is one component, `LockBadge` (`DesignSystem/Components/`), drawn
identically at every gate. It is `accessibilityHidden`; the words go on the
enclosing button instead, via `View.bbLockedAccessibility(_:)`, which appends
`premium.locked_a11y` as the control's accessibility **value** so VoiceOver
reads "Events, Requires Premium" rather than losing the gate entirely.

**The free history window.** Activity lists show a free account the last 15
calendar days and offer the rest for sale. `Core/History/HistoryWindow.swift`
is the whole mechanism and it is pure Foundation: `freeDays` (15) — a number
also spelled out in six JSON strings, see the comment on the constant — and
`cutoff()`, `startOfDay(now − 14 days)`.

`HistoryWindow.list(_:date:cutoff:cap:)` is the single derivation all five
surfaces use. It returns three things: `visible` (windowed, then capped),
`showsLockedFooter`, and `deletable` — the **untouched input**, which is what
makes the no-hostage rule a property of the type instead of a discipline at
five call sites.

- **Where the boundary comes from.** Views never compute it. They forward
  `SubscriptionManager.historyCutoff`, the one place the entitlement, the
  15-day arithmetic and the unresolved-entitlement grace meet. It returns `nil`
  (unlimited) for a subscriber **and while `hasResolvedEntitlements` is
  false** — truncating on an unresolved `isEntitled == false` would hide a
  paying parent's records and sell to them, the build-9 mistake. Every failure
  in this file fails open.
- **Window before cap.** `BBHistorySection` (Feeding, Sleep, Diapers) passes no
  cap and applies the window after the range picker's own filter.
  `EventsView` and `RecentActivityView` pass `cap: 20`, applied *after* the
  window, so the footer means "older than 15 days" and not "beyond twenty
  rows".
- **The lock appears only where the window is the binding limit.**
  `windowCostsRows` compares what is drawn with the window against what would
  be drawn without it. Where a cap is what is costing rows — 45 events inside
  the window, twenty rendered — a free account and a subscriber see the same
  list, so the lock would state a falsehood and sell nothing. A fresh install
  sees no lock either.

All five render the same `BBLockedHistoryFooter`
(`DesignSystem/Components/`, its own file like `LockBadge`): calm tint, 44pt
target, whole row taps through to `PaywallView`, one accessibility element
labelled with the window and valued `premium.locked_a11y`.

What it does NOT touch: every `@Query` still reads the whole store. Statistics,
the weekly charts, `FeedingAdequacy`, `WeightVelocity`, exports, the widget and
notifications all consume the unwindowed arrays; only the arrays a list view
renders pass through `list`. **Growth measurement history is exempt** — the
weighings are the clinical spine and `GrowthView` renders all of them.

**Deleting is never gated and never windowed.** Every surface that windows a
list owes it a delete path over the *unwindowed* array, and all four that can
delete have one: `BBHistorySection` hands `onDeleteAll` the full
picker-filtered range, and `EventsView` grew a `BBDeleteHistoryButton` for
exactly this reason — its older events had no swipe to reach them and export is
itself paid. (`RecentActivityView` has none by design: it is a read-only view
onto three lists that each have their own, and every row it can reach stays
swipe-deletable.) `BBDeleteHistoryButton` warns whenever
`deletable.count > visible.count` — deliberately broader than the footer's
test, since the confirmation must own up to rows the cap is holding back too —
and picks its wording from its `Scope`: `confirm.delete_message_hidden` ("in
the selected period") only where a `BBHistoryFilterPicker` gives that phrase a
referent, and `confirm.delete_message_all` on `EventsView`, whose button wipes
the whole event history. Recorded data is not held hostage.

One bound worth naming: "delete history" acts on the *picker's* range, so on
the three tracker screens the widest it reaches is `filter.year`. Entries older
than a year are not reachable by that button — from either tier, and for
reasons that predate the window.

## Notifications

`Services/NotificationManager.swift`, local notifications only, no APNs. The
intervals are age-scaled and the feeding interval adapts to the parent's own
logged rhythm. The full catalogue — identifiers, age tables, scheduling
triggers — is [NOTIFICATIONS.md](NOTIFICATIONS.md); it is a reference, keep it
in step with the code.

Permission is requested from onboarding's own notifications page (page 8 of
11, before the Generating loader whose last step promises reminders) — never
at launch and never over the Dashboard. That page is the single call site of
`requestPermission`.
`onAppForegrounded()` runs on every `scenePhase == .active`.

## The review prompt

The App Store rating prompt is requested from exactly one place, and only
after an entry is saved. `ReviewPromptPolicy` (`Core/Review/`, pure) decides;
`ReviewPromptService` (`Services/`) remembers the first launch, the last
requested version and date in `UserDefaults`, and holds a per-process
"a save is waiting" flag; `ReviewPromptTrigger` is the SwiftUI side. Save
paths call `@Environment(\.reviewPrompt).entrySaved(<kind>)` and nothing more
— the same call reports a kind's `first_entry` (see Analytics).
`MainTabView` installs the live trigger (`.reviewPromptHost()`), which on a
tab asks the policy at once; every sheet that can save an entry is presented
with `.entrySheet` instead of `.sheet`, which hands its content a DEFERRED
trigger and asks only from its `onDismiss` — the outermost one's, so the
Dashboard's quick sheets (whole tab screens with their own add sheets) wait
until the parent is back on a tab. Onboarding sits outside `MainTabView` and
gets the inert default, so it cannot reach the prompt; nor can launch, a tab
switch or Cancel, because only a save sets the flag; `PaywallView` clears it
on appearing, so a declined upsell inside a quick sheet is not followed by a
rating prompt. Timer STOPS ask, because that is when the entry becomes a
finished record; timer starts do not, because nothing is finished yet. Nothing
is asked in quiet hours, 22:00–07:00 on the device's local clock, whatever the
trigger; the refusal records nothing, so the next daytime save that meets the
rules asks. The thresholds — quiet hours included, all timing and counts — are
checked first; only a yes goes on to read the
store for the blockers, through the growth engine's own predicates —
`gainDeferral` + `WeightVelocity.latest` for a below-reference gain,
`NewbornWeightLoss.analyse` flags — plus
`SubscriptionManager.transactionFailedThisSession`, a flag that, unlike
`purchaseError`, the next paywall visit does not clear. A user cancel does not
set it; a restore that finds nothing does. The system
never says whether it showed anything: TestFlight builds never show it, so
"no prompt on TestFlight" is not a bug (DECISIONS 2026-09-22).

## Analytics

Product analytics go to Amplitude (US region) through one facade,
`Services/Analytics/`. It measures the onboarding and paywall funnel and
activation — never a name, a weight, a date or anything a parent typed, and
never a per-entry or intraday timeline.

**Views and services see only `Analytics.shared` and `AnalyticsEvent`.**
`AnalyticsBackend` is the protocol behind the facade, one file per backend:
`AmplitudeAnalyticsBackend` (the only file that imports `AmplitudeSwift`),
`NoopAnalyticsBackend`, and the simulator-only `LoggingAnalyticsBackend` behind
`-BBAnalyticsSpy`. Moving to another vendor is one new backend file and one line
in `Analytics.makeShared()`; no call site changes. `ReviewPromptTrigger` and
`ReviewPromptService` take their analytics injected (`live(…analytics:)`,
`init(…track:)`), so tests hand in an isolated facade.

**What keeps the payload safe, and what does not.** `AnalyticsEvent` is a
closed enum. A property value is an `AnalyticsValue`, whose only constructors
take a Bool, an Int, or a case of an `AnalyticsToken` — meant to be the app's
own String enums, whose raw values are compile-time literals, though the
protocol cannot enforce "enum". There is no initializer from a free `String`,
and `AnalyticsPayload` can only be built by `AnalyticsEvent.payload`. That keeps
typed text out by construction. It does NOT bound numbers: `.int` takes any
Int. What fixes which numbers and tokens go out is the rest of the guarantee —
the closed enum, an exhaustiveness guard in the test that stops compiling when
a case is added, and `AnalyticsEventTests`' hand-edited allow-list of names,
keys and value sets (today the only Int is `seconds_visible`).

**When it is a no-op.** `Analytics.decide` (pure, unit-tested): no API key → no-op;
simulator → no-op (or a simulator hook, below); Debug build → no-op; otherwise
Amplitude. So a fresh clone, every simulator run and every test run construct
no SDK, send nothing and write no analytics state (the test host runs the real
app, and a no-op facade leaves `UserDefaults` alone). Only Release device
builds send. Every event carries `build_channel`, detected in AmplitudeCore's
own order: simulator → `simulator`; an embedded `embedded.mobileprovision`
(development, ad-hoc, a Release build run from Xcode or handed to QA) →
`development`; a `sandboxReceipt` → `testflight`; otherwise `appstore`.

**No sessions.** `autocapture` is empty. Session start/end events would be the
one intraday timeline left — in a newborn tracker, app opens track night feeds
— and `daily_activity` already marks active days, so DAU and retention run on
it. The SDK still numbers sessions internally, so the funnel events carry a
`session_id` (the start time of the session they fell in) and their own client
time; `daily_activity` carries neither (below).

**The opt-out.** Profile › Data › «Статистика использования» / "Usage
Statistics" (`settings.analytics`; not called anonymous — a persistent
per-install id is pseudonymous), default on, stored in `UserDefaults` under
`analytics.enabled`. The facade drops every event while it is off. The
Amplitude backend is built lazily and never for an opted-out launch —
constructing the SDK's `Configuration` alone fires a remote-config request.
Turned off mid-session it sets the SDK's `optOut`, resets both storage
providers (`configuration.storageProvider` / `identifyStorageProvider`: the
unsent queue and every stored id and counter), calls `reset()` (a new random
device id), and is retired for the rest of the process — `canSend` is false
even if the setting comes back on, and the next launch builds a fresh SDK.
**The wipe is done twice.** The retired instance's session bookkeeping runs on
every foregrounding, with session events off too, and writes the old event
counter, session id and last-event time back into the storage just cleared
(verified on the simulator: `last_event_id` reappeared after a foreground). So
the opt-out also persists `analytics.amplitudeWipePending`, and `make()` resets
both storages again BEFORE `Amplitude(configuration:)` reads them, then clears
the flag: after opt-out → relaunch → opt-in the SDK starts with a new device id
and `event_id` from 1, and the two periods cannot be joined. Residuals: an
upload already in flight cannot be recalled; an event handed to the SDK in the
instant before the switch can still be written, and the retired instance's
30-second flush timer then UPLOADS it; and the retired instance can re-fetch
remote config (no event data) until the process exits.

**Once-only markers are spent on delivery.** `track` answers whether the event
reached a backend that `canSend`. `first_entry` kinds, the `daily_activity` day,
the `history_lock_shown` surface-day, the `widget_installed` flag and an Ask to
Buy marker are recorded only on a yes, so a retired backend burns none of them.
The one deliberate exception is the parent's own opt-out: a kind logged while
opted out is still marked seen (no false "first" after opting back in), and an
opted-out day is marked handled (never back-filled with data from a period the
parent declined). A day or probe marker found in the FUTURE — the clock moved
back, or the `-BBAnalyticsDayOffset` hook — is pulled back to today without
sending.

**SDK configuration** (`AmplitudeAnalyticsBackend.make`, Amplitude-Swift
1.19.0 read from source): no `setUserId`, ever; `serverZone: .US`;
`TrackingOptions` with IP address off (so the SDK no longer asks the server to
geolocate the request with `"$remote"`), city, DMA, region, **country** (with no
`"$remote"` the SDK would otherwise fill it from the locale's region code) and
carrier off, and IDFV off, so the device id is a random per-install UUID rather
than the vendor id shared with the owner's other apps; `enableCoppaControl` on
(the only public switch for the SDK's internal IDFA field — the SDK never reads
the IDFA or an ADID itself); `autocapture: []` — no sessions, screen views,
element interactions (which read on-screen text), app lifecycles or network
tracking, and this SDK has no deep-link autocapture;
`enableAutoCaptureRemoteConfig: false`, so the Amplitude dashboard cannot switch
any of those on remotely; `enableDiagnostics: false`. Still sent with every
event: app version, OS and version, device model and manufacturer, platform,
preferred language. That is what the client can prove. Whether the server still
derives a location from the connection is Amplitude's side: **owner step** —
after the first TestFlight build with the key, open one event in Amplitude's
User Look-Up and confirm Country, City and Region are empty.

**Residual, not closable from app code:** AmplitudeCore fetches remote config
from `sr-client-cfg.amplitude.com` when the SDK is constructed (and again on
new internal sessions, throttled), and it subscribes to a server-side
`diagnostics` key that can turn Amplitude's own SDK telemetry — crash capture
included — back on regardless of `enableDiagnostics`. That is why the privacy
manifest declares Crash Data and Other Diagnostic Data (below).

**The pin.** Amplitude-Swift, AmplitudeCore-Swift and analytics-connector-ios
are all `exactVersion` in `project.yml` (the latter two only to pin them;
Amplitude-Swift's own manifest asks for open `from:` ranges), and the committed
`Package.resolved` is part of the pin. Any diff to either is a privacy change:
re-read `Configuration`, `TrackingOptions`, `ContextPlugin`, `Sessions`,
`AutocaptureManager`, `PersistentStorage` and AmplitudeCore's
`RemoteConfigClient` / `DiagnosticsClient` before merging it.

**Events and where each is emitted** — one line at an existing choke point:

| Event | Properties | Emitted from |
|---|---|---|
| `onboarding_page_viewed` | `page` (11 page ids) | `OnboardingView`, `.onChange(of: step, initial: true)` — forward and back |
| `onboarding_completed` | `birth_measurements_known` | `OnboardingView.createAndFinish` |
| `paywall_shown` | `source`: `onboarding` \| `settings` \| `history_lock` \| `locked_card` \| `events` | `PremiumPage` / `PaywallView`, once StoreKit has answered AND the parent is not premium — a subscriber who opens the settings row sees the badge, not an offer. `PaywallView(source:)` has no default, so every presentation site names one |
| `plan_selected` | `plan`: `weekly` \| `monthly` \| `yearly` | `PlanPickerSection`, on a CHANGE of plan |
| `purchase_result` | `plan`, `result`: `success` \| `cancelled` \| `failed` \| `pending` \| `already_subscribed` | `SubscriptionManager.purchase`, each branch once, BEFORE `refreshEntitlements()` publishes — so it precedes `onboarding_completed`. `already_subscribed` is StoreKit's `.userCancelled` for an Apple ID that owns a plan. An Ask to Buy approved later arrives only via `Transaction.updates`: the listener reports `success` once for a plan the facade saw go `.pending` (`analytics.pendingPurchasePlans`, plan → when), and only for the parent's own purchase (`ownershipType == .purchased`, not family-shared), dated at or after that moment, with `tx.reason == .purchase`; the next purchase attempt and any restore clear the marker |
| `restore_result` | `result`: `found` \| `not_found` \| `failed` \| `cancelled` | `SubscriptionManager.restorePurchases` |
| `paywall_closed_x` | `seconds_visible` | the X of either paywall (not a swipe-down), once per paywall shown |
| `first_entry` | `kind`: `feeding` \| `sleep` \| `diaper` \| `growth` \| `event` | `ReviewPromptTrigger.entrySaved(_:)` → `Analytics.noteEntrySaved`, once per kind per install (`analytics.firstEntryKinds`); an install already past onboarding when analytics arrives is seeded with every kind, so it reports no firsts |
| `daily_activity` | `feeding`, `sleep`, `diaper`, `growth`, `event`: Bool (logged at all); `total`: `0` \| `1-5` \| `6-15` \| `16+` | `Analytics.appBecameActive` (and `start`) at the first foregrounding of a new local day, for the PREVIOUS day only, once (`analytics.dailyActivityDay`). `DailyActivityCounter` counts that day with one `fetchCount` per kind; the facade reduces the counts to presence plus one total bucket — no per-kind count, and edges clear of the clinical 8–12 feeds a day. Sent with the event time set to NOON of the reported day (local) and `sessionId -1`, so neither the time nor a session id gives away the first open after midnight. Nothing for a store with no baby; the first launch only sets the marker. The store is CloudKit-synced, so this is the baby's logged day across the family's devices, not this install's own usage. A time-zone change can make two consecutive reports cover overlapping hours — acceptable noise for a bucketed aggregate. There is deliberately no per-entry event (DECISIONS 2026-09-23) |
| `notification_permission` | `granted` | `NotificationsPage`, the system dialog's answer only |
| `widget_installed` | — | `Analytics.appBecameActive` via `WidgetCenter.getCurrentConfigurations`, asked at most once a local day (`analytics.widgetProbeDay`), reported once per install |
| `history_lock_shown` | `surface`: `feeding` \| `sleep` \| `diaper` \| `events` \| `recent_activity` | `BBLockedHistoryFooter.onAppear` → `Analytics.noteHistoryLockShown`, at most once per surface per local day (`analytics.historyLockDays`) — on insertion into a (non-lazy) list, not on scroll |
| `review_prompt_requested` | — | `ReviewPromptService.consumePendingSave`, when a request is made |

Every event also carries `build_channel`. `Resources/PrivacyInfo.xcprivacy`
declares Product Interaction, Device ID and Purchase History (Analytics) and
Crash Data plus Other Diagnostic Data (App Functionality, for the remote
diagnostics residual), none linked, none tracking. Keep it, this section and
the App Store Connect answers in step.

## Navigation

`MainTabView` — five tabs: Home, Feeding, Sleep, Diapers, More. Growth,
Recent activity, Events and Profile live under More rather than in the bar;
`RecentActivityView` is the Dashboard's former recent-events section, moved out
whole. The Dashboard's own sections run header → activeTimers → quickActions →
stats → growth → progress. Its Growth header AND the data card under it are one
tap target into `GrowthView` — the second route to that screen — built as a
`contentShape` + `onTapGesture` driving a `navigationDestination`, not as a
`NavigationLink`: a link is a Button and would flatten the card's per-row
accessibility elements into one, the same trade `ExplainerCard` makes. The
named action on the header title is the way in without sight. The locked teaser
below is outside that gesture and keeps its own paywall tap. There is no
separate Settings screen: `ProfileView` carries the baby's details and settings
on one screen, deliberately merged from what used to be two More entries.
Every tab carries an `accessibilityIdentifier` (`tab_home`, `tab_feeding`, …)
because e2e flows select on them; the tab bar itself is reached as
`childOf: {text: "Tab Bar"}`.

The splash plays on **every** cold launch (~5s) — it is `@State`, not
persisted, and there is no `hasShownSplash` flag.

## Build and generation

`BabyBloom.xcodeproj` is **generated** from `project.yml` by XcodeGen. Never
edit it by hand:

    xcodegen generate

XcodeGen **silently ignores unknown or misplaced keys** — no warning, no
error, no diff. After changing `project.yml`, verify the generated artifact
actually changed. This has cost the project real time more than once.

Build phases are driven purely by the `sources` scan; there is no target-level
`resources` key. That is why `WidgetResources/Localization` is declared under
`sources` with `buildPhase: resources`.

**Swift packages** are declared in `project.yml`'s top-level `packages:` and
linked per target: Amplitude-Swift reaches the APP target only (the widget
links nothing from it); its two dependencies are listed too, only to pin them.
All three are `exactVersion`, and `Package.resolved` — committed under
`BabyBloom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, surviving
`xcodegen generate` — is part of that pin: a diff to it needs the privacy
review in Analytics above.

**Secrets never live in the repo — it is public.** The app target's Debug and
Release configurations are based on `Config/App.xcconfig` (XcodeGen
`configFiles`), which sets `AMPLITUDE_API_KEY =` empty and then
`#include? "Secrets.xcconfig"` — the optional include, so a missing file is
not an error. `Config/Secrets.xcconfig` is gitignored; to add the key locally,
copy `Config/Secrets.example.xcconfig` to it and fill in the value. Info.plist
reads it as `AmplitudeAPIKey = $(AMPLITUDE_API_KEY)`. Do not put the key under
the target's `settings:` in `project.yml`: a target build setting outranks the
xcconfig and would silently pin it empty. A fresh clone therefore builds and
runs with an empty key, which makes analytics a no-op (below). `Config/` sits
outside every target's source path, so no xcconfig is ever bundled.

A second pre-build script, "Refuse a Release archive without the Amplitude
key", checks — without echoing it — that the key is not empty, not the
`Secrets.example.xcconfig` placeholder, and exactly 32 characters: in a Release
**archive** (`ACTION == install`) a failure is an error — the build would ship
with analytics off or rejected — and in any other Release build a warning;
Debug builds and a fresh clone are untouched. **Build logs are not shareable from a checkout that
has `Secrets.xcconfig`:** xcodebuild prints every build setting as an
`export` line for each script phase, the key included. Redact it (or build
without the file) before pasting a log anywhere.

## Test hooks — how the app is driven

iOS folds `-key value` launch arguments into `UserDefaults`' argument domain,
so every `@AppStorage` key is drivable from the command line with no product
code: `-hasCompletedOnboarding`, `-appLanguage`, `-appAppearance`.

Seven hooks *are* product code, and six of them are gated on
`#if targetEnvironment(simulator)` — not on `DEBUG`, because a
release-optimized QA build is still a real build on a real device and no
shipped binary may carry a path that wipes data, hands out a paid
entitlement, spends a rating prompt or swaps the analytics backend:

| Argument | What it does |
|---|---|
| `-BBSkipSplash true` | Skips the splash. `@State`, so it needs a hook. |
| `-BBSeedScenario <name>` | **Simulator only.** Wipes the database and seeds one deterministic fixture (`lowGain`, `healthy`, `sparseLogs`, `newbornWindow`, `newbornStalePair`, `showcase`). An unrecognised name logs the valid ones and calls `fatalError` — a typo fails the run instead of quietly testing against the previous fixture's leftovers. |
| `-BBForcePremium true` | **Simulator only.** Renders the paid branch. Without it, an assertion on a gated card passes whether the paid card works, throws, or renders blank — the half of the app people pay for would be structurally untestable. |
| `-BBForceReviewPrompt true` | **Simulator only.** Skips the review prompt's thresholds (count, age, version, interval) but never its blockers, so a single save on a fresh seed reaches the system rating sheet — which development builds show on every request. |
| `-BBAnalyticsSpy true` | **Simulator only.** Swaps the no-op analytics backend for `LoggingAnalyticsBackend`, which writes every payload to the unified log (subsystem `com.nenita.app`, category `Analytics`) instead of sending it. It still requires a non-empty API key, so a spy run also proves the key reaches Info.plist; use a dummy one on the command line (`AMPLITUDE_API_KEY=dummy`). |
| `-BBAnalyticsDayOffset N` | **Simulator only.** Moves the analytics facade's clock N days ahead (nothing else sees it), so a relaunch with `1` crosses midnight on demand and sends `daily_activity` for the real today. It leaves the day markers in the future; the next launch without it pulls them back to today without sending. |
| `-BBAnalyticsLocalSDK true` | **Simulator only.** Runs the REAL `AmplitudeAnalyticsBackend` with uploads pointed at a dead local port (`http://127.0.0.1:9`), so the SDK's own queue under `Library/Application Support/amplitude` and its identity suite show exactly what it would send — device id, event id, session id, time — while no event leaves the simulator. Constructing the SDK still fetches Amplitude's remote config with the build's key: build with a dummy one. |

Widget views live in the **app's** source tree
(`Features/Widget/WidgetViews.swift`) and the widget target compiles them from
there, alongside `Core/Models` and `Core/Localization`. That is what lets the
test bundle render them per locale through `@testable import BabyBloom`.
Moving the file into the widget target breaks this: it has no
`import BabyBloom`, so `.l` and `Color(hex:)` become invisible.

## Where to look next

- [DECISIONS.md](DECISIONS.md) — what was decided and why.
- [NOTIFICATIONS.md](NOTIFICATIONS.md) — the notification catalogue.
- [CLAUDE.md](CLAUDE.md) — working rules for agents in this repo.
- `docs/release/` — Apple Developer and App Store Connect setup.
- `docs/naming/` — how the three brand names were chosen.

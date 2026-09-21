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
(`isQuiz`, progress bar, shared bottom nav); the six after `growth` are info
pages, so inserting or reordering among them touches neither `quizProgress`
nor the nav (DECISIONS 2026-09-01).

Two of those pages show the REAL product rather than a picture of it.
`WidgetShowcasePage` renders `BabyBloomMediumWidgetView` with a constructed
entry. `GrowthShowcasePage` renders `PercentileCard` with the parent's own
answers: `OnboardingGrowthPreview.state(...)` — pure, unit-tested — scores the
birth weight at day 0 through the same
`WHOGrowthStandard.percentileReading(of:correctedBirthDate:isMale:)` the Growth
screen calls, and returns `.invitation` for the two cases with no honest
number (no birth measurement, and a preterm birth before the corrected due
date). The corridor drawing beside it reads the real tables through
`WHOGrowthStandard.weight(atZ:ageDays:isMale:)`; the baby's forward line is
dashed and labelled as a sketch, because it is the one thing the app cannot
know yet. Nothing on either page is seeded, saved or read back.

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

That badge is one component, `LockBadge` (`DesignSystem/Components/`), drawn
identically at every gate. It is `accessibilityHidden`; the words go on the
enclosing button instead, via `View.bbLockedAccessibility(_:)`, which appends
`premium.locked_a11y` as the control's accessibility **value** so VoiceOver
reads "Events, Requires Premium" rather than losing the gate entirely.

Viewing, and deleting, what is already recorded is never gated — recorded data
is not held hostage.

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

## Test hooks — how the app is driven

iOS folds `-key value` launch arguments into `UserDefaults`' argument domain,
so every `@AppStorage` key is drivable from the command line with no product
code: `-hasCompletedOnboarding`, `-appLanguage`, `-appAppearance`.

Three hooks *are* product code, and two of them are gated on
`#if targetEnvironment(simulator)` — not on `DEBUG`, because a
release-optimized QA build is still a real build on a real device and no
shipped binary may carry a path that wipes data or hands out a paid
entitlement:

| Argument | What it does |
|---|---|
| `-BBSkipSplash true` | Skips the splash. `@State`, so it needs a hook. |
| `-BBSeedScenario <name>` | **Simulator only.** Wipes the database and seeds one deterministic fixture (`lowGain`, `healthy`, `sparseLogs`, `newbornWindow`, `newbornStalePair`, `showcase`). An unrecognised name logs the valid ones and calls `fatalError` — a typo fails the run instead of quietly testing against the previous fixture's leftovers. |
| `-BBForcePremium true` | **Simulator only.** Renders the paid branch. Without it, an assertion on a gated card passes whether the paid card works, throws, or renders blank — the half of the app people pay for would be structurally untestable. |

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

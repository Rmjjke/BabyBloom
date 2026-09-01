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
| `GrowthTrend` | Is the baby *sliding* down the chart? Centile-space movement, NICE faltering-growth thresholds. |
| `NewbornWeightLoss` | The first two weeks, measured against birth weight — where a percentile is the wrong and actively frightening instrument. |
| `FeedingAdequacy` | Is the baby getting enough food? Gain + feeds + wet nappies. |

The medical spine of `FeedingAdequacy`: **weight gain is the only trigger.**
Feeds and nappy counts are context and never raise a concern on their own. If
gain sits within the reference the app says nothing, whatever the other two
say. Do not "improve" this into a multi-signal alarm.

`Baby` also carries corrected age for preterm babies, used everywhere except
newborn weight loss — the physiological drop follows delivery, so it is
counted from the actual birth.

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
`refreshEntitlements()` assigns unconditionally from a `.task` that runs on
every appearance and would clobber an override written once at init.
`restorePurchases` deliberately reports off `isEntitled`, so the override
cannot fake a restore.

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

Permission is requested from onboarding's own notifications page (page 7 of
10, before the Generating loader whose last step promises reminders) — never
at launch and never over the Dashboard. That page is the single call site of
`requestPermission`.
`onAppForegrounded()` runs on every `scenePhase == .active`.

## Navigation

`MainTabView` — five tabs: Home, Feeding, Sleep, Diapers, More. Growth,
Recent activity, Events and Profile live under More rather than in the bar;
`RecentActivityView` is the Dashboard's former recent-events section, moved out
whole. The Dashboard's own sections run header → activeTimers → quickActions →
stats → growth → progress, and its Growth header is a `NavigationLink` into
`GrowthView` — the second route to that screen. There is no separate
Settings screen: `ProfileView` carries the baby's details and the app settings
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
| `-BBSeedScenario <name>` | **Simulator only.** Wipes the database and seeds one deterministic fixture (`lowGain`, `healthy`, `sparseLogs`, `showcase`). An unrecognised name logs the valid ones and calls `fatalError` — a typo fails the run instead of quietly testing against the previous fixture's leftovers. |
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

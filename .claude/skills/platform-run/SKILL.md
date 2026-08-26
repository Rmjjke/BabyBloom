---
name: platform-run
description: The canonical recipe for launching BabyBloom on the iOS simulator and driving it — build, install, launch arguments, screenshots, logs. Consumed by desk-task run-and-look checks and e2e-tests; not an entry point.
---

# platform-run — BabyBloom on the iOS simulator

executor: agent

## The short version

    # 1. build (see the platform-build skill for the full invocation)
    xcodegen generate
    xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom \
      -configuration Debug \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -derivedDataPath .superpowers/build build

    # 2. install onto the booted simulator
    xcrun simctl install booted \
      .superpowers/build/Build/Products/Debug-iphonesimulator/BabyBloom.app

    # 3. launch straight into the main tabs, in English, no splash
    xcrun simctl launch booted com.nenita.app \
      -BBSkipSplash true -hasCompletedOnboarding true -appLanguage en

Bundle id `com.nenita.app`. No entitlement re-sign is needed for the
simulator — `simctl install` accepts the Debug-signed `.app` with its
embedded `BabyBloomWidget.appex` as built. (Verified 2026-08-24.)

## Launch arguments — the state hooks

iOS folds `-key value` launch arguments into UserDefaults' argument domain,
so every `@AppStorage` key in the app is drivable from the command line with
no product code at all. The ones that matter:

| argument | effect |
|---|---|
| `-hasCompletedOnboarding true` | skip the 8-page onboarding, land on the Dashboard |
| `-appLanguage en` \| `ru` \| `es` | pin the UI language, so selectors do not depend on the device locale |
| `-appAppearance light` \| `dark` \| `system` | pin the theme |
| `-BBSkipSplash true` | skip the branded splash |
| `-BBSeedScenario lowGain` \| `healthy` \| `sparseLogs` | **simulator only** — wipe the database and seed one deterministic growth scenario (see `.desk/app-map.md` for what each produces) |
| `-BBForcePremium true` | **simulator only** — render every Premium-gated card as the real thing instead of its `LockedInsightCard` placeholder |

`BBSkipSplash`, `BBSeedScenario` and `BBForcePremium` are the only three backed
by product code (`BabyBloomApp.showingSplash`, `SeedScenario.seedIfRequested`
and `SubscriptionManager.isPremium`) — the splash is `@State`, not
`@AppStorage`, and neither the seeder nor the entitlement is a stored default.
Without `-BBSkipSplash` every cold launch costs ~5s (SplashView.play: 4.6s +
a 0.4s fade). With it the Dashboard is up in under 3s.

Omit an argument to exercise the real path: no `-hasCompletedOnboarding`
means the flow gets the genuine first-run onboarding.

`-BBSeedScenario` is the exception to that paragraph's spirit — it IS product
code, in `BabyBloom/Core/Models/SeedScenario.swift`, gated on
`#if targetEnvironment(simulator)` so a device build contains no seeding path
at all. It runs at most once per process, and the wipe is unreachable without
the argument (verified 2026-08-26: relaunching without it left the previous
scenario's data untouched). Under Maestro the value goes in the same
`arguments:` block with the dash spelled out:

    "-BBSeedScenario": "lowGain"

> ### ⚠️ Run seeded flows only on a simulator that is NOT signed into iCloud
>
> Seeding **wipes the database first** — every `Baby` and every entry. The
> simulator gate keeps that out of shipped binaries; it does not make it local.
> The model container is `cloudKitDatabase: .automatic`, so on a simulator
> signed into a real Apple Account the wipe deletes those records from **that
> account's private CloudKit database** — the ones the person's own phone is
> syncing — and then pushes the fixture baby out in their place. There is no
> undo.
>
> Before the first seeded run: Settings ▸ [your name] ▸ Sign Out on the
> simulator, or pick a simulator that was never signed in. A simulator with no
> account does not sync at all, which is the normal state for a test run.

**Spell the name right, and it will tell you if you did not.** The names are
case-sensitive (`lowGain`, `healthy`, `sparseLogs`). An unrecognised value logs
a fault naming it and the valid ones, then calls `fatalError` — the app dies on
launch in every build configuration (`assertionFailure` would vanish under
Release), so a typo fails the flow instead of quietly running it against the
previous flow's leftover data. A successful seed logs `Seeded scenario <name>.`
under subsystem `com.nenita.app`, category `SeedScenario`, the cheapest way to confirm
which fixture a run's assertions actually saw:

    xcrun simctl spawn booted log stream --predicate 'subsystem == "com.nenita.app"'

## Premium without a purchase

`-BBForcePremium true` is the other piece of product-code scaffolding, in
`SubscriptionManager`, gated on `#if targetEnvironment(simulator)` for the same
reason `SeedScenario` is: `DEBUG` is false in a release-optimized QA build,
which is still a real build on a real device, and no shipped binary may carry a
path that hands out a paid entitlement.

**Why it has to exist.** `GrowthView` chooses between `FeedingBreakdownCard` and
a `LockedInsightCard` built with the SAME title key (`breakdown.title`). Without
a way to force the paid branch, an e2e assertion on that title passes whether
the paid card works, throws, or renders blank — the half of the app people pay
for would be structurally untestable.

**Why it is not a one-liner.** `refreshEntitlements()` assigns unconditionally
and `MainTabView` calls it from a `.task` on every appearance, so an override
written once at init is clobbered before Growth is ever reached. It is therefore
read on every access: `isEntitled` stays the StoreKit truth and `isPremium`
computes `isEntitled || override`. `restorePurchases` deliberately reports off
`isEntitled`, so the override cannot fake a restore.

    "-BBForcePremium": "true"

Verified 2026-08-26 by launching the same seeded scenario twice, changing
nothing but this argument: with it the Growth screen renders the breakdown
card's reference lines and its "This is an observation, not a diagnosis"
disclaimer and no card reads "Available with Premium"; without it the same
screen shows the lock, the teaser and no disclaimer.

## Clean state

`simctl uninstall` wipes the app container. The SwiftData store lives in the
App Group container `group.com.nenita.app`, which **survives** an app
uninstall — erase the whole device when a flow needs a genuinely empty
database:

    xcrun simctl uninstall booted com.nenita.app        # app only
    xcrun simctl erase <udid>                           # everything, needs shutdown first

CloudKit sync is `.automatic`; a simulator without an iCloud account simply
does not sync, which is the normal state for test runs — and the state
`-BBSeedScenario` requires, since its wipe would otherwise reach a real
account's private database (see the warning above).

## Looking at the result

    xcrun simctl io booted screenshot shot.png
    xcrun simctl list devices booted          # which simulator is live
    xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "nenita"'

`iPhone 17` is the working default on this machine. `simctl` has no tap or
swipe — any interaction goes through Maestro (see the tool-maestro skill).

## Traps

- The splash is not skippable by waiting a fixed 5s and hoping: the fade is
  animated and the transition lands ~5.0s in. Use `-BBSkipSplash true` for
  every flow that is not specifically testing the splash.
- A stale install silently keeps old localization JSONs. After changing
  anything under `Resources/Localization` or `WidgetResources`, reinstall —
  do not just relaunch.

## Driving the app with Maestro

Maestro is NOT on the PATH by default on this machine (Homebrew is blocked by
outdated Command Line Tools — the full story and the manual install are in
`.desk/knowledge.md`). Every run needs:

    export JAVA_HOME="$HOME/.local/opt/jdk-21.0.12.1+1-jre/Contents/Home"
    export PATH="$HOME/.maestro/bin:$JAVA_HOME/bin:$PATH"
    export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

    maestro test .desk/tests/SMOKE-main-tabs.yaml

Inside a flow the same launch arguments apply, but Maestro needs the dash
spelled out in the key and `stopApp: true` alongside `clearState: true`:

    - launchApp:
        clearState: true
        stopApp: true
        arguments:
          "-BBSkipSplash": "true"
          "-hasCompletedOnboarding": "true"
          "-appLanguage": "en"

Tabs are tapped through `childOf: {text: "Tab Bar"}`; which tab is open is
asserted via the `tab_*` ids. See `.desk/app-map.md`.

**Name the device, and make sure nothing else is on it.** `maestro test` with
no `--device` picks a booted simulator for you, and more than one is usually
booted here:

    maestro --device <udid> test .desk/tests/

On 2026-08-26 four separate red runs — a missed tap, a rotated screenshot, two
`Device became unreachable` drops — turned out to be a second party driving the
same simulator (a different app came to the foreground mid-flow, in landscape),
plus a `maestro test` process left running since 2026-08-24 that was still
holding the XCUITest driver. Killing the stale process and moving to a
simulator created for the run turned an every-other-run flake into ten green
flows in a row. Before blaming a flow, check:

    ps aux | grep '[m]aestro.cli.AppKt'      # a hung run from a previous session
    xcrun simctl list devices booted         # who else is booted
    xcrun simctl create BB-e2e-iPhone17 "iPhone 17"   # a device of your own

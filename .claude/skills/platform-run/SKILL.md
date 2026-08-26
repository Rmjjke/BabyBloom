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

`BBSkipSplash` and `BBSeedScenario` are the only two backed by product code
(`BabyBloomApp.showingSplash` and `SeedScenario.seedIfRequested`) — the splash
is `@State`, not `@AppStorage`, and the seeder is not a stored default at all.
Without it every cold launch costs ~5s (SplashView.play: 4.6s + a 0.4s
fade). With it the Dashboard is up in under 3s.

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

## Clean state

`simctl uninstall` wipes the app container. The SwiftData store lives in the
App Group container `group.com.nenita.app`, which **survives** an app
uninstall — erase the whole device when a flow needs a genuinely empty
database:

    xcrun simctl uninstall booted com.nenita.app        # app only
    xcrun simctl erase <udid>                           # everything, needs shutdown first

CloudKit sync is `.automatic`; a simulator without an iCloud account simply
does not sync, which is the normal state for test runs.

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

---
name: platform-test-runner
description: How to run BabyBloom's existing XCTest suite and report the results. Consumed by desk-task; not an entry point, and not about writing tests.
---

# platform-test-runner — BabyBloom

executor: agent

## Run the whole suite

    xcodebuild -project BabyBloom.xcodeproj \
      -scheme BabyBloom \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -derivedDataPath .superpowers/build \
      test

The `BabyBloom` scheme's test action is wired to the `BabyBloomTests`
bundle (unit tests only — there is no UI-test target).

## Run one test class or method

    -only-testing:BabyBloomTests/GrowthTrendTests
    -only-testing:BabyBloomTests/GrowthTrendTests/testCentileFall

## What is in the suite

`BabyBloomTests/` — growth/WHO standards (`WHOGrowthStandardTests`,
`GrowthTrendTests`, `WeightVelocityTests`, `NewbornWeightLossTests`,
`CorrectedAgeTests`), notifications (`NotificationManagerTests`), export
(`ExportGeneratorTests`), and a visual render dump (`GrowthCardRenderDump`)
that writes card snapshots across locales and themes.

## Reporting

Report the counts (`Executed N tests, with M failures`) and, for each
failure, the test name plus the assertion message and its `file:line`.
Never claim green without the summary line in front of you. A build failure
inside a test run is a BUILD failure — say so and hand it to
`platform-build`, do not report it as a test failure.

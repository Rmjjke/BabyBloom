# Decisions

What was decided, and **why**. A decision without its reason cannot be safely
revisited — someone will undo it in a year, for good-looking reasons, and
rediscover the problem it solved.

Newest on top. Add an entry when a choice will outlive the task that made it:
an architecture direction, a convention, a rejected approach, a constraint
that is not visible in the code. Mechanics belong in
[ARCHITECTURE.md](ARCHITECTURE.md); this file is the reasoning.

Working-process rules (git flow, verification, task cards) are not here — they
live with the workflow in `.desk/`.

---

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

---

## 2026-08-28 — Every Dynamic Type scale goes through `BBTheme.Typography`

A bare `UIFontMetrics.scaledValue(for:)` anywhere in the app is a defect, and
the rule covers layout metrics as much as fonts.

**Why.** The form with no trait collection reads the *device* content size and
ignores the SwiftUI environment. So `.dynamicTypeSize(...accessibility2)` at
the app root — which only sets the environment — capped nothing it sized: a
card measured 774pt at AX5 against 442pt at AX2, under a ceiling that was
doing nothing. `NutritionSection`'s icon column was a second, independent
instance of the same call, and it kept growing after the text had stopped.

**Consequences.** The ceiling lives in one constant,
`Typography.maxContentSizeCategory`, from which `BabyBloomApp` derives its
modifier, so the two cannot drift apart again. The AX2 ceiling itself is a
deliberate MVP compromise — raising it means per-screen relayout across the
app and is a separate task, not a constant edit. And a render dump above AX2
now produces the AX2 image: the filename records the device setting, not the
rendered size.

## 2026-08-27 — Prices, savings and trial lengths are never written in source

The paywall derives all three from `Product` — `displayPrice` and
`subscriptionInfo?.introductoryOffer`.

**Why.** The products are configured in 175 territories. Any constant in the
source is correct in one of them and wrong in the rest, and a hardcoded
percentage turns a price change in App Store Connect into a screen
advertising a discount it does not give. The 52% yearly saving is arithmetic
over two fetched prices, not a number someone typed.

## 2026-08-25 — Weight gain is the only trigger in `FeedingAdequacy`

Feeding frequency and wet-nappy counts are context. If gain sits within the
reference, the app says nothing, whatever the other two signals say.

**Why.** This is the clinical spine of the feature, not a tuning choice. A
multi-signal alarm invents problems out of secondary signs and frightens
parents who are already frightened; the reference tables exist precisely so
the app can stay quiet when it should. Do not "improve" this into an
any-signal-fires rule.

## 2026-08-25 — Entries carry a `baby` link, but nothing scopes queries by it

Every entry type has a `baby` relationship with a cascade delete rule, and no
`@Query` in the app filters on it.

**Why.** The link exists so `Baby`'s cascade rules mean something — without it
deleting the baby left orphaned history. Scoping is a separate concern: the
app is single-baby by construction (onboarding creates one, every screen reads
`babies.first`). Multi-baby support is therefore not a model change but a
change to every query in the app, and pretending otherwise would leave a
half-migration nobody can finish safely.

## 2026-08-26 — Test hooks that wipe data or grant entitlement gate on `targetEnvironment(simulator)`, never `DEBUG`

`-BBSeedScenario` and `-BBForcePremium` are compiled out of anything but a
simulator build. (Decided and verified during feeding-weight-link; reached
`main` inside PR #17's squash, `76f1ac4`, not under its own commit.)

**Why.** `DEBUG` is false in a release-optimized QA build, which is still a
real build on a real device. No shipped binary may carry a path that wipes a
person's data or hands out a paid entitlement. The hooks are product code and
that is accepted: without `-BBForcePremium`, an assertion on a gated card
passes whether the paid card works, throws, or renders blank — the half of the
app people pay for would be structurally untestable.

## 2026-08-24 — The `appLanguage` choice travels through the App Group

`LocalizationManager.setLanguage` mirrors the choice into the suite
`group.com.nenita.app`; resolution order is launch argument → App Group →
this process's own defaults → device default.

**Why.** The widget runs in its own process and cannot see the app's
`UserDefaults.standard`. The legacy step keeps upgrading users' choice. The
launch argument must be read explicitly via `volatileDomain(forName:)`,
because the argument domain's precedence applies only within
`UserDefaults.standard` — the App Group is a separate store and would
otherwise shadow the `-appLanguage` argument that e2e flows depend on.

## 2026-08-09 — Brand is per-language, not global

Bitty (en) / Ночка (ru) / Nenita (es). App Store Connect app name
"Bitty: Baby tracker", app id 6799234275, primary locale en-US.

**Why.** A tender, native-sounding name in each language is the point of the
product's voice; the selection criterion was tenderness of sound, not legal
cleanliness or global recognisability. One global name was explicitly
rejected.

**Mechanism.** One token `brand.name` in `en/ru/es.json` and the widget
copies, plus per-locale `Resources/{en,ru,es}.lproj/InfoPlist.strings` for
`CFBundleDisplayName`. Russian copy must decline the name («в Ночку»).

## 2026-08-09 — Bundle ID, App Group, iCloud container and target names stay `com.nenita` / `BabyBloom`

**Why.** They are baked into existing stores; renaming them means data loss
for anyone already using the app. The cosmetic mismatch with the brand names
is accepted permanently — do not propose a "cleanup" rename.

## 2026-07-21 — The palette is fully tokenized in the Asset Catalog

All colours are colorsets with light and dark variants, reached through
`BBTheme.Colors`.

**Why.** Re-theming used to be a source-wide edit. It is now: colorset edits,
the two splash PNGs, and the hex constants in `ExportGenerator` — the PDF
renderer cannot read the Asset Catalog, so it is the single accepted
duplication.

**Also decided here.** The splash plays on every cold launch: no
`hasShownSplash` flag, and the launch screen is colour-only. Splash art is the
design PNG with its text band stitched out (`docs/design/*-notext.png`).

## 2026-07 — All UI strings go through the JSON `LocalizationManager`

`NSLocalizedString` is called exactly zero times.

**Why.** One JSON per language keeps the three locales and the widget's
physical copies in parity, and makes adding a language a mechanical change the
compiler can check (`SupportedLanguage` switches are exhaustive). The dead
`Localizable.strings` files were deleted in PR #14; the three
`InfoPlist.strings` remain live and drive the per-language app name.

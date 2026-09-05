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

## 2026-09-05 — The word a parent reads is split from the gate that fires

`FeedingAdequacy.Signal` keeps its three cases and its collapse of an
above-reference gain onto `.within`. Every parent-facing surface renders
`StatusWord`, which has four.

**Why.** The collapse is the breakdown gate and must not change (2026-08-25);
it is also the wrong vocabulary, and build 11 showed what that costs: the
Dashboard printed a +10267 g/week gain as "within the reference" in green
while the Growth screen, on the same data, said "above" it. A parent who sees
two verdicts on one number stops trusting both. Widening `Signal` would have
been the smaller diff and would have put the gate one `case` away from firing
on a thriving baby. Keep them separate.

## 2026-09-05 — Growth verdicts are measured against RECENT history, and against the weighing's own date

Three rules settled together, all of them about which moment a number
describes:

- `WeightVelocity` divides by real elapsed duration; whole days stay a label.
  Truncation only ever rounds the denominator down, so it only ever overstates
  gain — the one direction that can suppress the low-gain signal the feature
  exists for.
- `GrowthTrend` bounds its REFERENCES — peak and starting point — to the last
  180 days, and never its evidence gates, which read the whole scorable
  history. Unbounded, ordinary regression to the mean becomes a flag that no
  later weighing can ever clear; bounded the other way, a toddler weighed twice
  a year would have a card reading "not enough data" forever. One floor keeps
  the window usable — it always admits at least the two most recent weighings,
  however far apart, because those two are the current trajectory by definition
  — and beyond that **nothing reaches past the bound to find a reference**.
  That last rule is what keeps the displacement property true: every reference
  is inside the window or among the two newest readings, so the next weighing
  displaces it, which is precisely what the unclearable flag was not.
  A verdict also has to describe four weeks, and when the readings inside the
  bound cannot span that — a parent whose only recent weighings are days apart
  — the answer is `insufficientData`. Widening backwards to reach the span was
  tried and reverted: it let a tight recent cluster pull in a peak from a year
  earlier and flag an ordinary catch-down, unclearably, until the cluster grew
  four weeks wide.
  The remaining cost is narrower than "180 days": because of the
  two-most-recent floor the effective window is longer than the bound whenever
  weighings are sparse, so a fall between two readings 200 days apart IS
  reported. What escapes is a fall spread across three or more weighings, each
  step small enough that no eligible peak inside the window is a full threshold
  above the latest — where the threshold is `thresholdSpaces`, 1, 2 or 3 spaces
  by birth centile, not a flat two. That shape is outside NICE's scope, whose
  thresholds describe weeks to months. The bound is a judgement, not a
  published threshold — retune it knowingly.
- A single-value percentile is scored at the age on the WEIGHING date. Scored
  at today's age it drifts downward every morning the app is opened, which is
  movement the parent did not cause and cannot undo.

**Why record it.** Each of these is a place where the obvious implementation is
subtly wrong in the reassuring direction, and each was written the obvious way
first.

## 2026-09-05 — An upward centile crossing is reported, on a flat threshold, measured from the start

`GrowthTrend.crossingUp(spaces:)` fires at a rise of two centile spaces or
more, with `upwardCrossingSpaces` a flat 2 rather than `thresholdSpaces`, and
the rise measured from the first reading in the window rather than from its
lowest.

**Why report it at all.** The detector is downward-only by clinical design and
stays that way — a fast climb raises no flag. But its `.stable` case was
returned for ANY non-fall, and the card renders that as "Holding its centile
channel" behind a green tick. A baby that went from the 50th centile to the
99th was told it was holding its channel. Downward-only scope is defensible;
the wording claiming a bidirectional check was not.

**Why a flat two.** NICE scales the fall threshold by birth centile because a
baby born small has less room to fall before it matters. That argument has no
upward counterpart — nothing about being born on the 95th centile makes a rise
more or less worth naming — so borrowing the scaling would have been symmetry
for its own sake, and would have made a baby born small announce every ordinary
catch-up week.

**Why from the start, not the trough.** A dip that has climbed back to its
opening centile has crossed nothing, and measuring from the trough would
announce a recovery as a rocket — it would also have contradicted the existing
"a recovered dip is stable" rule one case away. There is deliberately no mirror
of the fall's "latest is the extreme" guard either: the from-start measurement
already collapses a recovered dip to about zero, while requiring the latest
reading to be the highest handed the green tick back to any baby whose final
weighing wobbled a little below the one before it.

## 2026-09-05 — The doctor-facing export carries measurements, not verdicts

`ExportGenerator` writes raw growth rows — date, weight, height, head — and no
percentile, gain band or centile-trend verdict. Verified, not merely observed:
the file references none of `Core/Growth`.

**Why.** A clinician reading the PDF has better instruments and their own
chart; an app's verdict in that document would be a second opinion nobody
asked for, printed with the authority of a record. If a verdict is ever added,
it must come from these same functions and no others — a second implementation
inside the exporter is how two surfaces start disagreeing.

`FeedingRhythm` is the other accepted exception in this area: it reads
CHRONOLOGICAL age at its call sites, unlike every growth reference. Left as
is, because it schedules a reminder cadence rather than reaching a verdict,
and a reminder is not measured against a table.

## 2026-09-05 — A count above its reference is never styled as an alarm

Nappy and feed references are floors with no ceiling. Exceeding one is
reassurance, so no surface may render it red, flagged or triangled; the
Dashboard's rings and `DiaperView`'s norm card are neutral above target and
neutral below it.

**Why.** `DiaperView` turned red with a warning triangle for a baby who wet
MORE nappies than the norm — clinically inverted, and in the one domain where
this app has to stay calm. The same reasoning covers `WeightVelocity.Band
.above`, which takes the neutral primary tint rather than the green "within"
tick: fast gain is not a worry, and it is not an achievement either.

**Consequence.** The palette gained `BBAlert`, and red became a token instead
of the `#E05A5A` literal repeated across the growth cards. Having exactly one
name for it is the point: the colour now has a stated meaning — the growth
flags and the tails of the percentile chart, never a count — and a fourth
surface reaching for red has to justify itself against that sentence rather
than copy a hex code. Re-theming still means editing colorsets; there is now
one more of them.

## 2026-09-02 — Advancing on entitlement belongs to the paywall's HOST, not to its purchase button

`PlanPickerSection` has no `onPurchased` callback. `PremiumPage` observes
`store.isPremium` and calls `onPurchased()` from one place; `PaywallView`
observes nothing and navigates nowhere.

**Why.** The callback used to fire on the `isEntitled` TRANSITION inside the
button's closure — a deliberate fix so an already-entitled user who cancelled
the sheet did not advance. It was right about its own bug and wrong as the
ONLY advance path. Entitlement reaches the app four ways: a purchase, a
restore, `Transaction.updates`, and simply being subscribed before the screen
opened. A button closure sees the first. For the fourth — the case the owner
hit on build 9, with a sandbox subscription active — buying an owned product
raises StoreKit's "You are currently subscribed" alert and changes no state at
all, so there was no transition to fire on and no way out of onboarding but
the X.

**Also decided here.** Nothing in onboarding asked StoreKit who the user was,
so the paywall branched on an `isEntitled` that was `false` because it had
never been read. `hasResolvedEntitlements` makes that distinction explicit and
the selling half waits for it: a paywall must never sell on an unresolved
answer. And `purchase()` re-reads entitlements on `.userCancelled` and on a
thrown error, not only on success — a purchase that did not happen still says
nothing about what the Apple ID already owns.

**Consequence.** A new paywall host must observe `isPremium` itself. That is
the intended cost: the alternative — a callback that looks like it covers
purchase — is the arrangement that shipped this bug.

---

## 2026-09-01 — The onboarding loader runs after the permission ask, and the commitment CTA sits on the widget page

Onboarding order: Welcome → Name → Birth → Feeding → Growth → Fact →
Notifications → Widget → Generating → Paywall. «Создать мой трекер»
(`onboarding.widget.cta`, formerly `onboarding.fact.cta`) is the WIDGET page's
button; the Fact page ends with a plain `button.next`.

**Why.** `GeneratingPage`'s last step says smart reminders are being
configured — backwards while it ran before the permission ask (claiming a
permission that hadn't even been offered yet), so notifications had to move
ahead of the loader. The move only fixes the claim for a parent who taps
«Включить уведомления»: it is now honest for that path, and merely optimistic
— not backwards — for one who taps «Не сейчас», since the step still runs
without the permission it describes. With the loader last, its "your tracker
is ready" crescendo lands directly on the paywall instead of being spent on
two more info pages. The commitment CTA follows the loader it triggers: it
now sits on the last page before it, which also buys spacing between the
permission ask and the money ask (widget page + ~5s loader).

Consequence for anyone adding a page: the four pages after Growth are all
non-quiz, so `isQuiz` / `quizProgress` and the shared bottom nav are untouched
by any reordering among them — only the enum's case order defines the flow.

## 2026-09-01 — A permanent Growth teaser, and a gate on creating events only

The Dashboard's Growth section always shows the latest weight and
`FeedingAdequacy`'s calm word for gain. The paid half — the weekly figure and
the percentile — sits behind a `LockedInsightCard` that never goes away. Event
CREATION asks for Premium at every entry point; viewing and deleting existing
events stay free.

**Why.** A free-first-days window was the alternative, and rejected: a section
that vanishes after two days reads as breakage, in the one domain where the
app must never frighten. A parent who has grown used to a calm word about
their baby's weight and then finds it gone does not conclude "my trial
expired". The permanent teaser is honest about what is paid without ever
withdrawing what was shown.

Deletion in particular stays free because a paywall in front of it would hold
a person's own records hostage — the one thing a tracking app must not do. The
same reasoning is why the Growth screen's newborn red flags are free.

**Consequence.** Every creation path on the Events screen funnels through one
gate (`addEvent(_:)`): the four quick-add tiles wrote a `CustomEvent` straight
to the context, and left free they would have walked around the padlock two
rows above them. Adding a fifth tile means going through that function, not
around it. Each gated control carries a padlock badge — a control that looks
free and answers with a paywall is a bait-and-switch.

The free line reads `assessment.gain` and nothing else, so the 2026-08-25 rule
holds on the Dashboard too. `DashboardGrowthSummary` is a pure function for
exactly that reason: the rule is testable without a simulator.

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

## 2026-09-01 — One brand badge, one onboarding ground

`BBLogo` is never placed raw. Every appearance goes through `BrandMark`,
which clips the square app-icon art to a circle so its own opaque background
becomes the badge fill.

**Why.** The art was dropped raw into four places at four sizes; each read as
a screenshot of the app icon rather than a mark, and the four drifted apart
independently. One component makes the badge a decision instead of an
accident, and it retired the last wreath glyph from the paywall hero along
the way.

**Also decided here.** The onboarding backdrop is rendered ONCE, by
`OnboardingView`, as `OnboardingBackground` behind the page switcher — so
onboarding pages must not paint an opaque ground of their own, or they punch
a hole in it. Any page added to the flow inherits the backdrop by doing
nothing. `OnboardingBackground` drifts on a `repeatForever` animation, which
means Maestro's `waitForAnimationToEnd` has nothing to settle on during
onboarding; no flow uses it there today, and none should start.

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

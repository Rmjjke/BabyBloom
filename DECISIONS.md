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

## 2026-09-21 — Onboarding shows the ONE real number it has, and labels everything else a sketch

A `growthShowcase` page sits between Fact and Notifications (eleven pages now).
It renders `PercentileCard` — the Growth screen's own card, extracted, not
copied — fed by the parent's own answers: the birth weight scored at day 0
through `WHOGrowthStandard.percentileReading`, via the pure, unit-tested
`OnboardingGrowthPreview`. Beside it, a WHO corridor drawn from the real LMS
tables, the baby's real point on it, and a DASHED forward line captioned
«Набросок — настоящая кривая появится по вашим взвешиваниям». Three bullets
name only capabilities that exist today.

**Why show rather than tell.** The growth engine is the product's strongest
claim and the one a parent cannot evaluate from a sentence. `WidgetShowcasePage`
already established the form — render the real view with constructed data — and
this page is the same move with data that is not constructed at all. The parent
recognises their own baby's weight in it, which no mock-up can buy.

**Why the card is extracted and not duplicated.** A second hand-kept copy of a
card that states a clinical figure would drift, and this project has paid for
that class of drift before (the build-11 contradiction between two surfaces
reading one number). One view, one call site each. Proved pixel-equivalent at
the extraction: the pre-split private markup and the shared view rendered
byte-identical PNGs across three locales, both schemes and both tails.

**Why extremes are neutral HERE and red on the Growth screen.** Below the 3rd
or above the 97th, `tone: .neutralOnly` swaps `BBAlert` for the neutral
`textPrimary`. Nothing is withheld — the band label still reads «< 3-й» in
full, and the ring's badge still names the side of the chart; only the alarm
is. On the Growth screen a red reading arrives with its explainer, the chart,
the history and the copy telling the parent to ask someone qualified. Three
minutes into onboarding there is none of that, and a parent who has just typed
their newborn's discharge weight is the last person who should meet a red
number they cannot act on. This is the 2026-09-05 rule about colour one step
further: the word carries the finding, the colour only ever carries urgency,
and there is no urgency the app can serve on this page.

**Why a forward line at all, and why dashed.** A flat corridor with one dot
does not read as a growth chart, and the page has to show what the screen
becomes. Drawing invented weighings would be the one unforgivable version — the
parent would recognise it later as a promise the app never made — so the line
follows the baby's own centile, is dashed, and is captioned as a sketch. The
corridor underneath is genuinely the WHO standard, which is why
`WHOGrowthStandard.weight(atZ:ageDays:isMale:)` was added rather than a
plausible curve drawn in the view.

**The showcase may only draw what the app draws — so the weight chart gained
the corridor.** The first cut of this page shipped a WHO corridor that existed
nowhere else: `WeightChartView` was an index-axis polyline of the baby's own
weights, and `weight(atZ:)` had exactly one caller, the sketch. The dashed line
was honestly labelled and the corridor was not — a caption saying "the real
curve appears from your weighings" is a promise about the CHART, and the chart
had no bands. The picture is the promise. Rather than delete the corridor from
the preview, the chart was made to match it: an age axis (which the band
requires, and which fixes the old chart's own distortion of unevenly spaced
weighings), the shared `WHOCorridor` sampler, and one legend wording in both
places. The rule this leaves behind: **a showcase page may render the real view
with real data, or a clearly labelled sketch of a view that exists — never a
picture of a feature.**

**Why «не помню точно» and a pre-due-date preterm birth get the SAME
invitation.** They are different causes with one honest answer: there is no
number yet. Splitting them would mean explaining prematurity and the WHO
tables' starting point on an onboarding page, to a parent whose baby may be in
intensive care. The invitation names the action that produces a number and says
nothing else; the sketch stays, so the page still shows what it is for.

## 2026-09-20 — The birth-day measurement follows the birth date

Correcting the birth date in `BabyProfileEditSheet` moves every growth entry
dated on the OLD birth DAY to the new birth date, and nothing else. The picker
is bounded at the day BEFORE the earliest non-birth-day measurement (or today,
whichever is earlier), and `BirthDateChange.commit` clamps the stored value to
that same bound. The rules live in `BirthDateChange`, pure and pinned by tests.

**Every field on that sheet is now buffered until Save.** Name, birth date,
gender, feeding type and the photo were written to the model as the parent
touched them, so Cancel discarded nothing but the sliders, and Return in the
name field committed a rename. Nothing on this sheet is an action in its own
right — it is one form with one commit point — so there is no field left
deliberately write-through.

**Why history moves at all, when the 2026-09-05 one-way rule says profile
corrections never touch it.** It is not the same kind of edit. Those entries
ARE the birth measurement — `OnboardingBabyBuilder` creates the first entry
dated AT `birthDate`, so the entry and the field are two recordings of one
fact, and correcting one without the other makes them disagree. Moving the
birth date forward used to strand that entry BEFORE the birth, where
`NewbornWeightLoss.analyse` drops it as bad data and a preterm baby's
`correctedBirthDate` can strand it further still: the parent fixes a typo and
silently loses the first point on the chart and the anchor the whole newborn
window is measured against. Every other weighing happened when it happened and
is left alone, which is the one-way rule still holding for the rest.

**By calendar DAY, not by instant.** Onboarding's own entry matches the birth
instant exactly, but a parent who typed the discharge numbers in by hand
picked the day and got the sheet's clock. A measurement recorded on the birth
day is a birth measurement whatever its time. The day is the DEVICE's, so far
enough travel can move an entry off the birth day; `BirthDateChange` documents
why that is accepted rather than fixed with a stored day key.

**Why the picker is bounded, and why it is also clamped on Save.** A birth
date later than a real weighing dates that weighing before the birth, and
re-dating cannot repair it — a day-3 weighing is not a birth measurement and
must not be moved. The bound refuses that state; the clamp is needed because
the range is enforced in days while the value is an instant, so a selection on
the bound's own day keeps the old time of day and could otherwise land past the
bound. Same two-guard shape as the future-dated weighing (2026-09-05), and the
reason both live in `commit` rather than in the view: a rule the view owns
privately is a rule no test can reach.

**Why the first weighing's whole DAY is out, so "born the day of the first
weighing" is not selectable.** Membership is by calendar day — that is what
makes a hand-entered birth measurement follow the date — so a birth date
landing on the first weighing's day would reclassify that weighing as a birth
measurement, and the NEXT edit would silently drag a weighing the parent never
touched. Refusing the day closes that class instead of leaving it one edit
away. The cost is real but small and recoverable: a parent whose baby really
was weighed again on the day of birth re-dates or deletes that row explicitly
— an edit they can see, on the row they mean — and the birth date then follows.

**No migration, again deliberately** — this changes nothing already stored.
Existing installs keep their dates until a parent edits the birth date, which
is the only moment the app learns the old one was wrong.

## 2026-09-05 — Onboarding asks for the measurements AT BIRTH, and dates the first entry there

The measurements page is titled "Height and weight at birth" and its answer
does two jobs: it fills `Baby.birthWeightKg` and becomes a `GrowthEntry` dated
at `Baby.birthDate`. The separate optional birth-weight toggle on the birth
page is gone; the gestational-weeks toggle stays. The page carries an
«I don't remember» opt-out, which leaves the field nil and creates no entry.

**Why one question instead of two.** The toggle was optional and off by
default, so most parents walked past it — and a nil birth weight silently
switches off `NewbornProgressCard`, the free safety card, AND the newborn
window gate below. The app was asking the same number twice and usually
getting it once. Asking for the birth measurements outright is also the
question a parent can actually answer in week one: the numbers are on the
discharge record, whereas "weight today" needs scales they may not own.

**Why the entry is dated at the birth.** It is what the number IS. Dating it
today stamps a birth weight onto day 5 and makes the physiological dip look
like a week of no gain measured from a point the baby had already left. It
also gives every baby a real first point on the chart from day one.

**Why prematurity stays optional.** It is a fact some parents genuinely do not
have, and nil means "unknown" everywhere downstream.

**Why the birth weight kept an opt-out too — the reversal of the reversal.**
Removing the toggle removed a real protection along with the duplicate
question: the deleted comment on it said a parent who does not know must be
able to walk past without a made-up number being stored, and that is still
true. A slider cannot express "I don't know"; it always holds a number, and
the default is 3.5 kg. So a mandatory slider does not collect an answer from
the parent who has no discharge record — it invents one, and stores the
invention twice: as the profile baseline the 10%-loss flag is measured
against, and as the first point on the chart, which every verdict measured
over a pair reaching back to it then inherits.

What changed is only WHERE the question is asked and how it reads. The old
toggle was an off-by-default aside on a page about dates and gender, so the
common answer was silence. The page now asks the question outright and the
opt-out is a deliberate second answer, so nil means "this parent told us they
do not know" rather than "this parent did not notice the question".

That also makes the profile editor's optional toggle consistent rather than
contradictory: nil is a legitimate answered state on both surfaces, and
`BabyProfileEditSheet` is left exactly as it was.

**Clearing the birth weight in the profile turns the newborn instrument off,
and that is deliberate.** No `NewbornProgressCard`, and no gain deferral —
the same state as never having known it, and the same state as an install
from before this feature. Deferring a gain verdict with nothing put in its
place would be worse than the ordinary rules, so the gate requires a birth
weight for exactly the reason the card does.

**No migration, deliberately.** Existing installs keep their first entry's
original date and whatever `birthWeightKg` they have. A migration would have
to guess that an old first entry "meant" the birth — and for a parent who
installed at four months it plainly did not, so re-dating it would move a real
weighing to a date it never happened on and change every verdict computed from
it. The one-way rule has the same shape: `BabyProfileEditSheet` writes
`birthWeightKg` without touching history, because a correction to the profile
is not a new weighing.

## 2026-09-05 — During the newborn window, no surface reports a weight-gain verdict

`NewbornWeightLoss.gainDeferral(birthWeightKg:birthDate:measurements:now:)` is
the single gate. While it returns non-nil, `FeedingAdequacy.assess` returns
`Signal.deferredToNewbornWindow` instead of a band-derived verdict, the gain
card prints a deferral, the Dashboard's free line prints the calm word, and
`growthGainLow` cannot fire. The first-weeks card is the verdict for this
period.

**The word a parent reads names the period, it does not point at a card.** It
started as «см. «Первые недели»», which is true only on the Growth screen
while the window is open — the Dashboard has no such card, and neither does
the Growth screen once the window has closed on a stale pair. A one-line
status has no room to say which; the gain card, which has room for a sentence,
is the surface that says where the verdict lives.

**Why.** A newborn loses 5–10% of its birth weight over the first days. Every
WHO velocity reference starts well above zero, so a gain measured across that
dip is below the reference by construction — the app would tell a parent their
baby is gaining too slowly for doing exactly the normal thing, in the fortnight
they are least able to hear it calmly. `NewbornWeightLoss` exists because a
growth curve is the wrong instrument here; the gate is that same judgement
applied to gain. The hole was already open for anyone who weighed early;
dating the first entry at the birth made it universal, which is what forced it.

**This does not weaken the 2026-08-25 rule.** Gain is still the only trigger,
and no new trigger was added. `warrantsBreakdown` still reads `gain == .below`
and simply cannot see that case during the window. The one safety signal for
this period, `NewbornWeightLoss.Flag`, is untouched and still free.

**Two conditions, and neither alone is enough.** The gate defers when the baby
is inside the window NOW, *or* when the later endpoint of the measured pair
still lies inside it.

The second condition is not a refinement, it is the day-22 cliff. With only
the first, a baby weighed at birth and on day 10 and not since is silent on
day 21 and prints "below the reference" everywhere on day 22 — and fires
`growthGainLow` — off data that has not changed, the morning after
`NewbornProgressCard` disappeared. The reading is a reading about the dip
whatever the calendar says.

**Rejected: gating on the pair's EARLIER endpoint.** It reads more natural,
since the dip is at the start of the interval, and it is the one variant that
can silence the card permanently: a baby whose only two weighings are birth
and month one has a pair that reaches back into the window and never stops.
The later endpoint cannot do that — any new weighing becomes the newest one
and moves the endpoint out — which is why the post-window state is the one
that carries an add-weighing button. A pair that spans the window and ENDS
outside it is measured honestly, and the reason is stronger than the midpoint
rule: **the WHO 0–4 week row is itself a birth-to-one-month increment, so it
already CONTAINS the dip.** A pair ending at day 28 is the very quantity that
row was built from and is comparable to it; a pair ending at day 10 is a
fragment of it — the losing half — measured against the whole. That is the
line that survives re-litigation, because it is a fact about the reference
table rather than a judgement about which age to compare at.

**Why the deferral has two cases rather than one.** They differ in what the
parent can do about it. Inside the window the first-weeks card is on screen and
already asks for weighings — through the same `HintWithAddWeighing` the entry
below this one describes — so a second ask would be the same request twice.
Outside it that card is gone and nothing else is asking, so the gain card says
so itself and offers the weighing that ends the state, on that one shared CTA
mechanism rather than a button of its own.

A deferral is NOT one of the "held back by a missing weighing" states that
entry is about: there is data, it is simply the wrong data to read a current
gain from, which is why the deferral outranks `hasWeighing` and why the
in-window case carries no CTA despite being a hint.

**Why `deferredToNewbornWindow` is a case and not `notEnoughData`.** The data
is there; it is being read by the right instrument. Reusing `notEnoughData`
would print "not enough data" beside three weighings, and would have silently
compiled at every switch instead of forcing each surface to decide what to
say.

**Why the notification is gated at its call site, not inside
`consecutiveBelowReference`.** That function belongs to `WeightVelocity`, a
transcribed WHO table with a walk over it. Putting a newborn-period policy
inside it would make the two `Core/Growth` modules depend on each other and
bury a clinical rule in arithmetic. The gate belongs where a verdict is
emitted.

## 2026-09-05 — The newborn window is excluded from the centile trend, and a preterm baby is not scored before its due date

Two exclusions in `GrowthTrend`'s scored set, and a matching nil from
`WHOGrowthStandard`'s two per-measurement entry points.

**Weighings inside `birth + observationWindowDays` are dropped.** The
physiological dip is a fall of one to two centile spaces — NICE's own
thresholds — so a birth weighing becomes the trend's peak and ordinary
month-one catch-down reads as sustained faltering growth. A baby born on the
90th centile settling onto the low 30s by two months scored a 2.6-space drop
against its own 2-space threshold: `sustainedDrop`, on a healthy baby, on the
card whose whole job is to name faltering growth. It is the rule the gain gate
encodes, applied to the other verdict computed over the same days.

Unlike the gain gate this one is unconditional rather than requiring a birth
weight: dropping points leaves `insufficientData`, an honest state that needs
nothing put in its place, whereas deferring a gain verdict with no first-weeks
card to hold it would be worse than the ordinary rules.

**The cost, stated so it does not come back as a bug report: the first trend
verdict now arrives around day 50 rather than day 28.** The card needs three
scorable weighings spanning 28 days, and the earliest scorable one is day 22,
so the earliest span ends near day 50. That is honest degradation rather than
a regression — the verdicts it used to give before then were computed across
the dip, which is what this entry removes — and `insufficientData` already
says "not enough yet" in exactly the calm way this screen needs.

**A weighing dated before `correctedBirthDate` is not percentile-scored at
all.** `correctedAgeDays` clamps at zero, which is right for an increment table
and wrong for weight-for-age: a 1.4 kg baby born ten weeks early, weighed on
its actual birth day, scores the 0.4th percentile against the TERM newborn
curve — a comparison with babies that spent ten more weeks growing. It was
arithmetically fine and the first thing the Growth screen showed a parent whose
baby was in intensive care. `percentile(of:)` and `percentileReading(of:)`
return nil, `GrowthTrend` skips the point, and the percentile card says the
tables start at the due date rather than borrowing the "past 24 months"
sentence, which is true and about a different baby.

The entry itself is still created and still appears in the history and on the
chart — it is real data, and only the *verdicts* are withheld.

**`WeightVelocity` keeps its clamp**, deliberately. It reads an increment
table, whose newborn row is roughly right for a preterm baby growing at
catch-up rates, and gain is the signal a parent most needs during that period.

**Consequence, and it is correct rather than a bug:
`thresholdSpaces(birthPercentile:)` now applies more often.** That mapping IS
NICE's rule — one space for a baby born below the 9th centile, two between,
three above — and it was previously reached only by the minority who had
recorded a birth weight. Onboarding now asks for one, so most babies get the
threshold their birth centile actually calls for instead of the middle default.

## 2026-09-05 — An empty state names the missing thing AND offers the action that resolves it

Every Growth-screen state where a missing WEIGHING is what holds a card back
carries a button that adds one — first weeks, gain, centile trend, nutrition
and the measurement history. States missing something else (per-row "мало
данных" for unlogged feeds/nappies, the breakdown's no-data line) correctly
carry no weighing CTA: their resolving action lives on other tabs. The button is not decoration on the copy: the copy is
written as an instruction ("one more weighing, three days after the previous
one"), and the button performs it. Where a card's state depends on how much is
already on file, the sentence follows (`hasWeighing`), so a parent is never
asked for something they have already done.

**Why.** Build 14, fresh install: the owner logged feedings and nappies for
days and the Growth screen kept saying "not enough data". Every hint on it was
true and none of them was usable — they named a requirement in the passive
("two weighings are needed") without saying that only WEIGHINGS advance these
cards, and the only way to add one was a "+" in the navigation bar two hundred
points away. A parent reading "not enough data" while logging diligently does
not conclude they are logging the wrong thing; they conclude the app is broken,
and they stop logging. The nutrition hint therefore also says what the feeding
and nappy counts are measured over, which is the sentence that answers the
actual confusion.

**The action is injected, never wired per card.** `GrowthView` puts it in the
environment once (`\.addWeighingAction`), and the button draws itself only when
something is there to answer it — the same rule `InfoBadge` follows, for the
same reason: a card rendered in a dump, a preview or a future screen must not
advertise an affordance that does nothing. One sheet presentation serves the
whole screen.

**The Dashboard's growth section is a gesture, not a `NavigationLink`** (the
link shipped briefly within this branch and was reverted in review).
Header and card are one tap target now, but a `NavigationLink` is a `Button`
and flattens its label into a single accessibility element, which would undo
the per-row VoiceOver structure the Dashboard and `NutritionSection` were
deliberately built with. This is the trade `ExplainerCard` already made; making
it again here rather than taking the convenient link is the point of recording
it.

## 2026-09-05 — Adding a weighing never makes the app show less: one pairing rule, and it widens

The gain reading is measured over `WeightVelocity.pair(in:)` — the newest
weighing paired with the most recent EARLIER one that clears
`minimumIntervalDays`, found by walking backwards. Only when no such partner
exists does the "two measurements needed" hint appear. `FeedingAdequacy
.window(for:)` and `consecutiveBelowReference` both go through that same
walk; the last-two rule survives only as `window(for:)`'s fallback for the
case where no gain can be measured at all.

**Why.** A parent on build 13 weighed on day 0 and day 7 and had a verdict,
weighed again on day 8, and the gain card demanded "2 measurements" while
holding three — deleting the new weighing brought the verdict back. More data
showing less reads as the app breaking, and it teaches a parent not to log.
The short noisy tail is absorbed into a longer interval rather than allowed to
silence the verdict; `minimumIntervalDays` still holds, because the interval
that gets measured is the widened one and it clears the floor on its own.

**The newest weighing always stays in the pair.** The card claims to describe
the CURRENT trajectory, so a measurable older pair (day 0 → day 7, with day 8
on file) is a statement about the past wearing the present's clothes.

**Three surfaces, one pair.** The nutrition window follows the gain's pair
rather than the last two weighings, because one Growth screen prints three day
counts of the same window — section header, gain card, breakdown card — and
`FeedingAdequacy.Assessment.windowDays` documents the whole-day rule that
exists to keep those three identical. A
header reading "over 1 day" above a card reading "over 8 days" is the same
defect that rule was written for, arriving through the pairing instead of
through the arithmetic. The last-two fallback stays for a gap under three
days: there is no gain to contradict there, and feeds and nappies over two
days are still countable.

**The notification moved too, and that was the point of checking.**
`consecutiveBelowReference` walks the same chain, so a curious re-weigh the
morning after cannot break a run of two below-reference intervals. What moved
is which weighing an interval starts from; the count and the per-interval
floor did not, so two intervals are still required and each still clears
`minimumIntervalDays` on its own — two weighings a day apart cannot raise an
alarm between them. Noise in the MIDDLE of a history is absorbed the same way:
weighings on days 0, 14, 15 and 29 now chain 0→15 and 15→29 and can report a
pattern, where the raw-pair walk hit the one-day 14→15 step and reported
nothing. Left on raw consecutive pairs, a single extra weighing would suppress
the `growthGainLow` signal entirely, which is the same defect in the surface
where it costs most: a notification that does not fire says nothing at all.

`GrowthTrend` is deliberately NOT part of this. Its window rules answer a
different question — where a baby is heading over months — and it already
refuses to widen backwards to reach a span (see its `referenceWindowStart`
doc, which records what that cost).

## 2026-09-05 — A future-dated weighing is refused at the picker AND ignored at the read

Two guards, deliberately not one. `AddGrowthSheet`'s date picker is bounded to
`birthDate...today` (clamping the lower bound with `min(birthDate, now)`, so a
drifted birth date cannot form an inverted range and trap). And the
`weightMeasurements` accessor — the single door every growth analysis reads
through — drops any entry dated more than 24 hours ahead of this device's
clock.

**Why.** The build-13 report started with a weighing dated September 17 in
early September. A future date is not a typo the growth engine can absorb: the
entry sorts to the end of the history and becomes the newest half of every
pair, and the interval it defines has not elapsed, so the measured gain is
divided by days that are still to come. That UNDERSTATES the rate — the one
direction `WeightVelocity.measure` documents as unsafe, because it can turn a
healthy `.within` into `.below` and fire `growthGainLow` off arithmetic about
the future.

**The picker alone would not have been enough**, and the pair fallback above
is why it matters more now than it did: rows entered before the bound existed,
and rows synced from a phone with a wrong clock, still arrive. Under the old
last-two rule such a row often produced no reading at all; under the fallback
it produces a confident wrong one. Filtering at the read boundary rather than
on save also covers the rows already in people's databases, which a save-time
validation never could.

**24 hours, not zero.** The picker legitimately stamps the chosen DAY with the
clock at the moment the sheet opened, and cross-device clock skew is real, so a
genuine row can sit a little ahead of `now`. **The row is not deleted and not
hidden** — the measurement history still shows it, which is how a parent
notices the wrong date, and it starts counting by itself once its date
arrives.

The birth-date pickers (`BabyProfileEditSheet`, onboarding's `BirthPage`) were
already bounded `...Date()` — the profile one has since been tightened further,
see 2026-09-20; the event-time pickers (sleep, nappies, events)
are deliberately left alone — a future event time is a scheduling mistake with
no clinical reading downstream.

## 2026-09-05 — One explainer pattern, and it never eats a sell tap

Every verdict card on the Growth screen opens the same `ExplainerSheet`,
parameterized by a `GrowthExplainer` case. On an unlocked card the whole card
is the control and the "?" is only the affordance; on a `LockedInsightCard`
the "?" is its own button and the card around it still opens the paywall.
Explainer copy lives under the card's OWN key family (`velocity.info_body`,
not `growth.info.gain.body`).

**Why.** Build-12 feedback was that three cards say a couple of words a parent
cannot decode — the same complaint the percentile explainer already answered,
so the answer had to be the same thing five times rather than five things.
Which tap opens it is not a style choice: a locked card exists to sell, and an
explainer laid over its tap would trade the paywall for a help sheet, so the
badge stays the smaller target there and the sell keeps the card. The key
prefixes follow the card because a `growth.info.*` family would scatter one
card's strings over two places in six JSON files.

**The unlocked card is a tap gesture, not a Button, and that is not a style
choice either.** A SwiftUI Button flattens its label into a single
accessibility element: wrapping the cards in one silently collapsed
`NutritionSection`'s three rows — built to read as one VoiceOver stop each, a
label and its status as one statement — into a wall of text. A `contentShape`
plus `onTapGesture` leaves the children as the card built them, and the
explainer stays reachable without sight through a named action on the card's
TITLE, not on the card: a container is not an accessibility element, and
whether an action attached to one reaches the elements inside it is a promise
this project has no way to verify — an accessibility feature nobody can check
is one nobody knows they have. A title is an element with certainty, and it is
where the "?" already is. The price is the
press bounce: animating a press would take a `DragGesture(minimumDistance: 0)`,
which fights the enclosing `ScrollView`. A card is not a button-shaped control,
so it does not need to bounce like one; a locked card, which IS a control, keeps
its Button and its bounce.

The badge is injected by `ExplainerCard` rather than drawn by each card,
because a card that draws its own "?" advertises an explanation nothing opens
the moment it is rendered anywhere else — which is exactly what the test render
dumps showed.

The nutrition copy says outright that **gain is the main signal and feeds and
nappies are context** — the 2026-08-25 rule, finally stated to the parent
rather than only enforced in `FeedingAdequacy`. A parent who reads "8 feeds a
day" beside a reference and is not told which line decides will invent the
multi-signal alarm in their own head, which is the exact fear that rule exists
to prevent.

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

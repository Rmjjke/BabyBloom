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
| `BabyBloomWidget` | WidgetKit extension: the home-screen widgets and the timers' Live Activity views. Reads the same store, writes nothing — the Live Activity's Stop button and the widget's Start feeding button run in the app's process. |
| `BabyBloomTests` | XCTest bundle. Also compiles parts of the app source directly. |

The three meet at the App Group `group.com.nenita.app`, which is where the
SwiftData store physically lives. That single fact explains most of the
structure below.

## Domain model

Nine `@Model` types in `BabyBloom/Core/Models/`: `Baby`, `FeedingEntry`,
`SleepEntry`, `DiaperEntry`, `GrowthEntry`, `CustomEvent`, the 1.2.0 pair
`DoctorVisit` / `DoctorQuestion` (`DoctorVisit.swift`) and the 1.3.0
`Medicine` (`Medicine.swift`). They are listed ONCE,
in `AppSchema.models`, and every container — app, widget, tests — opens the
store through `AppSchema.schema`; `AppSchemaTests` pins the list.

**A persisted enum is closed.** Enum properties (`CustomEvent.type`,
`FeedingEntry.side`, …) are stored as their raw value. A build that reads a
value it does not know — one written by a newer version and delivered by
CloudKit — crashes in SwiftData's decoder, on every launch. A new kind of
record is therefore a new model or a new optional attribute, never a new
case; `FrozenPersistedEnumTests` fails on a new case with that explanation
(DECISIONS 2026-11-01).

**Every stored property has a default value and every relationship is
optional.** That is not style — it is what CloudKit requires of a mirrored
SwiftData schema. A new non-optional property without a default will compile
and then fail at container creation, at launch, in `fatalError`.

`Baby` owns the five entry types, the visits, the questions and the medicines
with `deleteRule: .cascade` and an explicit `inverse:`. Deleting the baby deletes
its history.

**Visits and questions change only through `DoctorVisitActions`**
(`Services/`), the same idea as `TimerActions`. A visit stamps the questions
asked at it (`askedAt` + `visit`) in the same save that writes it, and
deleting a visit returns those questions to open before it goes; the
visit→questions relationship is `.nullify`, which alone would leave them
"asked" at nothing. A question is open when it has no `askedAt` OR no
`visit` — the link is the truth, so a cross-device merge that leaves a stray
stamp brings the question back instead of losing it. A visit's `date` is held
at NOON of its day (`DoctorVisitActions.visitDay`), so it reads as the same
day in any time zone a synced device sits in; readers take `startOfDay`. Every
action saves once and rolls the context back if the save fails. `DoctorPeriod` (`Core/DoctorReport/`) answers where the
report's period starts: 00:00 of the latest visit's date (same date → the one
logged last), else the birth day.

**A medicine and its doses** (`Medicine`, 1.3.0). A medicine holds a name,
the minimum interval between doses in minutes, an optional dose text, note
and 24-hour maximum, and `endedAt` once its course is ended. A dose is NOT a
model: it is a `.medication` `CustomEvent` made by `CustomEvent.dose(of:at:)`,
which links it (`CustomEvent.medicine`) and copies the medicine's name and
dose text onto it. The copy is the record of what was given: a rename leaves
past doses as logged, a deleted medicine (`.nullify`) leaves them as
medication events that keep the name, and an older version, which imports no
`Medicine` and ignores the link, still lists each dose as the medication
event it is. The medication screens, the Events rows, the events CSV (columns
Medication and Dose) and the export PDF's events table (name · dose · note in
its notes cell, `ExportGenerator.eventNote`) read the two copies, never the
medicine's current name. Events from before medicines, and free-text ones, have no link
(`CustomEvent.isDose` is false) and count for no medicine.

The rules every medicine surface reads are `MedicineSchedule`
(`Core/Medicine/`; app target only, since the widget compiles `Core/Models`
but not this folder). Only linked `.medication` events are doses, and a dose
later than now is ignored. The next allowed time is the last dose plus the
interval and, once the last `max` doses fall within 24 hours, no earlier than
the oldest of them plus 24 hours. `check(t)` flags a dose closer than the
interval on EITHER side of `t` (exactly the interval is on time). It names
the nearest close later dose first, and only without one the latest close
earlier dose with its interval's end, so the time it gives is always a true
«not before». It also flags the fullest window `[s, s + 24 h)` holding `t`
when that is over the maximum. `showsDaily` says which of the two the one
confirmation states: the maximum only when, with the dose counted, it holds
the next dose back past the interval's end. `nextAllowed(adding:)` is the
«not before» once a dose at `t` is logged too, never earlier than
`nextAllowed`. `dosesInLast24Hours` is the count shown against the
maximum. It is all elapsed time, never calendar arithmetic.
`Medicine.status(now:excluding:)` reads `.ended`, `.noDose`, `.waiting` or
`.allowed`; `excluding` and `Medicine.check(_:now:editing:)` leave the dose
being edited out. A dose deleted from the context counts for nothing even
before the save removes it from the relationship. Nothing
about a medicine is sent to analytics; a dose sits in the daily activity
count's `event` figure like every event.

**The medication screens** (`Features/Medications/`, More › Medications).
The list shows running courses sorted by name and ended ones under a collapsed
`DisclosureGroup`; the detail shows the status card, what was set, the doses
newest first, End/Resume Course, and Log Dose pinned under the scroll (an
ended course has no footer). Every word comes from `MedicationFormat`, which
builds lines A, B and C from `MedicineStatus` and the copy keys: each time
slot takes a when-string (today's clock, or yesterday / tomorrow / a date),
ages count hours and minutes up to 48 h and then days. The screens read
`AppClock.now` and redraw once a minute (`TimelineView(.everyMinute)`).
`MedicationFormInput` holds the form and its Save rule: a name, and an
interval in `Medicine.intervalMinutesRange` (15 min … 48 h) from a chip or
the Other wheels (at 48 h the minutes wheel offers only 0); the maximum field
keeps two digits and may be empty, but 0 or over 24 keeps Save off and shows
the range hint under the field. Lines the code joins with a middle dot use
`MedicationFormat.separator`, which puts a no-break space before the dot, so
a wrapped line never opens with it; a dot inside a copy key is the key's.
The name and dose fields wrap (`axis: .vertical`) but stay one paragraph
(`View.oneParagraph`): Return ends editing and a pasted line break becomes
a space, since the copies travel into every row, the alert and the export.
`DoseSheet`
logs a dose (`CustomEvent.dose(of:at:)`, the dose text as edited) or edits
one (time, dose text, note; never the copied name); its picker ends at now
and save clamps to now as well, since the picker clamps only its display. It
is a plain `.sheet` and never calls `entrySaved`. The dose list applies
`HistoryWindow` like every history list, with `BBLockedHistoryFooter(surface:
nil)`, which draws the footer without its lock event. The detail lists the
doses from a `@Query` of events, and the list reads one too: a dose linked or
deleted on the event's side does not always reach observers of
`medicine.doses`, and a stale row would open a deleted dose. Deleting is
ordered so no view reads a deleted model: the form only asks, and the detail
pops itself and deletes the medicine once it has disappeared; Delete Dose
hands the dose back and the detail deletes it in the dose sheet's
`onDismiss`. The detail and the dose sheet draw nothing for a model with no
context or `isDeleted` (one deleted on another device). Nothing in the feature is
gated. The reminder is under Notifications.

**The Home card** (`MedicationHomeCard.swift`). While a course runs and its
last dose is under 24 hours old (`Medicine.onHome`), the Dashboard shows one
plain card under the running timers and above the weekly card: a line per
medication (name and line A, by name), the whole card one link, to the
detail with one medication and to the list with two or more. A course with
no dose does not show, and one nobody ends leaves Home a day after its last
dose. `MedicationHomeSection` reads its own queries (a dose saved anywhere
redraws it) and ticks each minute while the card shows. It is a plain view
that draws nothing when empty, not a `TimelineView`: an empty
`TimelineView` still takes a place in the Dashboard's stack, and the stack's
32 pt spacing with it.

**The confirmation** (`DoseConfirmation.swift`). Save in the dose sheet, and
in the Add Event form with a medication chosen, first asks
`Medicine.confirmation(for:now:editing:loggedTime:)` about the time it will
store. It reads `check` and returns the words of one variant, or nil when
the dose is on time: «before» (a close earlier dose and the next time; when
a later dose is logged too, `laterDoseLogged`, the neutral «between» words
name it a logged dose, since «last dose» names only the newest),
«after» (a close later dose and the interval), or «24 h» (the count with
this dose, the maximum and the next time), the last only when `showsDaily`
holds. The next time is `nextAllowed(adding:)`: what the screen shows once
this dose is saved, which is the answer the alert waits for. It is each
message's last line and is dropped when it is not after now (a dose logged
after the fact), so the alert never names a time that has passed. A
non-nil answer raises a system alert (`View.doseConfirmation`) and keeps a
`ConfirmedDose` (the medication's id and the time): Cancel returns to the
sheet with every field kept; Save stores exactly that dose, or nothing when
the choice has changed meanwhile. There is no alert for an ended course, or
for an edited dose saved at the time the sheet read when it opened; a
free-text event is never checked.

**Medicines on Events.** One `MedicationStatusLine` per running medication
sits above Quick input and pushes its detail. While a medication runs, the
Medication tile opens `DoseSheet(choosingFrom:)` free and with no padlock: one
running medication is preselected, with two or more the «Medication» menu
shows «Choose» and Save waits. With none, the tile is the old one-tap entry
behind the gate. The Add Event form, type Medication, shows the same menu
(`MedicationMenuField`) of running medications plus «Not in the list»: a
chosen one logs a linked dose (`CustomEvent.dose(of:at:)`) with the status
box (`MedicationStatusBox`) and no name or dose fields; «Not in the list», or
no running medication, keeps the two free-text fields. The form's time
starts at `AppClock.now`; for the Medication type, linked or not, its picker
ends at now and the save clamps to now. The bound follows the type, not the
choice in the menu: a compact picker whose bound moves under its selection
redraws its date in the short style. No medication
save from any path calls `entrySaved`. A medication row's text is
`MedicationFormat.eventRow`: a dose titled by its copied name, then dose ·
note; an older one by the type word, then name · dose · note. `BBEventRow`
shows every string verbatim (its callers localize, so a typed note or name is
never looked up as a key), scales its second line and time, and moves the time
under the text at accessibility sizes, where a long word beside it broke
mid-word, and below them wherever a word of its title or subtitle misses its
column beside the time: ru «вскармливание» on a 320-pt screen at Large, en
«Breastfeeding» there at xLarge with Bold Text.

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
are CloudKit-compatible and the widget uses the app's own `AppSchema`, `.none`
reads the identical store with no schema mismatch. A widget list that lacked
a model would open the store as another model version, and a lightweight
migration may drop the tables it does not know.

**A new model needs the CloudKit schema deployed to Production** (CloudKit
Console → Deploy Schema Changes) before the build that adds it ships.
TestFlight and App Store builds sync against Production, where the new record
types do not exist until deployed; without that the new records never sync,
and nothing reports it. It is an owner step on the release card.

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

**A span of time has one writer.** `DurationText.minutes`
(`Core/Localization/DurationText.swift`) writes whole minutes as «45 мин»,
«1 ч», «1 ч 15 мин» for every screen, the widget, the weekly card, medications
and the export. Each caller turns seconds into minutes its own way: a clock
floors, a countdown rounds up. Seconds show only under a minute and on a
running timer. A count carries no unit word: a stat tile shows the figure
alone, and a progress card reads «0 из 6» (`progress.of_fmt`), or «10 из 14 ч»
for a measured target (`progress.of_unit_fmt`). A duration tile keeps its unit
words inside the value, drawn smaller than the figures.

## Theming and typography

The palette is **entirely** in the Asset Catalog
(`Resources/Assets.xcassets/Colors/`), reached through `BBTheme.Colors`.
Never hardcode a colour in a view. Re-theming the app is: colorset edits (a
colorset the widget uses also has its copy in `WidgetResources/Colors.xcassets`,
which the pre-build check keeps byte-identical), the
two splash PNGs (a new `BBSplashBg` also means measuring its figure's box
again, `SplashLayout.figure`), and the hex constants in `ExportGenerator` and
`DoctorReportPDF` — the PDF renderer cannot read the Asset Catalog, so those
two are the only places a colour is duplicated (both mirror the LIGHT
colorsets: a PDF page is always white).

**On the growth surfaces a tier tint (`BBSuccess`, `BBAccent`, `BBAlert`) is
a mark, never text ink**: in light the green and the peach read under 2:1 on
the surface. The verdicts put their words and figures in `textPrimary`
(`textSecondary` for «not enough data» and «first weeks») and the tier on a
mark beside them: the percentile ring, the newborn card's tick, the flag
row's icon, and the dot `BBTierValue` draws before a value (within green,
below peach, none above). `StatusWord.ink` / `.dot` are the mapping for the
Nutrition rows, Home's gain row (`GrowthSummaryRow`) and the weight gain
card's band word. The dot is part of the value's text run, so it wraps with
the first word, and the value carries its words as its VoiceOver label
(DECISIONS 2026-11-04 "A growth verdict's tier is a dot, never the colour of
its words").

**A category tint (`BBFeeding`, `BBSleep`, `BBDiaper`) is a mark too**: the
running-timer cards' wash, stroke and Home's glyph disc, the week chart's
bars, the bottle slider. The words and figures beside them are text ink: the
timer's label and digits (`BBElapsedTimer.face` and `BBTimerCardHeader` take
no colour), the chart's day labels and values, and the bottle volume. As ink
in light a tint read at 1.6–2.1:1 on its wash or the surface, under the 3:1 a
large figure needs; the same digits are `textPrimary` on the Lock Screen too.
The week chart has no axis numbers: every day up to today states its value
over its bar, today's in `textPrimary`, the others in `textSecondary`, hidden
from VoiceOver, which reads each bar's day and value.

`textSecondary` holds 4.5:1 on every fill it sits on in light: 5.12 on the
background, 5.62 on the surface, at least 4.62 on the stat cards', timer
cards' and pickers' washes. A primary wash under `BBPrimary` words (a selected
tile, a pill or chip, the secondary button) is laid over `surface`
(`.background(selected ? primary.opacity(0.12) : .clear).background(surface)`),
so the words read 4.78 on any ground, a timer card's wash or an onboarding
blob included; over the bare background they were 4.38. Onboarding's two
primary blobs stay at 0.08 for the same reason (DECISIONS 2026-11-05).

A selected tile's or chip's 1.5 pt `BBPrimary` border lies outside its fill:
`bbSelectedBorder(_:shape:)` puts the stroke's inner edge on the fill's edge,
with corners `Radius.md + 1.5` concentric with the fill's (`.capsule` for the
feeding timer's side pills). Drawn inside, it covered the fill's outer 1.5 pt,
and with Bold Text a word that fills its tile on a 320-pt phone («Izquierdo»
with its glyph, «Смешанное») ran under it. As an overlay it takes no room: a
tile is laid out the same selected or not, and a gap beside a selected tile
reads 1.5 pt less (8 → 6.5). VoiceOver's frame of a selected tile takes the
border in, 1.5 pt a side. It goes after `bbShadow`, so the shadow keeps the
fill's outline. The Export format tiles and the plan rows draw their own
outline.

A delete draws the system red: from `role: .destructive` where the button has
a role (the sheets' Delete, the confirmations), from `Color.red` where it has
none (the delete-history button, the swipe action, remove photo). Never
`BBAlert` on a delete's label, which overrides the role: `BBAlert` means a
growth flag or a percentile tail (DECISIONS 2026-09-05 "A count above its
reference is never styled as an alarm"). Red stays on deletes and marks: the
delete-history button has a red stroke and no red wash, the purchase error's
words are `textPrimary` beside a red glyph, and no card has an over-limit red
state.

**The brand gradient (`BBGradientStart` → `BBGradientEnd`, `premiumGradient`
and the widget's `WidgetBackground`) has one value in light and dark**, and
every word and glyph on it is white at full strength: white reads 4.67:1 at
its lighter end and more everywhere else, so a word passes wherever it lands.
On the widget and the paywall hero the hierarchy is size and weight, never a
white at an opacity; the widget's one tap target is a `BBSurface` capsule
with `BBPrimary` words. An unselected or unchecked mark (the Export screen's
range circle and category square, the visit sheet's questions, the plan
picker) is `textSecondary` at full strength, 5.62 light and 6.11 dark on the
surface; the checked one is `BBPrimary`. The splash words are `BBSplashText`
#4A357E in both modes, because the art does not change with the mode; in
portrait they sit on its lavender field, the tagline at 4.61 or more
(DECISIONS 2026-11-05 "One brand gradient for both modes").

**The splash places its words by the art's figure** (`SplashLayout`, in
`SplashView.swift`). `BBSplashBg` fills the window and the words stand centred
at 82 % of its height wherever they clear the figure's box (the crescent, the
baby, the sprout and their shadow) and the safe bottom: every portrait window,
and iPad Split View 1/2 and 1/3. In a wider window that place is on the figure
(a phone or a full iPad in landscape, iPad Split View 2/3), so there the
figure and the words stand side by side, the figure leading and 32 pt before
the words, centred as one group in the safe area and 24 pt inside it. The art
is drawn at the largest scale that fits, never above the fill, and a side of it
that ends inside the window fades into `BBLaunchBackground` on a smoothstep
that starts at the figure's edge, so the figure is never faded and no line
shows. The box is measured on the art in its pixels, so a new art means
measuring it again. In a right-to-left language the group is mirrored and the
art is not. The insets come from a `GeometryReader` inside the safe area,
wrapped around the one that ignores it for the full size: a reader under
`.ignoresSafeArea()` reports zero insets. The layout is a function of the
window and the words' size alone, so a rotation puts everything in its new
place in one pass and the reveal goes on (DECISIONS 2026-11-05 "In a wide
window the splash puts the figure and the words side by side"). The art and
the tagline's two leaves are decorative and hidden from VoiceOver, which reads
the app's name and the tagline only, in every layout.

`BBTheme.Typography` is the app's type scale (SF Pro semibold headers, SF
Rounded body, rounded monospaced digits for metrics and timers). **Every
Dynamic Type scale in the app goes through `Typography.scaledPointSize`**,
including layout metrics that
must track text size. A bare `UIFontMetrics.scaledValue(for:)` is a defect:
that form reads the *device* content size and ignores the SwiftUI environment,
so the app's ceiling walks straight past it. The ceiling itself
(`Typography.maxContentSizeCategory`, AX2) lives in exactly one constant, from
which `BabyBloomApp` derives its `.dynamicTypeSize` modifier — the two cannot
drift apart. See [DECISIONS.md](DECISIONS.md), 2026-08-28.

Two field layouts have one helper each in
`DesignSystem/Components/BBFieldLabels.swift`. `BBLabeledPicker` puts a date
or time picker's label above it at every size (beside the buttons it broke
mid-word as the text grew, and at Large on a 320-pt screen it had no room
beside the widest date) and hides that visible label from VoiceOver, so the
picker's own label is read once; the entry sheets' date and time rows use it.
The profile edit sheet's birth date keeps that form's smaller caption above
the picker, so it takes the same two halves without the helper: the caption
is hidden from VoiceOver and the picker carries the name. `bbPlaceholderLabel`
is for a vertical `TextField` whose placeholder is its only visible label (the
medication name, dose and note, the Diaper note, the doctor question; also
the medication maximum, whose example placeholder needs two lines in es): it
keeps two lines at accessibility sizes and takes the body size from
`Typography.scaled`. Both halves matter: on iOS 26 a placeholder wraps only into lines the field already
has, and with a text-style font such as `.body` it stays on one line and ends
in «…» however many lines the field keeps.

Words that had a fixed point size grow the same way: `Typography.scaled(<size>,
relativeTo: .body, …)` keeps their size, weight and design at Large and then
follows the text size as body text does: smaller below Large, larger above
it, most at accessibility sizes. The entry sheets' tile words (with their
glyphs), the Diaper and Events quick tiles' glyphs, the Sleep start tiles'
glyph and caption, the Feeding quick tiles' words and captions, the Home
quick actions' words, the Feeding and Sleep timer cards' labels and the Home
timer card's subtitle, the Diaper screen's norm chip (word and glyph),
onboarding's gender tiles (figure and word), stool colour names, slider
ends and hints use it, and so do the stat card's title, unit and trend chip
and the Growth gain card's interval, band label and reference line.
Some screens outside the entry sheets still set fixed sizes. A glyph that
stands over or beside its word grows with it; colour samples, icon plates
(with the glyph inside them) and decoration keep their size, and the Growth
sheet leaves its ruler out at accessibility sizes. The stool warning and the
profile photo hint keep their wrapped alignment at every size, Large
included: the warning's triangle sits on its first line and the hint is
centred, because in ru both wrap at Large on a 320-pt screen.

A row of tiles keeps a column count only while its widest en, ru or es word
fits the column (the tile less its side padding) at a 320-pt width with 8 pt
to spare; the spare covers a measuring error, a later word and Bold Text.
320 pt is Display Zoom on the smaller phones and iPad Slide Over. The rule is
checked at every text size, with the row's count there: at Large, which every
smaller size follows, at xLarge, xxLarge and xxxLarge, and at AX2, where scaled
type stops growing. A row takes fewer columns from the first size where its
widest word misses, and each text size has one shape at every width; no count
follows the width, except on Home's quick actions (below). The rows below
state their counts once, in a `BBTileColumns` (beside `BBStatGrid` in
`DesignSystem/Components/BBCard.swift`): Large, which stands for every smaller
size too, xLarge, xxLarge, xxxLarge and accessibility. A row that is an
`HStack` at Large stays that `HStack` wherever its count is unchanged (a grid
sets it a third of a point lower), becomes a grid where the count drops and a
`VStack` where it reaches one; a row that is a grid at Large takes the count.
The counts, Large to accessibility:
- Diaper and Feeding screens' quick-add 3/2/2/2/1; Sleep screen start tiles
  2/2/2/1/1; Events quick row and `BBStatGrid` (five screens) 2/2/1/1/1.
- Stool colours 4/3/3/3/2; Feeding sheet types 3/3/3/2/2 and breast sides
  3/2/2/2/1; Diaper sheet types and Sleep sheet locations 3/3/3/3/2; Add Event
  types and moods 3/3/2/2/2; Sleep sheet types two at every size.
- Profile sheet feeding 3/2/2/2/1; profile sheet and onboarding gender
  2/2/2/2/1.

Four rows keep a count with less than the 8-pt spare, each measured with and
without Bold Text, and measured again whenever its words change in any locale.
The stool row at Large: «Коричневый» fits a quarter of 320 pt; three columns
would set the default Diaper sheet's seven swatches 3 + 3 + 1 on every phone.
The profile edit sheet's feeding row at Medium and Large: «Смешанное» fits a
third of the sheet at 320 pt, and is the same word at the same size it always
was. The Feeding screen's quick-add row at Large («Сцеженное», 5.4 pt with
Bold Text) and the Feeding sheet's breast sides at Medium and Large
(«Izquierdo», 4.0 and 0.7 pt with Bold Text) keep three, because fewer columns
would change the default screen on every phone. Side padding is what keeps
three quick tiles at Large on 320 pt: 8 pt on the Diaper tile (16 above and
below), where 16 broke «Грязный», and none on the Feeding tile, where 8 broke
«Сцеженное». The Feeding tile's caption keeps 4 pt a side of its own, so a
caption on one line keeps clear of the tile's border; es «Agregar manualmente»
on 402 pt and ru «Добавить вручную» on 375 pt set on two lines.
The breast-side chip sets its glyph 4 pt from its word, not the default 8. In
one column a quick or start tile keeps its shape: glyph above word, centred,
full width. The profile edit sheet's gender and feeding rows and onboarding's
gender row, measured at a 320-pt width, drop to one at accessibility sizes;
the profile feeding row already takes two from xLarge, where «Смешанное» no
longer fits a third of that width. Home's quick actions are the one
equal-column row whose count follows the width (`QuickActionsLayout` in
`DashboardView.swift`): below the accessibility sizes they stand four in a row
while every action's word fits a quarter of the card as drawn, measured live
in the app's language, at the text size and with Bold Text, else two by two;
one column at accessibility sizes. A tile is as wide as its word or its 60-pt
plate, whichever is wider. At Large that is four on 375 pt and wider; on
320 pt ru goes two by two, where «Подгузники» (71.1 pt) misses a quarter (64),
and en and es, whose widest tile is the plate, stay four.

A title with one trailing value is a `BBValueRow`
(`DesignSystem/Components/BBValueRow.swift`): Settings' Premium row and its
badge, the measure sliders' and the bottle volume's figure, `BBProgressCard`'s
count, Export's category «0», a plan row's badge and the iCloud Sync state.
The value keeps its one-line width and the title wraps beside it, between
words only; at accessibility sizes the value stands under the title, lined up
with the title's text: where a glyph leads the title (`BBProgressCard`), the
`bbValueRowTitle` alignment guide marks the text, so the figure starts past it.
`.byFit` keeps the value beside only while the title fits one line next to it,
else under it at any size: on a 320-pt screen at Large the ru and es iCloud
Sync titles miss that line, and beside the value «Синхронизация» broke inside
the word. That row is one Label around the title, the state and the hint, as
the switch rows hold theirs, so the state and the hint start at the title's x,
and it stays one VoiceOver element. The medication menu's label stands above
its menu at every size, not beside it below the accessibility sizes: a long
running name squeezed it. The Export format tiles keep 8 pt a side inside the
outline and take the taller tile's height, so the two stay one row. The
caption under them names where the doctor's PDF is from the tab's and the
row's own keys (`ExportDoctorHint`), so it follows a rename of either.

A row of content-sized parts whose fit changes with the width or the running
time takes its shape from the fit instead, with `ViewThatFits`: the row while
it fits, else stacked. The Feeding timer's side pills stand three in a row while the row
fits the card, else one per row; in es the row is wider than the card on a
320-pt screen from Medium up. Every timer card in the app takes its shape from
`BBTimerFit` (in `DesignSystem/Components/BBElapsedTimer.swift`): the
Feeding and Sleep cards' `BBTimerCardHeader` (label over title) and Home's
`ActiveTimerCard` (title over subtitle, its icon plate beside) set what is
running beside the timer while the two fit one line, else above it. The
timer's width follows the elapsed time (hours past an hour of sleep on the
Sleep card and Home's sleep card, three-digit minutes past 100 minutes of
feeding), so `BBTimerFit`
draws both shapes from one `TimelineView` clock, and each fit check reads the
digits on screen. Home's card, whose title and subtitle stand in one column,
stacks at Large on a 320-pt screen whatever the time. The pills and the timer
rows stack at accessibility sizes on any width, so the running cards keep one
shape at the largest text. The Diaper
screen's Today row puts the norm chip under the title at accessibility sizes
by the text size: its words hold at 320 pt at every size below, so no width
changes the answer. The Growth gain card sets its number («+210 g/week») and
the interval («over 9 days») on one row while both fit whole, else the
interval under the number. Squeezed beside the interval, the number broke at
its slash. Alone, it still breaks there, its only break, where it outgrows
the line: at AX2 on a 320-pt screen in en and es. Home's Today feeding card
sets the time since the last feed («59 мин назад») beside its plate while
each word of it fits the room there, wrapping between words, else on its
own line under the plate. In two columns on a 320-pt screen that room is
about 32 pt of text at Large. `WordWrappingText` (in `BBCard.swift`) gives
`ViewThatFits` the widest word as the text's ideal width, so the check is
about words, not the whole line. `BBEventRow`'s title and subtitle are
measured the same way. `SideBySideIdeal` (in
`DesignSystem/Components/SideBySideIdeal.swift`) does it for a label | Spacer
| value row: its ideal width is the least at which the stack's own split (the
less flexible text offered half the room, the other the rest) leaves each
text its widest word, and a concrete width passes through untouched, so a row
that fits lays out as the plain stack. The Nutrition card's three rows take
one shape together through it: all beside while every row keeps its words
whole, else all stacked as at the accessibility sizes (ru at xxxLarge on
320 pt, and at xxLarge with Bold Text). Its hidden measuring copies take the
drawn `multilineTextAlignment`: wrapped flush right, a text reports about a
space more width. The diaper norm editor's stepper card
(− digits +) keeps the column's xl inset, as Save: with xl between each
symbol and the digits and inside the card it needs 313 pt with «12», 2 more
than a 375-pt column leaves. Where that misses, the card takes the column's
width, and its four gaps, the two inner sides and the two beside the digits,
share what the symbols and the digits leave, equal and md at least: 31.4 pt
each on 375 pt and 17.7 on 320 at Large. Below md the digits shrink.
The digits are sized before the gaps (`layoutPriority`): the stack's equal
offer would shrink them above Large while the gaps still had room. The
editor scrolls once its content is taller than the sheet (above Large on a
320-pt phone) and does not bounce where it fits. The weekly card's
three value rows (feeds, sleep, gain) take one shape together: each on one
line, its delta at the row's end, while every shown row fits there at full
size, else all three with the delta under the value, as at the accessibility
sizes, where they always stack. A shape per row would break the deltas'
column, and nothing shrinks. The lines that wrap (the expanded details, the
gain line without a figure, the first-week and days lines) sit in
`WrapsToWidth`, which asks for no width when measured for its ideal width,
so only the value lines decide. At Large, with
sleep «14 h 20 min» and a delta of «1 h 45 min», the rows stack on 320 pt in
every language and take one line in en and es from 375 pt, in ru from 402;
on 375 ru takes one line while the sleep delta is under an hour.

Sheet titles follow the same rule, through `bbSheetTitle` and `BBSheetHeading`
in `DesignSystem/BBTheme.swift`, which take the same `BBSheetTitlePlacement`.
With the default, `.barUpToLarge`, used by the five add sheets, the question,
visit and medication form sheets and the profile edit sheet, the title sits in
the bar up to Large, on one line, shrinking to fit between the bar's buttons
down to 13/17 of its size (13 pt at Large, the sheets' caption size). Above
Large, where it would stay at its Large size while the sheet's text grows,
the bar shows no title; the sheet's first content line, `BBSheetHeading`,
shows it at the sheet's text size and carries the header trait, so VoiceOver
reads it once. The dose sheet passes `.content`: its title is the
medication's name, which the parent wrote and no length holds, so it heads
the content at every size and wraps. The modifier and the heading go together
with the same placement: the modifier alone leaves no title where the bar has
none, the heading alone shows it twice. The diaper norm editor, with Close
alone in its bar, does the same without the helper: above Large its bar shows
no title, and its first heading, «Норма в день», takes the header trait.

Screen titles go by fit. The nine scrolling screens with a large title
(Feeding, Sleep, Diapers, Events, Growth, Medications, Recent activity,
Export, the report) set it through `bbScreenTitle(_:)` and put
`BBScreenHeading` first in their content stack
(`DesignSystem/Components/BBScreenTitle.swift`). The bar sets a large title
on one line and cuts its tail, so `BBScreenTitleFit` measures the title's
line at the bar's face (largeTitle bold at the current size, capped at AX2)
against the bar's room, W − 32 below 414 pt and W − 40 from 414. The width
comes from a `GeometryReader` around the content, in the same layout pass,
so no frame shows one shape and then the other. Where the title fits, the
bar keeps its large title and the heading draws nothing, not even stack
spacing. Where it misses, the bar goes inline and the heading shows the
title: largeTitle bold, wrapping between words, stepping to title1 and
title2 while its widest word misses the width with sm 8 to spare
(`WidestWordIdeal`'s `spare`). The bar's principal item then holds a 17-pt
title, hidden (opacity 0, out of VoiceOver) until the heading's last line
has passed under the bar; the heading reports that through an environment
closure, from `onGeometryChange` in the modifier's named coordinate space,
whose y = 0 is the bar's bottom. The principal item stays in the bar while
hidden because an empty one lets the system draw its own inline title, cut.
`navigationTitle` is set in both shapes, for the next screen's back button
and the app switcher. CoreText measures a title about 3 % wider than the
bar draws it, so a few titles leave the bar a size before the bar would cut
them, never after.

The sheet bars' buttons are glyphs, through `BBBarButton`
(`DesignSystem/Components/BBBarButton.swift`): × for Cancel and Close in the
secondary ink, ✓ for Save, a pencil for Edit (the visit sheet's, and the
pushed medication screen's, which takes the same button). The New Feeding
sheet's confirm is ▶ (`.startFeeding`) while Start Timer is on, the same act
as its bottom button «Start Feeding», and ✓ when it is off; both follow the
toggle. On iOS 26 the bar draws each glyph in a glass circle and the confirm
(✓ or ▶) is the prominent one, a primary fill with an on-primary glyph,
dimmed by the system when disabled. Before iOS 26 the glyphs stand bare, the
confirm and Edit in the primary ink and a disabled Save in the secondary one.
Each button's VoiceOver name is the app's word (`button.cancel`,
`button.save`, `button.start_feeding`, `button.close`, `button.edit`), set
explicitly: a glyph's or a role's default name is read in the device's
language. Every other icon-only button in a bar names itself the same way:
the Feeding, Sleep, Growth and Events add buttons take their add sheet's
title, the Diaper one `diaper.add`. The norm editor's × is Close, because its
− and + write the goal at once; they carry `diaper.norm.a11y_decrease` and
`diaper.norm.a11y_increase` with the goal as their value, so VoiceOver reads
the new number after a tap. With a glyph on each side the title has 174 pt at Large on a
320-pt phone in every language, so a title of at most 166 pt at 17 pt
semibold stays whole there.

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
| `WHOGrowthStandard` | How big is this baby? Weight-for-age percentile from published LMS coefficients (0–24 mo); length-for-age in `WHOGrowthStandard+Length` (same LMS code path, its own denser grid), read by the pediatrician report (`DoctorReportSummary`). |
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
and `ExplainerSheet` renders any of them. Every insight card's header is
`InsightCardHeader` (the percentile card's hand-built one too). A title wraps
at the larger text sizes on a narrow screen, and the badge stays on its first
line, as a glyph beside wrapping text does everywhere in the app: a hidden
one-line box in the title's face carries that line's baseline, and the badge
is centred in it. Beside a one-line title that is where the centred badge
always sat.

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
`tone: .neutralOnly`. Its figure is the percentile itself,
`PercentileReading.badge` («61», «> 97», «< 3»), in `textPrimary` under
«Weight Percentile», and the two are one VoiceOver element; there is no band
word. The ring beside it draws the reading in its tier tint (`percentileTint`),
carries no number and is hidden from VoiceOver, because the figure states what
it pictures. The tone is the only behavioural difference: below the 3rd
centile or above the 97th the ring takes the neutral `textPrimary` instead of
`BBAlert`, while the figure is unchanged (DECISIONS 2026-09-21). It is one view
rather than two because a hand-copied card stating a clinical figure is a
drift this project has already paid for.

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

**Two paywalls, one selling half.** The selling half is two views in
`PlanPickerSection.swift` over one `PlanPickerState` (the selected plan and
whether the first product load returned), which the host owns:
`PlanPickerSection` holds the plans, prices, restore and legal footer and goes
inside the host's ScrollView; `PlanPickerCTA` holds the trial promise and the
buy button and goes *below* the ScrollView, so the button is on screen at
every text size up to AX2 (DECISIONS 2026-10-28). `PaywallView` (settings,
modal) and `PremiumPage` (onboarding, page 11) compose both. Each host shows
the CTA only while it is selling and the load did not fail; the section's
retry card stands alone then. The section has no
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
The one exception is a dose: while a medication runs, the Medication tile
branches in `addEvent(_:)` to the dose sheet before the gate and wears no
badge, because a dose given to a sick baby is never sold.
And **how far back the five activity lists read** — the free history window
below, the only gate that bounds something already recorded. The
pediatrician report's PDF is an export like any other: its share button wears
the badge and opens `PaywallView(source: .doctorReport)` for a free parent,
while the screen itself and visits stay free.

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
surfaces use. Pediatrician visits never go through it: Events
(`EventsHistory`) and Recent activity merge them in AFTER the window and the
cap (`Core/History/HistoryMerge`), so they are free and always listed, the
locked footer still means "entries older than 15 days", and Events' delete-all
reaches events only (its confirm says the visits are kept). Visit rows have no
swipe. A medicine's doses go through the window and have twenty rows of their
own: `EventsHistory` lists them apart and merges them back by time, so four a
day cannot push every bath and walk out of the shared twenty, and a year of
daily drops still draws a bounded list (the medication's screen lists every
dose). Each half decides its footer the usual way; delete-all still reaches
them, as events. It returns three things: `visible` (windowed, then capped),
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
at launch and never over the Dashboard. A medication's reminder switch asks
through the same `requestPermission` when iOS has not been asked yet; there
is no other call site.
`onAppForegrounded()` runs on every `scenePhase == .active`, and
`onAppBackgrounded()` on every `.background`.

**Weekly summary.** Last calendar week, Monday to Sunday whatever the
locale, is `Core/Weekly/WeeklySummary` — pure, fed by
`WeeklySummary.Input` (built from the Dashboard's queries, or fetched for the
notification). Averages divide by the days that have any entry: a day with
nothing logged is a gap in the log, not a day without feeds or sleep. The
card's days line says so on every week, a full one too («Averages over the
days with entries: 7 of 7»). The gain is a rate in g/week, the
`WeightVelocity` pair whose later weighing falls in the week, so it is the
number Growth shows. Without such a pair the line says what is missing
(`WeeklySummary.missingPair`), judged on every weighing up to now and in this
order: a pair ending after the week shows next Monday, so the line offers
nothing; a pair that ended before the week, weighings with no pair, and no
weighing at all each have their own line and the «Add a weighing» button. A
pair ending after the week but inside the newborn window takes the older
pair's line and button, since next Monday's card withholds it too.
The newborn gate (`NewbornWeightLoss.gainDeferral`)
withholds it (DECISIONS 2026-09-05, «During the newborn window, no surface
reports a weight-gain verdict»). The Dashboard shows `WeeklySummaryCard` under
the running timers. It is hidden per week by × (`weekly.hiddenWeek`, the Monday as `yyyy-MM-dd`, local)
and sends `weekly_summary_viewed` once a week. × fades the card, in 0.2 s (no
fade with Reduce Motion), to `WeeklyHiddenLine` on the card's own surface: the summary is hidden until next
Monday, and «Undo», which clears the hide and brings the card back collapsed.
Each week's card opens collapsed: the open state is the Monday it was opened
in (view state), so the same card handed the next week's summary, by an app
left running across Monday 00:00, shows that week collapsed, a card hidden
while open too. The line is view state, never stored, with no timer: it lasts while the
Dashboard stays on screen and is gone after another tab, a pushed screen or
the app in the background, while the card stays hidden until Monday. When an
arrow shows, one legend line under the rows says the arrows compare with the
week before; VoiceOver skips it, since each row speaks its comparison in
words. The Monday notification is a
ONE-SHOT for the next Monday 10:00 under the old id, re-planned on every
foreground and background, and after the Lock Screen and widget intents' own
writes (no scenePhase change there), by `WeeklyNotificationPlan`, and only when the reported week has
entries and the Settings switch (`notify.weeklySummary`, on by default) is on.
Off stops the notification only; the card still shows. A repeating trigger
cannot skip an empty week. `AppClock.now` is the clock for
this path only, so `-BBNow` can move it.

**Medication reminders.** One pending request per medication,
`bb.med.<uuid>`, while this device's switch for it is on
(`notify.medication.<uuid>` in `UserDefaults`, off when absent, never
synced). `MedicationReminderPlan` (pure, `Core/Medicine`) wants it at the
schedule's `nextAllowed`, the 24-hour maximum included, only while that is
ahead and the course runs. `MedicationReminderSync` (`Services`) makes the
centre agree: it removes every `bb.med.*` the plan does not want (a switch
off, a course ended or past its time, a medication deleted here or on
another device) and adds each wanted one again, which replaces it. A pass
runs at once after every local store save (`ModelContext.didSave`), so no
surface that logs, moves or deletes a dose calls it, and after every
`NSPersistentStoreRemoteChange`, debounced 0.5 s for CloudKit's bursts; also
on every foregrounding, on backgrounding (holding a background task until it
lands), after a switch changes, and when notifications are allowed.
Passes are serialized, so the last one, read from the freshest store, lands.
The trigger is a time interval (elapsed time, like the interval itself); the
content has the default sound, no badge and the plain interruption level.
The title is the name; the body (`MedicationFormat.reminder`) is the time
since the dose it counts from, with that dose's time and its day word
counted against the moment it fires. `NotificationPermission` holds iOS's
answer (not asked, allowed, denied) for the switches: denied draws the
switch off and disabled with «Open Settings», like the Live Activity
switch. The switch sits in the medication form (stored on Save) and in a
card on the detail (at once); the list row shows a bell while it is on,
except on an ended course and while iOS has notifications off. With no
`UNUserNotificationCenter` delegate in the app, a reminder that comes while
the app is open is not shown; the medication's screen states the same fact.

## Timers and the Live Activity

A running feeding or sleep timer is an entry with `endTime == nil`. It shows on
the Lock Screen and in the Dynamic Island as a Live Activity with a Stop button
(free, on by default, Settings › Notifications › "Timer on Lock Screen").

**One mutation path.** Every timer start, stop, side change and delete goes
through `Services/TimerActions.swift`: the Feeding and Sleep screens, Recent
activity, the Stop intent and the widget's Start feeding button
(`StartFeedingIntent`, see Navigation). Each call saves, reloads the widget,
fires the matching `NotificationManager` hook (a side change has none) and then
`TimerActions.afterChange`, which reconciles the Live Activity. The add-feeding sheet keeps its own insert but
calls `afterChange` too. The review prompt stays in the views: a Lock Screen
stop never asks.

**Reconciled, never pushed.** `LiveActivitySync.reconcile()` reads the running
entries and `Activity<TimerActivityAttributes>.activities`, then executes what
the pure `LiveActivityPlanner.plan` returns. `LiveActivityPlannerTests` pin the
rules:
- one activity per kind, for the newest running entry;
- update the title when the side changes;
- a stopped entry ends with "Saved · N min" (the store's title), dismissed after 15 min;
  its content carries `relevanceScore` 0 against a running one's 100, so iOS
  keeps a running timer above a newer Saved card (design note § 2);
- a deleted entry, the switch off, iOS off or an iPad end it at once;
- no start for a timer aged ≥ 8 h; an activity iOS ended at ~8 h (still on the
  Lock Screen) gets the same final content once its timer stops;
- one start per entry (`liveActivity.startedEntryIDs`), so an activity the user
  swiped away does not come back. A closed gate forgets them all
  (`LiveActivityPlanner.remembered`), so the switch or iOS turning back on shows
  the running timer again. iOS toggled off and on while the app was not running
  cannot be told from a swipe: that timer stays without an activity.

ActivityKit calls run one at a time in a queue (`LiveActivitySync.enqueue`), so
quick side changes and a stop land in order; `settle()` waits for it. The Stop
intent awaits `settle()` before returning, since iOS may suspend a background
launch right after.

It runs after every mutation, on launch, on every foregrounding, on
`NSPersistentStoreRemoteChange` (debounced 1 s) and when the iOS permission
changes. With no push (no aps-environment, no server), a stop made on another
device reaches this Lock Screen when the app next runs here. That limit was
accepted for 1.1.0.

**Stop runs in the app.** `StopTimerIntent` is a `LiveActivityIntent`, compiled
into both targets because the extension's `Button(intent:)` needs the type.
Its body is compiled only into the app (`LIVE_ACTIVITY_APP`, set on the app
target in project.yml); the system runs it in the app's process, sometimes in a
background launch with no scene. That is why the store is one
`SharedStore.container` per process, and why `reconcile()` reads the iOS
permission fresh instead of trusting `start()` to have run. A stop on an entry
that is already stopped or gone writes nothing (`TimerActions.stop` returns
false) and just ends the activity.

**States.** `staleDate = start + 8 h`. When stale, or after the system's ~8 h
cut-off, the views show no digits, only the start time and "The timer goes on
in Bitty". The elapsed time is `Text(timerInterval:)`, drawn by the system, so
it never freezes. Views live in `Features/LiveActivity/` (both targets; they use
only `Color("BB…")` and system text styles, since `BBTheme` is not in the
widget). `LiveActivityRenderDump` renders every state, but only the simulator
shows the real Island (see knowledge: expanded regions and `fixedSize`). Levers:
`-BBSeedScenario runningLongFeed` / `runningBottle`, ids `settings.live_activity`,
`timer.card.feeding`, `timer.card.sleep`. Logs: subsystem `com.nenita.app`,
category `LiveActivity`.

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
| `paywall_shown` | `source`: `onboarding` \| `settings` \| `history_lock` \| `locked_card` \| `events` \| `doctor_report` | `PremiumPage` / `PaywallView`, once StoreKit has answered AND the parent is not premium — a subscriber who opens the settings row sees the badge, not an offer. `PaywallView(source:)` has no default, so every presentation site names one |
| `plan_selected` | `plan`: `weekly` \| `monthly` \| `yearly` | `PlanPickerSection`, on a CHANGE of plan |
| `purchase_result` | `plan`, `result`: `success` \| `cancelled` \| `failed` \| `pending` \| `already_subscribed` | `SubscriptionManager.purchase`, each branch once, BEFORE `refreshEntitlements()` publishes — so it precedes `onboarding_completed`. `already_subscribed` is StoreKit's `.userCancelled` for an Apple ID that owns a plan. An Ask to Buy approved later arrives only via `Transaction.updates`: the listener reports `success` once for a plan the facade saw go `.pending` (`analytics.pendingPurchasePlans`, plan → when), and only for the parent's own purchase (`ownershipType == .purchased`, not family-shared), dated at or after that moment, with `tx.reason == .purchase`; the next purchase attempt and any restore clear the marker |
| `restore_result` | `result`: `found` \| `not_found` \| `failed` \| `cancelled` | `SubscriptionManager.restorePurchases` |
| `paywall_closed_x` | `seconds_visible` | the X of either paywall (not a swipe-down), once per paywall shown |
| `first_entry` | `kind`: `feeding` \| `sleep` \| `diaper` \| `growth` \| `event` | `ReviewPromptTrigger.entrySaved(_:)` → `Analytics.noteEntrySaved`, once per kind per install (`analytics.firstEntryKinds`); an install already past onboarding when analytics arrives is seeded with every kind, so it reports no firsts |
| `daily_activity` | `feeding`, `sleep`, `diaper`, `growth`, `event`: Bool (logged at all); `total`: `0` \| `1-5` \| `6-15` \| `16+` | `Analytics.appBecameActive` (and `start`) at the first foregrounding of a new local day, for the PREVIOUS day only, once (`analytics.dailyActivityDay`). `DailyActivityCounter` counts that day with one `fetchCount` per kind; the facade reduces the counts to presence plus one total bucket — no per-kind count, and edges clear of the clinical 8–12 feeds a day. Sent with the event time set to NOON of the reported day (local) and `sessionId -1`, so neither the time nor a session id gives away the first open after midnight. Nothing for a store with no baby; the first launch only sets the marker. The store is CloudKit-synced, so this is the baby's logged day across the family's devices, not this install's own usage. A time-zone change can make two consecutive reports cover overlapping hours — acceptable noise for a bucketed aggregate. There is deliberately no per-entry event (DECISIONS 2026-09-23) |
| `notification_permission` | `granted` | `NotificationsPage`, the system dialog's answer only |
| `widget_installed` | — | `Analytics.appBecameActive` via `WidgetCenter.getCurrentConfigurations`, asked at most once a local day (`analytics.widgetProbeDay`), reported once per install |
| `history_lock_shown` | `surface`: `feeding` \| `sleep` \| `diaper` \| `events` \| `recent_activity` | `BBLockedHistoryFooter.onAppear` → `Analytics.noteHistoryLockShown`, at most once per surface per local day (`analytics.historyLockDays`) — on insertion into a (non-lazy) list, not on scroll; a footer built with no `surface` (a medicine's doses) sends none |
| `review_prompt_requested` | — | `ReviewPromptService.consumePendingSave`, when a request is made |
| `live_activity_started` | — | `LiveActivitySync.reconcile`, only when `Activity.request` succeeds (not on a reconcile that finds it running) |
| `live_activity_stopped_from_lock_screen` | — | `StopTimerIntent.perform`, only when the tap actually stopped a running timer; sent from a background launch, so it may upload on a later launch |
| `widget_feeding_logged` | — | `StartFeedingIntent.perform`, only when the widget's button actually started a feed (not when one was already running); background launch, as above |
| `weekly_summary_viewed` | — | `WeeklySummaryCard.onAppear`, once per calendar week per device (`weekly.viewedWeek`, set only when the event was sent) |

Every event also carries `build_channel`. `Resources/PrivacyInfo.xcprivacy`
declares Product Interaction, Device ID and Purchase History (Analytics) and
Crash Data plus Other Diagnostic Data (App Functionality, for the remote
diagnostics residual), none linked, none tracking. Keep it, this section and
the App Store Connect answers in step.

## Navigation

`MainTabView` — five tabs: Home, Feeding, Sleep, Diapers, More. Growth,
«For the pediatrician», Recent activity, Events and Profile live under More
rather than in the bar;
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

**«For the pediatrician»** (`Features/DoctorReport/DoctorReportView`, 1.2.0)
comes right after Growth in More. Top to bottom: the name ①, the period line
(②, tap → the visit detail), the age ③, the questions card (④ open
questions, add, log the visit; ⑥ the questions asked at the latest visit,
«Back to the list»), the data cards ⑦ and the footnote ⑧. The numbers
come from `DoctorReportSummary` (`Core/DoctorReport/`), pure and built from
plain values through its store bridge, over `[periodStart, AppClock.now)`.
It feeds `PeriodSummary` (`Core/Summary/`), the calendar-day core the weekly
card also runs on, with the REPORT's input: running timers out and a sleep
that began before the period clipped to it — the weekly card counts a running
feed and files a sleep whole on its start day, so those rules live in what
each caller passes in, never in the core. The share button ⑩ (Premium) makes
`DoctorReportPDF`: an HTML page over the SAME `DoctorReportSummary` and the
same `ReportFormat` / `WeeklyFormat` helpers (`Core/Formatting/`, shared with
the export and the weekly card), so the PDF cannot print a number
the screen does not; `DoctorReportPDFTests` pins that as strings, and scans
the page for a closed list of verdict words. Medications given in the
period (`summary.medications`: a medicine's doses together, older events by
their trimmed, case-insensitive name beside them, nameless ones in one line;
each line's doses grouped again by dose text in order of first use, so a
changed dose shows one caption, and in the PDF one row, per text) are a card
after Diapers and a fixed-column table after the PDF's diapers section. Both
are absent when no dose falls in the period. A dose counts as an entry
for the new-period card, and the table moves to the next page whole when
it fits on one. It renders through `PagedPDF`
(`Features/Export/`), which the export shares. `UIMarkupTextPrintFormatter`
slices its layout at the page height and ignores the CSS break rules, so a
document hands over its blocks and rows, every page is composed as its own
small HTML document with its own formatter, and the engine's page count says
what fits: rows move whole, a table prints its head on every page it reaches,
and a document that fits one page is laid out once, as it is. Each page's table
would size its own columns, so their widths are fixed in advance: the export's
from all of a table's rows (`ExportGenerator.columnWidths`). The report's own
`UIPrintPageRenderer` subclass draws the footer (brand · name · period, «Page
N of M») on every page. Both PDFs print in Helvetica Neue with a named fallback
list and no colour emoji, the footer included (DECISIONS 2026-11-02).
`PDFPagesTests` reads rendered files back with PDFKit to pin all of it.
The button has no `@Query` of its own: `DoctorReportSummary.Input.load`
fetches with `Input.window(periodStart:)`, the same window
`ReportDataSection`'s queries use. Every PDF prints numbers in the app
language; every CSV stays dot-decimal with units in its headers (DECISIONS
2026-11-02). A file name cleans and caps the baby's name alone
(`ExportGenerator.fileNamePart`), and `ExportGenerator.fileName(fitting:_:)`
lets that name give way, a whole character at a time, until the whole fits
the 255 UTF-8 bytes a file name may take: the day and the extension always
stay. The Export PDF is «All entries – Mia – 2026-11-05.pdf», the report
«Pediatrician report – Mia – 2026-11-05.pdf» (DECISIONS 2026-11-06). A
visit is changed in ONE place, `VisitDetailSheet`, presented everywhere
through `.visitDetailSheet(item:)` — from the period line, Events and Recent
activity. That modifier deletes in the sheet's `onDismiss`, after the sheet
is gone: deleting while a sheet still holds the model makes its body read a
deleted model ("backing data could no longer be found"). The question sheet
follows the same rule in the report screen. The doctor sheets are plain
`.sheet`, never `.entrySheet` — no rating prompt over a question for the
doctor (DECISIONS 2026-11-01).

**Deep links.** `nenita://tab/<home|feeding|sleep|diapers>`
(`Features/Widget/DeepLink.swift`, shared with the widget) selects a tab. The
`onOpenURL` sits on the app root, not on `MainTabView`: a cold launch shows the
~5 s splash first, and a URL that arrives while no view listens is dropped. The
root keeps the destination, and `MainTabView` takes it when it appears (or at
once, when it is already up). Before onboarding is done a link just opens
onboarding and is not kept. The widget's tap areas build these URLs. The
scheme is registered in Info.plist only so that `xcrun simctl openurl booted
nenita://tab/sleep` works for testing; a widget link would reach its app without it.

**The widget's tap areas, and its one button, which starts a feeding timer**
(`teamdocs/design/m1-live-activity.md` § 5):
- **Small:** the whole widget opens Feeding (`widgetURL`). WidgetKit ignores a `Link` in this family, so only the capsule's button is a separate target.
- **Medium:** the left column and the feed row open Feeding, the sleep row opens Sleep (each a `Link`). The feed row hides while a feed runs, since the capsule already shows its minutes. The rows are 30–40 pt: they take layout priority over the spacer, so the smallest medium widgets (SE, 10.2" iPad) shrink them rather than overflow.
- **The capsule:** with no feed running, it is `Button(intent: StartFeedingIntent())`. That is a `LiveActivityIntent`, so it runs in the app's process, where the store is synced and `TimerActions` exists, and the Live Activity may start from the background. It calls `TimerActions.startFeedingFromWidget`, a left breastfeed that does nothing while any feed runs or before onboarding has created a Baby. While a feed runs, the capsule is a `Link` to Feeding (medium) with the feed's glyph and whole minutes. With no Baby yet (`entry.hasBaby == false`) it looks idle but only opens the app.
- **The onboarding showcase** renders the same view with `isInteractive: false`, so a tap there starts nothing.

The widget writes time since an event in whole days from 48 hours, rounded
down, as Home's Today tile does (`WidgetCopy.elapsedText`): the medium's feed
row, the hero past 12 months and the overdue line («Прошло ещё 4 дня»).
«131 ч 5 мин» left the reader to divide. A duration keeps its hours and
minutes (`WidgetCopy.minutesText`): a running feed in the capsule, a running
or finished sleep, the countdown to the next feed and the Live Activity's
ended timer.

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
| `-BBSeedScenario <name>` | **Simulator only.** Wipes the database and seeds one deterministic fixture (`lowGain`, `healthy`, `sparseLogs`, `newbornWindow`, `newbornStalePair`, `showcase`, and two with RUNNING timers for the Live Activity: `runningLongFeed` — a left breastfeed at 7 h 58 min plus a 40 min nap, `runningBottle` — a 12 min formula feed; seven for the weekly card, built from `AppClock.now`: `weeklyNormal`, `weeklyFirstWeek`, `weeklyGaps`, `weeklyNewborn`, and three for its gain line without a pair, each `weeklyNormal` with other weighings — `weeklyOneWeighing` (one, in last week), `weeklyWeighedThisWeek` (last week's one plus one an hour before now, or at the week's end in Monday's first hour), `weeklyOlderPair` (a pair in the week before only); and five for the pediatrician screen, also from `AppClock.now`: `doctorMonth` — one visit 20 days ago with 2 asked and 3 open questions, `doctorNoVisit`, `doctorVisitToday`, `doctorTwoVisits` — two visits on one date plus an older one logged late, `doctorEventsCap` — `doctorMonth` plus 24 events (31 inside the free window) and a second visit on day 4, past the free list's 20-row cap. All five share a base of 10 weighings, 182 feeds, 41 sleeps, 140 diapers and 15 baths; the totals are pinned by `SeedScenarioDoctorTests`; and `medsTwoCourses`, also from `AppClock.now`: paracetamol every 6 h with a 24-hour maximum of 4, its latest dose two hours ago, so the next is still to come; vitamin D once a day, its latest 26 hours ago, so allowed now; and two medication events from before medicines, one named and one bare, pinned by `SeedScenarioMedicineTests`). An unrecognised name logs the valid ones and calls `fatalError` — a typo fails the run instead of quietly testing against the previous fixture's leftovers. |
| `-BBNow <ISO 8601>` | **Simulator only.** Pins `AppClock.now` (e.g. `2026-10-26T00:00:00`, local time), which the weekly card, the Monday notification, the weekly, doctor and medicines seeds, the pediatrician period length, the visit date's default and upper bound, the Today tile's «last feed … ago», and the medication screens (status lines, a dose's default time and the picker's upper bound, a course's end date, the confirmation), and the Add Event form's default time and its Medication bound read; nothing else moves. A value that does not parse calls `fatalError`. |
| `-BBWeeklyNotifyIn <s>` | **Simulator only.** Schedules the weekly notification N seconds out, whatever the week holds, so its banner can be looked at. |
| `-BBLogPendingNotifications true` | **Simulator only.** On every foreground, and after each medication reminder pass, logs each pending notification request and its next fire date (category `Notifications`), so a reminder's delivery time is read rather than waited for. |
| `-BBMedicationNotifyIn <seconds>` | **Simulator only.** Every pending medication reminder fires in N seconds instead of at its time, with the words of its real time, so the banner can be looked at. |
| `-BBForcePremium true` | **Simulator only.** Renders the paid branch. Without it, an assertion on a gated card passes whether the paid card works, throws, or renders blank — the half of the app people pay for would be structurally untestable. |
| `-BBFailProductsOnce true` | **Simulator only.** The first `loadProducts` of the process fails exactly like a real load failure (so the paywall's retry card shows); the retry succeeds. Use it on an onboarded (seeded) run from Settings → Premium: onboarding loads products on its first page, which spends the one failure unseen. |
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
- [docs/README.md](docs/README.md) — the docs map: every doc with its kind,
  owner and status; closed subjects sit in `docs/archive/`.
- `docs/release/` — Apple Developer and App Store Connect setup.
- `docs/naming/` — how the three brand names were chosen.

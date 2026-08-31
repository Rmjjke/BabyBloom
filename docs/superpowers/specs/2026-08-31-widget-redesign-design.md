# Widget redesign — design

Date: 2026-08-31
Task: `.desk/tasks/widget-redesign/`
Scope: the two home-screen widgets only. Interactive buttons, deep links,
Lock Screen families and the in-app "how to add a widget" screen are three
separate follow-up tasks, agreed with the owner on 2026-08-31.

## The question this answers

The widget currently reports what already happened: "16 min ago", "Feedings:
0", "Sleep 0 min". A parent glancing at a home screen is not asking what
happened — they are asking **how long until the next feed**. The app already
computes that: it is the same interval the feeding reminder is scheduled on.
The widget just never had access to it.

Second, the widget looks broken, and one part of that is an actual defect
rather than taste. See "The container defect" below.

## Scope decisions (settled with the owner, 2026-08-31)

1. The hero figure is **time until the next feed**, from the same interval
   logic the notifications use — so the widget and the push can never
   disagree.
2. With no entries, the widget shows an **invitation** ("log the first
   feeding"), not dashes and zeroes. An empty widget is a normal first day.
3. The palette comes from the **brand colorsets**, with a widget-side copy
   guarded at build time — the same arrangement the localization JSONs
   already use.
4. The baby's name is dropped from the **small** widget and kept on the
   medium one.
5. Not in scope: interactivity, deep links, Lock Screen, configuration.

## The container defect

`BabyBloomWidget.swift` gives the container `.containerBackground(.fill.tertiary,
for: .widget)` while `WidgetViews.swift` paints the brand gradient as a
`.background(...)` on the inner `HStack`. The gradient therefore sits inside
the system's content margins with square corners, and the container's own
background — near-black in dark mode — shows around it as a frame.

Fix: the gradient becomes the container background; the inner `.background`
is removed. This is what makes the widget fill its own shape.

It is worth naming why no existing check caught this. `WidgetRenderDump`
renders the widget *views*, not the widget *container*: in-process there is no
`containerBackground` and no content margin, so the dump shows the gradient
edge-to-edge and looks correct. Only a widget placed on a real home screen
shows it. That is why AC1 is verified by a run-and-look and not by the dump.

## Domain core — `FeedingRhythm`

A new pure type in `BabyBloom/Core/Feeding/FeedingRhythm.swift`, following the
shape of `Core/Growth`: no SwiftData, no SwiftUI, no model context, directly
constructible in tests.

It takes over three pieces of arithmetic that currently sit as instance
methods on `NotificationManager`:

- `interval(ageMonths:)` — the age table (0 → 2.5 h, 1–2 → 3 h, 3–5 → 3.5 h,
  6–8 → 4 h, 9–11 → 4.5 h, **12+ → nil**).
- `interval(ageMonths:recentFeedings:)` — the adaptive form: with three or
  more recent feedings, the average logged gap plus a 10-minute grace;
  otherwise the age table.
- `nextFeed(afterLastFeedingAt:ageMonths:recentFeedings:) -> Date?` — the value
  the widget needs; the first argument is the most recent logged feeding.
  `nil` means "do not predict", and it happens for two distinct reasons: no
  feeding logged yet, and 12+ months.

`NotificationManager` keeps its public methods and delegates to
`FeedingRhythm`, so notification behaviour is unchanged and its existing tests
keep passing. The extraction is what lets the widget target use the same
arithmetic without importing a `UNUserNotificationCenter`-bound service.

**The nil case is load-bearing.** At 12+ months the app deliberately stops
telling parents when to feed; a widget that invented a due time there would
contradict a considered product decision. Where `nextFeed` is nil the widget
falls back to elapsed time since the last feed.

## What each size shows

### Small (`systemSmall`)

```
┌──────────────────┐
│ 🍃 Feeding in    │   caption, secondary
│                  │
│   1 h 12 m       │   hero, live countdown
│                  │
│ ♥ 6 today   ☾    │   footer strip
└──────────────────┘
```

The baby's name is dropped here: at 158×158 pt it costs a line that the hero
needs, and the owner of the phone knows whose baby it is. The one exception is
the empty state below, where there is no hero to protect and the name is what
tells the parent the widget is theirs and working.

The footer's moon appears only while a sleep timer is running; there is no
"awake" glyph, because a widget that always shows an icon teaches nobody to
read it.

### Medium (`systemMedium`)

```
┌───────────────────────┬───────────────────────┐
│ Feeding in            │  ♥  Last feed         │
│                       │     1 h 12 m ago      │
│   1 h 12 m            │                       │
│                       │  ☾  Sleeping          │
│ Vlad                  │     1 h 3 m           │
└───────────────────────┴───────────────────────┘
```

The vertical hairline divider is removed; the two blocks are separated by
space. When a sleep timer is running the sleep row reads the live duration of
the current sleep rather than the length of the previous one — that is the
fact a parent handing over a shift needs.

### States

| State | Small | Medium |
|---|---|---|
| Normal | countdown hero | countdown hero + last feed + sleep |
| Due / overdue | "Time to feed" in place of the countdown, tinted `BBAccent` | same, plus how long overdue |
| No feeding logged yet | name + "Log the first feeding" | name + "Log the first feeding" across the full width; the two-column split is not drawn at all |
| 12+ months | elapsed since last feed, labelled as elapsed | same |
| No baby yet | existing placeholder entry, unchanged | unchanged |

"Due" is the moment `nextFeed` passes. There is no separate warning styling
beyond the accent tint: this app does not alarm parents about feeding (see the
`FeedingAdequacy` rule in `DECISIONS.md`), and a red widget would break that.

## Staleness, and why the countdown stays honest

The timeline reloads about every 15 minutes. A countdown rendered as a plain
string would therefore be wrong by up to 15 minutes almost all the time.

The timeline entry carries the **date** of the next feed, not a formatted
duration, and the view renders it with `Text(_:style:)`. WidgetKit updates
those in place every minute without a timeline reload. The 15-minute cadence
then only governs how fresh the underlying data is (a feeding logged on
another device, the sleep state), never the number on screen.

`Text(_:style:)` keeps the NUMBER right, but not the WORDING: "Feeding in"
has to become "Time to feed" the moment the feed falls due, and no amount of
in-place re-rendering changes a label. The timeline therefore carries a second
entry dated exactly at `nextFeed`, so the widget flips at that minute without
polling for it. (Refinement found while writing the implementation plan,
2026-09-01.)

The app already calls `WidgetCenter.reloadAllTimelines()` on a language
change. This design adds a reload after a feeding or sleep entry is saved or
deleted, so the widget reflects an action taken in the app immediately rather
than up to 15 minutes later.

## Palette — a second, guarded catalog

The widget target has no Asset Catalog and does not compile `DesignSystem/`.
That is why its gradient is two hex literals, why it has no dark variant, and
why `Color(hex:)` is duplicated into the extension.

The literals are also simply wrong: the widget uses `#6B5EA8 → #B08ED8`, which
is README's documented palette, while the catalog holds
`BBGradientStart #6F5BA8 → BBGradientEnd #A795D9` with distinct dark values.

**Chosen approach:** a widget-only catalog at `WidgetResources/Colors.xcassets`
holding the colorsets the widget uses, declared in the widget target's
`sources` with `buildPhase: resources`, and covered by an extension of the
existing pre-build sync script so a drift from the app's catalog fails the
build.

**Rejected:** adding `BabyBloom/Resources/Assets.xcassets` to the widget
target. That path is inside the tree the app target already scans, which is
precisely the situation that once made XcodeGen dedupe the file references and
ship an `.appex` with no Resources build phase at all — the widget then
rendered raw i18n keys. The trap is recorded in `.desk/knowledge.md`; the
localization JSONs live at a distinct path for exactly this reason, and the
colours will follow that precedent rather than re-test the trap.

**Rejected:** a shared Swift constants file. It would work and needs no
guard, but it puts the palette back into source, against the standing decision
that re-theming is a colorset edit with no code changes.

Typography stays as explicit sizes with `minimumScaleFactor` rather than
adopting `BBTheme.Typography`: widget canvases are fixed and small, the app's
type scale is built for scrollable screens, and Russian and Spanish strings
already need the scale factor at these sizes.

## Documentation to correct

The investigation found the documented palette contradicting the shipped one
in three places. These are corrected in the same PR, because the palette is
this task's subject:

- `README.md` — the design-system table lists `#6B5EA8` and a "powder pink"
  accent `#E8A0BF`; the catalog holds `#6F5BA8` and a peach `~#E8B49B`.
- `BBTheme.swift` header comment — "sage/mint palette", from an older theme.
- `CLAUDE.md` — the same "sage/mint" phrase.

Per the upkeep rule added in PR #21, `ARCHITECTURE.md` gains the widget's
palette arrangement, and `DECISIONS.md` gains the guarded-second-catalog
decision with its reason.

## Testing

**Unit — `FeedingRhythmTests`:** the age table at each boundary (0, 1, 2, 3,
5, 6, 8, 9, 11, 12), the nil at 12+, the adaptive interval with 3+ feedings
including the 10-minute grace, the fallback below 3 feedings, and `nextFeed`
returning nil for both distinct reasons.

**Regression — `NotificationManager`:** its existing tests must pass
unchanged. That is the evidence the extraction did not alter notification
behaviour.

**Render — `WidgetRenderDump`, extended:** both sizes × three locales × two
themes × the five states in the table above. This catches truncation, which is
how the Russian string defect was found last time.

**Run-and-look:** both widgets placed on a simulator home screen, shot in
light and dark. This is the only check that sees the container defect, and it
is the acceptance evidence for AC1.

## Out of scope, deliberately

- Interactive buttons (`AppIntent`) — follow-up task 2, with deep links.
- Deep links from a widget tap — follow-up task 2.
- Lock Screen / Smart Stack families and relevance donation — follow-up 3.
- In-app "how to add a widget" screen — follow-up 4.
- Widget configuration (`AppIntentConfiguration`) — not requested; there is
  one baby, so there is nothing to configure.

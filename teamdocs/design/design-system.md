# Design system — BabyBloom (Bitty / Ночка / Nenita)

status: baseline — describes what `main` ships at 10cf1a9 (2026-10-28); updated
2026-10-28 with the stool-colour exception (G3), the contrast floor (P8) and the
M1 token BBOnPrimary; § 2 and G16 follow the export PDF of 2026-11-02; on
2026-11-03 BBOnPrimary and the Live Activity are in force as shipped in 1.1.0,
and the colorset counts and the re-theme list follow the code. Also on
2026-11-03: the primary button's ink for 1.3.0 (G1), the platform red as the
destructive red (§ 2, G4) and G9 follow the 1.2.0 code; the accent ink
BBOnAccent, the stool check and the White and Black swatches' edge for 1.3.0
(G18, G19, G20) follow the code of the same day, and so do the
accessibility-size layout rule (§ 3), the field-label helpers and the sheet
heading (§ 7), and the fixed-size words of the entry sheets and the stat card
growing with fewer columns, `BBStatGrid` among them (§ 3, § 7, G2). The
column rule is checked at 320 pt and at every text size; the counts it sets,
with two measured exceptions to its spare, and the profile sheet's rows and
title follow the code of the same day (§ 3, § 7, `BBTileColumns`). Sheet
titles in the content from xLarge, the pickers' labels above at every size,
the wrapped alignment at Large and the quick rows' one column at accessibility
sizes are proposed (§ 3, § 7); sheet titles at Large on 320 pt are a gap (G21).
Every value marked `in force` is in code, in `DECISIONS.md` or in a product
decision stated here with its reason; `planned` means decided, not shipped yet. Gaps are notes
(§ 10), not fixes.
sources: `BabyBloom/Resources/Assets.xcassets/Colors/`, `BabyBloom/DesignSystem/`,
`DECISIONS.md`, `docs/design/`, `README.md#дизайн-система`.
surface notes: `teamdocs/design/m1-live-activity.md` (Live Activity, widget controls).

## 1. Principles

triggers: a new product decision or DECISIONS.md entry about colour, copy tone, gates or accessibility
check: none — principles are read against DECISIONS.md at review, not measured

Character: soft lavender femtech — pastel tints, rounded surfaces, diffuse
shadows tinted in the brand hue, rounded SF for body and digits, straight SF
semibold for headers.

| # | principle | status | source |
|---|---|---|---|
| P1 | **Calm rule.** The app never frightens a tired parent: no alarming colour, icon or copy unless something genuinely needs raising with someone. A count above its reference is reassurance, never red, flagged or triangled; fast gain takes the neutral primary tint, not the green tick. Red (`BBAlert`) means only "raise this with someone": growth flags and the tails of the percentile chart — never a count. The platform's destructive red marks only a delete (§ 2). **One by-design exception:** the stool-colour warning in DiaperView (orange + triangle, G3). | in force | DECISIONS 2026-09-05 "A count above its reference is never styled as an alarm"; DECISIONS 2026-09-22 (rating prompt blocked by the calm rule); product decision 2026-10-28 (G3) |
| P2 | **Locked is not wrong.** A paywall gate is drawn in the calm primary tint (`primary@0.08` fill, `lock.fill`), never alarm red — nothing was lost. | in force | `BBLockedHistoryFooter` |
| P3 | **Gate visible before the tap.** Every gated control carries `LockBadge` and says "locked" to VoiceOver (`bbLockedAccessibility`). A free-looking control that answers with a paywall is a bait-and-switch. | in force | `LockBadge`, `BBQuickActionButton.locked` |
| P4 | **Paywall gates seeing, never deleting.** Delete reaches every row in range, hidden ones included, and the confirmation says so. | in force | DECISIONS 2026-09-01; `BBDeleteHistoryButton` |
| P5 | **Colours only through the Asset Catalog** (`BBTheme.Colors`); never a literal in a view. Re-theming = colorsets + the widget's copies + the two splash PNGs + the hex constants of `ExportGenerator` and of `DoctorReportPDF` (§ 2 "Outside `Colors/`"). | in force | DECISIONS 2026-07-21, 2026-09-01 |
| P6 | **Dynamic Type through `BBTheme.Typography`**, ceiling AX2 (`accessibilityLarge`) in one constant. | in force | DECISIONS 2026-08-28 |
| P7 | **One-handed at night.** Primary "add" sits in the thumb zone (`BBFab`, bottom-trailing); tap targets ≥ 44 pt. | in force | `BBFab`, `BBLockedHistoryFooter`, `DiaperView` |
| P8 | **Contrast floor (WCAG 2.2 AA):** text ≥ 4.5:1 against its fill; ≥ 3:1 for text ≥ 18.66 pt bold / 24 pt regular and for non-text UI that carries meaning (icons, rings, borders). New surfaces are held to it; existing violations go to the backlog, not to blockers. | in force | product decision 2026-10-28: WCAG 2.2 AA is the review bar |

## 2. Colour tokens

triggers: a colorset added, removed or re-valued; a `BBTheme.Colors` member added
check: `ls BabyBloom/Resources/Assets.xcassets/Colors | sed 's/.colorset//'` → the 19 names below; `grep -o 'Color("BB' BabyBloom/DesignSystem/BBTheme.swift | wc -l` → 17 (BBLaunchBackground and BBSplashText are read by `SplashView` directly)

All sRGB, light (`any`) / dark (`luminosity: dark`).

| colorset | Swift | light | dark | role |
|---|---|---|---|---|
| BBPrimary | `Colors.primary` | #6F5BA8 | #A795D9 | brand violet: primary buttons, FAB, links, selected states, calm gates, shadow hue |
| BBOnPrimary | `Colors.onPrimary` | #FFFFFF | #171420 | **in force since 1.1.0** (decided 2026-10-28) — label and glyph colour on any filled BBPrimary surface. Shipped with the Live Activity (its button capsule, `TimerActivityViews.swift`) and copied to the widget catalog; from 1.3.0 it is the ink on every BBPrimary fill: `BBPrimaryButton`, the `BBFab` "+", the selected `BBHistoryFilterPicker` chip and the other places G1 lists |
| BBAccent | `Colors.accent` | #E8B49B | #EFBFA6 | warm peach accent (also copied to the widget) |
| BBOnAccent | `Colors.onAccent` | #171420 | #171420 | **from 1.3.0** (decided 2026-11-03) — text on a BBAccent fill: the plan picker's savings badge (`PlanPickerSection.swift:181`), on the paywall and on the onboarding Premium page. One value in both modes, because the peach is light in both: white on it was 1.84 / 1.66 (G18). App catalog only: the widget draws no text on the accent |
| BBBackground | `Colors.background` | #F6F3FB | #171420 | app background |
| BBSurface | `Colors.surface` | #FFFFFF | #221E2C | elevated cards, rows, badge discs |
| BBTextPrimary | `Colors.textPrimary` | #2D2837 | #F0EDF6 | body and titles |
| BBTextSecondary | `Colors.textSecondary` | #746D85 | #A29BB5 | captions, units, metadata, inactive |
| BBSuccess | `Colors.success` | #7FC7A4 | #8FD4B2 | "within" ticks, trend chip wash |
| BBAlert | `Colors.alert` | #E05A5A | #E87373 | **only** growth flags and percentile tails (P1); deliberately rare |
| BBFeeding | `Colors.feeding` | #E8A0B4 | #C98BA0 | category tint — feeding |
| BBSleep | `Colors.sleep` | #A9B0E8 | #8A93CC | category tint — sleep |
| BBDiaper | `Colors.diaper` | #E5C98F | #C4AA75 | category tint — diapers |
| BBGrowth | `Colors.growth` | #8FC9AC | #79B396 | category tint — growth |
| BBEvents | `Colors.events` | #C4ABDD | #A78FC2 | category tint — events |
| BBGradientStart | `Colors.premiumGradient` | #6F5BA8 | #7E6BB8 | premium hero / widget gradient, top-leading |
| BBGradientEnd | `Colors.premiumGradient` | #A795D9 | #9C89CE | premium hero / widget gradient, bottom-trailing |
| BBLaunchBackground | `Color("BBLaunchBackground")` | #D3BEE7 | #D3BEE7 | splash backdrop (one value) |
| BBSplashText | `Color("BBSplashText")` | #F7F1E4 | #F7F1E4 | splash wordmark/tagline over the art (one value) |

Outside `Colors/`:
- `AccentColor.colorset` (system tint) = BBPrimary's values, #6F5BA8 / #A795D9.
- `WidgetResources/Colors.xcassets`: copies of BBAccent, BBFeeding,
  BBGradientEnd, BBGradientStart, BBOnPrimary, BBPrimary, BBSleep, BBSurface,
  BBTextPrimary, BBTextSecondary (10; since 1.1.0 they include the ones the Live
  Activity and the widget control need, `m1-live-activity.md` § 6). The pre-build
  script in `project.yml` compares all 10 with the app's and fails on drift
  (DECISIONS 2026-09-01).
- `ExportGenerator` (PDF/HTML): solid #6F5BA8 header and table heads with white
  text (5.6:1), #6F5BA8 card titles (5.0:1 on the card), #746D85 labels and footer
  (BBTextSecondary, 4.9:1 on white); the other neutrals are iOS system greys
  (#1C1C1E text, #F2F2F7 cards, #F9F9FB even rows, #E5E5EA rules). Solid because
  white on the old gradient's light end (#A795D9) was under 3:1; #746D85 because
  #8E8E93 on white was 3.3:1. `DoctorReportPDF` holds its own constants, four of
  them the light colorsets' values (`m2-doctor-report.md` § 5). Accepted
  duplication: the PDF renderer cannot read the Asset Catalog.
- Platform red (`role: .destructive`, `.red`): the system's destructive colour,
  #FF383C / #FF4245 on iOS 26 (#FF3B30 / #FF453A on iOS 17–18), taken from the
  system and never re-valued. It is the app's one destructive red and marks only
  a delete: the delete-all button, the swipe action, the photo, visit and
  question deletes, and from 1.3.0 Delete Dose and Delete Medication. On the
  background it is 3.25:1 in light (3.23 on iOS 17–18; under P8, accepted) and
  5.29:1 in dark; under Increase Contrast iOS draws it darker in light and
  lighter in dark. Why accepted: it is the system's destructive role, iOS
  adjusts it for Increase Contrast, and a custom red would differ from the red
  of the system's own delete alerts. Red that is not a delete: G4.

Tint usage pattern (in force, from components): icon disc/tile fill =
`tint@0.22`; tonal surface = `tint@0.08`; secondary button = `primary@0.10`
fill + `primary@0.30` 1.5 pt stroke; calm gate = `primary@0.08`. Category tints
on a light surface are about 2.1:1, so a glyph whose colour is the only cue
fails P8; on light surfaces the glyph shape carries the meaning and the tint is
a wash.

### Data colours (not tokens)

Domain enums carry hex strings rendered with `Color(hex:)` — no dark variants:
- `FeedingEntry.type` — breast #E8A0BF, formula #B0C4F5, pumped #D4A8D5
- `CustomEvent.type` — bath #B0C4F5, walk #A8D5C2, medication #F5D6A0, mood #E8A0BF, custom #D4A8D5
- `DiaperEntry` stool swatches — yellow #F5D55F, green #6BBF6B, black #2C2C2C, brown #8B5E3C, orange #F5A45F, red #E05A5A, white #F0F0F0 (these depict a real colour, so a literal is defensible here). The selected swatch's check is a literal beside them, `StoolColor.checkHex` (from 1.3.0, G19): #171420 on yellow, green, orange, red and white; white on brown and black. White and Black carry a 1 pt BBTextSecondary edge inside the disc, flagged by `StoolColor.needsEdge` (from 1.3.0, G20).

### Measured contrast

| pair | light | dark |
|---|---|---|
| textPrimary on background | 13.0 | 15.7 |
| textSecondary on background | **4.48** | 6.8 |
| textSecondary on surface | 4.9 | 6.1 |
| primary on background | 5.1 | 6.9 |
| primary on surface | 5.6 | 6.2 |
| white on primary (buttons, FAB, selected chip) | 5.6 | **2.64** |
| BBOnPrimary on primary | 5.6 | 6.9 |
| white on `BBPrimaryButton`'s primary@0.8 end, over the background | **3.80** | **3.76** |
| BBOnPrimary on `BBPrimaryButton`'s primary@0.9 end (from 1.3.0) | 4.60 | 5.78 |
| white on accent (the plan badge before 1.3.0) | **1.84** | **1.66** |
| BBOnAccent on accent (the plan badge from 1.3.0) | 9.88 | 10.95 |
| textSecondary edge of the White / Black stool swatch on the background (from 1.3.0; a border, 3:1) | 4.48 | 6.82 |
| white on gradient end | **2.64** | 3.05 |
| white on gradient start | 5.6 | 4.48 |
| alert on surface | 3.6 | — |
| platform red (destructive text) on background | **3.25** | 5.29 |
| feeding / sleep tint on surface | **2.1 / 2.1** | 6.0 / 5.5 |

Bold = under P8 for normal-size text; see § 10.

## 3. Typography

triggers: a `BBTheme.Typography` function added or re-sized; the Dynamic Type ceiling moved
check: `grep -nE 'static func (largeTitle|title[123]|body|bodyEmphasized|callout|caption|metric|metricSmall)\(' BabyBloom/DesignSystem/BBTheme.swift` → the 10 rows below

Scale: straight SF Pro semibold for headers; SF Rounded for body; rounded +
`monospacedDigit` for metrics and timers. Every size goes through
`Typography.scaled(_:relativeTo:weight:design:)`: scales with Dynamic Type,
capped at `maxContentSizeCategory = .accessibilityLarge` (AX2), pixel-identical
to the fixed scale at "Large".

| style | pt | weight | design | relative to | tracking |
|---|---|---|---|---|---|
| largeTitle | 30 | semibold | default | title1 | −0.4 |
| title1 | 26 | semibold | default | title2 | −0.3 |
| title2 | 21 | semibold | default | title3 | −0.2 |
| title3 | 18 | semibold | default | headline | — |
| body | 17 | regular | rounded | body | — |
| bodyEmphasized | 17 | medium | rounded | body | — |
| callout | 16 | regular | rounded | callout | — |
| caption | 12 | medium | rounded | caption1 | +0.3 |
| metric | 28 | semibold | rounded, mono digits | title2 | — |
| metricSmall | 17 | semibold | rounded, mono digits | body | — |

In use but not named (via `scaled`): button label 17 semibold rounded; row
title 15 semibold; section action 15 medium; footer/legend 13; chart title 14
semibold; slider value 20 semibold mono; elapsed timer 36 semibold rounded mono
(`.largeTitle`). Actual call counts: § 10 G7.

**Accessibility sizes** (from AX1, `dynamicTypeSize.isAccessibilitySize`).
Scaled type stops growing at AX2, so AX2 is the size to check. There a size
scaled relative to `.body` grows by 40/22, body's line height there over its
22 pt at Large, rounded to the pixel (17 → 31.0, 13 → 23.7, 11 → 20.0,
24 → 43.7 pt, measured on the simulator). From 1.3.0 the layout rule of
`m3-medications.md` § 11 holds in every sheet and screen, not only on the
medication path:
- A word never breaks inside itself. A line breaks only at a space, or after
  a hyphen the word already has.
- A label that shares a line with its controls stacks above them:
  `BBLabeledPicker` (§ 7).
- A placeholder that is a field's only label stays whole:
  `bbPlaceholderLabel` (§ 7).
- An entry sheet's title moves from the bar into the content:
  `BBSheetHeading` (§ 7).
- A grid that cannot give its widest word its width takes fewer columns; the
  tiles keep their order and spacing.

Below AX1 a size scaled relative to `.body` grows the same way, by body's line
height at the size over 22: 29/22 at xxxLarge (13 → 17.0, 15 → 19.7 on the
simulator; 34/22 at AX1 gives 13 → 20.0, 15 → 23.3, as measured). Body's point
size ratio (23/17 at xxxLarge, 33/17 at AX2) misses every measured value.
xLarge and xxLarge are not measured: 24/22 and 26/22, checked also at the
larger 19/17 and 21/17; no column count below differs between the two.

From 1.3.0 every word of the entry sheets, the stat card, the profile sheet and
the tile rows below scales, as P6 says (decided 2026-11-03, in code at
c813d99, 427d55e and 6f66d45):
- A word set at a fixed point size (G2) takes `scaled(<its size>,
  relativeTo: .body, weight:, design:)` with its size, weight and design, so
  "Large" stays pixel-identical. A tile's glyph scales with its word: Diaper
  type 22, Feeding type 22, Sleep type 24 and Sleep location 20, as on the Add
  Event type and mood tiles, and the quick and start glyphs: the Diaper
  screen's 28 (`DiaperView.swift:110`), the Events quick tile's 26
  (`EventsView.swift:117`) and the Sleep screen's 30 (`SleepView.swift:122`),
  whose 13 pt «Начать» caption scales too.
- These stay fixed: a colour swatch and its check (the 36 pt stool disc, on
  whose geometry G20's edge sits); the stat card's 36 pt icon plate and the
  glyphs of its top row; the profile photo's figure and its 30 pt camera
  plate; decorative figures (empty-state art); the widget and the Live
  Activity (§ 9); the PDF. The Growth sheet leaves its ruler out at
  accessibility sizes (§ 7, BBSheetHeading).
- A grid's column count is the largest one whose column holds the widest word
  of en, ru and es with sm 8 to spare at 320 pt (in force, decided
  2026-11-03). 320 pt is Display Zoom on the SE, the mini and the 390 and
  393 pt phones, and iPad Slide Over; Display Zoom is a setting turned on
  beside large text, and the rule that a word never breaks has no width
  exception. The column is the word's own room: the tile's width less its
  horizontal padding.
- The rule holds at every text size (in force, decided 2026-11-03). It is
  checked at AX2 with the count at accessibility sizes and at xxxLarge with
  the count below them, because a scaled word grows from xLarge on. A row
  that misses takes fewer columns from the first size where it misses. Each
  text size has one shape at every width. Not a count that follows the width:
  `ViewThatFits` compares a row's whole width, not its narrowest column, so it
  needs a measuring layout, and one sheet would take two shapes at one text
  size. `BBTileColumns` (§ 7) states a row's count at each size.
- The spare keeps a measuring error, a later word or Bold Text from landing a
  break. Bold Text sets a medium word bold, two weight steps: the profile
  sheet's ru «Смешанное» at 17 pt medium is 96.1 pt on the simulator and
  100.8 with Bold Text, which is CoreText's bold (semibold gives 98.1). That
  adds 2.7 to 8.1 pt to these words below AX1 and up to 11.2 at AX2. Every row that
  passes the check also holds with Bold Text (the closest, the Events quick
  tiles at xLarge: +3.3, or +1.4 at the larger scale).
- Measured exceptions (in force, decided 2026-11-03): the spare may be
  smaller only where the row's widest word is measured in both weights
  (CoreText within 0.1 pt of the simulator) and fits in both. Such a row is
  marked † in the table, and any change to its words in any locale is
  measured again before it ships. Two rows: the stool grid at Large, and the
  profile sheet's feeding row at Medium and Large. Why: there the spare would
  change the default sheet on every phone (the seven swatches 3 + 3 + 1, the
  three feeding tiles 2 + 1), and the spare covers what is not measured, while
  both weights are measured there.
- Where its count does not change, a row of tiles that is an `HStack` stays
  one, because a grid sets it a third of a point lower. A tile name of two
  words that wraps at accessibility sizes is centred in its tile. Three tiles
  in two columns set 2 + 1, the third at half width under the first, at every
  size: the Feeding type, Diaper type, Sleep location and profile feeding rows,
  and the Diaper quick-add row from xLarge.

Column counts by text size, checked at 320 pt, all in code at 6f66d45 (1.3.0).
Lines at 6f66d45; widths from CoreText in SF Rounded, within 0.1 pt of the
simulator's. A count in bold differs from c813d99; xSmall to Medium take
Large's count; † marks a measured exception.

| row | size | widest word | L | xL | xxL | xxxL | AX | where the count is set (word in its room at 320 pt) |
|---|---|---|---|---|---|---|---|---|
| stool labels (`DiaperView.swift:458`, grid `:438`) | 10 medium | ru «Коричневый» | 4 † | **3** | **3** | **3** | 2 | four hold at Large without the spare (62.4 in 66.0, +3.6; +0.2 with Bold Text) and break at xLarge (68.0, −2.0); three hold at xxxLarge (80.6 in 90.7, +10.1); two at AX2 (107.6 in 140.0) |
| Feeding type tiles (`FeedingView.swift:373`, row `:407`) | 12 medium | ru «Сцеженное» | 3 | 3 | 3 | **2** | 2 | three hold at xxLarge (80.2 in 90.7, +10.4) and miss at xxxLarge (86.9, +3.8); two at AX2 (118.0 in 140.0) |
| Diaper type tiles (`DiaperView.swift:385`, row `:413`) | 13 medium | ru «Грязный» | 3 | 3 | 3 | 3 | **2** | three hold at xxxLarge (67.6 in 90.7, +23.1) and break at AX2 (92.9, −2.2); two give 140.0 |
| Sleep type tiles (`SleepView.swift:323`) | 13 medium | ru «Дневной» | 2 | 2 | 2 | 2 | 2 | two at AX2 (97.4 in 136.0, +38.6); es «Sueño nocturno» wraps at its space below 402 pt |
| Sleep location tiles (`SleepView.swift:291`, row `:349`) | 11 medium | es «Cochecito» | 3 | 3 | 3 | 3 | **2** | three hold at xxxLarge (69.0 in 90.7, +21.6) and break at AX2 (91.8, −1.1); two give 140.0 |
| Diaper screen quick-add tiles (`DiaperView.swift:112`, row `:83`, padding sm at the sides) | 14 semibold | ru «Грязный» | 3 | **2** | **2** | **2** | **1** | three hold at Large (58.5 in 69.3, +10.8) and miss at xLarge (63.4, +5.9); two hold at xxxLarge (74.8 in 120.0, +45.2) and at AX2 (102.3, +17.7); one at accessibility sizes, the quick rows' shape (below) |
| Sleep screen start tiles (`SleepView.swift:124`, row `:101`, padding lg) | 15 semibold | ru «Дневной» | 2 | 2 | 2 | **1** | **1** | two hold at xxLarge (75.1 in 88.0, +12.9) and miss at xxxLarge (83.2, +4.8); one gives 240.0 |
| Events quick tiles (`EventsView.swift:123`, grid `:105`, padding md) | 14 semibold | es «Medicamento» | 2 | 2 | **1** | **1** | 1 | two hold at xLarge (97.9 in 108.0, +10.1) and miss at xxLarge (105.5, +2.5); one gives 256.0 |
| Add Event type tiles (`EventsView.swift:332`, grid `:322`) | 11 medium | es «Medicamento» | 3 | 3 | **2** | **2** | 2 | three hold at xLarge (77.2 in 90.7, +13.4) and miss at xxLarge (82.8, +7.8); two give 140.0 (AX2 122.8, +17.2) |
| mood tiles (`EventsView.swift:368`, grid `:358`) | 11 medium | ru «Беспокойный» | 3 | 3 | **2** | **2** | 2 | three hold at xLarge (80.3 in 90.7, +10.4) and miss at xxLarge (86.2, +4.5); two give 140.0 (AX2 127.9, +12.1) |
| stat-card title (`BBCard.swift:76`, `BBStatGrid` `:129`, card padding md) | 13 regular | en «Measurements» | 2 | 2 | **1** | **1** | 1 | two hold at xLarge (95.0 in 108.0, +13.0) and miss at xxLarge (100.8, +7.2); one gives 256.0 (AX2 151.9) |
| profile feeding tiles (`BabyProfileEditSheet.swift:284`, row `:192`, section padding md) | 13 medium | ru «Смешанное» | 3 † | **2** | **2** | **2** | **1** | three hold at Large without the spare (75.5 in 80.0, +4.5; +0.9 with Bold Text) and at Medium (72.0, +8.0, +7.9 on the simulator; +4.6 with Bold Text), and break at xLarge (82.3, −2.3); two hold at AX1 (112.3 in 124.0, +11.7) and break at AX2 (132.2, −8.2); one gives 256.0 |
| profile gender tiles (`BabyProfileEditSheet.swift:259`, row `:169`, section padding md) | 15 medium, its figure at `.body` | ru «Девочка» or «Мальчик» with its figure | 2 | 2 | 2 | 2 | **1** | two hold at xxxLarge (105.0 to 106.1 in 124.0, +19.0 to +17.9) and miss at AX1 (+0.8 to −1.4); one gives 256.0. The range is the figure's box, about 1 pt wider on the simulator than in AppKit |

A quick or start tile's glyph grows with its word, and in one column the tile
keeps its shape: glyph above word, centred, full width, as the Events quick
tile at accessibility sizes (in force, in code at 6f66d45). The Diaper
screen's quick-add tile takes sm 8 of horizontal padding, md above and below
(decided 2026-11-03, in code at 6f66d45): with md a side, ru «Грязный» broke
at Large on 320 pt (58.5 in 53.3). The padding sits inside the fill around a
centred word, so 375 and 402 pt draw as before. The three quick and start rows
take one column at accessibility sizes.

Rows the column rule does not reach yet (at 6f66d45; their counts are set when
their words grow): the Feeding screen's quick row (`FeedingView.swift:114`,
`:117`), whose words are still fixed (13 and 11) and whose sub-line keeps a
fixed 30 pt frame; grown, ru «Сцеженное» 131.7 at AX2 needs one column at
320 pt (two give 120.0). Not measured yet: the Home quick actions
(`BBQuickActionButton`'s fixed 12 pt label, `BBButton.swift:120`, four to a
row at `DashboardView.swift:194`), the Feeding timer's side pills
(`FeedingView.swift:267`) and the Feeding sheet's breast-side chips (`:441`),
and the onboarding gender row (`Onboarding/Pages/BirthPage.swift:37`).

The same surfaces' other fixed words scale too, with no change to their
layout: the stool-colour warning (`DiaperView.swift:477`, G3), the slider ends
and hint (`BBMeasureSlider.swift:32`, `:64`, `:86`; `FeedingView.swift:482`),
the timer hint (`FeedingView.swift:497`) and the stat card's trend chip
(`BBCard.swift:44`). The warning's triangle sits on its first line from
xLarge (`.firstTextBaseline` at `DiaperView.swift:474`, in force, in code at
6f66d45), where the warning can wrap (es at xxxLarge on 402 pt); at Large it
stays centred, because on one line the first baseline sets the warning and
the fields below a pixel lower.

Proposed (2026-11-03, not decided):
- **One column for the quick rows at accessibility sizes is a shape, not the
  rule's count.** With sm padding two Diaper quick-add columns hold at AX2
  (102.3 in 120.0, +17.7; +7.9 with Bold Text), so the rule as it stands gives
  two: the three tiles would set 2 + 1, «Оба» alone at half width, beside the
  Events quick and Sleep start rows in one column. Proposed: the column rule
  sets the most columns a row may take, and the three quick and start rows
  take one at accessibility sizes, full-width tiles in one shape.
- **A sheet's title moves into its content from xLarge**, not only at
  accessibility sizes (`BBSheetHeading`, § 7). The bar title never grows past
  Large while Cancel and Save do, so its slot shrinks: in ru 131, 116 and 92 pt
  at Large, xLarge and xxxLarge on 402 pt (104, 89 and 65 on 375). At 17 pt
  semibold with the 0.6 floor, at xLarge on 375 pt ru «Новое кормление»
  (148.7), «Новое измерение» (148.8), «Приём у педиатра» (152.7) and
  «Редактировать профиль» (202.4) are cut, and at xxxLarge on 402 pt four
  titles shrink to 10.2–11.0 pt. The diaper norm editor, whose bar holds
  Cancel alone, follows: from xLarge its bar shows no title and its first
  heading, «Норма в день» (`DiaperView.swift:283`), takes the header trait; a
  second heading would repeat it. Its system title, shifted right of Cancel,
  has no spare at xxxLarge and AX2 on 320 pt (from 134 to 304 against a
  304 pt edge).
- **A date picker's label sits above its pills at every size**
  (`BBLabeledPicker`, § 7), as the sheets' other captions do. At Large on
  320 pt the label misses beside the widest date and time pills before its
  gap is counted: ru «Время» −21.9, «Начало» −29.5, «Конец» −19.7, en «Time»
  −10.9 (12-hour time); the date-only ru «Дата измерения» keeps 17.0, under
  the spare once the gap (at least 9.7 pt) is taken. On 375 pt ru «Время»
  misses from xLarge; on 402 pt it breaks at xxxLarge («Врем / я», rendered).
- **Text that wraps at some width takes its wrapped alignment at that size**:
  the stool warning's triangle on the first line and the profile photo hint
  centred, at Large too. At Large on 320 pt the ru warning wraps (253.4 pt in
  247.0; es 259.0) and so does the ru hint (309.9 in 288.0). The cost: with a
  warning colour picked, the warning and the fields below sit a pixel lower at
  Large, and the hint moves by a fraction of a pixel.

## 4. Spacing

triggers: a `BBTheme.Spacing` member added or changed
check: `awk '/enum Spacing/,/^    }/' BabyBloom/DesignSystem/BBTheme.swift | grep 'static let'` → 6 rows

| token | pt | typical use |
|---|---|---|
| xs | 4 | icon–label gap in tiles |
| sm | 8 | stack spacing inside a card, button inner vertical padding, list row gap |
| md | 16 | card padding (default for every surface modifier), screen side gutter, FAB inset |
| lg | 24 | section gap |
| xl | 32 | large section / onboarding gap |
| xxl | 48 | bottom content inset under the FAB (rule: lists keep ≥ xxl so the last row clears it) |

Micro gaps of 2 pt (label–sublabel) and 3/6 pt chip padding are used raw.

## 5. Corner radii

triggers: a `BBTheme.Radius` member added or changed
check: `awk '/enum Radius/,/^    }/' BabyBloom/DesignSystem/BBTheme.swift | grep 'static let'` → 5 rows

| token | pt | used for |
|---|---|---|
| sm | 12 | small warning callouts |
| md | 16 | elevated cards, event rows, sliders, gate footer, delete button, swipe action |
| lg | 24 | primary/secondary buttons, tonal stat tiles, weekly chart card |
| xl | 32 | premium hero bottom corners, onboarding fact card |
| pill | 999 | chips and capsule tags |

Raw radii in use: 10 (stat-card icon tile, filter chip), 14 (filter picker
track), 8 (trend chip, chart nav buttons), 6 (progress bar), 4, 9, 2 (§ 10 G8).

## 6. Elevation and surfaces

triggers: a `BBTheme.Shadow` member or a surface modifier added or changed
check: `grep -nE 'static let (soft|card|button) = ShadowConfig|struct BB[A-Za-z]+Modifier' BabyBloom/DesignSystem/BBTheme.swift` → 3 shadows + 4 modifiers

Shadows: diffuse, tinted with `primary` instead of black.

| shadow | colour | radius | y |
|---|---|---|---|
| soft | primary@0.14 | 28 | 12 |
| card | primary@0.10 | 20 | 8 |
| button | primary@0.18 | 10 | 4 |

Surface levels:
- **Elevated (level 1)** — `bbCard()`: surface fill, radius md, `card` shadow,
  1 pt top highlight (white@0.5 light / white@0.08 dark, overlay blend).
- **Tonal (level 0)** — `bbCardTonal(tint)`: `tint@0.08`, radius lg, no shadow,
  no border. At-a-glance stat tiles and quick-add tiles.
- **Bare row** — `bbBareRow()`: vertical sm padding only, for grouped lists with dividers.
- **Glass** — `bbGlass()`: `.ultraThinMaterial`, radius md, `soft` shadow.

## 7. Components (`BabyBloom/DesignSystem/`)

triggers: a file added to or removed from `DesignSystem/Components/`; a public component renamed
check: `grep -hoE '^(struct|enum) [A-Za-z]+' BabyBloom/DesignSystem/Components/*.swift | sort` → the names below (`HistoryFilter` is the picker's model; `EmptyStateView` and `AppAppearance` live elsewhere; `BBSheetHeading` and `bbSheetTitle` live in `BBTheme.swift`, and `bbPlaceholderLabel` is a modifier)

| component | file | purpose | used in |
|---|---|---|---|
| BBPrimaryButton | BBButton | full-width CTA: primary→primary@0.8 gradient, white 17 semibold, min 56 pt, radius lg, `button` shadow, loading state. From 1.3.0 the gradient ends at primary@0.9 and the label is BBOnPrimary (G1) | Feeding, Sleep, Diaper, Events, Growth, Export, BabyProfileEditSheet, PlanPickerSection, Onboarding (Welcome, Fact, Notifications, GrowthShowcase, WidgetShowcase, OnboardingView) |
| BBSecondaryButton | BBButton | outlined companion: primary@0.10 fill, primary@0.30 stroke | DoctorReport (QuestionsCard), since 1.2.0 |
| BBQuickActionButton | BBButton | 60 pt tint@0.22 disc + 26 pt glyph + 12 pt label; optional `LockBadge` | Dashboard |
| BBIconButton | BBButton | circular tint@0.12 icon button, 48 pt | — (unused) |
| BBScaleButtonStyle | BBButton | press feedback for every tappable (§ 8) | 11 feature files |
| BBStatCard | BBCard | tonal KPI tile: 36 pt icon tile, metric value + unit + title, optional trend chip and chevron, whole card tappable, min 110 pt. From 1.3.0 its title (13 regular), unit (13 medium) and trend chip (12 medium) scale relative to `.body` (§ 3); the icon plate stays 36 pt | Dashboard, Feeding, Sleep, Diaper, Growth |
| BBStatGrid | BBCard | **from 1.3.0** — the grid of stat cards: two flexible columns 8 pt apart (the grid's own spacing), rows md 16 apart; one column from xxLarge and at accessibility sizes (in code at 6f66d45, through `BBTileColumns`), where a grown title no longer fits half the screen: en «Measurements» is 100.8 pt at xxLarge and 151.9 at AX2, and half a 320 pt screen leaves a card 108.0 pt inside its md padding (135.5 at 375 pt); one column leaves 256.0 (311.0) | Dashboard, Feeding, Sleep, Diaper, Growth |
| BBTileColumns | BBCard | **from 1.3.0** — a tile or grid row's column count at Large (and every smaller size), xLarge, xxLarge, xxxLarge and accessibility sizes, stated in one place; the counts come from the column rule (§ 3) | BBStatGrid; Diaper (quick-add, type, stool), Feeding (type), Sleep (start, location), Events (quick, Add Event type, mood). The profile sheet's feeding and gender rows branch on the text size directly, with the same counts |
| BBEventRow | BBCard | elevated list row: 44 pt tint disc, title (scaled 15 semibold), subtitle, trailing time. From 1.3.0 the subtitle and the time scale too (13 relative to footnote; time 13 / date 12 relative to footnote / caption1), because a medication row's subtitle carries its name and dose (`m3-medications.md` § 6) | Feeding, Sleep, Diaper, Events, RecentActivity |
| BBProgressCard | BBCard | elevated card with 8 pt progress bar toward a target | Dashboard, Diaper |
| BBSectionHeader | BBCard | title3 header + optional "All" action | Dashboard, Feeding, Sleep, Diaper, Events, Growth, BBHistorySection |
| SwipeToDeleteRow | BBCard | custom swipe-to-reveal 76 pt delete action | Events, Growth, RecentActivity, BBHistorySection |
| BBFab | BBFab | 56 pt primary circle, white "+" (BBOnPrimary from 1.3.0, G1), bottom-trailing overlay, md inset; mirrors the toolbar "+" | Feeding, Sleep, Diaper, Growth |
| BBHistorySection | BBHistorySection | history header + range picker + empty state + swipe list + locked footer + delete-all | Feeding, Sleep, Diaper |
| BBHistoryFilterPicker | BBCharts | segmented range picker (selected chip primary, white text; BBOnPrimary from 1.3.0, G1) | BBHistorySection |
| BBWeeklyBarChart | BBCharts | Swift Charts 7-day bars, today full tint, week navigation | Feeding, Sleep, Diaper |
| BBDeleteHistoryButton | BBCharts | destructive "delete all" with a scope-honest confirmation (P4) | Events, BBHistorySection |
| BBLockedHistoryFooter | BBLockedHistoryFooter | the one calm locked row for history beyond the free window (P2) | Events, RecentActivity, BBHistorySection |
| LockBadge + `bbLockedAccessibility` | LockBadge | the one padlock: 10 pt glyph on a surface disc; VoiceOver value "locked" (P3) | Events, BBQuickActionButton |
| BrandMark | BrandMark | `BBLogo` clipped to a circle, 1 pt ring, optional shadow, on-gradient variant | MainTabView, PremiumHero, Onboarding (Welcome, Generating) |
| BBElapsedTimer | BBElapsedTimer | per-second elapsed label, 36 pt mono, MM:SS or HH:MM:SS | Dashboard, Feeding, Sleep |
| BBMeasureSlider | BBMeasureSlider | elevated labelled slider with mono value and min/max | Growth, Onboarding GrowthPage |
| BBOptionalMeasureToggle | BBMeasureSlider | toggle that reveals a slider (head circumference) | Growth, BabyProfileEditSheet, Onboarding (Birth, Growth) |
| BBLabeledPicker | BBFieldLabels | **from 1.3.0** — a picker with its label beside it below AX1 (the picker alone, as before). At accessibility sizes: the label in the row's text style, then the picker with `labelsHidden()`, sm 8 apart, both leading, at the row's full width. VoiceOver reads the label once: the picker keeps its own, and the visible label is hidden from VoiceOver. Proposed (§ 3): the stacked form at every size, because at Large on 320 pt the label misses beside its pills | Diaper (Time), Sleep (Start, End), Growth (measurement date), VisitFields (date), DoseSheet (time), Events (Time). The profile sheet's birth date takes the stacked form's two halves at every size without the helper: a caption above, hidden from VoiceOver, and the picker named «Дата рождения» (in code at 427d55e) |
| `bbPlaceholderLabel(design:maxLines:)` | BBFieldLabels | **from 1.3.0** — for a vertical text field whose placeholder is its only label, or is the example of what to type. A placeholder wraps only into lines the field already has, and only in a point-size face, so: 17 regular relative to `.body` (rounded, or default), and 1…`maxLines` lines below AX1, 2…`maxLines` + 1 at accessibility sizes (default 3); nil lets the field grow without a bound | Diaper (note), Events (free-text name), MedicationFormSheet (name, dose, maximum, note; the maximum has a label above, and its es example takes two lines at AX2), QuestionSheet (unbounded) |
| BBSheetHeading + `bbSheetTitle(_:movesIntoContentAtAX:)` | BBTheme | **from 1.3.0** — a sheet's title. Below AX1 it sits in the bar between Cancel and Save (capped at Large, one line, shrinks to 0.6). At accessibility sizes the bar shows no title and `BBSheetHeading` is the content's first line: title3 (32.8 pt at AX2), textPrimary, leading, wraps, header trait. The flag and the heading go together: the flag alone leaves no title, the heading alone shows it twice. The next block follows at the sheet stack's spacing (lg 24). A section label right under the heading keeps its own style (16 semibold): the heading's ratio to it is 18 : 16 at every size, and the label sits 15 pt above its tiles against 34 pt below the heading, so it reads with its tiles. A decorative figure above the content (the Growth sheet's 48 pt ruler) is left out at accessibility sizes, where the heading is the sheet's top, and is hidden from VoiceOver at every size. Proposed (§ 3): the title in the content from xLarge. The ru profile title, «Редактировать профиль» (202.4 pt at 17 pt semibold), shrinks to 11.0 pt at Large on 402 pt and is cut on 375; a shorter ru title of at most 96 pt, whole at Large on 375 pt with 8 to spare, is proposed («Профиль» is 75.5) | Add Event, Feeding, Growth, Sleep, Diaper, QuestionSheet, DoseSheet, MedicationFormSheet, VisitSheet, VisitDetailSheet, BabyProfileEditSheet (from 427d55e). The diaper norm editor keeps the system inline title: whole at AX2 on 402 and 375 pt, without spare on 320 pt (§ 3) |
| `cornerRadius(_:corners:)` / RoundedCorner | RoundedCorner | per-corner rounding | PremiumHero |
| EmptyStateView | *Features/Feeding/FeedingView.swift* | icon + title + subtitle empty state | Feeding, Events, Growth, BBHistorySection — shared, but lives outside `DesignSystem/` (§ 10 G11) |
| AppAppearance | AppAppearance | system / light / dark preference; overrides the colour scheme only | BabyBloomApp, MainTabView |

## 8. Motion and haptics

triggers: a new animation curve in a shared component; a Reduce Motion rule added
check: `grep -rnoE --include=*.swift 'spring\(response: [0-9.]+, dampingFraction: [0-9.]+\)' BabyBloom | sed 's/.*spring/spring/' | sort | uniq -c` → the curves below

| use | curve | status |
|---|---|---|
| press (every button via `BBScaleButtonStyle`) | scale 0.96, `spring(0.3, 0.7)` + soft impact haptic at 0.7 intensity on press-down | in force |
| progress fill, value changes | `spring(0.6, 0.8)` (6 sites) | in force |
| swipe-to-delete drag / settle | `interactiveSpring(0.3, 0.8)` / `spring(0.35, 0.85)` | in force |
| reveal (optional measure toggle) | `easeInOut(0.25)` | in force |
| onboarding entrances | `spring(0.5–0.7, 0.75–0.8)`; honour `accessibilityReduceMotion` (6 onboarding files) | in force |

## 9. Platform surfaces

triggers: a widget family / Live Activity / export format added; splash art changed
check: `ls WidgetResources/Colors.xcassets` → BBAccent, BBFeeding, BBGradientEnd, BBGradientStart, BBOnPrimary, BBPrimary, BBSleep, BBSurface, BBTextPrimary, BBTextSecondary (10 colorsets) + Contents.json

- **Widget** (`Features/Widget/WidgetViews.swift`): premium gradient
  background, all text white at 0.7–1.0 opacity, raw rounded sizes 10–32 pt
  (widgets do not take Dynamic Type the same way; fixed sizes are expected
  here). Since 1.1.0 it has tap areas and a start-feeding control:
  `m1-live-activity.md` § 5.
- **Live Activity** (in force since 1.1.0, `Features/LiveActivity/`): Lock
  Screen on BBSurface, Dynamic Island on its black — spec in `m1-live-activity.md`.
- **Splash** (`Features/Splash/SplashView.swift`): BBLaunchBackground, then
  `BBSplashBg` art (design PNG with its text band stitched out), wordmark in
  BBSplashText. Launch screen is colour-only. Art: `docs/design/splash*.png`.
- **App icon**: `docs/design/icon*.png`, brief `docs/design/icon-design-brief.md`.
- **PDF / HTML export**: § 2 "Outside `Colors/`".

## 10. Gaps and inconsistencies (notes, not fixes — 2026-10-28)

triggers: any gap fixed or a new one found at review
check: none — each gap carries its own grep; re-run it when the gap is worked

Seen from code at 10cf1a9; no live look on device yet. G1, G4 and G9 were
re-read at 1b01297 (1.2.0) on 2026-11-03, and G1's button numbers were also
measured on the medication screens' renders. G1 was read again at c1354c4,
with its renders in light and dark, and G18 and G19 were found there
(2026-11-03). G18 and G19 were read at b503825 with their renders in light and
dark, and G20 was found there; G20 was read at 890c80b with its renders in
light and dark, and G2 at 337fff5 for the entry sheets and the stat card, at
c813d99 with its renders at AX2 and at Large, and at 427d55e and 6f66d45 for
the profile sheet and the tile rows, with their renders at AX2, xxxLarge and
Large, where G21 was found (2026-11-03). Each line: what, where, which rule.
Under P8, existing contrast violations are backlog items, not blockers; G2 is
in the backlog (2026-10-28) and fixed for 1.3.0 on the entry sheets, the stat
card, the profile sheet and the tile rows, and G1, G18, G19 and G20 are fixed
for 1.3.0.

**Major**
- **G1 · White on BBPrimary in dark mode was 2.64:1; fixed for 1.3.0.** Dark
  primary #A795D9 is a light lavender, so white labels and glyphs on primary
  fills sat under 3:1. Broke P8. `BBPrimaryButton`'s worse end differed by
  mode: in dark the start (2.64, against 3.76 at the primary@0.8 end, which
  the dark background darkens); in light the end (3.80, against 5.6 at the
  start), where long ru and es labels measured 4.26–4.40 as their text ends.
  Fix, decided 2026-11-03 for 1.3.0, in code at c1354c4: every ink on a
  BBPrimary fill is BBOnPrimary (§ 2), and `BBPrimaryButton`'s gradient ends
  at primary@0.9. The places:
  - `BBPrimaryButton`: label, icon and loading spinner (`BBButton.swift:22`, `:37`);
  - the `BBFab` "+" (`BBFab.swift:20`);
  - the selected `BBHistoryFilterPicker` chip (`BBCharts.swift:40`);
  - the Premium Active badge in Profile (`MainTabView.swift:362`);
  - the camera glyph on the profile photo (`BabyProfileEditSheet.swift:274`);
  - the step checkmark of the onboarding generating page (`GeneratingPage.swift:79`);
  - the selected interval chip of the medication form (`MedicationFormSheet.swift:218`);
  - the Live Activity's button capsule (`TimerActivityViews.swift:56`), since
    1.1.0, from the widget catalog's copy of both colours.
  Every fill but the button's is opaque primary: 5.62 in light, 6.86 in dark.
  The button's primary@0.9 end is 4.60 / 5.78 over the background and
  4.53 / 5.86 over the surface (sheets). On the renders the label's trailing
  end reads 5.05–5.11 in light and 6.29–6.35 in dark.
  Not ink, so not on the list: the toolbar `plus.circle.fill` buttons, whose
  plus is the bar or card behind showing through (5.50 light, 5.84 dark on
  Diapers), and the primary@0.08–0.22 tints, which carry primary ink.
  A new control on a BBPrimary fill takes BBOnPrimary.
  grep: `grep -rn --include=*.swift 'onPrimary\|BBOnPrimary' BabyBloom` → 12
  lines at c1354c4: the nine uses above (two in the button), the token, two
  comments. Why before 1.3.0: the medication screens carry the button and are
  opened at night, in dark.
- **G18 · White on BBAccent in the plan picker's badge was 1.84:1 in light and
  1.66:1 in dark; fixed for 1.3.0** (`PlanPickerSection.swift:181`, 11 pt
  bold). Broke P8. BBOnPrimary is not its ink: its light value is white. Fix,
  decided 2026-11-03 for 1.3.0, in code at b503825: a token of its own,
  BBOnAccent (§ 2), #171420 in both modes (BBOnPrimary's dark value): 9.88 in
  light and 10.95 in dark, the same on the renders, where the badge's ink is
  #171420 on the peach. The badge is the one text on an opaque BBAccent fill,
  and the paywall and the onboarding Premium page both draw it from
  `PlanPickerSection`. The other accent uses are tints, glyphs in the accent,
  gradients and a progress bar, none with text on the accent. A new text on a
  BBAccent fill takes BBOnAccent.
  grep: `grep -rn --include=*.swift 'onAccent\|BBOnAccent' BabyBloom` → 2 lines
  at b503825: the token and the badge.
- **G2 · 148 raw `.system(size:)` fonts in the app** (widget excluded) never
  scale with Dynamic Type, against P6 / DECISIONS 2026-08-28. Heaviest:
  GrowthInsightCards 20, BBCard 15, DiaperView 12, FeedingView 10,
  BabyProfileEditSheet 9. Includes shared components: `BBStatCard`
  unit/title 13 pt and `BBMeasureSlider` min/max 11 pt (both scaled from 1.3.0,
  § 3), `BBEventRow` subtitle/time 13 pt (scaled from 1.3.0, § 7), `BBQuickActionButton`
  label 12 pt. grep: `grep -rno --include=*.swift '\.system(size:' BabyBloom | grep -v WidgetViews | wc -l`
  → 158 at 337fff5, 140 at c813d99, 129 at 6f66d45.
  Fixed for 1.3.0 on the entry sheets, `BBStatCard`, the profile sheet and the
  Diaper and Sleep screens' quick and start tiles (decided 2026-11-03, in code
  at c813d99, 427d55e and 6f66d45): their words and tile glyphs scale, and the
  grids and tile rows take the counts of § 3 at every text size. The rest of
  the app's fixed words (among them the Growth insight cards, the charts, the
  Feeding screen's quick row, the Home quick actions, onboarding and the
  Diaper norm chip, `DiaperView.swift:146`) follow the same rule, screen by
  screen.

**Minor**
- **G19 · The stool swatch's check was white on every swatch; fixed for
  1.3.0** (`DiaperView.swift:395`). It read 1.14 on white, 1.44 on yellow,
  2.03 on orange, 2.26 on green and 3.63 on red, so it vanished on four
  swatches, the white one G3 warns about among them. The 2.5 pt BBPrimary
  ring carried the choice, so the state was not lost. Fix, decided 2026-11-03
  for 1.3.0, in code at b503825: `StoolColor.checkHex`, a literal beside the
  swatch literals (`DiaperEntry.swift:92`). The check is #171420 on the five
  light swatches (yellow 12.59, green 8.03, orange 8.95, red 4.99, white 15.92)
  and stays white on brown and black (5.58, 13.97). On the renders the check on
  White is #171420 in both modes; the ring is 5.12 in light and 6.86 in dark
  against the sheet.
- **G20 · The White swatch on the light sheet and the Black swatch on the
  dark sheet had no edge; fixed for 1.3.0** (`DiaperView.swift:393`). Against
  the sheet (BBBackground) their fills are 1.04 and 1.30, so the unselected
  disc nearly vanished and its label stood alone. The other five swatches read
  by their hue. The fill cannot change, because it depicts a real colour (§ 2
  Data colours). Fix, decided 2026-11-03 for 1.3.0, in code at 890c80b:
  - White and Black carry a 1 pt BBTextSecondary edge, drawn inside the 36 pt
    disc (`strokeBorder`), in both modes, flagged by `StoolColor.needsEdge`
    (`DiaperEntry.swift:101`; the switch is exhaustive, so a new colour has to
    choose). On the renders the edge spans radius 17–18 pt in the token's
    colour: 4.48 in light and 6.82 in dark against the sheet, over P8's 3:1
    for a border.
  - The disc stays 36 pt. The 2.5 pt selected ring is drawn on the same
    circle (radius 16.75–19.25 pt), so it covers the edge when the swatch is
    chosen: on the selected White no edge pixel is left in either mode, and the
    selected look does not change.
  - In the other mode, the edge rims a disc that already stands at 15.92
    (White on dark) and 12.72 (Black on light), so one rule per swatch needs
    no appearance branch.
  - Not on all seven: on the hued swatches a grey edge dulls the depicted
    colour at its rim, and it adds weight where the hue already separates the
    disc. Not a faint edge (textSecondary@0.30, the export radio circle's):
    1.50 and 2.19, under 3:1.
  grep: `grep -rn --include=*.swift 'needsEdge' BabyBloom` → 2 lines at
  890c80b: the flag and the disc.
- **G21 · Sheet titles at Large on 320 pt** (`bbSheetTitle`,
  `BBTheme.swift:336`). In ru the bar slot between «Отмена» (85 pt) and
  «Сохранить» (114 pt) is 49 pt there, so with the 0.6 floor every ru
  entry-sheet title is cut, «Подгузник» (89.2) among them, and es titles from
  116 pt on («Agregar sueño»); en holds. Breaks the helper's own promise of a
  whole title. Measured at 6f66d45 from the bar's frames on 402 pt and CoreText
  widths, not rendered. Ways out for a later decision: the platform's glyph
  Cancel and Save on iOS 26, which leave the title about 160 pt, or the title
  in the content at every size.
- **G4 · Red outside the destructive role.** The platform red is the app's
  destructive red (§ 2): `SwipeToDeleteRow` (`.red` tint, `BBCard.swift:232`)
  and `BBDeleteHistoryButton` (`.red`, red@0.06 fill, red@0.2 stroke,
  `BBCharts.swift:329–336`) use it for a delete. Off that role:
  `BabyProfileEditSheet:288` remove photo at red@0.8, paler than the system's
  red and so under its 3.25:1, and `PlanPickerSection:316` purchase error
  (`.red`): a purchase error is not destructive at all. The code itself names
  red "the colour for your data is about to go away" (`BBLockedHistoryFooter`).
  Breaks P1.
- **G5 · Dead alarm styling in shared components:** `BBStatCard.overLimit` and
  `BBProgressCard.overLimit` still render system red + triangle/exclamation;
  no call site passes `true` since DECISIONS 2026-09-05. Breaks P1 if ever
  reused.
- **G6 · Data colours bypass the catalog** (§ 2 Data colours): no dark
  variants, and near-misses with the category tints (breast #E8A0BF vs
  BBFeeding #E8A0B4; formula/bath #B0C4F5 vs BBSleep #A9B0E8). One literal is
  in a view: `DiaperView.swift:142` `Color(hex: "#B0C4F5")`. Breaks P5
  (stool swatches excepted).
- **G7 · The type scale in use is wider than the named one:** 23 calls to named
  styles vs 104 ad-hoc `scaled()` calls at 11–64 pt, mostly 13/14/15/16 pt
  (12 + 27 + 27 + 12). Candidates for named styles: 15 (row title /
  subheadline), 14 (card title), 13 (footnote).
- **G8 · Off-token radii:** 10, 14, 8, 6, 9, 4, 2 pt used raw (filter picker
  14/10, stat icon tile 10, chips 8) while `Radius.sm` (12) has 2 users.
- **G9 · Unused system API next to hand-rolled copies:** `bbBareRow()`,
  `bbGlass()` and `BBIconButton` have no callers. `bbCard()` has callers since
  1.1.0 (the weekly card) and 1.2.0 (the doctor report's cards, header and
  question sheet), and `BBSecondaryButton` one since 1.2.0 (the report's
  questions card). `BBEventRow`, `BBProgressCard`, `BBMeasureSlider` and the
  weekly chart still hand-roll surface + radius + `card` shadow and so lack the
  level-1 top highlight `bbCard()` defines. grep: `grep -rnF --include=*.swift
  '.bbCard()' BabyBloom | wc -l` → 8 in 1.2.0.
- **G10 · textSecondary on background is 4.48:1 (light)** — a hair under P8,
  and it carries the 12–13 pt captions and units.
- **G11 · `EmptyStateView` lives in `Features/Feeding/FeedingView.swift`**
  though four surfaces share it; belongs in `DesignSystem/Components/`.
- **G12 · Gradient text in light mode:** white on BBGradientEnd is 2.64:1;
  widget labels at white@0.7–0.85 and the premium hero lose more toward the
  bottom-trailing end. Breaks P8. Check live on the widget and paywall.
- **G13 · Reduce Motion is honoured only in onboarding;** shared springs
  (press, progress, swipe) ignore it. Small movements, low risk.
- **G14 · No named motion tokens:** 8 spring variants for 4 intents.
- **G15 · Palette of record is incomplete:** `README.md#дизайн-система` lists 4
  light-only colours of 19 colorsets; `AccentColor.colorset` duplicates
  BBPrimary and is missing from the re-theme list in CLAUDE.md. README should
  point here.
- **G16 · The export PDF's neutrals are mostly iOS system greys,** not the brand
  neutrals (#1C1C1E/#F2F2F7 vs BBTextPrimary/BBBackground; also #F9F9FB even rows,
  #E5E5EA rules). Its labels and footer are BBTextSecondary #746D85. Defensible for
  print; noted so a re-theme does not miss it.
- **G17 · Splash text contrast unknown:** BBSplashText on BBLaunchBackground
  is 1.52:1, but the text sits on the splash art, not the plain backdrop —
  needs a live look.

**By design (not gaps — do not re-raise)**
- **G3 · Stool-colour warning in DiaperView** (`DiaperView.swift:474–483` at
  6f66d45, orange + `exclamationmark.triangle.fill`): it stays as it is — a
  deliberate exception to the calm rule for a medically meaningful signal
  (pale/white stool). Product decision, 2026-10-28.

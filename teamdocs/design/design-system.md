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
title follow the code of the same day (§ 3, § 7, `BBTileColumns`). On
2026-11-04 the quick rows' one column at accessibility sizes, the tracker
screens', Home's and onboarding's tile rows, with two more measured
exceptions, the fit rule for rows whose width follows their content and the
timer cards follow the code (§ 3, § 7, G2), and so do: sheet titles in the
content from xLarge, the pickers' labels above at every size and the wrapped
alignment at every size; glyph buttons in the sheet bars, a 166 pt title
budget with a 13 pt floor and the dose sheet's name in its content (G21);
Home's quick actions four in a row where their tiles fit, the Feeding quick
caption's own padding and the hours on Home's sleep card (§ 3, § 7, § 10).
The diaper norm editor's × as Close and its scroll (G22), the medication
screen's Edit as the pencil, the weight gain card's number and interval and
the Today feeding card's time since the last feed taking their shape from the
fit, and the Growth cards' ? on a wrapped title's first line follow the code
of the same day (§ 3, § 7). A bar confirm that shows ▶ while its sheet
starts a timer, value rows that share a column of deltas taking one shape by
fit and the percentile card's figure in place of its band label, decided the
same day, are in code (7335076, 0334779, e3d45e2; § 3, § 7,
G23), and so is a Settings switch's hint inside its label (8b90029, § 7).
Words and figures on the other Growth cards in the text colours with the
tier tint on a mark, a tier dot before the verdict word (§ 2, § 7, G23),
decided the same day, are in code (855227f), and so is the same direction
for the category tints as text ink (the timer cards, Home's timer card, the
week chart, the bottle volume): the text colours, with the tint on the wash,
stroke, glyph disc, bars and slider beside them (fa5c55f; § 2, § 7, G24).
Decided the same day and in code too (16f2802 unless named): BBTextSecondary
darker in light, #6B647C, with the onboarding backdrop's primary blobs at
0.08 (G10); a value over every bar of the week chart up to today, in the text
colours, without the axis numbers (G25); a primary wash under BBPrimary words
laid over the surface (G26); and the question and visit sheets' deletes
(170d574), the photo's Remove, the purchase error and the delete-all button
under the platform red's role, with no over-limit red (G4, G5). The
stool-colour warning keeps its orange words (G3, by design). Decided the same
day and in code (3bb4936): the brand gradient one step deeper, one pair in
both modes, with every word on it in white at full strength (G12); unchecked
and unselected marks in BBTextSecondary at full strength (G27); the splash
words in a deep violet (G17).
Decided the same day and in code too: the norm editor's stepper card as wide
as the column where its widest form does not fit (G22, eb1f410), a selected
tile's or chip's border drawn outside its fill (§ 3, § 7, G29, 1187418), and
the splash words beside the art's figure wherever its crop would put them on
it, as in landscape (G28, d3e94e8).
Decided the same day and in code at c090a8e: a title and its trailing value keeping the value whole
and the title's words whole, with the value under the title at accessibility
sizes and, in Settings' iCloud Sync row, wherever the two do not share one
line, and the medication menu's label above it at every size (§ 3, § 7, G30);
and the Export format tiles' description with sm 8 a side and the two tiles of
one height (G29).
Decided on 2026-11-05 and in code at 42a74fe: the event row's time under its texts
wherever a word of the title or the second line misses beside it, and the
Nutrition card's three rows taking one shape by fit (§ 3, § 7). In code at
19a14f1: a span of minutes from one writer, and the stat tile's duration
with its unit words at the unit's size inside the value (§ 7). Decided on
2026-11-05, from 1.3.0: a screen's large title in the content wherever it
misses the bar's one line, with the inline title after the scroll (§ 3,
§ 7, G31), and Growth without the floating + (P7, § 7, G32), in code at
7b886b1; the splash art silent to VoiceOver (§ 9), in code at 8c4bdae; the
Export PDF told apart from the doctor's report by its tile's words, its
first page and its file name, with a pointer to the report under the
format tiles (§ 7, G33), in code at 361abe5, its count tiles naming what
they count at 0a925bf; a weight-for-age section in the report PDF (§ 9,
G34) and a weighing's head value on its own line in the report screen's
Growth card (§ 7, G35), in code at 80d2e54.
Decided on 2026-11-06, from 1.3.0, in code at a298c62: the section header
without its action, Home's growth rows and Growth's history rows by fit,
and a Settings row by fit, its switch under the label where a word misses
beside it and, at the accessibility sizes, its icon above a title whose
first word misses beside the icon (§ 7); Export's category rows without
lines, in code at 361abe5 (§ 7). Decided on 2026-11-06: the system Language
row's hyphen as the one stated exception to a word kept whole (§ 3, in
force, the system's row); and a dash never starting a line (§ 3, planned).
Decided on 2026-11-06, from 1.3.0: an age, a report's period length and its
day and month glued at their writers (§ 3), with Settings' baby row by fit
at the accessibility sizes (§ 7), in code at 92c70db; Home's sleep card read
as two durations (§ 3, § 7), in code at c67ab7c; the progress card's figure
and glyph scaling with its title, its row by words (§ 7, G36), in code at
1fb7ece. Decided on 2026-11-06, from 1.3.0, in code at e58f04b: the paywall's
plan rows by fit, the savings badge under the price where the plan's name or
its price would miss one line beside it, and the paywalls' feature card in one
shape by fit, all its rows beside their icons or all under them (§ 3, § 7).
Proposed on 2026-11-06: Home's header name under the greeting's row
where it misses beside the avatar (§ 7, G37); the primary and secondary
buttons' md 16 inset, their labels centred and wrapping between words (§ 7,
G38); the onboarding setup page's step in progress in place of its five rows
where they miss the page (§ 7, G39).
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
| P7 | **One-handed at night.** Primary "add" sits in the thumb zone (`BBFab`, bottom-trailing); tap targets ≥ 44 pt. **From 1.3.0** (G32, decided 2026-11-05; in code at 7b886b1): the floating + on the screens of the night actions, Feeding, Sleep and Diapers, and not on Growth, where a weighing is added a few times a month from the bar's + and «Add a weighing», and where the + sat over the chart's end and the cards' «?» at rest. | in force | `BBFab`, `BBLockedHistoryFooter`, `DiaperView` |
| P8 | **Contrast floor (WCAG 2.2 AA):** text ≥ 4.5:1 against its fill; ≥ 3:1 for text ≥ 18.66 pt bold / 24 pt regular and for non-text UI that carries meaning (icons, rings, borders). New surfaces are held to it; existing violations go to the backlog, not to blockers. | in force | product decision 2026-10-28: WCAG 2.2 AA is the review bar |

## 2. Colour tokens

triggers: a colorset added, removed or re-valued; a `BBTheme.Colors` member added
check: `ls BabyBloom/Resources/Assets.xcassets/Colors | sed 's/.colorset//'` → the 19 names below; `grep -o 'Color("BB' BabyBloom/DesignSystem/BBTheme.swift | wc -l` → 17 (BBLaunchBackground and BBSplashText are read by `SplashView` directly)

All sRGB, light (`any`) / dark (`luminosity: dark`).

| colorset | Swift | light | dark | role |
|---|---|---|---|---|
| BBPrimary | `Colors.primary` | #6F5BA8 | #A795D9 | brand violet: primary buttons, FAB, links, selected states, calm gates, shadow hue |
| BBOnPrimary | `Colors.onPrimary` | #FFFFFF | #171420 | **in force since 1.1.0** (decided 2026-10-28) — label and glyph colour on any filled BBPrimary surface. Shipped with the Live Activity (its button capsule, `TimerActivityViews.swift`) and copied to the widget catalog; from 1.3.0 it is the ink on every BBPrimary fill: `BBPrimaryButton`, the `BBFab` "+", the selected `BBHistoryFilterPicker` chip and the other places G1 lists |
| BBAccent | `Colors.accent` | #E8B49B | #EFBFA6 | warm peach accent (also copied to the widget); on the Growth cards the "below" tier tint. As text ink it is 1.84 on the light surface, so there it is a mark, never text ink (G23: in code on the percentile card at e3d45e2 and on the other cards at 855227f) |
| BBOnAccent | `Colors.onAccent` | #171420 | #171420 | **from 1.3.0** (decided 2026-11-03) — text on a BBAccent fill: the plan picker's savings badge (`PlanPickerSection.swift:185`), on the paywall and on the onboarding Premium page. One value in both modes, because the peach is light in both: white on it was 1.84 / 1.66 (G18). App catalog only: the widget draws no text on the accent |
| BBBackground | `Colors.background` | #F6F3FB | #171420 | app background |
| BBSurface | `Colors.surface` | #FFFFFF | #221E2C | elevated cards, rows, badge discs |
| BBTextPrimary | `Colors.textPrimary` | #2D2837 | #F0EDF6 | body and titles |
| BBTextSecondary | `Colors.textSecondary` | #6B647C | #A29BB5 | captions, units, metadata, inactive. 5.12 in light on the background, 5.62 on the surface and at least 4.62 on the washes it sits on; #746D85 before 16f2802 (4.48 on the background), dark unchanged (G10) |
| BBSuccess | `Colors.success` | #7FC7A4 | #8FD4B2 | "within" ticks, trend chip wash, the "within" tier tint and a typical percentile's ring. As text ink it is 1.98 on the light surface, so it is a mark, never text ink (G23: in code on the percentile card at e3d45e2 and on the other cards at 855227f) |
| BBAlert | `Colors.alert` | #E05A5A | #E87373 | **only** growth flags and percentile tails (P1); deliberately rare. Under 4.5:1 as text in light (3.64 on the surface, 3.31 on the background): a flag's words are BBTextPrimary on its wash, and no delete draws it: the question and visit sheets' deletes take the platform red since 170d574 (G4) |
| BBFeeding | `Colors.feeding` | #E8A0B4 | #C98BA0 | category tint — feeding |
| BBSleep | `Colors.sleep` | #A9B0E8 | #8A93CC | category tint — sleep |
| BBDiaper | `Colors.diaper` | #E5C98F | #C4AA75 | category tint — diapers |
| BBGrowth | `Colors.growth` | #8FC9AC | #79B396 | category tint — growth |
| BBEvents | `Colors.events` | #C4ABDD | #A78FC2 | category tint — events |
| BBGradientStart | `Colors.premiumGradient` | #5D4893 | #5D4893 | premium hero / widget gradient, top-leading, one value in both modes, in the app's and the widget's catalogs; white reads 7.46 on it (G12, in code at 3bb4936; #6F5BA8 / #7E6BB8 before, under 4.5:1 for white words in both modes) |
| BBGradientEnd | `Colors.premiumGradient` | #7B68B6 | #7B68B6 | premium hero / widget gradient, bottom-trailing, one value; white reads 4.67 on it (G12, in code at 3bb4936; #A795D9 / #9C89CE before) |
| BBLaunchBackground | `Color("BBLaunchBackground")` | #D3BEE7 | #D3BEE7 | splash backdrop (one value) |
| BBSplashText | `Color("BBSplashText")` | #4A357E | #4A357E | splash wordmark/tagline over the art (one value), both lines at full strength: 4.87 or more under the tagline in portrait, 5.72 beside the figure (G17, G28; in code at 3bb4936; #F7F1E4 before, 1.1–1.5 over the art in portrait, 1.0 in landscape) |

Outside `Colors/`:
- `AccentColor.colorset` (system tint) = BBPrimary's values, #6F5BA8 / #A795D9.
- `WidgetResources/Colors.xcassets`: copies of BBAccent, BBFeeding,
  BBGradientEnd, BBGradientStart, BBOnPrimary, BBPrimary, BBSleep, BBSurface,
  BBTextPrimary, BBTextSecondary (10; since 1.1.0 they include the ones the Live
  Activity and the widget control need, `m1-live-activity.md` § 6). The pre-build
  script in `project.yml` compares all 10 with the app's and fails on drift
  (DECISIONS 2026-09-01).
- `ExportGenerator` (PDF/HTML): solid #6F5BA8 header and table heads with white
  text (5.6:1), #6F5BA8 card titles (5.0:1 on the card), #6B647C labels and footer
  (BBTextSecondary, 5.62:1 on white, 5.03 on the #F2F2F7 cards; #746D85 before
  16f2802); the other neutrals are iOS system greys
  (#1C1C1E text, #F2F2F7 cards, #F9F9FB even rows, #E5E5EA rules). Solid because
  white on the old gradient's light end (#A795D9) was under 3:1; BBTextSecondary's
  value because #8E8E93 on white was 3.3:1. `DoctorReportPDF` holds its own constants, four of
  them the light colorsets' values (`m2-doctor-report.md` § 5). Accepted
  duplication: the PDF renderer cannot read the Asset Catalog.
- Platform red (`role: .destructive`, `.red`): the system's destructive colour,
  #FF383C / #FF4245 on iOS 26 (#FF3B30 / #FF453A on iOS 17–18), taken from the
  system and never re-valued. It is the app's one destructive red and marks only
  a delete: the delete-all button (red words and a red@0.2 stroke, no wash,
  since 16f2802), the swipe action, the photo's Remove (at full strength since
  16f2802), the question and visit sheets' deletes (through their role since
  170d574), and from 1.3.0 Delete Dose and Delete Medication (G4). On the
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

Decided 2026-11-04 (G23), in code on the percentile card at e3d45e2 and on
the other cards at 855227f: a tier tint (BBSuccess "within", BBAccent
"below", BBAlert a percentile tail) is a mark, never text ink: the percentile
ring, the newborn tick, or the **tier dot** before a verdict word. The dot
(`BBTierValue`, § 7) is drawn inside its word's run of text: a filled circle
7/13 of the word's size across (7 pt beside a 13 pt word at Large), in the
tier tint, 5/13 of the size before its word and glued to it by a word joiner
(U+2060), so it stays on the first line beside the first word. It sits on the
baseline, its centre within a fifth of a point of the x-height middle (3.4 pt
above the baseline at 13 pt semibold), scales with its word, and is silent to
VoiceOver: the value's words are the label. A wrapped second line starts at
the text's leading edge, under the dot. The word and any figure beside it are
BBTextPrimary (14.28 / 14.05); a "not yet" stays BBTextSecondary, and a
reading with no tier ("above") has no dot. The newborn figure is BBTextPrimary
beside a 20 pt success tick. A mark whose meaning its word states needs no 3:1
(WCAG 1.4.11).

In code at fa5c55f (G24, decided 2026-11-04): the same for the category tints.
BBFeeding, BBSleep and BBDiaper are marks: the timer card's wash and 1.5 pt
stroke, the glyph disc, the week chart's bars, a slider's track. The words and
figures beside them are BBTextPrimary in both modes: the timer cards' label and
digits (12.41 / 12.42 on the card's wash, 14.03 / 14.09 in dark), Home's
timer digits, the week chart's value and today's day, and the bottle volume
(14.28 / 14.05 on the surface), as the Live Activity and `BBMeasureSlider`
draw theirs. No mark was added and no width changed.

In code at 16f2802 (decided 2026-11-04):
- BBTextSecondary in light #6B647C, the same hue and chroma a little darker
  (OKLCH L 0.550 → 0.518), dark unchanged: 5.12 on the background, 5.62 on the
  surface and at least 4.62 on every wash secondary words sit on. The
  widget's copy and the PDFs' constants take the same value, and the
  onboarding backdrop's two primary blobs are at 0.08, from 0.16 and 0.12 (G10).
- The week chart states every value up to today above its bar, at a fixed
  11 pt semibold, today's in BBTextPrimary and the other days' in
  BBTextSecondary, silent to VoiceOver, and has no axis numbers; the grid lines
  stay, and the bars stay as they are, marks whose figures the text states
  (G25). This took the place of G24's line for the tallest bar's value.
- A primary wash under BBPrimary words is laid over BBSurface: the selected
  tiles (primary@0.12) and the primary pills (@0.10: the secondary button,
  Home's age pill, the diaper norm chip, the medication chips, the fact chip,
  the add-weighing button, the corrected-age chip) read 4.78 and 4.91
  whatever is under them (G26).
- Words are drawn in a red under 4.5:1 only as a delete in the platform red
  (accepted at 3.25, above): a purchase error's words in BBTextPrimary after a
  platform-red `exclamationmark.circle.fill`, hidden from VoiceOver, a mark
  (3.25 over its 3:1); the photo's Remove at the full platform red and the
  delete-all button without its red wash (G4); no over-limit red (G5). The
  stool-colour warning's orange words stay: the one exception (G3).

In code at 3bb4936 (decided 2026-11-04), the gradient, the marks and the splash:
- The brand gradient one step deeper in its own hue, one pair in both modes:
  BBGradientStart #5D4893 and BBGradientEnd #7B68B6 (OKLCH L 0.460 → 0.569),
  every word and glyph on it white at full strength, 7.46 at the start and
  4.67 at the end; the hierarchy by size and weight (G12). The hero's
  BrandMark keeps its white@0.35 ring, a badge's edge (§ 7).
- An unchecked or unselected mark in BBTextSecondary at full strength, the
  checked one in BBPrimary (G27): Export's range circle and category square
  (`ExportView.swift:141`, `:180`).
- BBSplashText #4A357E, one value, both splash lines at full strength (G17).

### Data colours (not tokens)

Domain enums carry hex strings rendered with `Color(hex:)` — no dark variants:
- `FeedingEntry.type` — breast #E8A0BF, formula #B0C4F5, pumped #D4A8D5
- `CustomEvent.type` — bath #B0C4F5, walk #A8D5C2, medication #F5D6A0, mood #E8A0BF, custom #D4A8D5
- `DiaperEntry` stool swatches — yellow #F5D55F, green #6BBF6B, black #2C2C2C, brown #8B5E3C, orange #F5A45F, red #E05A5A, white #F0F0F0 (these depict a real colour, so a literal is defensible here). The selected swatch's check is a literal beside them, `StoolColor.checkHex` (from 1.3.0, G19): #171420 on yellow, green, orange, red and white; white on brown and black. White and Black carry a 1 pt BBTextSecondary edge inside the disc, flagged by `StoolColor.needsEdge` (from 1.3.0, G20).

### Measured contrast

| pair | light | dark |
|---|---|---|
| textPrimary on background | 13.0 | 15.7 |
| textSecondary on background (4.48 with #746D85, before 16f2802) | 5.12 | 6.8 |
| textSecondary on surface (4.9 before 16f2802) | 5.62 | 6.1 |
| primary on background | 5.1 | 6.9 |
| primary on surface | 5.6 | 6.2 |
| white on primary (buttons, FAB, selected chip) | 5.6 | **2.64** |
| BBOnPrimary on primary | 5.6 | 6.9 |
| white on `BBPrimaryButton`'s primary@0.8 end, over the background | **3.80** | **3.76** |
| BBOnPrimary on `BBPrimaryButton`'s primary@0.9 end (from 1.3.0) | 4.60 | 5.78 |
| white on accent (the plan badge before 1.3.0) | **1.84** | **1.66** |
| BBOnAccent on accent (the plan badge from 1.3.0) | 9.88 | 10.95 |
| textSecondary edge of the White / Black stool swatch on the background (from 1.3.0; a border, 3:1) | 5.12 | 6.82 |
| white on gradient end, before 3bb4936 | **2.64** | **3.05** |
| white on gradient start, before 3bb4936 | 5.6 | **4.48** |
| the widget's words at white@0.7–1.0 on the gradient, at their places, before 3bb4936 (G12) | **2.37–4.62** | **2.46–4.07** |
| white on the gradient #5D4893 → #7B68B6 (from 3bb4936), start / end; the widget's words at their places (G12) | 7.46 / 4.67; 5.21–6.68 | the same |
| the BrandMark's ring, white@0.35 on the gradient from 3bb4936, start / end (a badge's edge, not a state: § 7; 2.03 / 1.46 on the light plate before) | **2.32 / 1.87** | the same |
| alert on surface / background, as text | **3.64 / 3.31** | 5.53 / 6.17 |
| success / accent on the surface, as text ink on the Growth cards before 855227f (G23) | **1.98 / 1.84** | 9.47 / 9.82 |
| feeding / sleep tint as ink on its timer card, tint@0.08 over the background, before fa5c55f (G24) | **1.80 / 1.82** | 5.94 / 5.53 |
| textPrimary on the feeding / sleep timer card (G24, from fa5c55f) | 12.41 / 12.42 | 14.03 / 14.09 |
| textSecondary #746D85 on a tint@0.08 wash over the background, before 16f2802: feeding and sleep (diaper 4.36, growth 4.31, primary 4.05; G10) | **4.28** | 6.11 |
| textSecondary #6B647C (G10, from 16f2802) on background / surface / primary@0.08 over the background, its darkest wash; on the category washes over the surface | 5.12 / 5.62 / 4.62; 4.83–5.05 | unchanged |
| platform red (destructive text) on background | **3.25** | 5.29 |
| platform red on its red@0.06 wash (the delete-all button before 16f2802, which drew the wash away; G4) | **3.01** | 5.01 |
| feeding / sleep / diaper tint on surface (the week chart, the bottle volume: G24; the chart's bars: G25) | **2.08 / 2.09 / 1.61** | 5.95 / 5.51 / 7.25 |
| the week chart's other days' bars at their top, tint@0.5 on the surface (G25) | **1.42 / 1.41 / 1.26** | **2.51 / 2.40 / 2.85** |
| primary as words on primary@0.12 / @0.10 over the background: selected tiles, pills, before 16f2802 (G26) | **4.38 / 4.50** (4.499) | 5.71 / 5.92 |
| primary as words on primary@0.12 / @0.10 over the surface (G26, from 16f2802) | 4.78 / 4.91 | 5.04 / 5.22 |
| system orange words on their orange@0.1 wash (the stool-colour warning, G3, by design) | **2.13** | 6.14 |
| the Export screen's unselected circle textSecondary@0.3 / unchecked square @0.4 on the surface, before 3bb4936 (G27) | **1.48 / 1.71** | **1.72 / 2.10** |
| an unchecked or unselected mark in BBTextSecondary on the surface (G27, from 3bb4936; #6B647C in light) | 5.62 | 6.11 |
| BBSplashText #F7F1E4 over the splash art under the words in portrait, worst / median; in landscape, worst, before 3bb4936 (G17, G28) | **1.07 / 1.38**; **1.00** | the same |
| BBSplashText #4A357E (from 3bb4936) under the tagline, every portrait screen, worst (G17) | 4.87 | the same |
| BBSplashText #4A357E beside the art's figure, wordmark / tagline, worst (G28, from d3e94e8) | 5.72 / 5.74 | the same |

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
  a hyphen the word already has. One stated exception (decided 2026-11-06),
  the system's own Language picker row in Settings, which places
  its value and chevron itself and hyphenates a title it cannot fit beside
  them: en «Lan-» / «guage» at xxxLarge with Bold Text on 320 pt («Language»
  103.6 pt semibold; 98.9 regular sets one line); from AX1 the row stacks,
  its value at the row's leading edge. The hyphen marks the break. Why kept:
  a row and a list of our own for one hyphen, in one language at one size
  with Bold Text, would give up the system's selection list and its
  VoiceOver selected state.
- **Planned** (decided 2026-11-06): a dash never starts a line. A spaced em
  dash keeps a no-break space (U+00A0) before it, so a line that breaks
  there ends with the dash. The rule reaches every spaced em dash in the
  app's words, the widget's medium name, the source labels and the dash
  before a line break in the onboarding subtitle among them; only the two
  export file names keep a plain space, a file name not being set text.
  Where a word and its dash cannot keep one line, the dash goes: the feed
  titles read «Сцеженное 80 мл», «Смесь 100 мл», "Pumped 100 ml", "Formula
  100 ml". On 320 pt at xLarge ru «Сцеженное — 80 мл» set «Сцеженное» /
  «— 80 мл» in a history row, and the glued «Сцеженное —» (114.4 pt at 17
  semibold) is wider than the event row's title room there (111 pt), so the
  line would still break, at the no-break space. Why: a dash that opens a
  line reads as a list mark or a reply, and Russian setting never starts a
  line with one; a word and its amount read as one title without it. The
  row's fit (`SideBySideIdeal`) parts words at plain spaces only, so a word
  glued to its dash counts as one word and the time goes under the texts
  where it misses.
- A number keeps its unit, and an age or a span of time its words, by
  no-break spaces set at the phrase's writer, never in a format string
  (decided 2026-11-06 for the age and the report's phrases; in code at
  92c70db): an age from `Baby.describeAge` («11 месяцев», «3 semanas»), a
  report's period length and day and month from `ReportFormat.periodLength`
  and `dayMonth`, one writer for the report screen and its PDF («30 дней»,
  «28 сент.»), and a span of minutes from `DurationText.minutes`
  («2 ч 55 мин»: each number with its unit, the space between the parts
  plain; in code at 19a14f1). A format string's own spaces stay plain:
  Home's sleep line «2 ч 55 мин из 14 ч» (`progress.of_duration_fmt`, in
  code at c67ab7c) parts at «из», and a count «3 из 7» has no glue. A date
  that stands as a line of its own (a visit's date) is not glued: glued, it
  is wider than its line at the largest sizes and would break inside a word
  instead of between words. Glue cannot hold a phrase wider than its line
  either, since the text engine then breaks it at the no-break space; there
  the row gives the words room (Settings' baby row, § 7). At AX2 on 320 pt
  the glued phrases keep one line: Home's age pill at most 147.0 pt
  («11 месяцев», Bold Text) of the 228 beside the avatar, and the report
  screen's head line's widest run 124.7 («28 сент.») of about 264. Why at
  the writer: one source leaves no caller to forget, and the screen and the
  PDF break the same way.
- A label that shares a line with its controls stacks above them; a date
  picker's label stands above its pills at every size: `BBLabeledPicker` (§ 7).
- A placeholder that is a field's only label stays whole:
  `bbPlaceholderLabel` (§ 7).
- A sheet's title moves from the bar into the content, from xLarge on:
  `BBSheetHeading` (§ 7).
- A screen's large title moves from the bar into the content wherever it
  misses the bar's one line: `BBScreenHeading` (§ 7, G31; from 1.3.0, in
  code at 7b886b1).
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
c813d99, 427d55e and 6f66d45), and so do the tracker screens' remaining words,
Home's quick actions and running-timer card and onboarding's gender row
(decided 2026-11-04, in code at 4259dd0 and 54af23c):
- A word set at a fixed point size (G2) takes `scaled(<its size>,
  relativeTo: .body, weight:, design:)` with its size, weight and design, so
  "Large" stays pixel-identical. A tile's glyph scales with its word: Diaper
  type 22, Feeding type 22, Sleep type 24 and Sleep location 20, as on the Add
  Event type and mood tiles, and the quick and start glyphs: the Diaper
  screen's 28 (`DiaperView.swift:110`), the Events quick tile's 26
  (`EventsView.swift:117`) and the Sleep screen's 30 (`SleepView.swift:122`),
  whose 13 pt «Начать» caption scales too. A glyph that stands over or beside
  its word grows with it the same way: the Diaper norm chip's 13 pt target
  (`DiaperView.swift:206`) and onboarding's 34 pt gender figure
  (`Onboarding/Pages/BirthPage.swift:99`).
- These stay fixed: a colour swatch and its check (the 36 pt stool disc, on
  whose geometry G20's edge sits); an icon plate with the glyph inside it (the
  stat card's 36 pt plate and the glyphs of its top row, the Feeding quick
  tile's 44 pt plate, Home's 60 pt quick-action disc and 48 pt timer plate);
  the profile photo's figure and its 30 pt camera plate; decorative figures
  (empty-state art); the widget and the Live Activity (§ 9); the PDF. The
  Growth sheet leaves its ruler out at accessibility sizes (§ 7,
  BBSheetHeading).
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
  that misses takes fewer columns from the first size where it misses.
- **A row of equal columns keeps one shape per text size at every width; a
  row whose width follows its content takes its shape from the fit** (in
  force, decided 2026-11-04, in code at 4259dd0 and 54af23c). Equal columns:
  `ViewThatFits` compares a row's whole width, not its narrowest column, so a
  count that follows the width would need a measuring layout, and one screen
  would take two shapes at one text size; `BBTileColumns` (§ 7) states the
  row's count at each size. The one exception is Home's quick actions, which
  have that measuring layout (below; decided 2026-11-04, in code at
  95525c6); any other equal-column row that wants one needs its own
  decision. Content width: a row with no columns, whose whole
  width is the right measure. The Feeding timer's side pills
  (`FeedingView.swift:287`) stand three in a row while the row fits the card,
  else one per row, flush left; every timer card's top (`BBTimerFit`, § 7)
  sets what is running beside the digits while both fit one line, else above
  them. Their width follows the words and the running time, so a count per
  size would assume the widest: the es pills (263.8 pt at Large) are wider
  than the 240 pt card on 320 pt from Medium up, and hours past an hour of
  sleep or three-digit minutes past 100 minutes widen the digits. Both stack
  at accessibility sizes on any width, so the running cards keep one shape at
  the largest text. The weight gain card's number and its interval share a
  row while both fit whole, else the interval goes under the number, xs 4
  apart, leading (`GrowthInsightCards.swift:612`, in code at e8abca8):
  squeezed beside it the number broke at its slash, and alone it still breaks
  there at AX2 on 320 pt in en and es. The Today feeding card's time since the
  last feed stands beside its plate while each of its words fits the room
  there, wrapping between words, else on its own line under the plate,
  leading, sm 8 below it (`BBCard.swift:38`, in code at 4f3c86c): on 320 pt at
  Large that room is 31.7 pt, so ru stacks every form («назад» 35.3) and en
  «47h ago» and es «hace 47 h» keep the row on two lines; on 375 and 402 pt
  and at accessibility sizes it stands beside the plate as shipped. A
  no-break space keeps a number with its unit. Both change shape with their
  figures, as the timer cards do past an hour. A content-sized row whose words hold at 320 pt at every
  size below the accessibility sizes branches on the text size, because no
  width changes the answer: the Diaper screen's Today row (title and norm
  chip, `DiaperView.swift:140`; +56.8 pt at xxxLarge, −19.5 at AX2).
  `BBEventRow` branched on the text size too (the time under the texts at the
  accessibility sizes, in code at fa7de91), but its titles did not hold beside
  the time at 320 pt below them: ru «вскармливание» broke from Large (−10 pt
  in the history row), en «Breastfeeding» from xLarge (−12). Decided
  2026-11-05 and in code at 42a74fe: the row goes by fit, the time under the
  texts wherever a word of the title or the second line misses beside it
  (`SideBySideIdeal`, § 7). A row whose shape would change under the parent's own edit
  (picking a date with a longer name) keeps one shape per size
  (`BBLabeledPicker`, decided 2026-11-04).
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
  measured again before it ships. Four rows: the stool grid at Large, the
  profile sheet's feeding row at Medium and Large, the Feeding screen's
  quick-add row at Large and the Feeding sheet's breast-side chips at Medium
  and Large (the last two decided 2026-11-04, in code at 4259dd0). Why: there
  the spare would change the default screen or sheet on every phone (the
  seven swatches 3 + 3 + 1; the three feeding tiles, quick tiles and chips
  2 + 1), and the spare covers what is not measured, while both weights are
  measured there.
- Where its count does not change, a row of tiles that is an `HStack` stays
  one, because a grid sets it a third of a point lower. A tile name of two
  words that wraps at accessibility sizes is centred in its tile. Below them
  none wraps on 320 pt: es «Sueño nocturno», the longest, keeps one line in
  its half of the Sleep sheet at xxxLarge (121.9 pt in 136.0, +14.1; +7.6
  with Bold Text, selected or not, since the border lies outside the fill
  from 1187418; +4.6 inside it before) and wraps
  from AX1 (142.3, −6.3), where `SleepView.swift:275` centres it. Three tiles
  in two columns set 2 + 1, the third at half width under the first, at every
  size: the Feeding type, Diaper type, Sleep location and profile feeding rows,
  and from xLarge the Diaper and Feeding quick-add rows and the breast-side
  chips.
- **A selected tile's or chip's border is drawn outside its fill** (decided
  2026-11-04, in code at 1187418: `bbSelectedBorder`, § 7; G29). The 1.5 pt BBPrimary border's inner edge lies on
  the fill's edge and its outer edge 1.5 pt beyond it, on a shape whose
  corner radius is the tile's plus 1.5 (a capsule stays a capsule). The fill,
  the layout and the unselected tile stay as they are. Why: a word's room is
  the tile's width less its padding (above), and a border drawn inside took
  1.5 pt a side of it on every tile without side padding, which no count
  measured; drawn outside it takes none, so the table's numbers hold for the
  selected tile too. With Bold Text on 320 pt the inside border lay over the
  word's box at three sites: the breast-side chips at Large (es «Izquierdo»
  with its glyph, −1.0 a side), the profile feeding tiles at Large (ru
  «Смешанное», −1.0) and the Sleep type tiles at AX2 (ru «Ночной сон» on one
  line, −1.1). Outside they keep +0.5, +0.5 and +0.4; on the outline, half
  inside, −0.2, −0.3 and −0.3. The cost: the border reaches 1.5 pt into the
  gap beside the tile, so tiles sm 8 apart keep 6.5 to their neighbour, md 16
  apart 14.5, and the md margins of a sheet or a section 14.5. Without Bold
  Text every word on 320 pt kept +0.7 a side or more inside the border, and on
  375 pt every word keeps +5.2 or more with Bold Text whichever way it is
  drawn. The sites: the Feeding sheet's type tiles and breast-side chips, the
  Feeding timer's side pills, the Sleep sheet's type and location tiles, the
  Diaper sheet's type tiles, the Add Event type and mood tiles, the profile
  sheet's gender and feeding tiles, and onboarding's gender tiles and feeding
  rows (lines in G29). The border is laid after the tile's `bbShadow`, so the
  shadow keeps the fill's outline and selecting changes the ring only; the
  tile's VoiceOver frame takes the ring in, 1.5 pt a side, and with 6.5 pt or
  more between rings no two frames meet.
- **A title and its trailing value** (decided 2026-11-04, in code at c090a8e, `BBValueRow`, G30). A row with a
  title at its leading edge and a value at its trailing edge (a status, a
  figure, a count, a badge) keeps the value whole: it never wraps or shrinks,
  and the title wraps only between its words. Below the accessibility sizes
  the value stands beside the title. A row whose title's longest word fits
  beside the value's widest form at 320 pt at every size below them keeps that
  shape below them, a branch on the text size as above; a row where it does
  not takes its shape from the fit: beside while title and value share one
  line, else the value under the title. At the accessibility sizes the value
  stands under the title on any width. Under the title the value is the
  title's next line, leading with its text, xs 4 below it (2 in a Settings
  row, as its hints). A value picked on the row itself keeps one shape per
  size: the medication menu's label stands above it at every size, as
  `BBLabeledPicker`'s does. Why: the value is the fact the row is for, short
  and bounded, so any break falls in the title, and only between words; a
  figure that changes under a slider's drag cannot change the row's shape when
  the shape follows the text size; the rows that take the fit change their
  value only with the account or the offer. Settings' iCloud Sync keeps its
  long first word whole where the system-drawn Language row beside it stays
  side by side below the accessibility sizes and hyphenates its title (the
  exception above); on 320 pt in ru it stacks from Large. The paywall's plan
  rows (decided 2026-11-06, in code at e58f04b) keep the savings badge beside
  only while the plan's name and its price each keep one line next to it: at
  xxxLarge the badge left the yearly price room for «$39.99 /» alone in en on
  320 pt and in ru on 375 pt, and on 320 pt in ru the price broke inside its
  number; the badge now goes under the price in all three. On 320 pt at Large «Синхронизация»
  beside «Выключена» misses by 9.2 pt, so the title broke inside the word; at
  the accessibility sizes on 320 pt the Premium badge, onboarding's sliders,
  the Export category rows with their «0» and the plan rows break a word
  beside their value, and the rows that still hold keep under 20 pt there.
  The rows, their lines and their numbers: G30.

Column counts by text size, checked at 320 pt, all in code at 95525c6 (1.3.0).
Lines at 95525c6; widths from CoreText in SF Rounded, within 0.1 pt of the
simulator's (a glyph's box as the simulator draws it). A count in bold differs
from c813d99; xSmall to Medium take Large's count; † marks a measured
exception; 4 / 2 is Home's fit (below).

| row | size | widest word | L | xL | xxL | xxxL | AX | where the count is set (word in its room at 320 pt) |
|---|---|---|---|---|---|---|---|---|
| stool labels (`DiaperView.swift:483`, grid `:462`) | 10 medium | ru «Коричневый» | 4 † | **3** | **3** | **3** | 2 | four hold at Large without the spare (62.4 in 66.0, +3.6; +0.2 with Bold Text) and break at xLarge (68.0, −2.0); three hold at xxxLarge (80.6 in 90.7, +10.1); two at AX2 (107.6 in 140.0) |
| Feeding type tiles (`FeedingView.swift:402`, row `:463`) | 12 medium | ru «Сцеженное» | 3 | 3 | 3 | **2** | 2 | three hold at xxLarge (80.2 in 90.7, +10.4) and miss at xxxLarge (86.9, +3.8); two at AX2 (118.0 in 140.0) |
| Diaper type tiles (`DiaperView.swift:409`, row `:437`) | 13 medium | ru «Грязный» | 3 | 3 | 3 | 3 | **2** | three hold at xxxLarge (67.6 in 90.7, +23.1) and break at AX2 (92.9, −2.2); two give 140.0 |
| Sleep type tiles (`SleepView.swift:317`) | 13 medium | ru «Дневной» | 2 | 2 | 2 | 2 | 2 | two at AX2 (97.4 in 136.0, +38.6); es «Sueño nocturno» keeps one line at xxxLarge (121.9, +14.1) and wraps at its space from AX1, centred |
| Sleep location tiles (`SleepView.swift:285`, row `:343`) | 11 medium | es «Cochecito» | 3 | 3 | 3 | 3 | **2** | three hold at xxxLarge (69.0 in 90.7, +21.6) and break at AX2 (91.8, −1.1); two give 140.0 |
| Diaper screen quick-add tiles (`DiaperView.swift:113`, row `:83`, padding sm at the sides) | 14 semibold | ru «Грязный» | 3 | **2** | **2** | **2** | **1** | three hold at Large (58.5 in 69.3, +10.8) and miss at xLarge (63.4, +5.9); two hold at xxxLarge (74.8 in 120.0, +45.2) and at AX2 (102.3, +17.7); one at accessibility sizes, the quick rows' shape (below) |
| Feeding screen quick-add tiles (`FeedingView.swift:142`, row `:107`, no side padding; the caption xs 4 a side, `:152`) | 13 semibold | ru «Сцеженное» | 3 † | **2** | **2** | **2** | **1** | three hold at Large without the spare (75.1 in 85.3, +10.2; +5.4 with Bold Text) and miss at xLarge (81.9, +3.4); two hold at xxxLarge (95.5 in 136.0, +40.5) and keep +4.6 at AX2, under the spare (−4.2 with Bold Text); one at accessibility sizes |
| Feeding sheet breast-side chips (`FeedingView.swift:431`, row `:489`, glyph xs 4 from its word, no side padding) | 15 medium, its glyph at the same size | es «Izquierdo» with its glyph | 3 † | **2** | **2** | **2** | **1** | three hold at Large without the spare (+5.0; +0.7 with Bold Text) and at Medium (+8.1; +4.0), the glyph's box measured on the simulator; they break at xLarge (−1.3); two hold at xxxLarge (+31.5) and break at AX2 (−8.9) |
| Sleep screen start tiles (`SleepView.swift:125`, row `:101`, padding lg) | 15 semibold | ru «Дневной» | 2 | 2 | 2 | **1** | **1** | two hold at xxLarge (75.1 in 88.0, +12.9) and miss at xxxLarge (83.2, +4.8); one gives 240.0 |
| Events quick tiles (`EventsView.swift:123`, grid `:105`, padding md) | 14 semibold | es «Medicamento» | 2 | 2 | **1** | **1** | 1 | two hold at xLarge (97.9 in 108.0, +10.1) and miss at xxLarge (105.5, +2.5); one gives 256.0 |
| Home quick actions (`BBButton.swift:121`, layout `DashboardView.swift:200`, card padding md, columns 0 apart) | 12 medium; a tile at least its 60 pt plate | ru «Подгузники» | **4 / 2** | **4 / 2** | **4 / 2** | **4 / 2** | **1** | four where the widest tile fits a quarter of the card as drawn, else two by two (below): on 320 ru goes two by two at every size (71.3 in 64.0 at Large, −7.3 on the simulator), en and es stand four (the 60 pt plate, +4.0); one at accessibility sizes, as the running cards above it |
| Add Event type tiles (`EventsView.swift:332`, grid `:322`) | 11 medium | es «Medicamento» | 3 | 3 | **2** | **2** | 2 | three hold at xLarge (77.2 in 90.7, +13.4) and miss at xxLarge (82.8, +7.8); two give 140.0 (AX2 122.8, +17.2) |
| mood tiles (`EventsView.swift:368`, grid `:358`) | 11 medium | ru «Беспокойный» | 3 | 3 | **2** | **2** | 2 | three hold at xLarge (80.3 in 90.7, +10.4) and miss at xxLarge (86.2, +4.5); two give 140.0 (AX2 127.9, +12.1) |
| stat-card title (`BBCard.swift:76`, `BBStatGrid` `:130`, card padding md) | 13 regular | en «Measurements» | 2 | 2 | **1** | **1** | 1 | two hold at xLarge (95.0 in 108.0, +13.0) and miss at xxLarge (100.8, +7.2); one gives 256.0 (AX2 151.9) |
| profile feeding tiles (`BabyProfileEditSheet.swift:284`, row `:193`, section padding md) | 13 medium | ru «Смешанное» | 3 † | **2** | **2** | **2** | **1** | three hold at Large without the spare (75.5 in 80.0, +4.5; +0.9 with Bold Text) and at Medium (72.0, +8.0, +7.9 on the simulator; +4.6 with Bold Text), and break at xLarge (82.3, −2.3); two hold at AX1 (112.3 in 124.0, +11.7) and break at AX2 (132.2, −8.2); one gives 256.0 |
| profile gender tiles (`BabyProfileEditSheet.swift:259`, row `:169`, section padding md) | 15 medium, its figure at `.body` | ru «Девочка» or «Мальчик» with its figure | 2 | 2 | 2 | 2 | **1** | two hold at xxxLarge (105.0 to 106.1 in 124.0, +19.0 to +17.9) and miss at AX1 (+0.8 to −1.4); one gives 256.0. The range is the figure's box, about 1 pt wider on the simulator than in AppKit |
| onboarding gender tiles (`Onboarding/Pages/BirthPage.swift:102`, row `:41`, page padding lg) | 15 semibold, its figure scaled 34 | ru «Мальчик» | 2 | 2 | 2 | 2 | **1** | two hold at xxxLarge (83.1 in 128.0, +44.9; +38.5 with Bold Text) and keep +13.6 at AX2 (+4.6 with Bold Text, under the spare); one, as the profile sheet's gender row, gives 272.0 |

A quick or start tile's glyph grows with its word, and in one column the tile
keeps its shape: glyph above word, centred, full width, as the Events quick
tile at accessibility sizes (in force, in code at 6f66d45). The Diaper
screen's quick-add tile takes sm 8 of horizontal padding, md above and below
(decided 2026-11-03, in code at 6f66d45): with md a side, ru «Грязный» broke
at Large on 320 pt (58.5 in 53.3). The Feeding screen's quick-add tile takes
none, 14 above and below (decided 2026-11-04, in code at 4259dd0): with sm a
side, ru «Сцеженное» broke at Large on 320 pt (75.1 in 69.3). The padding
sits inside the fill around a centred word, so 375 and 402 pt draw the words
where they were. The Feeding quick tile's caption keeps a two-line box (30 pt
scaled) in a row or grid, so every tile of the row is one height, and takes
its own height in one column. The caption takes xs 4 a side of its own, while
the tile keeps none (in force, decided 2026-11-04, in code at 95525c6,
`FeedingView.swift:152`): with the tile's none, a one-line caption ran onto
the border (es «Agregar manualmente» 0.0 and 1.0 pt from it on 402 pt), and sm
8 would break es «manualmente» on 320 pt with Bold Text (−3.4). With xs 4 on
402 the ru caption keeps one line, 7.3 and 6.7 pt clear of the border
(rendered); es on 402 and ru on 375 take two lines, as at 6f66d45; no caption
needs a third line at any size. The breast-side chip sets its glyph xs 4 from
its word, not the default 8 (decided 2026-11-04, in code at 4259dd0): with 8,
«Izquierdo» broke at Large on 320 pt with Bold Text. The quick and start rows
and Home's quick actions take one column at accessibility sizes.

Every tile row of the tracker screens, Home and onboarding's gender page is
checked at 54af23c, and the rows whose code changed since are checked again at
95525c6. Onboarding's feeding page is one column of full-width
rows, not a tile row (`Onboarding/Pages/FeedingPage.swift:49`): a fixed 46 pt
plate, the word at 17 semibold and, when chosen, a fixed 20 pt check leave the
chosen word 139.0 pt on 320 pt, where ru «Смешанное» misses at AX1 and AX2
(149.9 and 176.0) and holds at xxxLarge (+11.5, +2.9 with Bold Text); measured,
not rendered (G2).

The same surfaces' other fixed words scale too, with no change to their
layout: the stool-colour warning (`DiaperView.swift:499`, G3), the slider ends
and hint (`BBMeasureSlider.swift:32`, `:64`, `:86`; `FeedingView.swift:530`),
the timer hint (`FeedingView.swift:545`) and the stat card's trend chip
(`BBCard.swift:44`); on the tracker screens, Home and onboarding the Feeding
quick tiles' words (13 semibold) and captions (11 regular), the Feeding and
Sleep timer cards' labels (13 medium), Home's quick-action words (12 medium)
and timer subtitle (13 regular), the Diaper norm chip (13 medium) and
onboarding's gender word (15 semibold).

**One column for the quick rows at accessibility sizes is a shape, not the
rule's count** (in force, decided 2026-11-04, in code at 6f66d45). With sm
padding two Diaper quick-add columns hold at AX2 (102.3 in 120.0, +17.7; +7.9
with Bold Text), so the rule alone would give two: the three tiles would set
2 + 1, «Оба» alone at half width, beside the Events quick and Sleep start rows
in one column. The column rule sets the most columns a row may take, and the
quick and start rows take one at accessibility sizes, full-width tiles in one
shape.

**Home's quick actions stand four in a row while each tile fits its quarter of
the card as drawn, else two by two; one column at accessibility sizes** (in
force, decided 2026-11-04, in code at 95525c6). `QuickActionsLayout`
(`DashboardView.swift:677`, private to Home) takes the first of four and two
whose column holds the widest tile's ideal width, as drawn: in the app's
language, at the text size and with Bold Text, not from a table of widths. A
tile's ideal width is the larger of its word and its 60 pt plate, so en and es
stand four on 320 pt too, plates 4 pt apart as shipped: their widest words (en
«Feeding» 45.7, es «Eventos» 45.3; 47.7 with Bold Text) are narrower than the
plate, which fits a 64.0 pt quarter. ru «Подгузники» (71.3; 75.0 with Bold
Text) misses that quarter, so ru alone goes two by two on 320. The check takes
no spare: a live measure has no measuring error, no later word and no
unmeasured weight to cover. Where four stand, neighbouring words keep at least
4.6 pt apart (es with Bold Text at xxxLarge on 320, where the plates are 4
apart). Why: two by two on every phone put what follows the card 94.7 pt lower
on the default Home to cover 320 pt, and no padding or shorter word reaches
320, because the words name the screens the tiles open. This is the one
equal-column row whose count follows the width. Expected for ru below the
accessibility sizes, from CoreText (within 0.2 pt of the simulator at Large;
xLarge to xxxLarge not rendered; Bold Text measured, not rendered):

| ru «Подгузники» | Large | xLarge | xxLarge | xxxLarge |
|---|---|---|---|---|
| width, regular / Bold Text | 71.2 / 75.0 | 76.4 / 80.5 | 83.3 / 87.7 | 90.1 / 95.0 |
| four from, regular | 375 pt (+6.5) | 375 (+1.3) | 402 (+1.2) | 440 (+3.9) |
| four from, Bold Text | 375 (+2.8) | 390 (+1.0) | 440 (+6.3) | none |

en and es stand four on every width at every size below the accessibility
sizes (the plate's +4.0 on 320; +3.7 and +3.5 with Bold Text at xxxLarge).

In force (decided 2026-11-04, in code at b8e9a41):
- **A sheet's title moves into its content from xLarge**, not only at
  accessibility sizes (`BBSheetHeading`, § 7). In the bar the title would
  keep its Large size while the sheet's text grows, and its slot shrinks as the
  buttons grow: with words in the bar, in ru 131, 116 and 92 pt at Large,
  xLarge and xxxLarge on 402 pt (104, 89 and 65 on 375). At 17 pt semibold
  with the 0.6 floor, at xLarge on 375 pt ru «Новое кормление» (148.7), «Новое
  измерение» (148.8), «Приём у педиатра» (152.7) and «Редактировать профиль»
  (202.4) were cut, and at xxxLarge on 402 pt four titles shrank to 10.2–11.0
  pt. With glyph buttons (below) the slot stays, but the title would still be
  smaller than what it names: 17 pt while the sheet's text grows to 19–23 pt
  from xLarge to xxxLarge. The diaper norm editor, whose bar holds × alone,
  follows: up to Large the system title is its one heading; from xLarge its
  bar shows no title and its first heading, «Норма в день»
  (`DiaperView.swift:304`), takes the header trait. A second heading would
  repeat it.
- **A date picker's label sits above its pills at every size**
  (`BBLabeledPicker`, § 7), as the sheets' other captions do. At Large on
  320 pt the label missed beside the widest date and time pills before its
  gap was counted: ru «Время» −21.9, «Начало» −29.5, «Конец» −19.7, en «Time»
  −10.9 (12-hour time); the date-only ru «Дата измерения» kept 17.0, under
  the spare once the gap (at least 9.7 pt) was taken. On 375 pt ru «Время»
  missed from xLarge; on 402 pt it broke at xxxLarge («Врем / я», rendered).
  At the default size on 402 and 375 pt the pill stands flush with its label
  (rendered).
- **Text that wraps at some width takes its wrapped alignment at that size,
  so at every size**: the stool warning's triangle on the first line
  (`.firstTextBaseline`, `DiaperView.swift:497`) and the profile photo hint
  centred (`BabyProfileEditSheet.swift:339`); the Growth cards' ? stays on a
  wrapped title's first line (`InsightCardHeader`,
  `GrowthInsightCards.swift:35`, in code at e8abca8: at AX2 on 320 pt ru
  «Прибавка / веса» sets it 108.0–127.7 pt against a first line of
  101.3–130.0, where it stood between the lines at 123.0–142.7). At Large on 320 pt the ru
  warning wraps (253.4 pt in 247.0; es 259.0) and so does the ru hint (309.9
  in 288.0); es wraps at xxxLarge on 402 pt. The cost: with a warning colour
  picked, the warning and the fields below sit a pixel lower at Large, and the
  hint moves by a fraction of a pixel.

In force (decided 2026-11-04, in code at 265557e), for sheet titles at Large
(G21). Measured at 4259dd0 with the words of 78471f8: bar frames from the 26.3
hierarchy on 402 and 375 pt (edge 20, gap to the title 16, buttons 36 pt
high), CoreText widths for the words; the glyphs' contrast on the 265557e
renders.
- **A sheet's bar carries glyphs, not words**, on every iOS version
  (`BBBarButton`, § 7; 28 buttons in 17 bars): Cancel and Close as ×
  (`xmark`), Save as ✓ (`checkmark`), the visit sheet's Edit as a pencil
  (`pencil`). On iOS 26 each is the platform's glass circle, 37 pt wide (the
  toolbar plus on 26.3: 37 × 36 pt), where the words took 54 to 114 pt. Save
  is the prominent one, BBPrimary-tinted glass with a BBOnPrimary check, like
  the sheet's Save button. On the renders × reads 5.53 in light and 6.71 in
  dark against its glass, and ✓ 5.70 and 7.27 against the primary glass. Before
  iOS 26 the glyphs stand bare: Cancel and Close in BBTextSecondary (5.12 /
  6.82 on the background; 4.48 in light before 16f2802), Save and Edit in BBPrimary (5.12 / 6.86), a
  disabled Save in BBTextSecondary. On iOS 26 a disabled Save (the dose sheet
  before a medication is chosen) takes the platform's disabled look, exempt
  from P8 as an inactive control. VoiceOver reads each by its word in the
  app's language (`button.cancel`, `button.save`, `button.close`,
  `button.edit`), because the platform's own names follow the device's
  language. Hit areas stay 44 pt.
  - The title's room at Large is then 256, 229 and 174 pt on 402, 375 and
    320 pt in every language, against 131, 104 and 49 in ru with the words
    (es 149.5, 122.5, 67.5; en 190.1, 163.1, 108.1). All 48 titles, 16 in
    three languages, are whole at 17 pt on all three widths; the least spare
    is es «Nuevo medicamento», +10.6 on 320. With the words, ten ru and five
    es titles shrank at Large on 375 pt, and on 320 every ru title was cut.
  - Sheets with one button (the Growth sheet, the diaper norm editor) keep
    the title centred in the same room. The bars that hold Close alone (the
    Feeding, Sleep and Diaper screens opened as sheets, the growth
    explainer) take the × too; the paywall draws its own × already.
  - The word Save stays on the nine sheets with a Save button at the bottom.
    The question sheet, the visit sheet and the visit detail in edit mode
    have none, so there the ✓ is the only Save, as in the platform's own
    sheets on iOS 26.
  - iOS 17 and 18 draw the glyphs without the glass, so the room there is at
    least as wide. Not rendered: no iOS 17–18 runtime on this machine.
- **A sheet title is at most 166 pt at 17 pt semibold, and its floor is the
  sheets' caption size, 13 pt** (`minimumScaleFactor(13.0 / 17.0)`,
  `BBTheme.swift:370`, against 0.6, which reached 10.2 pt). 166 pt is whole at
  Large on 320 pt with 8 to spare. The budget keeps the floor from acting; the
  floor keeps a word over it from drawing smaller than the captions under it.
  Above Large the title is never in the bar, so the bar title has no size cap.
  ru «Редактировать профиль» (202.4) is the one title over the budget until
  «Профиль» (75.5, decided 2026-11-04) ships: whole at about 14.4 pt at Large
  on 320 pt.
- **The dose sheet's title, the medication's own name, sits in its content at
  every size** (`BBSheetTitlePlacement.content`, `DoseSheet.swift:95`,
  `:112`), and that sheet's bar shows no title. No budget holds a name the
  parent typed: «Нурофен для детей 100 мг/5 мл» (262.6 pt) would be 11.3 pt
  in the 174 pt room on 320 and 14.8 pt on 375, and past the floor its end is
  cut, where two medications' names often differ. In the content it wraps; one
  line of title3 holds 288 pt on 320. The sheet's fixed titles, «Отметить
  дозу» and «Изменить дозу», move with it.
- Not taken: shorter words alone, and the title in the content on every
  sheet. Words cannot reach 320 pt, where the ru room is 49 pt and the
  shortest ru title, «Вопрос», is 61.6. The heading costs each sheet 45.2 pt
  at Large (a 21.2 pt line of title3 and lg 24 to the next block), and the
  bar would lose the title the platform keeps there.

Decided 2026-11-04:
- **The diaper norm editor's × is Close, not Cancel** (in force, in code at
  2511a0b: `DiaperView.swift:371`, `BBBarButton(.close)`, read «Закрыть»).
  Its − and + write the stored norm at once (`DiaperView.swift:13`, passed as
  a binding), so the × keeps the change, and «Отмена» promised the opposite.
  Before the glyphs every user read the word; now only VoiceOver does. × is
  Cancel where it drops the sheet's edits and Close where nothing waits (§ 7
  `BBBarButton`). The bottom «Сохранить» names what the parent wants and
  stays.
- **A pushed screen's bar takes glyphs too: the medication screen's Edit is
  the pencil** (in force, in code at b57b678: `MedicationDetailView.swift:72`,
  `BBBarButton(.edit)`, read «Изменить»; 6.50 in light and 6.83 in dark on its
  glass on the renders). After the sheet bars it was the one word left in any bar of the
  app: every other bar item is a glyph (the screens' +, the report's share, the
  17 sheet bars), and the visit sheet's Edit, the same action, is already the
  pencil. G21's own reason, the title's room, does not reach it: the screen's
  bar shows no title (inline and empty, the name heads the content), and
  «Изменить» (103 pt on 26.3) fits beside the back button on 320 pt. Not
  taken: the word, which the platform's pushed screens often keep and which
  explains itself; its cost is one action in two looks.

In force (decided 2026-11-04), in code at 7335076 and 0334779:
- **A bar's confirm shows what it does: ▶ while the sheet starts a timer.**
  With Start Timer on, the New Feeding sheet's bottom button reads «Начать
  кормление» with ▶ (`FeedingView.swift:566–567`), and the bar's confirm
  shows `play.fill` and VoiceOver reads the bottom button's word
  (`button.start_feeding`; `BBBarAction.startFeeding`, `:581`); with the
  toggle off it is ✓ «Сохранить» again. Before, the bar's ✓ did the same as
  ▶ and VoiceOver named it «Сохранить». Same style as Save (§ 7
  `BBBarButton`); bar and bottom swap together, at once, when the toggle
  flips. One action, one glyph in both places. It is the app's one sheet that
  starts a timer (the only Start Timer toggle, `FeedingView.swift:543`). Not
  taken: no confirm in the bar while the timer
  is on (the bar changes under a toggle, and every entry sheet confirms in
  both places); ✓ named «Начать кормление» (the glyph says done while the
  tap starts a feed, and the sighted parent still sees two signs for one act).
- **Value rows that share a column of deltas take one shape together, by
  fit**: one line each while every row fits at full size, else every row
  stacked as at accessibility sizes, with no shrink (the weekly card,
  `teamdocs/design/m1-weekly-summary.md` § 4). A fit per row would set one
  delta at the column's edge and the next under its value. On 320 pt at Large
  the weekly sleep row is over its room beside its delta in en, ru and es
  (−23.8 to −57.7 pt, CoreText at a8369f8). The weekly card is the app's one
  column of deltas (`WeeklySummaryCard.swift:366`, at 7070300).

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
check: `grep -hoE '^(struct|enum) [A-Za-z]+' BabyBloom/DesignSystem/Components/*.swift | sort` → the names below (`HistoryFilter` is the picker's model, `BBBarAction` the bar button's, and `SideBySideIdeal` (`SideBySideIdeal.swift`) and `WidestWordIdeal` (`BBCard.swift:169`) the by-fit rows' measures; `EmptyStateView`, `AppAppearance`, `SettingsSwitchRow` and `SettingsRowLabel` live elsewhere; `BBSheetHeading`, `bbSheetTitle` and `BBSheetTitlePlacement` live in `BBTheme.swift`, and `bbPlaceholderLabel` is a modifier)

| component | file | purpose | used in |
|---|---|---|---|
| BBPrimaryButton | BBButton | full-width CTA: primary→primary@0.8 gradient, white 17 semibold, min 56 pt, radius lg, `button` shadow, loading state. From 1.3.0 the gradient ends at primary@0.9 and the label is BBOnPrimary (G1). **Proposed** (G38): md 16 inside each side (`padding(.horizontal, md)` inside the fill), so the glyph and the label get the button's width less 32 (240 pt on 320, 295 on 375), as a surface's words keep md 16 from its edge (§ 4) and `BBDeleteHistoryButton` already does. The label 17 semibold rounded relative to `.body`, letter-spacing 0, the SF line (20.0 pt at Large), centred (`multilineTextAlignment(.center)`), wrapping between words with no line limit (`fixedSize(horizontal: false, vertical: true)`); sm 8 above and below, so two lines keep the 56 pt (2 × 20.0 + 16) and a third grows the button. The glyph (17 semibold, the symbol's own design) sm 8 before the label, centred on its lines. Where the glyph and the label's widest word miss one line of that width, the glyph goes and the words stay, a mark beside words that say the action; only a word wider than the whole width steps the label down to the AX1 size (26.3 pt), then xxxLarge's (22.3), as `BBScreenHeading` steps down. Never cut, never broken inside a word, never shrunk to fit. The fit is `ViewThatFits(in: .horizontal)` over the label set one word a line (`WidestWordIdeal`), with the glyph, then without; the loading state keeps its spinner alone | Feeding, Sleep, Diaper, Events, Growth, Export, Medications (the list, a medication, DoseSheet, MedicationFormSheet), BabyProfileEditSheet, PlanPickerSection, Onboarding (Welcome, Fact, Notifications, GrowthShowcase, WidgetShowcase, OnboardingView) |
| BBSecondaryButton | BBButton | outlined companion: primary@0.10 fill, primary@0.30 stroke. **Proposed** (G38): `BBPrimaryButton`'s md 16 inset and its label and glyph rule, the words in BBPrimary | DoctorReport (QuestionsCard), since 1.2.0 |
| BBQuickActionButton | BBButton | 60 pt tint@0.22 disc + 26 pt glyph (a plate: both keep their size), xs 4 above a 12 pt medium rounded label in BBTextSecondary (14.1 pt line at Large); optional `LockBadge`. From 1.3.0 the label scales relative to `.body` (§ 3). Its ideal width is the larger of its label and its disc | Dashboard: four in a row while the widest tile fits a quarter of the card, else two by two (`QuickActionsLayout`, `DashboardView.swift:677`), one column at accessibility sizes (§ 3) |
| BBIconButton | BBButton | circular tint@0.12 icon button, 48 pt | — (unused) |
| BBScaleButtonStyle | BBButton | press feedback for every tappable (§ 8) | 11 feature files |
| BBBarButton + BBBarAction | BBBarButton | **from 1.3.0** (G21) — a sheet bar's button as a glyph: `.cancel` and `.close` ×, `.save` ✓, `.edit` a pencil. Each case owns its glyph and the word VoiceOver reads, in the app's language (`button.cancel`, `button.close`, `button.save`, `button.edit`). On iOS 26 the bar draws each in the platform's glass circle and Save is `.glassProminent`, BBPrimary tint with a BBOnPrimary check; before iOS 26 the glyphs stand bare, Cancel and Close in BBTextSecondary, Save and Edit in BBPrimary, a disabled Save in BBTextSecondary. Measured on the 26.3 renders: × 5.53 / 6.71 on its glass, ✓ 5.70 / 7.27. × is Cancel where it drops the sheet's edits, Close where nothing waits (the diaper norm editor's × is Close, in code at 2511a0b). A fifth case, `.startFeeding`, is a confirm that starts a timer: `play.fill` in Save's style, read with the bottom button's word (`button.start_feeding`), for the Feeding sheet while Start Timer is on (§ 3; in code at 7335076, `BBBarButton.swift:9`) | the 17 sheet bars and the medication screen's bar, 29 buttons: Add Event, Feeding, Growth, Sleep, Diaper, QuestionSheet, DoseSheet, MedicationFormSheet, VisitSheet, VisitDetailSheet (the pencil and, in edit mode, × and ✓), BabyProfileEditSheet, the diaper norm editor (Close), the three Home quick sheets, the growth explainer (Close) and the medication screen, a pushed screen (the pencil, in code at b57b678) |
| BBStatCard | BBCard | tonal KPI tile: 36 pt icon tile, metric value + unit + title, optional trend chip and chevron, whole card tappable, min 110 pt. From 1.3.0 its title (13 regular), unit (13 medium) and trend chip (12 medium) scale relative to `.body` (§ 3); the icon plate stays 36 pt. The trend chip stands beside the plate while each of its words fits the room there, wrapping between words, else on its own line under the plate, leading, sm 8 below it (in force, in code at 4f3c86c, `WordWrappingText` `:127`, § 3). The unit and title are BBTextSecondary on the tonal wash (4.83–5.05 in light from 16f2802; 4.28–4.36 with #746D85 before, G10); no over-limit red: `overLimit`, set by no caller, went with its red at 16f2802 (G5). A duration carries its unit words inside its value («10 ч 45 мин»; in code at 19a14f1): one Text cut into runs (`valueRuns`, `valueText`), the figures 28 semibold rounded relative to `title2` with monospaced digits in BBTextPrimary, the words and the spaces between them 13 medium rounded relative to `.body` in BBTextSecondary, the unit's own style, letter-spacing 0, the SF line; one line, scaling down to 0.6 as a whole. A weight or length keeps its unit as a Text of its own beside the value, 2 apart on the last baseline; a count has none. The words come from `DurationText.minutes`, the one writer of a span of minutes, which glues each number to its unit and keeps the space between the parts. Why: each of a duration's two units keeps the style a unit has on the tile, and one Text keeps the value on one line, scaling as one where two Texts would shrink apart | Dashboard, Feeding, Sleep, Diaper, Growth |
| BBStatGrid | BBCard | **from 1.3.0** — the grid of stat cards: two flexible columns 8 pt apart (the grid's own spacing), rows md 16 apart; one column from xxLarge and at accessibility sizes (in code at 6f66d45, through `BBTileColumns`), where a grown title no longer fits half the screen: en «Measurements» is 100.8 pt at xxLarge and 151.9 at AX2, and half a 320 pt screen leaves a card 108.0 pt inside its md padding (135.5 at 375 pt); one column leaves 256.0 (311.0) | Dashboard, Feeding, Sleep, Diaper, Growth |
| BBTileColumns | BBCard | **from 1.3.0** — a tile or grid row's column count at Large (and every smaller size), xLarge, xxLarge, xxxLarge and accessibility sizes, stated in one place; the counts come from the column rule (§ 3) | BBStatGrid; Diaper (quick-add, type, stool), Feeding (quick-add, type, breast sides), Sleep (start, location), Events (quick, Add Event type, mood), the profile sheet (gender, feeding) and onboarding (gender), from b8e9a41. Home's quick actions count by their own fit (`QuickActionsLayout`, § 3) |
| BBEventRow | BBCard | elevated list row: 44 pt tint disc, title (scaled 15 semibold), subtitle, trailing time. From 1.3.0 the subtitle and the time scale too (13 relative to footnote; time 13 / date 12 relative to footnote / caption1), because a medication row's subtitle carries its name and dose (`m3-medications.md` § 6). At the accessibility sizes the time and its date go on one line under the texts, so the title takes the row less the disc and paddings (196 pt on 320; in code at fa7de91, `BBCard.swift:214`). Below the accessibility sizes the row goes by fit (decided 2026-11-05, § 3; in code at 42a74fe): the time column beside while every word of the title and the second line fits, else the time line under the texts as at the accessibility sizes. The fit is `SideBySideIdeal` (`DesignSystem/Components/SideBySideIdeal.swift:13`): the least width at which both texts keep every word whole, measured on each text as set and with one word a line, words parted at plain spaces only, so a no-break space keeps a run one word; `ViewThatFits` takes beside only from that width. Beside the time on 320 pt, titles broke inside a word from Large in ru («Грудное вскармливание» −10 pt in the history row, +3 on Home) and from xLarge in en («Breastfeeding» −12), and at xxxLarge in 11 of the event titles; on 375 pt only ru «вскармливание» at xxxLarge in the history row (−5). By fit cures every case but ru «вскармливание» at AX2 on 320 (−8 under the texts), which breaks once and is kept | Feeding, Sleep, Diaper, Events, RecentActivity |
| BBProgressCard | BBCard | elevated card with 8 pt progress bar toward a target (`BBCard.swift:348`); the title and its value through `BBValueRow` (in code at c090a8e), by words from 1.3.0 (`BBProgressCard.Row`, `shape: .byWords`; decided 2026-11-06, in code at 1fb7ece, G36): below the accessibility sizes the figure stands beside while every word of the title keeps whole next to it, the title wrapping between its words («Мокрые / подгузники» beside «9 из 6» at xxxLarge on 320 pt), else under the title, as at the accessibility sizes. Under, the figure starts at the title's text past the glyph (`bbValueRowTitle`) and is offered only the width from there, so a long line wraps between its words short of the card's edge (ru «20 ч 40 мин из / 14 ч» at AX2 with Bold Text). The value by `measure` (from 1.3.0, decided 2026-11-06; in code at c67ab7c): `.count` «3 из 7» from `progress.of_fmt`; `.hours`, Home's sleep card, «2 ч 55 мин из 14 ч» from `progress.of_duration_fmt` («%@ из %@» / "%@ of %@" / «%@ de %@»), both sides from `DurationText.minutes`, each number glued to its unit and the two sides joined by plain spaces around the word between (§ 3); the current side rounds the seconds, then floors the minute, as the Sleep tile counts, and the target is whole hours. Past the target the line reads as it is, no alarm style. On 320 pt the sleep line stands beside «Сон» at Large (113 pt wide) and xxxLarge and under it at the accessibility sizes, «Мокрые / подгузники» wrapping between its words at AX-L. The faces relative to `.body` (`BBProgressCard.Face`; in code at 1fb7ece, G36): the title 14 semibold rounded, the figure 13 medium rounded, the glyph 14 semibold in the symbol's own design, so the figure keeps 13 : 14 with its title at every size (title / figure / glyph: Large 14 / 13 / 14, xxxLarge 18.33 / 17 / 18.33, AX1 21.67 / 20 / 21.67, AX2 25.33 / 23.67 / 25.33 pt), capped at AX2 with the type scale; no over-limit red: `overLimit`, set by no caller, went with its red at 16f2802 (G5). `progress.of_unit_fmt` («10 из 14 ч», whole hours) has no reader from c67ab7c. Why one writer on both sides: the Sleep tile beside the card shows the total to the minute, and whole hours on the card disagreed with it | Dashboard (feeding, sleep, wet nappies, `DashboardView.swift:490`), Diaper (the daily norm, `DiaperView.swift:182`) |
| BBSectionHeader | BBCard | **from 1.3.0** (decided 2026-11-06; in code at a298c62, `BBCard.swift:416`) — a section's title alone: title3, BBTextPrimary, leading, a `Spacer` after it. Its one action, Growth's «All» over the current measurements, opened the add sheet and went with `action` and `actionTitle`: once the floating + left Growth (G32) the bar's + is the screen's add, a second add in a header was a second door to the same sheet under a weaker word, and a scroll to the history reaches the section right under it | Dashboard, Feeding, Sleep, Diaper, Events, Growth, Medications (the list, a medication's doses), BBHistorySection |
| BBValueRow | — | **in code at c090a8e** (decided 2026-11-04; § 3, G30; `BBValueRow.swift:32`) — a title and its trailing value. Beside: `HStack(alignment: .center)`, `Spacer(minLength: sm)`, the value `.fixedSize()` with layout priority 1, the title wrapping between words. Under: the title, then the value from the title's text's leading edge (the `bbValueRowTitle` alignment guide; the row's leading edge where none is set), offered only the width from there, so a long value wraps short of the trailing edge (`UnderTitle`, `:100`; in code at c3d54a2); `underSpacing` below the title, xs 4 by default, 2 in the Settings rows, as their hints; an absent value adds no gap. At the accessibility sizes the value is always under. Below them `shape` picks: `.bySize`, the default, beside; `.byFit`, beside while every text of the title side keeps one line next to the value (`ViewThatFits(in: .horizontal)` of beside with the title `.fixedSize(horizontal: true, vertical: true)`, then under); `.byWords`, beside while every word of the title keeps whole next to the value, the title side's ideal width its widest word (`WidestWordIdeal`), for BBProgressCard (in code at 1fb7ece, G36). By fit: Settings' iCloud Sync row, whose value and hint sit in its `SettingsRowLabel`'s texts as a switch row's hint does, and the paywall's plan rows (decided 2026-11-06, in code at e58f04b; `PlanPickerSection.swift:164`). A plan row: the radio (18 regular rounded relative to `.body`, BBPrimary when selected, else BBTextSecondary), sm 8, then the BBValueRow. Its title side is the plan's name (15 semibold rounded relative to `.body`, BBPrimary when selected, else BBTextPrimary) over its price and period, 2 below (13 regular rounded relative to `caption1`, monospaced digits, BBTextSecondary), letter-spacing 0, the SF line; its value is the savings badge (11 bold rounded relative to `caption2`, BBOnAccent on BBAccent, 8 a side, 3 top and bottom, a pill), on the yearly row only. The badge stands beside while the name and the price each keep one line next to it, else under the price, xs 4 below it, at the name's leading edge, the radio staying at the row's left; at the accessibility sizes always under. The row: 14 top and bottom, md 16 a side, BBPrimary@0.08 when selected, else BBSurface, radius lg, a 2 pt BBPrimary stroke when selected, else 1 pt BBTextSecondary@0.15, the `card` shadow, one VoiceOver element. At xxxLarge the badge goes under in en on 320 pt and in ru on 320 and 375 pt. The medication menu is not on it: its label stands above it at every size (§ 3) | Settings (iCloud Sync, Premium), BBMeasureSlider, the Feeding sheet's bottle volume, BBProgressCard, Export's category rows, the plan rows |
| BBTierValue | BBTierValue | **from 1.3.0** (G23, § 2) — a value whose tier a dot carries: the words semibold at the caller's size relative to its text style (13 / `caption1` on Home and the Nutrition card, 14 / `body` on the Growth cards), in BBTextPrimary or the caller's text ink, led by a dot in the tier tint drawn into the words' own run of text: 7/13 of the size across (7 pt at 13, 7.5 at 14) and a 5/13 gap, both scaled with the style, on the baseline, its centre within 0.2 pt of the x-height's middle, glued to the first word by a word joiner (U+2060). A wrapped second line starts at the dot's x, the text's leading edge; the dot stays on the first line. The tint is resolved from the environment, so it follows a switch between light and dark; the tints are under 3:1 on the light surfaces and stand as marks beside words that say the verdict. VoiceOver reads the words, the dot is silent. In code at 855227f | Dashboard (`DashboardView.swift:598`), the Growth cards (`GrowthInsightCards.swift:628`), the Nutrition card (`NutritionSection.swift:156`) |
| Nutrition card rows | — (`NutritionSection`) | the card's three rows (gain, feeds, wet diapers): the label beside its status (BBTierValue) below the accessibility sizes, the status under the label at them. The three take one shape by fit (decided 2026-11-05; in code at 42a74fe, `ViewThatFits { rows(true); rows(false) }`, each row's beside width from `SideBySideIdeal`): all beside while every row keeps its words whole, else all stacked as at the accessibility sizes, so the eye does not jump between rows (the weekly rows' rule, 0334779). Beside, ru xxxLarge on 320 pt broke three words («12·в·сутки» 102 pt in 98, «Кормления» 105 in 98, «в·пределах» 112 in 106), and with Bold Text ru xxLarge one («подгузники» 103 in 100); stacked, the status lines wrap between words | Growth |
| Home growth rows | — (`GrowthSummaryRow`, `DashboardView.swift:589`) | **from 1.3.0** (decided 2026-11-06; in code at a298c62) — a label and its status on Home's growth card: the label 15 medium rounded relative to `.body`, BBTextPrimary; the status `BBTierValue` 13 / `caption1`; letter-spacing 0, the SF line; rows sm 8 apart. The card's rows take one shape by fit, the Nutrition card's: all beside while every row keeps its words whole (`SideBySideIdeal` per row, its chrome the two sm 8 gaps and the spacer's least sm 8; one `ViewThatFits` over the rows, `summary`, `:362`), else all stacked as at the accessibility sizes, where they always stack. Beside: `HStack(alignment: .firstTextBaseline, spacing: sm)`, `Spacer(minLength: sm)`, the status trailing-aligned; stacked: `VStack(alignment: .leading, spacing: xs)`, the status leading. VoiceOver reads each row as one element. Beside on 320 pt at xxxLarge with Premium, words broke inside before: the status of en «Weight gain», and with Bold Text en «Weight Percentile» and ru «Перцентиль по весу» (at 42a74fe); now at xxxLarge en stacks, ru stays beside, ru with Bold Text stacks, every word whole. Why: the rows read as one list, as the Nutrition card's do, and a branch on the text size cannot see a word that misses below the accessibility sizes | Dashboard |
| Paywall feature card | — (`PremiumFeatureList`, `PaywallView.swift:172`; `PremiumFeatureRow`, `:226`) | **from 1.3.0** (decided 2026-11-06; in code at e58f04b) — the four Premium features, one list for the paywall sheet and onboarding's Premium page, the same offer at two moments. A row: the icon in a 34 pt square (15 semibold in BBPrimary on BBPrimary@0.1, radius 9), the text (15 medium rounded relative to `.body`, BBTextPrimary, letter-spacing 0, the SF line, wrapping between its words), the BBSuccess check (`checkmark.circle.fill`) at the trailing edge; 10 top and bottom, md 16 a side; a divider between rows, inset md; the card BBSurface, radius lg, the `card` shadow. VoiceOver reads each row as one element, its text alone. The four rows take one shape by fit (`ViewThatFits(in: .horizontal)` over the two lists): all beside (the icon, md 16, the text, a `Spacer`, the check) while every word of every row fits there, the text's ideal width its widest word (`WordWrappingText`, `BBCard.swift:155`) and a list's ideal its widest row's; else all under (the icon and the check on one line, the text sm 8 under them from the leading edge, across the row); under at every accessibility size. Why: rows of one shape read as a list, as the Nutrition card's do, and two rows under their icons next to two beside read as a broken card (`DECISIONS.md`, 2026-11-06). On 320 pt in ru the card is under from xLarge, where «Неограниченная» misses beside its icon, and by xxxLarge «Расширенная» misses too; it stays beside at Large there, up to xxxLarge in en on 320 pt, and in both languages on 375 pt. Before, beside below the accessibility sizes, «Неограниченная» broke inside the word on 320 pt in ru from xLarge | Paywall, Onboarding (Premium) |
| Home header | — (`DashboardView.headerSection`, `DashboardView.swift:127`) | the greeting (15 medium rounded relative to `.body`, BBTextSecondary) over the baby's name (`title1`: 26 semibold SF Pro relative to `.title2`, tracking −0.3, BBTextPrimary) over the age pill (14 medium rounded relative to `.body`, BBPrimary on BBPrimary at 0.10 over BBSurface, 10 / 4 padding, pill radius), 4 apart, leading; the avatar (52 pt, a 1.5 pt ring in BBPrimary at 0.15) at the trailing edge, top-aligned; md 16 above; the other texts at letter-spacing 0, the SF line. **Proposed** (G37): where the name's widest word misses beside the avatar (228 pt on 320 at AX1 and AX2), the greeting keeps the avatar's row, wrapping between words, and the name and the pill go under that row at the full content width (288 on 320), 4 apart; the name wraps between words with no line limit, and only a word wider than the full width steps down to `title2`, then `title3`, as `BBScreenHeading`; never cut, never broken inside. The fit is the Settings baby row's: `ViewThatFits` over the row set one word a line. Where the name fits beside the avatar nothing changes; VoiceOver's order stays greeting, name, age, the profile button | Dashboard |
| Growth history row | — (`GrowthEntryRow`, `GrowthView.swift:744`) | **from 1.3.0** (decided 2026-11-06; in code at a298c62) — a weighing in Growth's history: a 44 pt tile (growth@0.22, radius 10, an 18 pt `scalemass.fill` in the growth tint), md 16, then the values, weight and length (`Label`s, 14 semibold rounded relative to `.body`, BBTextPrimary, each number glued to its unit by a no-break space), 4 apart over the head line (12 regular rounded relative to `caption1`, BBTextSecondary), and the date (13 medium rounded relative to `.footnote`, BBTextSecondary, `BBEventRow`'s time: 55.6 pt at xxLarge, 61.6 at xxxLarge); md 16 padding, the surface, radius md, the card shadow. A value is one line at its full size, never shrunk or cut. The row goes by fit as `BBEventRow`: below the accessibility sizes the date stands at the trailing edge while every value and every word of the head line keeps whole beside it (`WidestWordIdeal` over the values and the head line one word a line), else on a line of its own under the texts, leading, 4 apart; at the accessibility sizes always under. The values stand side by side md 16 apart while both fit whole, else one under the other, 4 apart, at every size. Each row fits on its own, as each event row does, so one list can mix the two shapes: at xxxLarge with Bold Text on 320 pt en «Nov 6» stands beside its values and «Oct 28» goes under its row's; kept, as in every list of event rows. Before, on 320 pt at xxLarge, ru «4,29 кг» drew «4…» in 47 pt and «55 см» «…» in 42, beside a fixed date «6 нояб.» 46 pt wide (at 42a74fe). Why: a value is the fact the row is for and is never cut (§ 3), and a fixed date took the values' room first | Growth (the measurement history) |
| Report weighing row | — (`GrowthReportCard`) | **from 1.3.0** (decided 2026-11-05; § 3, G35; in code at 80d2e54) — a weighing in the report screen's Growth card, one Text: the date in `callout` (16 regular rounded relative to `.callout`) with « · », then the values in `metricSmall` (17 semibold rounded relative to `.body`, monospaced digits), weight and length joined by « · », BBTextPrimary, letter-spacing 0, the SF line (20.3 pt a line at Large, measured), wrapping between words; at accessibility sizes the date as a caption (12 medium rounded relative to `caption1`, tracking 0.3, BBTextSecondary) over the values, xs 4 apart. A weighing with a head value adds a line under its values, «Head: 38.5 cm» from `growth.head_fmt` split at its %@ as `ReportRow` splits a row's key: the words in `callout`, the figure in `metricSmall`, BBTextPrimary, never stacked; 0 apart below the accessibility sizes (the row 20.3 → 40.7 pt at Large on 320 pt; a year-dated row, its date and values on two lines, 61.0 with its head), xs 4 at them (69.7 → 110.7 pt at AX2 on 320). It sets one line at every size: 112.2 / 123.1 / 128.3 pt at Large (en / ru / es) and about 202 / 222 / 232 at AX2, in the card's 256 pt on 320 and 338 on 402. Leading, full width, growing in height (`fixedSize(horizontal: false, vertical: true)`); VoiceOver reads the row as one element: date, values, head. No line without a head value | the report screen (`GrowthReportCard.swift:132`) |
| Export format card | — (`ExportView`) | **in code at c090a8e** (decided 2026-11-04, G29): sm 8 a side inside each tile for the glyph, the name and the description (11 pt regular rounded, fixed, centred), the two tiles of the taller one's height, each laid from its top. **From 1.3.0** (decided 2026-11-05, G33; in code at 361abe5): the PDF tile's description says what the file holds, without «report» / «отчёт» / «informe»: «Every entry, day by day» / «Все записи по дням» / «Cada registro, día a día» (117.6 / 106.1 / 116.7 pt), one line from 375 pt; on 320 pt en and es take two lines, «Every entry, day / by day» and «Cada registro, día / a día». **Planned** (decided 2026-11-06): «day by day» and «día a día» held together by no-break spaces, so those lines break at the comma; ru keeps one line. Why: "day by day" is one idea, and half of it alone on line 2 reads as a stray word. Then, sm 8 under the tiles, a caption pointing to the doctor's PDF, «For the doctor’s visit: More › For the pediatrician» (`ExportDoctorHint`, `ExportView.swift:339`), its path built from the More tab's and the report row's own names (`tab.more`, `report.title`) so it cannot drift from them, a no-break space before « › » so no line starts with it: caption (12 medium rounded relative to `caption1`, tracking 0.3; 14.1 pt line at Large, 29.4 at AX2), BBTextSecondary (5.62:1 on the surface in light), leading at the card's content edge, 256 pt wide on 320 and 338 on 402, wrapping between words, no line limit, shown whichever format is selected. Plain text, not a link: a link would jump from Profile to another tab, which the app does nowhere else. VoiceOver reads «, » for « › », static text: «For the doctor's visit: More, For the pediatrician». Lines at Large on 320 / 402 and at AX2, as built: en 2 / 1 and 3 / 2, ru 1 / 1 and 2 / 2, es 2 / 1 and 3 / 2 | Export (`ExportView.swift:34`, the tile `formatButton`) |
| Export category rows | — (`ExportView.categoryToggle`, `ExportView.swift:174`) | a category to include: a 30 pt tile (the glyph 15 semibold in BBPrimary on BBPrimary at 0.1, radius 8), md 16, the name (15 medium rounded relative to `.body`, BBTextPrimary) and, for a category with no entries, its «0» (13 medium rounded, fixed, BBTextSecondary) through `BBValueRow` (in code at c090a8e), then the check square (20 pt); 10 pt above and below; a category with no entries at 0.4 and disabled. **From 1.3.0** (decided 2026-11-06; in code at 361abe5): no lines between the rows, as shipped since 4c0481c; the `Divider` after the `return`, which never ran, went. Why: each row's tinted tile and its 10 pt above and below part the rows, the date-range rows above have no lines, and the screen reads right as shipped | Export |
| SettingsSwitchRow + SettingsRowLabel | — (`Features/Profile/SettingsRows.swift`: `SettingsSwitchRow` `:92`, `SettingsRowLabel` `:8`) | **from 1.3.0** (decided 2026-11-06; in code at a298c62) — a Settings switch with a line under its title, and a Settings row's icon and texts. The texts: the title (the row's `body`, BBTextPrimary) over its hint (`footnote`, BBTextSecondary), 2 apart (`VStack(alignment: .leading, spacing: 2)`); the icon in BBTextPrimary. Below the accessibility sizes the switch goes by fit: beside as the system row (a `Toggle` around one `Label`, the icon centred on the title and hint, the hint at the title's leading edge) while every word of the title and the hint keeps whole beside it, else under the texts, its leading edge at the title's x, sm 8 under the hint; at the accessibility sizes always under. The beside width is the same row set one word a line (`ProbedIdealWidth`, `:71`): asked its ideal width, a Label in a List at the accessibility sizes answers its icon's column alone (59.7 pt at AX2), so hidden copies give `ViewThatFits` the words' width, and the probe sets `.body` itself so Bold Text is measured. At the accessibility sizes `SettingsRowLabel` keeps the system Label while each text's first word fits beside the icon, else sets the icon on a line of its own above the texts, leading, xs 4 apart. With the icon beside, the Label sets it as a first-line indent of each text: the hint's first line starts at the title's x and its later lines run under the icon (at AX2 on 320 pt ru «Приходит / утром / по понедельникам.»), the system Label's layout, the same before; kept. VoiceOver reads one switch with the title and the hint in either shape. Why one Label: a Label nested in a VStack put its icon on a row of its own (iOS 26). Before, beside the switch on 320 pt ru «использования» broke from xxxLarge (158.3 pt; the column lay in [134.0, 158.3)), and beside the icon «Синхронизация» at AX2 (236.6) and at AX1 with Bold Text, es «Sincronización» at AX2 (207.0). Now every Settings word in en, ru and es keeps whole, Bold Text included: on a 320 pt screen the ru switch goes under its line at xxxLarge, and the iCloud icon stands above its title at AX1 with Bold Text and at AX2 in ru and es, every other row's icon beside. Why: the words fit once the switch and the icon give back their room, so no shorter words; the icon moves only where a first word misses, since the Label already runs later lines under it | Settings: the weekly summary, Lock Screen timer (iPhone only) and usage statistics switches (`MainTabView.swift:271`, `:284`, `:322`); `SettingsRowLabel` also the iCloud Sync row (`ICloudStatusRow`, `AboutView.swift:8`), its status through `BBValueRow` |
| Settings baby row | — (`SettingsBabyRowLabel`, `Features/Profile/SettingsRows.swift:70`) | **from 1.3.0** (decided 2026-11-06; in code at 92c70db) — the baby's row at the top of Settings: the avatar (56 pt), md 16, the texts, a `Spacer`, the chevron (`chevron.right` 13 semibold, BBTextSecondary at 0.4). The texts: the name (20 semibold rounded relative to `.title3`, BBTextPrimary) over the age (14 medium rounded relative to `.body`, BBPrimary, from `Baby.describeAge`, its number glued to its word, § 3), 3 apart, leading; letter-spacing 0, the SF line. Below the accessibility sizes the row stands as before. At the accessibility sizes it goes by fit: beside while the row also fits set one word a line (`ViewThatFits(in: .horizontal)` over `ProbedIdealWidth`, the Settings switch rows' probe), else the avatar and the chevron on a line of their own above the texts (`VStack(alignment: .leading, spacing: sm)`; the avatar leading, the chevron trailing), the texts under them at the row's full width, the name wrapping between words. At AX2 on 320 pt in ru, beside the avatar the name broke «Алекса / ндра» before, and with Bold Text the age «11 / месяцев»: a glued phrase wider than its line breaks at its no-break space. Now «Александра» and «11 месяцев» stand whole under the avatar's line, Regular and Bold. Why: glue cannot hold a phrase wider than its line, so the row gives the words room, as a Settings row's icon goes above a title whose first word misses beside it | Settings (`MainTabView.swift:201`) |
| Onboarding setup steps | — (`GeneratingPage`, `Features/Onboarding/Pages/GeneratingPage.swift:39`) | the onboarding page that sets the app up and moves on by itself in 4.65 s (the five steps tick 450 / 1000 / 650 / 1200 / 550 ms apart, the done state 500 ms after the last, the next page 300 ms later); no button, no scroll. One column centred in the page's height, lg 24 a side (272 pt on 320): the progress ring (100 pt; a 6 pt BBPrimary@0.12 track under a BBPrimary→BBAccent trim of the steps done, `easeInOut(0.5)`; the 44 pt `BrandMark` in its middle), xl 32, the title (`title3`, BBTextPrimary, centred), sm 8, the steps card (lg 24 padding, the surface, radius lg, the card shadow): five rows 10 apart, each a 28 pt disc (BBPrimary with a 12 bold BBOnPrimary check when done, else BBPrimary@0.1 with the step's 11 pt glyph at BBPrimary@0.5), 10, the step (15 medium rounded relative to `.body`, BBTextPrimary when done, else BBTextSecondary; 186 pt of room on 320), a row past the one in progress at 0.3; letter-spacing 0, the SF line (17.7 pt at Large). **Proposed** (G39): the step wraps between words (`fixedSize(horizontal: false, vertical: true)`, no line limit). The five rows stand while the column fits the page's height with every step's words whole in its row; else the card's place takes one step, the one in progress (the last after the fifth): 15 medium rounded relative to `.body`, BBTextPrimary, centred at the page's width (272 on 320), sm 8 under the title, wrapping between words with no line limit; no card and no disc, since the ring's trim carries the count. Its box is as tall as the tallest of the five at that width (all five set in one place, the one in progress shown, the others at 0 and hidden from VoiceOver), so the ring and the title stand still from step to step; the next step takes the place by opacity, `easeInOut(0.25)`, with no movement, which Reduce Motion keeps. The fit is `ViewThatFits(in: .vertical)` over the five-row column and the one-step column against the page's own height, the one-step column in `onboardingCenteredScroll` as the net (in landscape it may miss too). VoiceOver reads the title and the step in progress. On 320 pt the one step takes over at AX1 and AX2 in every language, from xxxLarge in ru and from xxLarge in es and in ru with Bold Text, there at the edge (549 pt in 548); on 375 pt from AX1 in es and at AX2 in every language | Onboarding |
| SwipeToDeleteRow | BBCard | custom swipe-to-reveal 76 pt delete action | Events, Growth, RecentActivity, BBHistorySection |
| BBFab | BBFab | 56 pt primary circle, white "+" (BBOnPrimary from 1.3.0, G1), bottom-trailing overlay, md inset; mirrors the toolbar "+". **From 1.3.0** (P7, G32, decided 2026-11-05; in code at 7b886b1): not on Growth, where at rest it sat over the chart's trailing end and its tap layer, the Nutrition card's «?» and, at AX2, the Measurements tile's chevron; Growth's bottom padding is xl 32, as on Events | Feeding, Sleep, Diaper |
| BBHistorySection | BBHistorySection | history header + range picker + empty state + swipe list + locked footer + delete-all | Feeding, Sleep, Diaper |
| BBHistoryFilterPicker | BBCharts | segmented range picker (selected chip primary, white text; BBOnPrimary from 1.3.0, G1); the other words BBTextSecondary on primary@0.08, 4.62 in light from 16f2802 (4.05 with #746D85 before, G10) | BBHistorySection |
| BBWeeklyBarChart | BBCharts | Swift Charts 7-day bars, today full tint, week navigation. The day labels 11 pt rounded in BBTextSecondary, today's bold in BBTextPrimary (G24, from fa5c55f; the tint before); a value 4 pt over every bar up to today, «0» included, 11 semibold rounded, today's in BBTextPrimary and the others' in BBTextSecondary, hidden from VoiceOver, a future day without one; no axis numbers, the grid lines kept at BBTextSecondary@0.06; the bars, under 3:1 in light, stay as marks (G25, from 16f2802; before it only the tallest bar's value, in the tint, with axis numbers). The values and labels stay at a fixed 11 pt; at 320 pt the widest value («24,0», 25.4 pt) has a 36.6 pt slot | Feeding, Sleep, Diaper |
| BBDeleteHistoryButton | BBCharts | destructive "delete all" with a scope-honest confirmation (P4): the platform red words and a 1 pt red@0.2 stroke, no wash (G4, from 16f2802; the red@0.06 wash took the words from 3.25:1 to 3.01:1) | Events, BBHistorySection |
| BBLockedHistoryFooter | BBLockedHistoryFooter | the one calm locked row for history beyond the free window (P2) | Events, RecentActivity, BBHistorySection |
| LockBadge + `bbLockedAccessibility` | LockBadge | the one padlock: 10 pt glyph on a surface disc; VoiceOver value "locked" (P3) | Events, BBQuickActionButton |
| BrandMark | BrandMark | `BBLogo` clipped to a circle, 1 pt ring, optional shadow, on-gradient variant. The ring is BBPrimary@0.25, and white@0.35 on the gradient (`BrandMark.swift:31`): the badge's edge, not a word, a state or a control, so P8's 3:1 for marks does not bind it and it keeps its alpha; on the gradient from 3bb4936 it reads 2.32 → 1.87, more than on the light plate before (2.03 → 1.46) | MainTabView, PremiumHero (on the gradient), Onboarding (Welcome, Generating) |
| BBElapsedTimer | BBElapsedTimer | **an enum from 1.3.0** — the digits every timer card draws and how they read: 36 pt semibold rounded with monospaced digits, relative to `.largeTitle` (42.4 pt line at Large), one line, shrinks to 0.7; ink: BBTextPrimary in both modes (G24, from fa5c55f; the caller's tint before); MM:SS with the minutes running on past 59, or HH:MM:SS from an hour with `showsHours` (the sleep cards: the Sleep screen's and, from 95525c6, Home's). The clock lives in `BBTimerFit` | Feeding and Sleep (through BBTimerCardHeader), Dashboard (through BBTimerFit, 22 pt relative to `.title2`) |
| BBTimerFit | BBElapsedTimer | **from 1.3.0** — a running timer with what is running: one per-second `TimelineView` clock draws both shapes, so each fit check reads the digits on screen. Below AX1 the content stands beside the digits (a `Spacer` between, the given gap on each side) while both fit one line, else above them, sm 8 apart, both leading (`ViewThatFits`); at accessibility sizes always above (§ 3) | Dashboard (`ActiveTimerCard`: title 15 semibold over subtitle 13 regular, 2 apart, md 16 gaps, beside a 48 pt plate; on 320 pt at Large it stacks at any time; the sleep card passes `showsHours`, `DashboardView.swift:187`, and past an hour stacks on en 375 pt and es 375 and 402 pt too), BBTimerCardHeader |
| BBTimerCardHeader | BBElapsedTimer | **from 1.3.0** — the Feeding and Sleep cards' top: a 13 pt medium rounded label in BBTextPrimary (G24, from fa5c55f; the card's colour before) over the title (title3), 4 apart (15.3 and 21.2 pt lines at Large), beside or above the digits as `BBTimerFit` decides | Feeding (`FeedingTimerCard`), Sleep (`SleepTimerCard`, `showsHours`) |
| BBMeasureSlider | BBMeasureSlider | elevated labelled slider with mono value and min/max | Growth, Onboarding GrowthPage |
| BBOptionalMeasureToggle | BBMeasureSlider | toggle that reveals a slider (head circumference) | Growth, BabyProfileEditSheet, Onboarding (Birth, Growth) |
| BBLabeledPicker | BBFieldLabels | **from 1.3.0** — a picker with its label above it at every size (decided 2026-11-04, in code at b8e9a41): the label in the row's text style, then the picker with `labelsHidden()`, sm 8 apart, both leading, at the row's full width. One shape, not a fit: a row that fit by its date would change shape while the parent picks one. VoiceOver reads the label once: the picker keeps its own, and the visible label is hidden from VoiceOver | Diaper (Time), Sleep (Start, End), Growth (measurement date), VisitFields (date), DoseSheet (time), Events (Time). The profile sheet's birth date takes the same two halves without the helper: a caption above, hidden from VoiceOver, and the picker named «Дата рождения» (in code at 427d55e) |
| `bbPlaceholderLabel(design:maxLines:)` | BBFieldLabels | **from 1.3.0** — for a vertical text field whose placeholder is its only label, or is the example of what to type. A placeholder wraps only into lines the field already has, and only in a point-size face, so: 17 regular relative to `.body` (rounded, or default), and 1…`maxLines` lines below AX1, 2…`maxLines` + 1 at accessibility sizes (default 3); nil lets the field grow without a bound | Diaper (note), Events (free-text name), MedicationFormSheet (name, dose, maximum, note; the maximum has a label above, and its es example takes two lines at AX2), QuestionSheet (unbounded) |
| BBSheetHeading + `bbSheetTitle(_:placement:)` + BBSheetTitlePlacement | BBTheme | **from 1.3.0** — a sheet's title (in force, decided 2026-11-04, in code at b8e9a41 and 265557e). With `.barUpToLarge`, the default, it sits in the bar between the glyph buttons up to Large: one line, shrinking rather than cut to 13/17 of its size (13 pt at Large, the sheets' caption size, `BBTheme.swift:370`). Above Large the bar shows no title and `BBSheetHeading`, given the same placement, is the content's first line: title3 (32.8 pt at AX2), textPrimary, leading, wraps, header trait. With `.content` (the dose sheet, whose title is a medication's name) the heading is the content's first line at every size and the bar has none. The modifier and the heading go together: the modifier alone leaves no title where the bar has none, the heading alone shows it twice. The next block follows at the sheet stack's spacing (lg 24). A section label right under the heading keeps its own style (16 semibold): the heading's ratio to it is 18 : 16 at every size, and the label sits 15 pt above its tiles against 34 pt below the heading at AX2 (12.5 and 29.5 pt at xLarge on 375 pt), so it reads with its tiles. A decorative figure above the content (the Growth sheet's 48 pt ruler) is left out at accessibility sizes and is hidden from VoiceOver at every size. The ru profile title is «Профиль» (75.5 pt, decided 2026-11-04); until it ships «Редактировать профиль» (202.4) shrinks to about 14.4 pt at Large on 320 pt, whole | Add Event, Feeding, Growth, Sleep, Diaper, QuestionSheet, DoseSheet (`.content`), MedicationFormSheet, VisitSheet, VisitDetailSheet, BabyProfileEditSheet. The diaper norm editor does the same by hand: the system inline title up to Large, none above it, and «Норма в день» (`DiaperView.swift:304`) as the header above Large |
| `bbSelectedBorder(_:shape:)` + BBSelectionShape | BBTheme | **from 1.3.0** (decided 2026-11-04, in code at 1187418, `BBTheme.swift:327`; § 3, G29) — a selected tile's or chip's border, drawn outside its fill: a 1.5 pt `strokeBorder` in BBPrimary, clear when not selected so the tree is the same in both states, on the tile's shape padded −1.5, its inner edge on the fill's edge; `.tile` a rounded rectangle of Radius.md + 1.5 = 17.5, `.capsule` a capsule. Laid after `cornerRadius(Radius.md)` and `bbShadow`, so the shadow keeps the fill's outline. It takes no layout, so a word's room is its tile's (§ 3); the ring reaches 1.5 pt into the gap (sm 8 → 6.5, md 16 → 14.5), and VoiceOver's frame grows by it | Feeding (type tiles, breast-side chips, the timer's side pills as `.capsule`), Sleep (type, location), Diaper (type), Add Event (type, mood), the profile sheet (gender, feeding), onboarding (gender, feeding rows). Not on: Export's format tiles (their own outline, G29), the plan rows, the stool swatches' 2.5 pt ring, the medication interval chips, the retry capsule |
| BBScreenHeading + `bbScreenTitle(_:)` + BBScreenTitleFit | BBScreenTitle | **from 1.3.0** (§ 3, G31) — a screen's large title (in force, decided 2026-11-05; in code at 7b886b1). It stays in the bar while it fits the bar's one line: largeTitle bold against the bar's room, W − 32 pt below 414 pt of width and W − 40 from 414 (288 on 320, 370 on 402, 400 on 440), measured at the font's own width, which is 3 % wider than the bar draws it, so a title leaves the bar a size early rather than late. Where it misses, at that width and size, the bar goes inline and `BBScreenHeading` is the first child of the screen's content stack: largeTitle bold (SF Pro, the bar's large-title face) at the current size, 34 / 36 / 38 / 40 / 44 / 48 pt from Large to AX2 (lines 40.0 / 42.4 / 44.8 / 47.1 / 51.8 / 56.5), the font's own tracking, no added line spacing, BBTextPrimary, leading, wrapping between words with no line limit, header trait. Where its widest word misses the heading's width with sm 8 to spare it steps to title1 bold, then title2 bold (today es «Medicamentos» on 320 pt only: 38 pt at AX1, 39 at AX2, 260.1 pt in 280). It stands in the content column (x md 16, width W − 32, inside the screen's iPad column where it has one), sm 8 below the bar where the stack starts at the bar, at the stack's own md 16 where it has one (the report, Export); the next block follows at the stack's spacing (lg 24; md 16 on the report and Recent activity), as the sheets' heading does. Once its last line has passed under the bar, the bar's principal item shows the title: 17 pt semibold at every size, the system inline title's size, one line, shrinking to 13 pt, then cut at the tail, revealed with § 8's `easeInOut(0.25)` and at once with Reduce Motion. While hidden it stays in the layout at opacity 0 and hidden from VoiceOver, because an empty principal item let the system draw its own title, cut. `navigationTitle` stays set, so the next screen's back button and VoiceOver keep the name. A List screen puts the heading in its first section's header, `.textCase(nil)` | the report, Recent activity, Export and Medications (whose titles miss today), Feeding, Sleep, Diapers, Events, Growth; More and Profile (List; ≤ 207.0 pt at AX2) once a title would miss |
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

- **Widget** (`Features/Widget/WidgetViews.swift`): the brand gradient
  #5D4893 → #7B68B6 in both modes, every word and glyph white at full
  strength, 4.67:1 or more (G12, in code at 3bb4936; white at 0.7–1.0 on a
  lighter gradient before, 2.37–4.62), raw rounded sizes 10–32 pt
  (widgets do not take Dynamic Type the same way; fixed sizes are expected
  here). Since 1.1.0 it has tap areas and a start-feeding control:
  `m1-live-activity.md` § 5.
- **Live Activity** (in force since 1.1.0, `Features/LiveActivity/`): Lock
  Screen on BBSurface, Dynamic Island on its black — spec in `m1-live-activity.md`.
- **Splash** (`Features/Splash/SplashView.swift`): BBLaunchBackground, then
  `BBSplashBg` art (design PNG with its text band stitched out), wordmark and
  tagline in BBSplashText #4A357E at full strength (G17, in code at 3bb4936;
  #F7F1E4 at 1.1–1.5 over the art before). Wherever the stack at 0.82 of the
  height would touch the art's figure (landscape on the phones and the full
  iPads, Split View at 2/3), the figure and the words stand side by side, the
  art's inner sides faded into BBLaunchBackground (G28, in code at d3e94e8,
  `SplashLayout`); every portrait window keeps the stack under the figure.
  The art and the tagline's two leaves are hidden from VoiceOver (from
  1.3.0, in code at 8c4bdae, `SplashView.swift:56`, `:71`, `:77`): the
  splash reads as its two texts, the wordmark and the tagline, with their
  frames and traits as before (5 accessibility elements before, 2 after, in
  every window). Why: they carry no information, and a picture that says
  nothing is not read out (WCAG 2.2, 1.1.1).
  Launch screen is colour-only. Art: `docs/design/splash*.png`.
- **App icon**: `docs/design/icon*.png`, brief `docs/design/icon-design-brief.md`.
- **PDF / HTML export**: § 2 "Outside `Colors/`".
- **The Export PDF** (from 1.3.0, G33, in code at 361abe5;
  `ExportGenerator.swift`, `ExportView.swift`): its first page says «All
  entries» («Все записи», «Todos los registros») under its title, and its
  file is «All entries – Mia – 2026-11-06.pdf», the baby's name as typed, as
  the doctor's file has it. Every exported file name, both PDFs and the
  CSVs, stays within 255 bytes of UTF-8 and only the name gives way, a whole
  character at a time, so the date and «.pdf» always stay (a 60-character
  name: 95 to 180 bytes, each ending « – 2026-11-06.pdf»); a name keeps the
  joiners and tags inside an emoji, and bidi overrides stay out. The
  feeds-a-day tile shows the bare figure («7»): its label says «a day». The
  count tiles read the plural stat words (`stat.feedings`,
  `stat.sleep_episodes`, `stat.diapers`, `stat.measurements`): «45 Feedings
  · 13 Sleep episodes · 45 Diapers · 10 Measurements», ru «45 Кормления · 13
  Эпизоды сна · 45 Подгузники · 10 Измерения», es «45 Tomas · 13 Episodios
  de sueño · 45 Pañales · 10 Medidas»; the tables keep the category's name
  as their heading («Feeding», «Кормление», «Alimentación»; from 1.3.0, in
  code at 0a925bf, `ExportGenerator.swift:289–310`, headings `:319–379`).
  Why: a count reads with its plural («45 Кормления», never «45 Кормление»),
  a heading names its category.
- **The report PDF's weight for age** (from 1.3.0, G34, in code at 80d2e54;
  `DoctorReportPDF.swift:93–137`, `Core/DoctorReport/WeightForAgeChart.swift`,
  `Core/Growth/WeightChartWindow.swift`): the report's last section, after
  the questions and before its closing line, kept whole on one page of A4
  (595.2 × 841.8, margins 36, the body to 781.8). The report's heading
  «Weight for age» (13 px, weight 600, #6F5BA8, Helvetica Neue) with « · WHO
  percentiles» on its line in 10 px #6B647C, then the chart, 523.2 × 111.5 pt
  (612 CSS px, the printable width); the block with its heading is 145.6 pt
  (149.0 estimated before the build). doctorMonth goes from 1 page to 2,
  page 1 losing only its closing line.
  - Geometry, in the chart's own points: the plot x 28–501 (page x 64–537),
    y 6–96; labels 10 px (8.55 pt) Helvetica Neue in #6B647C, x labels' top
    at y 100; ticks 3 pt of 0.5 pt #6B647C; a label stands 4 pt from its
    tick, line or neighbour.
  - y: gridlines 0.5 pt #E5E5EA at whole kilograms, from the floor of the
    lowest of P3 and the child's weights to the ceiling of the highest of
    P97 and them (the top + 1 where the two meet); a step of 1 kg up to a
    6 kg range, else 2, an odd range at step 2 taking its top + 1, so both
    ends carry a label; labelled «N kg» (a no-break space), right-aligned
    4 pt left of the plot and centred on their line.
  - x: the window the Growth screen's chart takes for the same weighings,
    one source for both (`WeightChartWindow`); a tick at its start and at
    each month mark of age at least 15 % of the span from it (a four-week
    window shows its start alone, «Nov 4» / «4 нояб.» / «4 nov»). Past six
    marks they are thinned by halves, every second one going, until six or
    fewer remain (a two-year history shows months 4, 8, 12, 16, 20). Each
    tick carries its label, the report's short date, centred and kept
    inside x 24–505 (page x 60–541): the start's label always shows, and a
    later one that would not stand 4 pt clear of the one before goes with
    its tick, never a tick without its date (doctorMonth «Sep 5 Oct 5 Nov
    5»). The screen's own chart is unchanged: it drops a label within 18 %
    of its right edge (`GrowthView.swift:734`).
  - Lines: P3 and P97 dashed 0.75 pt (3 on, 2 off), P50 solid 1 pt, all
    #6B647C, from `WHOCorridor` for the baby's sex, each numbered «3», «50»,
    «97» 4 pt past its end (page x 541); the child's weights a 1.5 pt
    #6F5BA8 line with a 2.5 pt-radius dot at each, drawn over it, the points
    the screen draws. Lines, not a band: a black-and-white print keeps them.
    Every label is text in Helvetica Neue in the text layer.
  - Shown only where the report's weight percentile shows a figure and the
    window holds two weighings at different instants or more; two at the
    same instant count as one, so no chart. Known limit: near two years the
    window can run past the WHO tables' last day (730); there the centile
    lines stop inside the plot, each number at its line's end. The child's
    points never pass 730, since the chart needs a percentile figure.

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
Large, where G21 was found (2026-11-03). G21's ways were measured at 4259dd0
on 2026-11-04, from the bars' frames and CoreText widths, and its direction
was decided the same day. G2 was read at 4259dd0 and 54af23c for the tracker
screens, Home and onboarding, with their renders at Large, xxxLarge and AX2
(2026-11-04). G21 was read at 265557e and the sheets' titles and labels at
b8e9a41, with their renders at the default size, xLarge and xxxLarge, in
light and dark and in the 320 pt dumps, and Home at 95525c6; G22 was found
there (2026-11-04). G23 was found at a8369f8 and read at 6fc67d1 on every
tint site of the Growth tab and Home's growth card, and G24 was found there
and read at 6fc67d1 on every category-tint site, where G25 was found
(2026-11-04). G10, G25 and every word drawn in a tint, BBPrimary, a red or
an orange were read at 4f3c86c, where G26 was found, and G12, G17 and every
state mark at 8d3d2ba, with the splash art under its words, where G27 and
G28 were found (2026-11-04). G2, G21 and G22 were read at e8abca8, 4f3c86c,
b57b678 and 1590974 with their renders and 320 pt dumps (2026-11-04). The
selected tiles' borders were read at 3b9dd3d, where G29 was measured
(2026-11-04). G17 and G28 were measured again at 32fefea, with the splash
art's pixels read where they lie, in portrait, in landscape and in Split
View (2026-11-04). The title + value rows and the Export format tiles were
measured at 8b90029 from CoreText widths, the live Settings tree and shots on
402 pt and a 320 pt dump, where G30 was found (2026-11-04). The Feeding
sheet's bar confirm, the weekly card's rows, legend and hidden line, the
Settings switch labels and the percentile card were read at 3b9dd3d to
7070300 with their renders, trees and 320 pt dumps (2026-11-05). G4, G5,
G10 and G23 to G26 were read at 855227f, 170d574, fa5c55f and 16f2802 with
their renders in light and dark and the week chart's 320 pt shots
(2026-11-05). The screens' large titles were measured at 3bb4936 from
CoreText widths against the bar's room and a shot of the report at AX2 on
402 pt, and Growth's floating + from the app's tree and shots on 440 pt at
Large and AX2, where G31 and G32 were found (2026-11-05). The two PDFs'
words and file names, the report PDF's pages and the report screen's
weighings were read at eb1f410 from the code, the rendered PDFs of 8eea793,
the shots of bb17b39 and CoreText widths, where G33 to G35 were found
(2026-11-05). The builds of G12, G17 and G27 (3bb4936), G22's stepper card
(eb1f410), the selected border (1187418) and G28 (d3e94e8) were read at
their hashes against their directions, with their renders on 320, 375 and
402 pt and the iPads, the splash's frames from the app's tree and the
contrasts computed from the colorsets (2026-11-05). The title + value rows,
the weekly card's week change, the stat tile's duration, the event row and
the Nutrition card's rows were read at c090a8e, 3e4044a, 19a14f1 and 42a74fe
with their renders, 320 pt dumps, live 320 pt shots and trees and CoreText
widths (2026-11-06). The builds of G31 and G32 (7b886b1), the splash's
silent art (8c4bdae), G33 (361abe5, 0a925bf), G34 and G35 (80d2e54) and
G30's last rows, Home's growth rows, Growth's history rows, the Settings
switch rows and the section header (a298c62), were read at their hashes
against their directions, with their renders, trees, rendered PDFs and live
320 pt shots before and after (2026-11-06). The age glue and Settings' baby
row (92c70db), Home's sleep line (c67ab7c) and the charts' VoiceOver words
(ed4a561, dc529cc; nothing drawn changes) were read at their hashes, with
their renders before and after and CoreText widths (2026-11-06). The primary
button and the onboarding setup page were read at a070713 in its 320 pt
renders at Large and AX2, with CoreText widths, where G38 and G39 were found
(2026-11-06). Each line: what, where, which rule.
Under P8, existing contrast violations are backlog items, not blockers; G2 is
in the backlog (2026-10-28) and fixed for 1.3.0 on the entry sheets, the stat
card, the profile sheet, the tile rows, the tracker screens' timer cards,
Home's quick actions and the weight gain card, G22 is fixed for its reach,
and G1, G4, G5, G10, G18, G19, G20, G21, G23 to G26 and G30 to G36 are fixed
for 1.3.0; G37 to G39 are proposed.

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
  1.66:1 in dark; fixed for 1.3.0** (`PlanPickerSection.swift:185`, 11 pt
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
  label 12 pt (scaled from 1.3.0, § 7). grep: `grep -rno --include=*.swift '\.system(size:' BabyBloom | grep -v WidgetViews | wc -l`
  → 158 at 337fff5, 140 at c813d99, 129 at 6f66d45, 123 at 4259dd0, 120 at
  54af23c and at 95525c6, 117 at e8abca8 and at 1590974.
  Fixed for 1.3.0 on the entry sheets, `BBStatCard`, the profile sheet and the
  Diaper and Sleep screens' quick and start tiles (decided 2026-11-03, in code
  at c813d99, 427d55e and 6f66d45), and on the Feeding, Sleep and Diaper
  screens' remaining words, Home's quick actions and timer subtitle and
  onboarding's gender row (decided 2026-11-04, in code at 4259dd0 and
  54af23c), and on the weight gain card's interval, verdict word and reference
  (in code at e8abca8): their words and the glyphs that stand with them scale, and the
  grids and tile rows take the counts of § 3 at every text size. The rest of
  the app's fixed words follow the same rule, screen by screen: among them the
  Growth insight cards and screen (GrowthInsightCards 17 at e8abca8, GrowthView 8), the
  charts, the Home cards' 13 pt words (`BBProgressCard`'s figure and glyph,
  in code at 1fb7ece, G36; the growth hint, `GrowthInsightCards.swift:458`;
  `LockedInsightCard`, `:785`, `:790`), the weekly card, the paywall and
  onboarding's other pages. Onboarding's feeding rows also miss the column
  room at accessibility sizes on 320 pt (§ 3).

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
    colour: 5.12 in light (4.48 before 16f2802) and 6.82 in dark against the
    sheet, over P8's 3:1
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
- **G21 · Sheet titles at Large on 320 pt were cut; fixed for 1.3.0**
  (`bbSheetTitle`, `BBTheme.swift:334`). In ru the bar slot between «Отмена»
  (85 pt) and «Сохранить» (114 pt) was 49 pt there, so with the 0.6 floor
  every ru entry-sheet title was cut, «Подгузник» (89.2) among them, and es
  titles from 116 pt on («Agregar sueño»); en held. It broke the helper's own
  promise of a whole title. Measured at 6f66d45 from the bar's frames on
  402 pt and CoreText widths. Fix, decided 2026-11-04 for 1.3.0, in code at
  265557e (§ 3): glyph buttons in every sheet bar (`BBBarButton`, § 7) leave
  the title 174 pt on 320 (229 on 375, 256 on 402) in every language, and all
  48 titles are whole at 17 pt, as the 320 pt dumps show in en, ru and es;
  titles of at most 166 pt, with a 13 pt floor; the dose sheet's name, which
  no budget holds, in its content at every size. grep: `grep -rn
  --include=*.swift 'BBBarButton(' BabyBloom` → 28 lines at 265557e, one per
  bar button. A pushed screen's Edit, the medication screen's
  (`MedicationDetailView.swift:72`), is the pencil too (in code at b57b678,
  § 3): 29 lines at 1590974.
- **G22 · The diaper norm editor did not scroll, and on 320 pt its stepper
  card was wider than the column; its reach is fixed for 1.3.0**
  (at 8d3d2ba: `DiaperView.swift:294`, a `VStack` with a
  `Spacer` and no `ScrollView`; the stepper at `:314`). Height: at Large on
  the live SE run (375 × 667) Save ends 128.0 pt above the screen's bottom, so
  a 320 × 568 pt screen (the SE with Display Zoom) keeps 29 pt; above Large the
  title, hint and digits grow (on 320, ru and es +31 pt at xxxLarge, +53 at
  AX1, +105 at AX2; en +48, +70, +93), so the content no longer fits from
  about xxxLarge (−2) and clearly at AX1 (−24) and AX2 (−47 to −76). With no
  scroll the stack then overflows at both ends: the drop runs under the bar
  and Save is cut. On 375 × 667 and 320 × 693 it fits at every size. Width:
  two 52 pt symbol frames, xl 32 between each and the digits, the digits' 80 pt
  minimum and xl 32 inside the card make 312 pt, so in the 256 pt that the
  card's xl margins leave on 320 the card sits 4 pt from the screen's edges,
  against the Save button's 32. Computed from the live 402 and SE runs and
  CoreText, not rendered: there is no 320 pt simulator, and the 320 pt dump's
  420 pt window overflows already at Large. Breaks § 3 (every control
  reachable at every size on 320 pt) and § 4 (one inset per column). Not
  from 1.3.0's builds: the layout is as before. Fix decided 2026-11-04, in
  code at 1590974: the content in a `ScrollView` (`DiaperView.swift:301`)
  with `.scrollBounceBehavior(.basedOnSize)` (`:337`), as the onboarding pages
  (`OnboardingHelpers.swift:67`), so where it fits nothing moves or bounces;
  md 16 under Save, as the Growth sheet's padding; the stepper card in its xl
  form where that fits, else md 16 for its four gaps (`:325`), at most 256 pt
  on 320. Save is reached by scroll at xxxLarge and AX2 on 320 × 568, and en
  at Large fits without one; the hint wraps whole. The md form reaches 375 pt
  at Large too: the xl card is 312 pt and the column 311, so the card drops
  to 248 pt, 63.5 pt from the screen's edges against Save's 32 (on 402 pt
  312, 45 from them), and on 320 at Large its edges stand 4 pt inside Save's.
  Computed from the simulator's metrics; 375 not rendered. Decided
  2026-11-04, in code at eb1f410 (`DiaperView.swift:326`, a `ViewThatFits`
  of the xl form and a filling form): where the xl form misses, the card
  takes the column's width and its four gaps share the room, md 16 at
  least, the digits shrinking below that as built. The xl form is 312 pt
  with a one-digit norm and 313.3 with «12» (81.3 pt at 64 pt semibold
  rounded, over the digits' 80 pt minimum): on 375 at Large the card is the
  column's 311 pt (gaps 31.4; 31.75 with one digit), on 320 its 256 (gaps
  17.7; 18), its edges on Save's in both, as the build's shots show; 402
  unchanged. Why: the card
  changes by the room it lacks, not by 64 pt for 1.
- **G23 · Tier tints as text ink on the Growth cards and Home's growth card**
  (found 2026-11-04 at a8369f8; every site read at 6fc67d1). The tier tints
  are BBSuccess ("within", a typical percentile), BBAccent ("below", an edge
  percentile) and BBAlert (a percentile tail). As ink on the light surface
  they are 1.98, 1.84 and 3.64 (dark 9.47, 9.82 and 5.53, all pass). Seven
  sites draw words or figures in them (kind, type, ink, the ratio it needs):
  - the percentile card's band label («50–85»): label, metric 28 pt
    semibold, the tier tint, 3 (`PercentileCard.swift:72`);
  - the percentile card's ring number: small text, 16 pt semibold, the tier
    tint, 4.5 (`PercentileCard.swift:85`);
  - the newborn card's regained figure («102% от веса при рождении»):
    figure, metric, BBSuccess, 3 (`GrowthInsightCards.swift:517`; `:543` at
    7070300);
  - the weight gain card's figure («+180 г/нед»): figure, metric, BBSuccess
    or BBAccent, 3 (`GrowthInsightCards.swift:582`, tints at `:677`);
  - the weight gain card's band word: label, 14 pt semibold at a fixed size
    (G2), BBSuccess or BBAccent, 4.5 (`GrowthInsightCards.swift:593`);
  - the Nutrition card's three status values (gain, feeds, wet diapers):
    small text, 13 pt semibold, BBSuccess or BBAccent, 4.5
    (`NutritionSection.swift:155`, tints at `:176`);
  - Home's growth card's gain value: small text, 13 pt semibold, BBSuccess or
    BBAccent, 4.5 (`DashboardView.swift:446`, tints at `:405`).
  "Above the reference" and a gain figure without a band are BBTextPrimary,
  and "not enough data" and "first weeks" BBTextSecondary (4.92 / 6.11):
  those pass. Onboarding's growth page renders the percentile card itself
  (`GrowthShowcasePage.swift:102`, a tail there in BBTextPrimary). Breaks P8.
  The percentile card, decided 2026-11-04, in force (in code at e3d45e2: the
  figure `PercentileCard.swift:72`, one element `:75`, the ring `:80–89`;
  the band label and the ring number are gone): the band label goes; the
  big figure is the percentile itself, the card's badge («61», «> 97», «< 3»,
  36.1 to 60.1 pt in the 168 pt beside the ring on 320), in BBTextPrimary
  (14.28 / 14.05) under its caption `percentile.weight`; the ring keeps the
  tint as the picture of where the reading sits, without its number, hidden
  from VoiceOver, so the reading is stated once; the caption and the figure
  are one VoiceOver element. A graphic whose meaning the text beside it
  states needs no 3:1 (WCAG 1.4.11). Onboarding's page follows, as the same
  card.
  Direction for the other five sites (decided 2026-11-04, in force; in code
  at 855227f, the dot through `BBTierValue`, § 7): **a
  tier tint is a mark, never text ink** (§ 2, after the tint usage pattern),
  one look in light and dark:
  - figures: BBTextPrimary in every tier (14.28 / 14.05), as the percentile
    figure; the tint stays on the mark beside them: the newborn card's
    BBSuccess tick, and the gain card's tier dot on its band word;
  - labels (the gain card's band word): BBTextPrimary, led by the tier dot;
  - small text (the Nutrition card's status values, Home's gain value):
    BBTextPrimary, led by the tier dot; "above" with no dot; "not enough
    data" and "first weeks" BBTextSecondary, with no dot.
  The words say the verdict, so no colour is one (P1), and none of these
  sites uses BBAlert. The dot adds 12.1 pt. At Large it adds a line in 5 of
  108 measured cases (a row at 320, 375 or 402 pt in en, ru or es), none on
  320: ru feeds on 402, es gain on 402, es feeds on 375 and 402, es Home gain
  on 375 (CoreText at 6fc67d1, the row's label at its own width). Not taken:
  ink tokens of the same hues for light (#357D5E and #94654E reach 4.5 on both
  light fills, #549B7A and #B4836B reach 3; dark keeps the tints): two
  colorsets whose forest green and brown the palette does not have, and that
  make the verdict word the loudest line of its card beside a percentile
  figure already neutral. No mark at all: no tier cue is left on the cards
  that have no ring or tick.
- **G24 · Category tints as text ink on the timer cards, the week chart and
  the bottle volume** (found 2026-11-04 at 6fc67d1, in G23's audit, and read
  there on every category-tint site). Six sites draw words or figures in
  BBFeeding, BBSleep or BBDiaper (kind, type, the ratio it needs):
  - the Feeding and Sleep timer cards' label («Кормление», «Ребёнок спит»):
    label, 13 pt medium, 4.5 (`BBElapsedTimer.swift:94`);
  - their digits: figure, 36 pt semibold, 3 (`BBElapsedTimer.face`, `:14`);
  - Home's running-timer card's digits: figure, 22 pt semibold, 3, and 4.5
    once they shrink under 18.7 pt (to 15.4 at 0.7; `DashboardView.swift:648`);
  - the week chart's tallest-bar value: small text, 11 pt semibold, 4.5
    (`BBCharts.swift:232`);
  - the week chart's today's day: small text, 11 pt bold, 4.5
    (`BBCharts.swift:261`);
  - the bottle volume on the feeding entry sheet: figure, 20 pt semibold, 3
    (`FeedingView.swift:522`).
  On the timer cards' tint@0.08 wash they are 1.80 (feeding) and 1.82 (sleep)
  in light, and on the surface 2.08, 2.09 and 1.61 (diapers); in dark 5.51 to
  7.25, all pass. Breaks P8. Not from 1.3.0's builds. The Live Activity's
  digits (`TimerActivityViews.swift:156`, `:248`) and `BBMeasureSlider`'s
  value (`BBMeasureSlider.swift:23`) are BBTextPrimary already.
  Direction (decided 2026-11-04, in force; in code at fa5c55f, the chart's
  values with G25 at 16f2802): G23's rule, **a tint is a
  mark, never text ink**, one look in light and dark:
  - figures (the timer digits, the bottle volume): BBTextPrimary, 12.41 /
    12.42 on the timer cards and 14.28 on the surface (dark 14.03 to 14.09),
    which also passes 4.5 for Home's shrunk digits;
  - the timer label: BBTextPrimary, apart from the title by size and weight;
    BBTextSecondary was 4.28 on the wash when this was decided (4.83 with
    G10's value);
  - the week chart's value and today's day: BBTextPrimary (14.28 / 14.05);
    today keeps its bold and its full-strength bar. The chart's values follow
    G25 (decided 2026-11-04): every bar's, today's in BBTextPrimary.
  The tint stays on the marks each site already has: the timer card's wash
  and 1.5 pt stroke, Home's glyph disc, the bars, the slider's track. Nothing
  is added, no width changes, and the shapes at every size are today's. Not
  taken: one ink colorset per category for light at 4.5 (feeding #9B596D,
  sleep #64699D, diapers #8D733B; at 3 for the big digits alone #BB768A and
  #8086BC), dark keeping the tints: a plum, a slate blue and an ochre the
  palette does not have, two values per hue to keep in step, and an in-app
  timer unlike the Lock Screen's. The chart's value in BBTextSecondary (4.92)
  passes but reads as an axis number.
- **G25 · The week chart's bars are under 3:1** (found 2026-11-04 at 6fc67d1,
  in G24's audit). `BBWeeklyBarChart` (`BBCharts.swift:152–163`, `:226`)
  fills today's bar with the tint fading to 0.35 and the other days with 0.5
  fading to 0.175, on the surface. At their top in light: today 2.08 / 2.09 /
  1.61 (feeding / sleep / diapers), the other days 1.42 / 1.41 / 1.26; in
  dark today 5.95 / 5.51 / 7.25 and the other days 2.51 / 2.40 / 2.85. A bar
  is a graphical object the chart needs (WCAG 1.4.11, 3:1); the axis numbers
  (4.92 / 6.11) and the tallest bar's value give the figures, and the grid
  lines are textSecondary@0.06. Breaks P8. The bars also fade to 0.35 (today)
  and 0.175 at their foot: 1.27 and 1.13 in light, 1.88 and 1.34 in dark
  (feeding; read at 4f3c86c).
  Direction (decided 2026-11-04, in force; in code at 16f2802,
  `BBCharts.swift:226–237`): every day up to today states
  its value 4 pt above its bar, «0» included, 11 pt semibold rounded as now:
  today's in BBTextPrimary (14.28 / 14.05), the other days' in
  BBTextSecondary (5.62 with G10's value, 6.11 in dark), hidden from
  VoiceOver, since each bar already speaks its day and value. The leading
  axis numbers go and the grid lines stay: seven values beside a column of
  0 / 5 / 10 would read as two scales. The bars stay as they are: every
  figure is stated beside its bar, so a bar is a mark and needs no 3:1 (WCAG
  1.4.11), as G23's ring. Today stays apart by its full-strength bar, its
  bold day label and its value's ink. The widest value, «23,9» hours (25.3
  pt; counts at most 14.6), leaves 11.3 pt to the next on 320 pt, where a
  day's slot is 36.6 (CoreText; the font is fixed, G2); the 320 pt shot at
  16f2802 reads «24,0» at 25.4 pt, at least 11.2 pt from the next, in en and
  ru, light and dark. Not taken: a 1 pt
  edge inside each bar in a deeper shade for light (#C68094, #8B91C8,
  #AB9158: 3.04, 3.01, 3.03; the tints in dark), three colours the palette
  does not have, with the other days' values still unread; solid bars in
  BBPrimary and BBTextSecondary (5.62 each), the same lightness, so today
  would differ by hue alone and the category colour would leave the chart.
- **G26 · BBPrimary words on a primary wash over the background are under
  4.5:1 in light** (found 2026-11-04 at 4f3c86c, in the rule transfer of
  G23 and G24). BBPrimary as text is 5.12 on the background, 5.62 on the
  surface and 4.62 on primary@0.08 over the background; on primary@0.12
  over the background it is 4.38, and on @0.10 4.50 (4.499):
  - the selected tiles' words (primary@0.12): `SleepView.swift:290`, `:322`;
    `FeedingView.swift:406`, `:435`; `DiaperView.swift:421`;
    `EventsView.swift:334`, `:370`; `BabyProfileEditSheet.swift:262`,
    `:286`; onboarding's `BirthPage.swift:103` and `FeedingPage.swift:51`.
    Over the Feeding timer card's wash the breast sides
    (`FeedingView.swift:318`) read 4.18, and over an onboarding blob 3.61;
  - the pills at @0.10: Home's age pill (`DashboardView.swift:138`), the
    diaper norm chip (`DiaperView.swift:213`), the medication interval
    chips (`MedicationFormSheet.swift:205`) and onboarding's fact chip
    (`FactPage.swift:34`; 3.70 over a blob).
  Dark passes (5.71, 5.92). Breaks P8. Passing, so not on the list: the same
  washes over the surface (4.78 at 0.12: the Growth card's add-weighing
  button and corrected-age pill; 4.91 at 0.10: `BBSecondaryButton`), the
  trend capsule on success@0.12 over a stat card (4.58 to 4.66), and the
  compact date pills (4.87, computed from the system fill). Direction
  (decided 2026-11-04, in force; in code at 16f2802): the wash is laid over BBSurface, 4.78
  / 5.04 at 0.12 and 4.91 / 5.22 at 0.10, whatever is under it; a selected
  tile is a shade lighter (#E6E1F1 → #EEEBF5 in light) and its 1.5 pt
  BBPrimary edge carries the choice; the words keep BBPrimary, the ink of a
  control. Not taken: the words in BBTextPrimary, which leaves the choice to
  the wash and the edge and takes the control ink off the chips; the washes
  at 0.08, which over a wash or a blob stay under 4.5.
- **G27 · The Export screen's unchecked marks are under 3:1** (found
  2026-11-04 at 8d3d2ba). The unselected date range's circle
  (`ExportView.swift:140–142`, 20 pt, a 1.5 pt stroke at textSecondary@0.3)
  and an unchecked category's square (`:178–180`, `square` at 20 pt,
  textSecondary@0.4) read 1.48 and 1.71 on the section card in light, 1.72
  and 2.10 in dark. A mark that shows a state needs 3:1 (WCAG 1.4.11), and
  the row's words name the range or the category, not whether it is in the
  export. Breaks P8. The checked marks are BBPrimary (5.62 / 6.15). Passing:
  the visit sheet's and the plan picker's circles (`VisitSheet.swift:98–100`,
  `PlanPickerSection.swift:154–156`) in BBTextSecondary (4.92 / 6.11 on the
  surface) and the onboarding generating page's done steps (a filled
  BBPrimary disc). Inactive, so exempt: an empty category's row at 0.4
  (`.disabled`), the week chart's forward chevron at @0.3 when it cannot go
  on, the Export button at 0.5. Not a state, so not on the list: the row
  chevrons at textSecondary@0.4 / @0.5 (1.73–2.64 on the surfaces; none
  lies on the brand gradient), the format tile's textSecondary@0.15
  edge (the selected tile's 2 pt BBPrimary edge and wash carry the choice),
  the tiles' tint strokes, the charts' grid lines. Direction (decided
  2026-11-04, in code at 3bb4936, `ExportView.swift:141`, `:180`): an
  unchecked or unselected mark is
  BBTextSecondary at full strength and a checked one BBPrimary, as the visit
  sheet and the plan picker already draw theirs: the circle and the square
  read 5.62 in light with #6B647C (G10) and 6.11 in dark; shapes and sizes
  stay. Why: the mark is the row's only sign of its state. Not taken: textSecondary@0.70, the least alpha at 3:1 (3.00 / 3.72),
  a second grey for marks that renders just under 3.
- **G28 · The splash words lie over the art's subject in landscape** (found
  2026-11-04 at 8d3d2ba, measured again at 32fefea). `SplashView.swift:56`
  centres the words at 0.82 of the screen's height over `BBSplashBg`, a
  portrait art (941 × 1362) drawn `scaledToFill`. In portrait that is the
  field under the crescent; in a window wider than the art's 0.69 the crop
  keeps the art's middle. On iPhone and on the full iPad in landscape the
  wordmark and the tagline then lie on the crescent and the baby's face, every
  word's box on the figure (1.00 then; with G17's new ink 2.05–8.38 for
  the wordmark and 3.20–8.64 for the tagline at worst). In Split View at 2/3
  they lie on the crescent's shadow (the wordmark 3.05–3.57). Not a contrast
  fix: the words need a place of their own. Direction (decided 2026-11-04,
  in code at d3e94e8: `SplashLayout`, `SplashView.swift:126`): where the
  0.82 stack would touch the figure (the crescent, the
  baby, the sprout and the crescent's shadow: x 0.2317–0.8257, y
  0.2658–0.7269 of the art), the figure and the words sit side by side. The
  art keeps today's fill scale where it can and is drawn smaller where it
  must, so that the figure fits the safe height with lg above and below, and
  the figure, xl 32 and the stack fit the safe width with lg at both ends.
  The group is centred in the safe area, the figure leading, and a side of
  the art inside the window fades from the figure's edge into
  BBLaunchBackground on a smoothstep (the art's edge in view is within 1.03
  of it). Every word clears the figure, 5.72 / 5.74 at worst. Nothing changes
  where the stack already lies clear of the figure: every portrait window (11
  pt at the least, on the 320 class) and Split View at 1/2 and 1/3. Why: it
  is the one layout with the art as it is that gives the words a place of
  their own in every window, and on phones it shows the whole figure, which
  the crop cuts today. Not taken: the art moved up with the words under the
  figure (the figure alone is taller than the safe height less the words on
  phones and on the full iPads); beside at today's crop (135–140 pt beside
  the figure for a 220–262 pt stack); a field behind the words (a panel over
  the baby's face); a landscape crop of the art (a new brand image, not
  needed). As built, the stack's width is the words' layout box
  (`SplashView.swift:82`), a little wider than their ink: on the 320 class in
  landscape the scale is 0.407 against 0.405 from CoreText's advances, the
  box ends lg 24 from the trailing safe edge and the ink 24.7–25.0; every
  word clears the figure by xl 32 or more, and right-to-left mirrors the
  group.
- **G29 · A selected tile's border took its word's room** (found 2026-11-04
  at 4259dd0, measured at 3b9dd3d). Twelve selected marks draw
  `strokeBorder(BBPrimary, lineWidth: 1.5)` inside the tile:
  `FeedingView.swift:325` (the timer's side pills), `:414`, `:442`;
  `SleepView.swift:297`, `:329`; `DiaperView.swift:447`;
  `EventsView.swift:341`, `:377`; `BabyProfileEditSheet.swift:269`, `:293`;
  `Onboarding/Pages/BirthPage.swift:111`, `FeedingPage.swift:64`. Ten have no
  side padding, so the border lay 1.5 pt a side inside the word's room, and
  with Bold Text on 320 pt over the word's box at three (§ 3). Breaks § 3
  (the column is the word's own room). Direction (decided 2026-11-04,
  in code at 1187418): drawn outside the fill (§ 3, § 7
  `bbSelectedBorder`) at the twelve sites, at that hash
  `FeedingView.swift:322`, `:409`, `:434`; `SleepView.swift:295`, `:324`;
  `DiaperView.swift:479`; `EventsView.swift:340`, `:373`;
  `BabyProfileEditSheet.swift:268`, `:289`; `BirthPage.swift:110`,
  `FeedingPage.swift:63`. Not taken: on the outline, half
  inside, which leaves those three about a quarter point under it; inside
  with fewer columns, which sets the chips and the profile feeding row 2 + 1
  at Large on every phone. Also seen: Export's format tiles
  (`ExportView.swift:115–119`) keep their own outline, 1 pt at rest and 2 pt
  centred when selected, the tile's edge in both states. Their description
  (11 pt, fixed) has no side padding and runs edge to edge: on 375 pt en
  «Beautiful report for printing or sharing» sets a first line of 151.2 pt
  in 151.5, which lies 0.8 pt under the selected outline (es 0.6). Measured at
  8b90029: the two descriptions set different line counts (on 375 pt en 2
  against 1), so the tiles have two heights. Direction (decided 2026-11-04,
  in code at c090a8e): sm 8 a side
  inside the tile, for the glyph, the name and the description, and the two
  tiles of the taller one's height, each laid from its top
  (`ExportView.swift:33–37`, `:99–112`). With sm 8 every line keeps 7 pt or
  more inside the outline's inner edge, with or without Bold Text, on 320 to
  440 pt; on 375 pt both tiles set 2 lines in every language, on 320 pt ru and
  es set 3 against 2. Why: a sentence needs a margin from its container's
  edge, sm 8 is the side padding of the app's other tiles that carry more than
  a word, and two equal tiles read as one control at one height. Not taken:
  the outline outside the fill (the sentence stays on the fill's edge, 0.15 pt
  a side on 375 pt en); xs 4 (5.7, and 3.2 with Bold Text). The 11 pt stays
  fixed (G2).
- **G30 · A title and its trailing value broke a word where they did not
  share a line** (found 2026-11-04 at 8b90029). Settings' iCloud Sync row
  (`AboutView.swift:17–28`) sets its value beside the title below the
  accessibility sizes. On 320 pt at Large the line needs 318.6 pt of the row's
  256, and «Синхронизация» beside «Выключена» misses by 9.2 (20.4 with Bold
  Text), so the title broke inside the word, as a 320 pt dump showed; es
  «Sincronización» misses from xLarge on 320 pt (at Large with Bold Text), and
  on 375 pt ru from xxLarge and es from xxxLarge. Every row of the kind was
  measured from CoreText (SF Pro in Settings, SF Rounded elsewhere; the row's
  inner width 256 on 320 pt and 311 on 375, a Settings Label's title 40 pt in at
  Large and 60 at AX2, from the live tree and shots on 402 pt) in en, ru and
  es, Large to AX2, regular and with Bold Text. Break: the Premium row's badge
  (`MainTabView.swift:343`) breaks «Premium» at AX1 in ru and at AX2 in en and
  es on 320 pt; `BBMeasureSlider` (`BBMeasureSlider.swift:16`) breaks ru
  «рождении» at AX2 on onboarding's birth weight and height (−14.3, −24.7);
  the Export category rows with their «0» (`ExportView.swift:162`) break ru
  «Подгузники» and es «Alimentación» at AX2 (−5.4, −10.6); the plan rows
  (`PlanPickerSection.swift:153`) miss by 3.8 at AX2 in ru on the title and
  badge alone; the medication menu (`DoseSheet.swift:245`) breaks a one-word
  name beside its label from xxLarge on 320 pt (ru «Парацетамол» −25.0 at
  xxxLarge). Hold: the bottle volume (`FeedingView.swift:514`, +3.7 at AX2
  with Bold Text), `BBProgressCard` (`BBCard.swift:294`, +13.4), the Growth
  history rows (`GrowthView.swift:792`, their values stacking at accessibility
  sizes) and `BBSectionHeader`'s action (a button, +8.9). Settings' Language
  row is the system's picker (`MainTabView.swift:232`): its one line misses
  from AX1 on 320 pt (en −44.0) and at AX2 on 375 pt in en (−34.5). Read on
  the 320 pt renders at c090a8e: the system keeps it side by side below the
  accessibility sizes and hyphenates a title that misses (en «Lan-» /
  «guage» at xxxLarge with Bold Text), and stacks it at them, the value at
  the row's leading edge (§ 3, the stated exception, decided 2026-11-06). A
  Settings Label does not move a first word wider than its room beside the
  icon (about 196 pt at AX2 on 320; «Синхронизация» 236.6) under the icon: it
  breaks it («Синхрониза» / «ция» at AX2, «Синхронизаци» / «я» at AX1 with
  Bold Text), since it sets the icon as a first-line indent and runs the
  later lines under it; from 1.3.0 the icon stands above a title whose first
  word misses its room beside it (§ 7 Settings switch row, in code at
  a298c62). Breaks § 3 (a word never breaks inside itself). Direction
  (decided 2026-11-04, in code at c090a8e): § 3's title + value rule, through `BBValueRow` (§ 7),
  on every row above that broke but the medication menu, whose label stands
  above it, and on the bottle volume and `BBProgressCard`, which held. The
  Growth history rows held on their words alone: a fixed date beside them
  cut their values at xxLarge on 320 pt, so they go by fit (§ 7 Growth
  history row; from 1.3.0, in code at a298c62), and `BBSectionHeader`'s
  action went (§ 7; in code at a298c62). Not taken:
  one fit for every row (a slider's figure changes under the drag, and the
  rows that hold would change shape with nothing broken); shorter words (they
  hold at Large only); a title that shrinks (the user's text set smaller in
  the one row that lacks room).
- **G31 · A screen's large title cut at the bar's edge; fixed for 1.3.0**
  (found 2026-11-05 at 3bb4936). The bar sets a large title on one line and
  cuts it at the tail; it never wraps. Its room is W − 32 pt below 414 pt of
  width and W − 40 from 414 (288 on 320, 343 on 375, 370 on 402, 400 on 440),
  and it draws the title at 0.969 of its CoreText width. The report at AX2 on
  402 pt read «For the pediatri…» (414.2 pt in 370). Of the 11 screens with a
  large title, 4 titles of 33 were cut at AX2 on 402 pt (the report in en,
  Recent activity in ru and es, Export in ru) and 9 on 320 pt (the report and
  Recent activity in all three languages, Export in ru and es, Medications in
  es); the report's en title from Large on 320 pt (295.9 in 288) and from
  xxxLarge on 375 pt. The other seven titles fit at every width and size (ru
  «Подгузники», the widest, 272.6 at AX2 in 288). Breaks § 3 (a word never
  breaks inside itself; here the title was cut inside one). Fix, decided
  2026-11-05 for 1.3.0, in code at 7b886b1, `BBScreenTitle.swift` (§ 3,
  § 7): the title leaves the bar where it misses it, `BBScreenHeading`. The
  fit measures the title at its CoreText width, so in six cells it leaves
  the bar one size before the bar would cut it, never after: Recent activity
  in ru on 320, 402 and 440 pt and in es on 440, Export in ru on 320 and
  375. At AX2 every heading but es «Medicamentos» (title2, 260.1 pt) takes
  two lines on 320 pt, and on 402 pt «For the / pediatrician», «Недавние /
  записи», «Actividad / reciente» and «Экспорт / данных» do. Not taken: an
  empty bar once the heading has scrolled away, as the sheets have (a screen
  with no name beside screens whose bar keeps it); shorter titles (the
  report's names are decided, and es «Medicamentos» alone misses at AX1 on
  320 pt); the inline title from AX1 (17 pt over content up to 48, and Large
  on 320 pt and xxxLarge on 375 stay cut).
- **G32 · Growth's floating + over the chart's end and the «?»; fixed for
  1.3.0** (found 2026-11-05 at 3bb4936). `BBFab` sat at the bottom-trailing
  corner, [368, 801]–[424, 857] on 440 pt at every scroll and size, over a
  page 3 screens long at Large and 4 at AX2. At rest it covered the chart's
  trailing bottom (40 × 25 pt at Large, 40 × 20 at AX2), where the chart's
  clear tap layer would select the nearest weighing and the + opened the
  new-measurement sheet instead; the Nutrition card's header «?» at Large
  and AX2; and at AX2 the Measurements tile's chevron (56 × 41 pt of the
  tile). Only the end of the scroll was clear, through the 64 pt bottom
  padding. The overlaps held on every width: the + spanned W − 72 to W − 16,
  the plot's trailing 40 pt W − 72 to W − 32, the «?» about W − 54 to
  W − 34. Breaks P7 (a tap target keeps its 44 pt; under the + the «?» and
  the chart's corner kept none at rest). Fix, decided 2026-11-05 for 1.3.0,
  in code at 7b886b1, `GrowthView.swift` (P7, `BBFab`): Growth has no
  floating +; a weighing is added from the bar's + and «Add a weighing», and
  the bottom padding is xl 32. Not taken: an inset (the end of the scroll is
  clear already, and at rest nothing moves out from under a fixed overlay);
  hiding it while scrolling (it returns at rest); bottom-leading (it would
  cover the chart's start and the cards' first words); a 72 pt trailing inset
  on the chart (a smaller plot on every width, the «?» still under the +).
- **G33 · Two PDFs, one word; fixed for 1.3.0** (found 2026-11-05 at
  eb1f410). The app makes two PDFs: the doctor's, from More › «For the
  pediatrician», and the export, from Profile › Data › «Export Data» › PDF
  (16 pages for 30 days: a summary, then a table per category). The entry
  rows are apart; at the choice and after it «report» named both. The PDF
  tile read «Beautiful report for printing or sharing» (ru «Красивый
  отчёт…», es «Un informe bonito…», `ExportView.swift:106`), the export's
  first page «Health & activity report» under «Bitty — Mia»
  (`ExportGenerator.swift:424`), and its file «Bitty_mia_2026-11-05.pdf»
  (`ExportView.swift:285`) lay beside «Pediatrician report – Mia –
  2026-11-05.pdf». A parent who looked for the doctor's report under Export
  picked the tile that promised one and got the tables. No written rule
  covered it: one word named two files. Fix, decided 2026-11-05 for 1.3.0,
  in code at 361abe5 and 0a925bf (§ 7 Export format card, § 9 The Export
  PDF): «report» stays the doctor's word. The PDF tile says what the file
  holds («Every entry, day by day», 117.6 pt at 11 pt; on 320 pt with sm 8 a
  side en 2 lines, ru 1, es 2, against 2, 3 and 3 before); under the tiles a
  caption points to the doctor's PDF («For the doctor’s visit: More › For
  the pediatrician»); the export's first page says «All entries» under its
  title and its file is «All entries – Mia – 2026-11-05.pdf», the name as
  typed, as the doctor's file has it, every file name within 255 bytes of
  UTF-8 with only the name giving way; the first page's count tiles read the
  plural stat words («45 Feedings»), the tables' headings the category's
  name (0a925bf). The entry rows stay. Not taken: renaming «Export Data»
  (the name says what the row does); a subtitle on the More row (one
  two-line row in a plain list); a link from Export to the report (a jump
  from Profile to another tab, which the app makes nowhere else); renaming
  the doctor's PDF (its names are decided).
- **G34 · No growth chart in the report PDF; fixed for 1.3.0** (found
  2026-11-05 at eb1f410, with the rendered PDFs of 8eea793). The Growth tab
  draws the weight on WHO's 3–97 corridor; the report PDF printed the same
  weighings as numbers only: the latest values, the weight and length
  percentiles as numbers, a table of the period's weighings. A doctor reads
  a growth history against the curves first. No rule was broken; a piece
  was missing. The month-long seed (doctorMonth) had 16.2 pt left on its one
  page (the closing line ends 765.6, the body 781.8), so any chart takes it
  to 2 pages. Fix, decided 2026-11-05 for 1.3.0, in code at 80d2e54
  (`DoctorReportPDF.swift`, `WeightForAgeChart.swift`; § 9 The report PDF's
  weight for age): weight for age only, as the report's last section before
  its closing line, kept whole, its block 145.6 pt. doctorMonth goes from 1
  page to 2, its page 1 losing only its closing line, with the chart and the
  closing line on page 2; on the other seeds page 1 stays as before; a short
  history (two weighings, the last question ending 591.4) stays on 1 page
  (14.2 pt to spare by the estimate); a period of today only stays on 1;
  a 2-page report stays on 2. The curves are lines, not a band, with no
  tint, no band word and no mark, as the percentile number has none
  (`m2-doctor-report.md` § 10.1 rule 7). Not taken: the chart in the Growth
  section under «At birth» (148 pt there push Diapers, the questions and the
  closing line of doctorMonth to page 2, splitting the month's figures); a
  length chart (the screen draws none, and a second block takes the short
  history to 2 pages); a head chart (the app holds no WHO head table, and
  head has no percentile); a filled band (a black-and-white print turns it
  into a grey slab and loses its edges); the period's window alone (a month
  of weighings draws a short stroke, not the curve).
- **G35 · Head on the PDF's weighings, not on the screen's; fixed for
  1.3.0** (found 2026-11-05 at eb1f410). The report screen's Growth card
  listed each weighing as «28 Oct · 5.42 kg · 58 cm»
  (`GrowthReportCard.swift:130`); the PDF's table of the same weighings has a
  Head column (`DoctorReportPDF.swift:206`), and the data holds the value
  (`DoctorReportSummary.Weighing.headCm`). The screen showed head only as the
  latest value in the card's facts. Broke the report's rule that the PDF's
  rows are the screen's rows (`m2-doctor-report.md` § 5). Fix, decided
  2026-11-05 for 1.3.0, in code at 80d2e54 (`GrowthReportCard.swift:132`,
  § 7 Report weighing row): a weighing with a head value gets a line under
  its values, «Head: 38.5 cm» (`growth.head_fmt`), the one shape that fits
  at every size: 112.2 / 123.1 / 128.3 pt at Large (en / ru / es) and about
  202 / 222 / 232 at AX2, in 256 pt on 320. Measured in ru on 320 pt at
  Large: a row 20.3 pt tall without a head value and 40.7 with one, a
  year-dated row with its head 61.0, one VoiceOver element a row. Not taken: head joined
  to the line bare (28 to 48 pt over on 320 pt at Large, over on every width
  at AX2, and a bare third number does not read as head); joined with
  «Head:» (74 to 102 pt over on 320 pt at Large); left out (the screen and
  its PDF keep disagreeing on one list). Also seen: a weighing from another
  year carries the year («May 28, 2026»), and its line wraps between words at
  Large on 320 pt (en by 7 pt with a wide value, ru by 17, es by 3); nothing
  is cut.
- **G36 · The progress card's figure stayed 13 pt at every size; fixed for
  1.3.0** (found 2026-11-06 at c67ab7c). `BBProgressCard`'s figure was
  `.system(size: 13, weight: .medium, design: .rounded)` (`BBCard.swift:393`
  at c67ab7c) and its icon `.system(size: 14, weight: .semibold)` (`:384`);
  only the title scaled (`:387`). At AX2 the figure stood 13 pt under a
  25.33 pt title (0.51), on every progress card: Home's feeding, sleep and
  wet nappies (`DashboardView.swift:490`) and the Diaper screen's daily norm
  (`DiaperView.swift:182`). Broke P6 and WCAG 1.4.4 (G2): the figure is the
  card's read-at-a-glance value. Fix (decided 2026-11-06, in code at
  1fb7ece; § 7 BBProgressCard): the figure 13 medium rounded and the glyph
  14 semibold relative to `.body`, as the 14 pt title
  (`BBProgressCard.Face`), so the figure keeps 13 : 14 with its title at
  every size (17 : 18.33 at xxxLarge, 23.67 : 25.33 at AX2), capped at AX2
  with the type scale; the glyph grows with the word it stands beside (§ 3).
  Below the accessibility sizes the row stands beside only while every word
  of the title keeps whole next to the figure (`BBValueRow`'s `.byWords`),
  else the figure goes under the title, as at the accessibility sizes. Not
  `SideBySideIdeal`: it splits a row between two wrapping texts, and the
  figure here is one line. Measured on 320 pt before the build (CoreText,
  the card 256 inside), beside held in ru, en and es at every size below the
  accessibility sizes but at xxxLarge with Bold Text, where es «Sueño»
  beside the widest sleep line «20 h 40 min de 14 h» kept +2.1 with the
  moon's advance and −0.2 with the heart's; every other case kept +7.3 or
  more, the counts +34.3 or more. A branch on the text size cannot see that
  edge; the fit can. Measured at 1fb7ece, that edge keeps +2.3, so with
  today's words no row goes under below the accessibility sizes. Under the
  title the figure starts past the glyph and is offered only the width from
  there: at AX2 with Bold Text ru «20 ч 40 мин из 14 ч» needs about 221 of
  about 219 and wraps between its words onto two lines, where a stack offered
  the row's whole width ran it to 289.7, past the card's inner edge at 288.
  Not taken: relative to `.footnote`, as `BBEventRow`'s
  subtitle, which outgrows the title at xxxLarge (19 against 18.33) and
  breaks es «Sueño» beside «16 h 20 min de 16 h» (−1.3 Regular, −9.1 Bold);
  left fixed, which keeps the one number the card is for at its smallest.
- **G37 · Home's header name cut at AX2 on 320 pt; proposed, after 1.2.0**
  (found 2026-11-06 at 92c70db). At AX2 on a 320 pt screen the name beside
  the 52 pt avatar reads «Алексан…», Regular and Bold. `title1` is 46.1 pt
  there and «Александра» 263.2 / 271.1 pt (Regular / Bold) in the 228 beside
  the avatar; at c67ab7c the source sets no line limit on the name
  (`DashboardView.swift:127`, `BBTheme.swift:120`), so the fix finds the
  cut's cause. Of 19 names tested in ru, en and es, every one fits 228 at
  xxxLarge and below, 13 miss it at AX2, and all 19 fit the full content
  width, 288 (the widest, «Анна-Мария», 278.5 Bold); on 375 pt the room
  beside the avatar is about 283 and every one fits. Breaks § 3: a word is
  never cut or broken inside itself. Proposed fix: § 7 Home header, the name
  and its pill under the greeting's row at the full width where the name
  misses beside the avatar, wrapping between words, stepping down to
  `title2`, then `title3`, only for a word wider than the full width. Not
  taken: a smaller size alone (at `title2`, 38.85 pt, «Александра» Bold is
  228.8 in 228, and every name would lose its size where it fits); a second
  line beside the avatar (no help to a one-word name); the greeting giving
  way (it loses words, and its widest word, «пожаловать» 171.9 pt, fits
  beside the avatar).
- **G38 · A primary button's words run to its edges on 320 pt; proposed,
  after 1.2.0** (found 2026-11-06 at a070713). On a 320 pt screen at Large the
  trial button's words with their arrow, ru «Попробовать 7 дн. бесплатно»,
  are 270.7 pt (278.2 Bold) in the 272 pt button and touch both edges, on the
  onboarding premium page and the paywall sheet alike
  (`PlanPickerSection.swift:298`); nothing is cut. `BBPrimaryButton` and
  `BBSecondaryButton` set no side padding and no line alignment
  (`BBButton.swift:4`, `:57`), so a label wider than its button wraps flush to
  the leading edge: at AX2 the widget page's «Создать / мой трекер». Breaks
  § 4: a surface's words keep md 16 from its edge. Measured with CoreText at
  17 pt and at 30.9 (AX2, 17 × 40/22), Regular and Bold, for every primary and
  secondary button's words in en, ru and es: at md 16 on 320 pt at Large only
  the ru trial words miss one line and set two, «Попробовать 7 дн. /
  бесплатно», 56 pt tall still; on 375 pt (295 inside) they keep one. At AX2
  on 320 pt the glyph leaves three labels whose widest word misses beside it,
  ru «Включить уведомления» (242.0 / 249.4 pt in 240), the ru trial words
  (240.3 / 247.0) and es «Activar notificaciones» (241.0 / 248.9); es
  «Agregar medicamento» with Bold Text keeps it at the edge (239.5). ru
  «Экспортировать» leaves its glyph from AX1 (246.5 / 252.9), and at AX2 the
  word alone (243.5 / 251.0) steps down to the AX1 size (207.5 / 213.9); on
  375 pt only that word with Bold Text leaves its glyph (296.0 in 295). Every
  other label keeps its glyph and its size. Proposed fix: § 7 BBPrimaryButton
  and BBSecondaryButton, md 16 a side, the label centred and wrapping between
  words, the glyph leaving before a word would break, a step down only for a
  word wider than the whole width. Not taken: sm 8 a side (a two-line label's
  ends then sit 1.9 pt clear of the radius-lg corner's curve, 9.9 at md 16); lg
  24 (16 pt more from every label, for corners already clear at md 16); a
  smaller size for every long label (the size is the reader's, P6); a shorter
  ru trial line (the wrap holds any length). Its fix is to come.
- **G39 · The onboarding setup steps cut at the accessibility sizes on
  320 pt; proposed, after 1.2.0** (found 2026-11-06 at a070713). At AX2 on a
  320 pt screen each of the five steps under the ring reads one cut line,
  «Персонализ…», «Калибруем п…», «Настраивае…», «Подготавли…»,
  «Настраивае…»: the steps set no vertical `fixedSize` and the page does not
  scroll (`GeneratingPage.swift:88`), so the column squeezes each to a line.
  The page moves on by itself, so nobody is stranded; the words are lost.
  Measured with CoreText and the SF line, not rendered: the step's 15 pt is
  19.8 / 23.2 / 27.3 at xxxLarge / AX1 / AX2, and ru «Персонализируем» is
  172.5 / 201.0 / 235.7 pt (181.5 / 211.6 / 248.2 Bold) in the 186 beside the
  disc, so from AX1 it would break inside the word even wrapped, and at AX2
  even in 218 with md paddings. Wrapped, the five rows' column is 610 pt at
  xxxLarge and 825 at AX2 in ru against the page's 548 (en 540 and 754, es
  610 and 889), and fits through xxLarge in en and ru (xLarge in ru with Bold
  Text) and through xLarge in es; one step in their place is at most 384 pt
  (ru Bold, AX2) and fits at every size. On 375 pt the five rows fit through
  xxxLarge in every language and through AX1 in en and ru. Breaks § 3: a word
  is never cut or broken inside itself. Proposed fix: § 7 Onboarding setup
  steps, the five rows wrapping while the column fits the page, else the step
  in progress alone under the title, centred, in a box as tall as the tallest
  step. Not taken: the five rows wrapping alone (the column is half again the
  page's height and more at AX2, and ru's word breaks); a scroll (the page
  moves on in 4.65 s, and steps below the fold go by unseen unless the parent
  scrolls); the discs kept beside the one step (the ring already counts);
  shorter steps (at AX2 they would still need the fit). Its fix is to come.
- **G4 · Red outside the destructive role.** The platform red is the app's
  destructive red (§ 2): `SwipeToDeleteRow` (`.red` tint, `BBCard.swift:232`)
  and `BBDeleteHistoryButton` (`.red`, red@0.06 fill, red@0.2 stroke,
  `BBCharts.swift:329–336`) use it for a delete. Off that role:
  `BabyProfileEditSheet:288` remove photo at red@0.8, paler than the system's
  red and so under its 3.25:1, and `PlanPickerSection:320` purchase error
  (`.red`): a purchase error is not destructive at all. The code itself names
  red "the colour for your data is about to go away" (`BBLockedHistoryFooter`).
  The other way round: the question and visit sheets' Delete
  (`QuestionSheet.swift:57`, `VisitDetailSheet.swift:137`, callout) is drawn
  in BBAlert, not the platform red, since the sheets came (read at 6fc67d1):
  BBAlert means only "raise this with someone", and as text it is 3.31 on the
  sheets' background in light. Breaks P1. Those two take the platform red
  through their destructive role (decided 2026-11-04, in force; in code at
  170d574). Measured at
  4f3c86c in light (iOS 26) and dark: the delete-all button's words 3.01 /
  5.01 on its red@0.06 wash, the photo's Remove 2.76 / 3.76 at red@0.8, the
  purchase error 3.25 / 5.29. In force (decided 2026-11-04; in code at
  16f2802, `BabyProfileEditSheet.swift:330`, `PlanPickerSection.swift:321`,
  `BBCharts.swift:321–331`): the Remove at
  the full platform red (3.25, as § 2 accepts for a delete); the purchase
  error's words in BBTextPrimary (13.01) after a platform-red
  `exclamationmark.circle.fill`, hidden from VoiceOver, so the colour sits on
  a mark beside the words (3.25, over a mark's 3:1) and the line still reads
  as an error; the delete-all button without its wash (3.25; its red@0.2
  stroke stays as its shape).
- **G5 · Dead alarm styling in shared components:** `BBStatCard.overLimit` and
  `BBProgressCard.overLimit` still render system red + triangle/exclamation;
  no call site passes `true` since DECISIONS 2026-09-05. Breaks P1 if ever
  reused. Their red words read 2.68 (the value at red@0.85 on its red wash)
  and 2.46 (the count at red@0.75) in light (at 4f3c86c); the only caller
  passing the flag, `DiaperView.swift:168` and `:176`, passes `false`.
  In force (decided 2026-11-04; in code at 16f2802): `overLimit` is gone
  from both cards with its red inks.
- **G6 · Data colours bypass the catalog** (§ 2 Data colours): no dark
  variants, and near-misses with the category tints (breast #E8A0BF vs
  BBFeeding #E8A0B4; formula/bath #B0C4F5 vs BBSleep #A9B0E8). One literal is
  in a view: `DiaperView.swift:164` (at 95525c6) `Color(hex: "#B0C4F5")`.
  Breaks P5 (stool swatches excepted).
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
- **G10 · textSecondary is under 4.5:1 in light on the background (4.48) and
  on every wash it sits on** — it carries the 11–15 pt captions, units and
  hints. Read at 4f3c86c on every site: 4.28 on the feeding and sleep
  tint@0.08 washes, 4.36 on diapers and 4.31 on growth, under `BBStatCard`'s
  unit and title (`BBCard.swift:70–76`) and Home's running-timer subtitle
  (`DashboardView.swift:655–657`); 4.05 on primary@0.08 over the background,
  under the history period picker's other words (`BBCharts.swift:38–40`),
  the locked footer's first line (`BBLockedHistoryFooter.swift:27–30`) and
  the paywall's Premium-active line (`PaywallView.swift:145–147`); 4.23 on
  sleep@0.10 (the Sleep start tiles' «Начать», `SleepView.swift:130–132`),
  4.30 on feeding@0.07 (the Feeding quick captions,
  `FeedingView.swift:147–149`) and 4.42 on primary@0.08 over the surface
  (Export's selected format, `ExportView.swift:106–108`); over the
  onboarding backdrop's blobs (`OnboardingBackground.swift:30–35`) the 14
  hints of the pages fall to 3.64 at a primary blob's centre. Dark passes
  (4.57 to 6.83). Breaks P8.
  Direction (decided 2026-11-04, in force; in code at 16f2802, in the app's
  and the widget's catalogs, both PDFs and the backdrop): BBTextSecondary in light
  #6B647C (components 0.420 / 0.392 / 0.486; OKLCH L 0.550 → 0.518, the same
  hue and chroma), dark unchanged: 5.12 on the background, 5.62 on the
  surface, 4.62 at worst (primary@0.08 over the background) and 4.83 to 5.05
  on the other washes; the backdrop's two primary blobs at 0.08 (4.62 at
  their centre; the accent blob, 4.69, stays at 0.18). Primary text against
  it is 2.54:1 (2.90 with #746D85), and the secondary words stay the smaller or
  lighter of their pair. The widget's copy takes the value (the Live
  Activity's secondary lines on BBSurface, 4.92 → 5.62), and so do
  `ExportGenerator`'s #746D85 (`:408`, `:416` at 4f3c86c) and `DoctorReportPDF`'s
  `secondary` (`:18`): on paper 4.92 → 5.62, on the export card's #F2F2F7
  4.41 → 5.03 (G16). The White and Black swatches' edge (G20) goes 4.48 →
  5.12. Why 4.6 and not 4.5: renders read a few hundredths under the
  computed ratio, and #6C657D (4.55) leaves no margin. Not taken: today's
  value nudged to 4.5 on the background (#736C84) with the words on the
  washes in BBTextPrimary, which makes a stat card's value, unit and title
  one ink; lighter washes, since the bare background is 4.48.
- **G11 · `EmptyStateView` lives in `Features/Feeding/FeedingView.swift`**
  though four surfaces share it; belongs in `DesignSystem/Components/`.
- **G12 · Words on the brand gradient are under 4.5:1 in both modes** (read
  at 8d3d2ba). The widget (`WidgetViews.swift`, small and medium, and the
  onboarding page's copy, `WidgetShowcasePage.swift:93–103`) and the premium
  hero (`PremiumHero.swift`, both paywalls) draw white words on
  BBGradientStart → BBGradientEnd: white is 5.62 → 2.64 in light and 4.48 →
  3.05 in dark, and most words are at white@0.7–0.9, which fails at both ends
  in both modes (white@0.75: 3.96 / 2.13 in light). At the words' own places
  (CoreText layout, en / ru / es, every widget size): the widget's 16 word
  sites read 2.37–4.62 in light and 2.46–4.07 in dark, the row titles at
  white@0.7 (`:479–481`) the worst; the row glyphs at white@0.8 2.89 in both;
  the hero's title 3.09–3.26 / 3.32–3.41 (26 semibold, needs 3), its
  headline at white@0.82 2.40–2.59 / 2.65–2.75. Breaks P8. The widget's
  control capsule passes (BBPrimary on BBSurface, 5.62 / 6.15).
  Direction (decided 2026-11-04, in code at 3bb4936): one gradient in both modes,
  one step deeper in its own hue, BBGradientStart #5D4893 and BBGradientEnd
  #7B68B6 (OKLCH L 0.460 → 0.569 at the start's hue and chroma) in the app's
  and the widget's catalogs, with every word and glyph on it in white at full
  strength and the hierarchy by size and weight: 7.46 at the start and 4.67
  at the end, so every point of the plate passes; the widget's words
  5.21–6.68, the hero's title 5.16–5.35 and headline 4.88–5.16. The dark
  plate is dimmer than today's (L 0.46–0.57 against 0.58–0.67). In dark the
  capsule stands 2.6–3.5 against the plate around it, and its words name it
  (WCAG 1.4.11 needs no edge). The hero's BrandMark keeps its white@0.35
  ring, the badge's edge, not a word, a state or a control: 2.32 → 1.87 on
  this plate (2.03 → 1.46 on the old light one; § 7). Why: every point of the plate passes white,
  so no word, locale or new state reaches a failing corner, and the widget is
  quieter on a home screen at night. Not taken: the dark plate kept lavender
  (#8874C4 → #9C89CE) with BBOnPrimary's dark ink, which makes the widget
  brighter in dark than in light and flips its ink by mode; a pale plate in
  light (#A795D9 → #D3BEE7) with BBTextPrimary words, which turns the widget
  into a pale card and takes the white capsule's shape (1.71); today's light
  start with the end moved to 4.62 (#7D69B4), a gradient flattened to a
  quarter of its range.
- **G13 · Reduce Motion is honoured only in onboarding;** shared springs
  (press, progress, swipe) ignore it. Small movements, low risk.
- **G14 · No named motion tokens:** 8 spring variants for 4 intents.
- **G15 · Palette of record is incomplete:** `README.md#дизайн-система` lists 4
  light-only colours of 19 colorsets; `AccentColor.colorset` duplicates
  BBPrimary and is missing from the re-theme list in CLAUDE.md. README should
  point here.
- **G16 · The export PDF's neutrals are mostly iOS system greys,** not the brand
  neutrals (#1C1C1E/#F2F2F7 vs BBTextPrimary/BBBackground; also #F9F9FB even rows,
  #E5E5EA rules). Its labels and footer are BBTextSecondary (#6B647C from 16f2802,
  #746D85 before). Defensible for
  print; noted so a re-theme does not miss it. The labels on the cards'
  #F2F2F7 are 4.41:1, under P8 (`ExportGenerator.swift:403`, `:408`, at
  4f3c86c); G10's #6B647C makes them 5.03 (in code at 16f2802).
- **G17 · The splash words over the art are under every ratio** (measured
  2026-11-04 at 8d3d2ba and again at 32fefea with the art's pixels read
  where they lie, from `BBSplashBg` under the words' frames, every pixel, on
  six portrait screens and eight landscape windows, en / ru / es). The wordmark
  (`SplashView.swift:33–35`, 42 semibold serif) and the tagline (`:40–50`,
  14 medium caps, tracking 4.5, at @0.85 with its leaves) are BBSplashText
  #F7F1E4 over the lavender field and its white clouds: in portrait the
  wordmark reads 1.16–1.41 at worst (1.45 median), the tagline 1.07–1.35
  (1.38–1.40); BBSplashText on BBLaunchBackground alone is 1.52. The
  wordmark is the brand name, a logotype (WCAG 1.4.3 sets no minimum); the
  tagline is text (4.5). Breaks P8. Direction (decided 2026-11-04,
  in code at 3bb4936): BBSplashText #4A357E, one value in both modes, the deep violet of
  the brand hue (OKLCH L 0.392), and the tagline at full strength: under the
  tagline 4.87 (en, 320 pt) to 5.90 at worst on every portrait screen, the
  wordmark 5.58–5.97. BBTextPrimary cannot carry it: it turns light in dark
  while the art stays. Why: the tagline is live text, and one ink keeps the
  lockup whole. Not taken: the wordmark kept cream as a logotype with
  only the tagline deep, one lockup in two inks; the cream kept on both lines
  as a brand moment by design, which leaves live text at 1.1–1.4. In
  landscape: G28.

**By design (not gaps — do not re-raise)**
- **G3 · Stool-colour warning in DiaperView** (`DiaperView.swift:497–505` at
  95525c6, orange + `exclamationmark.triangle.fill`): it stays as it is — a
  deliberate exception to the calm rule for a medically meaningful signal
  (pale/white stool). Product decision, 2026-10-28. Its words, system orange
  on the orange@0.1 wash, are 2.13:1 in light (2.03 on iOS 17–18; 6.14 in
  dark; at 4f3c86c, `DiaperView.swift:510–515`). They stay orange with the
  triangle and the wash: the exception is its whole look (2026-11-04).

# Design system — BabyBloom (Bitty / Ночка / Nenita)

status: baseline — describes what `main` ships at 10cf1a9 (2026-10-28); updated
2026-10-28 with D13, D14 and the M1 token BBOnPrimary. Every value marked
`in force` is in code, in `DECISIONS.md` or an owner decision (D<n>); `planned`
means decided, not shipped yet. Gaps are notes (§ 10), not fixes.
owner: design · **canonical copy `teamdocs/design/design-system.md`** (committed);
`.team/design/design-system.md` is the designer's working draft, kept
byte-identical (`cmp` before every commit).
sources: `BabyBloom/Resources/Assets.xcassets/Colors/`, `BabyBloom/DesignSystem/`,
`DECISIONS.md`, `docs/design/`, `README.md#дизайн-система`.
surface notes: `teamdocs/design/m1-live-activity.md` (Live Activity, widget controls).

## 1. Principles

triggers: a new DECISIONS.md entry or owner decision about colour, copy tone, gates or accessibility
check: none — principles are read against DECISIONS.md and `.team/manager/decisions.md` at review, not measured

Character: soft lavender femtech — pastel tints, rounded surfaces, diffuse
shadows tinted in the brand hue, rounded SF for body and digits, straight SF
semibold for headers.

| # | principle | status | source |
|---|---|---|---|
| P1 | **Calm rule.** The app never frightens a tired parent: no alarming colour, icon or copy unless something genuinely needs raising with someone. A count above its reference is reassurance, never red, flagged or triangled; fast gain takes the neutral primary tint, not the green tick. Red (`BBAlert`) means only "raise this with someone": growth flags and the tails of the percentile chart — never a count. **One by-design exception:** the stool-colour warning in DiaperView (orange + triangle, D13). | in force | DECISIONS 2026-09-05 "A count above its reference is never styled as an alarm"; DECISIONS 2026-09-22 (rating prompt blocked by the calm rule); D13 |
| P2 | **Locked is not wrong.** A paywall gate is drawn in the calm primary tint (`primary@0.08` fill, `lock.fill`), never alarm red — nothing was lost. | in force | `BBLockedHistoryFooter` |
| P3 | **Gate visible before the tap.** Every gated control carries `LockBadge` and says "locked" to VoiceOver (`bbLockedAccessibility`). A free-looking control that answers with a paywall is a bait-and-switch. | in force | `LockBadge`, `BBQuickActionButton.locked` |
| P4 | **Paywall gates seeing, never deleting.** Delete reaches every row in range, hidden ones included, and the confirmation says so. | in force | DECISIONS 2026-09-01; `BBDeleteHistoryButton` |
| P5 | **Colours only through the Asset Catalog** (`BBTheme.Colors`); never a literal in a view. Re-theming = colorsets + the widget's copies + the two splash PNGs + `ExportGenerator` hex. | in force | DECISIONS 2026-07-21, 2026-09-01 |
| P6 | **Dynamic Type through `BBTheme.Typography`**, ceiling AX2 (`accessibilityLarge`) in one constant. | in force | DECISIONS 2026-08-28 |
| P7 | **One-handed at night.** Primary "add" sits in the thumb zone (`BBFab`, bottom-trailing); tap targets ≥ 44 pt. | in force | `BBFab` (D6 in code), `BBLockedHistoryFooter`, `DiaperView` |
| P8 | **Contrast floor (WCAG 2.2 AA):** text ≥ 4.5:1 against its fill; ≥ 3:1 for text ≥ 18.66 pt bold / 24 pt regular and for non-text UI that carries meaning (icons, rings, borders). New surfaces are held to it; existing violations go to the backlog, not to blockers. | in force | D14 (owner, 2026-10-28) |

## 2. Colour tokens

triggers: a colorset added, removed or re-valued; a `BBTheme.Colors` member added
check: `ls BabyBloom/Resources/Assets.xcassets/Colors | sed 's/.colorset//'` → the 17 shipped names below (18 once BBOnPrimary lands); `grep -o 'Color("BB' BabyBloom/DesignSystem/BBTheme.swift | wc -l` → 15 (BBLaunchBackground and BBSplashText are read by `SplashView` directly)

All sRGB, light (`any`) / dark (`luminosity: dark`).

| colorset | Swift | light | dark | role |
|---|---|---|---|---|
| BBPrimary | `Colors.primary` | #6F5BA8 | #A795D9 | brand violet: primary buttons, FAB, links, selected states, calm gates, shadow hue |
| BBOnPrimary | `Colors.onPrimary` | #FFFFFF | #171420 | **planned (M1, accepted in the plan v2 review round, D15)** — label and glyph colour on any filled BBPrimary surface; white-on-primary in dark is G1. Added by Dev in `live-activity-timers`, also copied to the widget catalog |
| BBAccent | `Colors.accent` | #E8B49B | #EFBFA6 | warm peach accent (also copied to the widget) |
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
- `WidgetResources/Colors.xcassets`: copies of BBGradientStart, BBGradientEnd,
  BBAccent; the pre-build script fails on drift (DECISIONS 2026-09-01). M1 adds
  the colorsets the Live Activity and the widget control need (list in
  `m1-live-activity.md` § 6).
- `ExportGenerator` (PDF/HTML): #6F5BA8 → #A795D9 header gradient and table
  heads, #6F5BA8 card titles; neutrals are iOS system greys (#1C1C1E text,
  #F2F2F7 cards, #8E8E93 labels, #E5E5EA rules). The one accepted duplication.

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
- `DiaperEntry` stool swatches — yellow #F5D55F, green #6BBF6B, black #2C2C2C, brown #8B5E3C, orange #F5A45F, red #E05A5A, white #F0F0F0 (these depict a real colour, so a literal is defensible here)

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
| white on gradient end | **2.64** | 3.05 |
| white on gradient start | 5.6 | 4.48 |
| alert on surface | 3.6 | — |
| feeding / sleep tint on surface | **2.1 / 2.1** | 6.0 / 5.5 |

Bold = under P8 for normal-size text; see § 10.

## 3. Typography

triggers: a `BBTheme.Typography` function added or re-sized; the Dynamic Type ceiling moved
check: `grep -nE 'static func (largeTitle|title[123]|body|bodyEmphasized|callout|caption|metric|metricSmall)\(' BabyBloom/DesignSystem/BBTheme.swift` → the 10 rows below

Scale "D1": straight SF Pro semibold for headers; SF Rounded for body; rounded +
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

Shadows "D2": diffuse, tinted with `primary` instead of black.

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
check: `grep -hoE '^(struct|enum) [A-Za-z]+' BabyBloom/DesignSystem/Components/*.swift | sort` → the names below (`HistoryFilter` is the picker's model; `EmptyStateView` and `AppAppearance` live elsewhere)

| component | file | purpose | used in |
|---|---|---|---|
| BBPrimaryButton | BBButton | full-width CTA: primary→primary@0.8 gradient, white 17 semibold, min 56 pt, radius lg, `button` shadow, loading state | Feeding, Sleep, Diaper, Events, Growth, Export, BabyProfileEditSheet, PlanPickerSection, Onboarding (Welcome, Fact, Notifications, GrowthShowcase, WidgetShowcase, OnboardingView) |
| BBSecondaryButton | BBButton | outlined companion: primary@0.10 fill, primary@0.30 stroke | — (unused) |
| BBQuickActionButton | BBButton | 60 pt tint@0.22 disc + 26 pt glyph + 12 pt label; optional `LockBadge` | Dashboard |
| BBIconButton | BBButton | circular tint@0.12 icon button, 48 pt | — (unused) |
| BBScaleButtonStyle | BBButton | press feedback for every tappable (§ 8) | 11 feature files |
| BBStatCard | BBCard | tonal KPI tile: 36 pt icon tile, metric value + unit + title, optional trend chip and chevron, whole card tappable, min 110 pt | Dashboard, Feeding, Sleep, Diaper, Growth |
| BBEventRow | BBCard | elevated list row: 44 pt tint disc, title/subtitle, trailing time | Feeding, Sleep, Diaper, Events, RecentActivity |
| BBProgressCard | BBCard | elevated card with 8 pt progress bar toward a target | Dashboard, Diaper |
| BBSectionHeader | BBCard | title3 header + optional "All" action | Dashboard, Feeding, Sleep, Diaper, Events, Growth, BBHistorySection |
| SwipeToDeleteRow | BBCard | custom swipe-to-reveal 76 pt delete action | Events, Growth, RecentActivity, BBHistorySection |
| BBFab | BBFab | 56 pt primary circle "+", bottom-trailing overlay, md inset; mirrors the toolbar "+" | Feeding, Sleep, Diaper, Growth |
| BBHistorySection | BBHistorySection | history header + range picker + empty state + swipe list + locked footer + delete-all | Feeding, Sleep, Diaper |
| BBHistoryFilterPicker | BBCharts | segmented range picker (selected chip primary, white text) | BBHistorySection |
| BBWeeklyBarChart | BBCharts | Swift Charts 7-day bars, today full tint, week navigation | Feeding, Sleep, Diaper |
| BBDeleteHistoryButton | BBCharts | destructive "delete all" with a scope-honest confirmation (P4) | Events, BBHistorySection |
| BBLockedHistoryFooter | BBLockedHistoryFooter | the one calm locked row for history beyond the free window (P2) | Events, RecentActivity, BBHistorySection |
| LockBadge + `bbLockedAccessibility` | LockBadge | the one padlock: 10 pt glyph on a surface disc; VoiceOver value "locked" (P3) | Events, BBQuickActionButton |
| BrandMark | BrandMark | `BBLogo` clipped to a circle, 1 pt ring, optional shadow, on-gradient variant | MainTabView, PremiumHero, Onboarding (Welcome, Generating) |
| BBElapsedTimer | BBElapsedTimer | per-second elapsed label, 36 pt mono, MM:SS or HH:MM:SS | Dashboard, Feeding, Sleep |
| BBMeasureSlider | BBMeasureSlider | elevated labelled slider with mono value and min/max | Growth, Onboarding GrowthPage |
| BBOptionalMeasureToggle | BBMeasureSlider | toggle that reveals a slider (head circumference) | Growth, BabyProfileEditSheet, Onboarding (Birth, Growth) |
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
check: `ls WidgetResources/Colors.xcassets` → BBAccent, BBGradientEnd, BBGradientStart (plus the M1 list once it lands)

- **Widget** (`Features/Widget/WidgetViews.swift`): premium gradient
  background, all text white at 0.7–1.0 opacity, raw rounded sizes 10–32 pt
  (widgets do not take Dynamic Type the same way; fixed sizes are expected
  here). M1 adds tap areas and a start-feeding control (D16):
  `m1-live-activity.md` § 5.
- **Live Activity** (M1, `planned`): Lock Screen on BBSurface, Dynamic Island
  on its black — spec in `m1-live-activity.md`.
- **Splash** (`Features/Splash/SplashView.swift`): BBLaunchBackground, then
  `BBSplashBg` art (design PNG with its text band stitched out), wordmark in
  BBSplashText. Launch screen is colour-only. Art: `docs/design/splash*.png`.
- **App icon**: `docs/design/icon*.png`, brief `docs/design/icon-design-brief.md`.
- **PDF / HTML export**: § 2 "Outside `Colors/`".

## 10. Gaps and inconsistencies (notes, not fixes — 2026-10-28)

triggers: any gap fixed or a new one found at review
check: none — each gap carries its own grep; re-run it when the gap is worked

Seen from code at 10cf1a9; no live look on device yet. Each line: what,
where, which rule. Per D14, existing contrast violations are backlog items, not
blockers; G1 and G2 are in the backlog (Manager, 2026-10-28).

**Major**
- **G1 · White on BBPrimary in dark mode is 2.64:1.** Dark primary #A795D9 is
  a light lavender; `BBFab` "+", `BBPrimaryButton` (worse at the
  primary@0.8 end of its gradient), the selected chip of
  `BBHistoryFilterPicker` and other `foregroundStyle(.white)` on primary fills
  sit under 3:1. Breaks P8. Fix: adopt BBOnPrimary (§ 2) on those surfaces;
  M1 surfaces use it from the start.
- **G2 · 148 raw `.system(size:)` fonts in the app** (widget excluded) never
  scale with Dynamic Type, against P6 / DECISIONS 2026-08-28. Heaviest:
  GrowthInsightCards 20, BBCard 15, DiaperView 12, FeedingView 10,
  BabyProfileEditSheet 9. Includes shared components: `BBStatCard`
  unit/title 13 pt, `BBEventRow` subtitle/time 13 pt, `BBQuickActionButton`
  label 12 pt, `BBMeasureSlider` min/max 11 pt. grep: `grep -rno --include=*.swift '\.system(size:' BabyBloom | grep -v WidgetViews | wc -l`

**Minor**
- **G4 · System red without a token for destructive actions:**
  `SwipeToDeleteRow` (`Color.red`), `BBDeleteHistoryButton`
  (`.red`, red@0.06 fill, red@0.2 stroke), `BabyProfileEditSheet:288`
  remove photo (red@0.8), `PlanPickerSection:214` purchase error (`.red`).
  The code itself names red "the colour for your data is about to go away"
  (`BBLockedHistoryFooter`), yet no `destructive` token exists; a purchase
  error is not destructive at all. Breaks P5.
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
- **G9 · Unused system API next to hand-rolled copies:** `bbCard()`,
  `bbBareRow()`, `bbGlass()`, `BBSecondaryButton`, `BBIconButton` have no
  callers; `BBEventRow`, `BBProgressCard`, `BBMeasureSlider` and the weekly
  chart hand-roll surface + radius + `card` shadow and so lack the level-1 top
  highlight `bbCard()` defines.
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
  light-only colours of 17 colorsets; `AccentColor.colorset` duplicates
  BBPrimary and is missing from the re-theme list in CLAUDE.md. README should
  point here.
- **G16 · PDF neutrals are iOS system greys,** not the brand neutrals
  (#1C1C1E/#F2F2F7/#8E8E93 vs BBTextPrimary/BBBackground/BBTextSecondary).
  Defensible for print; noted so a re-theme does not miss it.
- **G17 · Splash text contrast unknown:** BBSplashText on BBLaunchBackground
  is 1.52:1, but the text sits on the splash art, not the plain backdrop —
  needs a live look.

**By design (not gaps — do not re-raise)**
- **G3 · Stool-colour warning in DiaperView** (`DiaperView.swift:410–416`,
  orange + `exclamationmark.triangle.fill`): the owner keeps it as it is — a
  deliberate exception to the calm rule for a medically meaningful signal
  (pale/white stool). D13, 2026-10-28.

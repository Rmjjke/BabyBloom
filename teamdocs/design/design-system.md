# Design system — BabyBloom (Bitty / Ночка / Nenita)

status: baseline — describes what `main` ships at 10cf1a9 (2026-10-28); updated
2026-10-28 with the stool-colour exception (G3), the contrast floor (P8) and the
M1 token BBOnPrimary; § 2 and G16 follow the export PDF of 2026-11-02; on
2026-11-03 BBOnPrimary and the Live Activity are in force as shipped in 1.1.0,
and the colorset counts and the re-theme list follow the code. Also on
2026-11-03: the primary button's ink for 1.3.0 (G1), the platform red as the
destructive red (§ 2, G4) and G9 follow the 1.2.0 code. Every value
marked `in force` is in code, in `DECISIONS.md` or in a product decision stated
here with its reason; `planned` means decided, not shipped yet. Gaps are notes
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
check: `ls BabyBloom/Resources/Assets.xcassets/Colors | sed 's/.colorset//'` → the 18 names below; `grep -o 'Color("BB' BabyBloom/DesignSystem/BBTheme.swift | wc -l` → 16 (BBLaunchBackground and BBSplashText are read by `SplashView` directly)

All sRGB, light (`any`) / dark (`luminosity: dark`).

| colorset | Swift | light | dark | role |
|---|---|---|---|---|
| BBPrimary | `Colors.primary` | #6F5BA8 | #A795D9 | brand violet: primary buttons, FAB, links, selected states, calm gates, shadow hue |
| BBOnPrimary | `Colors.onPrimary` | #FFFFFF | #171420 | **in force since 1.1.0** (decided 2026-10-28) — label and glyph colour on any filled BBPrimary surface. Shipped with the Live Activity (its button capsule, `TimerActivityViews.swift`) and copied to the widget catalog; from 1.3.0 it is also the label of `BBPrimaryButton`, the `BBFab` "+" and the selected `BBHistoryFilterPicker` chip (G1), and other white-on-primary fills stay G1 |
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
| white on `BBPrimaryButton`'s primary@0.8 end, over the background | **3.80** | **3.76** |
| BBOnPrimary on `BBPrimaryButton`'s primary@0.9 end (from 1.3.0) | 4.60 | 5.78 |
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
check: `grep -hoE '^(struct|enum) [A-Za-z]+' BabyBloom/DesignSystem/Components/*.swift | sort` → the names below (`HistoryFilter` is the picker's model; `EmptyStateView` and `AppAppearance` live elsewhere)

| component | file | purpose | used in |
|---|---|---|---|
| BBPrimaryButton | BBButton | full-width CTA: primary→primary@0.8 gradient, white 17 semibold, min 56 pt, radius lg, `button` shadow, loading state. From 1.3.0 the gradient ends at primary@0.9 and the label is BBOnPrimary (G1) | Feeding, Sleep, Diaper, Events, Growth, Export, BabyProfileEditSheet, PlanPickerSection, Onboarding (Welcome, Fact, Notifications, GrowthShowcase, WidgetShowcase, OnboardingView) |
| BBSecondaryButton | BBButton | outlined companion: primary@0.10 fill, primary@0.30 stroke | DoctorReport (QuestionsCard), since 1.2.0 |
| BBQuickActionButton | BBButton | 60 pt tint@0.22 disc + 26 pt glyph + 12 pt label; optional `LockBadge` | Dashboard |
| BBIconButton | BBButton | circular tint@0.12 icon button, 48 pt | — (unused) |
| BBScaleButtonStyle | BBButton | press feedback for every tappable (§ 8) | 11 feature files |
| BBStatCard | BBCard | tonal KPI tile: 36 pt icon tile, metric value + unit + title, optional trend chip and chevron, whole card tappable, min 110 pt | Dashboard, Feeding, Sleep, Diaper, Growth |
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
measured on the medication screens' renders. Each line: what,
where, which rule. Under P8, existing contrast violations are backlog items, not
blockers; G1 and G2 are in the backlog (2026-10-28).

**Major**
- **G1 · White on BBPrimary in dark mode is 2.64:1.** Dark primary #A795D9 is
  a light lavender; `BBFab` "+", `BBPrimaryButton`, the selected chip of
  `BBHistoryFilterPicker` and other `foregroundStyle(.white)` on primary fills
  sit under 3:1. Breaks P8. `BBPrimaryButton`'s worse end differs by mode: in
  dark it is the start (2.64, against 3.76 at the primary@0.8 end, which the
  dark background darkens); in light it is the end (3.80, against 5.6 at the
  start), where long ru and es labels measure 4.26–4.40 as their text ends.
  Fix, decided 2026-11-03 for 1.3.0: `BBPrimaryButton`, `BBFab` and the
  selected chip take BBOnPrimary (§ 2), and the button's gradient ends at
  primary@0.9; the button's worse end is then 4.60 in light and 5.78 in dark.
  Why before 1.3.0: the medication screens carry the button and are opened at
  night, in dark. The Live Activity has used BBOnPrimary since 1.1.0; other
  white-on-primary fills stay in this gap.
- **G2 · 148 raw `.system(size:)` fonts in the app** (widget excluded) never
  scale with Dynamic Type, against P6 / DECISIONS 2026-08-28. Heaviest:
  GrowthInsightCards 20, BBCard 15, DiaperView 12, FeedingView 10,
  BabyProfileEditSheet 9. Includes shared components: `BBStatCard`
  unit/title 13 pt, `BBEventRow` subtitle/time 13 pt (scaled from 1.3.0, § 7), `BBQuickActionButton`
  label 12 pt, `BBMeasureSlider` min/max 11 pt. grep: `grep -rno --include=*.swift '\.system(size:' BabyBloom | grep -v WidgetViews | wc -l`

**Minor**
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
  light-only colours of 18 colorsets; `AccentColor.colorset` duplicates
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
- **G3 · Stool-colour warning in DiaperView** (`DiaperView.swift:410–416`,
  orange + `exclamationmark.triangle.fill`): it stays as it is — a
  deliberate exception to the calm rule for a medically meaningful signal
  (pale/white stool). Product decision, 2026-10-28.

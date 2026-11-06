# M1 — Weekly summary card on the Dashboard (design note)

status: final, 2026-10-28; corrected after the design review 2026-10-30 (notification tap lands collapsed, range per locale, gain as a rate, glyphs scale with the text, × and Reduce Motion, days before birth); § 2 ⑥ the delta arrow scales with caption, after the live AX2 look of #85, 2026-11-01 (main 1fc4848 via #86); 2026-11-04: the days line ⑦ shows on every week and says the rows are averages, and the gain line without a number has four cases, one without the button (S6) (both decided), the rows' fit on 320 pt is measured (§ 4 Fit), and the rows' one shape by fit, a legend line for the arrows ⑪ and a hidden line after × ⑫ are decided the same day; 2026-11-05: in code as built — the days line on every week (3b9dd3d), the four gain cases (98e26b3), the rows' one shape by fit with no shrink (0334779), the legend ⑪ and the hidden line ⑫ (7070300); ③ follows the code (scaled with footnote); each week's card opens collapsed (in code at 3e4044a, 2026-11-06)
decisions: a Dashboard card at the top once a week that expands on tap, because everyone who opens the app sees it and it is quicker to build; calendar week Mon–Sun and a calm notification on Monday morning outside quiet hours, a reason to come back; free, because the summary is about retention and is already bounded by the 15-day free history window; WCAG 2.2 AA; no gain number in the newborn window, because a −180 g in week one is normal but reads as a verdict (DECISIONS 2026-09-05); stays Mon–Sun, × hides until next week; averages over days with entries + "N of 7", because a forgotten day is not "the baby slept less"; neutral deltas; a notification tap lands collapsed (2026-10-29); the days line on every week, worded as averages, because no row label with "average" fits beside its delta on 320 pt and a full week said "a day" with nothing beside it (2026-11-04); the rows' one shape by fit with no shrink, because a fit per row breaks the deltas' column and the 0.85 floor cut the sleep row on 320 pt in every language; one legend line for the arrows, because no word fits beside them on 320 pt and VoiceOver already speaks each comparison; the hidden line with an undo after ×, because the parent learns where the card went and when it comes back and can take back a mistaken tap (2026-11-04); each week's card opens collapsed, because the open state belongs to the week it was opened on and a Monday notification tap lands collapsed (2026-11-05)
reference: `teamdocs/design/design-system.md` (P = principle, G = gap)
triggers: a figure added to or removed from the card; a state added; the newborn-window, week-span or averages rule changed; a row's words or a delta's format changed (measure § 4 Fit again)
check: `grep -c '"weekly\.' BabyBloom/Resources/Localization/en.json` vs the string keys in § 6

Drawn by hand. Sizes were targets; the design review checked them on renders and live.

## 1. Place and surface

- **Dashboard order:** header → running timers (if any) → **weekly card** → Quick input → … A running timer outranks the summary at 3 a.m. Otherwise the card is the first thing under the header.
- **Shown** from Monday 00:00 to Sunday 23:59 for the calendar week before. Hidden by × until the next Monday. Not shown when last week holds no entries.
- **Surface:** elevated `bbCard()` (surface, radius md, `card` shadow, top highlight). It is the first real caller of `bbCard()`, which partly closes G9.
- **Type:** named `BBTheme.Typography` styles and `Typography.scaled` only (G2 not repeated); drawn at default size and AX2.

## 2. Collapsed

Where every row fits beside its delta (at Large: en and es from 375 pt, ru from 402 pt; § 4 Fit):

```
┌───────────────────────────────────────────────────────┐
│ Last week                                   (⌄)  (×)  │  ① title3 · ② range caption · ③ chevron · ④ ×
│ Oct 20 – 26                                           │
│                                                       │
│ ♥  Feeds a day: 7.4                         ↑ 0.6     │  ⑤ value rows (label: value) · ⑥ delta
│ ☾  Sleep a day: 14 h 20 min                 ↓ 25 min  │
│ ⚖  Weight gain: +210 g/week                           │
│                                                       │
│ Arrows show the change from the week before.          │  ⑪ legend (S2: the first-week line)
│ Averages over the days with entries: 6 of 7           │  ⑦ every week
└───────────────────────────────────────────────────────┘
   padding md 16 · rows sm 8 apart · header to rows md 16
```

Where one row does not fit (320 pt at Large in every language; § 4 Fit):

```
┌──────────────────────────────────┐
│ Last week               (⌄)  (×) │
│ Oct 20 – 26                      │
│                                  │
│ ♥  Feeds a day: 7.4              │
│    ↑ 0.6                         │  ⑥ under the value, 2 apart
│ ☾  Sleep a day: 14 h 20 min      │
│    ↓ 25 min                      │
│ ⚖  Weight gain: +210 g/week      │
│                                  │
│ Arrows show the change from the  │
│ week before.                     │
│ Averages over the days with      │
│ entries: 6 of 7                  │
└──────────────────────────────────┘
```

| # | element | spec | light | dark |
|---|---|---|---|---|
| ① | title `weekly.title` | `Typography.title3`, BBTextPrimary | 14.3 | 14.1 |
| ② | range `weekly.range_fmt` | `Typography.caption`, BBTextSecondary. The month is written once, on the side the language puts it: "Oct 19 – 25", «19 – 25 окт.», "19 – 25 oct". Across months both ends carry theirs: "Sep 28 – Oct 4" | 4.9 | 6.1 |
| ③ | chevron | `chevron.down` 13 pt semibold, **scaled** with `@ScaledMetric(relativeTo: .footnote)`: 27 pt at AX2, a touch ahead of the title (18 pt relative to `.headline`, 34.9 at AX2, which would put the chevron at 25.2). BBPrimary; rotates 180° when expanded. It is the only visible sign that the header expands, so it grows at least as fast as the text. The **whole header row** is the expand button, min 44 high, VoiceOver `weekly.a11y_expand` / `_collapse` | 5.6 | 6.2 |
| ④ | × hide | `xmark` 11 pt semibold, BBTextSecondary, in a 28 pt circle `textSecondary@0.10`; hit area 44 × 44; stays fixed at AX sizes (a secondary action whose hit area is already 44). VoiceOver label `weekly.a11y_hide` ("Hide until next week"). After the tap the card folds to the hidden line ⑫ (§ 4 S8) | 4.9 | 6.1 |
| ⑤ | glyph | 15 pt at default, **scaled with the label** (`@ScaledMetric(relativeTo: .callout)`); the expanded lines' indent is the glyph width + 8, so it scales too. Category tint (BBFeeding / BBSleep / BBGrowth). **Decorative**: the label names the figure, so the tint's 2.1:1 on white is not a P8 failure | — | — |
| ⑤ | label: value | label `Typography.callout` BBTextPrimary + value `Typography.metricSmall` BBTextPrimary, in one Text (`weekly.feeds_fmt` …). One line beside its delta where every row fits; else stacked: the text wraps between words, as many lines as the column needs, with the delta under it at the label's start, 2 apart (§ 4 Fit). No shrink, so the card's type is one size. Gain is a rate: "+210 g/week", the same unit as Growth's velocity | 14.3 | 14.1 |
| ⑥ | delta | `arrow.up` / `arrow.down` 10 pt, **scales with caption** (`@ScaledMetric(relativeTo: .caption)`, so at AX2 it keeps pace with its number) + number, `Typography.caption` mono digits, **BBTextSecondary — never green or red** (P1). At the trailing edge where every row fits, else under the value at the label's start, 2 apart (§ 4 Fit). Equal values: no delta. The gain row has no delta; its week before is in the expanded view. VoiceOver speaks the direction in words (`weekly.a11y_delta_up_fmt` / `_down_fmt`): the arrow is the only carrier of direction, so without words it fails WCAG 1.1.1. No visible word beside it: none fits at Large on 320 pt (§ 4 Fit); the legend ⑪ says it once | 4.9 | 6.1 |
| ⑦ | days line `weekly.days_logged_fmt` | "Averages over the days with entries: N of 7" / «Среднее по дням с записями: N из 7» / «Promedio de los días con registros: N de 7», the count glued to its "of 7". `Typography.caption`, BBTextSecondary, wraps. **On every week**, "7 of 7" included (decided 2026-11-04). It says what the rows' "a day" means, so the row labels keep their words | 4.9 | 6.1 |
| ⑪ | legend `weekly.legend` (decided 2026-11-04) | "Arrows show the change from the week before." / «Стрелки показывают, на сколько больше или меньше, чем неделей раньше.» / "Las flechas muestran el cambio respecto a la semana anterior." `Typography.caption`, BBTextSecondary, wraps: at Large en 279.0 pt (one line from 375 pt, two on 320), ru 470.8 and es 369.1 (two lines on 402; es one on 440). In S1 when the feeds or sleep delta shows, in the place where S2 puts `weekly.first_week`: sm 8 under the rows, above ⑦, sm 8 apart. **Hidden from VoiceOver**: every delta already speaks its direction and the week it compares with | 4.9 | 6.1 |

## 3. Expanded (tap on the header row)

```
┌───────────────────────────────────────────────────────┐
│ Last week                                   (⌃)  (×)  │
│ Oct 20 – 26                                           │
│                                                       │
│ ♥  Feeds a day: 7.4                         ↑ 0.6     │
│    week before: 6.8                                   │  ⑧ previous line
│    ▂ ▅ ▃ ▆ ▄ ▇ ░                                      │  ⑨ mini bars Mon…Sun (░ = day without entries)
│    M T W T F S S                                      │
│                                                       │
│ ☾  Sleep a day: 14 h 20 min                 ↓ 25 min  │
│    week before: 14 h 45 min                           │
│    ▅ ▅ ▆ ▄ ▅ ▆ ▅                                      │
│    Longest sleep: 5 h 10 min                          │  ⑩ "what changed"
│                                                       │
│ ⚖  Weight gain: +210 g/week                           │
│    week before: +190 g/week                           │
│                                                       │
│ Arrows show the change from the week before.          │
│ Averages over the days with entries: 6 of 7           │
└───────────────────────────────────────────────────────┘
```

Where the rows stack (§ 4 Fit), each delta sits under its value and the expanded lines follow it, at the same indent.

| # | element | spec | light | dark |
|---|---|---|---|---|
| ⑧ | `weekly.previous_fmt` | `Typography.caption`, BBTextSecondary, indented to the label | 4.9 | 6.1 |
| ⑨ | mini bars | 7 bars, 6 pt wide, 4 pt gap, max 28 pt tall, radius 2, **BBPrimary**; a day without entries is a 2 pt stub in `primary@0.15`; **a day before the birth date is absent** (no stub: nothing was missed); day letters `caption` BBTextSecondary. BBPrimary rather than the tint because the bars carry data (P8 non-text ≥ 3:1; tints are 2.1 on white). Values are printed above, so the bars are support, not the only cue | 5.6 | 6.2 |
| ⑩ | `weekly.longest_sleep_fmt` | `Typography.caption`, BBTextSecondary | 4.9 | 6.1 |

## 4. States

| # | state | what changes |
|---|---|---|
| S1 | normal week, previous week present | as §§ 2–3 |
| S2 | **first week** (no previous week with entries) | no deltas ⑥, no previous lines ⑧, no legend ⑪; one line `weekly.first_week` under the rows (`caption`, BBTextSecondary, wraps) |
| S3 | **partial week** (born or installed mid-week) | averages over days with entries + ⑦ "… 4 of 7"; bars: days before the birth date are absent, not stubs. An install mid-week cannot be told from a gap, so those days are stubs (as S4) |
| S4 | **week with gaps** | as S3: ⑦ shows N of 7; the gap days are stubs in ⑨ |
| S5 | **newborn window** | gain row: no number, no delta, no previous line — the glyph + `weekly.gain_newborn` in `callout` BBTextSecondary (calm: no ⚠, no tint change) |
| S6 | **no weighing pair** in the week | gain row: the glyph + one line in `callout` BBTextSecondary (wraps; as S5), and in three of the four cases a text button `growth.add_weighing` ("Add a weighing", existing key) under it, BBPrimary `callout` semibold, min 44 high, indented to the line, the two 2 apart; it opens AddGrowthSheet. Four cases (decided 2026-11-04), judged on every weighing up to now, in this order, after the newborn window S5: **(c)** a pair whose later weighing falls after the week → `weekly.gain_next_monday`, **no button** (the parent has weighed; a button would invite a duplicate); **(d)** else a pair whose later weighing falls before the week → `weekly.gain_needs_weighing`, button; **(b)** else weighings with no pair at least 3 days apart → `weekly.gain_needs_second`, button; **(a)** else no weighing at all → `weekly.gain_needs_two`, button. The button stays wherever the next step is a weighing. One exception to (c): a pair that ends after the week but still inside the newborn window takes (d) with the button, because next Monday's card withholds that gain too, so the next step is a weighing |
| S7 | **nothing logged last week** | no card (and no notification) |
| S8 | hidden by × | the card cross-fades (0.2 s) to the hidden line ⑫ in its place, which says the summary is hidden until next Monday and offers to bring it back; gone until next Monday after that |
| — | **a new week** | each week's card opens collapsed: the open state belongs to the week it was opened on. A card left expanded, or expanded and then hidden, in an app kept alive across Monday 00:00 shows the new week collapsed, as a Monday notification tap expects. In code at 3e4044a: the open state is kept under the week's Monday, so a new week finds the card closed |
| — | light / dark | tokens only, values in the tables |
| — | **AX2** | at `dynamicTypeSize >= .accessibility1` every row stacks: the label and value are one text that wraps between words as the column needs (ru «Прибавка веса: / +210 г/нед» on two lines at AX1 on 402), the delta under it at the label's start, 2 apart. Glyphs ⑤ and the chevron ③ scale with their text; × keeps its 28 pt circle; all keep 44 pt hits; bars keep their size (not text). A long value may wrap between its parts ("8 ч / 30 мин"); a number never leaves its unit (`DurationText` glues each number to its unit and keeps the space between the parts). Below AX1 the same stacked shape by fit (Fit below) |
| — | **iPad 13"** | the card spans the Dashboard column; the rows keep a max width of 480 pt, leading-aligned, so the delta does not drift 700 pt from its value |

### Fit on narrow screens (measured 2026-11-04 at a8369f8, CoreText, at Large)

The column is the screen less 64 pt (the Dashboard's md 16 margins and the card's md 16 padding): 256 pt on 320. A one-line row needs its glyph, 8, the label and value, 16 (8 on each side of the `Spacer`) and its delta. Sample values: feeds 12.5 with a 2.5 delta; sleep 14 h 20 min with a 25 min or 1 h 45 min delta; gain +350.

| row at Large | en | ru | es |
|---|---|---|---|
| feeds, one line on 320 | +49.5 | −1.4 | +47.1 |
| sleep with 25 min, one line on 320 | −23.8 | −35.7 | −28.0 |
| sleep with 1 h 45 min, on 320 / 375 / 402 | −46.1 / +8.9 / +35.9 | −57.7 / −2.7 / +24.3 | −50.4 / +4.6 / +31.6 |
| gain, one line on 320 (no delta) | +36.9 | +22.3 | +4.8 |
| stacked on 320: the label and value line / the delta line | +45.6 to +98.0 / +151.8 or more | +22.3 to +47.2 / +151.8 or more | +4.8 to +95.7 / +154.3 or more |

- Before 0334779 every row below AX1 was one line with `lineLimit(1)` and `minimumScaleFactor(0.85)`. On 320 the sleep row shrank below its 0.85 floor in ru (0.82) and with a delta of an hour or more in every language (0.75 en), and so was cut with "…"; ru feeds shrank to 0.99. This matched the copy's own measure within 2 pt.
- **In code (decided 2026-11-04, 0334779): the three rows take one shape together, by fit.** One line each while every shown row fits its column at full size (`ViewThatFits`); otherwise every row stacks as at accessibility sizes: the label and value text, wrapping between words where it must, the delta under it at the label's start, 2 apart. No shrink. The deltas are one column; a fit per row would set one at the edge and the next under its value. The lines that wrap anyway (the gain notes, the legend, the days line) are kept out of the fit, so only the value rows decide it. At Large: 320 stacks in all three languages; en and es take one line from 375, ru from 402 (on 375 ru takes one line in a week whose sleep delta is under an hour, +19.3). The cost on 320 is one caption line per row with a delta.
- No visible word beside the delta fits at Large on 320: the shortest, "↓ 25 min vs the week before", is 168.6 pt and leaves 44 pt for a label and value that need 131 to 193; ru «на 25 мин меньше, чем неделей раньше» (261.1) is wider than the column. So the comparison is said once, by the legend ⑪.
- Not taken: the delta under the value on every phone (a line more per row where one fits); a fit per row (the deltas' column breaks); shorter labels or units (the full-word rule), or "average" in the labels (the days line ⑦ carries it).

### The hidden line ⑫ (decided 2026-11-04, in code at 7070300)

```
┌──────────────────────────────────┐
│ The weekly summary is hidden     │   the text over the button on
│ until next Monday.               │   every phone; one line where
│ Undo                             │   both fit (iPad)
└──────────────────────────────────┘
```

- **Surface:** `WeeklyHiddenLine`, on the card's own `bbCard()` (surface, padding md 16), in the card's place. On the bare background BBTextSecondary is 4.48 in light, under AA for 16 pt regular; on the surface it is 4.9 / 6.1.
- **Text:** `weekly.hidden` — "The weekly summary is hidden until next Monday." / «Недельная сводка скрыта до следующего понедельника.» / "El resumen semanal está oculto hasta el próximo lunes." `Typography.callout`, BBTextSecondary, wraps.
- **Button:** `weekly.undo` — "Undo" / «Вернуть» / "Deshacer". A text button, `Typography.scaled(16, relativeTo: .callout, weight: .semibold)`, BBPrimary, in a frame at least 44 × 44, its word at the frame's leading edge and the whole frame the hit area («Undo» alone is 40 pt wide). It brings the week back, collapsed, with the same 0.2 s fade, none with Reduce Motion.
- **Shape by fit:** below accessibility sizes, the text, a `Spacer` of at least 16 and the button on one line (first baseline) while both fit, else the text over the button, both leading, their frames 2 apart, as S6: the word's line sits 14.6 pt under the text's last line, about 12 pt of visible space, because the 44 pt frame centres it. Always stacked at accessibility sizes. One line needs at Large en 408.9 pt (the sentence 348.9), ru 505.9, es 473.2, against 376 on 440: it stacks at every phone width and takes one line only where the column is wider (iPad). In the 402 en tree the text is [32,208]–[286,246] and the button [32,248]–[76,292].
- **How long:** while the Dashboard stays on screen. It is gone when the Dashboard disappears (another tab) or the app goes to the background. No timer, so a slow reader or VoiceOver never misses it (WCAG 2.2.1). The card comes back next Monday in any case.
- **VoiceOver:** when the card folds, focus moves to the line's text (250 ms after the swap), then to the button; after the button brings the card back, focus moves to the card's header.
- Not taken: a confirmation before hiding (a step every week for an act undone in one tap; the platform confirms what cannot be undone); a toast with an undo (it leaves on a timer, and the app has none); the line on the bare background (contrast, above).

## 5. Motion

- Expand / collapse: `easeInOut(0.25)` on height plus chevron rotation (the existing reveal curve). With **Reduce Motion** on, the rows appear in place with no animation; a cross-fade is optional. This is the first shared-surface use of Reduce Motion (G13).
- Hide (×): the card cross-fades to the hidden line ⑫ in 0.2 s (`easeInOut`), and its button brings the card back the same way. With **Reduce Motion**, both swap with no animation, the same as expand.
- Values do not count up or animate: a summary is read, not performed.

## 6. What the copy and the build need

**Copy:**
- Collapsed card = title + range + **three value rows** (feeds, sleep, gain) + the days line on every week + the first-week line in S2, or in S1 the legend ⑪. Expanded adds the previous lines, bars and "Longest sleep".
- Value rows: **label and value on one line beside the delta where every row fits.** At Large that holds from 375 pt in en and es and from 402 pt in ru; on 320 pt the sleep row does not fit beside its delta in any language (§ 4 Fit), so there the rows stack, as they do at accessibility sizes. The labels keep their words: no shorter variants, and "average" is in the days line, not the labels.
- New string: `weekly.a11y_hide` ("Hide until next week"). The add-weighing action reuses `growth.add_weighing`.
- From the review: a VoiceOver delta per direction (⑥); an hours-only duration for whole hours ("1 ч", not "1 ч 0 мин"); a no-break space between a number and its unit in the gain value.
- From 2026-11-04: the legend sentence `weekly.legend` ⑪; the hidden line's sentence `weekly.hidden` and its undo word `weekly.undo` ⑫; the four gain lines `weekly.gain_next_monday`, `weekly.gain_needs_weighing`, `weekly.gain_needs_second`, `weekly.gain_needs_two` (S6).
- String keys (24): `weekly.title`, `range_fmt`, `feeds_fmt`, `sleep_fmt`, `gain_fmt`, `previous_fmt`, `longest_sleep_fmt`, `days_logged_fmt`, `first_week`, `legend`, `gain_newborn`, `gain_next_monday`, `gain_needs_weighing`, `gain_needs_second`, `gain_needs_two`, `a11y_expand`, `a11y_collapse`, `a11y_expanded`, `a11y_collapsed`, `a11y_hide`, `a11y_delta_up_fmt`, `a11y_delta_down_fmt`, `hidden`, `undo`.

**Build:**
- Figures: per-day averages over days with entries, N of 7; previous week computed the same way; gain from the weighings of the week (none in the newborn window); longest sleep.
- The days line ⑦ on every week.
- Hidden state per calendar week (× until next Monday), local is enough. The hidden line ⑫ lasts for one Dashboard visit and is not stored.
- The rows' one shape by fit (§ 4 Fit), without `minimumScaleFactor`; the legend ⑪ hidden from VoiceOver.
- The notification tap opens the Dashboard with the card **collapsed** (2026-10-29). The collapsed card already shows the three figures the notification speaks of. Opening it expanded waits for notification tap handling, in the backlog.
- Each week's card opens collapsed (§ 4, a new week): the open state is kept under the week's Monday, so it resets when the week changes. In code at 3e4044a.
- Renders for the design review: S1–S6 light/dark, default and AX2, iPhone 17 and iPad 13"; from 2026-11-04 also 320 pt at Large (one row stacked) and S8's hidden line.

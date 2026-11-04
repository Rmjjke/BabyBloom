# M1 — Weekly summary card on the Dashboard (design note)

status: final, 2026-10-28; corrected after the design review 2026-10-30 (notification tap lands collapsed, range per locale, gain as a rate, glyphs scale with the text, × and Reduce Motion, days before birth); § 2 ⑥ the delta arrow scales with caption, after the live AX2 look of #85, 2026-11-01 (main 1fc4848 via #86); 2026-11-04: the days line ⑦ shows on every week and says the rows are averages, and the gain line without a number has four cases, one without the button (S6) (both decided), the rows' fit on 320 pt is measured (§ 4 Fit), and the rows' one shape by fit, a legend line for the arrows ⑪ and a hidden line after × ⑫ are proposed
decisions: a Dashboard card at the top once a week that expands on tap, because everyone who opens the app sees it and it is quicker to build; calendar week Mon–Sun and a calm notification on Monday morning outside quiet hours, a reason to come back; free, because the summary is about retention and is already bounded by the 15-day free history window; WCAG 2.2 AA; no gain number in the newborn window, because a −180 g in week one is normal but reads as a verdict (DECISIONS 2026-09-05); stays Mon–Sun, × hides until next week; averages over days with entries + "N of 7", because a forgotten day is not "the baby slept less"; neutral deltas; a notification tap lands collapsed (2026-10-29); the days line on every week, worded as averages, because no row label with "average" fits beside its delta on 320 pt and a full week said "a day" with nothing beside it (2026-11-04)
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
│ Arrows show the change from the week before.          │  ⑪ legend (proposed; S2: the first-week line)
│ Averages over the days with entries: 6 of 7           │  ⑦ every week
└───────────────────────────────────────────────────────┘
   padding md 16 · rows sm 8 apart · header to rows md 16
```

Where one row does not fit (320 pt at Large in every language; proposed, § 4 Fit):

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

The legend's words above are a placeholder; the copy writes them.

| # | element | spec | light | dark |
|---|---|---|---|---|
| ① | title `weekly.title` | `Typography.title3`, BBTextPrimary | 14.3 | 14.1 |
| ② | range `weekly.range_fmt` | `Typography.caption`, BBTextSecondary. The month is written once, on the side the language puts it: "Oct 19 – 25", «19 – 25 окт.», "19 – 25 oct". Across months both ends carry theirs: "Sep 28 – Oct 4" | 4.9 | 6.1 |
| ③ | chevron | `chevron.down` 13 pt semibold **scaled with the title** (`@ScaledMetric(relativeTo: .title3)`), BBPrimary; rotates 180° when expanded. It is the only visible sign that the header expands, so it grows with the text. The **whole header row** is the expand button, min 44 high, VoiceOver `weekly.a11y_expand` / `_collapse` | 5.6 | 6.2 |
| ④ | × hide | `xmark` 11 pt semibold, BBTextSecondary, in a 28 pt circle `textSecondary@0.10`; hit area 44 × 44; stays fixed at AX sizes (a secondary action whose hit area is already 44). VoiceOver label `weekly.a11y_hide` ("Hide until next week"). After the tap the card folds to the hidden line ⑫ (proposed, § 4 S8) | 4.9 | 6.1 |
| ⑤ | glyph | 15 pt at default, **scaled with the label** (`@ScaledMetric(relativeTo: .callout)`); the expanded lines' indent is the glyph width + 8, so it scales too. Category tint (BBFeeding / BBSleep / BBGrowth). **Decorative**: the label names the figure, so the tint's 2.1:1 on white is not a P8 failure | — | — |
| ⑤ | label: value | label `Typography.callout` BBTextPrimary + value `Typography.metricSmall` BBTextPrimary, in one Text (`weekly.feeds_fmt` …), 1 line beside its delta where every row fits, else stacked (§ 4 Fit). Proposed: no shrink (today `minimumScaleFactor(0.85)`), so the card's type is one size. Gain is a rate: "+210 g/week", the same unit as Growth's velocity | 14.3 | 14.1 |
| ⑥ | delta | `arrow.up` / `arrow.down` 10 pt, **scales with caption** (`@ScaledMetric(relativeTo: .caption)`, so at AX2 it keeps pace with its number) + number, `Typography.caption` mono digits, **BBTextSecondary — never green or red** (P1). At the trailing edge where every row fits, else under the value at the label's start, 2 apart (§ 4 Fit). Equal values: no delta. The gain row has no delta; its week before is in the expanded view. VoiceOver speaks the direction in words (`weekly.a11y_delta_up_fmt` / `_down_fmt`): the arrow is the only carrier of direction, so without words it fails WCAG 1.1.1. No visible word beside it: none fits at Large on 320 pt (§ 4 Fit); the legend ⑪ says it once | 4.9 | 6.1 |
| ⑦ | days line `weekly.days_logged_fmt` | "Averages over the days with entries: N of 7" / «Среднее по дням с записями: N из 7» / «Promedio de los días con registros: N de 7», the count glued to its "of 7". `Typography.caption`, BBTextSecondary, wraps. **On every week**, "7 of 7" included (decided 2026-11-04; until that build only when N < 7). It says what the rows' "a day" means, so the row labels keep their words | 4.9 | 6.1 |
| ⑪ | legend (proposed, 2026-11-04) | one sentence: the arrows compare with the week before (a new key; the copy writes it). `Typography.caption`, BBTextSecondary, wraps. In S1 when at least one delta shows, in the place where S2 puts `weekly.first_week`, above ⑦. **Hidden from VoiceOver**: every delta already speaks its direction and the week it compares with | 4.9 | 6.1 |

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
| S6 | **no weighing pair** in the week | gain row: the glyph + one line in `callout` BBTextSecondary (wraps; as S5), and in three of the four cases a text button `growth.add_weighing` ("Add a weighing", existing key) under it, BBPrimary `callout` semibold, min 44 high, opens AddGrowthSheet. Four cases (decided 2026-11-04), judged on every weighing up to now, in this order, after the newborn window S5: **(c)** a pair whose later weighing falls after the week → `weekly.gain_next_monday`, **no button** (the parent has weighed; a button would invite a duplicate); **(d)** else a pair whose later weighing falls before the week → `weekly.gain_needs_weighing`, button; **(b)** else weighings with no pair at least 3 days apart → `weekly.gain_needs_second`, button; **(a)** else no weighing at all → `weekly.gain_needs_two`, button. The button stays wherever the next step is a weighing. Until that build the card knows weighings up to the week's end only and always shows (d) |
| S7 | **nothing logged last week** | no card (and no notification) |
| S8 | hidden by × | gone until next Monday. Today it fades out (opacity, 0.2 s) and the rows below close up, with nothing said. **Proposed (2026-11-04, not decided):** the card folds to the hidden line ⑫ in its place, which says the summary is hidden and comes back on Monday and offers to bring it back |
| — | light / dark | tokens only, values in the tables |
| — | **AX2** | at `dynamicTypeSize >= .accessibility1` each row stacks: label line, value line, delta under the value. Glyphs ⑤ and the chevron ③ scale with their text; × keeps its 28 pt circle; all keep 44 pt hits; bars keep their size (not text). A long value may wrap between its parts ("8 ч / 30 мин"); a number never leaves its unit. Below AX1 the same stacked shape by fit (proposed, Fit below) |
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

- Today every row below AX1 is one line with `lineLimit(1)` and `minimumScaleFactor(0.85)`. On 320 the sleep row shrinks below its 0.85 floor in ru (0.82) and with a delta of an hour or more in every language (0.75 en), and so is cut with "…"; ru feeds shrinks to 0.99. This matches the copy's own measure within 2 pt.
- **Proposed (2026-11-04, not decided): the three rows take one shape together, by fit.** One line each while every shown row fits its column at full size; otherwise every row stacks as at accessibility sizes: the label and value line, the delta under it at the label's start, 2 apart. No shrink. The deltas are one column; a fit per row would set one at the edge and the next under its value. At Large: 320 stacks in all three languages; en and es take one line from 375, ru from 402 (on 375 ru takes one line in a week whose sleep delta is under an hour, +19.3). The cost on 320 is one caption line per row with a delta.
- No visible word beside the delta fits at Large on 320: the shortest, "↓ 25 min vs the week before", is 168.6 pt and leaves 44 pt for a label and value that need 131 to 193; ru «на 25 мин меньше, чем неделей раньше» (261.1) is wider than the column. So the comparison is said once, by the legend ⑪.
- Not taken: the delta under the value on every phone (a line more per row where one fits); a fit per row (the deltas' column breaks); shorter labels or units (the full-word rule), or "average" in the labels (the days line ⑦ carries it).

### The hidden line ⑫ (proposed, 2026-11-04, not decided)

```
┌──────────────────────────────────┐
│ Last week is hidden until        │   one line where text and button fit,
│ Monday.                          │   else the text over the button
│ Undo                             │
└──────────────────────────────────┘
```

- **Surface:** the card's own `bbCard()` (surface, padding md 16), in the card's place. On the bare background BBTextSecondary is 4.48 in light, under AA for 16 pt regular; on the surface it is 4.9 / 6.1.
- **Text:** `Typography.callout`, BBTextSecondary, wraps: that the summary is hidden and comes back on Monday (a new key; the copy writes it).
- **Button:** a text button, `Typography.scaled(16, relativeTo: .callout, weight: .semibold)`, BBPrimary, min 44 high, as S6's «Add a weighing»; its word is an undo (the copy writes it). It brings the week back, collapsed, with the same 0.2 s fade, none with Reduce Motion.
- **Shape by fit:** the text, a `Spacer` of at least 16 and the button on one line (first baseline) while both fit, else the text over the button, both leading, 2 apart, as S6. Always stacked at accessibility sizes. On 320 at Large it stacks in all three languages (placeholder words: en 289.7 pt in 256).
- **How long:** while the Dashboard stays on screen. It is gone the next time the Dashboard appears (another tab, the app back from the background). No timer, so a slow reader or VoiceOver never misses it (WCAG 2.2.1). The card comes back next Monday in any case.
- **VoiceOver:** when the card folds, focus moves to the line's text, then to the button; after the button brings the card back, focus moves to the card's header.
- Not taken: a confirmation before hiding (a step every week for an act undone in one tap; the platform confirms what cannot be undone); a toast with an undo (it leaves on a timer, and the app has none); the line on the bare background (contrast, above).

## 5. Motion

- Expand / collapse: `easeInOut(0.25)` on height plus chevron rotation (the existing reveal curve). With **Reduce Motion** on, the rows appear in place with no animation; a cross-fade is optional. This is the first shared-surface use of Reduce Motion (G13).
- Hide (×): opacity 0.2 s, then the layout closes. With **Reduce Motion**, the card goes with no animation, the same as expand. Proposed: the card cross-fades to the hidden line ⑫ in the same 0.2 s, and its button brings the card back the same way.
- Values do not count up or animate: a summary is read, not performed.

## 6. What the copy and the build need

**Copy:**
- Collapsed card = title + range + **three value rows** (feeds, sleep, gain) + the days line on every week (decided 2026-11-04) + the first-week line in S2, or in S1 the legend ⑪ (proposed). Expanded adds the previous lines, bars and "Longest sleep".
- Value rows: **label and value on one line beside the delta where every row fits.** At Large that holds from 375 pt in en and es and from 402 pt in ru; on 320 pt the sleep row does not fit beside its delta in any language (§ 4 Fit), so there the rows stack (proposed), as they do at accessibility sizes. The labels keep their words: no shorter variants, and "average" is in the days line, not the labels.
- New string: `weekly.a11y_hide` ("Hide until next week"). The add-weighing action reuses `growth.add_weighing`.
- From the review: a VoiceOver delta per direction (⑥); an hours-only duration for whole hours ("1 ч", not "1 ч 0 мин"); a no-break space between a number and its unit in the gain value.
- Proposed (2026-11-04): the legend sentence ⑪ (one key); the hidden line's sentence and its undo word ⑫ (one key each, or an existing word if one says it).

**Build:**
- Figures: per-day averages over days with entries, N of 7; previous week computed the same way; gain from the weighings of the week (none in the newborn window); longest sleep.
- The days line ⑦ on every week (decided 2026-11-04).
- Hidden state per calendar week (× until next Monday), local is enough. Proposed: the hidden line ⑫ lasts for one Dashboard visit and is not stored.
- Proposed: the rows' one shape by fit (§ 4 Fit), without `minimumScaleFactor`; the legend ⑪ hidden from VoiceOver.
- The notification tap opens the Dashboard with the card **collapsed** (2026-10-29). The collapsed card already shows the three figures the notification speaks of. Opening it expanded waits for notification tap handling, in the backlog.
- Renders for the design review: S1–S6 light/dark, default and AX2, iPhone 17 and iPad 13"; from 2026-11-04 also 320 pt at Large (one row stacked) and S8's hidden line.

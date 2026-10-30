# M1 — Weekly summary card on the Dashboard (design note)

status: final — card `m1-weekly-design`, 2026-10-28; corrected after the design review of `weekly-summary` 2026-10-30 (notification tap lands collapsed, range per locale, gain as a rate, glyphs scale with the text, × and Reduce Motion, days before birth)
decisions: D8 (Dashboard card, expands on tap), D9 (Mon–Sun + Monday notification), D10 (free), D14 (WCAG 2.2 AA), D17 (no gain number in the newborn window), D18 (stays Mon–Sun, × hides until next week), D19 (averages over days with entries + "N of 7"); plan v2 review: neutral deltas; Manager 2026-10-29: a notification tap lands collapsed
reference: `teamdocs/design/design-system.md` (P = principle, G = gap); strings: Content's review `m1-weekly-copy`; review: `.team/desk/tasks/m1-design-review-weekly/docs/review.md`
triggers: a figure added to or removed from the card; a state added; D17–D19 changed
check: `grep -c '"weekly\.' BabyBloom/Resources/Localization/en.json` vs the string keys in § 6

Drawn by hand (`ios: none`). Sizes were targets; the review of `weekly-summary` checked them on renders and live.

## 1. Place and surface

- **Dashboard order:** header → running timers (if any) → **weekly card** → Quick input → … A running timer outranks the summary at 3 a.m. Otherwise the card is the first thing under the header (D8 "at the top").
- **Shown** from Monday 00:00 to Sunday 23:59 for the calendar week before (D9, D18). Hidden by × until the next Monday. Not shown when last week holds no entries.
- **Surface:** elevated `bbCard()` (surface, radius md, `card` shadow, top highlight). It is the first real caller of `bbCard()`, which partly closes G9.
- **Type:** named `BBTheme.Typography` styles and `Typography.scaled` only (G2 not repeated); drawn at default size and AX2.

## 2. Collapsed

```
┌───────────────────────────────────────────────────────┐
│ Last week                                   (⌄)  (×)  │  ① title3 · ② range caption · ③ chevron · ④ ×
│ Oct 20 – 26                                           │
│                                                       │
│ ♥  Feeds a day: 7.4                         ↑ 0.6     │  ⑤ value rows (label: value) · ⑥ delta
│ ☾  Sleep a day: 14 h 20 min                 ↓ 25 min  │
│ ⚖  Weight gain: +210 g/week                           │
│                                                       │
│ Days with entries: 6 of 7                             │  ⑦ only when N < 7 (D19)
└───────────────────────────────────────────────────────┘
   padding md 16 · rows sm 8 apart · header to rows md 16
```

| # | element | spec | light | dark |
|---|---|---|---|---|
| ① | title `weekly.title` | `Typography.title3`, BBTextPrimary | 14.3 | 14.1 |
| ② | range `weekly.range_fmt` | `Typography.caption`, BBTextSecondary. The month is written once, on the side the language puts it: "Oct 19 – 25", «19 – 25 окт.», "19 – 25 oct". Across months both ends carry theirs: "Sep 28 – Oct 4" | 4.9 | 6.1 |
| ③ | chevron | `chevron.down` 13 pt semibold **scaled with the title** (`@ScaledMetric(relativeTo: .title3)`), BBPrimary; rotates 180° when expanded. It is the only visible sign that the header expands, so it grows with the text. The **whole header row** is the expand button, min 44 high, VoiceOver `weekly.a11y_expand` / `_collapse` | 5.6 | 6.2 |
| ④ | × hide | `xmark` 11 pt semibold, BBTextSecondary, in a 28 pt circle `textSecondary@0.10`; hit area 44 × 44; stays fixed at AX sizes (a secondary action whose hit area is already 44). VoiceOver label `weekly.a11y_hide` ("Hide until next week") | 4.9 | 6.1 |
| ⑤ | glyph | 15 pt at default, **scaled with the label** (`@ScaledMetric(relativeTo: .callout)`); the expanded lines' indent is the glyph width + 8, so it scales too. Category tint (BBFeeding / BBSleep / BBGrowth). **Decorative**: the label names the figure, so the tint's 2.1:1 on white is not a P8 failure | — | — |
| ⑤ | label: value | label `Typography.callout` BBTextPrimary + value `Typography.metricSmall` BBTextPrimary, in one Text (`weekly.feeds_fmt` …), 1 line at default size. Gain is a rate: "+210 g/week", the same unit as Growth's velocity | 14.3 | 14.1 |
| ⑥ | delta | `arrow.up` / `arrow.down` 10 pt + number, `Typography.caption` mono digits, **BBTextSecondary — never green or red** (P1, plan v2 review). Equal values: no delta. The gain row has no delta; its week before is in the expanded view. VoiceOver speaks the direction in words (`weekly.a11y_delta_more_fmt` / `_less_fmt`, Content): the arrow is the only carrier of direction, so without words it fails WCAG 1.1.1 | 4.9 | 6.1 |
| ⑦ | days line `weekly.days_logged_fmt` | `Typography.caption`, BBTextSecondary | 4.9 | 6.1 |

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
│    Longest sleep: 5 h 10 min                          │  ⑩ "what changed" (Content's line)
│                                                       │
│ ⚖  Weight gain: +210 g/week                           │
│    week before: +190 g/week                           │
│                                                       │
│ Days with entries: 6 of 7                             │
└───────────────────────────────────────────────────────┘
```

| # | element | spec | light | dark |
|---|---|---|---|---|
| ⑧ | `weekly.previous_fmt` | `Typography.caption`, BBTextSecondary, indented to the label | 4.9 | 6.1 |
| ⑨ | mini bars | 7 bars, 6 pt wide, 4 pt gap, max 28 pt tall, radius 2, **BBPrimary**; a day without entries is a 2 pt stub in `primary@0.15`; **a day before the birth date is absent** (no stub: nothing was missed); day letters `caption` BBTextSecondary. BBPrimary rather than the tint because the bars carry data (P8 non-text ≥ 3:1; tints are 2.1 on white). Values are printed above, so the bars are support, not the only cue | 5.6 | 6.2 |
| ⑩ | `weekly.longest_sleep_fmt` | `Typography.caption`, BBTextSecondary | 4.9 | 6.1 |

## 4. States

| # | state | what changes |
|---|---|---|
| S1 | normal week, previous week present | as §§ 2–3 |
| S2 | **first week** (no previous week with entries) | no deltas ⑥, no previous lines ⑧; one line `weekly.first_week` under the rows (`caption`, BBTextSecondary, wraps) |
| S3 | **partial week** (born or installed mid-week) | averages over days with entries (D19) + ⑦ "Days with entries: 4 of 7"; bars: days before the birth date are absent, not stubs. An install mid-week cannot be told from a gap, so those days are stubs (as S4) |
| S4 | **week with gaps** | as S3: ⑦ shows N of 7; the gap days are stubs in ⑨ |
| S5 | **newborn window** (D17) | gain row: no number, no delta, no previous line — the glyph + `weekly.gain_newborn` in `callout` BBTextSecondary (calm: no ⚠, no tint change) |
| S6 | **no weighing pair** in the week | gain row: `weekly.gain_needs_weighing` + a text button `growth.add_weighing` ("Add a weighing", existing key), BBPrimary `callout` semibold, min 44 high, opens AddGrowthSheet |
| S7 | **nothing logged last week** | no card (and, per Content Q7, no notification) |
| S8 | hidden by × | gone until next Monday; it fades out (opacity, 0.2 s) and the rows below close up |
| — | light / dark | tokens only, values in the tables |
| — | **AX2** | at `dynamicTypeSize >= .accessibility1` each row stacks: label line, value line, delta under the value. Glyphs ⑤ and the chevron ③ scale with their text; × keeps its 28 pt circle; all keep 44 pt hits; bars keep their size (not text). A long value may wrap between its parts ("8 ч / 30 мин"); a number never leaves its unit |
| — | **iPad 13"** | the card spans the Dashboard column; the rows keep a max width of 480 pt, leading-aligned, so the delta does not drift 700 pt from its value |

## 5. Motion

- Expand / collapse: `easeInOut(0.25)` on height plus chevron rotation (the existing reveal curve). With **Reduce Motion** on, the rows appear in place with no animation; a cross-fade is optional. This is the first shared-surface use of Reduce Motion (G13).
- Hide (×): opacity 0.2 s, then the layout closes. With **Reduce Motion**, the card goes with no animation, the same as expand.
- Values do not count up or animate: a summary is read, not performed.

## 6. What Content and Dev need

**Content** (answers to Content's two questions):
- Collapsed card = title + range + **three value rows** (feeds, sleep, gain) + the days line when N < 7 + the first-week line in S2. Expanded adds the previous lines, bars and "Longest sleep".
- Value rows: **label and value on one line at default size.** Content's longest are 21–25 characters plus a delta, which fits an iPhone 17 card. At accessibility sizes they stack (§ 4), so no shorter variants are needed.
- New string: `weekly.a11y_hide` ("Hide until next week"). The add-weighing action reuses `growth.add_weighing`.
- From the review: a VoiceOver delta per direction (⑥); an hours-only duration for whole hours ("1 ч", not "1 ч 0 мин"); a no-break space between a number and its unit in the gain value.

**Dev** (`weekly-summary`):
- Figures: per-day averages over days with entries (D19), N of 7; previous week computed the same way; gain from the weighings of the week (none in the newborn window, D17); longest sleep.
- Hidden state per calendar week (× until next Monday), local is enough.
- The notification tap opens the Dashboard with the card **collapsed** (Manager, 2026-10-29). The collapsed card already shows the three figures the notification speaks of. Opening it expanded waits for the backlog card `notification-tap-handling`.
- Renders for the design review: S1–S6 light/dark, default and AX2, iPhone 17 and iPad 13".

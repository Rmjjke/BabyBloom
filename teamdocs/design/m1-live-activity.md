# M1 — Live Activity and widget controls (design note)

status: final — card `m1-lockscreen-design`, 2026-10-28; § 2 "Saved looks done" + stack order from `m1-saved-state-distinct` (CHECK 2) 2026-10-29; § 0 confirmed by the Dev Lead's § A5 answers 2026-10-29 (one correction: the bottle timer, D28); corrected after the design review of `live-activity-timers` 2026-10-29 (§ 1 Dynamic Type caps, § 3 two-line title and the long-state "…", bottle glyph); `widget-interactive` still to review
decisions: D5 (auto start, Settings switch), D6/D10 (free), D14 (WCAG 2.2 AA), D16 (widget control starts a feeding timer), D28 (formula/pumped feeds run as a timer → bottle state); plan v2 review round: BBOnPrimary, Lock Screen on BBSurface, design review before MERGE
reference: `teamdocs/design/design-system.md` (P = principle, G = gap); review: `.team/desk/tasks/m1-design-review-live-activity/docs/review.md`
triggers: a timer kind added; a Live Activity presentation or widget family added; a token in § 6 renamed; the stale/dismissal policy changed; a Dynamic Type cap changed
check: `grep -n 'case ' BabyBloom/Core/Models/SleepEntry.swift BabyBloom/Core/Models/FeedingEntry.swift BabyBloom/Features/LiveActivity/TimerActivityAttributes.swift` vs § 0 kinds; `ls WidgetResources/Colors.xcassets` vs § 6 list; `grep -n 'dynamicTypeSize' BabyBloom/Features/LiveActivity/TimerActivityViews.swift` vs § 1 caps

Drawn by hand (no design tools, `ios: none`): annotated layouts plus spec
tables. Sizes are targets to verify on the first render, not pixel promises.

## 0. What the code says (confirmed by the Dev Lead, 2026-10-29)

| fact | source | consequence |
|---|---|---|
| A **breastfeed** runs as a timer (quick start), and so does a **formula or pumped** feed: the add-feeding sheet's "Start timer" works for every type (D28) | `FeedingView.quickStart`; `FeedingView` `form.start_timer` toggle outside the breast-only block, saved with `endTime == nil` | a **bottle state**: one title for both (`TimerTitle.bottle`), no side |
| Breast side is L / R / Both and **can change while the feed runs** | `FeedingView` side switcher in the running card | the title updates in place; no side control on the activity |
| Sleep is **nap** or **night** | `SleepEntry.SleepType` | two sleep titles, two glyphs |
| Feeding and sleep **can run together** | `DashboardView.activeTimersSection` | two activities at once |
| No pause in any timer | — | no paused state |
| `staleDate = start + 8 h`; the system draws the timer, so it never freezes | Dev's build | one "long" state (§ 2), no "frozen / open to update" state |
| A timer stopped on another device (CloudKit) ends the activity when the app comes to the foreground | Dev's build | no string, no state of its own |
| The Settings switch is hidden on iPad | Dev's build | no iPad wording |

Glyphs (the app's own): breastfeed `heart.fill`, bottle `drop.fill` (the formula glyph; formula and pumped share one title, so they share one glyph), nap `sun.max.fill`, night `moon.fill`, ended `checkmark.circle.fill`. Bottle states use the **BBFeeding** token for the disc and island tint, never the model's per-type hex (#B0C4F5 / #D4A8D5 — design-system G-list, P5).

## 1. Shared rules

- **Timer:** `Text(timerInterval: start...start + 24 h, countsDown: false)` with `.monospacedDigit()`. The system ticks it, so it needs no updates. Reads `14:32` under an hour and `1:23:45` after.
- **Type:** system text styles in the rounded design, so Dynamic Type follows the system. **Caps** (the system gives an activity about 160 pt of height and fixed Island regions; past these sizes the timer and Stop no longer fit): Lock Screen `...xxxLarge`, Dynamic Island `...xLarge`. Up to the cap the **title truncates (tail), never the timer** (`fixedSize` + higher `layoutPriority`); the Stop label shrinks down to 0.8, never truncates; the started line and the "continues in the app" line shrink down to 0.8 before they truncate, so the **start time is never cut** ("Inicio: 4:43 p.m." must not lose "p.m." at night).
- **Calm (P1):** no red, orange or triangle, at any duration. BBAlert and BBSuccess are not used. A 50-minute feed looks exactly like a 5-minute one, and an 8-hour one only loses its digits.
- **Contrast (P8):** every pair below was measured with the WCAG formula. Glyphs on light surfaces are BBPrimary, because category tints on white are 2.1:1 and the glyph's shape carries the kind.

## 2. Lock Screen (and StandBy)

```
┌────────────────────────────────────────────────────┐  background: BBSurface  (activityBackgroundTint)
│ (♥)  Breastfeeding · left                          │  ① disc 32 + title
│                                                    │
│ 14:32                               ┌───────────┐  │  ② timer          ③ Stop
│ Started 03:12                       │ ■  Stop   │  │  ④ secondary line
│                                     └───────────┘  │
└────────────────────────────────────────────────────┘  padding 16 · rows 8 apart
```

| # | element | spec | light | dark |
|---|---|---|---|---|
| ① | disc + glyph | 32 pt circle `tint@0.22` (BBFeeding / BBSleep) + glyph 15 pt **BBPrimary** | 5.6 | 6.2 |
| ① | title | `.headline` rounded semibold, BBTextPrimary, 1 line, truncates | 14.3 | 14.1 |
| ② | timer | `.largeTitle` rounded semibold mono (≈ 34–40 pt), BBTextPrimary | 14.3 | 14.1 |
| ③ | Stop | § 4 | 5.6 | 6.9 |
| ④ | "Started 03:12" | `.footnote` rounded, BBTextSecondary, 1 line, `minimumScaleFactor(0.8)` | 4.9 | 6.1 |

Kinds (① only; everything else is shared):

| kind | glyph | title |
|---|---|---|
| breastfeed L / R / Both | `heart.fill` | `live_activity.title.bf_*` ("Breastfeeding · left"); changes in place when the side changes |
| bottle — formula or pumped (D28) | `drop.fill` | `live_activity.title.bottle`; **no side** |
| nap / night | `sun.max.fill` / `moon.fill` | `live_activity.title.nap` / `.night` |

States:

| state | ① | ② | ③ | ④ |
|---|---|---|---|---|
| running | as above | live timer | Stop | `live_activity.started_fmt` |
| stopping (intent in flight) | — | — | system pressed dim; label stays, no spinner | — |
| ended (Stop tapped, in app or here) — **a quiet card, see "Saved looks done" below** | glyph → `checkmark.circle.fill` BBPrimary on a **neutral disc** `BBTextSecondary@0.12`; title in **BBTextSecondary** | replaced by `live_activity.saved_fmt` "Saved · 14 min", `.subheadline` rounded medium, BBTextSecondary — **no large text** | none | started line stays |
| long (`context.isStale`, start + 8 h; covers the system cut-off) | as running | **no digits** (the activity may soon be ended by the system, and a number left behind would lie) | Stop stays: the intent still ends the timer and writes the store | `live_activity.continues_in_app` "The timer goes on in Bitty", up to 2 lines, `minimumScaleFactor(0.8)`, BBTextSecondary; started line under it |
| two activities | the system stacks two banners, each as above | | | |

**Saved looks done** (CHECK 2 blind pass, 2026-10-29: "at 3 a.m. I can't tell at a glance whether it is still counting"). A running card and a saved card must differ in *weight*, not in a detail:

```
running                                              saved
┌──────────────────────────────────────────┐        ┌──────────────────────────────────────────┐
│ (♥)  Breastfeeding · left                │        │ (✓)  Breastfeeding · left                │  tinted disc, dark title   |  grey disc, grey title
│ 14:32                     ┌───────────┐  │        │ Saved · 14 min                           │  34–40 pt ticking number   |  one quiet line, no number
│ Started 03:12             │ ■  Stop   │  │        │ Started 03:12                            │  filled violet Stop        |  no button
└──────────────────────────────────────────┘        └──────────────────────────────────────────┘
```

- Three cues, each enough on its own: **no big number**, **no filled button**, **no colour** (neutral disc, all text BBTextSecondary). The saved card is also about a third shorter.
- Calm (P1): nothing red, no BBSuccess green, no opacity tricks. "Saved" stays readable: BBTextSecondary on BBSurface is 4.9 light / 6.1 dark (D14 text ≥ 4.5). The check glyph BBPrimary on the neutral disc is 4.8 / 5.1 (non-text ≥ 3).
- The Island is unchanged: an ended activity already leaves it (§ 3).

Dismissal after Stop: `.after(now + 15 min)` (built; owner-approved spec R2.4). Long enough to see "Saved" at a glance after settling the baby, short enough not to clutter the morning.

**Order in the stack.** iOS stacks a Saved card above a running one when the Saved card is newer (CHECK 2 By design? 3). The fix is order, not a shorter life:
- Set `relevanceScore` on every `ActivityContent`: running 100, ended 0. iOS shows the higher-relevance activity first on the Lock Screen and in the Island.
- The 15 minutes stay.
- Only if a hardware check still shows a Saved card above a running timer, the owner gets a proposal: end with `.immediate` when another Bitty timer is still running (15 min otherwise).

## 3. Dynamic Island (always on black — dark token values)

```
compact   (♥ ·············· camera ·············· 14:32)
minimal   (♥)
expanded  ┌──────────────────────────────────────────────┐
          │ (♥)                                    14:32 │  leading / trailing
          │ Кормление грудью ·               [ ■ Stop ]  │  bottom: title up to 2 lines
          │ левая                                        │
          └──────────────────────────────────────────────┘
```

| region | spec | contrast on black |
|---|---|---|
| compact leading | glyph `.body`, category tint (dark: BBFeeding #C98BA0 7.7, BBSleep #8A93CC 7.1) | ≥ 7.1 |
| compact trailing | timer `.body` rounded semibold mono, BBTextPrimary (dark #F0EDF6); **fixed width** measured for `1:23:45` (≈ 64 pt; `Text(timerInterval:)` is greedy in the island otherwise) | 18.2 |
| minimal | glyph only, category tint | ≥ 7.1 |
| expanded leading | 36 pt disc `tint@0.22` + glyph in tint | ≥ 7.1 |
| expanded trailing | timer `.title2` rounded semibold mono, BBTextPrimary | 18.2 |
| expanded bottom, title | `.subheadline` rounded, BBTextSecondary (dark #A29BB5), **up to 2 lines** beside the button, tail truncation only past 2 lines. Two `.subheadline` lines (≈ 2 × 20 pt at default) fit inside the 44 pt Stop row, so the Island does not grow at default size; at the xLarge cap the row grows by a few points, which the expanded Island allows (render to confirm); one line cut the side ("Кормление грудью · л…") at default size | 7.9 |
| expanded bottom, Stop | § 4 (BBPrimary #A795D9 fill + BBOnPrimary #171420 label) | 6.9 |
| keyline tint | BBPrimary | — |

- No words in compact or minimal: glyph and digits only (Content agrees, so three locales fit).
- **Long state** (as built, accepted in the review): compact trailing shows the `ellipsis` glyph in BBTextPrimary, no time (a time there would read as elapsed); its VoiceOver label is `live_activity.continues_in_app`, not the system's "More". Expanded trailing shows the started line (`.footnote` BBTextSecondary); expanded bottom shows `continues_in_app` in place of the title, and the glyph keeps the kind.
- With two activities (feeding + sleep), the system shows one compact and one minimal. Each draws as above, and the glyph shape tells them apart.
- An ended activity leaves the Island; "Saved" lives on the Lock Screen only.
- The Island views are pinned to `.environment(\.colorScheme, .dark)` (built).

## 4. Stop button (one spec, both surfaces)

| property | value |
|---|---|
| shape | capsule, min height 44 (tap target, P7), horizontal padding 16, min width 96 |
| fill / label | BBPrimary / **BBOnPrimary** — 5.6 light, 6.9 dark. White in dark would be G1 (2.64) |
| glyph + label | same glyph and string as the in-app stop for that timer: feeding (all kinds) `stop.fill` + `button.finish` "Stop · Завершить · Detener", sleep `sun.max.fill` + `button.woke_up` "Woke Up · Проснулся · Se despertó" |
| type | `.subheadline` rounded semibold, `minimumScaleFactor(0.8)`, 1 line, horizontal `fixedSize` |
| action | the LiveActivityIntent that ends the timer and saves the entry (no unlock) |

## 5. Widget — tap areas and the start-feeding control (D16)

The background stays the premium gradient. The control is a **BBSurface capsule with a BBPrimary label**, because white on the gradient's light end is 2.64 (G12).

| pair | light | dark |
|---|---|---|
| BBPrimary label on BBSurface capsule | 5.6 | 6.2 |
| BBTextPrimary (started state) on capsule | 14.3 | 14.1 |
| capsule edge vs gradient start (non-text, ≥ 3) | 5.6 | 3.6 |

**Small**

```
┌──────────────────────┐   whole widget → Feeding tab (widgetURL)
│ Last feed            │
│ 1 h 20 min           │
│                      │
│ ┌──────────────────┐ │   capsule → StartFeedingIntent
│ │ ▶  Feeding       │ │   h 36 visual, 44 hit; label `tab.feeding` (≤ 12)
│ └──────────────────┘ │
└──────────────────────┘
```
The "today N feeds" line leaves the small widget to make room for a 44 pt control. The hero answers the 3 a.m. question ("when did she last eat"), and the count stays on the medium widget. The label reuses `tab.feeding` with a `play.fill` glyph, because "Начать кормление" (16) does not fit 138 pt beside a glyph.

**Medium**

```
┌────────────────────────────────────────────────┐
│ Last feed               ♥ Last feed    1 h 20  │  left column → Feeding tab (Link)
│ 1 h 20 min              ☾ Sleeping     0:40    │  right rows: feed row → Feeding, sleep row → Sleep (each Link, min 44 high)
│                                                │
│ Mia                     ┌────────────────────┐ │
│                         │ ▶  Start feeding   │ │  capsule → StartFeedingIntent, label `button.start_feeding` (≤ 18)
│                         └────────────────────┘ │
└────────────────────────────────────────────────┘
```

Control states (both families):

| state | capsule shows | tap |
|---|---|---|
| idle (no feeding running) | `play.fill` + label, BBPrimary | starts a breastfeed timer (side left, as in-app quick start); the Live Activity takes over |
| pressed | system highlight | — |
| started / a feeding is running (any kind, bottle included) | the running kind's glyph + live timer `0:12`, BBTextPrimary, no words | opens the Feeding tab (a Link, not the intent) so a second tap never starts a second feed |
| sleep running | unchanged (feeding and sleep coexist) | — |
| intent failed | unchanged; the next timeline reload shows the truth; no error UI (P1) | — |
| first run (nothing logged) | idle capsule under the existing "log your first feeding" line | starts the first feed |

Observation for Content, not this card: the medium widget's `widget.overdue_by` line ("Overdue by 20 min") is worry-framing against P1. It is white@0.75, not red, but the word itself judges.

## 6. What Dev needs (`live-activity-timers`, `widget-interactive`)

1. **New colorset `BBOnPrimary`** in `Assets.xcassets/Colors/`: light #FFFFFF, dark #171420 (sRGB), plus `BBTheme.Colors.onPrimary`.
2. **Widget catalog copies** (the Live Activity renders in the widget extension). Add to `WidgetResources/Colors.xcassets` and to the pre-build drift list: BBSurface, BBPrimary, BBOnPrimary, BBTextPrimary, BBTextSecondary, BBFeeding, BBSleep. Before M1 the extension had only BBGradientStart, BBGradientEnd, BBAccent.
3. `activityBackgroundTint(Color("BBSurface"))`, `activitySystemActionForegroundColor(Color("BBPrimary"))`, `keylineTint(Color("BBPrimary"))`.
4. Fonts: system text styles, `.rounded`, mono digits on every timer. No `BBTheme.Typography` in the extension.
5. Renders for the design review: `LiveActivityRenderDump` (BabyBloomTests) — en/ru/es × light/dark × the states in §§ 2–3 (running for each kind incl. bottle, ended, long, two activities), at the default size and at the cap; the widget § 5 states. The real Dynamic Island on a dev build on my iPhone 17 Pro clone, booted only for the review (one simulator at a time, D25).

## 7. Strings — limits for Content (confirmed against Content's list)

| string | limit | Content's longest | fits |
|---|---|---|---|
| Lock Screen title (`live_activity.title.*`) | ≤ 26 | «Кормление грудью · правая» 25 | yes |
| bottle title (`live_activity.title.bottle`, D28) | ≤ 26, no side | «Кормление из бутылочки» 22 | yes |
| DI expanded bottom title | up to 2 lines beside the button (§ 3), ≤ 26 in all | 25 | yes, on 2 lines in ru; no copy change |
| `live_activity.started_fmt` / `saved_fmt` | ≤ 30 | «Сохранено · 1 ч 20 мин» 22 | yes |
| `live_activity.continues_in_app` | ≤ 32, up to 2 lines on the Lock Screen, scales to 0.8 at the cap | «Таймер идёт дальше в Ночке» 26 | yes |
| ~~`live_activity.stale`~~ | dropped: there is no frozen state (§ 0) | — | — |
| Stop labels | ≤ 12 (corrected from 10: es «Se despertó» is 11) | 11 | yes |
| widget small control | ≤ 12 → reuse `tab.feeding` | «Кормление» 9 | yes |
| widget medium control | ≤ 18 → reuse `button.start_feeding` | «Начать кормление» 16 | yes |
| widget started state | no string (glyph + timer) | — | — |
| Settings switch label / hint | label 1 line ≤ 32, or 2 lines; hint 2–3 lines; hidden on iPad | es «Temporizador en pantalla bloqueada» 34 | es may wrap to 2 lines (Settings rows wrap); Content's choice whether to shorten |
| `settings.live_activity_off_in_ios` (Dev, Q3) | 2–3 lines under the disabled switch, BBTextSecondary | — | to write |

Content's variant B strings (`widget.log_feeding`, `widget.logged_fmt`) are not needed after D16.

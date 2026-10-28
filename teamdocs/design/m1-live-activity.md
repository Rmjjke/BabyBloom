# M1 — Live Activity and widget controls (design note)

status: draft — card `m1-lockscreen-design`, 2026-10-28; judged live in the design review of `live-activity-timers` / `widget-interactive`
decisions: D5 (auto start, Settings switch), D6/D10 (free), D14 (WCAG 2.2 AA), D16 (widget control starts a feeding timer); plan v2 review round: BBOnPrimary, Lock Screen on BBSurface, design review before MERGE
reference: `teamdocs/design/design-system.md` (P = principle, G = gap)
triggers: a timer kind added; a Live Activity presentation or widget family added; a token in § 6 renamed
check: `grep -n 'case ' BabyBloom/Core/Models/SleepEntry.swift BabyBloom/Core/Models/FeedingEntry.swift` vs § 0 kinds; `ls WidgetResources/Colors.xcassets` vs § 6 list

Drawn by hand (no design tools, `ios: none`): annotated layouts plus spec
tables. Sizes are targets to verify on the first render, not pixel promises.

## 0. What the code says (to be confirmed by Dev's § A5 answers)

| fact | source | consequence |
|---|---|---|
| Only a **breastfeed** runs as a timer; formula / pumped are logged complete | `FeedingView.quickStart` | no bottle state (Content's `title.bottle` not needed) |
| Breast side is L / R / Both and **can change while the feed runs** | `FeedingView` side switcher | the title updates in place; no side control on the activity |
| Sleep is **nap** or **night** | `SleepEntry.SleepType` | two sleep titles, two glyphs |
| Feeding and sleep **can run together** | `DashboardView.activeTimersSection` | two activities at once |
| No pause | — | no paused state |

Glyphs (same as in the app): feeding `heart.fill`, nap `sun.max.fill`, night `moon.fill`, ended `checkmark.circle.fill`.

## 1. Shared rules

- **Timer:** `Text(timerInterval: start...Date.distantFuture, countsDown: false)` with `.monospacedDigit()`. The system ticks it, so it needs no updates. Reads `14:32` under an hour and `1:23:45` after.
- **Type:** system text styles in the rounded design, so Dynamic Type follows the system. The app's AX2 cap does not apply on the Lock Screen. At the largest sizes the **title truncates (tail), never the timer** (`fixedSize` + higher `layoutPriority`), and the Stop label shrinks down to 0.8, never truncates.
- **Calm (P1):** no red, orange or triangle, at any duration. BBAlert and BBSuccess are not used. A 50-minute feed looks exactly like a 5-minute one.
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
| ④ | "Started 03:12" | `.footnote` rounded, BBTextSecondary | 4.9 | 6.1 |

States:

| state | ① | ② | ③ | ④ |
|---|---|---|---|---|
| running | as above | live timer | Stop | `live_activity.started_fmt` |
| stopping (intent in flight) | — | — | system pressed dim; label stays, no spinner | — |
| ended (Stop tapped, in app or here) | glyph → `checkmark.circle.fill` BBPrimary | replaced by `live_activity.saved_fmt` "Saved · 14 min", `.title3` BBTextPrimary | none | started line stays |
| stale (`staleDate` passed, state unknown) | — | timer in BBTextSecondary (6.1 / 4.9) | Stop stays (the intent still writes the store) | `live_activity.stale` "Open the app to update" |
| ended by the system (~8 h; it can stay up to 4 h longer) | — | **no digits** (a frozen number would be wrong) | none | started line + `live_activity.continues_in_app` "The timer continues in the app" |
| two activities | the system stacks two banners, each as above | | | |

Dismissal after Stop: suggest `.after(now + 15 min)`. That's long enough to see "Saved" at a glance after settling the baby, and short enough not to clutter the morning. Dev's call if the system policy argues otherwise.

## 3. Dynamic Island (always on black — dark token values)

```
compact   (♥ ·············· camera ·············· 14:32)
minimal   (♥)
expanded  ┌──────────────────────────────────────────────┐
          │ (♥)                                    14:32 │  leading / trailing
          │ Breastfeeding · left             [ ■ Stop ]  │  bottom
          └──────────────────────────────────────────────┘
```

| region | spec | contrast on black |
|---|---|---|
| compact leading | glyph `.body`, category tint (dark: BBFeeding #C98BA0 7.7, BBSleep #8A93CC 7.1) | ≥ 7.1 |
| compact trailing | timer `.body` rounded semibold mono, BBTextPrimary (dark #F0EDF6); width holds `1:23:45` (≈ 64 pt) | 18.2 |
| minimal | glyph only, category tint | ≥ 7.1 |
| expanded leading | 36 pt disc `tint@0.22` + glyph in tint | ≥ 7.1 |
| expanded trailing | timer `.title2` rounded semibold mono, BBTextPrimary | 18.2 |
| expanded bottom, title | `.subheadline` rounded, BBTextSecondary (dark #A29BB5), 1 line ≤ 26 chars beside the button | 7.9 |
| expanded bottom, Stop | § 4 (BBPrimary #A795D9 fill + BBOnPrimary #171420 label) | 6.9 |
| keyline tint | BBPrimary | — |

- No words in compact or minimal: glyph and digits only (Content agrees, so three locales fit).
- With two activities (feeding + sleep), the system shows one compact and one minimal. Each draws as above, and the glyph shape tells them apart.
- An ended activity leaves the Island; "Saved" lives on the Lock Screen only.
- The Island renders in the dark scheme. If the tokens resolve light there, Dev forces `.environment(\.colorScheme, .dark)` on the island views. Verify on the first render.

## 4. Stop button (one spec, both surfaces)

| property | value |
|---|---|
| shape | capsule, min height 44 (tap target, P7), horizontal padding 16, min width 96 |
| fill / label | BBPrimary / **BBOnPrimary** — 5.6 light, 6.9 dark. White in dark would be G1 (2.64) |
| glyph + label | same glyph and string as the in-app stop for that timer: feeding `button.finish` "Stop · Завершить · Detener", sleep `button.woke_up` "Woke Up · Проснулся · Se despertó" |
| type | `.subheadline` rounded semibold, `minimumScaleFactor(0.8)`, 1 line |
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
| started / a feeding is running | `heart.fill` + live timer `0:12`, BBTextPrimary, no words | opens the Feeding tab (a Link, not the intent) so a second tap never starts a second feed |
| sleep running | unchanged (feeding and sleep coexist) | — |
| intent failed | unchanged; the next timeline reload shows the truth; no error UI (P1) | — |
| first run (nothing logged) | idle capsule under the existing "log your first feeding" line | starts the first feed |

Observation for Content, not this card: the medium widget's `widget.overdue_by` line ("Overdue by 20 min") is worry-framing against P1. It is white@0.75, not red, but the word itself judges.

## 6. What Dev needs (`live-activity-timers`, `widget-interactive`)

1. **New colorset `BBOnPrimary`** in `Assets.xcassets/Colors/`: light #FFFFFF, dark #171420 (sRGB), plus `BBTheme.Colors.onPrimary`.
2. **Widget catalog copies** (the Live Activity renders in the widget extension). Add to `WidgetResources/Colors.xcassets` and to the pre-build drift list: BBSurface, BBPrimary, BBOnPrimary, BBTextPrimary, BBTextSecondary, BBFeeding, BBSleep. Today the extension has only BBGradientStart, BBGradientEnd, BBAccent.
3. `activityBackgroundTint(Color("BBSurface"))`, `activitySystemActionForegroundColor(Color("BBPrimary"))`, `keylineTint(Color("BBPrimary"))`.
4. Fonts: system text styles, `.rounded`, mono digits on every timer. No `BBTheme.Typography` in the extension.
5. Renders for the design review: every state in §§ 2–3 in light/dark and at the default and largest text size, and the widget §5 states. WidgetRenderDump or the simulator. I review on my own iPhone 17 Pro clone.

## 7. Strings — limits for Content (confirmed against Content's list)

| string | limit | Content's longest | fits |
|---|---|---|---|
| Lock Screen title (`live_activity.title.*`) | ≤ 26 | «Кормление грудью · правая» 25 | yes |
| DI expanded bottom title | ≤ 26 beside the button. **No need to move the side to its own line** | 25 | yes |
| `live_activity.started_fmt` / `saved_fmt` | ≤ 30 | «Сохранено · 1 ч 20 мин» 22 | yes |
| `live_activity.stale` (new) | ≤ 32, calm, no "error" | — | to write |
| `live_activity.continues_in_app` (new) | ≤ 32 | — | to write |
| Stop labels | ≤ 12 (corrected from 10: es «Se despertó» is 11) | 11 | yes |
| widget small control | ≤ 12 → reuse `tab.feeding` | «Кормление» 9 | yes |
| widget medium control | ≤ 18 → reuse `button.start_feeding` | «Начать кормление» 16 | yes |
| widget started state | no string (glyph + timer) | — | — |
| Settings switch label / hint | label 1 line ≤ 32, or 2 lines; hint 2–3 lines | es «Temporizador en pantalla bloqueada» 34 | es may wrap to 2 lines (Settings rows wrap); Content's choice whether to shorten |

Content's variant B strings (`widget.log_feeding`, `widget.logged_fmt`) are not needed after D16.

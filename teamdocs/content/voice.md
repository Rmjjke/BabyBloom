# Voice, terms and surface rules — BabyBloom copy

Canon above this file: `README.md` (scope), `NOTIFICATIONS.md` (notification
catalogue), `docs/naming/` (brand), `DECISIONS.md` (product rules).
Strings live in `BabyBloom/Resources/Localization/{en,ru,es}.json`; the widget
and the Live Activity read the byte-identical copies in
`WidgetResources/Localization/` (the pre-build script fails on drift).

## Voice

- Calm. Numbers, never verdicts: no "good / bad / better / worse / only",
  no colour words, no alarm. A count above its reference is not an
  achievement, below it is not a worry (`DECISIONS.md` 2026-09-05).
- Full plain sentences; one message, one point.
- Russian addresses the parent as «вы». The brand is declined in Russian
  («в Ночку», «Откройте Ночку»), so a Russian string that names the brand
  writes the declined form, not `%@`.
- Spanish addresses the parent as «tú».

## Terms

| meaning | en | ru | es | note |
|---|---|---|---|---|
| breastfeeding (full) | Breastfeeding | Кормление грудью | Lactancia | Lock Screen, Dynamic Island |
| breastfeeding (list shorthand) | BF | ГВ | LM | in-app lists only, never on the Lock Screen |
| timer | timer | таймер | cronómetro | es uses «cronómetro», as `form.start_timer` |
| Lock Screen | Lock Screen | экран блокировки | pantalla bloqueada | Apple's own terms |
| stop a feeding | Stop | Завершить | Detener | `button.finish`, everywhere |
| stop a sleep | Woke Up | Проснулся | Se despertó | `button.woke_up`, everywhere |
| start a feeding | Start Feeding | Начать кормление | Iniciar toma | `button.start_feeding`, app and widget |

## Surface rules

- **Live Activity.**
  - Dynamic Island compact and minimal carry no words: glyph + timer only.
  - The title (kind · side) fits 26 characters on the Lock Screen and in the
    expanded island. A formula or pumped feed can run as a timer too and has
    no side, so it has one title, `live_activity.title.bottle`.
  - The started / saved line fits 30; "goes on in the app" fits 32.
  - There is no frozen or stale timer: after ~8 h the activity shows
    `started_fmt` + `continues_in_app` instead of digits. Elapsed time is
    system-rendered, no string.
  - The stop action is the same key as the in-app button for that timer
    (≤ 12).
  - Limits: `teamdocs/design/m1-live-activity.md` § 7.
- **Settings switch.** Hidden on iPad. When iOS has Live Activities off for
  the app, the switch is off and disabled, and
  `settings.live_activity_off_in_ios` says where to turn them on
  (Settings → app name). Russian says «это» instead of naming the iOS
  toggle, because its Russian label is not one we control.
- **Widget.** The control starts a feeding timer: `tab.feeding` on the small
  family, `button.start_feeding` on the medium. The entry is the same record
  as one started in the app, so "a feeding" has one meaning and the widget
  needs no strings of its own. No "logged" confirmation — the widget's own
  state shows the running feed.
- **Time past a reminder** is told as elapsed time, never as a fault:
  «Прошло ещё 20 мин», not «Просрочено на 20 мин».
- **Lengths.** Length limits live in the design notes in `teamdocs/design/`.
  Every new string is checked against them in all three locales before it is
  committed.

## Changes

- 2026-10-28 — 1.1.0 Live Activity, Settings switch, widget descriptions
  (`live_activity.*`, `settings.live_activity*`, `widget.description_*`).
- 2026-10-29 — `live_activity.title.bottle` added, `live_activity.stale`
  removed (no stale state in the build), `settings.live_activity_off_in_ios`
  added.

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
- Spanish addresses the parent as «tú». The app's Spanish is Latin American:
  es is pinned to es_419 (`DECISIONS.md` 2026-10-30), and its words follow
  iOS in that locale. The same text serves Spain, so a word that reads oddly
  there is avoided.

## Terms

| meaning | en | ru | es | note |
|---|---|---|---|---|
| add (a record, a weighing, a question, a medication) | Add | Добавить | Agregar | every form: «Agregar», «agregar», «Agrega», «agrega»; never «Añadir». iOS 26 says «Agregar» in es_419 (348 strings, no «Añadir») and «Añadir» in Spain's es; «agregar» is ordinary Spanish in Spain too |
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
- **Sheet titles in the bar.** The title sits on one line between the bar's
  two glyph buttons: × for Cancel or Close, ✓ for Save, a pencil for Edit.
  It is set in SF Pro 17 pt semibold at the default text size and never
  grows past it. Through the sheet-title helper (`bbSheetTitle`) it shrinks
  to fit, down to 13 pt, the size of the sheets' captions; a plain bar title
  is cut with «…» instead. At larger text sizes the title moves into the
  sheet's content.
  - A title of at most 166 pt (CoreText width at 17 pt semibold) stays whole
    and full-size on every phone, with 8 pt to spare on a 320 pt one. The
    glyphs take the same room in every language, which leaves the title
    256 pt on a 402 pt phone, 229 on 375 and 174 on 320, so the 13 pt floor
    never acts on a title within the budget.
  - Every sheet title in en, ru and es is within it. The widest is es
    «Nuevo medicamento», 163.4 pt; none shrinks on any width.
  - The dose sheet shows no title in its bar. Its heading, the medication's
    name, sits in the content at every size: the name is the parent's own
    text, so no budget holds it, and as a heading it wraps instead of losing
    its end, which is often where two names differ. The sheet's fixed
    titles (ru «Отметить дозу», es «Registrar dosis») sit there too.
  - A Russian edit sheet may take the bare noun of what it edits: «Вопрос»
    (61.6 pt), «Лекарство» (88.1), «Профиль» (75.5). The bar's × and ✓
    already say that the sheet edits. «Профиль» is also the title of the
    screen the sheet opens from; the sheet covers that screen, so the two
    never show together.
  - Not taken for the profile: «Изменить» (82.6) reads as a button; «О
    малыше» (86.6) reads as an information page, not a form. «Изменить
    профиль» (159.6), «Правка профиля» (138.1) and «Данные малыша» (138.8)
    fit the budget, but the bare noun already names the form in fewer
    words.
- **Line breaks around numbers.** A number never wraps away from its unit,
  and a short word that belongs to the number stays on its line.
  - Number + short word + unit: «4 в сутки», «4,5 al día», «8 o más». The
    short word gets a no-break space on both sides. The code glues every
    digit to the word after it (`gluingNumbersToUnits`), so with a plain
    space after the short word the line breaks right there («4 в» / «сутки»).
  - A short Russian preposition before a number or a date: «за 7 дн.»,
    «от 6», «с 2 нояб.», «на 1,5 коридора». Russian typesetting never leaves
    the preposition at the end of a line.
  - A number range stays on one line. The line may break after an en dash
    («6–» / «10»), so a word joiner (U+2060, invisible, no width) follows
    the dash: `6–\u{2060}10`, and `%d–\u{2060}%d` in a format. A range in
    words glues its words with no-break spaces: "1 to 24", «от 1 до 24»,
    «del 1 al 24», «de 6 a 10», «del percentil 15 al 85».
  - The percentile band labels (`percentile.3_15` … `percentile.85_97`)
    keep the plain dash. Each stands alone, so its line breaks only when the
    whole label is wider than its box, and there a break after the dash
    reads better than one inside a number. A unit test also matches «15–50»
    as written.
  - In the JSON the no-break space is written as the escape ` `, which
    reads as the same character.
  - Not glued:
    - counts «5 из 7» / "5 of 7", which have no unit;
    - a date or a name after an English or Spanish preposition, where
      wrapping is normal;
    - strings that VoiceOver speaks and the screen never shows.
  - Still open: English "a day" and "or more" on the Nutrition card have the
    same break. The e2e flows for that card match these lines with a plain
    space, so the English change goes in together with the flows. Literal
    numbers inside longer texts (onboarding facts, hints, notifications, the
    export ranges) still use plain spaces.

## Changes

- 2026-10-28 — 1.1.0 Live Activity, Settings switch, widget descriptions
  (`live_activity.*`, `settings.live_activity*`, `widget.description_*`).
- 2026-10-29 — `live_activity.title.bottle` added, `live_activity.stale`
  removed (no stale state in the build), `settings.live_activity_off_in_ios`
  added.
- 2026-11-03 — 1.2.0 no-break spaces around short words next to numbers.
  ru: `nutrition.per_day_fmt`, `nutrition.window_fmt`, `breakdown.gain_fmt`,
  `breakdown.feeds_fmt`, `breakdown.nappies_fmt`, `velocity.interval_fmt`,
  `trend.drop_fmt`, `report.change_since_fmt`, `report.empty_*_fmt`. es:
  `nutrition.per_day_fmt`, `breakdown.feeds_fmt`, `breakdown.nappies_fmt`.
  Text unchanged.
- 2026-11-03 — es: one verb for "add", «agregar». Eleven values that said
  «Añadir» / «añade» now say «Agregar» / «agrega»: `dashboard.growth.empty`,
  `growth.add_weighing`, `newborn.needs_weighing`, `newborn.info_body`,
  `velocity.info_body`, `nutrition.info_body`, `notification.weigh_in_body`,
  `onboarding.showcase.invite`, `question.add`, `medication.add`,
  `medication.empty_body`. No other word changed.
- 2026-11-04 — ru `profile.edit_title` «Редактировать профиль» → «Профиль».
  The old title was 202.4 pt: it shrank to 11 pt on a 402 pt phone, smaller
  than the sheet's captions, and was cut on a 375 pt one. en "Edit Profile"
  (86.4 pt) and es «Editar perfil» (92.7) stay.
- 2026-11-04 — number ranges never split across lines. A word joiner after
  the dash in en/ru/es `diaper.norm.hint` (es: no-break spaces in «de 6 a
  10»), `newborn.info_body` (three ranges), `velocity.expected_fmt`,
  `breakdown.gain_fmt`, `breakdown.feeds_fmt`, `percentile.info_body` (es:
  no-break spaces in «15 al 85»), `onboarding.fact.infant2`,
  `onboarding.fact.breast1`, `onboarding.fact.formula1`, `chart.who_corridor`.
  Text unchanged.
- 2026-11-04 — the sheet-title budget is 166 pt on every width (was 96 pt
  on a 375 pt phone). The sheet bars carry glyph buttons instead of the
  words Cancel and Save, so a title has 174 pt even on a 320 pt phone, and
  the list of titles that shrank on 375 pt is empty. The dose sheet's title
  moves into its content. No text changed.

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
- **Widget: time since the last feed** (`widget.last_feed`): "Last feed",
  «С кормления», «Última toma». One key, two places: the medium widget's
  row title (10 pt, above the time since the feed) and the headline at 12+
  months (12 pt, above the same time as the hero). The row's title has
  99.5 pt on a 10.2" iPad and 107.5 pt on the iPhone SE; «Последнее
  кормление» (114.4 pt) was cut on both, and as a headline it took two lines
  on the medium and shrank on the small. Not «Кормление»: above a duration
  it reads as how long the feed lasted, and the capsule below it already
  says «Кормление».
- **Time past a reminder** is told as elapsed time, never as a fault:
  «Прошло ещё 20 мин», not «Просрочено на 20 мин».
- **Time since the last feed** on Home's Today tile counts in minutes under
  an hour and in hours under 48 hours. From 48 hours it counts whole days,
  rounded down: «4 дня назад», "4 days ago", «hace 4 días». «131 ч назад»
  left the arithmetic to the parent.
  - The days form is `stats.days_ago_fmt` around the number and its day
    word from the age plurals (`age.day.*`: one / few / many in Russian,
    one / other in English and Spanish). The number and the word are joined
    by a no-break space, so no count needs a key of its own and the plural
    rule is the one the age already uses.
  - Medications tell a dose's age the same way (`medications.md`).
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
- **VoiceOver names of glyph-only buttons.** A button that shows only a
  glyph takes its VoiceOver name from the app's strings. The name iOS gives
  a symbol follows the device's language, not the app's: VoiceOver would
  say «Добавить» or «Удалить» to a parent reading the app in another
  language. The + that opens a screen's entry sheet says what it adds; the
  − and + of the diaper goal editor say what they change:

  | button | key | en | ru | es |
  |---|---|---|---|---|
  | Feeding + | `sheet.new_feeding` | New Feeding | Новое кормление | Nueva toma |
  | Sleep + | `sheet.add_sleep` | Add Sleep | Добавить сон | Agregar sueño |
  | Diaper + | `diaper.add` | Add Diaper | Добавить подгузник | Agregar pañal |
  | Growth + | `sheet.new_measurement` | New Measurement | Новое измерение | Nueva medición |
  | Events + | `sheet.new_event` | New Event | Новое событие | Nuevo evento |
  | Diaper goal − | `diaper.norm.a11y_decrease` | Decrease goal | Уменьшить норму | Disminuir meta |
  | Diaper goal + | `diaper.norm.a11y_increase` | Increase goal | Увеличить норму | Aumentar meta |

  - Four of the five add buttons reuse their sheet's title, which already
    names what the sheet adds, so VoiceOver reads the same words on the
    button and as the sheet's heading.
  - The Diaper sheet's title, «Подгузник» / "Diaper" / «Pañal», names the
    thing, not the action, so its button has a key of its own, built like
    «Добавить сон» with the add verb of the Terms table.
  - The Home quick sheets for Feeding, Sleep and Diaper show the same
    screen, so their + carries the same name.
  - The goal editor's names use the editor's own noun: "goal", «норма»,
    «meta», as its heading "Daily Goal" / «Норма в день» / «Meta diaria».
    They are VoiceOver-only strings (`a11y_`), so they take sentence case,
    as `weekly.a11y_hide`.
- **A switch's line.** A switch carries a line under its title only when the
  title alone does not say what turning it on does, or when it happens. The
  line says what the title leaves out, and nothing else.
  - A switch that sends something later says when. The weekly summary's
    title and its Notifications section already say what arrives, so its
    line is the time: "It arrives on Monday mornings." / «Приходит утром по
    понедельникам.» / «Llega los lunes por la mañana.»
  - A part of the day, not a clock time: "mornings", not "10:00" or
    "10 AM". A typed hour prints the wrong clock form on a phone set the
    other way, and a part of the day stays true if the hour moves within it.
    A time the code formats, such as the medication reminder's «Уведомление:
    14:30», follows the phone's own clock.
  - No "every" / «каждый» / «cada» where an empty period sends nothing: the
    weekly summary skips a week with no entries.
  - A switch whose title names a thing says what the switch does with it.
    "Usage Statistics" alone can read as statistics the app shows the
    parent, so its line says who sees what: "We see which features are
    used." / «Мы видим, чем пользуются.» / «Vemos qué funciones se usan.» It
    names only what is sent. What is never sent (names, measurements, notes)
    takes three lines or more there. It never says "anonymous": the install
    keeps one random id.
  - A switch that shows its field at once, an optional measurement, needs
    no more than "(optional)": the field appears as the switch turns on.
  - Two lines at most at the default text size on a 320 pt screen, in every
    language. In Settings the line is set at 13 pt beside the switch, in
    about 145–155 pt there, so it holds one short sentence of about 30
    characters in English.
  - The switches today:

    | switch | title | line under it | why |
    |---|---|---|---|
    | Settings › Weekly summary | `settings.notify_weekly` | `settings.notify_weekly_hint` | it sends later: the line says when |
    | Settings › Timer on Lock Screen (not on iPad) | `settings.live_activity` | `settings.live_activity_hint`; `settings.live_activity_off_in_ios` while iOS has it off | the line says when the timer shows and what it adds: a stop from the Lock Screen |
    | Settings › Usage Statistics | `settings.analytics` | `settings.analytics_hint` | the title names a thing: the line says who sees what |
    | Feeding sheet › Start Timer | `form.start_timer` | `form.timer_hint` | the title says what; the sheet's button says when (Start Feeding) |
    | Medication › reminder (form and detail) | `medication.reminder_switch` | `medication.reminder_at_fmt` while on; `medication.reminder_footer`; `medication.reminder_off_in_settings` while iOS has it off | the title says what and when: once the interval has passed |
    | Growth sheet › Height, Head circumference | `form.height_cm`, `form.head_cm` | `form.head_optional_hint` | the switch shows the field at once |
    | Onboarding › Head circumference | `form.head_cm` | `onboarding.growth_head_optional` | the same |
    | Onboarding and Profile › Preterm birth | `form.preterm` | `form.preterm_hint` | the line says what it changes: growth at corrected age |
    | Profile › Birth weight | `form.birth_weight_kg` | `form.birth_weight_hint` | the line says what it feeds and for how long |

    The export screen's categories are check boxes, not switches: each one's
    name is what it adds to the file.
- **A legend for a glyph.** A line that says once what a glyph means on
  several rows is for sight only and is hidden from VoiceOver. Each row
  speaks the glyph's meaning in words, so the legend read aloud would only
  repeat it. Its words name the same thing as the spoken ones. The weekly
  card's arrows: `weekly.legend` "Arrows show the change from the week
  before.", spoken on each row as `weekly.a11y_delta_up_fmt` /
  `_down_fmt` "… more / less than the week before".
- **Line breaks around numbers.** A number never wraps away from its unit,
  and a short word that belongs to the number stays on its line.
  - Number + unit, in every language, in the value itself: "119 g/week",
    "over 9 days", «9 días». Most views do not glue a number in code.
  - Number + short word + unit: "4.5 a day", "6 or more", «4 в сутки»,
    «4,5 al día», «8 o más». The short word gets a no-break space on both
    sides. With a plain space the line breaks inside: «reference 6 or» /
    «more.» at the default size on a 320 pt screen. The duration, weekly and
    report formats also glue every digit to the word after it in code
    (`gluingNumbersToUnits`), and there a plain space after the short word
    is where the line breaks («4 в» / «сутки»). A UI test that matches such
    a line takes `.` where the no-break space is: a plain space no longer
    matches.
  - A short Russian preposition before a number or a date: «за 7 дн.»,
    «от 6», «с 2 нояб.», «на 1,5 коридора». Russian typesetting never leaves
    the preposition at the end of a line.
  - A one-letter Russian preposition (в, к, с, у, о) or conjunction (и, а)
    before a word, in every text of the app: «в пределах ориентира»,
    «с интервалом», «О питании», «Мокрый и грязный», «а не диагноз».
    Russian typesetting never leaves a one-letter word at the end of a line.
    The verdict stands in a narrow column at the right of its row, after the
    number: «8 в сутки · в пределах ориентира». With a plain space that line
    ended on «· в» at the default size on 375 and 402 pt screens. The
    no-break space joins the one-letter word to the next word only, so the
    run stays short. Two one-letter words in a row are both glued: «и к
    10–14-му дню».
  - On a 320 pt screen at xxxL, the largest size before the accessibility
    sizes, the Nutrition card's gain row leaves its verdict about 103 pt.
    The dot and «в пределах» take 116 pt, so «пределах» breaks inside. The
    same card breaks words at that size without the glue too («Кормлени» /
    «я», «подгузни» / «ки»): the cure there is the row's layout, not the
    words.
  - The event row's title «Мокрый и грязный» (`diaper.title.both`) breaks
    inside «грязный» on a 320 pt screen at AX1. Beside the icon and the time
    the title has about 111 pt, less than «и грязный». Loose, the «и» ended
    a line in 12 of the 18 cases (three widths, six sizes from Large to
    AX2). At AX2 the row breaks both words without the glue too: the cure
    there is the row's layout, not the words.
  - A number range stays on one line. The line may break after an en dash
    («6–» / «10»), so a word joiner (U+2060, invisible, no width) follows
    the dash: `6–\u{2060}10`, and `%d–\u{2060}%d` in a format. A range in
    words glues its words with no-break spaces: "1 to 24", «от 1 до 24»,
    «del 1 al 24», «de 6 a 10», «del percentil 15 al 85».
  - A unit with a slash stays whole. The line may break after the slash
    («100–200 g/» / «week.»), so a word joiner follows it:
    `g/\u{2060}week`, `г/\u{2060}нед`, `g/\u{2060}sem`. A UI test that
    matches such a value takes `.?` after the slash.
  - The gain card's big number (`velocity.per_week_fmt`) keeps the plain
    slash. It stands alone beside the interval, and when it is wider than its
    room (English from xxL on a 320 pt screen, every language at AX2 on a
    375 pt one), the slash is the one place it can break. With a joiner it
    would break inside «week» instead. The same key also fills the Home
    growth row and the weekly summary's previous week, where it has room.
  - In the JSON the no-break space and the word joiner are the raw
    characters U+00A0 and U+2060, not escapes. An editor and a diff show
    them as a plain space or as nothing, so a value is checked with a script
    that prints its code points.
  - A count «5 из 7» / "5 of 7" at the end of a line that wraps stays whole:
    `%d\u{00A0}of\u{00A0}%d` in `weekly.days_logged_fmt` and
    `report.days_logged_fmt`. These lines wrap on a 320 pt screen, and a
    break inside the count («…entries: 18» / «of 20») leaves 18 at a line's
    end, where it reads as a number of its own. The run is short, so it never
    has to break inside a word, at AX2 either.
  - Not glued:
    - the PDF page number `report.pdf.page_fmt` ("Page 2 of 3"), which
      never wraps;
    - a date or a name after an English or Spanish preposition, where
      wrapping is normal;
    - strings that VoiceOver speaks and the screen never shows;
    - a two-word label where the glue only trades the loose letter for a
      break inside the word: «О приложении» (`settings.about`). The Settings
      row holds it on one line at every size but AX1 and AX2 on a 320 pt
      screen. There, glued, it breaks inside «приложении» at AX1, where
      loose it breaks after «О»; at AX2 the word breaks either way.
  - The rule holds in every key and every language, long texts included:
    onboarding facts, info sheets, hints, notifications, the export ranges.
    Besides a number and its unit it glues:
    - a counted word before its number: "day 14", «día 14», «день 14»,
      «percentil 50», "Day %d";
    - a duration as a whole: `duration.min_sec` "%d min %d sec", as
      `duration.h_min`;
    - a short Russian preposition before a number, in every key: «до 12
      раз», «от 3 дней», «К 3 месяцам».
  - A Russian ordinal (a number, the end of a range or `%d`, then a hyphen
    and its ending) takes the no-break hyphen U+2011 in place of the
    hyphen: «14‑му», «3–97‑й», «%d‑й». It draws as the hyphen,
    and the line never breaks inside the ordinal. Every ordinal in the
    Russian JSON has it: `dashboard.growth.percentile_fmt`,
    `percentile.below3`, `percentile.above97`, `newborn.flag_not_regained`,
    `newborn.info_body`, `percentile.info_body` and `chart.who_corridor`.
    Like the no-break space, it is the raw character in the JSON, and a diff
    shows it as a hyphen.
    - The word after the ordinal stays loose: «50‑й перцентиль» may
      break at the space, and a break after a whole ordinal reads well.
      Glued, «50‑й перцентиль» would be one run wider than the value
      beside «Перцентиль по весу» on the Home growth row (on a 320 pt screen
      from xL, on a 375 pt one at xxxL), and the line would break inside
      «перцентиль». On the info sheets the glue only adds lines.
    - A one-letter preposition before the ordinal is glued like any other
      («к 14‑му дню»); a longer word before it is not («выше 97‑го»).
    - Measured on 320, 375 and 402 pt screens from Large to AX2, the line
      broke at the ordinal's own hyphen 5 times on the growth info sheets:
      «к 14-» / «му» on the newborn sheet on a 320 pt screen at AX1, 375 pt
      at AX2 and 402 pt at Large, «10–14-» / «му» on the same sheet at AX2
      on 402 pt, and «97-» / «го» on the percentile sheet at AX2 on 402 pt.
      With the no-break hyphen it never does. No line breaks inside a word
      that did not before; at AX2 on a 402 pt screen each of the two sheets
      takes one line more.
    - SF and SF Rounded, the app's and the widget's faces, draw U+2011 with
      the hyphen's own glyph. Helvetica Neue, the PDF's face, draws it as a
      hyphen a little shorter than its plain one (86% of its width in
      Regular, 82% in Bold); Helvetica draws it at the same width.
    - A unit test that compares one of these strings with a literal writes
      `\u{2011}` in it; a UI test matcher takes `.` in its place.
  - Before this rule the ordinal was loose, and a glue around it only moved
    the break inside it: «3–97-» / «й перцентили», which reads worse than a
    break at the space. With the glue and without it the line broke at the
    ordinal's own hyphen in the same places, and loose, the «к» before
    «14-му» ended a line 6 times in 18 cases on the newborn sheet, so it was
    glued.
  - Left to the code: a key whose every use passes through
    `gluingNumbersToUnits` keeps its plain space in the JSON, because the
    code glues each digit to the space after it when it shows the line.
    These are `stats.min_ago`, `stats.h_ago`, `premium.cta_trial_fmt` and
    `velocity.interval_fmt`. A new use of one of them outside that function
    needs the no-break space in the JSON.
  - Left loose, because glued it would break inside a word: Russian «на 6–8
    кормлений» in `onboarding.fact.infant2`. The fact page's text is 224 pt
    wide on a 320 pt screen. Glued whole, «на 6–8 кормлений» would break
    inside «кормлений» at AX1 and AX2, and «6–8 кормлений» alone at AX2.
  - Check a glued run against its place at AX2 before committing it: a run
    wider than its line breaks inside a word, which is worse than the break
    the glue prevents.

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
- 2026-11-04 — `diaper.add` added, the VoiceOver name of the Diaper
  screen's +: "Add Diaper", «Добавить подгузник», «Agregar pañal». The
  Feeding, Sleep and Growth + take their sheets' titles, as Events already
  does.
- 2026-11-04 — `diaper.norm.a11y_decrease` and `diaper.norm.a11y_increase`
  added, the VoiceOver names of the diaper goal editor's − and +: "Decrease
  goal" / "Increase goal", «Уменьшить норму» / «Увеличить норму», «Disminuir
  meta» / «Aumentar meta».
- 2026-11-04 — English "a day" and "or more" on the Nutrition card and in
  the feeding breakdown are glued to their number (`nutrition.per_day_fmt`,
  `breakdown.feeds_fmt`, `breakdown.nappies_fmt`), and so are the number and
  unit of `nutrition.window_fmt` and `breakdown.gain_fmt` in English and
  Spanish ("over 9 days", "119 g/week", «9 días», «119 g/sem»). Russian had
  them already.
- 2026-11-04 — Russian `widget.last_feed` «Последнее кормление» → «С
  кормления», whole in the medium widget's row on the iPhone SE and the
  10.2" iPad. English and Spanish fit as they are.
- 2026-11-04 — A word joiner after the unit's slash in `velocity.expected_fmt`,
  `weekly.gain_fmt` and `breakdown.gain_fmt` (en/ru/es), and a no-break space
  between `velocity.expected_fmt`'s range and its unit. `velocity.per_week_fmt`
  keeps the plain slash.
- 2026-11-04 — The rule for the time since the last feed on Home is written
  down: minutes, hours under 48, then whole days through `stats.days_ago_fmt`
  and `age.day.*`. These words have been in the app since 2026-11-02.
- 2026-11-04 — The days-with-entries line says that the "a day" figures
  above it are averages, on the weekly card and in the doctor report
  (`weekly.days_logged_fmt`, `report.days_logged_fmt`): "Averages over the
  days with entries: 5 of 7" / «Среднее по дням с записями: 5 из 7» /
  «Promedio de los días con registros: 5 de 7». The row labels keep their
  words: with "average" in it, a label no longer fits beside the week's
  delta on a 320 pt screen. The count at the line's end is glued whole
  ("18 of 20"), since the report's line wraps on that screen.
- 2026-11-04 — The weekly card's gain line without a pair of weighings
  names what is missing: no weighing yet (`weekly.gain_needs_two`), one more
  at least 3 days after the first (`weekly.gain_needs_second`), or a weighing
  this week that shows next Monday (`weekly.gain_next_monday`). Russian «Два
  взвешивания… покажут прибавку», «Ещё одно взвешивание… покажет прибавку»,
  «Взвешивание этой недели покажет прибавку в следующий понедельник».
  Spanish «Dos pesajes…», «Un pesaje más…», «El pesaje de esta semana…».
- 2026-11-04 — `settings.notify_weekly_hint` under the weekly summary
  switch: "It arrives on Monday mornings." / «Приходит утром по
  понедельникам.» / «Llega los lunes por la mañana.» Two lines at most on a
  320 pt screen.
- 2026-11-04 — A switch carries a line under its title only where the title
  does not say what it does or when (§ Surface rules, with every switch in
  the app). New `settings.analytics_hint` under Usage Statistics: "We see
  which features are used." / «Мы видим, чем пользуются.» / «Vemos qué
  funciones se usan.» Two lines at most on a 320 pt screen.
- 2026-11-04 — A legend for a glyph is for sight only (§ Surface rules). The
  weekly card's `weekly.legend`, and its hidden line `weekly.hidden` with
  `weekly.undo`: `weekly-and-notifications.md`.
- 2026-11-04 — The no-break rule for numbers covers every key (§ Line breaks
  around numbers). This change touches 30 English, 28 Russian and 31 Spanish
  values and only their space characters:
  `dashboard.growth.percentile_fmt` (en, es), `diaper.norm.hint`,
  `duration.min_sec`, `duration.sec`, `export.range.week` / `month` /
  `three_months`, `feeding.title.formula_ml` / `pumped_ml`,
  `history.free_window`, `newborn.day_fmt`, `newborn.flag_loss` (ru),
  `newborn.flag_not_regained` (en, es), `newborn.info_body`,
  `notification.feeding_long_body` / `idle_body` / `measurements_body`, the
  eight `onboarding.fact.*`, `percentile.info_body` (es),
  `percentile.out_of_range`, `trend.drop_fmt` (en, es), `velocity.info_body`,
  `velocity.needs_two` / `needs_second` / `no_reference`. A UI test that
  matches one of these lines takes `.` where the no-break space now is.
- 2026-11-04 — The four percentile band labels are deleted:
  `percentile.3_15`, `percentile.15_50`, `percentile.50_85`,
  `percentile.85_97`. The growth card states the percentile itself ("61"),
  so no screen, widget or report reads them. Their exception under the range
  rule goes with them. `percentile.below3`, `percentile.above97` and the
  badges stay.
- 2026-11-05 — Russian one-letter prepositions before a word are glued to
  it in the growth and Nutrition texts (§ Line breaks around numbers), so
  the Nutrition rows and the Home gain row no longer end a line on «· в».
  26 no-break spaces, nothing else changed: `velocity.within`,
  `velocity.needs_two`, `velocity.first_weeks`, `velocity.info_title`,
  `velocity.info_body`, `nutrition.status_within`, `nutrition.need_weighing`,
  `nutrition.need_weighing_detail`, `nutrition.info_title`,
  `nutrition.info_body`.
- 2026-11-05 — Every Russian text now glues a one-letter preposition (в, к,
  с, у, о) or conjunction (и, а) to the next word (§ Line breaks around
  numbers): 154 no-break spaces in 105 keys, nothing else changed. They are
  in the Home cards, the empty states, onboarding and its facts, the
  notifications, the weekly summary, Premium, Settings, the export, the
  widget and the Live Activity, the doctor report, the visit questions and
  the growth sheets. In `velocity.*` and `nutrition.*` only «и» and «а» were
  still loose. Left plain: the VoiceOver-only `medication.a11y_hint`,
  `premium.locked_a11y` and `report.a11y_hint`, and `settings.about`. At
  the default size no line breaks inside a word that did not before. A UI
  test that matches one of these lines takes `.` where the no-break space
  now is. The ordinal rule now says the one-letter preposition before an
  ordinal is glued («к 14-му дню»).
- 2026-11-05 — Every Russian ordinal takes the no-break hyphen U+2011 in
  place of its hyphen (§ Line breaks around numbers), so a line no longer
  ends on «14-» with «му» on the next: 11 hyphens in
  `dashboard.growth.percentile_fmt`, `percentile.below3`,
  `percentile.above97`, `newborn.flag_not_regained`, `newborn.info_body`
  (2), `percentile.info_body` (4) and `chart.who_corridor`, nothing else
  changed. The word after the ordinal stays loose. A test that compares
  `percentile.below3` or `percentile.above97` with «< 3-й» or «> 97-го»
  takes the new hyphen.

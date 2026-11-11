# Medications copy

Voice and terms: `voice.md` in this folder. Strings: `medication.*`,
`notification.medication_*`, `export.csv.medication`, `export.csv.dose` in
`BabyBloom/Resources/Localization/{en,ru,es}.json` (and the widget copies).

## The one rule

The app counts the time between doses from the interval the parent entered.
It never prescribes: no string tells the parent to give a dose, says that a
dose is allowed, or calls a dose safe, right or early. The parent's doctor may
have said otherwise, so the text states facts and never argues.

## Terms

| meaning | en | ru | es | note |
|---|---|---|---|---|
| the medicine the parent sets up | medication / medications | лекарство / лекарства | medicamento / medicamentos | en matches the event type and the iOS Health app; es «medicamento» reads the same in Spain and Mexico |
| one giving | dose | доза | dosis | ru never «приём»: on the same screens «приём» is the pediatrician visit |
| the amount text | Dose | Доза | Dosis | `form.dose` too; the frequency is the interval now |
| log a dose | Log Dose | Отметить дозу | Registrar dosis | the app's verb for an entry; no control says give / дать / dar |
| minimum interval | Minimum time between doses | Минимальный интервал между дозами | Tiempo mínimo entre dosis | no default value |
| end / resume | End Course / Resume Course | Закончить курс / Возобновить курс | Terminar / Reanudar tratamiento | ru not «Завершить», which stops a feeding |
| 24 h maximum | Most doses in 24 hours | Не больше доз за 24 часа | Máximo de dosis en 24 horas | optional, never prefilled |
| the newest dose | Last dose | Последняя доза | Última dosis | only the medication's newest dose; any other is a logged dose |
| a dose already in the log | logged dose | отмеченная доза | dosis registrada | claims no order |

Buttons of the feature use Title Case in en ("Log Dose", "End Course").

## Surface rules

- **Status words.** Inside the interval: "Next dose not before 8:10 AM" /
  «Следующая доза — 8:10 или позже» / «Próxima dosis: 8:10 o más tarde».
  After it: "Last dose at 2:10 AM · the 6 h interval has passed". Never
  "allowed", "you can", «можно», «пора». ru and es use "or later" because it
  reads right with a day word in front of the time («завтра, 1:30 или
  позже»), and es avoids the article that changes with the hour («la 1:30»,
  «las 2:30»).
- **The interval is "Interval: 6 h"**, never "every 6 h". It is a minimum,
  not a schedule, and "every 6 h" is how a prescription reads.
- **The same look in both states**: only the words change.
- **The last dose carries its age** ("Last dose at 2:10 AM · 1 h 20 min
  ago"); the next one is a clock time with its day word when it is not
  today. From 48 hours the age is told in days ("3 days ago", «3 дня назад»,
  «hace 3 días»): "73 h ago" would leave the arithmetic to the parent. A dose
  row shows its time with "Today", "Yesterday" or the date.
- **"Last dose" is the newest dose.** "Last dose at", "since the last dose"
  and their ru and es words name only the medication's newest dose, on every
  screen and in the confirmation. Any other dose is a "logged dose".
- **When-strings.** A time that is not today is built with
  `medication.when_yesterday_fmt`, `_tomorrow_fmt` or `_date_fmt`: en puts
  the day after the time ("1:30 AM tomorrow"), ru and es before it
  («завтра, 1:30», «mañana, 1:30»). Every slot that takes a time accepts a
  when-string: after a colon, after "at" or "not before" in en, before
  "or later", inside parentheses. No ru or es slot puts a preposition right
  before a time («в 1:30» breaks as «в завтра, 1:30»).
- **Lines joined by a middle dot are whole templates.** `passed_primary_fmt`,
  `waiting_secondary_ago_fmt`, `waiting_secondary_just_now_fmt` and
  `meta_fmt` each hold both pieces and the dot, so every language orders the
  pieces itself and code adds no word, space or dot. The piece after the dot
  starts in lower case: "Last dose at 2:10 AM · the 6 h interval has passed",
  "120 mg (5 ml) · interval 6 h". `status_ago_fmt` is the dose's age on a
  line of its own (es «Hace 8 h»).
- **The name the parent typed** stands in a nominative slot in Russian
  (first, before a colon, or as a title), as the baby's name does: typed text
  takes no case ending.
- **The safety line** stands at the top of the medication form, on a surface,
  in secondary text, with no icon and no red. It names where the dose and
  the interval come from (the pediatrician or the medication's instructions)
  and that the app does not check them.
- **Placeholders** say what the field holds and where it comes from
  ("Name, as on the package"). None holds a number or a drug name: at night
  a sample value reads as a suggestion. No field has a default interval or
  maximum.
- **The maximum** is a whole number from 1 to 24, or empty. Outside that
  range Save stays off, and `field_max_range_hint` under the field says what
  the field takes and that it may stay empty. The hint does not name Save: it
  shows the moment the value leaves the range and goes when it is fixed, so
  the cause and the button change together on screen.
- **Counts** use the one/few/many keys (`medication.dose_count.*`), never a
  bare number.
- **Line breaks.** A number is glued to its unit with a no-break space
  ("24 hours"), as everywhere. Russian one-letter prepositions and «не» are
  glued to the next word in these strings («с последней», «не проверяет»).
  - «или позже» and «o más tarde» are glued whole, so a line never ends in
    «или» or «o» and «más tarde» never splits.
  - Spanish «de» is glued to the duration after it («intervalo de 6 h»,
    «menos de 6 h»), so the duration never starts a line alone.
  - A range keeps its words together: "1 to 24", «от 1 до 24», «del 1 al 24».
  - A middle dot that joins two pieces ends a line, never opens one (see
    "Joined lines" below). `ended_on_fmt` holds its dot in the key, with the
    no-break space before it.
- **The confirmation** is the system alert. The title is a fact. The message
  has the name and the times, one per line. Buttons: `button.cancel`,
  `button.save`, no "anyway". There are three variants:
  - before: a dose already logged less than the interval earlier;
  - after: a dose logged less than the interval later, for a dose put in the past;
  - the 24 h maximum, which names its own "next dose not before" time.
  When a dose breaks both limits, the alert shows the variant of the limit
  that ends later.
- **A dose put between two logged doses.** When a later dose is logged too,
  at least the interval after this one, the before variant names the earlier
  dose in neutral words: "Less than 6 h after a logged dose" / «Меньше 6 ч
  после отмеченной дозы» / «Menos de 6 h después de una dosis registrada»,
  and "Logged dose at 8:00 AM" / «Отмеченная доза: 8:00» / «Dosis
  registrada: 8:00». The last line stays as in the before variant.
  - Example: doses at 8:00 AM and 4:00 PM, interval 6 h, a dose put at
    10:00 AM. 4:00 PM is exactly 6 h after it, which counts as on time, so
    the check names the 8:00 AM dose. The alert reads "Less than 6 h after a
    logged dose" / "Logged dose at 8:00 AM" / "If you save, next dose not
    before 10:00 PM".
  - Why: the dose sheet's status box under the alert says "Last dose at
    4:00 PM". "Last dose at 8:00 AM" would name a second last dose on the
    same screen, and 8:00 AM + 6 h does not give 10:00 PM. Naming 4:00 PM
    instead would contradict the title, since 10:00 AM is on time against
    it. "Logged dose" is already the after variant's word and claims no
    order.
  - When the later dose is less than the interval after this one, the after
    variant shows, as before.
- **The alert's time is the one after Save.** The before and 24 h variants
  end on the next time the medication's screen shows once this dose is
  saved, and the line says so: "If you save, next dose not before 4:00 PM" /
  «Если сохранить, следующая доза — 16:00 или позже» / «Si guardas, próxima
  dosis: 16:00 o más tarde». After the comma come the words of the status
  line the screen then shows.
  - Why: the alert opens before the dose is saved, and the time as it stood
    before this dose is earlier than the one that holds after it. Last dose
    8:00 AM, this one at 10:00 AM, interval 6 h: before Save the next time is
    2:00 PM, after Save the screen says 4:00 PM. With the 24 h maximum (doses
    at midnight and 8:00 AM, maximum 2, this one at 10:00 AM) it is midnight
    before and 8:00 AM tomorrow after. A parent who saves and follows the
    alert must get the later time.
  - The condition names the button the parent is about to press; Cancel
    keeps the time the screen showed before.
  - The time stays the message's last line in every language: a time that is
    not ahead of now is left out with its line.
  - The line does not say what sets the time. In the before variant the
    24 h maximum can set it: interval 6 h, maximum 3, doses at midnight and
    7:00 AM, this one at 8:00 AM, and under "Less than 6 h since the last
    dose" the next time is midnight tomorrow. Words such as "with your
    interval" would name a limit that is not the one in force.
- **The form's titles.** New: "New Medication" / «Новое лекарство» /
  «Nuevo medicamento». Edit: "Edit Medication" / «Лекарство» / «Editar
  medicamento». ru drops the verb, as «Вопрос» does for an edited question.
  Between the «Отмена» and «Сохранить» buttons the title has about 127 pt at
  the default size: «Новое лекарство» just fills it, and «Изменить
  лекарство» shrank to 0.79. No shorter ru phrase keeps the verb («Правка
  лекарства» needs 135 pt). The filled fields and Save show that the sheet
  is an edit.
- **The reminder.** Title = the name. Body = the time since the last logged
  dose, with that dose's time in parentheses, so it stays true on a phone
  that has not synced yet. No emoji. The day word in the body is computed
  against the time the notification fires, not the time it is scheduled. The
  switch's footer says the notification is for this device only and comes at
  night too, so neither surprises the parent.
- **The report** prints the name and the dose text as the parent wrote them,
  the number of doses and the first and last date. There is no interval, no
  maximum and no mark on an early dose, because in a document for the doctor
  that mark would be a verdict on the parent.
  - A line whose doses carry more than one dose text shows each text with
    its own count and first–last, in order of first use: a caption per text
    on the screen («2.5 ml · 10 doses · Oct 31 – Nov 2»), a PDF row per text
    with the name repeated. The doctor reads the dose beside a count as the
    dose of every dose counted, so one text for all would misstate the
    others.
  - Doses with no dose text, beside doses that have one, are their own
    group: "Dose not written" / «Доза не записана» / «Dosis no anotada». The
    words take the verb of the PDF's Dose head ("Dose (as written)",
    «Доза (как записано)», «Dosis (como se anotó)»), so the cell reads as
    that field left empty.
    - Not "no dose", «без дозы» or «sin dosis»: they read as a dose not given.
    - Not ru «не отмечена» or es «no registrada»: those are the app's words
      for logging, and these doses are logged.
    - Not es «no indicada», which in a medical text reads as "not indicated".
  - A line where no dose has a text shows none, as before.
  - Fit at the default size: the words take about 78 pt of the Dose column's
    142 pt in the PDF, and the ru caption «Доза не записана · 3 дозы ·
    2 нояб. – 3 нояб.» about 264 pt of the card's 338 pt.
- **The paywall** never sells the confirmation or the reminder, which are
  safety facts and free. Medications are free, so `onboarding.premium.f2`
  lists baths, walks and mood only.

## Wiring the keys

- **Arguments.** `%@` takes a string and `%d` an Int. A positional `%1$@`
  means the order differs between languages; pass the arguments in the
  numbered order.
- **Times.** A time today is `appTimeOfDay`. A time on another day is a
  when-string:
  - `medication.when_yesterday_fmt` (time);
  - `medication.when_tomorrow_fmt` (time);
  - `medication.when_date_fmt` (1 = `appDayMonth`, 2 = time).
  - Every slot marked "time" below takes either.
- **The reminder's day word** is computed for the fire date when the
  notification is scheduled. A dose at 22:00 with a 6 h interval fires at
  04:00, so its body reads "(10:00 PM yesterday)".
- **Durations** ("6 h", "1 h 20 min") come from `duration.*`, which carry
  their no-break spaces. The interval chips use `duration.h_only`. An age of
  48 h or more is days: `duration.days.<category>`, whose value holds the
  number and its no-break space.
- **Counts:** `MedicationFormat.doseCount(n)` reads the plural family
  `medication.dose_count.<category>` (CLDR categories, `.other` always), as
  `question.count` does. The result is the "dose count phrase" below.
- **Line C** is the family `medication.count_24h.<category>`, picked by the
  second number, the maximum ("of the 4 you set"):
  `PluralFamily.medicationCount24h.template(max)`, then filled with the dose
  count phrase (`%1$@`) and the maximum (`%2$d`). Every form shows `%2$d`, with
  a plain space on both sides: an "N of M" count is not glued (voice.md
  § Line breaks around numbers).
- **Joined lines** are the whole templates of the surface rules. The space
  before the dot is a no-break space inside the template (`%1$@\u{00A0}· `),
  so at large text sizes the dot stays at the end of the first line instead
  of opening the next one.
- **Existing keys reused:**
  - `button.save`, `button.cancel`, `button.delete` (alerts and sheets);
  - `button.edit` (the detail's toolbar);
  - `form.time`, `form.dose` (the dose sheet; the detail's "Dose" label);
  - `form.notes_optional` (the form's note field);
  - `duration.*`, `duration.days.*`;
  - `event.type.medication` (older history rows).
- **Typed text is not a key.** The medication's name and dose text are
  shown as typed (sheet titles, the detail's first line, row titles), and
  `gluingNumbersToUnits` is not run on them.

### The status lines

| state | line A | line B |
|---|---|---|
| no dose yet | `status_no_doses` | `interval_fmt` |
| inside the interval | `status_next_fmt`(time) | `waiting_secondary_ago_fmt`(time, duration), or `waiting_secondary_just_now_fmt`(time) |
| interval passed | `passed_primary_fmt`(time, interval) | `status_ago_fmt`(duration) |
| next dose tomorrow or later | `status_next_fmt`(when-string) | as inside |
| a maximum set | `status_next_fmt`(the later of the two limits) | as inside; line C `count_24h.<category>`(dose count phrase, maximum) |
| ended | — | `ended_on_fmt`(date, dose count phrase) |

- One-line places (the list row, the Events line, the Home card) show line A only.
- The list row's meta line is `meta_fmt`(dose text, interval), or `interval_fmt` alone when there is no dose text.
- A dose row shows its time with `day_today`, `day_yesterday` or `appDayMonth`.
- `passed_primary_fmt` and the two `waiting_secondary_*` templates take the
  medication's newest dose only, as do the
  alert's `alert_before_title_fmt` and `alert_before_message_fmt`. A
  confirmation that names an older dose uses `alert_between_title_fmt` and
  `alert_between_message_fmt` (see "The alert" below).

### Where the other keys go

- **More row and list:**
  - `title` (the row and the list title), `a11y_hint`;
  - `section_active`, `section_ended_fmt`(count);
  - `add` (the toolbar's VoiceOver label and the empty state's button);
  - `empty_title`, `empty_body`.
- **Detail:**
  - the About card labels: `form.dose`, `field_interval`, `detail_max`, `detail_note`;
  - `detail_doses`, `log_dose` (the pinned footer), `end_course`, `resume_course`.
- **Dose sheet:**
  - `picker_label`, `picker_choose`;
  - `detail_note` (the note's placeholder);
  - `dose_delete`, `dose_edit_title` (VoiceOver and fallback title).
- **Form:**
  - `form_new_title`, `form_edit_title`;
  - `safety_line` (first row of the first group);
  - `field_name` and `field_dose` (VoiceOver labels), with `field_name_placeholder` and `field_dose_placeholder`;
  - `field_interval`, `chip_other`, `other_hours`, `other_minutes`;
  - `field_max` (and `field_max_placeholder` if the field shows one apart from its label);
  - `field_max_range_hint` under the maximum field, in secondary text, while the field holds 0 or 25–99 (Save stays off); not shown while the field is empty or holds 1–24;
  - `delete` (the button and the alert's title), `delete_message` with `button.delete` (destructive) and `button.cancel`.
- **Reminder:**
  - `reminder_switch`, `reminder_at_fmt`(time), `reminder_footer`;
  - `reminder_off_in_settings` with `open_settings` (the link);
  - `a11y_reminder_on` (added to the row's VoiceOver label);
  - `notification.medication_title_fmt`(name);
  - `notification.medication_body_fmt`(interval, dose time).
- **Events form:** `picker_label`, `picker_choose`, `picker_not_listed`.
- **The alert:** one variant per save.
  - before: `alert_before_title_fmt`(interval) and `alert_before_message_fmt`(name, the earlier dose's time, the next time once this dose is saved), when this dose is the newest once saved;
  - before, with a later dose logged (this dose is not the newest once saved): `alert_between_title_fmt`(interval) and `alert_between_message_fmt`(name, the earlier dose's time, the next time once this dose is saved), the same arguments;
  - after: `alert_after_title_fmt`(interval) and `alert_after_message_fmt`(name, the later dose's time, interval);
  - 24 h: `alert_max_title_fmt`(dose count phrase with the new dose) and `alert_max_message_fmt`(name, maximum, the next time once this dose is saved).
  - The next time is the schedule's "not before" with this dose counted, never earlier than the time before it. It is the message's last line, left out when it is not ahead of now.
  - When both limits apply, the variant of the limit that ends later shows. Its time is the one the medication's screen shows after Save. A tie shows the interval variant.
- **VoiceOver:**
  - a label reads the visible lines joined by ". ", plus `a11y_reminder_on`; the Home card's label starts with `title`;
  - hints: `a11y_open_one` (a row, an Events line, the Home card with one medication), `a11y_open_list` (the Home card with two or more), `a11y_dose_hint` (a dose row).
- **Report:**
  - `report_title` (the card header and the PDF h2);
  - a block per medication: the name as the label, the dose count phrase as the value, the dose text as written as the caption, and the report's own date range;
  - more than one dose text on a line: a caption per text, the text · the dose count phrase · the date range, joined as in "Joined lines" (a no-break space before each dot); in the PDF a row per text, with the name repeated;
  - `report_dose_not_written` in place of the text, for the doses with none, only when other doses of the same line have a text (the screen caption and the PDF's Dose cell);
  - `report_without_name` for events with no name;
  - PDF heads `report_col_name`, `report_col_dose`, `report_col_count`, `report_col_dates`.
- **CSV:** `export.csv.medication` and `export.csv.dose` for the two new event columns.

## Safety word list

No `medication.*` or `notification.medication_*` value contains these whole
words (case-insensitive) or an exclamation mark. `MedicationCopyTests` holds
the same list: a word added here is added there.

- en: give, gives, giving, gave, given, allowed, allow, should, must, safe,
  safely, unsafe, recommend…, advise…, too, early, overdose…, warning,
  danger…, time for, you can
- ru: дай, дайте, дать, давать, даём, дали, дадим, дадите, можно, нельзя,
  пора, разреш…, рекоменд…, следует, стоит, должн…, безопасн…, опасн…, рано,
  передозиров…, предупрежд…, внимание, норм…
- es: da, dar, dale, darle, dado, dada, dele, puedes, puede, permitid…,
  debes, debe, debería, conviene, seguro/segura(s), peligr…, recomend…,
  pronto, demasiado, sobredosis, advertencia, toca, es hora

The same test checks that every language has every medication key with the
same arguments, and that no number in these strings is followed by a plain
space. The report's words also pass the pediatrician report's verdict list
(`doctor-report.md`).

## Changes

- 2026-11-03 — 1.3.0 medications: 77 keys added (`medication.*`,
  `notification.medication_*`, `export.csv.medication`, `export.csv.dose`).
  `form.dose` en "Dosage" → "Dose". `onboarding.premium.f2` no longer lists
  medications (they are free).
- 2026-11-03 — `medication.field_max_range_hint` added (the maximum outside
  1 to 24). No-break spaces, text unchanged: ru «или позже» and es «o más
  tarde» glued whole; es «de» glued to the duration after it
  (`status_next_fmt`, the passed-interval and meta short forms, now inside
  `passed_primary_fmt` and `meta_fmt`,
  `alert_before_title_fmt`, `alert_before_message_fmt`,
  `alert_after_title_fmt`, `alert_max_message_fmt`). Ages from 48 h are told
  in days.
- 2026-11-03 — The confirmation's time is the one after Save. The last line
  of `alert_before_message_fmt` and `alert_max_message_fmt` opens with "If
  you save," / «Если сохранить,» / «Si guardas,», and ru names «следующая
  доза» in full (alone, «Следующая» read as the dose being logged).
  Arguments unchanged. `ended_on_fmt` has a no-break space before its dot.
- 2026-11-03 — ru `form_edit_title` «Изменить лекарство» → «Лекарство»,
  so the edit form's title draws at full size between Cancel and Save. The
  alert's next-time line stays neutral on what sets the time.
- 2026-11-03 — `alert_between_title_fmt` and `alert_between_message_fmt`
  added, for a dose put between two logged doses. "Last dose" names only
  the medication's newest dose.
- 2026-11-03 — `report_dose_not_written` added: on a report line, the doses
  with no dose text beside doses that have one.

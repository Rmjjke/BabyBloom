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
  today. A dose row shows its time with "Today", "Yesterday" or the date.
- **When-strings.** A time that is not today is built with
  `medication.when_yesterday_fmt`, `_tomorrow_fmt` or `_date_fmt`: en puts
  the day after the time ("1:30 AM tomorrow"), ru and es before it
  («завтра, 1:30», «mañana, 1:30»). Every slot that takes a time accepts a
  when-string: after a colon, after "at" or "not before" in en, before
  "or later", inside parentheses. No ru or es slot puts a preposition right
  before a time («в 1:30» breaks as «в завтра, 1:30»).
- **Short forms after a middle dot.** `status_passed_short_fmt`,
  `interval_short_fmt` and `ago_fmt` start in lower case, for lines such as
  "Last dose at 2:10 AM · the 6 h interval has passed" or
  "120 mg (5 ml) · interval 6 h". `status_ago_fmt` is the same age on a line
  of its own (es «Hace 8 h»).
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
- **Counts** use the one/few/many keys (`medication.dose_count.*`), never a
  bare number.
- **Line breaks.** A number is glued to its unit with a no-break space
  ("24 hours"), as everywhere. Russian one-letter prepositions and «не» are
  glued to the next word in these strings («с последней», «не проверяет»).
- **The confirmation** is the system alert. The title is a fact. The message
  has the name and the times, one per line. Buttons: `button.cancel`,
  `button.save`, no "anyway". There are three variants:
  - before: a dose already logged less than the interval earlier;
  - after: a dose logged less than the interval later, for a dose put in the past;
  - the 24 h maximum, which names its own "next dose not before" time.
  When a dose breaks both limits, the alert shows the variant of the limit
  that ends later, so its time is the one the medication's screen shows.
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
  their no-break spaces. The interval chips use `duration.h_only`.
- **Counts:** `n.plural(one: "medication.dose_count.one", few: "….few",
  many: "….many")`, then `String(format:)` with `n`, as `question.count.*`.
  The result is the "dose count phrase" below.
- **Joined lines** use " · " and the lower-case short forms
  (`status_passed_short_fmt`, `interval_short_fmt`, `ago_fmt`).
- **Existing keys reused:**
  - `button.save`, `button.cancel`, `button.delete` (alerts and sheets);
  - `button.edit` (the detail's toolbar);
  - `form.time`, `form.dose` (the dose sheet; the detail's "Dose" label);
  - `form.notes_optional` (the form's note field);
  - `duration.*`;
  - `event.type.medication` (older history rows).
- **Typed text is not a key.** The medication's name and dose text are
  shown as typed (sheet titles, the detail's first line, row titles), and
  `gluingNumbersToUnits` is not run on them.

### The status lines

| state | line A | line B |
|---|---|---|
| no dose yet | `status_no_doses` | `interval_fmt` |
| inside the interval | `status_next_fmt`(time) | `status_last_at_fmt`(time) · `ago_fmt`(duration), or · `just_now` |
| interval passed | `status_last_at_fmt`(time) · `status_passed_short_fmt`(interval) | `status_ago_fmt`(duration) |
| next dose tomorrow or later | `status_next_fmt`(when-string) | as inside |
| a maximum set | `status_next_fmt`(the later of the two limits) | as inside; line C `count_24h_fmt`(dose count phrase, maximum) |
| ended | — | `ended_on_fmt`(date, dose count phrase) |

- One-line places (the list row, the Events line, the Home card) show line A only.
- The list row's meta line is the dose text · `interval_short_fmt`, or `interval_fmt` alone when there is no dose text.
- A dose row shows its time with `day_today`, `day_yesterday` or `appDayMonth`.

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
  - `delete` (the button and the alert's title), `delete_message` with `button.delete` (destructive) and `button.cancel`.
- **Reminder:**
  - `reminder_switch`, `reminder_at_fmt`(time), `reminder_footer`;
  - `reminder_off_in_settings` with `open_settings` (the link);
  - `a11y_reminder_on` (added to the row's VoiceOver label);
  - `notification.medication_title_fmt`(name);
  - `notification.medication_body_fmt`(interval, dose time).
- **Events form:** `picker_label`, `picker_choose`, `picker_not_listed`.
- **The alert:** one variant per save.
  - before: `alert_before_title_fmt`(interval) and `alert_before_message_fmt`(name, the earlier dose's time, the next time);
  - after: `alert_after_title_fmt`(interval) and `alert_after_message_fmt`(name, the later dose's time, interval);
  - 24 h: `alert_max_title_fmt`(dose count phrase with the new dose) and `alert_max_message_fmt`(name, maximum, the next time by the maximum).
  - When both limits apply, the variant of the limit that ends later shows. Its time is the one the medication's screen shows. A tie shows the interval variant.
- **VoiceOver:**
  - a label reads the visible lines joined by ". ", plus `a11y_reminder_on`; the Home card's label starts with `title`;
  - hints: `a11y_open_one` (a row, an Events line, the Home card with one medication), `a11y_open_list` (the Home card with two or more), `a11y_dose_hint` (a dose row).
- **Report:**
  - `report_title` (the card header and the PDF h2);
  - a block per medication: the name as the label, the dose count phrase as the value, the dose text as written as the caption, and the report's own date range;
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
space.

## Changes

- 2026-11-03 — 1.3.0 medications: 77 keys added (`medication.*`,
  `notification.medication_*`, `export.csv.medication`, `export.csv.dose`).
  `form.dose` en "Dosage" → "Dose". `onboarding.premium.f2` no longer lists
  medications (they are free).

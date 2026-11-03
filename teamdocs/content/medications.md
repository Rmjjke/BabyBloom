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

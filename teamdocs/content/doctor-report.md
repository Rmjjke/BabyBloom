# Pediatrician report copy

Voice and terms: `voice.md` in this folder. Layout, states and the PDF spec:
`teamdocs/design/m2-doctor-report.md`.

## Who reads it
The parent reads it on screen. The pediatrician reads the PDF, or the screen
held across the desk. Every line on it is one of four things:
- a measurement;
- a date;
- a count;
- the parent's own words.

Nothing on it grades the baby.

## Names
- The event is **Pediatrician visit / Приём у педиатра / Visita al
  pediatra** (`visit.title`), not "doctor visit". Logging it starts the
  report period and closes the asked questions, so a visit to another
  specialist must not count.
- The screen and the More row are **For the pediatrician / Для педиатра /
  Para el pediatra** (`report.title`). The PDF is "Report for the
  pediatrician" (`report.pdf.title`).
- **"Report" names this PDF only** (`voice.md` § Terms). The Export PDF reads
  "All entries" / «Все записи» / «Todos los registros» on its first page and
  in its file name (`export.pdf.subtitle`, `export.file_fmt`), and its tile
  says "Every entry, day by day" (`export.format.pdf_desc`). When both PDFs
  said "report", a parent looking for this one on the Export screen took
  16 pages of tables.
  - The Export screen points here: `export.pdf_doctor_hint_fmt` "For the
    doctor's visit: More › For the pediatrician" / «Для приёма у врача: Ещё ›
    Для педиатра» / «Para la consulta médica: Más › Para el pediatra».
  - The path is joined in code from `tab.more` and `report.title`, so it
    always matches the names it points to. VoiceOver reads ", " in place of
    « › ».
- The button is **Log the visit / Отметить приём / Registrar la visita**
  (`visit.log`): a button names its action, not a fact ("Visit happened").
  Copy that refers to it quotes it by this name.
- "Height", not WHO's "length": the app says height everywhere (stat,
  export columns), so the parent meets one word. Card titles reuse
  `export.cat.*`.
- Breastfeeding is "Breast / Грудь / Pecho" (`feeding.type.breast`), the one
  key for the word: the report reads the app's type name, the word of the
  history's titles too («Левая грудь»). No abbreviation a doctor would have
  to decode. Formula and pumped reuse `feeding.type.*` the same way.
- The app spells it the US way: "pediatrician", "color".

## Lines
- **label: value**, as on the weekly card. The baby's name stands alone on
  its own line (screen ①, PDF header), so in Russian it stays nominative.
- **The percentile is a number**: `report.percentile_weight_fmt`
  "Weight percentile (WHO): 42". There is no band word, tint or ⚠: a band
  ("normal", "below normal") grades the baby, while the number is the
  measurement a doctor plots. It is the same number the Growth screen
  computes.
  - `%@` takes the number or the badge forms `percentile.badge_below3` /
    `_above97` ("< 3", "> 97").
  - It needs no ordinal grammar, unlike today's
    `dashboard.growth.percentile_fmt`.
- **Before the due date there is no percentile**, so one sentence stands in
  for both percentile rows. It says the WHO percentiles **start** from the due
  date: "WHO percentiles start from the due date." / «Перцентили ВОЗ
  начинаются с предполагаемой даты родов.» / "Los percentiles de la OMS
  empiezan en la fecha prevista de parto." It does not say "are calculated
  from", because that reads as corrected age, which the app uses only after
  the due date. A doctor would read it as "there is a percentile, at corrected
  age", which is the opposite of the fact.
  - The screen reads `percentile.before_due_date`. This is the same key as on
    the Growth screen, and it adds a sentence for the parent: the weighings are
    still saved and shown on the chart.
  - The PDF reads `report.pdf.before_due_date`, which is that first sentence
    word for word. The fact reads in the same words on screen and paper.
- **Averages say what they are averaged over**: `report.days_logged_fmt`
  "Averages over the days with entries: %d of %d", in the same words as the
  weekly card's line. A gap in the log reads as a gap, and the "a day" lines
  above it read as averages. The weekly `weekly.days_logged_fmt` hard-codes
  "of 7", so the report has its own key. The report shows the line when a
  day of the period has no entry of that kind, and never in a short period,
  which prints counts.
- **A short period (< 3 days) shows counts, not rates**:
  `report.feeds_count_fmt`, `report.sleep_total_fmt`, `report.wet_count_fmt`,
  `report.dirty_count_fmt`.
- **The weight change is a difference between two dated points**:
  `report.change_since_fmt` "Since 12 Oct: +640 g". It is hidden in the
  newborn window. A small loss just after birth is normal, and a minus there
  reads as a verdict (`DECISIONS.md` 2026-09-05).
- **Counts by type**: `report.type_count_fmt` "%@ %d" joined by " · ", inside
  `report.feeds_by_type_fmt` ("Feeds by type, in total: Breast 120 · Formula
  30") and `report.stool_colors_fmt` ("Dirty by color, in total: Yellow 18 ·
  Green 2").
  - These are totals for the period, and they sit beside "a day" lines. So the
    label names what is counted (feeds, dirty diapers) and says "in total". In
    testing, a reader without that cue read the numbers as ml or per day.
  - There is no warning line, swatch or colour: a stool colour is printed by
    name and count, and the doctor judges it.
- **A count of questions is a word, not a bare number**:
  `question.asked_at_count_fmt` "Asked at the visit on Oct 13 · 2 questions".
  - `%@` is `question.count.one` / `.few` / `.many`, picked by the app's
    one/few/many rule (`Int.plural`).
  - The older `question.asked_at_fmt` (`· %d`) is no longer read by the app.
    It stays in the JSON until every branch that reads it is merged, so that
    no branch reaches main without a key it reads. Then it is deleted.
- **Composed in code, no key**:
  - "value · date" on the height and head rows and in the weighings list (a
    mid-dot between);
  - the period length ("20 days") from `age.*`; a period that starts today
    reads `report.period_today` ("today", lowercase: it follows a mid-dot or
    stands in brackets);
  - the footer "brand · name · period".
- A number never wraps away from its unit: a no-break space (` `),
  `growth.head_fmt` included.
- **Questions** have one state, "Asked". There is no answer field: an answer
  goes in the visit's note. Unchecked questions carry over
  (`visit.carry_over`). Deleting a visit puts its questions back in the list
  (`visit.delete_message`, shown only when the visit has asked questions).

## The footnote
`report.footnote` says where the numbers come from: entered by the parent in the
app, with percentiles from the WHO Child Growth Standards. It ends the screen and
the PDF.

It is not `growth.who_footnote` ("Not a substitute for a doctor's
examination"). That line is written for the parent, and here a doctor reads it.

Each language uses its natural generic:
- en "the parent";
- ru «родителями»;
- es "aportados por la familia", the usual Spanish clinical phrase. The PDF's
  `report.pdf.questions` matches: "Questions from the parent" / «Вопросы
  родителей» / "Preguntas de la familia".

The brand follows the locale: Bitty / «Ночка» (nominative after «в
приложении») / Nenita.

## The closed no-verdict list — the test list
`BabyBloomTests/DoctorReportPDFTests.swift` scans the rendered PDF HTML in en,
ru and es, in every report state. None of the keys or words below may appear
in it. The screen reads the same keys as the PDF, except the parent's
sentences, which have a `report.pdf.*` twin.

**Keys.** The test reads each value from the JSON of the language under test.
For a key with placeholders, it scans the longest fixed stretch between them.
- Percentile bands: `percentile.normal`, `percentile.below_normal`,
  `percentile.above_normal`, `percentile.very_low`, `percentile.very_high`,
  `percentile.below3`, `percentile.above97`. The badges
  `percentile.badge_below3` / `_above97` are allowed, because they are the
  number.
- Gain against the reference: `velocity.below`, `velocity.within`,
  `velocity.above`, `velocity.expected_fmt`, `nutrition.status_below`,
  `nutrition.status_within`, `nutrition.status_above`, `breakdown.title`,
  `breakdown.gain_fmt`, `breakdown.feeds_fmt`, `breakdown.nappies_fmt`,
  `breakdown.disclaimer`.
- Centile trend: `trend.stable`, `trend.crossing_up`, `trend.drop_fmt`.
- First weeks: `newborn.regained`, `newborn.not_regained`,
  `newborn.flag_loss`, `newborn.flag_not_regained`.
- Diapers: `diaper.color.warning`, `diaper.norm.fmt`, `diaper.norm.label`,
  `diaper.norm.hint`, `stat.daily_norm`. The goal is the parent's setting, not
  a measurement.
- Wrong reader: `growth.who_footnote`.
- The parent's sentence: `percentile.before_due_date`, as a whole value (both
  sentences). The PDF prints only its first sentence, through
  `report.pdf.before_due_date`.

**Words.** Whole words, case-insensitive, regex per language:
- en: `normal|abnormal|low|high|too|enough|only|good|poor|worry|concern|warning|should|risk|healthy|behind|ahead`
- ru: `норм\w*|мало|много|слишком|достаточно|недостаточно|хорошо|плохо|тревож\w*|опасн\w*|риск\w*|следует|стоит`
- es: `normal\w*|bajo|baja|alto|alta|demasiado|suficiente|insuficiente|solo|bien|mal|preocup\w*|riesgo|debería|conviene`
- the symbol ⚠.

The parent's own notes and questions print verbatim and are allowed, so the
test's seed data must keep them free of these words. Any new verdict key added
anywhere in the app joins this list in the same PR.

Every `report.*`, `visit.*` and `question.*` value passed this scan on
2026-11-01, checked by script. The values changed on 2026-11-03 pass it too,
and so do `report.pdf.chart_title` and `.chart_curves` (2026-11-05).

## Keys
- **Header:** `report.title`, `report.a11y_hint` (More row),
  `report.since_visit_fmt` / `report.since_birth_fmt` (period + length),
  `report.period_today` (the length on a same-day period),
  `report.age_corrected_fmt`, `report.no_visit_hint`,
  `report.new_period_fmt`, `report.a11y_period_hint`.
- **Growth:**
  - `report.weight_fmt`, `report.height_fmt`, `report.percentile_weight_fmt`,
    `report.percentile_height_fmt`, `report.change_since_fmt`,
    `report.weighings`, `report.show_all_fmt`, `report.at_birth_fmt`,
    `report.empty_growth` (+ ↺ `growth.add_weighing`);
  - ↺ `growth.head_fmt`, `percentile.as_of_fmt`, `percentile.before_due_date`,
    `percentile.out_of_range`, `percentile.badge_*`.
- **Feeding:**
  - ↺ `weekly.feeds_fmt`;
  - `report.feeds_by_type_fmt`, `report.type_count_fmt`
    (+ ↺ `feeding.type.breast` / `.formula` / `.pumped`), `report.bottle_a_day_fmt`,
    `report.breastfeed_avg_fmt`, `report.days_logged_fmt`.
- **Sleep:** ↺ `weekly.sleep_fmt`, `weekly.longest_sleep_fmt`, `duration.*`.
- **Diapers:** `report.wet_a_day_fmt`, `report.dirty_a_day_fmt`,
  `report.stool_colors_fmt` (+ ↺ `diaper.color.*`).
- **Short period:** `report.feeds_count_fmt`, `report.sleep_total_fmt`,
  `report.wet_count_fmt`, `report.dirty_count_fmt`.
- **Empty:** `report.empty_feeding_fmt`, `report.empty_sleep_fmt`,
  `report.empty_diapers_fmt`; the PDF's `report.pdf.no_entries`.
- **Card titles:** ↺ `export.cat.growth` / `.feeding` / `.sleep` / `.diapers`;
  `question.section`.
- **Questions:** `question.add`, `question.new_title` / `question.title` (sheet,
  new / edit), `question.placeholder`, `question.empty`, `question.asked`,
  `question.not_asked` (VoiceOver value and hint of the toggle),
  `question.asked_at_count_fmt` (date · count) with `question.count.one` /
  `.few` / `.many`, `question.back_to_list`, `question.delete`; `button.edit`
  (new, generic).
- **Visit:** `visit.title` (sheet title, Events row), `visit.log`, `visit.date`,
  `visit.questions_header`, `visit.carry_over`, `visit.asked_here`,
  `visit.delete`, `visit.delete_title`, `visit.delete_message`;
  ↺ `form.notes_optional`, `button.save` / `button.cancel` / `button.delete`.
- **PDF:**
  - `report.pdf.title`, `.birth_fmt`, `.age_fmt`, `.sex_fmt` (value ↺
    `baby.gender.*`), `.due_fmt`, `.period_fmt` (range ↺ `weekly.range_fmt` +
    length), `.date_fmt`, `.questions`, `.no_entries`, `.page_fmt`,
    `.file_fmt`;
  - `.before_due_date`, the first sentence of `percentile.before_due_date`
    word for word;
  - the weight-for-age section's heading, one line: `.chart_title` "Weight
    for age" / «Вес по возрасту» / «Peso para la edad», then « · » and
    `.chart_curves` "WHO percentiles" / «перцентили ВОЗ» / «percentiles de la
    OMS», lowercase because it follows the mid-dot. The heading lists no
    percentile numbers: the curves carry «3», «50», «97» at their ends, and
    «3, 50, 97» reads as a decimal in Russian and Spanish;
  - the footer of every export PDF, `export.generated_by_fmt` (brand, date);
  - table heads ↺ `export.col.date` / `.weight` / `.height` / `.head`;
  - `report.footnote`.
- **VoiceOver:** `report.a11y_share`, `report.a11y_period_hint`; the question
  row hint reuses `button.edit`.

## Changes
- 2026-11-01 — the report, the visit sheet and detail, questions, the PDF, the
  closed word list; `growth.head_fmt` gets its no-break space.
- 2026-11-01 — `report.period_today`. Events' «Delete History» gets its own
  confirm, `confirm.delete_message_events` / `_events_hidden`.
  - The reason: it deletes events but keeps pediatrician visits, which also
    show as rows on Events. The shared `confirm.delete_message_all` ("All
    records will be deleted") would over-warn there.
  - Like the shared pair, the `_hidden` variant is for when the free window
    hides rows; the plain one is for the rest. Both name the kept visits,
    because a parent sees them in the same list.
- 2026-11-02 — `export.generated_by_fmt`, `report.pdf.before_due_date`.
  - The breastfeed line is a median, so its label says "typical", not
    "average": "Typical breastfeed" / «Кормление грудью обычно» / "Toma de
    pecho habitual". The key keeps its old name `report.breastfeed_avg_fmt`,
    because keys are never renamed. "Normal" stays out: it is on the closed
    list.
  - en `duration.h_min` / `h_only` get spaces, "7 h 42 min", the same form as
    ru, es and "15 min".
- 2026-11-02 — `question.asked_at_count_fmt` and `question.count.*`: the
  question count is a word. The "in total" labels on the counts by type.
- 2026-11-03 — `report.pdf.before_due_date` is now the first sentence of
  `percentile.before_due_date` word for word, in en, ru and es ("start from
  the due date"). Before, screen and paper said one fact with two verbs. The
  ru `percentile.before_due_date` second sentence now says what en and es
  say: «До этой даты взвешивания всё равно сохраняются и видны на графике».
  The old one claimed something is counted from the due date in the
  meantime, and promised for later what the chart already shows.
- 2026-11-04 — `report.days_logged_fmt` takes the weekly line's words,
  "Averages over the days with entries: %d of %d" / «Среднее по дням с
  записями: %d из %d» / «Promedio de los días con registros: %d de %d». Its
  "a day" lines are averages too, and the line under them now says so.
- 2026-11-04 — The four percentile band labels (`percentile.3_15` …
  `percentile.85_97`) leave the closed list: their keys are deleted, because
  the growth card now states the percentile itself and nothing reads them.
- 2026-11-05 — The app names a breast feed with the report's word, "Breast /
  Грудь / Pecho", in place of the abbreviation BF / ГВ / LM, so the screen,
  the export and the report say one word.
- 2026-11-05 — "Report" names the pediatrician's PDF only (§ Names). The
  Export PDF's tile, first page and file name say "Every entry, day by day"
  and "All entries", and the Export screen points to this report with
  `export.pdf_doctor_hint_fmt`. New `report.pdf.chart_title` and
  `report.pdf.chart_curves` head the weight-for-age section.

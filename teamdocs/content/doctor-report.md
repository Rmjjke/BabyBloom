# Pediatrician report copy

Owner: content. Voice and terms: `voice.md` in this folder. Layout, states
and the PDF spec: `teamdocs/design/m2-doctor-report.md` (Design). The
decisions: milestone m2-doctor-visit-report plan v2 (decisions 2, 5, 7, 9).

## Who reads it
The parent reads it on screen. The pediatrician reads the PDF, or the screen
held across the desk. Every line on it is one of four things:
- a measurement;
- a date;
- a count;
- the parent's own words.

Nothing on it grades the baby.

## Names (plan v2, decision 2)
- The event is **Pediatrician visit / Приём у педиатра / Visita al
  pediatra** (`visit.title`), not "doctor visit". Logging it starts the
  report period and closes the asked questions, so a visit to another
  specialist must not count.
- The screen and the More row are **For the pediatrician / Для педиатра /
  Para el pediatra** (`report.title`). The PDF is "Report for the
  pediatrician" (`report.pdf.title`).
- The button is **Log the visit / Отметить приём / Registrar la visita**
  (`visit.log`): a button names its action, not a fact ("Visit happened").
  Copy that refers to it quotes it by this name.
- "Height", not WHO's "length": the app says height everywhere (stat,
  export columns), so the parent meets one word. Card titles reuse
  `export.cat.*`.
- Breastfeeding is "Breast / Грудь / Pecho" (`report.type_breast`). The
  app's `feeding.type.breast` is an abbreviation (BF / ГВ / LM), which a doctor
  must not have to decode. Formula and pumped reuse `feeding.type.*`.
- The app spells it the US way: "pediatrician", "color".

## Lines
- **label: value**, as on the weekly card. The baby's name stands alone on
  its own line (screen ①, PDF header), so in Russian it stays nominative.
- **The percentile is a number** (decision 7): `report.percentile_weight_fmt`
  "Weight percentile (WHO): 42".
  - `%@` takes the number or the badge forms `percentile.badge_below3` /
    `_above97` ("< 3", "> 97").
  - It needs no ordinal grammar, unlike today's
    `dashboard.growth.percentile_fmt`.
- **Averages say what they are averaged over**: `report.days_logged_fmt`
  "Days with entries: %d of %d" (D19). A gap in the log reads as a gap. The
  weekly `weekly.days_logged_fmt` hard-codes "of 7", so the report has its own
  key.
- **A short period (< 3 days) shows counts, not rates**:
  `report.feeds_count_fmt`, `report.sleep_total_fmt`, `report.wet_count_fmt`,
  `report.dirty_count_fmt`.
- **The weight change is a difference between two dated points**:
  `report.change_since_fmt` "Since 12 Oct: +640 g". It is hidden in the
  newborn window (D17).
- **Counts by type**: `report.type_count_fmt` "%@ %d" joined by " · ", inside
  `report.feeds_by_type_fmt` ("By type: Breast 120 · Formula 30") and
  `report.stool_colors_fmt` ("Stool colors: Yellow 18 · Green 2"). There is no
  warning line, swatch or colour (decision 9).
- **Composed by Dev, no key**:
  - "value · date" on the height and head rows and in the weighings list (a
    mid-dot between);
  - the period length ("20 days") from `age.*`; a period that starts today
    reads `report.period_today` ("today", lowercase: it follows a mid-dot or
    stands in brackets);
  - the footer "brand · name · period".
- A number never wraps away from its unit: a no-break space (` `),
  `growth.head_fmt` included.
- **Questions** have one state, "Asked" (decision 5). Unchecked questions
  carry over (`visit.carry_over`). Deleting a visit puts its questions back in
  the list (`visit.delete_message`, shown only when the visit has asked
  questions).

## The footnote (decision 9)
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

## The closed no-verdict list — the test list (decision 9)
Dev's PDF test (m2-report-pdf) scans the rendered report in en, ru and es: the
screen strings and the PDF HTML. None of the keys or words below may appear.

**Keys.** The test reads each value from the JSON of the language under test.
For a key with a placeholder, it scans the fixed text before the first
placeholder.
- Percentile bands: `percentile.normal`, `percentile.below_normal`,
  `percentile.above_normal`, `percentile.very_low`, `percentile.very_high`,
  `percentile.below3`, `percentile.3_15`, `percentile.15_50`,
  `percentile.50_85`, `percentile.85_97`, `percentile.above97`. The badges
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

**Words.** Whole words, case-insensitive, regex per language:
- en: `normal|abnormal|low|high|too|enough|only|good|poor|worry|concern|warning|should|risk|healthy|behind|ahead`
- ru: `норм\w*|мало|много|слишком|достаточно|недостаточно|хорошо|плохо|тревож\w*|опасн\w*|риск\w*|следует|стоит`
- es: `normal\w*|bajo|baja|alto|alta|demasiado|suficiente|insuficiente|solo|bien|mal|preocup\w*|riesgo|debería|conviene`
- the symbol ⚠.

The parent's own notes and questions print verbatim and are allowed, so the
test's seed data must keep them free of these words. Any new verdict key added
anywhere in the app joins this list in the same PR.

Every `report.*`, `visit.*` and `question.*` value passes this scan today
(content check script, 2026-11-01).

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
  - `report.feeds_by_type_fmt`, `report.type_count_fmt`, `report.type_breast`
    (+ ↺ `feeding.type.formula` / `.pumped`), `report.bottle_a_day_fmt`,
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
  `question.asked_at_fmt` (date · count), `question.back_to_list`,
  `question.delete`; `button.edit` (new, generic).
- **Visit:** `visit.title` (sheet title, Events row), `visit.log`, `visit.date`,
  `visit.questions_header`, `visit.carry_over`, `visit.asked_here`,
  `visit.delete`, `visit.delete_title`, `visit.delete_message`;
  ↺ `form.notes_optional`, `button.save` / `button.cancel` / `button.delete`.
- **PDF:** `report.pdf.title`, `.birth_fmt`, `.age_fmt`, `.sex_fmt` (value ↺
  `baby.gender.*`), `.due_fmt`, `.period_fmt` (range ↺ `weekly.range_fmt` +
  length), `.date_fmt`, `.questions`, `.no_entries`, `.page_fmt`, `.file_fmt`;
  table heads ↺ `export.col.date` / `.weight` / `.height` / `.head`;
  `report.footnote`.
- **VoiceOver:** `report.a11y_share`, `report.a11y_period_hint`; the question
  row hint reuses `button.edit`.

## Changes
- 2026-11-01 — the report, the visit sheet and detail, questions, the PDF, the
  closed word list; `growth.head_fmt` gets its no-break space.
- 2026-11-01 — `report.period_today`. Events' «Delete History» gets its own
  confirm, `confirm.delete_message_events` / `_events_hidden`, because it
  deletes events but keeps pediatrician visits, which also show as rows on
  Events. The shared `confirm.delete_message_all` ("All records will be
  deleted") would over-warn there. Like the shared pair, the `_hidden`
  variant is for when the free window hides rows; the plain one is for the
  rest. Both name the kept visits, because a parent sees them in the same
  list.

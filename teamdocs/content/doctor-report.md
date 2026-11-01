# Pediatrician report copy

Owner: content. Voice and terms: `voice.md` in this folder. Layout, states
and the PDF spec: `teamdocs/design/m2-doctor-report.md` (Design). The
decisions: milestone m2-doctor-visit-report plan v2 (decisions 2, 5, 7, 9).

## Who reads it
The parent reads it on screen. The pediatrician reads the PDF, or the screen
held across the desk. Every line on it is a measurement, a date, a count, or
the parent's own words. Nothing on it grades the baby.

## Names (plan v2, decision 2)
- The event is **Pediatrician visit / Приём у педиатра / Visita al
  pediatra** (`visit.title`), not "doctor visit". Logging it starts the
  report period and closes the asked questions, so a visit to another
  specialist must not count.
- The screen and the More row are **For the pediatrician / Для педиатра /
  Para el pediatra** (`report.title`). The PDF is "Report for the
  pediatrician" (`report.pdf.title`).
- The action is **Log the visit / Отметить приём / Registrar la visita**
  (`visit.log`). Copy that refers to it quotes it by this name.
- "Height", not WHO's "length": the app says height everywhere (stat,
  export columns), so the parent meets one word.
- The app spells it the US way, "pediatrician".

## Lines
- **label: value**, as on the weekly card. The baby's name sits in a value
  slot (`report.pdf.name_fmt` "Name: %@"), so in Russian it stays nominative.
- **The percentile is a number** (decision 7): `report.percentile_weight_fmt`
  "Weight percentile (WHO): 42". `%@` takes the number or the badge forms
  `percentile.badge_below3` / `_above97` ("< 3", "> 97"). It needs no ordinal
  grammar, unlike today's `dashboard.growth.percentile_fmt`.
- **Averages say what they are averaged over**: `report.days_logged_fmt`
  "Days with entries: %d of %d" (D19). A gap in the log reads as a gap. The
  weekly `weekly.days_logged_fmt` hard-codes "of 7", so the report has its own key.
- A number never wraps away from its unit: a no-break space (` `),
  `growth.head_fmt` included (fixed here).
- **Questions** have one state, "Asked" (decision 5). Unchecked questions
  carry over (`visit.carry_over`). Deleting a visit puts its questions back
  in the list (`visit.delete_message`).

## The footnote (decision 9)
`report.footnote` states where the numbers come from: entered by the parent in
the app, percentiles from the WHO Child Growth Standards.

It is not `growth.who_footnote` ("Not a substitute for a doctor's
examination"): that line is written for the parent, and here a doctor reads it.

Each language uses its natural generic: en "the parent", ru «родителями», es
"aportados por la familia" (the usual Spanish clinical phrase). The brand
follows the locale: Bitty / «Ночка» (nominative after «в приложении») / Nenita.

## The closed no-verdict list — the test list (decision 9)
Dev's PDF test (m2-report-pdf) scans the rendered report, screen strings and
PDF HTML, in en, ru and es. Neither the keys nor the words below may appear.

**Keys.** The test reads each value from the JSON of the language under test.
For a key with a placeholder, it scans the fixed text before the first
placeholder.
- Percentile bands: `percentile.normal`, `percentile.below_normal`,
  `percentile.above_normal`, `percentile.very_low`, `percentile.very_high`,
  `percentile.below3`, `percentile.3_15`, `percentile.15_50`,
  `percentile.50_85`, `percentile.85_97`, `percentile.above97`. The badges
  `percentile.badge_below3` / `_above97` are allowed: they are the number.
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

The parent's own notes and questions are printed verbatim and are allowed, so
the test's seed data must keep them free of these words. A new verdict key
added anywhere in the app joins this list in the same PR.

## Keys
Part 1 (layout-free, 2026-11-01):
- `report.title`, `report.a11y_hint`, `report.since_visit_fmt`,
  `report.since_birth`, `report.no_visit_hint`, `report.days_logged_fmt`,
  `report.percentile_weight_fmt`, `report.percentile_height_fmt`,
  `report.footnote`;
- `report.pdf.title`, `.name_fmt`, `.birth_fmt`, `.age_fmt`, `.sex_fmt`
  (value: `baby.gender.*`), `.period_fmt` (value: `weekly.range_fmt`),
  `.date_fmt`, `.page_fmt`;
- `visit.title`, `.log`, `.date`, `.questions_header`, `.carry_over`,
  `.delete_title`, `.delete_message`;
- `question.section`, `.add`, `.title`, `.placeholder`, `.empty`, `.asked`,
  `.not_asked` (VoiceOver value of the checkbox), `.asked_at_fmt`,
  `.delete_title`.

Reused, not duplicated: `form.notes_optional` (visit note), `button.save` /
`button.delete` / `button.cancel`, `growth.head_fmt`, `percentile.as_of_fmt`,
`percentile.before_due_date`, `percentile.out_of_range`,
`growth.corrected_age_fmt`, `weekly.range_fmt`, `weekly.feeds_fmt`,
`weekly.sleep_fmt`, `weekly.longest_sleep_fmt`, `velocity.per_week_fmt`,
`duration.*`, `diaper.color.*`, `export.button`.

Part 2 waits on the Designer's DRAFT: section titles, the row formats (feeding
split, bottle volume, wet / dirty a day, stool colours by count), empty
lines per section, the short-period line, the period length phrase, the
weighings list, the Events read-only row hint.

## Changes
- 2026-11-01: part 1 (names, questions, visit sheet, PDF header and
  footer, footnote, closed word list); `growth.head_fmt` gets its no-break
  space.

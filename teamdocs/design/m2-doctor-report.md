# M2 — For the pediatrician: report, visit sheet, questions, PDF (design note)

status: final — card `m2-report-design`, 2026-11-01; DRAFT 7f4f161 read by the Manager, § 10's five decisions accepted under D35 the same day
decisions: D14 (WCAG 2.2 AA), D17 (no gain number in the newborn window), D19 (averages over days with entries), D35 (Manager decides); plan v2 decisions 1–11 (`.team/desk/milestones/m2-doctor-visit-report/plan.md`); DECISIONS.md 2026-09-05 (doctor-facing = measurements; empty state names the thing + offers the action; a count above reference is never an alarm), 2026-09-01 (a gated control shows its padlock), 2026-10-28 (primary action never inside the scroll), 2026-10-30 (numbers in the app language)
reference: `teamdocs/design/design-system.md` (P = principle); the weekly card note `m1-weekly-summary.md` (row style, AX2 stacking); Content's inventory `reviews/content.md`
triggers: a section or row added to or removed from the report; a state added; the visit or question model changed; the PDF page layout changed; a plan v2 decision (1–11) changed
check: `grep -c '"report\.' BabyBloom/Resources/Localization/en.json` vs the key roles in § 8 once `m2-report-copy` lands; `grep -n 'stethoscope' BabyBloom/App/MainTabView.swift` (the More row, § 1)

Drawn by hand (`ios: none`). Sizes are targets, to be checked on the first render.
Copy in the wireframes is **working text**: Content owns every final string (`m2-report-copy`).
Names follow Content: the screen is **For the pediatrician / Для педиатра / Para el pediatra**, the visit is **Pediatrician visit / Приём у педиатра / Visita al pediatra**.

## 1. Entry

- **One row in More's first group, directly after «Рост»** (`MainTabView.swift:113`), in the same row view as Growth / Recent activity / Events.
  - Label: the screen title.
  - Glyph: `stethoscope`.
- No Dashboard surface, no badge, no "visit soon" banner (plan v2 decision 3). The app does not know the next visit's date.
- No second entry from Growth.
- Adding a question at 3 a.m. takes 3 taps: More → For the pediatrician → Add a question.

## 2. The screen

`ScrollView` on BBBackground, cards `bbCard()` (surface, radius md, `card` shadow), padding md 16, cards md 16 apart, rows sm 8 apart. Named `BBTheme.Typography` only. iPad: the content column has a max width of 600 pt, leading.

```
┌ nav: ‹ More        For the pediatrician          [⇪🔒] ┐   ⑩ share = PDF (padlock when free)
│                                                        │
│ Mia                                                    │   ① name
│ Since the visit on 12 Oct · 20 days  ›                 │   ② period line → visit detail (§ 3.3)
│ 2 months (corrected: 5 weeks)                          │   ③ age line
│                                                        │
│ ┌ ? Questions for the pediatrician ───────────────────┐ │   ④ questions card (§ 3.1)
│ │ Is it fine that she sleeps on her tummy?          › │ │
│ │ When can we start a bath every day?               › │ │
│ │ + Add a question                                    │ │
│ │ ─────────────────────────────────────────────────── │ │
│ │ [ Visit happened ]                                  │ │   ⑤ opens the visit sheet (§ 3.2)
│ │ Asked at the visit on 12 Oct · 2              ⌄     │ │   ⑥ last visit's asked list, collapsed
│ └─────────────────────────────────────────────────────┘ │
│ ┌ ⌇ Growth ───────────────────────────────────────────┐ │   ⑦ data cards (§ 2.1)
│ │ Weight: 5.42 kg                                     │ │
│ │ Weighed on 28 Oct                                   │ │
│ │ Weight percentile (WHO): 42                         │ │
│ │ Length: 58 cm  ·  28 Oct                            │ │
│ │ Length percentile (WHO): 35                         │ │
│ │ Head: 39 cm  ·  28 Oct                              │ │
│ │ Since 12 Oct: +640 g                                │ │
│ │ Weighings                                           │ │
│ │ 28 Oct  5.42 kg · 21 Oct  5.20 kg · …    Show all 9 │ │
│ └─────────────────────────────────────────────────────┘ │
│ ┌ ♥ Feeding ┐  ┌ ☾ Sleep ┐  ┌ 💧 Diapers ┐  (stacked, one per row)
│                                                        │
│ Entered by the parent. Percentiles: WHO Child Growth    │   ⑧ provenance (caption)
│ Standards.                                             │
└────────────────────────────────────────────────────────┘
```

| # | element | spec |
|---|---|---|
| ① | name | `Typography.title2`, BBTextPrimary |
| ② | period line | `Typography.callout`, BBTextSecondary. Two forms: «Since the visit on 12 Oct · 20 days» or «Since birth · 2 months». With a visit, the whole line is a button with a chevron `›` and opens the visit detail (§ 3.3); hit ≥ 44 pt high. With no visit it is plain text |
| ③ | age line | `Typography.caption`, BBTextSecondary. Today's age in the Growth screen's phrase; for a preterm baby "(corrected: …)" is added. It is a fact for the doctor and does not repeat ② (② counts the period, ③ the baby) |
| ④ | questions card | § 3.1. **Above the data**, because the screen is the parent's tool: questions are the one part they write into, and they are the first thing said at a visit. The PDF puts them last (§ 5) because the PDF is the doctor's record |
| ⑤ | Visit happened | a bordered full-width button, `Typography.callout` semibold, BBPrimary text and border, min 44 high. It lives in the questions card because the sheet it opens is mostly ticking questions. It shows even with no open questions, because it also closes the period |
| ⑥ | asked list | a disclosure row «Asked at the visit on 12 Oct · 2», `caption` BBTextSecondary with a chevron; collapsed by default. Expanded: each asked question in `callout` BBTextSecondary with a `checkmark` 13 pt BBTextSecondary. Swipe (and an accessibility action): «Back to open». Only the **latest** visit's questions; older ones are in that visit's detail (§ 3.3). Hidden when that visit asked none |
| ⑦ | data cards | § 2.1 |
| ⑧ | provenance | `Typography.caption`, BBTextSecondary, after the last card: the same footnote as the PDF (plan v2 decision 9). Content's key |
| ⑩ | share | toolbar `square.and.arrow.up`; makes the PDF and opens the share sheet. Free user: a padlock badge on the button (the 2026-09-01 rule), and a tap opens the paywall. VoiceOver: «Share PDF», plus «Premium» when locked (`bbLockedAccessibility`) |

There is no pinned footer. The screen is read, not acted on. The PDF is always visible in the bar, and «Visit happened» sits in the card that is first under the header, so it is reachable at AX2 without a long scroll (the 2026-10-28 rule).

### 2.1 Data cards — rows

Each card has a header row with a glyph and the title. The glyph is 15 pt `@ScaledMetric(relativeTo: .callout)` in the category tint (BBGrowth / BBFeeding / BBSleep / BBDiaper). It is **decorative**: the title names the section (as on the weekly card). The title is `Typography.title3` BBTextPrimary with the header trait.

The rows are **label: value in one Text**: label `Typography.callout` + value `Typography.metricSmall`, both BBTextPrimary. Secondary lines (dates, days lines) are `Typography.caption` BBTextSecondary. Every number goes through `appDecimal` / `appRate` with an NBSP before its unit (DECISIONS 2026-10-30). No colour on any value. No arrows. No band word.

| card | row | source / rule |
|---|---|---|
| Growth | Weight: 5.42 kg + «Weighed on 28 Oct» | the latest weighing at or before now (any date: the doctor wants the latest even when it is older than the period); reuse `percentile.as_of_fmt` |
| | Weight percentile (WHO): 42 | `WHOGrowthStandard.percentileReading` for that weighing. Number only (plan v2 decision 7). Preterm before the due date → the `percentile.before_due_date` sentence in `caption` instead of the row. Past 24 months → the out-of-range sentence |
| | Length: 58 cm · 28 Oct | the latest height. Percentile row as for weight, from Dev's length table (`m2-who-length`) |
| | Head: 39 cm · 28 Oct | `growth.head_fmt`; no percentile |
| | Since 12 Oct: +640 g | latest weight − the base weight, where the base is the latest weighing at or before the period start (the visit's own weighing, if logged), else the first weighing in the period. The base date is printed, so the doctor sees which two points it compares. **Hidden in the newborn window** (D17) and when only one weighing exists. A sign, no colour, no "per week" |
| | Weighings | the period's weighings, newest first, one per line: date · weight (· length when logged that day). The last 6 show; «Show all N» expands **in place** (plan v2 said "All weighings →"; in place keeps the context and does not depend on Growth's layout). The PDF prints all |
| | At birth: 3.40 kg · 51 cm | a `caption` line at the end, from the birth measurement (DECISIONS 2026-09-05 birth-day measurement); absent when unknown |
| Feeding | Feeds a day: 7.4 | `weekly.feeds_fmt`, averaged over days with feeding entries (D19) |
| | Breast 120 · Formula 30 · Pumped 12 | counts over the period, only the types logged, and **only when more than one type** was logged (one fact once: with breast only, the line adds nothing). The type words are the app's `feeding.type.*` (en Pumped, ru Сцеженное, es Extraída), with no report-only key: one word for one thing, the word the parent logs with (Manager, design review 2026-11-02) |
| | Bottle a day: 480 ml | formula + expressed volume, averaged over days with bottle entries; only when volumes exist |
| | Breastfeed: 18 min (Content's word for a median, e.g. «usually») | the **median** duration of finished breastfeeds (with an even count, the mean of the two middle values); only when breastfeeds exist. Not the mean: one forgotten timer moves a mean, never the median (Manager, design review 2026-11-02; supersedes "on average" in § 8 and § 10 item 5) |
| | Days with entries: 18 of 20 | only when N < M (D19) |
| Sleep | Sleep a day: 14 h 20 min | `weekly.sleep_fmt`, finished sleeps; a sleep that crosses the period start counts by its part inside (plan v2 decision 6) |
| | Longest sleep: 5 h 10 min · 24 Oct | `weekly.longest_sleep_fmt` + the date in `caption` |
| | Days with entries | as Feeding |
| Diapers | Wet a day: 7.1 · Dirty a day: 3.2 | two rows; `both` counts in both (as on the Diapers tab) |
| | Stool colours: Yellow 18 · Green 2 | name + count, most frequent first; colour names from `diaper.color.*`. **No swatch, no warning line, no red** (plan v2 decision 9, Content's list). Absent when no colour was logged |
| | Days with entries | as Feeding |

Running timers are not counted (plan v2 decision 6), and nothing on screen says so: a running feed has no number yet.

**AX2** (`dynamicTypeSize >= .accessibility1`), as on the weekly card:
- every label: value row stacks into a label line and a value line;
- the weighings go one per line, date over value;
- the counts line «Breast 120 · Formula 30 · …» wraps between items, never inside "120 · Formula" — Dev builds it from separate `Text`s in a flow layout or one Text with NBSP inside each item;
- a number never splits from its unit (NBSP).

## 3. Questions, the visit sheet, the visit detail

### 3.1 Questions card (④)

- **Open questions**, oldest first, so they are asked in the order they came up. Each row:
  - the full text in `Typography.body` BBTextPrimary, wrapped, no line limit; a chevron `›`;
  - row ≥ 44 high, divider between rows;
  - tap → the question sheet in edit mode;
  - swipe → Delete, which needs no confirm because a question is cheap to retype. VoiceOver gets the same as an accessibility action.
- **«Add a question»** row: a `plus.circle.fill` glyph 17 pt BBPrimary + the label in `callout` semibold BBPrimary, ≥ 44 high. It opens the question sheet.
- **Empty** (no open questions): Content's empty line in `callout` BBTextSecondary, then «Add a question», then «Visit happened».
- **Question sheet** (`.medium` and `.large` detents):
  - Nav: Cancel / Save. Save is disabled while the text is empty after trimming.
  - One multi-line `TextField(axis: .vertical)` with Content's placeholder, focused on appear so the keyboard is up at once.
  - Edit mode adds a destructive «Delete question» at the bottom.
  - Save/Cancel in the nav bar are always visible, so the 2026-10-28 rule holds at AX2 with the keyboard up.

### 3.2 Visit sheet («Visit happened», ⑤)

```
┌ Cancel      Pediatrician visit        Save ┐
│ Date                          [ 1 Nov 2026 ]│  compact DatePicker, ≤ today, ≥ birth date
│ ┌──────────────────────────────────────────┐│
│ │ Note (optional)                          ││  multi-line, Content's placeholder
│ └──────────────────────────────────────────┘│
│ Questions asked                             │  section header
│ ✓ Is it fine that she sleeps on her tummy?  │  all checked by default
│ ✓ When can we start a bath every day?       │
│ Questions not marked as asked stay for the  │  Content's carry-over line, caption
│ next visit.                                 │
└─────────────────────────────────────────────┘
```

- **Free** and **outside** `EventsView.addEvent` (plan v2 decision 4). Save writes one `DoctorVisit` and stamps every checked question (`askedAt`, `visit`) **in one save**, so the visit and the questions never part.
- **Date:**
  - default today; the range runs from the birth date to today (no future visit);
  - a date earlier than the latest visit is allowed (a visit logged late). The period still starts at the latest visit's date, and the late visit only takes its checked questions.
- **Note:** optional, kept verbatim, no limit shown (Dev caps it at 2000).
- **Questions:**
  - each row is a toggle with a `checkmark` 17 pt BBPrimary when checked and an empty 22 pt circle in BBTextSecondary when not; the whole row (≥ 44) toggles it;
  - VoiceOver: the question text with the `.isSelected` trait, and the hint «Asked».
  - With no open questions the section is absent; the sheet is date + note only.
- **After Save:** the sheet closes and the screen shows the new period («Since the visit on 1 Nov · 0 days»). There is no toast, because the changed header is the confirmation.

### 3.3 Visit detail (from ② and from the Events history)

A sheet with:
- Date and Note (read), then «Asked at this visit» (the list, read).
- Toolbar Edit. Edit mode reuses the visit sheet's date and note fields; the questions are not re-editable here, because «Back to open» lives in ⑥.
- A destructive «Delete visit» with a confirm: «Its N questions go back to the open list.» (plan v2 decision 5).
- **Events history** lists visits as rows: glyph `stethoscope` in BBEvents, the title «Pediatrician visit», the note's first line in `caption`.
  - The rows are read-only in the list: no swipe-delete, and no tile in the add sheet or in quick-add.
  - A tap opens this detail, so there is one place where a visit is changed. → DECISION? 1

## 4. States

| state | screen |
|---|---|
| **no visit yet** | ② «Since birth · <age>» (plain text, no chevron); under it one `caption` line from Content: after the visit, tap «Visit happened» and the next report starts from it. ⑥ absent |
| **visit today, nothing since** (all four data cards empty) | **one** card instead of four empty ones: «A new period started on 1 Nov. Entries from today will show here.» (`callout` BBTextSecondary). The Growth facts that do not depend on the period (latest weight, percentile, length, head, at birth) still show in their card; only the period rows go |
| **empty section** (some data, not this kind) | that card shows its title and one line «No feeds logged since 12 Oct» (`callout` BBTextSecondary). Growth with no weighing at all: the line + «Add a weighing» (`growth.add_weighing`, opens AddGrowthSheet; the 2026-09-05 empty-state rule). Feeding / sleep / diapers: no CTA, since their action lives on their tabs (same rule) |
| **short period** (< 3 days) | no "a day" rows; raw counts instead: «Feeds: 9», «Sleep: 21 h 40 min in total», «Wet: 14 · Dirty: 6». The days line is absent. A per-day figure over one day reads as a rate it is not |
| **long period** (> 8 weeks) | the same averages + the days line; weighings capped at 6 with «Show all N» (§ 2.1); nothing else changes |
| **preterm, before the due date** | percentile rows → the `percentile.before_due_date` sentence; ③ shows the corrected age |
| **past 24 months** | percentile rows → the out-of-range sentence (the Growth screen's) |
| **free user** | the whole screen and the whole period (plan v2 decision 8); share ⑩ with the padlock → paywall |
| **AX2** | § 2.1 stacking; sheets scroll, Save stays in the nav bar |
| **iPad 13"** | max column 600 pt, leading; sheets as form sheets |
| **light / dark** | tokens only; the PDF is always light (§ 5) |
| **VoiceOver** | each row is one element, read «label: value»; the percentile row is read «Weight percentile, WHO, 42» (Content's a11y key if the colon reads oddly); glyphs hidden; card titles are headers; ② reads with the hint «Opens the visit» |

## 5. PDF (`m2-report-pdf`)

A new template in the same renderer (`ExportGenerator.renderPDF`). It does **not** reuse the current export's CSS. Always light. A4 595 × 842, margins 36 (as today). Every number in the app language (plan v2 decision 10), NBSP between number and unit.

```
┌───────────────────────────────────────────────────────────┐
│ For the pediatrician                                      │  18 pt semibold, text
│ Mia                                                       │  14 pt semibold, text
│ Date of birth: 2 Sep 2026        Sex: Girl                │  11 pt label: value, 2 columns
│ Age: 2 months                    Due date: 7 Oct 2026     │  (due date / corrected age only when preterm)
│ Period: 12 Oct – 1 Nov 2026 (20 days)                     │
│ Made on: 1 Nov 2026                                       │
│ ───────────────────────────────────────────────────────── │  1 pt rule, primary
│ Growth                                                    │  13 pt semibold, primary
│ Weight: 5.42 kg (28 Oct)     Weight percentile (WHO): 42  │  11 pt
│ Length: 58 cm (28 Oct)       Length percentile (WHO): 35  │
│ Head: 39 cm (28 Oct)         Since 12 Oct: +640 g         │
│ At birth: 3.40 kg · 51 cm                                 │
│ ┌ Date ──── Weight ── Length ── Head ┐                    │  table, 11 pt; header row on background tint
│ │ 28 Oct    5.42 kg   58 cm     39 cm│                    │
│ │ …                                  │                    │
│ Feeding                                                   │
│ Feeds a day: 7.4 · Days with entries: 18 of 20            │
│ …  Sleep  …  Diapers  …                                   │
│ Questions from the parent                                 │  open questions, numbered 1. 2. 3.
│ 1. Is it fine that she sleeps on her tummy?               │
│                                                           │
│ Entered by the parent in Bitty. Percentiles: WHO Child    │  provenance, 10 pt secondary, end of last page
│ Growth Standards.                                         │
│ Bitty · Mia · 12 Oct – 1 Nov 2026            Page 1 of 2  │  footer every page, 9 pt secondary
└───────────────────────────────────────────────────────────┘
```

- **Colours** (hex constants beside the existing ones; CLAUDE.md theming rule — they mirror the light colorsets):
  - text `#2D2837` (BBTextPrimary), 14.3:1 on white;
  - secondary `#746D85` (BBTextSecondary), 4.9:1;
  - headings and the rule `#6F5BA8` (BBPrimary), 5.6:1;
  - the table header fill `#F6F3FB` (BBBackground), text on it 13.0:1;
  - row rules `#E5E5EA` (decorative);
  - **no gradient, no white-on-colour, no emoji, no category tints.**
- **Type:** the system font (`-apple-system`). Body and table 11 pt; headings 13; title 18; provenance 10; the page footer 9 (page furniture, not body). Dev checks on the first render that CSS sizes come out as these points in `UIMarkupTextPrintFormatter`. If they don't, he scales the CSS, not the targets.
- **Order:** header → Growth → Feeding → Sleep → Diapers → Questions → provenance. Data before questions, because the PDF is the doctor's record; the screen differs on purpose (§ 2 ④).
- **Rows are the screen's rows and keys,** in two columns where they fit. The same `PeriodSummary` feeds both (Dev's test compares the strings). The short-period and empty-section states print as on screen. The «visit today, nothing since» state prints the header + Growth facts + «No entries in this period».
- **Weighings table:** all weighings in the period, newest first; columns Date · Weight · Length · Head, with an empty cell when not measured that day. `thead { display: table-header-group }` so the header repeats on a new page.
- **Questions:** the **open** questions at the moment of making the PDF, numbered, verbatim. Absent when none. Asked questions and visit notes are not printed: they belong to the visit that already happened.
- **Breaks:** each section `page-break-inside: avoid` except the weighings table.
- **Footer** on every page (`UIPrintPageRenderer` footer): left «<brand> · <name> · <period>», right «Page N of M».
- **Excluded:** band words, tints, ⚠, the trend / adequacy / norm verdicts, `diaper.color.warning`, `growth.who_footnote`, marketing.
- **File name:** «<screen title> – <name> – <yyyy-MM-dd>.pdf» in the app language (Content may shorten).

The existing export PDF keeps its own layout in M2. Only its numbers move to the app language (plan v2 decision 10). Its gradient header (white on `#A795D9` ≈ 2.6:1) and its emoji headings are an AA debt, logged as finding m1 for the backlog (§ 9). They are not M2 scope.

## 6. Motion

- ⑥ expand and «Show all N» use `easeInOut(0.25)` on height, the existing reveal curve. With Reduce Motion: a 0.2 s cross-fade (the weekly card's rule).
- Sheets use system presentation. After the visit sheet saves, the header changes without animation.
- No numbers count up.

## 7. Tokens touched

None new. BBPrimary, BBTextPrimary, BBTextSecondary, BBBackground, BBSurface, the four category tints (decorative), BBEvents (visit glyph in Events); Typography `title2`, `title3`, `body`, `callout`, `caption`, `metricSmall`; Spacing sm / md; `bbCard()`. The PDF hex constants mirror four light colorsets (§ 5). The design system needs no change.

## 8. What Content and Dev need

**Content** (`m2-report-copy`), key roles. Reused keys are marked ↺.
- More row: the screen title (also the nav title and the PDF title).
- Header:
  - «Since the visit on %@ · %@», «Since birth · %@», «(corrected: %@)»;
  - the no-visit hint line;
  - the «new period started on %@» line.
- Card titles: Growth, Feeding, Sleep, Diapers, Questions for the pediatrician.
- Growth:
  - «Weight: %@», «Length: %@», ↺ `growth.head_fmt`, ↺ `percentile.as_of_fmt`;
  - «Weight percentile (WHO): %@», «Length percentile (WHO): %@» (+ VoiceOver forms);
  - «Since %@: %@», «Weighings», «Show all %d», «At birth: %@»;
  - ↺ `percentile.before_due_date` and the out-of-range sentence.
- Feeding:
  - ↺ `weekly.feeds_fmt`;
  - type counts «Breast %d», «Formula %d», «Expressed %d»;
  - «Bottle a day: %@», «Breastfeed: %@ on average»;
  - «Days with entries: %d of %d» (new: `weekly.days_logged_fmt` hard-codes 7).
- Sleep: ↺ `weekly.sleep_fmt`, ↺ `weekly.longest_sleep_fmt`.
- Diapers: «Wet a day: %@», «Dirty a day: %@», «Stool colours: %@», ↺ `diaper.color.*`.
- Short-period count forms: «Feeds: %d», «Sleep: %@ in total», «Wet: %d · Dirty: %d».
- Empty lines per section «No … logged since %@».
- Questions:
  - «Add a question», placeholder, empty line, «Visit happened», «Asked at the visit on %@ · %d», «Back to open»;
  - the question sheet title (new / edit), «Delete question».
- Visit sheet:
  - title (= the visit name), «Date», note placeholder, «Questions asked», ↺ carry-over line.
- Visit detail:
  - «Asked at this visit», «Delete visit», the confirm «Its %d questions go back to the open list.» (plural).
- Events row: the visit name.
- PDF:
  - header labels (Date of birth, Sex, Age, Due date, Period, Made on);
  - «Questions from the parent»;
  - the table column heads;
  - provenance (brand declined in ru);
  - «Page %d of %d»;
  - the file name.
- VoiceOver: «Share PDF», the period line hint «Opens the visit», the question row hint «Edit», the toggle hint «Asked».

**Dev** (`m2-visit-and-questions`, `m2-report-screen`, `m2-report-pdf`):
- The visit sheet saves the visit and the question stamps in one `context.save()`.
- Deleting a visit nils `askedAt` and `visit` on its questions (decision 5).
- `PeriodSummary` feeds screen and PDF; the base-weight rule for «Since %@» is in § 2.1.
- The More row and the screen route; the Events history row is read-only with a tap to the detail (§ 3.3, DECISION? 1).
- The seed lever `-BBSeedScenario doctorVisit` must show:
  - one earlier visit with 2 asked questions;
  - 3 open questions;
  - ≥ 7 weighings over the period (to show «Show all»);
  - feeds of two types with volumes;
  - stool colours.
  It also needs a second lever, or a variant, for «no visit yet» and «visit today, nothing since».

## 9. Findings outside M2 scope (for the backlog)

- **m1 (minor, AA, existing export PDF):**
  - the header is a `#6F5BA8 → #A795D9` gradient with white text, ≈ 2.6:1 at the light end (P8);
  - the headings are emoji (`ExportGenerator.swift:264–324`);
  - "Generated by" is in English (`:374`).
  - Fix when the export PDF is next touched: reuse § 5's header and colours.
  - Manager, 2026-11-01: into the backlog; Dev may fold it into `m2-report-pdf`.

## 10. Decisions (Manager under D35, 2026-11-01: all five accepted)

1. **A visit is changed in one place:** its detail sheet, reached from the report's period line and from the Events history row. Events lists visits read-only (no swipe-delete, no add tile). Why: plan v2 decision 4 keeps creation in the report. With edit and delete in two lists, the two places would drift on the "questions go back to open" rule.
2. **Questions sit above the data on screen and below it in the PDF.** Why: on screen they are what the parent writes into and says first at the visit. The PDF is the doctor's record, so its numbers lead.
3. **«Show all N» weighings expands in place** instead of linking to Growth. Why: it keeps the period's context, and Growth lists the whole history, not the period.
4. **The weight change since the period start** is printed with its base date («Since 12 Oct: +640 g»), hidden in the newborn window and with a single weighing. Why: a difference between two dated points is a measurement; the date shows which points are compared.
5. **Feeding adds two rows beyond the weekly card:** «Bottle a day» (volume) and «Breastfeed: N min on average». Why: they are the two questions a pediatrician asks about feeding that a count does not answer. Both are measurements and both are hidden when there is no data.

# teamdocs map

The map and the status of the teamdocs sections. Section bodies belong
to their owners; this file only points at them.

## Map

| Section | Owner | Path | Last change | Last check | Status |
|---|---|---|---|---|---|
| Design system (baseline, gaps § 10) | design | design/design-system.md | 2026-11-13 | 2026-11-18 | stale |
| Live Activity + widget controls | design | design/m1-live-activity.md | 2026-11-05 | 2026-11-18 | fresh |
| Weekly summary card | design | design/m1-weekly-summary.md | 2026-11-06 | 2026-11-18 | stale |
| Doctor-visit report | design | design/m2-doctor-report.md | 2026-11-04 | 2026-11-18 | fresh |
| Medications | design | design/m3-medications.md | 2026-11-13 | 2026-11-18 | fresh |
| Voice, terms, surface rules | content | content/voice.md | 2026-11-20 | 2026-10-28 | unchecked |
| Paywall + Settings copy rules | content | content/paywall-and-settings.md | 2026-11-20 | 2026-10-28 | unchecked |
| Free and Premium from 1.4.0 (the line every Premium string is checked against) | content | content/free-premium.md | 2026-11-20 | — | unchecked |
| Weekly card + notification rules | content | content/weekly-and-notifications.md | 2026-11-04 | 2026-10-28 | unchecked |
| Doctor-visit report copy | content | content/doctor-report.md | 2026-11-12 | — | unchecked |
| Medications copy | content | content/medications.md | 2026-11-12 | — | unchecked |
| Localization rules (engine, plurals, arguments, formats) | content | content/localization.md | 2026-11-11 | — | unchecked |
| Glossary per language | content | content/glossary.md | 2026-11-12 | — | unchecked |
| Tone per language | content | content/tone.md | 2026-11-11 | — | unchecked |
| QA overview (tree, checklists, bugs) | qa | qa/README.md | 2026-11-20 | 2026-10-28 | unchecked |

Status: `fresh` (check passed on the date, and the section has not
changed since) | `stale` (check failed, section is marked stale at its
top until fixed) | `unchecked` (never checked, or changed after its
last check).
A section gets its row when its owner first writes one.

## Check of 2026-11-18 (against main 04a53d2)

Each section's own `check:` lines were run on the code of main and
compared with what the section lists.

- `design/design-system.md`: the measured lists match the code: 19
  colorsets and 17 `Color("BB` reads; 10 type styles; 6 spacing and 5
  radius tokens; 3 shadows and 4 surface modifiers; all 45 component
  types; the spring curves; the 10 widget colorsets. Stale: lines 118
  and 2297 call "CJK tracking 0" and the PDF font per script planned.
  Both are in code (`BBTheme.Typography.tracking`, which returns 0 for
  ja, ko and zh-Hant; `PagedPDF.fallbackFamilies(for:)`).
- `design/m1-live-activity.md`: the timer kinds, the 10 widget
  colorsets and the two Dynamic Type caps (`xxxLarge` on the Lock
  Screen, `xLarge` in the Dynamic Island) match.
- `design/m1-weekly-summary.md`: stale. § 6 lists 24 string keys,
  `en.json` has 23 under `weekly.`; `weekly.range_fmt` (§ 2 row ②, § 6)
  is in no localization file and no Swift file.
- `design/m2-doctor-report.md`: the More row glyph (`stethoscope`) and
  the PDF's Helvetica Neue are found; `en.json` has 49 keys under
  `report.`. § 8 lists the copy by role in prose, so the count has no
  list to compare with.
- `design/m3-medications.md`: the More row glyph (`pills.fill`) is
  found; `en.json` has 76 keys under `medication.`; nothing in
  `Features/Medications` calls `entrySaved`. § 12 lists the copy by
  role in prose, as above.
- The eight `content/` sections and `qa/README.md` have no `triggers:`
  and `check:` header, so there is nothing to measure and they stay
  `unchecked`. A look at what they name as live found:
  `content/weekly-and-notifications.md` line 92 and
  `content/doctor-report.md` line 218 name `weekly.range_fmt`, which
  the code no longer has; `content/localization.md` names the tools
  `fit.swift` and `loc_lint.py`, which are not in the repository.

## Project docs (canonical for the code)

- `docs/README.md` — the project docs map
- `ARCHITECTURE.md` (how it works), `DECISIONS.md` (why), `NOTIFICATIONS.md`
  (notification catalogue), `README.md` (product, roadmap), `CLAUDE.md`
  (working rules for agents)

## Project status

- Last App Store release: 1.3.0, live since 2026-11-23, medications with a dosing interval and 12 more languages (uk, ja, ko, fr, de, sv, nb, da, fi, pt-BR, pt-PT, zh-Hant; 15 with en, ru, es). Built as 1.3.0 (30), tag v1.3.0+30.
- Before it: 1.2.0, 2026-11-11, the doctor-visit report (1.2.0 (28), tag v1.2.0+28, branch release/1.2.0); 1.1.0 (build 27), Live Activity for running timers, the interactive widget, the weekly summary card; 1.0.3 (build 26), 2026-09-27, metadata only.
- In TestFlight: 1.4.0 (31), free tracking first, uploaded 2026-11-24. Tag v1.4.0+31 on main; the full regression passed. Not submitted yet. Creating events is free; the weekly charts of Feeding, Sleep and Diaper are Premium; onboarding has nine steps and ends without a paywall; Premium is offered later by a card on Home. The line between Free and Premium is in `content/free-premium.md`.
- In work: 1.4.0 (32), which replaces build 31 on TestFlight. Two changes: the New Event form opens from Home without a delay; today's events are shown on Home and every event is listed in Recent activity.
- Team workflow files are local and untracked; nothing here depends on them.

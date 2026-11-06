# teamdocs map

The map and the status of the teamdocs sections. Section bodies belong
to their owners; this file only points at them.

## Map

| Section | Owner | Path | Last check | Status |
|---|---|---|---|---|
| Design system (baseline, gaps § 10) | design | design/design-system.md | 2026-10-28 | fresh |
| Live Activity + widget controls | design | design/m1-live-activity.md | 2026-10-29 | fresh |
| Weekly summary card | design | design/m1-weekly-summary.md | 2026-10-28 | fresh |
| Doctor-visit report | design | design/m2-doctor-report.md | — | unchecked |
| Voice, terms, surface rules | content | content/voice.md | 2026-10-28 | fresh |
| Paywall + Settings copy rules | content | content/paywall-and-settings.md | 2026-10-28 | fresh |
| Weekly card + notification rules | content | content/weekly-and-notifications.md | 2026-10-28 | fresh |
| Doctor-visit report copy | content | content/doctor-report.md | — | unchecked |
| QA overview (tree, checklists, bugs) | qa | qa/README.md | 2026-10-28 | fresh |

Status: `fresh` (check passed on the date) | `stale` (check failed,
section is marked stale at its top until fixed) | `unchecked`.
A section gets its row when its owner first writes one.

## Project docs (canonical for the code)

- `docs/README.md` — the project docs map
- `ARCHITECTURE.md` (how it works), `DECISIONS.md` (why), `NOTIFICATIONS.md`
  (notification catalogue), `README.md` (product, roadmap), `CLAUDE.md`
  (working rules for agents)

## Project status

- Last App Store release: 1.0.3 (build 26), 2026-09-27, metadata only.
- 1.1.0 (build 27): Live Activity for running timers, the interactive widget, the weekly summary card.
- In progress: 1.2.0, the doctor-visit report.
- Next on the roadmap: medications, then more localizations.
- Team workflow files are local and untracked; nothing here depends on them.

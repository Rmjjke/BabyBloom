# teamdocs map

Owner: Manager. Updated by the `docs` op. Section bodies belong to
their owner roles; this file is the map and the status.

## Map

| Section | Owner role | Path | Last check | Status |
|---|---|---|---|---|
| Design system (baseline, gaps § 10) | design | design/design-system.md | 2026-10-28 | fresh |
| M1 Live Activity + widget controls | design | design/m1-live-activity.md | 2026-10-28 | draft (branch feature/m1-lockscreen-design) |
| M1 weekly summary card | design | design/m1-weekly-summary.md | 2026-10-28 | fresh |
| Voice, terms, surface rules | content | content/voice.md | 2026-10-28 | fresh |
| Paywall + Settings copy rules | content | content/paywall-and-settings.md | 2026-10-28 | fresh |
| QA overview (tree, checklists, bugs) | qa | qa/README.md (authoritative copy .team/qa/teamdocs/qa/) | 2026-10-28 | fresh |
| Weekly card + notification rules | content | content/weekly-and-notifications.md | 2026-10-28 | fresh (branch held for weekly-summary) |

Status: `fresh` (check passed on the date) | `stale` (check failed,
section is marked stale at its top until fixed) | `unchecked`.
Sections for dev (architecture/), QA (qa/) and content (content/) get
their row when their role first writes one.

## Project docs (canonical for the code — map kept by the Dev Lead)

- `docs/README.md` — the project docs map (docs-layout pass, PR #72)
- `ARCHITECTURE.md` (how it works), `DECISIONS.md` (why), `NOTIFICATIONS.md`
  (notification catalogue), `README.md` (product, roadmap), `CLAUDE.md`
  (working rules for agents)

## Project status

- Milestones closed: none yet under teamdesk (MVP and 1.0.x shipped before, see desk/done.md)
- Milestones open: m1-lock-screen-release (planning) — #13 Live Activity, #3 interactive widget, #15 weekly summary → App Store release (D4)
- Next: M2 #14 doctor-visit report; M3 #16 medications; then more localizations (D4)
- Last release: 1.0.3 (build 26), 2026-09-27 — metadata-only
- Where things live: team files in `.team/` (untracked); cards in `.team/desk/tasks/`; milestones in `.team/desk/milestones/`

# QA — BabyBloom

How BabyBloom is tested: what the regression base covers, how bugs and
devices are graded, and what the simulator cannot show.

## Where QA keeps things

QA's working tree (checklists, Maestro flows, run evidence, bug reports)
lives on the test machine, outside version control. Paths below are
relative to its root.

- **Regression base.** One checklist per feature, 35 in all:
  `<area>/<feature>/test-cases/regression-checklist.md`. Areas are
  onboarding, tracking, growth, dashboard-widget, premium, profile-export,
  notifications, doctor-visit and medications. Version 1.1.0 added three features:
  `tracking/live-activity` (LIVE), `dashboard-widget/weekly-summary`
  (WEEKLY) and `notifications/weekly-notification` (WNOTIF), plus 13 rows
  in settings, widget, dashboard, feeding and sleep. The pediatrician
  report added the `doctor-visit/` area with `visit-marking` (VISIT),
  `questions` (QUEST), `report` (REPORT) and `report-pdf` (RPDF), plus
  EXPORT-023…025, EVENTS-021 and FREEHIST-020. Medications add the
  `medications/` area with `list-form` (MEDLIST), `detail-dose` (MEDDOSE),
  `confirmation` (MEDALERT), `reminder` (MEDREM) and `home` (MEDHOME),
  plus rows in events, dashboard, reminders, the free history window, both
  paywalls, export, and the pediatrician report and its PDF. Row ids are permanent
  (`FEED-001`, …). The P1 rows form the smoke set. Format:
  `qa/rules/local/checklist-format.md`.
- **Bugs.** One file each, indexed in `bugs.md` (ids `Q-NNN`). Severity:
  - **blocker**: a crash, data loss or broken sync, or a core flow that
    does not work (logging an entry, purchase or restore, leaving
    onboarding);
  - **major**: wrong data shown (totals, WHO percentiles, timers, the
    widget), or a feature broken with no easy workaround;
  - **minor**: a wrong or missing translation (en/ru/es), a layout defect,
    or a feature broken with a workaround;
  - **trivial**: purely cosmetic.
- **Devices.** `knowledge-base/device-tiers.md`: iPhone 17 is mandatory;
  iPad Pro 13" is sampled on a temporary simulator.
- **Coverage dimensions.** `knowledge-base/coverage-dimensions.md`.
- **Runs.** Each regression run keeps its flows, screenshots and tester
  reports in its own folder under `tickets/`. Flows worth keeping move to
  the feature's `test-flows/`.

## Not covered by the simulator (checked on a real phone)

Lock Screen stop on a passcode-locked phone, Dynamic Island on hardware,
a Live Activity past 8h, the Monday notification on a real Monday,
CloudKit across two devices, sandbox StoreKit (trial wording), and the
TestFlight build itself.

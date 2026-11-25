# QA — BabyBloom

How BabyBloom is tested: what the regression base covers, how bugs and
devices are graded, and what the simulator cannot show.

## Where QA keeps things

QA's working tree (checklists, Maestro flows, run evidence, bug reports)
lives on the test machine, outside version control. Paths below are
relative to its root.

- **Regression base.** One checklist per feature, 37 in all:
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
  paywalls, export, and the pediatrician report and its PDF. Version
  1.4.0 (tracking free, no paywall in onboarding) adds
  `premium/weekly-chart-lock` (WLOCK: the calm card in place of the weekly
  charts of feeding, sleep and diapers, the reason line for earlier
  installs) and `premium/offer-card` (OFFER: the Premium offer on Home,
  its contents, spacing, holds, the 3 days, the slower pace after three
  closes, earlier installs). It retires `onboarding/generating-loader`
  (OBLOAD) and `onboarding/onboarding-paywall` (OBPAY): onboarding has
  nine steps and the profile is created on the widgets page's button,
  rows now in onboarding-pages (OBPAGES-026…039). Events rows are
  inverted (events are free); the Dashboard rows place the offer card;
  the Premium screen carries the four-row 1.4.0 list (PREM-010,
  PREM-025…033); the free history window and the trackers' weekly-chart
  rows point to WLOCK. Retired checklists stay for history and are not
  run. Row ids are permanent
  (`FEED-001`, …). The P1 rows form the smoke set. Format:
  `qa/rules/local/checklist-format.md`.
- **Two cross-feature rules** (from 1.4.0 build 31, after two things a
  user met that the regression passed over), each with its checklist
  under `_cross/`:
  - **OPEN-TIME** (`_cross/open-time`, OPEN; `qa/rules/local/open-time.md`):
    every entry point (Home's quick actions and Today tiles, each tab,
    each row of More) is opened cold (first open after a launch) and
    warm, timed from a screen recording, and compared with its
    neighbours. One that is slower than its group by more than 100 ms,
    or over the stated time, is a bug.
  - **TRACE** (`_cross/trace`, TRACE; `qa/rules/local/trace.md`): every
    entry a person can create (feed, sleep, diaper, growth, each event
    type, a dose, a visit, a medicine), from every place it can be
    created, is seen back at that place, or the place says where it
    lives. No trace is a bug, whatever a decision says about a
    neighbour screen.
  - A blind tester's "could not find it" or "expected it elsewhere"
    note that a decision answers by design is not dropped: the run's
    result lists it under its own heading with that decision, for the
    owner to see.
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

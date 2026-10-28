# QA — BabyBloom

Owner: QA Lead. The authoritative copy is `.team/qa/teamdocs/qa/`; the Dev
Lead mirrors it to `teamdocs/qa/` after each merge.

## Where QA keeps things

The QA tree is `.team/qa/`, local and untracked. The map is
`.team/qa/CLAUDE.md`; the setup decisions are `.team/qa/qa/config.md`.

- **Regression base.** One checklist per feature, 23 in all, approved by
  the owner on 2026-10-28 (STOP 2): `.team/qa/<area>/<feature>/test-cases/regression-checklist.md`.
  Areas are onboarding, tracking, growth, dashboard-widget, premium,
  profile-export and notifications. Row ids are permanent
  (`FEED-001`, …). The P1 rows form the smoke set. Format:
  `.team/qa/qa/rules/local/checklist-format.md`.
- **Bugs.** One file each, indexed in `.team/qa/bugs.md` (ids `Q-NNN`).
  Severity follows the owner's D1 scale.
- **Devices.** `.team/qa/knowledge-base/device-tiers.md`: iPhone 17 is
  mandatory, iPad Pro 13" is sampled (D2).
- **Coverage dimensions.** `.team/qa/knowledge-base/coverage-dimensions.md`.
- **Check packs.** Runs and tester reports go to `.team/qa/tickets/check-<n>/`.

## Not covered by the simulator (the owner's real-phone look)

Lock Screen stop on a passcode-locked phone, Dynamic Island on hardware,
a Live Activity past 8h, the Monday notification on a real Monday,
CloudKit across two devices, sandbox StoreKit (trial wording), and the
TestFlight build itself.

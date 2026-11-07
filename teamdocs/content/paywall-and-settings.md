# Paywall and Settings copy

Voice and terms: `voice.md` in this folder.

## Paywall feature list

- Both paywalls (onboarding `PremiumPage`, in-app `PaywallView`) read the
  same `onboarding.premium.f*` keys, so one value changes both.
- The list names only what Premium unlocks. A row for a free feature sells
  the parent something they already have.
  - Before writing or changing a row, check it against the code's
    `isPremium` gates.
  - As of 2026-11-03 they are: history beyond the free 15-day window (f1),
    export (f3), the gain, trend, percentile and nutrition cards (f5), and
    creating events such as bath, walk and mood (f2).
  - Reminders are free and stay free: gating them would take a feature away
    from current users.
  - Medications are free (the list, doses, the early-dose confirmation and
    the dose reminder). No row names them, and no row sells the confirmation
    or the reminder: they are safety facts, and selling them would say a free
    parent is less safe. Notes: `medications.md`.
- f4 («Несколько профилей детей») is not shown: the app has one baby. The
  key numbering keeps its gap on purpose (comment in `PaywallView`).
- A non-breaking space stands before the dash in a row ("Events — …"),
  so a wrapped row never starts with a dash.

## Settings rows

Each row that looks tappable does one thing.

- About: the title reuses `settings.about`; `about.version_fmt` takes one
  string (the code may pass "1.4 (52)" if the build number is wanted); Terms
  and Privacy reuse `premium.terms` / `premium.privacy`, the same links as the
  paywall.
- Configure Reminders keeps its label; it opens the app's page in the iOS
  Settings app.
- Usage Statistics is a switch, on by default. `settings.analytics_hint`
  under its title says what it does: "We see which features are used." It
  names only what is sent and never says "anonymous", because the install
  keeps one random id. The rule for a switch's line: `voice.md` § Surface
  rules.

## Changes

- 2026-10-28 — `onboarding.premium.f2` now sells events instead of the free
  reminders. New `about.version_fmt` for the About row, which opened nothing.
- 2026-11-03 — `onboarding.premium.f2` lists baths, walks and mood: medications
  are free in 1.3.0.
- 2026-11-04 — `settings.analytics_hint` under Usage Statistics.
- 2026-11-08 — Settings has no sync row in 1.3.0: the entries stay on the
  device. Its four keys are deleted (`settings.icloud`, `settings.icloud_on`,
  `settings.icloud_off`, `settings.icloud_off_hint`).

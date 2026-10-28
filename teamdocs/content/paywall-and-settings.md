# Paywall and Settings copy

Owner: content. Voice and terms: `voice.md` in this folder.

## Paywall feature list

- Both paywalls (onboarding `PremiumPage`, in-app `PaywallView`) read the
  same `onboarding.premium.f*` keys, so one value changes both.
- The list names only what Premium unlocks (owner D20). Before writing or
  changing a row, check it against the code's `isPremium` gates. As of
  2026-10-28 they are: history beyond the free 15-day window (f1), export
  (f3), the gain, trend, percentile and nutrition cards (f5), and creating
  events such as bath, walk, medicine and mood (f2). Reminders are free and
  stay free.
- f4 («Несколько профилей детей») is not shown: the app has one baby. The
  key numbering keeps its gap on purpose (comment in `PaywallView`).
- A non-breaking space stands before the dash in a row ("Events — …"),
  so a wrapped row never starts with a dash.

## Settings rows (owner D21)

- iCloud Sync is a status line, not a button: `settings.icloud_on` /
  `settings.icloud_off`. When it is off, `settings.icloud_off_hint` says the
  one thing to do (sign in to iCloud in the Settings app) and why (entries on
  all your devices), with no warning tone.
- About: the title reuses `settings.about`; `about.version_fmt` takes one
  string (Dev may pass "1.4 (52)" if the build number is wanted); Terms and
  Privacy reuse `premium.terms` / `premium.privacy`, the same links as the
  paywall.
- Configure Reminders keeps its label; it opens the app's page in the iOS
  Settings app.

## Changes

- 2026-10-28 — `onboarding.premium.f2` now sells events instead of the free
  reminders (Q-004); new `settings.icloud_on/_off/_off_hint`,
  `about.version_fmt` (Q-003).

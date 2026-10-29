# Weekly summary and notification copy

Owner: content. Voice and terms: `voice.md` in this folder. The notification
catalogue (ids, schedules, texts) is `NOTIFICATIONS.md`; the weekly card's
layout and states are `teamdocs/design/m1-weekly-summary.md`.

## Weekly summary card (#15, M1)

- Shown Monday to Sunday for the calendar week before (D9, D18); × hides it
  until next Monday (`weekly.a11y_hide`).
- Lines are **label: value** (`Кормлений в день: 7,4`), so a decimal never
  meets a Russian plural form, and they stack cleanly at accessibility sizes.
- Averages are per day **over the days with entries** (D19), with
  `weekly.days_logged_fmt` ("Days with entries: 5 of 7") whenever N < 7: a
  forgotten day is not "the baby slept less".
- Comparison is two plain numbers: the delta is an arrow and a number in a
  neutral colour, and `weekly.previous_fmt` gives the week before. No word
  grades the change.
- Newborn window: no gain number at all, `weekly.gain_newborn` instead (D17;
  DECISIONS 2026-09-05 — a −180 g in week one is normal and reads as a
  verdict).
- Gain is a rate (D27): the WeightVelocity pair whose later weighing falls
  in the week, so it is the same number Growth shows. `weekly.gain_fmt`
  carries the unit ("Weight gain: %@ g/week", the units of
  `velocity.per_week_fmt`); `%@` is the signed number, "+210". The "Week
  before" line under it passes `velocity.per_week_fmt` into
  `weekly.previous_fmt`, so both lines read in g/week.
- No weighing pair: `weekly.gain_needs_weighing` + the existing
  `growth.add_weighing` action (DECISIONS 2026-09-05, empty states name the
  missing thing and offer the action).
- First week in the log: `weekly.first_week` — says when a comparison will
  come, not that something is missing.

## The Monday notification

`notification.weekly_title` / `_body`: "Last week in numbers" — feeds and
sleep, Monday to Sunday, beside the week before. The text is fixed when the
notification is scheduled, so it names what is waiting and never hints at how
the week went. No "tap to…" — the notification is tappable anyway.

It has its own switch, `settings.notify_weekly` "Weekly summary", in
Settings → Notifications (D26). Off stops the notification only; the card
stays.

## Notification copy rules (from the M1 sweep)

- Russian: «вы» to the parent in every notification.
- Russian: the baby's name (`%@`) stands only where the nominative is right
  («как там %@», «%@ растёт», «%@ — уже 2 дня…»). The substitution cannot
  decline the name, so «о %@» / «для %@» / «рост %@» would print «о Маша».

## Changes

- 2026-10-28 — weekly card strings (`weekly.*`), the Monday notification
  text, Russian «ты»→«вы» and nominative-only name slots
  (`profile.photo_hint`, `notification.diaper_title/_body`,
  `notification.measurements_title/_body`, `notification.weigh_in_body`,
  `notification.idle_body`, `onboarding.gen.title_named`).
- 2026-10-29 — `weekly.gain_fmt` reads as a rate (D27);
  `settings.notify_weekly` added (D26).

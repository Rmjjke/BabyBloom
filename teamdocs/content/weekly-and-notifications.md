# Weekly summary and notification copy

Voice and terms: `voice.md` in this folder. The notification catalogue (ids,
schedules, texts) is `NOTIFICATIONS.md`; the weekly card's layout and states
are `teamdocs/design/m1-weekly-summary.md`.

## Weekly summary card (#15, 1.1.0)

- Shown Monday to Sunday for the calendar week before; × hides it until next
  Monday (`weekly.a11y_hide`).
- Lines are **label: value** (`Кормлений в день: 7,4`), so a decimal never
  meets a Russian plural form, and they stack cleanly at accessibility sizes.
- Averages are per day **over the days with entries**, and the card says so
  in `weekly.days_logged_fmt` ("Averages over the days with entries: 5 of
  7"): a forgotten day is not "the baby slept less".
  - The app shows the line when N < 7. A full week is to show it too ("7 of
    7"): in testing, a reader of a full week asked whether «Feeds a day: 8»
    was an average.
  - The row labels keep "a day". With "average" in them, the label is 55–90
    pt longer in every language and no longer fits beside its delta on a
    320 pt screen at the default text size. An abbreviation ("avg.", «в
    ср.») would break the full-word rule.
- Comparison is two plain numbers: the delta is an arrow and a number in a
  neutral colour, and `weekly.previous_fmt` gives the week before. No word
  grades the change.
- **Gain is a rate**: the weight-velocity pair whose later weighing falls in
  the week (the earlier one may be before it).
  - It is the same number Growth shows. A pair of weighings inside one Monday
    to Sunday week would almost never exist.
  - `weekly.gain_fmt` carries the unit ("Weight gain: %@ g/week", the units of
    `velocity.per_week_fmt`); `%@` is the signed number, "+210".
  - The "Week before" line under it passes `velocity.per_week_fmt` into
    `weekly.previous_fmt`, so both lines read in g/week.
- Newborn window: no gain number at all, `weekly.gain_newborn` instead
  (`DECISIONS.md` 2026-09-05: a −180 g in week one is normal and reads as a
  verdict).
- No weighing pair: `weekly.gain_needs_weighing` + the existing
  `growth.add_weighing` action (`DECISIONS.md` 2026-09-05: empty states name
  the missing thing and offer the action).
- First week in the log: `weekly.first_week` — says when a comparison will
  come, not that something is missing.
- Durations: `duration.h_min` ("1 h 20 min"), `duration.h_only` ("1 h") when
  the minutes are 0, `duration.min_only` under an hour.
- **A number never wraps away from its unit.**
  - A no-break space (` ` in the JSON) stands between them in
    `weekly.gain_fmt`, `velocity.per_week_fmt` and the three `duration.*`
    forms above.
  - The range keeps a no-break space before its dash (`weekly.range_fmt`),
    so a wrapped range never starts a line with "–".
  - Without it, a wrap at the AX2 text size split «+210 / г/нед».

## VoiceOver

- Each value row is one stop. The arrow is silent, so the direction is
  spoken in words after the value: `weekly.a11y_delta_up_fmt` /
  `weekly.a11y_delta_down_fmt` ("Feeds a day: 6.4, 0.6 more than the week
  before"). `%@` is the unsigned delta as shown. "More / less" states the
  fact; it never says better or worse. No delta, no phrase (equal values
  show no arrow).
- Header button: label = title + range; hint `weekly.a11y_expand` /
  `weekly.a11y_collapse` (the action); value `weekly.a11y_expanded` /
  `weekly.a11y_collapsed` (the state).

## The Monday notification

`notification.weekly_title` / `_body`: "Last week in numbers" — feeds and
sleep, Monday to Sunday, day by day.
- One body serves every week. It says what the card holds and does not
  promise a comparison, so it stays true in the first week, when there is no
  week before (state S2 in `teamdocs/design/m1-weekly-summary.md`).
- The text is fixed when the notification is scheduled, so it names what is
  waiting and never hints at how the week went.
- No "tap to…" — the notification is tappable anyway.

It has its own switch, `settings.notify_weekly` "Weekly summary", in
Settings → Notifications. Off stops the notification only; the card stays. A
recurring notification with no off switch in the app pushes people to turn
off all of the app's notifications in iOS, feeding reminders included.

## Notification copy rules (from the 1.1.0 sweep)

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
- 2026-10-29 — `weekly.gain_fmt` reads as a rate; `settings.notify_weekly`
  added.
- 2026-10-30 — VoiceOver delta and header-state strings; the notification
  body drops "beside the week before" (false in a first week);
  `duration.h_only`.
- 2026-11-02 — en `duration.*` get spaces: "1 h 20 min", the same form as ru
  and es.
- 2026-11-04 — `weekly.days_logged_fmt` says that the rows are averages:
  "Averages over the days with entries: %d of 7" / «Среднее по дням с
  записями: %d из 7» / «Promedio de los días con registros: %d de 7».

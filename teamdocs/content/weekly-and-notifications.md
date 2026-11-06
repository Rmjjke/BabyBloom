# Weekly summary and notification copy

Voice and terms: `voice.md` in this folder. The notification catalogue (ids,
schedules, texts) is `NOTIFICATIONS.md`; the weekly card's layout and states
are `teamdocs/design/m1-weekly-summary.md`.

## Weekly summary card (#15, 1.1.0)

- Shown Monday to Sunday for the calendar week before; × hides it until next
  Monday (`weekly.a11y_hide`).
  - After ×, the card folds to one line in its place while the Dashboard stays
    on screen: `weekly.hidden` "The weekly summary is hidden until next
    Monday." / «Недельная сводка скрыта до следующего понедельника.» / «El
    resumen semanal está oculto hasta el próximo lunes.», and a button,
    `weekly.undo` "Undo" / «Вернуть» / «Deshacer», that brings the card back.
  - "Next Monday", as `weekly.gain_next_monday` says it. "Until Monday" would
    read as today to a parent who hides the card on a Monday. "Weekly
    summary" is the name the Settings switch and the notification use; the
    card's own title, "Last week", would read as if the week itself were
    hidden.
  - The line says "hidden until", not "comes back on": a week with no entries
    shows no card next Monday either.
  - Russian «Вернуть», not «Отменить», which sits too close to «Отмена»
    (Cancel). Russian glues «до» to the word after it.
- Lines are **label: value** (`Кормлений в день: 7,4`), so a decimal never
  meets a Russian plural form, and they stack cleanly at accessibility sizes.
- Averages are per day **over the days with entries**, and the card says so
  in `weekly.days_logged_fmt` ("Averages over the days with entries: 5 of
  7"): a forgotten day is not "the baby slept less".
  - The line shows on every week, a full one too ("7 of 7"): in testing, a
    reader of a full week asked whether «Feeds a day: 8» was an average.
  - The row labels keep "a day". With "average" in them, the label is 55–90
    pt longer in every language and no longer fits beside its delta on a
    320 pt screen at the default text size. An abbreviation ("avg.", «в
    ср.») would break the full-word rule.
- Comparison is two plain numbers: the delta is an arrow and a number in a
  neutral colour, and `weekly.previous_fmt` gives the week before. No word
  grades the change.
  - No word fits beside the arrow on a 320 pt screen, so one line under the
    rows says what the arrows compare, once for every row:
    `weekly.legend` "Arrows show the change from the week before." /
    «Стрелки показывают, на сколько больше или меньше, чем неделей раньше.» /
    «Las flechas muestran el cambio respecto a la semana anterior.» It shows
    when at least one arrow does; a first week has the first-week line in
    its place.
  - It names the week before as the card's other lines do: «неделей раньше»,
    as `weekly.previous_fmt` and the spoken deltas. «Прошлая неделя» is the
    card's title, the week shown, so «разница с прошлой неделей» would name
    the wrong week. Russian glues «на сколько».
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
- No weighing pair for the week: the line names what is missing, and the
  existing `growth.add_weighing` action follows where a weighing now helps
  (`DECISIONS.md` 2026-09-05: empty states name the missing thing and offer
  the action). There are four cases, judged on every weighing logged up to
  now, a pair being two weighings at least 3 days apart:

  | case | line | action |
  |---|---|---|
  | no weighing at all | `weekly.gain_needs_two` "Two weighings at least 3 days apart will show the gain here." | yes |
  | weighings, but no pair among them (one weighing, or several within 3 days) | `weekly.gain_needs_second` "One more weighing, at least 3 days after the first, will show the gain here." | yes |
  | a pair whose later weighing is after the week's end | `weekly.gain_next_monday` "This week's weighing will show the gain here next Monday." | no |
  | a pair whose later weighing is before the week | `weekly.gain_needs_weighing` "Weigh your baby, and the gain will show here next week." | yes |

  - The second line says "after the first", not "in 3 days": a parent who
    weighed five days ago may weigh today. "Weigh again" alone would send a
    parent who weighed yesterday to weigh again at once, which still gives
    no gain.
  - In the third case the next Monday's card shows the gain, so there is
    nothing to add.
  - The last line is true only when an earlier weighing exists: a single
    weighing in the coming week then completes a pair.
  - Until the app tells these cases apart, it shows
    `weekly.gain_needs_weighing` and the action in all four.
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
- The arrows' legend `weekly.legend` is for sight only and is hidden from
  VoiceOver. Each row with an arrow already speaks its comparison in words,
  so read aloud the legend would only repeat it.
- The hidden line and its button are read in that order: `weekly.hidden`,
  then `weekly.undo`.
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

Under the switch, `settings.notify_weekly_hint` says when the notification
comes: "It arrives on Monday mornings." / «Приходит утром по понедельникам.»
/ «Llega los lunes por la mañana.» It is built like the Live Activity row's
hint.
- The app plans it for Monday 10:00 and skips a week with no entries. The
  hint says "mornings" rather than a clock time, so it reads the same on a
  12-hour and a 24-hour phone.
- It names only the time. The section (Notifications) and the title
  (Weekly summary) say what it is. "…with last week's feeds and sleep"
  would take four lines on a 320 pt screen, where the switch leaves the
  hint about 145 pt.

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
- 2026-11-04 — `weekly.gain_needs_two`, `weekly.gain_needs_second` and
  `weekly.gain_next_monday`: the gain line names what is missing in each
  case without a pair. A parent who has weighed is no longer asked to weigh
  as if nothing were logged.
- 2026-11-04 — `settings.notify_weekly_hint`, the line under Settings ›
  Notifications › Weekly summary: when the notification comes.
- 2026-11-04 — `weekly.hidden` and `weekly.undo`, the line the card folds to
  after ×, and `weekly.legend`, one line under the rows for the arrows.
- 2026-11-04 — The days-with-entries line shows on every week, a full one
  too ("7 of 7"), not only when a day is missing.

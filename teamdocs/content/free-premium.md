# Free and Premium from 1.4.0

The reference that every Premium string is checked against: a paywall row,
an offer, a teaser, a lock hint. A string that sells something in the Free
column is wrong. A free promise that reaches into the Premium column is
wrong too.

## The line

| area | Free | Premium |
|---|---|---|
| Logging | Feeding, sleep, diapers, events (bath, walk, mood), medications, weighings | — |
| History | The last 15 days | Records older than 15 days. They are kept and never deleted; Premium opens them |
| Weekly charts (Feeding, Sleep, Diaper screens) | — | The charts of one Mon–Sun week, steppable back: feeds and diapers as counts, sleep in hours. Premium for everyone from 1.4.0 |
| Home weekly summary | The card, its per-day bars of feeds and sleep, and its notification | — |
| Growth screen | The WHO curve with the child's points; the percentile card; `NewbornProgressCard`; the nutrition summary (gain as a word up to 6 months) | The weekly gain in grams, the centile trend, the feeding breakdown |
| Home growth card | The card itself | Its percentile and gain rows |
| Growth notifications | — | The low-gain notification |
| Pediatrician report | The report on screen (averages) | Its PDF (Share) |
| Export | — | PDF and CSV |
| Reminders | All of them | — |
| Widgets, Live Activity | All of them | — |

## Where the paywall opens

Settings → Premium (the only place for Restore), the history lock, a locked
Growth card, the pediatrician report's Share, a locked weekly chart, and the
offer card on Home. Onboarding and events no longer open it.

## How a string is checked

- A free promise never says or implies unlimited, all or forever history:
  "Tracking is free" promises the act of recording, and the Premium side
  names "records older than 15 days".
- A Premium line names a figure or a function from the Premium column: "gain
  in grams", "the centile trend", "a PDF for your pediatrician". It never
  names a free surface: the WHO curve, the percentile, the weekly summary on
  Home, the report on screen.
- No Premium line sells a warning or a safety fact: the low-gain
  notification, medications and reminders are never sold.
- No string names a price, a saving or a trial length outside the paywall's
  own price lines.
- The rules for each surface: `voice.md` § Surface rules (Paywall list, The
  Premium offer, Locked weekly chart).

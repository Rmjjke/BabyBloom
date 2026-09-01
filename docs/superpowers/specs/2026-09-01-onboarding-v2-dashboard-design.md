# Onboarding v2 and the Dashboard's Growth surface — design

Date: 2026-09-01
Source: the owner's seven-point review of TestFlight build 8, decisions
settled in chat the same day.
Tasks: three streams — `onboarding-visual-identity` (short),
`onboarding-notify-widget-pages` (short), `dashboard-growth-premium` (long)
— one plan and one PR each. Streams A and C run in parallel (disjoint
files, separate worktrees); B starts after A merges, since both touch
`OnboardingView` and B's new pages must be born on A's shared backdrop.

## Verified starting points

- `BBLogo` is square app-icon art with its own opaque background, placed
  raw in four places; on `WelcomePage` it sits square inside a soft circle.
- Only `WelcomePage` has the soft-blob backdrop; every other onboarding
  page sits on flat `BBTheme.Colors.background` (`OnboardingView:28`).
- `PaywallView:89` still shows `Image(systemName: "laurel.leading")`.
- The notification permission fires from `BabyBloomApp:52` the moment
  onboarding completes — the system dialog lands on top of the Dashboard
  (documented as an e2e trap in `.desk/app-map.md`).
- The widget views compile into the APP target (`Features/Widget/`), so an
  onboarding page can render the real widgets.
- `LockedInsightCard(title:teaser:onUnlock:)` exists
  (`GrowthInsightCards.swift:222`).
- Event creation has exactly two entry points: the Dashboard quick action
  (`showQuickEventSheet`) and `EventsView:36`'s add sheet.
- Dashboard section order: header → activeTimers → quickActions → stats →
  progress → recentEvents.

## Owner decisions (2026-09-01)

1. Growth on the Dashboard is gated by a **permanent teaser**, not a
   free-first-days window (a section that vanishes after two days reads as
   breakage, in the one domain where the app must never frighten).
2. Recent events move **entirely to More** as their own screen; the
   Dashboard drops the section.
3. Onboarding order: … → Fact → Generating → **Notifications** →
   **Widget** → Premium. (Backlog #1: a Growth showcase page joins the flow
   in the next pass — "наш главный козырь".)
4. Events: **creation** is premium-gated; viewing existing events stays
   free — recorded data is never taken away.
5. Skip-X delay on the onboarding paywall: 3 s → **5 s**.

---

## Stream A — visual identity (`onboarding-visual-identity`, short)

### A1. `BrandMark` — one brand badge instead of four raw squares

New `BabyBloom/DesignSystem/Components/BrandMark.swift`:

- `BrandMark(diameter: CGFloat, onGradient: Bool = false)` — `Image("BBLogo")`
  clipped to `Circle()` (the art's own background becomes the circle fill,
  turning the crop into a deliberate round badge), a hairline ring
  (`.white.opacity(0.35)` when `onGradient`, `BBTheme.Colors.primary.opacity(0.25)`
  otherwise — the gradient-context white is the same documented exception as
  the widget's), and the standard card shadow.
- Applied at: `WelcomePage` (replacing square-in-circle), `GeneratingPage`
  (ring center), `PremiumPage` hero, `PaywallView` hero — where it REPLACES
  the laurel, ending the last laurel in the app.

### A2. `OnboardingBackground` — one backdrop for the whole flow

- Extract `WelcomePage`'s blob backdrop into
  `BabyBloom/Features/Onboarding/OnboardingBackground.swift`: two-three
  blurred radial blobs of `BBPrimary`/`BBAccent` at low opacity over
  `BBTheme.Colors.background`, drifting very slowly
  (`repeatForever(autoreverses:)`, ~20 s period), stilled under Reduce
  Motion.
- Rendered ONCE in `OnboardingView`'s ZStack behind the page switcher;
  pages lose their own background fills and become transparent over it.
  `WelcomePage` drops its private copy.
- Dark mode: the same blobs at the SAME opacity set — implementation showed
  one 0.12–0.20 band reads correctly in both themes (verified by eye:
  visible warmth, intact text contrast), so no per-theme values exist to
  drift apart. (Amended 2026-09-01 at stream review; the original text
  demanded reduced dark opacity.)

### A3. Mechanical

- `PremiumPage` close-X delay: `3_000_000_000` → `5_000_000_000`, comment
  updated (owner ruling; the never-fails-to-appear invariant from the
  previous spec is unchanged).

### Verification

- Render dump or run-and-look of every onboarding page, light + dark, RU:
  the same backdrop visibly continuous across pages; the badge round with
  its ring on all four surfaces; no laurel anywhere (`grep laurel` = 0).
- Suite stays green (189).

## Stream B — two new onboarding pages (`onboarding-notify-widget-pages`, short)

Flow becomes: Welcome → Name → Birth → Feeding → Growth → Fact →
Generating → **Notifications** → **Widget** → Premium (10 pages;
`OnboardingStep` enum + progress math updated).

### B1. Notifications page

Placed right after Generating — whose last step just said «настраиваем
умные напоминания», so the ask lands motivated.

- Copy (en/ru/es, agent-written, name woven in): headline like «Мы
  напомним, когда %@ пора есть или спать», 2–3 bullets grounded in real
  behaviour (the feeding reminder adapts to the parent's own logged
  rhythm; wake windows follow age; quiet by design — no spam), from
  NOTIFICATIONS.md's actual rules.
- CTA «Включить уведомления» → `NotificationManager.requestPermission()`
  with a completion → auto-advance on ANY answer. Secondary «Не сейчас» →
  advance. `requestPermission` gains a completion callback (it currently
  fires blind); no other behaviour change.
- `BabyBloomApp:52`'s post-onboarding `requestPermission()` call is
  REMOVED — the dialog-over-Dashboard interstitial dies. The app-map entry
  about it is updated in the same PR.
- Edge: a re-onboarding user who already granted/denied — the system
  resolves the request instantly without UI; we advance on the callback
  either way. No custom pre-check needed.

### B2. Widget showcase page

- Renders the REAL `BabyBloomMediumWidgetView` (and the small one beside
  or below, if it fits) over `WidgetBackground`, in a rounded
  home-screen-like frame with the standard card shadow — constructed
  `BabyBloomEntry` with the baby's real name, a feeding 1 h ago, next feed
  in ~40 min, 6 today. Not a screenshot: the live views, which therefore
  can never drift from the shipped widget.
- Copy: what the widget answers (time to the next feed at a glance) + one
  how-to line (long-press the home screen → «+» → Bitty). Single CTA
  «Далее». No actions required of the user.
- The entry is built inline with fixed offsets from `Date()` — no seeding,
  no persistence; this page is pure presentation.

### Verification

- Run-and-look: fresh onboarding through both pages, RU + EN, light +
  dark; the system permission dialog appears ON the notifications page and
  no dialog appears over the Dashboard afterwards (the old trap is gone).
- Unit: `OnboardingStep` order test if one exists; otherwise the flow walk
  in Maestro is the evidence. Suite green.

## Stream C — Dashboard Growth + monetization (`dashboard-growth-premium`, long)

### C1. Growth section on the Dashboard

Between `progressSection` and (the removed) recents slot — the section
order becomes: header → activeTimers → quickActions → stats → **growth** →
progress.

- Header row «Рост и развитие» with a chevron — the whole header is a
  `NavigationLink` pushing `GrowthView()` (the Dashboard already sits in a
  `NavigationStack`).
- Free content, always visible: latest weight (`growthEntries.first`) and
  the calm word-status line the Nutrition philosophy already ships free —
  reusing `FeedingAdequacy`'s assessment word, never a number that alarms.
  With no weighings yet: «Добавьте первое взвешивание» — an invitation,
  not an empty state (the widget's empty-state rule, applied here).
- Premium content in the same card: the gain-vs-reference line and
  percentile — for free users replaced by `LockedInsightCard`
  (title «Динамика и перцентили», teaser one line, `onUnlock` presents
  `PaywallView` as a sheet). `-BBForcePremium` opens it for e2e, as
  everywhere.

### C2. Recents move to More

- New `BabyBloom/Features/Dashboard/RecentActivityView.swift` (or
  `Features/Events/` — implementer's call by cohesion): the existing
  `RecentEvent` list UI moves out of `DashboardView` wholesale.
- A `NavigationLink` row «Недавние записи» in `MoreView`, icon
  `clock.arrow.circlepath`, placed after Growth's row.
- `DashboardView` loses `recentEventsSection` and its helpers; the
  `recentEvents` computed property moves with the view.

### C3. Events creation gate

- Both entry points check `store.isPremium`: the Dashboard quick action
  and `EventsView`'s add button present `PaywallView` in a sheet instead
  of `AddEventSheet` when not premium.
- Viewing, editing, deleting EXISTING events stays free (recorded data is
  never held hostage — deletion especially must stay free).
- The quick-action icon gains a small lock badge when locked, so the gate
  is visible before the tap — no bait-and-switch.

### Verification

- Run-and-look, seeded `healthy` + `-BBForcePremium` on/off: free
  dashboard shows weight + calm word + locked card; premium shows the
  numbers; lock badge on the Events quick action only when free; both
  gated entries open the paywall sheet; recents reachable via More and
  gone from the Dashboard.
- The existing `AC1/AC2` nutrition e2e flows must stay green (they assert
  on the Growth SCREEN, untouched).
- Suite green; new unit tests only if the free/premium branch logic earns
  one (a pure helper deciding the section's mode would).

## Execution

- Implementers and reviewers dispatched on **Opus** (owner's instruction);
  final whole-branch reviews likewise.
- Stream A ∥ Stream C in separate worktrees; B after A merges. Each stream:
  own card, branch (`feature/<stream>`), plan, per-task reviews, final
  review, PR. Evidence read by eye — this session's standing lesson.

## Out of scope (backlogged)

- Growth showcase page in onboarding (backlog #1, owner: next pass).
- Enforcing «Unlimited history» (backlog #2 — the paywall promises what
  nothing gates; needs a product decision on the free window).
- Widget deep links / Lock Screen / how-to screen (backlog #3–5).

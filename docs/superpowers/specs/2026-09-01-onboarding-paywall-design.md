# Onboarding paywall and pre-paywall polish — design

Date: 2026-09-01
Tasks: `.desk/tasks/onboarding-paywall/` (long) and `.desk/tasks/onboarding-delight/` (short)
Scope approved by the owner in chat, 2026-09-01, all four points.

## The findings this starts from

1. **The onboarding "Start Free Trial" button purchases nothing.**
   `PremiumPage.onTrial` is wired to `createAndFinish()` — the same closure as
   "Continue with free version". No plan selection, no price, no StoreKit
   call. The screen promises a trial that does not exist. The real paywall
   (plans, prices, purchase — PR #17) is reachable only from Settings.
   This is an App Review liability (3.1.2: price and terms must be shown
   before a subscription CTA) and, worse, a broken promise to the user.

2. **Apple grants ONE introductory offer per subscription group per Apple
   ID** — not one per plan. All three products share a group. A user who
   takes the weekly 3-day trial permanently loses the yearly 7-day one.
   "Trial on every plan" therefore spends the single credit on whichever
   plan is touched first, i.e. usually the cheapest.

3. The fact screen shows one hardcoded fact forever, behind a stock
   lightbulb, with one entrance animation and then stillness.

4. The generating screen runs 4 × 600 ms + 800 ms ≈ 3.2 s of perfectly
   uniform ticks — too fast and too regular to read as real work.

## Owner decisions (2026-09-01)

- **Trial on the yearly plan only (7 days).** Weekly and monthly lose their
  intro offers. Weekly IS the low-commitment tryout; its price is the trial.
  The group's single intro credit goes to the plan with the highest LTV.
  - Owner's action: remove the intro offers from
    `com.nenita.app.premium.weekly` and `.monthly` in App Store Connect.
  - Repo's action: mirror in `Nenita.storekit` (drop the P3D and monthly
    7-day offers, keep yearly's 7 days). No price changes.
  - No code change required for the wording: the paywall already derives
    trial text from `product.subscriptionInfo?.introductoryOffer` and
    already hides trial promises from users who spent the credit
    (`refreshIntroOfferEligibility`). Plans without an offer automatically
    show price-only copy — that path shipped in #17.
- Paywall work first; fact + generating screens second, as one short task.
- Fact copy and translations: written by the agent (EN/RU/ES).

## Task 1 — the onboarding paywall (`onboarding-paywall`, long)

### Shared plan picker

The plan selector, savings badge, per-plan trial/price line and the legal
footer currently live inside `PaywallView` (446 lines). They are extracted
into a component both paywalls compose:

- New file `BabyBloom/Features/Premium/PlanPickerSection.swift`:
  `planSelector` + `planRow` + the savings computation + the CTA-label and
  trial-line derivation (`trialText`-family) move there, parameterized by
  `SubscriptionManager` and a `@Binding selectedID`. `PaywallView` shrinks
  to hero + features + picker + restore/legal; `PremiumPage` composes the
  same picker. One source of truth — the two paywalls cannot drift, which
  is exactly how the onboarding one rotted last time.
- The legal footer (Terms, Privacy, auto-renew line) is part of the shared
  component, so no paywall can ship without it.

### PremiumPage rework

- Hero: `laurel.leading` replaced with the brand mark — `BBLogo`, as on the
  generating page next to it. Gradient header stays.
- Features list stays as is.
- Below features: the shared plan picker, yearly preselected.
- CTA becomes honest and dynamic, same derivation the main paywall uses:
  eligible + offer → "Try 7 days free", then price; no offer → "Subscribe —
  <price>". Tapping it calls `SubscriptionManager.purchase(_:)` for the
  selected product:
  - success → `createAndFinish()` (profile creation is unchanged);
  - cancel/failure → stay on the page, no error theatre beyond what the
    main paywall already shows.
- Skip becomes an "X" close button, top-LEFT, fading in 3 seconds after
  the screen appears (owner ruling, 2026-09-01 — replaces the "Continue
  with free version" text button). Still one tap once visible; a
  VoiceOver label ("close"), a comfortable hit target, and the fade
  respects `reduceMotion` (appears without animation, same 3 s delay).
  The delay is a common, review-safe pattern so long as the button
  reliably exists; it must never fail to appear — the timer starts
  `onAppear` and is not cancelled by scrolling.
- Products start loading when ONBOARDING starts (not when the page
  appears), so prices are ready eight pages later; the picker's existing
  `premium.loading` state covers slow networks.
- The stale `onboarding.premium.badge` line is replaced by the shared
  per-plan trial line.

### Verification

- Existing `SubscriptionSavingsTests` untouched and green — the arithmetic
  does not move, only the views around it.
- Run-and-look on the simulator with `Nenita.storekit` (simctl applies it —
  knowledge.md `## StoreKit`): fresh onboarding (no
  `-hasCompletedOnboarding`), walk to the paywall, screenshot: three plans
  with real prices, yearly preselected with "Save NN%", CTA shows the
  7-day wording for yearly and price-only after switching to weekly;
  purchase sheet appears on CTA tap; the X is absent on arrival, present
  after ~3 s, and lands on the Dashboard.
- Both themes, RU at minimum (longest strings).
- The main paywall re-shot once after extraction: pixel-parity is not
  required, but nothing may be lost (savings badge, trial line, legal).

## Task 2 — fact + generating screens (`onboarding-delight`, short)

### Fact screen

- A pool of 6–8 facts in the localization JSONs (`onboarding.fact.pool.*`),
  each with an optional numeric highlight. Selection by what we already
  know at page 6: the baby's age bracket (newborn / 1–3 mo / 3–6 mo / 6+)
  and feeding type, with the name woven into the text. Seeded per launch so
  repeat onboardings vary.
- The number in the fact counts up as the card appears
  (`contentTransition(.numericText)` or a timer-driven count).
- The lightbulb is replaced by the brand leaf; behind it a slow, looping
  drift of feeding/sleep/drop symbols and a gentle gradient shimmer —
  pure SwiftUI, no new dependencies, `reduceMotion`-respecting.
- Copy: agent-written EN/RU/ES, all six JSON files (widget copies must
  stay in sync — the pre-build guard enforces it).

### Generating screen

- Total runtime ≈ 4.5 s (owner: +40%).
- Five steps instead of four: the new one is personalized —
  "Calibrating for <name> — <age>" — placed second.
- Uneven step delays (e.g. 0.5 / 1.1 / 0.7 / 1.3 / 0.6 s): uniform ticks
  read as animation, uneven ones as work.

### Verification

- Run-and-look: fresh onboarding through both screens in RU and EN, both
  themes; confirm the counter animates, the fact varies across two runs
  with different birth dates, and the generating page's total time lands
  near 4.5 s (log timestamps or screen recording).
- Unit test for the fact-selection function (age bracket + feeding type →
  expected pool subset; deterministic under an injected seed).

## Out of scope

- Any change to prices or to the main paywall's structure beyond the
  extraction.
- Paywall A/B testing, analytics events, promo offers, win-back offers.
- The in-app "how to add a widget" screen and the widget deep links
  (separate backlog items).

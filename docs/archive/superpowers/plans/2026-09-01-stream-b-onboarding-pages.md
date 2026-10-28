# Stream B: Notifications + Widget Onboarding Pages Implementation Plan

> **For agentic workers:** STARTS ONLY AFTER STREAM A MERGES (shared `OnboardingView`; the new pages are born on A's shared backdrop). One implementer; review per stream.

**Goal:** Two new onboarding pages — a motivated notification ask right after Generating, and a widget showcase rendering the real widget views — making the flow ten pages and killing the permission-dialog-over-Dashboard interstitial.

**Spec:** `docs/superpowers/specs/2026-09-01-onboarding-v2-dashboard-design.md` (Stream B — binding).

## Global Constraints

Same as the sibling plans: Swift 6 / strict concurrency; `.l` strings ×6 JSON files with byte-synced widget copies; comments why-not-what; xcodegen + pbxproj proof for new files; suite baseline is whatever main carries after streams A and C (≥189); explicit-path commits with the `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` trailer; Reduce Motion respected; evidence read by eye and saved under `/Users/roman/BabyBloom/.desk/tasks/onboarding-notify-widget-pages/docs/evidence/`.

---

### Task B1: Notifications page

**Files:** Create `BabyBloom/Features/Onboarding/Pages/NotificationsPage.swift`; modify `Services/NotificationManager.swift` (completion), `App/BabyBloomApp.swift` (remove the post-onboarding call), `OnboardingView.swift` (step), localization ×6, `.desk/app-map.md` (main checkout — the interstitial entry).

- [ ] `NotificationManager.requestPermission(completion: (@Sendable (Bool) -> Void)? = nil)` — same UNUserNotificationCenter call, completion invoked on the main actor with `granted`. Existing no-argument call sites keep compiling (default nil).
- [ ] Page: `BrandMark`-consistent visual language (bell in a soft circle is fine — do NOT reuse BrandMark for a non-logo), headline `onboarding.notify.title` with the baby's name («Мы напомним, когда %@ пора есть или спать»), 2–3 bullets FROM REAL BEHAVIOUR (read `NOTIFICATIONS.md` first): the feeding reminder adapts to the parent's own logged rhythm; wake windows follow age; quiet by design. CTA `onboarding.notify.cta` («Включить уведомления») → `requestPermission { _ in onContinue() }`; secondary `onboarding.notify.later` («Не сейчас») → `onContinue()`. Copy en/ru/es, agent-written; name slots nominative-safe (the declension lesson).
- [ ] `BabyBloomApp`: the `NotificationManager.shared.requestPermission()` inside `onComplete` is deleted; comment explains where the ask now lives.
- [ ] `.desk/app-map.md`: the "Notification permission dialog fires immediately after tapping the paywall's X" trap entry is rewritten to describe the new page (dialog appears ON the page; nothing fires after onboarding).
- [ ] Build + suite; commit: `feat: the notification ask becomes a motivated onboarding page`

### Task B2: Widget showcase page

**Files:** Create `BabyBloom/Features/Onboarding/Pages/WidgetShowcasePage.swift`; `OnboardingView.swift` wiring; localization ×6.

- [ ] Renders the REAL views: a `BabyBloomEntry(date: .now, babyName: <real name or default>, lastFeedingTime: -1h, sleepStartTime: nil, lastSleepDuration: formatted 1h05, todayFeedingCount: 6, isAsleep: false, nextFeedingTime: +40min)` — read `WidgetViews.swift` for the CURRENT initializer first; do not guess fields. Show `BabyBloomMediumWidgetView(entry:)` over `WidgetBackground()` clipped to `RoundedRectangle(cornerRadius: 24)`, `.frame(height: ~160)`, card shadow — a home-screen-like specimen; the small view beside/below only if it fits without crowding (implementer judges, states the call).
- [ ] Copy: `onboarding.widget.title` («Виджет на домашний экран»), one line of value (time to next feed without opening the app), one how-to line `onboarding.widget.howto` (long-press → «+» → app name via `brand.name` composition). CTA `button.next`-family «Далее». No user actions.
- [ ] Flow: `OnboardingStep` gains `.notifications` and `.widgets` between `.generating` and `.premium`; progress denominator updates wherever it is derived; back-button behaviour consistent with neighbours.
- [ ] Build + suite; commit: `feat: onboarding shows the real widget before the paywall`

### Task B3: Verification sweep

- [ ] Fresh onboarding walk (Maestro, `clearState`, no `-hasCompletedOnboarding`), ru + en, light + dark: the permission dialog appears ON the notifications page ("Don't Allow"/"Allow" tap advances), the widget page shows the named widget, Premium follows, and NO dialog covers the Dashboard after finish (assert on the greeting being visible immediately — the exact old trap, inverted).
- [ ] Update the app-map walk-anchors table with the two new steps.
- [ ] Full suite; evidence saved and READ.

# Stream C: Dashboard Growth + Monetization Implementation Plan

> **For agentic workers:** Execute task-by-task in order; checkbox steps. One implementer owns the stream; review follows per stream.

**Goal:** A Growth section on the Dashboard (calm free summary + permanent premium teaser), recent events moved to their own screen under More, and event creation behind the paywall with a visible lock.

**Architecture:** The `RecentEvent` list UI moves wholesale out of `DashboardView` into a `RecentActivityView` reached from More. The freed Dashboard slot (conceptually) is taken by a `growthSection` placed between stats and progress: free content derives from the queries `DashboardView` already holds; the premium half is the existing `LockedInsightCard` opening `PaywallView` in a sheet. Event creation's two entry points branch on `store.isPremium`.

**Spec:** `docs/superpowers/specs/2026-09-01-onboarding-v2-dashboard-design.md` (Stream C — binding; owner decisions listed there).

## Global Constraints

- Swift 6.0 / iOS 17 / strict concurrency; strings via `.l` — every new key into `BabyBloom/Resources/Localization/{en,ru,es}.json` AND copied to the three `WidgetResources/Localization/` files (pre-build guard). No colour literals; comments why-not-what ~1/6–10.
- No price/trial/medical thresholds in source. The free summary uses `FeedingAdequacy`'s word-status philosophy: calm words, never alarming numbers, gain-is-the-only-trigger (DECISIONS.md 2026-08-25 binds this section too).
- Generated project: new files need `xcodegen generate` + pbxproj grep proof.
- Suite baseline 189. Build/test destination uses YOUR OWN simulator (name given in the dispatch) — another stream owns the default one.
- No `git add -A`; explicit paths; trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

### Task C1: Recents move to More

**Files:** Create `BabyBloom/Features/Dashboard/RecentActivityView.swift`; modify `DashboardView.swift` (remove `recentEventsSection`, its row helpers and the `recentEvents` computed), `BabyBloom/App/MainTabView.swift` (`MoreView` row).

- [ ] Move — do not rewrite — the list UI: `recentEvents` computed (with its queries' data passed via `@Query` in the new view), `recentEventsSection` body, the per-kind row rendering, `RecentEvent` enum stays where it is if other code uses it (grep first; if Dashboard-only, it moves too). Title key: new `nav.recent_activity` ("Recent activity" / "Недавние записи" / "Actividad reciente") ×6 JSONs.
- [ ] `MoreView`: `NavigationLink(destination: RecentActivityView())` with `Label("nav.recent_activity".l, systemImage: "clock.arrow.circlepath")`, placed after the Growth row.
- [ ] Dashboard body loses the section; order now ends `statsSection, progressSection`.
- [ ] Build + suite; commit: `feat: recent activity moves to its own screen under More`

### Task C2: Growth section on the Dashboard

**Files:** Modify `DashboardView.swift` (new `growthSection` between `statsSection` and `progressSection`); possibly a small pure helper + unit test if the free/premium mode logic earns one; localization keys ×6.

- [ ] Header row: title `dashboard.growth.title` ("Growth" / "Рост и развитие" / "Crecimiento") + chevron; whole header is a `NavigationLink { GrowthView() }` (Dashboard already sits in a NavigationStack).
- [ ] Free content (always): latest weight from the existing `growthEntries` query ("3.50 kg" style, reuse existing formatting used by the stats tile if any) and the calm word line — derive via `FeedingAdequacy` exactly the way `GrowthView`'s free Nutrition row does (read `NutritionSection`/`GrowthView` first; reuse their assessment entry point rather than re-deriving thresholds). No weighings → `dashboard.growth.empty` invitation key ("Add the first weighing…"), not dashes.
- [ ] Premium half: for `store.isPremium` (which honours `-BBForcePremium`), one line gain-vs-reference + percentile (reuse `WeightVelocity`/`WHOGrowthStandard` calls as `GrowthView` makes them); for free users `LockedInsightCard(title: "dashboard.growth.locked_title".l, teaser: "dashboard.growth.locked_teaser".l, onUnlock: { showPaywall = true })` and `.sheet(isPresented: $showPaywall) { PaywallView() }` (pattern exists in `MainTabView` — mirror it; `DashboardView` gains `@Environment(SubscriptionManager.self) private var store` and the state).
- [ ] Keys: title, empty, locked_title, locked_teaser + whatever the free line needs — ×6 JSONs, byte-synced copies.
- [ ] Build + suite; commit: `feat: a Growth section on the Dashboard, calm and free with a premium teaser`

### Task C3: Event creation behind the paywall

**Files:** Modify `DashboardView.swift` (quick action) and `BabyBloom/Features/Events/EventsView.swift` (add button).

- [ ] Dashboard quick action "Events": when `!store.isPremium`, tapping sets `showPaywall = true` instead of `showQuickEventSheet`; the button's icon gains a small `lock.fill` badge overlay (bottom-trailing, `BBTheme.Colors.textSecondary`) so the gate is visible before the tap.
- [ ] `EventsView`: the control at line ~36 that presents `AddEventSheet` branches the same way (gains its own store env + paywall sheet if it lacks one). Viewing/editing/deleting existing events untouched — verify by reading the file that no other mutation path exists; name what you checked.
- [ ] Build + suite; commit: `feat: event creation asks for Premium, with the lock visible before the tap`

### Task C4: Verification sweep

- [ ] Run-and-look on YOUR simulator, seeded `-BBSeedScenario healthy`, twice: with and without `-BBForcePremium true`. Read the screenshots: free Dashboard = weight + calm word + LockedInsightCard + lock badge on Events; premium = numbers, no locks; both gated entries open the paywall sheet; recents present in More, absent on the Dashboard; Growth header pushes GrowthView.
- [ ] Existing e2e: `maestro test .desk/tests/AC1-nutrition-calm.yaml` and `AC2-nutrition-breakdown.yaml` (env exports per `.claude/skills/platform-run/SKILL.md`, `--device` = YOUR sim) — must stay green; they assert the Growth SCREEN this stream must not break.
- [ ] Full suite; evidence to `/Users/roman/BabyBloom/.desk/tasks/dashboard-growth-premium/docs/evidence/` (main checkout path — the worktree's .desk is separate). Final commit if anything changed.

## Self-check before reporting

Every Stream-C spec line implemented; the calm-words rule respected (no red, no alarming numerics in the free line); deletion of recorded events still free; screenshots READ.

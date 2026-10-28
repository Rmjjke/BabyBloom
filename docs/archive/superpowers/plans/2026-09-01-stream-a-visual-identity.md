# Stream A: Visual Identity Implementation Plan

> **For agentic workers:** Execute task-by-task in order; checkbox (`- [ ]`) steps. One implementer owns the whole stream; review follows per stream.

**Goal:** One circular brand badge everywhere, one shared drifting onboarding backdrop, a 5-second paywall X.

**Architecture:** A `BrandMark` view in DesignSystem clips the square `BBLogo` art into a round badge (its own background becomes the circle fill) and replaces all four raw placements including the laurel in `PaywallView`. `WelcomePage`'s blob backdrop is extracted into `OnboardingBackground` and rendered once by `OnboardingView` behind the page switcher, making every page (and the two future Stream-B pages) sit on the same ground.

**Spec:** `docs/superpowers/specs/2026-09-01-onboarding-v2-dashboard-design.md` (Stream A — binding).

## Global Constraints

- Swift 6.0 / iOS 17 / strict concurrency. No colour literals in views (BBTheme tokens; `.white.opacity(...)` on a brand-gradient context is the one documented exception, and the BrandMark ring on gradients uses exactly that).
- Comments ~1 per 6–10 lines, why-not-what. Strings via `.l` (this stream adds NO strings).
- Generated project: after creating a Swift file run `xcodegen generate` and prove it took (`grep -c <File>.swift BabyBloom.xcodeproj/project.pbxproj` ≥ 2).
- Build/test: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=<SIM>' -derivedDataPath .superpowers/build build|test`. Suite baseline 189.
- Reduce Motion stills every repeatForever animation you add.
- No `git add -A`; commit with explicit paths and the `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` trailer.

---

### Task A1: `BrandMark`

**Files:** Create `BabyBloom/DesignSystem/Components/BrandMark.swift`; modify `Pages/WelcomePage.swift`, `Pages/GeneratingPage.swift`, `Pages/PremiumPage.swift` (hero), `Features/Premium/PaywallView.swift` (heroHeader, laurel out).

- [ ] `BrandMark(diameter: CGFloat, onGradient: Bool = false)`: `Image("BBLogo").resizable().scaledToFill().frame(width: d, height: d).clipShape(Circle())`, overlay `Circle().stroke(onGradient ? .white.opacity(0.35) : BBTheme.Colors.primary.opacity(0.25), lineWidth: 1)`, `.bbShadow(BBTheme.Shadow.card)`. Doc comment: why the circle clip makes the square art read as a designed badge, and why the ring colour splits on context.
- [ ] Welcome: replace the square-in-circle block with `BrandMark(diameter: ~96)`. Generating: ring center keeps the progress ring, its inner image becomes `BrandMark(diameter: 44 → keep current size)` without the extra shadow if it fights the ring — implementer judges, states the call in the report. PremiumPage + PaywallView heroes: `BrandMark(diameter: 64, onGradient: true)`; delete the laurel `Image(systemName:)` block.
- [ ] `grep -rn "laurel" BabyBloom/` → zero hits. Build green.
- [ ] Commit: `feat: one circular BrandMark replaces four raw logo placements`

### Task A2: `OnboardingBackground`

**Files:** Create `BabyBloom/Features/Onboarding/OnboardingBackground.swift`; modify `OnboardingView.swift`, `Pages/WelcomePage.swift` (drop private backdrop); check every other page for its own background fill and remove ones that would occlude the shared ground.

- [ ] Extract Welcome's blob backdrop: 2–3 `Circle().fill(token.opacity(0.12–0.2)).blur(radius: 60–90)` blobs (BBPrimary/BBAccent) positioned asymmetrically over `BBTheme.Colors.background`, drifting via `repeatForever(autoreverses: true)` with a ~20 s period and small offsets; `@Environment(\.accessibilityReduceMotion)` freezes them. Dark mode: same tokens read darker automatically — verify visually, tune opacity only if unreadable.
- [ ] `OnboardingView`: wrap the page switcher in a ZStack with `OnboardingBackground()` behind; remove `.background(BBTheme.Colors.background...)` (line ~28) so the shared ground shows; pages must not paint their own opaque grounds.
- [ ] Build; full suite (189).
- [ ] Commit: `feat: one shared drifting backdrop under the whole onboarding flow`

### Task A3: X delay + evidence

- [ ] `PremiumPage`: `3_000_000_000` → `5_000_000_000`, comment names the owner ruling; the appears-always invariant text stays.
- [ ] Run-and-look on YOUR simulator (fresh onboarding, ru): screenshot Welcome, one quiz page, Fact, Generating, Premium — light AND dark. Read them: backdrop continuous, badge round with ring on all four surfaces, X absent at 4 s and present by ~5.5 s. Save to `.desk/tasks/onboarding-visual-identity/docs/evidence/` (in the MAIN checkout: /Users/roman/BabyBloom — the worktree's .desk is not shared; write evidence to the main path).
- [ ] Full suite once more; commit: `feat: the paywall X waits five seconds`

## Self-check before reporting

Every spec Stream-A line implemented; no laurel; no colour literal outside the documented gradient-ring exception; screenshots READ, not just taken.

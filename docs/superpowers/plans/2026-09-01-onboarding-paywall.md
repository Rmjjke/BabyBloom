# Onboarding Paywall Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the onboarding paywall a real paywall — plans, prices, an honest CTA that purchases, legal footer, delayed-X skip — by extracting the main paywall's plan machinery into one shared component.

**Architecture:** `PaywallView`'s plan selector, trial-line derivation, CTA, restore and legal footer move into a self-contained `PlanPickerSection` that owns its selection state and purchase flow; both paywalls compose it, so they cannot drift. `PremiumPage` gains the component, a brand-mark hero, a purchase-completes-onboarding callback and a skip-X that fades in after 3 s. Products load when onboarding starts, not when the page appears. `Nenita.storekit` mirrors the trial-only-on-yearly decision.

**Tech Stack:** Swift 6.0, SwiftUI, StoreKit 2, XCTest, XcodeGen. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-01-onboarding-paywall-design.md`

## Global Constraints

- Swift 6.0, iOS 17.0 deployment target, strict concurrency.
- ALL user-facing strings go through the JSON `LocalizationManager` and `.l`. New keys go into `BabyBloom/Resources/Localization/{en,ru,es}.json` AND the three `WidgetResources/Localization/` copies (`cp` after editing) — the pre-build script fails the build on drift.
- No price, saving or trial length is ever written into source (DECISIONS.md 2026-08-27). Everything derives from `Product`.
- No colour literals in views; comments ~1 per 6–10 lines, why not what.
- The Xcode project is generated; a new source file is invisible until `xcodegen generate` reruns, and XcodeGen ignores misplaced keys silently — verify the `.pbxproj` changed.
- Branch `feature/onboarding-paywall` (already exists, carries the spec commits). Do not run `git add -A`; `docs/TASK-app-captures.md` stays untracked.
- Build/test invocations as in ARCHITECTURE.md: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .superpowers/build build|test`. Suite baseline: 184 tests.
- The skip path must remain reachable: the X always appears; its 3 s timer starts in `onAppear` and nothing cancels it.

---

### Task 1: Mirror trial-only-on-yearly in the local StoreKit config

The owner is removing the weekly (P3D) and monthly (P1W free) introductory offers in App Store Connect. The local config the simulator uses must say the same, or every local run shows trials production will not grant.

**Files:**
- Modify: `Nenita.storekit` (JSON — `subscriptionGroups[0].subscriptions[*].introductoryOffer`)

**Interfaces:**
- Consumes: nothing.
- Produces: a storekit config where ONLY `com.nenita.app.premium.yearly` has `introductoryOffer` (free, `P1W`); weekly and monthly carry `"introductoryOffer": null`. Tasks 2–5 rely on this when exercising the no-trial CTA path.

- [ ] **Step 1: Edit the config**

In `Nenita.storekit`, set `introductoryOffer` to `null` for `com.nenita.app.premium.weekly` and `com.nenita.app.premium.monthly`. Leave yearly's `{"paymentMode": "free", "subscriptionPeriod": "P1W", ...}` untouched. Edit only these fields — prices and periods stay.

- [ ] **Step 2: Verify the JSON and the invariant**

```bash
python3 -c "
import json
d = json.load(open('Nenita.storekit'))
subs = d['subscriptionGroups'][0]['subscriptions']
offers = {s['productID']: s.get('introductoryOffer') for s in subs}
assert offers['com.nenita.app.premium.yearly'] is not None
assert offers['com.nenita.app.premium.weekly'] is None
assert offers['com.nenita.app.premium.monthly'] is None
print('storekit mirror OK')
"
```

Expected: `storekit mirror OK`.

- [ ] **Step 3: Run the full suite**

Expected: 184 tests, 0 failures — nothing reads the offers at test time (`SubscriptionSavingsTests` is price arithmetic only).

- [ ] **Step 4: Commit**

```bash
git add Nenita.storekit
git commit -m "chore: local StoreKit config carries a trial on yearly only"
```

---

### Task 2: Extract `PlanPickerSection` and make the CTA honest

Everything both paywalls must agree on moves into one component: plan rows, savings badge, trial line, CTA, pending/error states, restore, legal links. The component owns its `selectedID` state and its load-retry logic. This task also fixes a latent defect: the CTA label is hardcoded to "Start Free Trial" (`onboarding.premium.trial`) regardless of plan — with trials on yearly only, that is a lie on two of three plans.

**Files:**
- Create: `BabyBloom/Features/Premium/PlanPickerSection.swift`
- Modify: `BabyBloom/Features/Premium/PaywallView.swift` (remove the moved sections; compose the component)
- Modify: the six localization JSONs (two new keys)
- Modify: `project.yml` — NOT modified; but run `xcodegen generate` so the new file enters the app target, and verify: `grep -c "PlanPickerSection.swift" BabyBloom.xcodeproj/project.pbxproj` ≥ 2.

**Interfaces:**
- Consumes: `SubscriptionManager` from `@Environment` (`yearlyProduct/monthlyProduct/weeklyProduct`, `isLoading`, `purchaseError`, `purchasePending`, `isEligibleForIntroOffer`, `isEntitled`, `loadProducts()`, `purchase(_:)`, `restorePurchases()`, `savingsPercent`, `PlanPeriod`).
- Produces: `struct PlanPickerSection: View` with `init(onPurchased: (() -> Void)? = nil)`. After a purchase that ends with `store.isEntitled == true`, it calls `onPurchased`. Tasks 3–4 rely on exactly this name and callback.

- [ ] **Step 1: Add the CTA keys to all six JSONs**

`en.json`:
```json
  "premium.cta_trial_fmt": "Try %d days free",
  "premium.cta_subscribe": "Subscribe"
```
`ru.json`:
```json
  "premium.cta_trial_fmt": "Попробовать %d дн. бесплатно",
  "premium.cta_subscribe": "Оформить подписку"
```
`es.json`:
```json
  "premium.cta_trial_fmt": "Prueba %d días gratis",
  "premium.cta_subscribe": "Suscribirse"
```
Then: `for f in en ru es; do cp BabyBloom/Resources/Localization/$f.json WidgetResources/Localization/$f.json; done`

- [ ] **Step 2: Create the component by MOVING, not rewriting**

Create `PlanPickerSection.swift` and move these members out of `PaywallView.swift`, verbatim except where this step says otherwise: `planSelector` (PaywallView.swift:191), `planRow(...)` (:218), `ctaSection` (:320), `footerLinks` (:371), `selectedProduct` (:384), `yearlySavingsPercent` (:396), `trialLine` (:413), `days(in:)` (:432), `reloadProducts()` (:441), and the `@State private var selectedID = SubscriptionManager.yearlyID`. Skeleton:

```swift
import SwiftUI
import StoreKit

/// The half of a paywall the two paywalls must never disagree on: plans,
/// prices, the trial promise, the purchase button, restore, and the legal
/// footer. The onboarding paywall rotted precisely because it was a separate
/// implementation; composing this section is what prevents a recurrence.
struct PlanPickerSection: View {
    @Environment(SubscriptionManager.self) private var store
    @State private var selectedID = SubscriptionManager.yearlyID

    /// Called after a purchase completes with entitlement. The onboarding
    /// paywall finishes onboarding here; the settings paywall passes nothing
    /// and shows its own active badge instead.
    var onPurchased: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: BBTheme.Spacing.lg) {
            if store.purchaseError != nil && store.yearlyProduct == nil {
                loadErrorView
            } else {
                planSelector
                ctaSection
            }
            footerLinks
        }
        .task { await reloadProducts() }
    }
    // moved members follow …
}
```

`loadErrorView` also moves (it is the retry state for the same rows). In `ctaSection`, two changes beyond the move:

1. The button label becomes plan-derived instead of the hardcoded key:

```swift
    /// "Try 7 days free" only when this plan HAS a trial this Apple ID can
    /// still take; otherwise plain "Subscribe". The old label promised a free
    /// trial on every plan, which trial-only-on-yearly turned into a lie on
    /// two of the three.
    private var ctaTitle: String {
        guard !store.isLoading else { return "premium.loading".l }
        guard let product = selectedProduct,
              store.isEligibleForIntroOffer,
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return "premium.cta_subscribe".l }
        return String(format: "premium.cta_trial_fmt".l, Self.days(in: offer.period))
    }
```

and `BBPrimaryButton(ctaTitle, icon: "arrow.right")` replaces the old label expression.

2. The purchase closure reports success:

```swift
                Task {
                    if let product = selectedProduct {
                        await store.purchase(product)
                        if store.isEntitled { onPurchased?() }
                    }
                }
```

- [ ] **Step 3: Recompose `PaywallView`**

In `PaywallView.body`, replace the `planSelector`/`loadErrorView` conditional, `ctaSection` conditional and `footerLinks` with:

```swift
                    if !store.isPremium {
                        PlanPickerSection()
                    } else {
                        footerLinksAreInsideThePicker_keepNothingHere
                    }
```

— concretely: `if !store.isPremium { PlanPickerSection() }`, and since `footerLinks` moved into the component, the already-premium branch keeps `activeBadge` + `featuresCard` only. Delete the moved members and the now-unused `@State selectedID` and `.task { await reloadProducts() }` wiring from `PaywallView`. `heroHeader`, `featuresCard`, `activeBadge` and `showRestoreAlert` stay.

- [ ] **Step 4: Regenerate, build, run the suite**

```bash
xcodegen generate
grep -c "PlanPickerSection.swift" BabyBloom.xcodeproj/project.pbxproj   # expect ≥ 2
```
Then build and full suite. Expected: `** BUILD SUCCEEDED **`, 184 tests, 0 failures.

- [ ] **Step 5: Run-and-look — the main paywall lost nothing**

Launch seeded (`-BBSkipSplash true -hasCompletedOnboarding true -appLanguage ru -BBSeedScenario healthy`), More → Профиль → premium row, screenshot. Confirm against the pre-change screen: three plans with prices, «Сэкономьте NN%» badge, per-plan trial line, restore link, Terms/Privacy. Selecting weekly must flip the CTA to «Оформить подписку» (no trial in the Task 1 config).

- [ ] **Step 6: Commit**

```bash
git add BabyBloom/Features/Premium/PlanPickerSection.swift BabyBloom/Features/Premium/PaywallView.swift \
        BabyBloom/Resources/Localization WidgetResources/Localization BabyBloom.xcodeproj/project.pbxproj
git commit -m "refactor: extract the shared PlanPickerSection and make the CTA plan-honest"
```

---

### Task 3: Rebuild `PremiumPage` around the real paywall

**Files:**
- Modify: `BabyBloom/Features/Onboarding/Pages/PremiumPage.swift`
- Modify: the six localization JSONs (one key edit)

**Interfaces:**
- Consumes: `PlanPickerSection(onPurchased:)` from Task 2.
- Produces: `PremiumPage(babyName:onPurchased:onSkip:)` — `onTrial` is renamed `onPurchased`, called only after entitlement; `onSkip` is now triggered by the delayed X. Task 4 updates the call site to these exact labels.

- [ ] **Step 1: Rework the page**

In `PremiumPage.swift`:

1. Rename `let onTrial` → `let onPurchased`.
2. Hero: replace the `Image(systemName: "laurel.leading")…` block with the brand mark used on the generating page:

```swift
                        Image("BBLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .padding(.top, 36)
                            .scaleEffect(appear ? 1 : 0.7)
```

3. Below the features card, replace the trial badge, `BBPrimaryButton("onboarding.premium.trial"…)` and the skip `Button` with:

```swift
                PlanPickerSection(onPurchased: onPurchased)
                    .padding(.horizontal, BBTheme.Spacing.lg)
                    .padding(.vertical, BBTheme.Spacing.xl)
                    .offset(y: appear ? 0 : 30)
                    .opacity(appear ? 1 : 0)
```

4. Skip becomes the delayed X, overlaid on the whole page (top level, after the `ScrollView`):

```swift
        .overlay(alignment: .topLeading) {
            if showClose {
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .padding(.top, 8)
                .padding(.leading, BBTheme.Spacing.md)
                .accessibilityLabel("common.close".l)
                .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appear = true }
            // The delay is review-safe ONLY because the button reliably
            // appears: the task is tied to the page, not to any subview, and
            // nothing cancels it.
            closeTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeIn(duration: 0.3)) { showClose = true }
            }
        }
        .onDisappear { closeTask?.cancel() }
```

with state `@State private var showClose = false`, `@State private var closeTask: Task<Void, Never>?`, and `@Environment(\.accessibilityReduceMotion) private var reduceMotion`. The old `.onAppear` animation block merges into this one.

5. Check whether `common.close` exists in the JSONs (`grep '"common.close"' BabyBloom/Resources/Localization/en.json`); if absent, add it to all six (`"Close"` / `"Закрыть"` / `"Cerrar"`) and re-copy the widget JSONs.
6. `onboarding.premium.trial` and `onboarding.premium.badge`, `onboarding.premium.skip` may now be unused — `grep -rn` each across `BabyBloom/`; delete from all six JSONs ONLY those with zero remaining uses, and say in the commit which were removed.

- [ ] **Step 2: Build**

Expected: one error — `OnboardingView.swift:57` still passes `onTrial:`. That is Task 4; do NOT fix it here if you are a different implementer. Same implementer executing sequentially: proceed to Task 4 before committing, then commit both tasks as their own commits (page first, wiring second) — the page commit may be build-broken in isolation, so fold Task 3+4 into ONE commit instead:

```bash
git add BabyBloom/Features/Onboarding/Pages/PremiumPage.swift BabyBloom/Features/Onboarding/OnboardingView.swift \
        BabyBloom/Resources/Localization WidgetResources/Localization
git commit -m "feat: the onboarding paywall sells the real plans, with a delayed-X skip"
```

(The single combined commit is the plan's choice; record it as such.)

---

### Task 4: Wire onboarding — early product load, new callbacks

**Files:**
- Modify: `BabyBloom/Features/Onboarding/OnboardingView.swift:55-58` and its top-level view.

**Interfaces:**
- Consumes: `PremiumPage(babyName:onPurchased:onSkip:)` from Task 3.
- Produces: nothing downstream.

- [ ] **Step 1: Update the call site and start the load early**

```swift
                    case .premium: PremiumPage(babyName: babyName,
                                               onPurchased: { createAndFinish() },
                                               onSkip:      { createAndFinish() })
```

Add to `OnboardingView` (it already has `@Environment(SubscriptionManager.self)`? — check; if not, add `@Environment(SubscriptionManager.self) private var store`) and on its outermost view:

```swift
        // Prices must be on screen by page 8. Loading starts with page 1 so a
        // slow network spends onboarding time, not paywall time.
        .task { await store.loadProducts() }
```

- [ ] **Step 2: Build + full suite**

Expected: `** BUILD SUCCEEDED **`, 184 tests, 0 failures.

- [ ] **Step 3: Commit** — see Task 3 Step 2 (one combined commit).

---

### Task 5: Verify the whole flow like a user

**Files:**
- Evidence: `.desk/tasks/onboarding-paywall/docs/evidence/`

**Interfaces:** consumes everything above; produces the acceptance evidence.

- [ ] **Step 1: Fresh onboarding to the paywall**

Erase state and launch WITHOUT `-hasCompletedOnboarding` (`xcrun simctl uninstall booted com.nenita.app` does not wipe the App Group — that is fine, onboarding is keyed on UserDefaults, and `clearState: true` in Maestro resets it). Walk the eight pages via Maestro or manually to the paywall. Screenshot at arrival and after 4 s:

- prices on all three rows, yearly preselected with the savings badge;
- CTA reads «Попробовать 7 дн. бесплатно»; after tapping the weekly row it reads «Оформить подписку»;
- the X is ABSENT on the first screenshot and PRESENT on the second;
- tapping the CTA opens the StoreKit purchase sheet (Nenita.storekit is wired into the scheme);
- cancelling the sheet stays on the page; tapping the X lands on the Dashboard.

- [ ] **Step 2: Both themes, RU + EN**

Repeat the arrival screenshot in dark mode and in English. RU is the longest-string check.

- [ ] **Step 3: Full suite, attach evidence, commit evidence-free**

Suite green at 184. Copy screenshots into the card's `docs/evidence/` (gitignored — nothing to commit). Update the card's `verify:` block and log.

---

## Self-Review

**Spec coverage.** Storekit mirror → T1. Shared picker incl. legal + restore → T2. Honest dynamic CTA → T2 (and the latent hardcoded-label defect it fixes is named there). Brand hero, purchase-finishes-onboarding, delayed X with reduceMotion/VoiceOver/never-fails-to-appear → T3. Early product load → T4. Run-and-look incl. X timing, purchase sheet, both themes → T5. Owner's ASC action is out of repo scope and tracked in the card.

**Placeholders.** The `footerLinksAreInsideThePicker_keepNothingHere` identifier in T2 Step 3 is deliberately not code — the sentence around it states the concrete edit; an implementer typing the identifier has not read the sentence. Kept as a tripwire.

**Type consistency.** `PlanPickerSection(onPurchased:)` defined in T2, consumed in T3 §3 and via `PremiumPage(babyName:onPurchased:onSkip:)` in T4 — labels match. `ctaTitle` uses `days(in:)` which moves in T2 with the rest. `common.close` is added conditionally with a stated check.

**Known risk, stated:** T3+T4 share one commit because the intermediate state does not build; the reviewer gets them as one diff.

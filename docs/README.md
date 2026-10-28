# Docs map

One line per doc: path — kind · owner · status. Kinds: **reference** (how
something is set up or works), **guide** (steps to follow), **decision**
(why it is this way), **task** (an open work spec), **log** (closed
history). A new doc gets its line here in the same change; a doc whose
subject closes moves to `archive/` with `git mv` and keeps its name.

The truth about the code lives at the repo root:
[ARCHITECTURE.md](../ARCHITECTURE.md) (how it works),
[DECISIONS.md](../DECISIONS.md) (why), [NOTIFICATIONS.md](../NOTIFICATIONS.md)
(notification catalogue), [README.md](../README.md) (product, roadmap,
palette of record), [CLAUDE.md](../CLAUDE.md) (working rules for agents).

## Live

### Release
- [release/apple-developer-setup.md](release/apple-developer-setup.md) — guide · Dev Lead · live (397 lines: split candidate)
- [release/app-store-connect-testflight.md](release/app-store-connect-testflight.md) — guide · Dev Lead · live

### Naming
- [naming/2026-08-08-english-names.md](naming/2026-08-08-english-names.md) — decision · owner · live (final brand names)
- [naming/2026-08-01-naming-analysis.md](naming/2026-08-01-naming-analysis.md) — decision · owner · live (wave 1)
- [naming/2026-08-06-naming-wave2.md](naming/2026-08-06-naming-wave2.md) — decision · owner · live (wave 2)
- [naming/2026-08-07-naming-wave3-tender.md](naming/2026-08-07-naming-wave3-tender.md) — decision · owner · live (wave 3)

### Design source art
- [design/icon-design-brief.md](design/icon-design-brief.md) — reference · Designer · live (icon brief)
- Icon candidates: `design/icon1.png`, `design/icon2.png`, `design/icon3.png`, `design/icon4.png` — reference · Designer · live
- Splash art: `design/splash1.png`, `design/splash2.png`, `design/splash2-notext.png`, `design/splash3.png`, `design/splash4.png`, `design/splash4-notext.png` — reference · Designer · live (splash4 ships; its `-notext` cut is the source of the `BBSplashBg` asset)

### Open tasks
- [tasks/adservices-attribution.md](tasks/adservices-attribution.md) — task · owner · open (AdServices install attribution; not in code yet)

## Archive (closed subjects, kept for history)

- [archive/subscriptions-2026-08-25.md](archive/subscriptions-2026-08-25.md) — log · closed (three plans shipped, #17 / #27)
- [archive/TASK-fix-legal-urls.md](archive/TASK-fix-legal-urls.md) — log · closed (paywall legal links fixed, 7c11701)
- [archive/TASK-review-fixes-1.4.1.md](archive/TASK-review-fixes-1.4.1.md) — log · closed (guideline 1.4.1 citations, #52 / #53)
- [archive/TASK-app-captures.md](archive/TASK-app-captures.md) — log · closed (store screen captures run)
- [archive/superpowers/](archive/superpowers/) — log · closed: superpowers specs and plans of shipped work (MVP readiness, weight gain, feeding↔weight link, onboarding + paywall, visual identity streams, widget redesign)

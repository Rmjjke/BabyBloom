# BabyBloom — Notification System Design

> Version 1.0 · April 2026  
> Covers: all push notification types, triggers, age-based logic, cancellation rules, and implementation notes.

---

## Overview

Notifications are divided into three categories:

| Category | Purpose |
|---|---|
| **Feeding** | Remind about next feeding; alert if BF session is too long |
| **Sleep** | Prompt nap when wake window expires; alert if sleep timer was forgotten |
| **Diaper** | Remind if no diaper has been logged for too long |
| **Engagement** | Prompt user to add measurements, check in weekly, re-engage after idle |

**Key philosophy:**
- No notification fires before the user has demonstrated intent to use the app (first real data entry).
- All reminders are age-adaptive — intervals shrink for newborns and relax as the baby grows.
- Every scheduled notification is replaced (cancelled then re-scheduled) on each relevant data save, so reminders always count from the *latest* event, not a fixed clock.

---

## 1. Activation Gates

Before any reminder category is active, a gate condition must be met:

| Gate | Condition | Enables |
|---|---|---|
| `hasLoggedFirstFeeding` | First `FeedingEntry` saved | Feeding reminders, Diaper reminders |
| `hasLoggedFirstSleep` | First `SleepEntry` saved | Sleep reminders |
| `hasLoggedFirstFeedingOrSleep` | Either of the above | Diaper reminders (if not already active) |
| `hasFirstGrowthEntry` | First `GrowthEntry` saved | Monthly measurement reminder; cancels one-time measurement prompt |

Gates are persisted in `@AppStorage` as `Bool` flags. They are checked before scheduling any notification in `NotificationManager`.

---

## 2. Feeding Notifications

### 2.1 Feeding Interval Reminder (`bb.feeding.reminder`)

Reminds the parent that it has been a while since the last feeding.

**Trigger:** Every time a feeding entry is saved (started or manually added).  
**Gate:** `hasLoggedFirstFeeding == true`  
**Action:** Cancel previous `bb.feeding.reminder`, schedule new one.

**Interval by baby age:**

| Age | Interval | Rationale |
|---|---|---|
| 0–4 weeks | 2.5 h | Newborns feed every 1.5–3 h; alert before the 3 h mark |
| 1–3 months | 3 h | Feeding sessions spacing out |
| 3–6 months | 3.5 h | Longer between feeds |
| 6–9 months | 4 h | Solids introduced; formula/breast spread out |
| 9–12 months | 4.5 h | Mostly solids, nursing/bottle as supplement |
| 12+ months | Disabled | Parent-led schedule; no automatic reminder |

**Cancellation:** Cancelled automatically when a new feeding is saved (before the new one is scheduled).

**Notification copy:**
- Title: `"Feeding Time 🍼"`
- Body: `"Your baby hasn't fed in about X hours. Don't forget to log the next feeding."`
  - Body text adapts to current interval (e.g. "2.5 hours" for a newborn).

---

### 2.2 Active Breastfeeding Alert (`bb.feeding.active.bf`)

Fires if a breastfeeding timer has been running for an unusually long time.

**Trigger:** When a `FeedingEntry` of type `.breast` is saved with `endTime == nil` (timer active).  
**Gate:** `hasLoggedFirstFeeding == true`  
**Interval:** 40 minutes (fixed — not age-based; 40 min is the medical threshold for concern).  
**Cancellation:** Cancelled immediately when the feeding timer is stopped (`endTime` set).

**Notification copy:**
- Title: `"Long Feeding Session ⏱"`
- Body: `"The feeding session has been going for 40 minutes. Everything ok?"`

---

## 3. Sleep Notifications

### 3.1 Wake Window Reminder (`bb.sleep.wake_window`)

Reminds the parent that the baby has been awake long enough and may need a nap soon.

**Trigger:** Every time a sleep entry ends (either `endTime` set on active entry, or manual entry saved with explicit end time).  
**Gate:** `hasLoggedFirstSleep == true`  
**Action:** Cancel previous `bb.sleep.wake_window`, schedule new one.

**Wake window by baby age:**

| Age | Wake window alert | Rationale |
|---|---|---|
| 0–6 weeks | 60 min | Very short awake stretches |
| 6 weeks–3 months | 1.5 h | Wake windows begin to lengthen |
| 3–6 months | 2 h | Two consistent nap periods forming |
| 6–8 months | 2.5 h | 2-nap schedule |
| 8–12 months | 3 h | Transitioning toward 1 nap |
| 12–18 months | 4 h | 1 nap per day |
| 18+ months | Disabled | Independent schedule; no automatic reminder |

**Notification copy:**
- Title: `"Nap Time 😴"`
- Body: `"Baby hasn't slept for X hours. Maybe it's time for a nap."`

---

### 3.2 Active Sleep Alert (`bb.sleep.active`)

Fires if a sleep timer has been running so long that the parent probably forgot to tap "Woke Up".

**Trigger:** When a `SleepEntry` is saved with `endTime == nil` (timer started).  
**Gate:** `hasLoggedFirstSleep == true`  
**Cancellation:** Cancelled immediately when the sleep timer is stopped.

**Alert interval by sleep type and age:**

| Sleep type | Age | Alert after | Rationale |
|---|---|---|---|
| Nap | 0–3 months | 2.5 h | Long nap; parent may have forgotten |
| Nap | 3–6 months | 2 h | Naps shorten with age |
| Nap | 6+ months | 2 h | Same threshold |
| Night | Any | 9 h | After 9 h the parent likely forgot to end session |

**Notification copy:**
- Title: `"Still sleeping?"`
- Body: `"Don't forget to tap 'Woke Up' when your baby wakes up."`

---

## 4. Diaper Notifications

### 4.1 Diaper Interval Reminder (`bb.diaper.reminder`)

Reminds the parent to log a diaper change if none have been recorded for a while.

**Trigger (activation):** First `FeedingEntry` or `SleepEntry` saved.  
**Gate:** `hasLoggedFirstFeedingOrSleep == true`  
**Reschedule:** Every time a `DiaperEntry` is saved — cancel previous, schedule new one.

**Interval by baby age:**

| Age | Interval | Rationale |
|---|---|---|
| 0–4 weeks | 4 h | Newborns should be changed every 2–3 h; 4 h is a soft limit |
| 1–6 months | 6 h | Frequency decreases naturally |
| 6–12 months | 8 h | Solids reduce frequency but reminder still useful |
| 12+ months | Disabled | Toddler schedule is parent-managed |

**Notification copy:**
- Title: `"Diaper check 🩲"`
- Body: `"No diaper logged in a while. Time to check on [Baby's name]?"`

---

## 5. Engagement Notifications

### 5.1 First Growth Measurement Prompt (`bb.engage.measurements`) — one-time

Nudges the parent to add the baby's first weight/height measurements.

**Trigger:** 3 days after `hasLoggedFirstFeeding` becomes `true` AND no `GrowthEntry` exists yet.  
**Fires:** Once only. Cancelled permanently once first `GrowthEntry` is saved.  
**Scheduling:** Scheduled at the moment the first feeding is saved, with a 3-day delay.

**Notification copy:**
- Title: `"Track [Name]'s growth 📏"`
- Body: `"You've been logging feedings for 3 days. Add weight and height to see WHO growth percentiles."`

---

### 5.2 Monthly Growth Reminder (`bb.engage.monthly_growth`) — recurring calendar

Reminds the parent to take monthly measurements.

**Trigger:** Fires on the 1st day of each month at 10:00, starting from the month after the first `GrowthEntry` is saved.  
**Gate:** `hasFirstGrowthEntry == true`  
**Scheduling:** Uses `UNCalendarNotificationTrigger` with `dateComponents: {day: 1, hour: 10}` and `repeats: true`.  
**Cancellation:** Only when the user disables notifications globally.

**Notification copy:**
- Title: `"Monthly check-up 📊"`
- Body: `"[Name] is X months old. Time to record new measurements and update the growth chart."`
  - Age is calculated at fire time — this requires the baby's birth date in the notification payload or a dynamic title.
  - **Implementation note:** Because `UNNotificationContent` is static, the body will say "Time to record new measurements" without the exact age. The age will be shown inside the app when the user opens it.

---

### 5.3 Weekly Summary (`bb.engage.weekly_summary`) — recurring calendar

A soft check-in every Sunday evening to keep parents engaged.

**Trigger:** Every Sunday at 20:00.  
**Gate:** At least one entry (any type) logged in the past 7 days. If the app has been completely idle for >7 days, this notification is not rescheduled until the app is opened again.  
**Scheduling:** `UNCalendarNotificationTrigger` with `dateComponents: {weekday: 1, hour: 20}` (weekday 1 = Sunday) and `repeats: true`.

**Notification copy:**
- Title: `"[Name]'s weekly recap 📋"`
- Body: `"See how feedings, sleep and diapers looked this week. Tap to review."`

---

### 5.4 App Idle Reminder (`bb.engage.idle`)

Fires if the parent has not opened the app or added any data for 2 days.

**Trigger:** Rescheduled every time the app enters the foreground: cancel previous `bb.engage.idle`, schedule new one 48 h from now.  
**Gate:** `hasLoggedFirstFeedingOrSleep == true` (only meaningful after initial onboarding).  
**Cancellation:** Cancelled and rescheduled every app launch.

**Notification copy:**
- Title: `"Everything ok with [Name]? 👀"`
- Body: `"You haven't logged anything in 2 days. Tap to catch up."`

---

## 6. Complete Notification ID Reference

| ID | Type | Repeating | Cancellation trigger |
|---|---|---|---|
| `bb.feeding.reminder` | Time interval | No | New feeding saved |
| `bb.feeding.active.bf` | Time interval | No | Feeding timer stopped |
| `bb.sleep.wake_window` | Time interval | No | New sleep started |
| `bb.sleep.active` | Time interval | No | Sleep timer stopped |
| `bb.diaper.reminder` | Time interval | No | New diaper saved |
| `bb.engage.measurements` | Time interval (3d) | No | First GrowthEntry saved |
| `bb.engage.monthly_growth` | Calendar (1st of month) | Yes | Never (persists) |
| `bb.engage.weekly_summary` | Calendar (Sunday 20:00) | Yes | Never (persists) |
| `bb.engage.idle` | Time interval (48h) | No | App foregrounded |

---

## 7. Event → Notification Matrix

| User action | Schedule | Cancel |
|---|---|---|
| First feeding saved | `bb.feeding.reminder` (age-based), `bb.engage.measurements` (3d), `bb.diaper.reminder` (age-based) | — |
| Any feeding saved (type = breast, isActive) | `bb.feeding.active.bf` (40 min) | `bb.feeding.reminder` (reschedule after) |
| Any feeding saved (manual or completed) | `bb.feeding.reminder` (age-based) | `bb.feeding.active.bf` |
| Feeding timer stopped | `bb.feeding.reminder` (age-based) | `bb.feeding.active.bf` |
| First sleep saved | `bb.sleep.wake_window` (age-based), `bb.diaper.reminder` (if not yet active) | — |
| Sleep timer started (isActive) | `bb.sleep.active` (type+age-based) | `bb.sleep.wake_window` |
| Sleep timer stopped | `bb.sleep.wake_window` (age-based) | `bb.sleep.active` |
| Manual sleep saved (has endTime) | `bb.sleep.wake_window` (age-based) | `bb.sleep.active` |
| Diaper saved | `bb.diaper.reminder` (age-based) | Previous `bb.diaper.reminder` |
| First GrowthEntry saved | `bb.engage.monthly_growth` (calendar) | `bb.engage.measurements` |
| App enters foreground | `bb.engage.idle` (48h) | Previous `bb.engage.idle` |
| Notifications permitted (onboarding) | `bb.engage.weekly_summary` (calendar) | — |

---

## 8. AppStorage Flags Required

| Key | Type | Purpose |
|---|---|---|
| `hasLoggedFirstFeeding` | Bool | Gate for feeding reminders |
| `hasLoggedFirstSleep` | Bool | Gate for sleep reminders |
| `hasLoggedFirstDiaper` | Bool | (Optional) gate for reschedule on diaper |
| `hasFirstGrowthEntry` | Bool | Gate for monthly growth reminder |
| `notificationsPermitted` | Bool | Set after `requestAuthorization` succeeds |

These flags live in the app's `@AppStorage`. They are checked inside `NotificationManager` before any `post()` call. They are set in the respective View's save functions (or in a shared `DataService` layer if one is introduced later).

---

## 9. What Is Already Implemented

The current `NotificationManager.swift` (v1) covers:

| Notification | Status | Gap |
|---|---|---|
| `bb.feeding.reminder` | ✅ Implemented | Fixed 3 h — not age-based yet |
| `bb.feeding.active.bf` | ✅ Implemented | Fixed 40 min — correct |
| `bb.sleep.reminder` (= wake window) | ✅ Implemented | Fixed 4 h — not age-based yet |
| `bb.sleep.active` | ✅ Implemented | Fixed 3 h/10 h — close but not fully age-based |
| `bb.diaper.reminder` | ❌ Missing | Not implemented |
| `bb.engage.measurements` | ❌ Missing | Not implemented |
| `bb.engage.monthly_growth` | ❌ Missing | Not implemented |
| `bb.engage.weekly_summary` | ❌ Missing | Not implemented |
| `bb.engage.idle` | ❌ Missing | Not implemented |
| Activation gates | ❌ Missing | No first-entry gates in place |
| Age-based intervals | ❌ Missing | All intervals are hardcoded |

---

## 10. Implementation Plan (Next Steps)

### Phase 1 — Age-aware core reminders
1. Add `babyAgeMonths: Int` parameter to `scheduleFeedingReminder()` and `scheduleSleepReminder()`.
2. Add helper `func feedingInterval(ageMonths: Int) -> TimeInterval` and `func wakeWindow(ageMonths: Int) -> TimeInterval`.
3. Update `FeedingView` and `SleepView` call sites to pass `baby?.ageInMonths ?? 0`.
4. Update `scheduleActiveSleepAlert` to also accept `ageMonths` for nap duration threshold.

### Phase 2 — Activation gates
1. Add `@AppStorage` flags to `NotificationManager` or inject them at call sites.
2. Guard all `post()` calls in feeding/sleep/diaper with their respective gate.
3. Set `hasLoggedFirstFeeding = true` inside `FeedingView.save()` / `AddFeedingSheet.save()`.
4. Set `hasLoggedFirstSleep = true` inside `SleepView` start/save paths.

### Phase 3 — Diaper reminder
1. Add `scheduleDiaperReminder(ageMonths: Int)` and `cancelDiaperReminder()` to `NotificationManager`.
2. Call `scheduleDiaperReminder` in `AddDiaperSheet.save()` and on first feeding/sleep logged.

### Phase 4 — Engagement notifications
1. `bb.engage.measurements`: schedule on first feeding save (3-day delay); cancel when first `GrowthEntry` saved.
2. `bb.engage.monthly_growth`: schedule with `UNCalendarNotificationTrigger` when first `GrowthEntry` saved.
3. `bb.engage.weekly_summary`: schedule once after notification permission granted during onboarding.
4. `bb.engage.idle`: reschedule every time `BabyBloomApp` body evaluates (scene phase `.active`).

### Phase 5 — Notification content localization
- Add missing localization keys to `en.json` / `ru.json` for new notification bodies (diaper, engagement).
- For monthly reminder: store baby birth date in notification `userInfo` and compute age in a `UNNotificationServiceExtension` if dynamic content is needed — or simply use a generic body.

# M3 — Medications with a dosing interval: list, detail, dose sheet, form, Events, Home, confirmation (design note)

status: final, 2026-11-03
decisions: the app counts time between doses and never prescribes, so no surface reads as advice, permission or a verdict; the calm rule (no red, no alarm shape, nothing that completes when the interval ends); WCAG 2.2 AA; the product rules and design decisions in § 13; DECISIONS.md 2026-09-05 (an empty state names the missing thing and offers the action; doctor-facing output carries measurements, not verdicts; a future-dated entry is refused at the picker and ignored at the read), 2026-09-22 and 2026-11-01 (no rating prompt over a worry; no analytics for health records), 2026-10-28 (a screen's primary action is pinned under its scroll)
reference: `teamdocs/design/design-system.md` (P = principle); the report note `m2-doctor-report.md` (report cards, PDF tables); the copy note `teamdocs/content/medications.md`
triggers: a medication surface, state or row added or removed; the status rule or the 24 h maximum changed; the confirmation's variants changed; the Home card's condition changed; a shared row (`BBEventRow`) restyled
check: `grep -n 'pills.fill' BabyBloom/App/MainTabView.swift` (the More row, § 1); `grep -c '"medication\.' BabyBloom/Resources/Localization/en.json` against the roles in § 12 once the copy lands; `grep -rn 'entrySaved' BabyBloom/Features/Medications` → nothing (§ 4)

Drawn by hand. Sizes are targets, checked on the first render.
Copy in the wireframes is **working text**; the final strings are in the localization files.
Words: en "medication(s)" and "Dose"; ru «лекарство», «доза» (never «приём», which is the pediatrician visit); es «medicamento», «dosis». The control is **Log Dose / Отметить дозу / Registrar dosis**. No screen says "allowed", "give", «можно» or «пора».

**Type metrics.** The app sets no line spacing, so every line height is the SF font's own: ascender + descender + leading = 1.177 × the point size, the same for SF Pro and SF Rounded (measured with CoreText). At Large: 12 → 14.1, 13 → 15.3, 15 → 17.7, 16 → 18.8, 17 → 20.0, 18 → 21.2, 21 → 24.7 pt. Tracking is 0 except where a named style sets it (title2 −0.2, caption +0.3). Every size below goes through `BBTheme.Typography.scaled(_:relativeTo:weight:design:)` and grows up to AX2; a row's height follows its text, so heights are minimums.

**Frame of every screen.** `ScrollView` on BBBackground; side gutter md 16; cards md 16 apart; sections lg 24 apart; iPad: one column, max 600 pt wide, leading. Secondary text (BBTextSecondary) sits **on a surface only**: 4.92:1 on BBSurface, 4.48:1 on BBBackground, which is under 4.5 (P8).

**Glyph and colour.** The medication glyph is `pills.fill`. The More row draws it in BBPrimary (5.62:1), as the other More rows draw tokens. Inside the feature it is decoration in a disc: BBAccent@0.22 fill, glyph BBAccent (1.84:1 light, 9.82:1 dark), `accessibilityHidden`. The name carries the meaning. Events' history rows keep the event type's own data colour (#F5D6A0), unchanged. No BBAlert anywhere in the feature; BBPrimary for actions only.

## 1. Entry

- **More row «Лекарства» / "Medications" / «Medicamentos»**, right after Events: the same `Label` row as Events and Recent activity, system body text in BBTextPrimary, icon `pills.fill` in BBPrimary. Identifier `more.medications`.
- **Home card** while a course runs (§ 7), and **one status line per active medication on Events** above Quick input (§ 6).
- The **Medication tile** on Events opens the dose sheet when a medication is active (§ 6).

## 2. Medications list

```
‹ More                 Medications           (+)
────────────────────────────────────────────────
Active
┌──────────────────────────────────────────────┐
│ ( ●)  Ibuprofen                       (bell) │
│       No doses logged yet                  › │
│       100 mg / 5 ml · every 8 h              │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ ( ●)  Paracetamol                            │
│       Next dose not before 08:10           › │
│       120 mg (5 ml) · every 6 h              │
└──────────────────────────────────────────────┘
Ended (1)                                     ⌄
┌──────────────────────────────────────────────┐
│ ( ●)  Amoxicillin                          › │
│       Ended 28 Oct · 14 doses                │
└──────────────────────────────────────────────┘
```

- Navigation title "Medications", large. Toolbar trailing: `plus.circle.fill` 22 pt BBPrimary, label "Add Medication" for VoiceOver; no padlock (medications are free).
- **Active**, sorted by name (locale-aware, case-insensitive). Why by name: an order by time or urgency would move rows each time a dose is logged and would rank which one to give first.
- **Ended (n)**, a disclosure header, collapsed by default, newest end date first. Hidden when no course has ended.
- Section headers: `BBSectionHeader`, title3 18 semibold default, line 21.2, BBTextPrimary.

### 2.1 Medication row (component spec)

| part | spec |
|---|---|
| box | whole row one `Button` (`BBScaleButtonStyle`) to the detail; BBSurface, radius md 16, `card` shadow, padding md 16 on all sides; rows sm 8 apart; min height 76 (disc 44 + 2 × 16) |
| layout | `HStack(alignment: .top, spacing: md 16)`: disc · text stack (fills) · trailing stack |
| disc | 44 × 44 circle, BBAccent@0.22; glyph `pills.fill` 18 pt medium BBAccent; hidden from VoiceOver |
| name | scaled(15, relativeTo: .body, semibold, rounded), line 17.7, BBTextPrimary, no line limit (wraps) |
| status | scaled(15, relativeTo: .body, regular, rounded), line 17.7, BBTextPrimary, wraps; 2 pt under the name. The same style in every state (§ 8) |
| meta | scaled(13, relativeTo: .footnote, regular, rounded), line 15.3, BBTextSecondary; 2 pt under the status. The dose text as typed, then «every N h» (the dose text left out when empty) |
| trailing | `VStack(spacing: 4)`, top-aligned: `bell.fill` scaled(13, .footnote) BBTextSecondary when this device's reminder is on; `chevron.right` 13 semibold BBTextSecondary@0.4, decorative |
| ended row | the same box; status line replaced by «Ended 28 Oct · 14 doses» in the meta style; no bell |
| VoiceOver | one element: «Paracetamol. Next dose not before 08:10. 120 mg (5 ml), every 6 hours. Reminder on.» (the bell's words are part of the label, so the glyph is never the only cue); hint «Opens the medication» |

### 2.2 Empty state (no medications)

```
┌──────────────────────────────────────────────┐
│                    ( ● )                     │
│             No medications yet               │
│   The interval comes from your pediatrician  │
│     or the medication's instructions.        │
│                                              │
│   [          Add Medication             ]    │
└──────────────────────────────────────────────┘
```

- `EmptyStateView` (72 pt disc, 32 pt glyph, title scaled 18 semibold rounded line 21.2, subtitle scaled 14 regular rounded line 16.5) **inside a `bbCard()`**, so its secondary subtitle sits on a surface, plus a `BBPrimaryButton` "Add Medication" lg 24 under it. It names the missing thing and offers the action (DECISIONS 2026-09-05).

## 3. Medication detail

```
‹ Medications                              Edit
 Paracetamol                                       title2, wraps
┌──────────────────────────────────────────────┐
│ Next dose not before 08:10                   │   line A
│ Last dose at 02:10 · 1 h 20 min ago          │   line B
│ Last 24 hours: 3 doses of the 4 you set      │   line C, only with a maximum
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ Dose                                         │
│ 120 mg (5 ml)                                │
│ Minimum time between doses                   │
│ 6 h                                          │
│ Most doses in 24 hours                       │   only when set
│ 4                                            │
│ Note                                         │   only when set
│ After food                                   │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ (bell) Notify when the interval has passed ● │
│ At 08:10                                     │
│ One notification after each dose, on this    │
│ device only, at night too.                   │
└──────────────────────────────────────────────┘
Doses
┌──────────────────────────────────────────────┐
│ 02:10  Today                               › │
│ 120 mg (5 ml)                                │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ 20:05  2 Nov                               › │
│ 120 mg (5 ml)                                │
└──────────────────────────────────────────────┘
 End course
────────────────────────────────────────────────
[                 + Log Dose                   ]
```

- **Navigation:** pushed from the list, the Home card or an Events status line. Title inline and empty; the name is the content's first line, title2 21 semibold default, tracking −0.2, line 24.7, BBTextPrimary on BBBackground (13.0:1), wraps, header trait for VoiceOver. Why not a large title: a large title cuts a long name («Ibuprofen suspension 100 mg/5 ml») to one line. Toolbar trailing "Edit" (BBPrimary, 17 regular) opens the form (§ 5) for this medication.
- **Status card** (`bbCard()`, padding 16, lines sm 8 apart):
  - line A: scaled(17, relativeTo: .body, medium, rounded) = bodyEmphasized, line 20.0, BBTextPrimary;
  - line B: scaled(16, relativeTo: .callout, regular, rounded) = callout, line 18.8, BBTextSecondary;
  - line C: callout as line B.
  - The words by state are in § 8; the styles never change with the state.
- **About card** (`bbCard()`, padding 16): label over value, always stacked, so AX2 needs no second layout. Label scaled(13, .footnote, regular, rounded) line 15.3 BBTextSecondary; value callout 16 line 18.8 BBTextPrimary, verbatim as typed; label-to-value 2 pt, pair-to-pair sm 8.
- **Reminder card** (`bbCard()`, padding 16), § 9.
- **Doses:** `BBSectionHeader` "Doses", then one elevated row per dose, newest first, sm 8 apart, inside `SwipeToDeleteRow` (76 pt delete action, deletes at once, as on Events).
  - Dose row box: BBSurface, radius md 16, `card` shadow, padding 16, min height 44 + 32; the whole row one `Button` → the dose sheet in edit mode (§ 4).
  - Time: scaled(15, .body, semibold, rounded) with monospaced digits, line 17.7, BBTextPrimary; the day word or date after it, glued, scaled(13, .footnote) BBTextSecondary; the dose text under it in the meta style, as typed when the dose was logged; chevron as § 2.1.
  - A free account's list shows the app's 15-day history window with `BBLockedHistoryFooter` under the last row, as every history list does. The rules read every dose whatever the window shows.
- **End course:** a text button in the scroll after the doses, BBPrimary scaled(15, .body, medium, rounded), min height 44, leading. No confirmation: ending deletes nothing. An ended medication shows **Resume course** in the same place.
- **Footer:** `VStack { ScrollView; footer }`. The footer holds `BBPrimaryButton("Log Dose", icon: "plus")`: min height 56, radius lg 24, 17 semibold rounded, white on the BBPrimary gradient. Padding horizontal md 16, top sm 8, bottom xs 4, on BBBackground (the Add Event sheet's footer values). An ended medication has no footer.

## 4. Dose sheet (new dose, edit a dose)

```
Cancel           Paracetamol                Save
┌──────────────────────────────────────────────┐
│ Medication                        Choose  ▾  │  only from the tile with 2+ active
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ Time                        Today  03:12   ▾ │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ 120 mg (5 ml)                                │  dose, prefilled, editable
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ Note                                         │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ Last dose at 21:05 · the 6 h interval has    │
│ passed                                       │
└──────────────────────────────────────────────┘
 Delete Dose                                      edit mode only
────────────────────────────────────────────────
[                  ✓ Save                      ]
```

- **Presentation:** plain `.sheet`, never `.entrySheet`, and no `entrySaved`: no rating prompt after a dose from any path. Detents `[.medium, .large]`, opening at `.large` so every field shows without a drag. Title `bbSheetTitle(name, movesIntoContentAtAX: true)`, so a long name wraps in the content at accessibility sizes.
- **Fields:** each its own field box: BBSurface, radius md 16, `card` shadow, padding md 16, lg 24 apart, as in the Add Event sheet.
  - **Medication** menu: shown only when the sheet opens from the Medication tile with two or more active medications. It shows "Choose", Save is off until one is chosen. With one active medication the sheet opens on it.
  - **Time:** compact `DatePicker` (date and time), BBPrimary tint, preset to now on open, range up to now: a future time cannot be picked.
  - **Dose:** a text field prefilled with the medication's dose text, editable; the edit stays on this dose only.
  - **Note:** a text field, vertical, up to 3 lines.
- **Status box:** a field box with the status lines A and B (§ 3 styles), computed without the dose being edited, so the parent sees the medication's state before this entry.
- **Footer:** `BBPrimaryButton("Save", icon: "checkmark")`, same footer box as § 3; the toolbar carries Cancel (BBTextSecondary) and Save (semibold BBPrimary), as the Add Event sheet. Save inside the interval or over the maximum shows the confirmation (§ 10); otherwise it saves and closes.
- **Edit mode:** opened from a dose row; title the medication's name; the time and dose text are those of the dose; **Delete Dose** is a text button in the scroll, `.destructive` role (the platform's red text), min height 44. It deletes at once and closes, as the swipe does. Why a button as well: a custom swipe is hard to reach for VoiceOver and Switch Control.
- **A disabled Save** (no medication chosen) draws the whole footer button at opacity 0.4 and the toolbar Save in BBTextSecondary. `BBPrimaryButton` has no disabled look of its own today.

## 5. Medication form (new, edit)

```
Cancel          New Medication              Save
┌──────────────────────────────────────────────┐
│ Bitty counts the time between doses from     │  safety line
│ the interval you enter. The dose and the     │
│ interval come from your pediatrician or the  │
│ medication's instructions; the app does not  │
│ check them.                                  │
│ ──────────────────────────────────────────── │
│ Name as on the package                       │  placeholder
│ ──────────────────────────────────────────── │
│ Minimum time between doses                   │
│ ( 4 h ) ( 6 h ) ( 8 h ) ( 12 h ) ( 24 h )    │
│ ( Other )                                    │  none selected
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ As on the prescription or package            │  dose
│ ──────────────────────────────────────────── │
│ Most doses in 24 hours (optional)            │  empty, number pad
│ ──────────────────────────────────────────── │
│ Note                                         │
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ (bell) Notify when the interval has passed ○ │
│ One notification after each dose, on this    │
│ device only, at night too.                   │
└──────────────────────────────────────────────┘
 Delete Medication                                edit mode only
────────────────────────────────────────────────
[                  ✓ Save                      ]   off until name + interval
```

- **Presentation:** plain `.sheet`, opening at `.large`; title "New Medication" / "Edit Medication" through `bbSheetTitle(…, movesIntoContentAtAX: true)`.
- **Group boxes:** BBSurface, radius md 16, `card` shadow, padding md 16, lg 24 apart; inside a group, rows are separated by a system `Divider` with sm 8 above and below.
- **Safety line:** the first row of the first group, above the name, so it is read before anything is typed. scaled(15, relativeTo: .body, regular, rounded), line 17.7, BBTextSecondary on the surface (4.92:1). It has no icon, no box of its own and no red: it is a statement, not a warning.
- **Name:** a text field, body 17 regular rounded, line 20.0. The placeholder names where the text comes from, never a drug name.
- **Interval chips:**
  - Label "Minimum time between doses": scaled(13, .footnote) line 15.3 BBTextSecondary, sm 8 above the chips.
  - Chips in a wrapping row (sm 8 between, sm 8 between lines): 4 h, 6 h, 8 h, 12 h, 24 h, Other. **None is selected** on a new medication, and Save stays off until one is chosen. Why: a preset beside a name reads as the app's advice at 3 a.m.
  - Chip box: capsule (radius pill), min height 44 (P7), padding horizontal 16, text scaled(15, .body, medium, rounded) line 17.7, number and unit glued.
  - Unselected: primary@0.10 fill, primary@0.30 1.5 pt stroke, BBPrimary text (4.93:1 light, 5.23:1 dark on the fill).
  - Selected: BBPrimary fill, BBOnPrimary text (5.62:1 light, 6.86:1 dark), no stroke. The fill change carries the state, and VoiceOver says "selected".
  - **Other** reveals two wheel pickers below the chips, hours 0–48 and minutes 0/15/30/45, `easeInOut(0.25)` (the optional-measure reveal; no animation under Reduce Motion). They start at 0 h 0 min.
  - **The interval's range is above 0 and up to 48 h.** 0 h 0 min is not an interval, so Save stays off on it; 48 h is the wheels' last value and the upper bound. The form's rule takes both bounds.
  - Editing a medication whose interval is one of the chips selects that chip; any other value opens Other with its value.
- **Dose:** a text field; the placeholder holds no number.
- **Most doses in 24 hours:** a text field with the number pad, empty by default, never prefilled; a whole number from 1; empty means not set. The label carries "(optional)"; the placeholder holds no number.
- **Note:** a text field, vertical, up to 3 lines.
- **Reminder group:** § 9.
- **Delete Medication** (edit mode only): a text button in the scroll, `.destructive` role, min height 44. It confirms with a system alert saying the doses stay in Events («Удалить» with the destructive role, as the delete-history confirmation does).
- **Footer:** as § 4. Save is off (opacity 0.4) until the name has a non-space character and the interval is in range.

## 6. Events: status lines, the Medication tile, the form, the history rows

```
Events                                      (+)
┌──────────────────────────────────────────────┐
│ ●  Paracetamol                             › │  status line, one per active medication
│    Next dose not before 08:10                │
└──────────────────────────────────────────────┘
Quick input
 [ Bath ] [ Walk ] [ Medication ] [ Mood ]        Medication: no padlock while a medication is active
History
 (●) Paracetamol            120 mg     02:10      a linked dose
 (●) Medication     Nurofen · 2.5 ml   2 Nov      an older dose with no medication
```

- **Status lines:** above Quick input, sorted by name, sm 8 apart, md 16 above Quick input's header.
  - Box: BBSurface, radius md 16, `card` shadow, padding horizontal 16, vertical 12, min height 44; the whole line one `Button` → the medication's detail.
  - Inside: glyph `pills.fill` scaled(15, .body) BBAccent, decorative; the name as § 2.1; the status line as § 2.1 under it; chevron as § 2.1.
  - Shown for active medications only; none → nothing, with no gap.
- **The Medication tile:** with at least one active medication it opens the dose sheet (§ 4), free, with no padlock. With none, it stays today's one-tap entry behind the Events gate, padlock included. Why: a one-tap dose with no name cannot be linked, so it would walk around the confirmation and the reminder.
- **The Events form, type Medication:** a field box at the top of the medication fields with a «Medication» menu: the active medications and "Not in the list".
  - One active medication → it is preselected.
  - Two or more → "Choose", and Save is off until a choice. Why: a wrong preselection would file a dose under the wrong medication and time the wrong interval.
  - With a medication chosen: no name or dose fields (the dose copies them; the dose text is editable on the dose afterwards), and the status box of § 4 under the menu.
  - "Not in the list" shows today's two free-text fields: no status, no confirmation.
  - With no active medication there is no menu, as today. The form's own gate stays.
- **History rows** (`BBEventRow`):
  - a linked dose: title = the medication's name; subtitle = the dose text, then the note, joined by « · »;
  - an older or free-text dose: title = the type word «Medication»; subtitle = «name · dose», then the note;
  - a medication event with neither: as today (the note, or nothing).
  - Text as typed: not translated, not reformatted, no no-break spaces added.
- **`BBEventRow` scales its second line.** The subtitle becomes scaled(13, relativeTo: .footnote, regular, rounded), line 15.3, and the time and trailing date scaled(13, .footnote, medium) and scaled(12, .caption1). Today the subtitle is fixed 13 pt, so at AX2 the name and dose stay small under a grown title. It is one change in the shared row, and it lifts Feeding, Sleep, Diapers and Recent activity the same way.

## 7. Home card

```
┌ running feed (as today) ─────────────────────┐
└──────────────────────────────────────────────┘
┌──────────────────────────────────────────────┐
│ ( ●)  Ibuprofen                            › │
│       Last dose at 23:40 · the 8 h interval  │
│       has passed                             │
│       Paracetamol                            │
│       Next dose not before 08:10             │
└──────────────────────────────────────────────┘
┌ last week (as today) ────────────────────────┐
```

- **When:** a medication is active and its last dose is under 24 h old. A medication with no dose yet does not show; a course nobody ends leaves Home a day after its last dose. The condition is read again each minute (`AppClock.now`).
- **Where:** in the Dashboard's xl 32 stack, after the running timers and before the weekly card.
- **Box:** `bbCard()` (BBSurface, radius md 16, `card` shadow, padding md 16), min height 76. Not the timer card's tonal fill and stroke: a timer says something is running, this card states a standing fact.
- **Layout:** `HStack(alignment: .top, spacing: 16)`: disc 44 as § 2.1 · the medications stacked, sm 8 apart, each name + status (§ 2.1 styles), sorted by name · chevron. No title: the names say what the card is.
- **Target:** the whole card is one `Button` (`BBScaleButtonStyle`, `contentShape`): one medication → its detail; two or more → the list.
- **VoiceOver:** one element, «Medications. Ibuprofen, last dose at 23:40, the 8 hour interval has passed. Paracetamol, next dose not before 08:10.», hint «Opens the medication» or «Opens Medications».
- **Motion:** none. The card appears and leaves with the layout's default, and nothing counts down.

## 8. Status words and the look rule

| state | line A (bodyEmphasized) | line B (callout, secondary) |
|---|---|---|
| no dose yet | No doses logged yet | Every 6 h |
| inside the interval | Next dose not before 08:10 | Last dose at 02:10 · 1 h 20 min ago |
| interval passed | Last dose at 02:10 · the 6 h interval has passed | 8 h 5 min ago |
| next dose tomorrow | Next dose not before tomorrow 01:30 | Last dose at 19:30 · 4 h ago |
| maximum reached first | Next dose not before 11:40 (the later of the two limits) | Last dose at 02:10 · … ; line C: Last 24 hours: 4 doses of the 4 you set |
| ended | — (no status) | Ended 28 Oct · 14 doses |

One-line placements (list row, Events line, Home card) show line A only.

- **The look never changes with the state.** No tick, ring, bar or countdown; no colour, weight or icon change at the boundary; no animation when line A's words change. Why: a visual that completes reads as an instruction to give, and the app only restates the parent's interval.
- **Times:** the last dose with its age, so nobody does the arithmetic; the next dose as an absolute clock time, which reads the same to both parents and on a screenshot. A time that is not today carries its day word or date. The clock follows the app's 12/24 h. Numbers and units are glued with no-break spaces: «6 ч», «завтра 01:30», «в 8:00».
- **The age** («1 h 20 min ago») updates once a minute with no transition.

## 9. Reminder switch (form and detail)

| state | switch | under it |
|---|---|---|
| off | off | the footer: One notification after each dose, on this device only, at night too. |
| on, a reminder pending | on | «At 08:10» (callout, secondary), then the footer |
| on, the interval passed | on | the footer only: nothing is pending |
| iOS notifications off | drawn off | «Notifications are off in iOS Settings», then «Open Settings ›» (BBPrimary 15 medium, min height 44, opens the app's notification settings), then the footer |
| not yet asked | off | the footer; turning it on asks iOS once, through the app's existing permission ask; a refusal returns it to the row above |

- **Row:** `Toggle` with `Label` (`bell.fill` BBPrimary), text callout 16 BBTextPrimary line 18.8, tint BBPrimary, min height 44. Under-lines scaled(13, .footnote) line 15.3 BBTextSecondary, xs 4 apart, inside the same surface box.
- **Per device:** the switch is this phone's alone, as the footer says; the partner's phone stays quiet unless it is turned on there.
- The same pattern as the Live Activity switch in Settings, which draws itself off with a hint line when iOS has it off.

## 10. The confirmation (system alert)

```
┌────────────────────────────────────┐
│ Less than 6 h since the last dose  │   title: a fact
│                                    │
│ Paracetamol: last dose at 08:00.   │   message: the name, both times
│ With your 6 h interval, the next   │
│ is not before 14:00.               │
│ ────────────────────────────────── │
│      Cancel       │      Save      │
└────────────────────────────────────┘
```

- **Component:** `.alert(title, isPresented:) { … } message: { … }`. The system draws it, scales it at AX2 (it grows, scrolls and stacks the buttons) and speaks it to VoiceOver. Nothing in it is coloured.
- **Buttons:** Cancel with `.cancel` (iOS draws it bold: the side that keeps things as they were) returns to the sheet with every field kept. Save has **no role**: it is not destructive and never red; it keeps the dose and closes the sheet.
- **Variants** (working text; the copy note holds the words):
  - **before:** a dose under the interval after the last one, as drawn;
  - **after:** a dose put before a dose already logged, less than the interval earlier: «Less than 6 h from a logged dose» / «Paracetamol: a dose is logged at 16:00. Your interval is 6 h.»;
  - **24 h:** the dose would take the count over the maximum: «With this one, 5 doses in 24 hours» / «Paracetamol: the most you set is 4 in 24 hours.»
- **One alert per save.** When a dose breaks both limits, the alert shows the variant of the limit that ends later, the one that sets "next dose not before" on the detail; when both end at the same time, the interval variant. Why: the alert's time is the detail's time, and the interval variant cannot explain a time the maximum set (last dose 14:00, interval 6 h, yet not before 22:30).
- **Shown** on Save from the dose sheet (new and edited doses) and from the Events form with a medication chosen. **Not shown** for a dose on time (exactly the interval counts as on time), for another medication, or for a free-text event.
- Times inside follow § 8 (day word, glued, the app's clock). The name comes first, before a colon, so the ru sentence needs no case ending on typed text.

## 11. States

| state | list | detail | Events | Home |
|---|---|---|---|---|
| no medications | the empty state of § 2.2 | — | no status lines; the tile as today | no card |
| a medication, no dose yet | «No doses logged yet» | status «No doses logged yet / Every 6 h»; the footer; no confirmation on the first dose | its line | no card |
| inside the interval | «Next dose not before 08:10» | as § 3 | its line | card |
| interval passed | «Last dose at 02:10 · the 6 h interval has passed» | same look | its line | card until 24 h after the dose |
| next dose tomorrow | «… not before tomorrow 01:30» | same | its line | card |
| maximum set | — | line C | — | — |
| course ended | under Ended: «Ended 28 Oct · 14 doses» | doses kept, edit and delete still there; no status, no footer, no reminder card; Resume course | no line; the history rows stay | gone |
| reminder on / off / iOS off / not asked | the bell when on | § 9 | — | — |
| older medication event, no medication | — | — | history row «Medication» + «name · dose»; no status, no confirmation | — |
| two medications | a row each | the confirmation looks at its own medication only | a line each | one card, a block each |
| a dose from another phone | the same rows once it syncs | the same; no device mark | the same | the same |
| doses older than 15 days, free account | — | the dose list ends with the history footer, as every list | the history window as today | — |
| a future time | — | the time picker stops at now | — | — |
| AX2 | rows grow; name, status and meta wrap; a time never splits from its day word | the about card is already stacked; chips wrap to more lines; the footer button grows | lines wrap | lines wrap, nothing is cut |
| iPad 13" | one column, max 600 pt, leading; sheets as form sheets | same | same | the card spans the Dashboard column |
| light / dark | tokens only; BBAccent glyph 1.84:1 light / 9.82:1 dark, decoration | same | same | same |

## 12. What the copy and the build need

Copy roles (keys under `medication.*` and `notification.medication_*`):
- More row title and VoiceOver hint; list title; «Active», «Ended (n)»; «Add Medication» (toolbar label, empty-state action).
- Empty state: title and the one sentence on where the interval comes from.
- Row and status lines: No doses logged yet; Every N h; Next dose not before (today / tomorrow / a date); Last dose at · the N h interval has passed; the age («… ago»); Ended on a date · N doses (plural); Last 24 hours: n doses of the m you set (plural).
- Detail: Edit; Dose; Minimum time between doses; Most doses in 24 hours; Note; Doses; Log Dose; End course; Resume course.
- Dose sheet: Medication; Choose; Time; the placeholders; Delete Dose.
- Form: New Medication; Edit Medication; the safety line; the name and dose placeholders (no number, no drug name); the interval label and the six chips; «(optional)»; Delete Medication and its confirmation (the doses stay).
- Reminder: the switch label; «At HH:MM»; the footer; «Notifications are off in iOS Settings»; «Open Settings»; the notification title (the name) and body (elapsed time since the named dose), no emoji.
- Confirmation: three titles and three messages.
- Events: the menu label «Medication» and «Not in the list».
- VoiceOver: the row, line and card sentences of §§ 2.1, 6, 7, with «reminder on».
- Report: the card title, the row formats, the PDF heads (§ 14).

Build facts:
- A medication's name and dose are stored on the event and, before this feature, read by no screen and no file: the Events row showed the note (`EventsView.swift`, history rows), and the events CSV wrote type and note only (`ExportGenerator.eventsCSV`). § 6 rows and the CSV's two new columns fix both. Stored data is not rewritten.
- The Medication tile used to insert a nameless dose in one tap (`EventsView.quickAdd`); § 6 changes it while a medication is active. The tile still enters through the screen's one creation path (`EventsView.addEvent(_:)`) and branches there: dose sheet, free, no padlock while a medication is active.
- No screen edited an event before this feature. The dose edit of § 4 is the first edit path and stays limited to doses.
- `AddEventSheet` is presented with `.entrySheet` from Events and from the Dashboard, and both of its saves call `entrySaved`. A medication save takes neither path (§ 4).
- `BBEventRow`'s subtitle and time were fixed sizes (13 and 12 pt, not scaled); § 6 scales them.
- `BBPrimaryButton` has no disabled look: a disabled Save draws at opacity 0.4, with the toolbar Save in BBTextSecondary (§ 4).
- The app asks for notification permission in onboarding only. A parent who declined there reaches the reminder switch with permission not yet asked or denied: § 9 covers both. There is no app-wide notifications switch in Settings; each medication's own switch is its off.

## 13. Decisions (2026-11-03)

### 13.1 Product rules
1. **Medications have their own More row after Events.** Events keeps the doses in its history and one status line per active medication above Quick input. Why: findable by name, room for ended courses and the reminder; the row can grow into a Health area without moving a feature people have learned.
2. **A Home card while a course runs:** an active medication whose last dose is under 24 h old. Why: at 3 a.m. the parent opens the app on Home, and the answer must be there, not two or three taps under More.
3. **Medications are free:** every medication surface, logging, editing and deleting doses, the confirmation, the reminder, the status lines. The Events form keeps its own gate, and lists keep the free 15-day history window while the rules read every dose. Why: the night moment is the core of the app's value and reminders stay free; a paywall in front of a feverish baby's dose count is the moment the rating prompt is already kept away from.
4. **Words:** "Log Dose" with the time preset to now; inside the interval "Next dose not before HH:MM"; after it "Last dose at HH:MM · the N h interval has passed"; never "allowed", "give", «можно», «пора»; ru «доза», never «приём». Why: the app restates the parent's interval and never grants permission; «приём» is the pediatrician visit on the same screens.
5. **No defaults that look like advice:** no placeholder with a number or a drug name, no preselected interval or maximum, Save off until the name and the interval are set. Why: at 3 a.m. a sample value reads as a suggestion and a preset as a prescription.
6. **The confirmation informs and never blocks:** a system alert with a fact title, the name and both times; Cancel and Save, Save always possible; three variants (before, after, 24 h). Why: the parent's doctor may have said otherwise.
7. **The 24 h maximum is optional and empty by default.** When set, "next dose not before" is the later of the interval's end and the time the 24 h count falls under the maximum. Why: the interval alone does not cap a day (six on-time doses fit in 24 h at 4 h), and the instructions give both numbers.
8. **No rating prompt after any medication dose, from any path.** Why: a dose is given to a sick baby (DECISIONS 2026-11-01's reason for the pediatrician sheets).
9. **Medication rows show the name and dose as typed; the events CSV gains name and dose columns; stored data is untouched.** Why: they were stored and shown nowhere, which hid the parent's own words.
10. **The Medication tile opens the dose sheet while a medication is active; one tap as before when none is.** Why: a nameless dose cannot be linked, so it would skip the confirmation and the reminder.
11. **Doses are edited (time, dose text) and deleted from the medication's dose list;** other event types stay without an edit path. Why: the rules and the reminder follow an edited dose.
12. **An ended course can be resumed as the same medication.** Why: one name, one dose list and one report row instead of duplicates.
13. **The reminder is per device, off by default, and fires at night:** title the name, body the time since the named dose; no emoji, no badge, the default sound, the plain interruption level. Why: a local notification is a fact of one phone, and a synced switch would ring the partner's phone unasked; the body stays true on a phone that has not synced yet; the parent asked for the night notification.
14. **The report lists medications given in the period with their doses and dates, and nothing else** (§ 14). Why: the doctor sees everything given; an interval or an early-dose mark would be a verdict on the parent.
15. **Medications send no analytics.** Why: the day a baby was given medicine is health information, as the day of a visit.

### 13.2 Design decisions
1. **Status styles never change with the state** (§ 8). Why: a completing visual reads as an instruction to give.
2. **Sorted by name** on the list, the Events lines and the Home card. Why: an order by time or urgency moves rows on every dose and ranks which medication to give first.
3. **BBAccent for the medication glyph on the new surfaces, BBPrimary on the More row;** the event type's data colour stays on Events' history rows. Why: tokens only on new surfaces; BBAccent is the warm token nearest the existing medication colour; a More icon at 1.84:1 would nearly vanish, so the row uses BBPrimary as its neighbours do.
4. **The name is the detail's first content line, not a large title.** Why: a large title cuts a long name to one line.
5. **One active medication is preselected in the Events form and the tile's sheet; with two or more the parent chooses, and Save waits.** Why: a wrong preselection files the dose under the wrong interval.
6. **The empty state sits in a card.** Why: its subtitle is secondary text, which is under 4.5:1 on the background.
7. **Delete Dose is also a button in the dose sheet.** Why: the custom swipe is hard to reach with VoiceOver and Switch Control.
8. **When a dose breaks both limits, the alert shows the limit that ends later; a tie shows the interval variant.** Why: the alert's time is the detail's "next dose not before".
9. **`BBEventRow` scales its subtitle and time.** Why: the subtitle now carries the name and dose, and every list using the row gains the same AX2 behaviour.
10. **The dose list keeps the app's history window with its usual footer.** Why: the window is the app's rule for every history list; the rules read every dose, so nothing about the next time depends on it.
11. **The interval is above 0 and at most 48 h.** Why: 0 is not an interval, and 48 h is the end of the Other wheels.

## 14. Report section (the pediatrician report)

- **Screen:** a card after Diapers, before the footnote, in the report's card pattern: `ReportCardHeader(icon: "pills.fill", tint: BBAccent, title: "Medications")` and one block per medication:
  - `ReportRow`: the name as the label (verbatim) and the dose count as the value («8 doses»), the first–last dates as its caption suffix («2–5 Nov»);
  - `ReportCaption` under it: the dose text as written, when there is one.
  - Blocks sorted by name.
  - Older events without a medication are grouped by their typed name (trimmed, case-insensitive) beside the linked ones; events with no name form one block «Without a name».
  - The card is hidden under the new-period card, as feeding, sleep and diapers are, and absent when no dose falls in the period. No "none" line: an absence of medicine is not a missing record.
- **PDF:** one section after Diapers. h2 «Medications» as the other sections, then a table with four fixed columns: Medication 34 % | Dose as written 30 % | Doses 12 % | First – last 24 %. Body 10 pt minimum, rows whole, the head repeated on each page the table reaches (the weighings table's pattern), Helvetica Neue. Names and dose text verbatim except emoji, as the questions.
- **Not printed:** the interval, the maximum, any mark on a dose given inside the interval.

# Localization — how the 12 new languages are written and checked

The translator's brief for uk, de, fr, ja, ko, zh-Hant, pt-BR, pt-PT, sv, nb, da and fi. en is the source. ru
and es are already live and written to the same canon. The 12 languages ship together, so a language counts
as done only when every key is translated and has passed every check below.

The translations are written by the team's own process, with no outside native speakers. This brief puts
checks where a native read would normally go: the glossary, the automatic checks, back-translation, and a
second reviewer for the languages furthest from the team's own.

## 1. Inputs

Read these before the first batch, in this order:

| File | What it gives |
|---|---|
| `BabyBloom/Resources/Localization/en.json` | The source. Translate from en only, never from ru or es. |
| `glossary.md` | The one word per language for each term, from Apple, WHO and medicine leaflets. Units, numbers, punctuation, and the zh-Hant lists. |
| `tone.md` | The form of address, how to name the baby, the «Нічка» case forms, the forbidden words in medication strings, the two stool registers, the demo names. |
| `voice.md` | The voice of en, ru and es. The new languages follow it: warm, plain, never judging the parent. |
| `medications.md` | The rules for medication strings. They bind every language word for word in meaning. |
| `doctor-report.md` | The closed word list of the doctor report: measurements only, no verdicts. |
| `weekly-and-notifications.md`, `paywall-and-settings.md` | The rules for those screens. |

A rule in these files beats this brief. A rule that does not seem to fit a language is raised as a
question before anyone writes around it.

## 2. The keys and the batches

en.json has about 700 keys. They are translated in batches of 60–80 keys, and each batch comes from one
group. The groups run in the order below in every language, so the strings with the highest risk get the
most careful pass:

| # | Group | Key prefixes | Risk |
|---|---|---|---|
| 1 | Medication safety | `medication.*`, `notification.medication_*`, `export.csv.medication`, `export.csv.dose` | **(S)** A wrong word can change a dose, an interval or a maximum. |
| 2 | Health and growth | `percentile.*`, `velocity.*`, `trend.*`, `nutrition.*`, `newborn.*`, `breakdown.*`, `growth.*`, `chart.*`, `diaper.*` warnings, `source.*` | **(S)** WHO terms, reference ranges, "see a doctor" lines. |
| 3 | System surfaces | `notification.*`, InfoPlist (the app name and the permission texts), `live_activity.*`, `widget.*` | Short fixed spaces; the parent reads them outside the app. |
| 4 | Core logging | `tab.*`, `button.*`, `form.*`, `feeding.*`, `sleep.*`, `event.*`, `stat.*`, `filter.*`, `history.*`, `empty.*`, `confirm.*` and the rest of the screens | Daily words; length limits. |
| 5 | Onboarding and Premium | `onboarding.*`, `premium.*`, `settings.*` | Persuasion that must stay honest; prices are never in the text. |
| 6 | Doctor report and export | `report.*`, `export.*`, `visit.*`, `question.*` | A clinician reads it; measurements only. |
| 7 | Long help | `*.info_body`, explainers, facts | Long text; tone carries most. |

Plural families (`<key>.one`, `.few`, `.many`, `.other`) are translated as a whole family in one batch. Each
language fills the categories its CLDR rule names, and `.other` is always required, because the app falls back
to it. Every family value is a whole phrase with the number inside, with a no-break space (U+00A0) between the
number and the word. In ja, ko and zh-Hant the number sits directly against its counter, with no space.

## 3. One batch, step by step

1. **Draft.** The draft is written from en plus the glossary rows and tone rules the batch touches. These go
   with the batch, so the drafter never guesses a term. A draft may be produced by a drafting assistant.
2. **Review.** The reviewer reads every line against en for meaning, against the glossary for terms, and
   against tone.md for address and voice. Each line is read as the parent would meet it, on its screen, at
   that moment. The reviewer rewrites what reads like a translation. Speed is never a reason to keep it.
3. **Automatic checks** (§ 4). A FAIL is fixed before anything else happens. Each warning is read and either
   fixed or marked as accepted, with the reason, in the batch note.
4. **Back-translation** of every **(S)** string (groups 1–2, plus any notification that names a medication or
   a measurement). A fresh reader who has not seen en translates the new language back into English. The
   back-translation is compared with en line by line, and every difference in meaning is fixed and checked again.
   "Not before 14:00" coming back as "at 14:00" is a difference in meaning. A change of word order is not.
5. **Second check** for uk, ja, ko, fi and zh-Hant (§ 5).
6. **Fit** (§ 6), then the batch is written into the language file. A batch is complete when its keys pass the
   checks in the language file itself, not in a draft.

## 4. The automatic checks

Two scripts are kept with the team's localization tooling, outside the app's targets. They are run from the repository root:

    python3 -I loc_lint.py [--langs uk,de] [--dir <folder>] [--quiet]
    swift fit.swift [--langs uk,de] [--dir <folder>] [--all]

`loc_lint.py` checks every language file next to en.json except en, ru and es, which have their own tests:

| Check | FAIL | Warning |
|---|---|---|
| Parity | A key is missing or not in en; a value is empty; a plural family has no `.other` | A value is identical to en |
| Placeholders | The arguments (position and type) differ from en | The same, in a plural form (compared with en's `.other`) |
| Digits | The digits in the prose differ from en. sv/nb/da «dygn/døgn» and fi «vuorokausi» may stand for "24 hours". | The same, in a plural form |
| Forbidden words | A word from tone.md § 4, a «!» or «！», or a plain space after a number, in a medication string | — |
| Brand | uk without «Нічка»; any other language with «Нічка», «Ночка» or «Nenita»; a possessive on «Bitty»; fi «Bitty» not followed by «-appi» or « Premium»; «Bitty» written in kana, hangul or Han; a wrong InfoPlist display name | — |
| Punctuation | ASCII «"»; fr without U+00A0 before «: ; ? !» or inside « »; the wrong space before %; in zh-Hant, a space next to a Han character; in ja/zh-Hant, half-width punctuation after a CJK character; full-width punctuation in ko; an uk apostrophe other than ʼ | Quotes that are not the language's own; in ja, a space next to a CJK character; outside medication strings, a plain space after a number |
| zh-Hant | A Simplified character, one outside Big5, or one from glossary.md § 11.1; a mainland term; 周 for "week" | A term Taiwan writes differently (glossary.md § 11.2) |
| Glossary | A **(S)** term from glossary.md § 3–8 is not used where en uses it | The same, for the other terms |
| Length | Over the character limits: Stop buttons 12, Live Activity title 26, its timers 30, its footer 32, the widget's Feeding tab 12, Start feeding 18, notification titles 36 | Notification titles over 30 |
| Widget copy | The widget's copy of the file is missing or differs | — |

`fit.swift` measures the short containers with CoreText at the app's fonts:

| Keys | Font | Budget |
|---|---|---|
| `tab.*` | 10 pt medium | ru «Подгузники», the widest label that ships today |
| `filter.day/week/month/year` | 13 pt semibold rounded | 70 pt |
| `settings.appearance.*` | 13 pt medium | 90 pt, one segment |
| `premium.plan.best_value`, `premium.save_fmt` (at 40 %) | 11 pt bold rounded | en «Best Value» + 30 %, or ru's shipping badge if wider |

The checks catch the mechanical errors. They do not catch a wrong meaning, which is what review and
back-translation are for. A term the glossary check misses (an inflected form, a compound) is caught by the
reviewer and added to the glossary in the same batch.

## 5. The second-check group: uk, ja, ko, fi, zh-Hant

These five languages get a second reviewer and two independent back-translations for the (S) strings. The
reasons: uk sits so close to ru that Russian habits slip in unseen. ja and ko change register and counters in
ways a first pass misses. fi builds words a stem match cannot check. zh-Hant has a mainland twin for almost
every term. Each language also has its own sweep:

**uk.** Sweep for Russian calques, among them «приймати ліки» (the line names the dose, «доза», as medications.md does; «дати» is
forbidden by tone.md § 4), слідкувати → стежити,
на протязі → протягом, являється → є, получати → отримувати, співпадати → збігатися, міроприємство,
більш ніж → понад, о 5 годині → о 5-й. Check every «Нічка» against the case table in tone.md § 3: every
preposition takes its case, and the vocative is «Нічко». Check the apostrophe ʼ and the address ви
(capitalised Ви never).

**ja.** Check the counters (回, 本, 時間, 分, 日, 週, か月), the particles after a number (に / で / から / まで), and
です・ます everywhere except buttons and labels, which are nouns or the dictionary form. Check for no space
between kana or kanji and digits, and full-width 「」、。 marks.

**ko.** Check 해요체 in every sentence, the counters (회, 번, 시간, 분, 일, 주, 개월), the particle pairs after a
number or a name (이/가, 은/는, 을/를; a name in a template takes the form that fits both, or the sentence is
rebuilt so no particle follows it), half-width punctuation, and a space between words as in Apple's strings.

**fi.** Check «Bitty-appi» and its cases (Bitty-appissa, Bitty-appiin, Bitty-appin) as glossary.md § 2 lists
them. After a number above 1 the noun is in the partitive (2 annosta, 3 tuntia). A template with the number
outside the phrase is rebuilt so the case can agree. Check sinä throughout.

**zh-Hant.** Check the Simplified and mainland lists in glossary.md § 11. Use Taiwan's words for software
things (檔案, 設定, 帳號, 訊息), 你 throughout, full-width punctuation 「」，。、：, no space around Latin or digits,
and 週 for week.

## 6. Fit on screen

After `fit.swift`, each language is captured at 320 pt width and at the largest accessibility text size
(AX2) on these screens: Home, the four logging sheets, the medication list and its alert, Growth with a
percentile, the paywall, Settings, one notification, the Live Activity and the widget. A string that clips,
truncates or breaks a word badly is shortened in that language, never with a smaller font. Where no shorter
wording keeps the meaning, it is raised as a layout question.

The design budgets for long strings replace the audit's numbers in § 4 when they land. Until then, the
budgets above hold.

## 7. Rules that hold in every batch

- Translate meaning, not words. One message = one point, as in en.
- Never translate an id, a key or a placeholder. Never reorder `%1$@` and `%2$d` away from their positions. Use
  positional arguments where a language needs another order.
- Numbers, units and dates are formatted by the app. The text never writes a date or a decimal itself.
- No gender for the baby except where the language has no neutral form. The baby's name appears only where
  the language can leave it in the nominative.
- A medication or health string never adds advice that en does not give, and never drops a condition that en
  states.
- A term that is not in the glossary is added to it, with its source, before it is used twice.

## 8. What is done

A language is done when:
- `loc_lint.py` and `fit.swift` pass with no FAIL;
- every warning is fixed or accepted with a reason;
- every (S) string has its back-translation, compared with en;
- the second-check group has its second reviewer and two back-translations;
- the 320 pt and AX2 captures are clean;
- the widget copy and the InfoPlist file match.

After all 12 languages are done, one pass across the 15 files checks that a term, the brand and the plural
rules read the same in all of them.

# Tone sheet — the 12 new languages

How the warm voice of voice.md sounds in uk, de, fr, ja, ko, zh-Hant, pt-BR, pt-PT, sv, nb, da and fi. voice.md
stays the canon (a calm adult next to a tired parent; facts, not verdicts). This sheet adds what each language
has to decide on its own. The terms themselves are in glossary.md.

## 1. Address

One form per language, in every string: screens, notifications, the widget, the paywall, errors. The doctor report
addresses no one.

| language | form | a button / instruction | a sentence to the parent |
|---|---|---|---|
| uk | **ви** (lower case) | infinitive on buttons, as Apple: «Зберегти», «Додати годування» | «Ви можете змінити це в Параметрах» → better without the pronoun: «Це можна змінити в Параметрах» |
| de | **du** (lower case) | infinitive: «Sichern», «Mahlzeit hinzufügen» | «Du findest das in den Einstellungen» |
| fr | **vous** | infinitive: «Enregistrer», «Ajouter un repas» | «Vous pouvez modifier cela dans Réglages» |
| ja | **です・ます** | noun or stem, never a sentence: 「保存」「授乳を追加」 | 「設定で変更できます」; no あなた |
| ko | **해요체** | noun: 「저장」「수유 추가」 | 「설정에서 변경할 수 있어요」; no 당신 |
| zh-Hant | **你** | verb + object: 「儲存」「加入餵奶」 | 可在「設定」中更改 (the pronoun 你 only where the sentence needs a subject) |
| pt-BR | **você** | infinitive: «Salvar», «Adicionar mamada» | «Você pode mudar isso em Ajustes» |
| pt-PT | **tu** (with the verb in the 2nd person) | infinitive: «Guardar», «Adicionar mamada» | «Podes alterar isto em Definições» |
| sv | **du** | infinitive: «Spara», «Lägg till matning» | «Du kan ändra det i Inställningar» |
| nb | **du** | infinitive: «Arkiver», «Legg til mating» | «Du kan endre dette i Innstillinger» |
| da | **du** | infinitive: «Gem», «Tilføj madning» | «Du kan ændre det i Indstillinger» |
| fi | **sinä**, mostly through the verb ending | the 2nd-person imperative, as Apple: «Tallenna», «Lisää syöttö» | «Voit muuttaa tämän Asetuksissa» |

- **Drop the pronoun where the language lets you.** uk, ja, ko, zh-Hant, pt-PT and fi read warmer without it.
  ja and ko never write あなた or 당신: both sound distant or rude to a reader.
- **pt-PT tu is not pt-BR você.** pt-PT writes «Podes», «Tens», «o teu bebé»; «você» never appears in pt-PT.
- **de du, sv/nb/da du** are written in lower case, also at the start of a clause after a colon.
- **Medication lines address no one** in any language (medications.md): they state the logged time and the
  interval. "You can" is a forbidden phrase there (§ 4).

## 2. The baby

The app knows the baby's name and, from the profile, a sex; the copy never depends on the sex.

- **The name in a nominative slot only.** `%@` stands where the language needs no case ending:
  - uk: «Злата: 3 годування» rather than «у Злати», since a name declines in Ukrainian.
  - fi: «Aino · 3 syöttöä», never «Ainon» or «Ainolle».
  - de, fr and pt: no article before the name.
  - ja and ko: the name takes a particle that has no vowel harmony or gender. ja 「の」; ko 「의」 or a
    label shape such as 「서아 · 수유 3회」, because 이/가 and 은/는 depend on the last letter of the name.
- **No gendered words for the baby.** Use "the baby" or the name:
  - uk «малюк» / «дитина»;
  - de «das Baby»;
  - fr «bébé», with no article where it can go;
  - pt-BR «o bebê», pt-PT «o bebé» (the masculine article is the noun's grammatical gender, not the child's);
  - sv «bebisen», nb «babyen», da «babyen», fi «vauva»;
  - ja 赤ちゃん, ko 아기, zh-Hant 寶寶.
  - Never a pronoun that carries a sex (er / sie, il / elle, ele / ela, han / hon, він / вона).
- **The one gendered form is uk «Прокинувся»** on the sleep stop button (glossary § 5). Every other uk past tense
  that needs the baby as its subject is rewritten without the verb: «Сон: 1 год 20 хв».

## 3. «Нічка» (uk)

«Нічка» declines like ru «Ночка». Use the form that matches the slot; a template never glues a case ending to `%@`.

| case | form | example |
|---|---|---|
| nominative | Нічка | «Нічка нагадає про годування» |
| genitive | Нічки | «Ласкаво просимо до Нічки» · «з Нічки» · «налаштування Нічки» |
| dative | Нічці | «Нічці потрібен доступ до сповіщень» |
| accusative | Нічку | «Оцініть Нічку» · «Видалити Нічку» |
| instrumental | Нічкою | «Користуйтеся Нічкою без обмежень» |
| locative | у / в Нічці | «у Нічці» after a consonant, «в Нічці» after a vowel: «дані в Нічці», «записано у Нічці» |
| vocative | Нічко | not used: the app does not address itself |

- The Home Screen name (InfoPlist) is «Нічка»; «Нічка Premium» keeps «Premium» in Latin.
- The stress is on the first syllable, as in ru «Ночка»; VoiceOver reads it right with no hint.
- All other languages keep «Bitty», which never declines (glossary § 2).

## 4. Forbidden words in medication strings **(S)**

medications.md is the law: medication copy states what was logged and the interval, and never tells the parent
to give a dose, that a dose is allowed, safe or due. These words fail the check in `medication.*`,
`notification.medication_*`, `export.csv.medication` and `export.csv.dose`. The en, ru and es lists are the ones
in MedicationCopyTests.

| language | forbidden (regular expression, case-insensitive) |
|---|---|
| uk | `да(?:й\|йте\|ти\|вати\|ли)\|можна\|не можна\|пора\|час (?:дати\|для)\|дозвол\w*\|рекоменд\w*\|слід\|варто\|повин\w*\|безпечн\w*\|небезпечн\w*\|рано\|передозув\w*\|попередж\w*\|увага\|норм\w*` |
| de | `gib\|geben\|gegeben\|verabreich\w*\|darfst\|dürfen\|darf\|erlaubt\|solltest\|sollte\|musst\|muss\|sicher\|unsicher\|empfehl\w*\|empfohlen\|zu früh\|überdos\w*\|warnung\|gefahr\w*\|gefährlich\|zeit für\|kannst\|normal\|norm` |
| fr | `donne\w*\|administr\w*\|pouvez\|peut\|autorisé\w*\|devez\|doit\|devrait\|sûr\|sans danger\|dangereu\w*\|recommand\w*\|conseill\w*\|trop tôt\|surdos\w*\|avertissement\|attention\|il est temps\|c’est l’heure\|normal\w*\|norme` |
| ja | `あげ\|与え\|飲ませ\|てもいい\|てもよい\|ても大丈夫\|できます\|べき\|安全\|危険\|推奨\|おすすめ\|早すぎ\|過剰\|警告\|注意\|時間です\|の時間\|正常\|標準` |
| ko | `주세요\|먹이\|먹여\|투여하세요\|해도 돼요\|해도 됩니다\|가능\|할 수 있어요\|해야\|안전\|위험\|권장\|추천\|너무 이르\|과다\|경고\|주의\|시간이에요\|시간입니다\|정상\|기준치` |
| zh-Hant | `給藥\|餵藥\|可以\|允許\|應該\|必須\|安全\|危險\|建議\|推薦\|太早\|過量\|警告\|注意\|時間到\|該吃\|正常\|標準` |
| pt-BR | `dê\|dar\|dado\|administr\w*\|pode\|permitid\w*\|deve\|deveria\|segur[oa]s?\|perig\w*\|recomend\w*\|cedo\|demais\|superdosagem\|overdose\|aviso\|atenção\|hora de\|normal` |
| pt-PT | `dá\|dar\|dado\|administr\w*\|pode\|podes\|permitid\w*\|deve\|deves\|deveria\|segur[oa]s?\|perig\w*\|recomend\w*\|cedo\|demasiado\|sobredosagem\|aviso\|atenção\|hora de\|normal` |
| sv | `ge\|ger\|gav\|givit\|tillåt\w*\|får\|bör\|måste\|säker\w*\|farlig\w*\|rekommend\w*\|för tidigt\|överdos\w*\|varning\|dags att\|dags för\|du kan\|normal\w*` |
| nb | `gi\|gir\|ga\|gitt\|tillat\w*\|får\|bør\|må\|trygg\w*\|farlig\w*\|anbefal\w*\|for tidlig\|overdos\w*\|advarsel\|på tide\|du kan\|normal\w*` |
| da | `giv\|give\|giver\|gav\|givet\|tilladt\|må\|bør\|skal\|sikker\w*\|farlig\w*\|anbefal\w*\|for tidligt\|overdosis\|advarsel\|tid til\|du kan\|normal\w*` |
| fi | `anna\|antaa\|annettu\|saa\|saat\|sallittu\|pitää\|täytyy\|kannattaa\|turvalli\w*\|vaaralli\w*\|suosit\w*\|liian aikaisin\|yliannostus\|varoitus\|on aika\|voit\|normaali\w*` |

How the check matches:
- **Latin and Cyrillic** match whole words, as MedicationCopyTests does. fi «anna» therefore never fires on
  «annos» or «annosväli», and pt «pode» never fires on «podem» (which is still a call to act; avoid it).
- **ja, ko and zh-Hant** match as substrings, since these scripts have no spaces between words.
  - ja 「できます」 is forbidden in medication strings only. 「設定で変更できます」 elsewhere is fine.
  - zh-Hant 「可以」 likewise.
  - zh-Hant 給 alone would catch 「給寶寶」 in neutral lines, so the list holds 給藥, and a reviewer reads every 給.
- **No «!»** in any medication string, in any language (ja and zh-Hant: no full-width 「！」 either).
- The words also stay out of the stool-colour warning and the growth notes, where they would turn a fact into a
  verdict ("normal", "norm"): the glossary marks those rows **(S)**.

## 5. Two registers for stool

A parent says one word; a doctor reads another. As es already does («caca» on the screen and in the warning,
«heces» in the CSV and the report), each language picks its pair:

| language | parent (screen, warning) | doctor (report, CSV) |
|---|---|---|
| es (live) | caca | heces |
| en, ru (live) | stool / стул | stool / стул |
| uk | випорожнення | випорожнення |
| de | Stuhl | Stuhl |
| fr | selles | selles |
| ja | うんち | 便 |
| ko | 대변 | 대변 |
| zh-Hant | 大便 | 大便 |
| pt-BR | cocô | fezes |
| pt-PT | cocó | fezes |
| sv | bajs | avföring |
| nb | bæsj | avføring |
| da | afføring | afføring |
| fi | kakka | uloste |

The warning keeps the parent's word and the clinical action: «Este color de caca requiere atención médica»,
ja 「このうんちの色は医師の診察が必要です」, pt-BR «Essa cor de cocô precisa de avaliação médica».

## 6. Demo names

The demo baby in the seed scenarios and the App Store screenshots is a girl of about two months. Her name is a
common girls' name of recent years in that country, short, and unmistakably a girl's name to a local reader.

| language | name | note |
|---|---|---|
| en (live) | Mia | — |
| ru (live) | Лея | — |
| es (live) | Lucía | — |
| uk | Злата | |
| de | Emma | |
| fr | Jade | |
| ja | ひまり | written in hiragana, so no kanji reading has to be chosen |
| ko | 서아 | |
| zh-Hant | 詠晴 | |
| pt-BR | Alice | |
| pt-PT | Leonor | |
| sv | Maja | |
| nb | Nora | |
| da | Alma | |
| fi | Aino | |

The names stand in for the parent's own and appear only in the demo data; any of them can be swapped later
without touching the copy.

- All names are nominative-only in the copy (§ 2), so none of them needs a case form.
- ja ひまり and ko 서아 end in a vowel: ko particles after it are 는 / 가 / 를 if a string ever needs one.

## 7. Small things that keep the voice

- **Exclamation marks**: as voice.md — at most one, in a celebration (onboarding done, a first week). Never in a
  medication, health or error line.
- **Contractions**: fr keeps «c’est», «l’app»; de never contracts «geht’s» in UI; pt-BR «pra» is too casual — write
  «para».
- **Diminutives**: uk and ru-style diminutives («пляшечка», «підгузочок») only where Apple or the clinic use them:
  «пляшечка» yes, «підгузочок» no.
- **Emoji**: none in the new languages beyond what en has.
- **Abbreviations**: only the unit symbols of glossary § 9. No «z. B.», «p. ex.», «esim.» in short UI text.

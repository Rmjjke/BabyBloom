# Glossary — the 12 new languages

The terms every translation uses, in uk, de, fr, ja, ko, zh-Hant, pt-BR, pt-PT, sv, nb, da and fi. en is the
source; ru and es live in their files and in voice.md. One term = one word per language, everywhere it appears:
a screen, a notification, the widget, the Live Activity, the doctor report and the CSV.

Column `nb` is Norwegian Bokmål. `zh-Hant` is the Taiwan vocabulary, which Hong Kong and Macau read too. **(S)**
marks a term where a wrong word changes the meaning of a medication or health line.

## 1. Sources and precedence

Every term was checked against these sources, in this order:

1. **Apple's own strings in iOS 26.3**, read from the simulator runtime's localized resources (not from screenshots).
   These cover system words, buttons, the Health app's words and the names of iOS places such as Settings and the
   Lock Screen. The parent sees these words around our app every day, so ours match them.
2. **The national child-health record**, for growth measurements, where we found one: Helsedirektoratet (nb),
   Caderneta da Criança (pt-BR), DGS Norma 010/2013 (pt-PT), the French WHO charts, Rikshandboken (sv). These are
   the words the parent hears at the clinic.
3. **WHO's published titles** in that language: the Child Growth Standards, "percentile".
4. **Medicine leaflets** for children's paracetamol and ibuprofen, for dose, interval and maximum: BDPM (fr),
   Nurofen Junior and ben-u-ron (de), Alvedon (sv), Felleskatalogen (nb), Panodil Junior (da), Fimea (fi),
   ben-u-ron (pt-PT), Tylenol (pt-BR), Нурофєн для дітей (uk), PMDA カロナール (ja), MFDS (ko), a Taipei City
   Hospital leaflet (zh-Hant).
5. **CLDR / Foundation** for units, numbers, dates and quotes (§ 9–10).

Where two sources disagree, the higher one wins, except for the medication words (§ 6): there the leaflet's
meaning (minimum, maximum, not before) wins over any wording, and Apple's word is used only when it carries
the same meaning.

**Where Apple's word differs from what a translator would expect** (each one checked; Apple wins):

| language | expected | Apple, used here |
|---|---|---|
| uk | застосунок (app) | **програма** (6964 uses, 0 of застосунок) |
| uk | Налаштування (Settings) | **Параметри** |
| fr | Plus (the tab "More") | **Autre** (the iOS tab bar's own "More" item) |
| fi | sovellus (app) | **appi** (2495 uses against 53) — the brand compound is "Bitty-appi", § 2 |
| pt-PT | app | **aplicação** (7359 against 575) |
| de | Health-App | **Health** (the app's name is not translated in de) |
| zh-Hant | 應用程式 (app) | **App**, in Latin (14867 against 327) |

## 2. The app's name

| language | name | in a sentence |
|---|---|---|
| uk | **Нічка** | declines: Нічка, Нічки, Нічці, Нічку, Нічкою, Нічко; the tone sheet has the slots |
| de, fr, pt-BR, pt-PT, sv, nb, da | **Bitty** | never declined; no genitive "Bittys", no adjective agreeing with the name |
| fi | **Bitty** | only as the compound **Bitty-appi**, the case on "appi": Bitty-appissa, Bitty-appiin, Bitty-appin |
| ja, ko, zh-Hant | **Bitty**, in Latin letters | no katakana, hangul or Chinese form |

- The name in "Settings → Bitty" equals the language's display name, letter for letter.
- **Premium** is Latin in every language, ja, ko and zh-Hant included: "Bitty Premium", uk «Нічка Premium».
- Prepositions with the name:
  - fr «dans Bitty» (not «sur»).
  - de «in Bitty», «für Bitty».
  - pt-BR «no Bitty» (o app); pt-PT «na aplicação Bitty».
  - sv/nb/da «i Bitty», «appen Bitty».
  - ja 「Bittyで」「Bittyの」.
  - ko: "Bitty" ends in a vowel, so 는 / 가 / 를 / 로 (Bitty는, Bitty에서).
  - zh-Hant 「在 Bitty 中」 → written 「在Bitty中」, no spaces (§ 10).

## 3. System words and buttons (Apple)

### 3.1 iOS places and features

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Settings (the iOS app) | Параметри | Einstellungen | Réglages | 設定 | 설정 | 設定 | Ajustes | Definições | Inställningar | Innstillinger | Indstillinger | Asetukset |
| Open Settings | Відкрити Параметри | Einstellungen öffnen | Ouvrir Réglages | 設定を開く | 설정 열기 | 打開「設定」 | Abrir Ajustes | Abrir Definições | Öppna Inställningar | Åpne Innstillinger | Åbn Indstillinger | Avaa Asetukset |
| Notifications | Сповіщення | Mitteilungen | Notifications | 通知 | 알림 | 通知 | Notificações | Notificações | Notiser | Varslinger | Notifikationer | Ilmoitukset |
| Allow Notifications | Дозволити сповіщення | Mitteilungen erlauben | Autoriser les notifications | 通知を許可 | 알림 허용 | 允許通知 | Permitir Notificações | Permitir notificações | Tillåt notiser | Tillat varslinger | Tillad notifikationer | Salli ilmoitukset |
| Live Activities | Дії наживо | Live-Aktivitäten | Activités en direct | ライブアクティビティ | 실시간 현황 | 即時動態 | Atividades ao Vivo | Atividades em tempo real | Liveaktiviteter | Oppdateringer i sanntid | Liveaktiviteter | Liveseuranta |
| Widgets | Віджети | Widgets | Widgets | ウィジェット | 위젯 | 小工具 | Widgets | Widgets | Widgetar | Widgeter | Widgets | Widgetit |
| Lock Screen | Замкнений екран | Sperrbildschirm | Écran verrouillé | ロック画面 | 잠금 화면 | 鎖定畫面 | Tela Bloqueada | Ecrã bloqueado | Låsskärm | Låst skjerm | Låseskærm | Lukittu näyttö |
| Home Screen | Початковий екран | Home-Bildschirm | Écran d’accueil | ホーム画面 | 홈 화면 | 主畫面 | Tela de Início | Ecrã principal | Hemskärm | Hjem-skjerm | Hjemmeskærm | Koti-valikko |
| Face ID & Passcode | Face ID і код допуску | Face ID & Code | Face ID et code | Face IDとパスコード | Face ID 및 암호 | Face ID與密碼 | Face ID e Código | Face ID e código | Face ID och lösenkod | Face ID og kode | Face ID & kode | Face ID ja pääsykoodi |
| Photos | Фотографії | Fotos | Photos | 写真 | 사진 | 照片 | Fotos | Fotografias | Bilder | Bilder | Fotos | Kuvat |
| Health (the app) | Здоровʼя | Health | Santé | ヘルスケア | 건강 | 健康 | Saúde | Saúde | Hälsa | Helse | Sundhed | Terveys |
| app | програма | App | app | アプリ | 앱 | App | app | aplicação | app | app | app | appi |
| Delete App | Видалити програму | App löschen | Supprimer l’app | アプリを削除 | 앱 삭제 | 刪除App | Apagar App | Apagar aplicação | Radera app | Slett app | Slet app | Poista appi |
| Subscriptions | Підписки | Abonnements | Abonnements | サブスクリプション | 구독 | 訂閱項目 | Assinaturas | Assinaturas | Abonnemang | Abonnementer | Abonnementer | Tilaukset |
| Language | Мова | Sprache | Langue | 言語 | 언어 | 語言 | Idioma | Idioma | Språk | Språk | Sprog | Kieli |
| Appearance | Вигляд | Darstellung | Apparence | 外観モード | 화면 모드 | 外觀 | Aparência | Apresentação | Utseende | Utseende | Udseende | Ulkoasu |
| Light / Dark / Automatic | Світлий / Темний / Автоматично | Hell / Dunkel / Automatisch | Claire / Sombre / Automatique | ライト / ダーク / 自動 | 라이트 / 다크 / 자동 | 淺色 / 深色 / 自動 | Clara / Escura / Automático | Tons claros / Tons escuros / Automático | Ljust / Mörkt / Automatiskt | Lyst / Mørkt / Automatisk | Lys / Mørk / Automatisk | Vaalea / Tumma / Automaattinen |
| Privacy Policy | Політика конфіденційності | Datenschutzrichtlinie | Politique de confidentialité | プライバシーポリシー | 개인정보 처리방침 | 隱私權政策 | Política de Privacidade | Política de Privacidade | Integritetspolicy | Personvernerklæring | Privatlivspolitik | Tietosuojakäytäntö |
| Terms of Use | Умови використання | Nutzungsbedingungen | Conditions d’utilisation | 利用規約 | 이용 약관 | 使用條款 | Termos de Uso | Termos de Utilização | Användarvillkor | Bruksvilkår | Brugsvilkår | Käyttöehdot |

Notes:
- ko «라이트 모드 / 다크 모드» is Apple's long form; the 3-segment control takes the short 라이트 / 다크 / 자동.
- de Appearance is «Darstellung». Apple's «Erscheinungsbild» breaks inside the word in the Settings section
  header at AX2 on 320 pt. The segment for Automatic reads «Auto», because «Automatisch» does not fit the
  three-segment control at 320 pt.
- uk «Замкнений екран» is the noun; Apple writes «на замкненому екрані» in sentences.
- Privacy Policy: Apple's strings use short or legal variants (de «Datenschutzvereinbarung», fr «Confidentialité»,
  nb «Personvern», da «Anonymitetspolitik»). The row above gives the plain title of a policy page in each
  language. Use it unless the linked page carries its own title.

### 3.2 Buttons and actions

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Save | Зберегти | Sichern | Enregistrer | 保存 | 저장 | 儲存 | Salvar | Guardar | Spara | Arkiver | Gem | Tallenna |
| Cancel | Скасувати | Abbrechen | Annuler | キャンセル | 취소 | 取消 | Cancelar | Cancelar | Avbryt | Avbryt | Annuller | Kumoa |
| Delete | Видалити | Löschen | Supprimer | 削除 | 삭제 | 刪除 | Apagar | Apagar | Radera | Slett | Slet | Poista |
| Done | Готово | Fertig | OK | 完了 | 완료 | 完成 | OK | OK | Klar | Ferdig | OK | Valmis |
| Edit | Змінити | Bearbeiten | Modifier | 編集 | 편집 | 編輯 | Editar | Editar | Ändra | Rediger | Rediger | Muokkaa |
| Add | Додати | Hinzufügen | Ajouter | 追加 | 추가 | 加入 | Adicionar | Adicionar | Lägg till | Legg til | Tilføj | Lisää |
| Close | Закрити | Schließen | Fermer | 閉じる | 닫기 | 關閉 | Fechar | Fechar | Stäng | Lukk | Luk | Sulje |
| Next | Далі | Weiter | Suivant | 次へ | 다음 | 下一步 | Seguinte | Seguinte | Nästa | Neste | Næste | Seuraava |
| Back | Назад | Zurück | Retour | 戻る | 뒤로 | 返回 | Voltar | Anterior | Tillbaka | Tilbake | Tilbage | Takaisin |
| Skip | Пропустити | Überspringen | Ignorer | スキップ | 건너뛰기 | 略過 | Ignorar | Ignorar | Hoppa över | Hopp over | Spring over | Ohita |
| Continue | Продовжити | Fortfahren | Continuer | 続ける | 계속 | 繼續 | Continuar | Continuar | Fortsätt | Fortsett | Fortsæt | Jatka |
| Not Now | Не зараз | Später | Plus tard | 今はしない | 지금 안 함 | 稍後再說 | Agora Não | Agora não | Inte nu | Ikke nå | Ikke nu | Ei nyt |
| Allow | Дозволити | Erlauben | Autoriser | 許可 | 허용 | 允許 | Permitir | Permitir | Tillåt | Tillat | Tillad | Salli |
| Turn On | Увімкнути | Aktivieren | Activer | オンにする | 켜기 | 開啟 | Ativar | Ativar | Slå på | Slå på | Slå til | Laita päälle |
| Start | Старт | Start | Démarrer | 開始 | 시작 | 開始 | Iniciar | Iniciar | Starta | Start | Start | Aloita |
| Stop | Зупинити | Stoppen | Arrêter | 停止 | 중단 | 停止 | Parar | Parar | Stoppa | Stopp | Stop | Lopeta |
| Export | Експортувати | Exportieren | Exporter | 書き出す | 내보내기 | 輸出 | Exportar | Exportar | Exportera | Eksporter | Eksporter | Vie |
| Share | Поширити | Teilen | Partager | 共有 | 공유 | 分享 | Compartilhar | Partilhar | Dela | Del | Del | Jaa |
| Restore | Повернути | Wiederherstellen | Restaurer | 復元 | 복원 | 回復 | Restaurar | Restaurar | Återskapa | Gjenopprett | Gendan | Palauta |
| Restore Purchases ¹ | Відновити покупки | Käufe wiederherstellen | Restaurer les achats | 購入を復元 | 구입 내역 복원 | 回復購買項目 | Restaurar Compras | Restaurar compras | Återställ köp | Gjenopprett kjøp | Gendan køb | Palauta ostot |
| Subscribe | Підписатися | Abonnieren | S’abonner | サブスクリプションに登録 | 구독 | 訂閱 | Assinar | Assinar | Abonnera | Abonner | Abonner | Tilaa |

¹ Not in Apple's iOS strings; the common App Store wording in each language.

- Buttons are verbs or nouns as Apple writes them: ja and ko buttons are nouns or verb stems (保存, 저장), never
  a polite sentence.
- Capitals: pt-BR capitalises each word in Apple's buttons («Agora Não», «Restaurar Compras»); pt-PT does not.
  Follow each language's column as written.
- "Stop" on the Live Activity and Dynamic Island is ≤ 12 characters in every language; all the Stop values fit.

### 3.3 Dates and periods

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Today | Сьогодні | Heute | Aujourd’hui | 今日 | 오늘 | 今天 | Hoje | Hoje | Idag | I dag | I dag | Tänään |
| Yesterday | Учора | Gestern | Hier | 昨日 | 어제 | 昨天 | Ontem | Ontem | Igår | I går | I går | Eilen |
| Day / Week / Month / Year (filter) | День / Тиждень / Місяць / Рік | Tag / Woche / Monat / Jahr | Jour / Semaine / Mois / Année | 日 / 週 / 月 / 年 | 일 / 주 / 월 / 년 | 日 / 週 / 月 / 年 | Dia / Semana / Mês / Ano | Dia / Semana / Mês / Ano | Dag / Vecka / Månad / År | Dag / Uke / Måned / År | Dag / Uge / Måned / År | Päivä / Viikko / Kuukausi / Vuosi |
| Date of Birth | Дата народження | Geburtsdatum | Date de naissance | 生年月日 | 생년월일 | 出生日期 | Data de Nascimento | Data de nascimento | Födelsedatum | Fødselsdato | Fødselsdato | Syntymäaika |
| Name | Імʼя | Name | Nom | 名前 | 이름 | 名字 | Nome | Nome | Namn | Navn | Navn | Nimi |

- de Date of Birth: Apple's Medical ID writes «Geburtstag»; a form field reads «Geburtsdatum».
- uk Name: Apple's «Назва» is the name of a thing; a child's name is «Імʼя». zh-Hant: 名稱 is a thing, 名字 a person.
- The apostrophe in uk «Здоровʼя», «Імʼя» is U+02BC, as Apple writes it.

## 4. Tabs and sections

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Home (tab) | Домівка | Startseite | Accueil | ホーム | 홈 | 首頁 | Início | Início | Hem | Hjem | Hjem | Koti |
| Feeding (tab) | Годування | Mahlzeiten | Repas | 授乳 | 수유 | 餵奶 | Mamadas | Mamadas | Matning | Mating | Madning | Syöttö |
| Sleep (tab) | Сон | Schlaf | Sommeil | 睡眠 | 수면 | 睡眠 | Sono | Sono | Sömn | Søvn | Søvn | Uni |
| Diapers (tab) | Підгузки | Windeln | Couches | おむつ | 기저귀 | 尿布 | Fraldas | Fraldas | Blöjor | Bleier | Bleer | Vaipat |
| Growth (tab) | Ріст | Wachstum | Croissance | 成長 | 성장 | 成長 | Crescimento | Crescimento | Tillväxt | Vekst | Vækst | Kasvu |
| More (tab) | Ще | Mehr | Autre | その他 | 더 보기 | 更多 | Mais | Mais | Mer | Mer | Mere | Lisää |
| History | Історія | Verlauf | Historique | 履歴 | 기록 | 記錄 | Histórico | Histórico | Historik | Logg | Historik | Historia |
| Statistics | Статистика | Statistik | Statistiques | 統計 | 통계 | 統計資料 | Estatísticas | Estatísticas | Statistik | Statistikk | Statistik | Tilastot |
| Summary | Підсумок | Übersicht | Résumé | 概要 | 요약 | 摘要 | Resumo | Resumo | Översikt | Oversikt | Oversigt | Yhteenveto |
| Profile | Профіль | Profil | Profil | プロフィール | 프로필 | 個人檔案 | Perfil | Perfil | Profil | Profil | Profil | Profiili |
| Reminder | Нагадування | Erinnerung | Rappel | リマインダー | 미리 알림 | 提醒事項 | Lembrete | Lembrete | Påminnelse | Påminnelse | Påmindelse | Muistutus |
| Timer | Таймер | Timer | Minuteur | タイマー | 타이머 | 計時器 | Timer | Temporizador | Timer | Tidtaker | Tidtagning | Ajastin |
| Notes | Нотатки | Notizen | Notes | メモ | 메모 | 備忘錄 | Notas | Notas | Anteckningar | Notater | Noter | Muistiinpanot |

- "Home" and "More" are the iOS tab words (the TV and Podcasts apps for Home, the system tab bar for More). uk
  «Домівка» is Apple's Home tab; «Ще» is the system "More" item.
- The tab labels must fit the tab bar at 320 pt (each no wider than ru «Подгузники» at the tab font). Measured with
  CoreText per language; the widest new ones are «Crescimento», «Croissance», «Mahlzeiten» and «Startseite».
- "History" is a list of past entries. ko 기록 and zh-Hant 記錄 are also the words for "log" (§ 6); in ko and
  zh-Hant a history title may read 기록 / 記錄 because Apple uses the same word there.
- "Timer" is the running feeding or sleep timer, which counts up. Apple's nb «Nedtelling» is the Clock app's
  countdown, so nb takes «Tidtaker» (a timer that measures). da «Tidtagning» is Apple's stopwatch word and fits.

## 5. Feeding, sleep, diapers

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| feeding (one event) | годування | Mahlzeit | repas | 授乳 | 수유 | 餵奶 | mamada | mamada | matning | mating | madning | syöttö |
| breastfeeding | годування грудьми | Stillen | allaitement | 母乳 | 모유 수유 | 親餵 | amamentação | amamentação | amning | amming | amning | imetys |
| breast | груди | Brust | sein | 胸 (左 / 右) | 가슴 | 乳房 | peito | mama | bröst | bryst | bryst | rinta |
| left / right / both | ліва / права / обидві | links / rechts / beide | gauche / droit / les deux | 左 / 右 / 両方 | 왼쪽 / 오른쪽 / 양쪽 | 左側 / 右側 / 兩側 | esquerdo / direito / ambos | esquerda / direita / ambas | vänster / höger / båda | venstre / høyre / begge | venstre / højre / begge | vasen / oikea / molemmat |
| bottle | пляшечка | Fläschchen | biberon | 哺乳瓶 | 젖병 | 奶瓶 | mamadeira | biberão | flaska | flaske | flaske | pullo |
| formula | суміш | Pulvermilch ³ | lait infantile | ミルク | 분유 | 配方奶 | fórmula | leite de fórmula | ersättning | morsmelkerstatning | modermælkserstatning | korvike |
| pumped milk | зціджене молоко | abgepumpte Milch | lait maternel tiré | 搾乳 | 유축 모유 | 擠出的母乳 | leite materno ordenhado | leite materno extraído | urpumpad bröstmjölk | utpumpet morsmelk | udmalket modermælk | pumpattu rintamaito |
| sleep | сон | Schlaf | sommeil | 睡眠 | 수면 | 睡眠 | sono | sono | sömn | søvn | søvn | uni |
| nap | денний сон | Tagschlaf | sieste | お昼寝 | 낮잠 | 小睡 | soneca | sesta | tupplur | lur | lur | päiväunet |
| night sleep | нічний сон | Nachtschlaf | sommeil de nuit | 夜の睡眠 | 밤잠 | 夜間睡眠 | sono noturno | sono noturno | nattsömn | nattesøvn | nattesøvn | yöunet |
| Woke up (the stop button) | Прокинувся | Wach | Réveil | 起きた | 깼어요 | 醒了 | Acordou | Acordou | Vaknade | Våknet | Vågnede | Heräsi |
| diaper | підгузок | Windel | couche | おむつ | 기저귀 | 尿布 | fralda | fralda | blöja | bleie | ble | vaippa |
| wet / dirty | мокрий / брудний | nass / voll | mouillée / sale | おしっこ / うんち | 소변 / 대변 | 濕 / 髒 | molhada / suja | molhada / suja | blöt / bajs | våt / bæsj | våd / bæ | märkä / kakka |
| stool (parent-facing) | випорожнення | Stuhl | selles | うんち | 대변 | 大便 | cocô | cocó | bajs | bæsj | afføring | kakka |
| stool (doctor report, CSV) | випорожнення | Stuhl | selles | 便 | 대변 | 大便 | fezes | fezes | avföring | avføring | afføring | uloste |
| stool colour warning: see a doctor **(S)** | «зверніться до лікаря» | «ärztlich abklären lassen» | «consultez un médecin» | 「医師に相談してください」 | 「의사와 상담하세요」 | 「請諮詢醫生」 | «procure um médico» | «consulte um médico» | «kontakta läkare» | «kontakt lege» | «kontakt læge» | «ota yhteyttä lääkäriin» |

Notes:
- **Feeding is one word for every kind** (breast, bottle, formula, pumped). The tab, the event, the timer and the
  stat use it.
  - de «Mahlzeit» rather than «Fütterung», which is said of animals.
- ³ de formula is «Pulvermilch», the parents' word. «Säuglingsnahrung» does not fit the feeding rows at 320 pt
  and AX2 (256 pt in 240), and it also means baby food in jars. The AAP source title keeps «Säuglingsnahrung».
  - fr «repas»: «tétée» is a breastfeed only.
  - ja 授乳 covers breast and bottle; Apple's Health app also uses 授乳 for breastfeeding.
  - pt «mamada» covers both, in pt-BR and pt-PT.
- **Side words agree with the language's word for breast.**
  - fr «sein» is masculine, so gauche / droit.
  - pt-BR «peito» is masculine (esquerdo / direito); pt-PT «mama» is feminine (esquerda / direita).
  - uk «груди» is plural only; the side is «ліва / права» (грудь), as Ukrainian feeding apps write it.
- **"Woke up" without gender.**
  - The past tense has no gender in pt, the Nordic languages and fi.
  - de «Wach», fr «Réveil» and ja/ko/zh-Hant need no gender either.
  - **uk is the one gendered form**: «Прокинувся», as ru «Проснулся». A gender-free uk form is either bookish
    («Пробудження») or longer than the 12-character Stop budget («Вже не спить»).
- **Wet / dirty.** ja, ko and the Nordic "dirty" are the words parents use for what is in the diaper (うんち, 대변,
  bajs/bæsj/bæ, kakka), because an adjective "dirty diaper" is not said. The others agree with the noun for diaper:
  fr «couche» f., pt «fralda» f.
- **Stool registers** (like es caca / heces): the parent-facing form and warning use the everyday word; the doctor
  report and the CSV use the clinical one. uk, de, fr, ko, zh-Hant and da use one word in both.
- **(S) stool colour warning**: the action stays "see a doctor", never "maybe", "you could" or "if you are worried".
  Apple's word for doctor: § 6.

## 6. Growth (WHO)

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| growth | ріст | Wachstum | croissance | 成長 | 성장 | 成長 | crescimento | crescimento | tillväxt | vekst | vækst | kasvu |
| weight | вага | Gewicht | poids | 体重 | 체중 | 體重 | peso | peso | vikt | vekt | vægt | paino |
| height (length) | зріст | Größe | taille | 身長 | 신장 | 身高 | comprimento | comprimento | längd | lengde | længde | pituus |
| head circumference | обвід голови | Kopfumfang | périmètre crânien | 頭囲 | 머리둘레 | 頭圍 | perímetro cefálico | perímetro cefálico | huvudomfång | hodeomkrets | hovedomfang | päänympärys |
| measurements | виміри | Messwerte | mesures | 測定値 | 측정값 | 測量值 | medidas | medidas | mått | mål | mål | mitat |
| weighing | зважування | Wiegen / Wägung ² | pesée | 体重測定 | 체중 측정 | 量體重 | pesagem | pesagem | vägning | veiing | vejning | punnitus |
| weight gain | набір ваги | Gewichtszunahme | prise de poids | 体重増加 | 체중 증가 | 體重增加 | ganho de peso | aumento de peso | viktökning | vektøkning | vægtøgning | painonnousu |
| percentile **(S)** | перцентиль | Perzentile | percentile | パーセンタイル | 백분위수 | 百分位 | percentil | percentil | percentil | prosentil | percentil | persentiili |
| centile channel **(S)** | перцентильний коридор | Perzentilenkanal | couloir de percentiles | パーセンタイル帯 | 백분위 구간 | 百分位區間 | faixa de percentil | faixa de percentil | percentilkanal | prosentilkanal | percentilkanal | persentiilikanava |
| WHO **(S)** | ВООЗ | WHO | OMS | WHO | WHO | WHO | OMS | OMS | WHO | WHO | WHO | WHO |
| WHO Child Growth Standards | стандарти росту дітей ВООЗ | WHO-Wachstumsstandards | normes de croissance de l’enfant de l’OMS | WHOの子どもの成長基準 | WHO 아동 성장 기준 | WHO兒童生長標準 | padrões de crescimento infantil da OMS | padrões de crescimento infantil da OMS | WHO:s tillväxtstandard | WHOs vekststandard | WHO’s vækststandard | WHO:n kasvustandardit |
| reference (range) **(S)** | орієнтир | Richtwert | repère | 目安 | 참고 범위 | 參考範圍 | referência | referência | riktvärde | referanseverdi | vejledende værdi | viitearvo |
| corrected age | скоригований вік | korrigiertes Alter | âge corrigé | 修正月齢 | 교정 연령 | 矯正年齡 | idade corrigida | idade corrigida | korrigerad ålder | korrigert alder | korrigeret alder | korjattu ikä |
| pediatrician | педіатр | Kinderarztpraxis ¹ | pédiatre | 小児科医 | 소아청소년과 의사 | 小兒科醫師 | pediatra | pediatra | barnläkare | barnelege | børnelæge | lastenlääkäri |
| doctor | лікар | Arzt / ärztlich | médecin | 医師 | 의사 | 醫生 | médico | médico | läkare | lege | læge | lääkäri |

¹ de: «Kinderarzt» is masculine. A title or line about the visit names the practice («für die Kinderarztpraxis»,
«beim Kinderarzttermin»), so it needs no gender.

² de: «Wiegen» is the act and has no plural («Zeit zum Wiegen»). A weighing as one logged entry, which can be
counted, is «Wägung / Wägungen» («Wägung hinzufügen», «Zwei Wägungen im Abstand von …», the report's «Wägungen»).

Notes:
- **Height.** Babies are measured lying down, so several national records say "length".
  - nb, pt-BR and pt-PT follow their child-health records (lengde, comprimento).
  - sv, da and fi say length / height with one word.
  - de «Größe», fr «taille», uk «зріст», ja 身長 and ko 신장 are the clinic words and Apple Health's.
  - zh-Hant 身高 is Apple Health's. The Taiwan child-health record's own term was not found.
- **Percentile.**
  - nb is spelled «prosentil» (Helsedirektoratet), never «persentil».
  - sv clinics chart SD and pt-BR clinics chart z-scores. Our charts show percentiles, so the word stays
    «percentil» there, and the help text says what it is.
- **Ordinals** (3rd / 97th percentile):
  - fr «3e / 97e»;
  - de «3. / 97. Perzentile»;
  - sv «3:e / 97:e»;
  - nb, da and fi «3. / 97.»;
  - uk «3‑й / 97‑й» with U+2011, as ru;
  - pt-BR and pt-PT «3º / 97º»;
  - ja, ko and zh-Hant a plain number before the word (3パーセンタイル, 3백분위수, 第3百分位).
- **The WHO name.**
  - In a footnote and the info text, write it out once: uk «Всесвітня організація охорони здоровʼя (ВООЗ)»,
    fr «Organisation mondiale de la santé (OMS)», ja 世界保健機関（WHO）, ko 세계보건기구(WHO),
    zh-Hant 世界衛生組織（WHO）, pt «Organização Mundial da Saúde (OMS)».
  - The Nordic languages, fi and de keep «WHO».
- **(S) "reference" is never a norm.** Never "normal", "norm" or "standard" in a verdict sense:
  - de normal / Norm;
  - fr normal / norme;
  - ja 正常 / 標準;
  - ko 정상;
  - zh-Hant 正常 / 標準;
  - pt normal;
  - sv/nb/da normal;
  - fi normaali;
  - uk норма / нормальний.
  The WHO standards' title is the one place «standard» appears.
  - The source wording: the 15–85 band is the "usual range" (ru «обычный диапазон», es «el rango habitual»);
    a small loss after birth and one-off wobbles are "common" (ru «обычное дело», es «habitual»); weight
    "growing steadily" (ru «стабильно», es «de forma estable»). Translate these, not a word for "normal".
  - The diaper goal ("Daily Goal", ru «Норма в день») is the parent's own target, not a reference: the rule
    does not touch it.
- **(S) A drop "by N centile channels"** stays a count of the bands between the chart lines. It is never a
  percentage and never "points".

## 7. Medications **(S)**

`medications.md` is the law for every language. The words below carry its meaning anchors:
minimum, not before, most in 24 hours, since / before / after, counts / does not check, logged / last.

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| medication (an item) | ліки | Medikament | médicament | 薬 | 약 | 藥品 | medicamento | medicamento | läkemedel | medisin | medicin | lääke |
| Medications (section) | Ліки | Medikamente | Médicaments | 薬 | 약 | 用藥 | Medicamentos | Medicação | Läkemedel | Medisiner | Medicin | Lääkkeet |
| dose (the amount) **(S)** | доза | Dosis | dose | 用量 | 용량 | 劑量 | dose | dose | dos | dose | dosis | annos |
| dose (one logged event) **(S)** | доза | Dosis | dose | 服薬 | 투여 | 一劑 | dose | dose | dos | dose | dosis | annos |
| N doses (a count) **(S)** | N доз | N Dosen | N doses | N回 | N회 | N次 | N doses | N doses | N doser | N doser | N doser | N annosta |
| last dose **(S)** | остання доза | letzte Dosis | dernière dose | 前回の服薬 | 마지막 투여 | 最後一劑 | última dose | última dose | sista dosen | siste dose | sidste dosis | viimeisin annos |
| logged dose **(S)** | записана доза | eingetragene Dosis | dose enregistrée | 記録した服薬 | 기록된 투여 | 已記錄的一劑 | dose registrada | dose registada | loggad dos | loggført dose | registreret dosis | kirjattu annos |
| log (a dose) | записати | eintragen | enregistrer | 記録 | 기록 | 記錄 | registrar | registar | logga | loggføre | registrere | kirjata |
| interval **(S)** | інтервал | Abstand | intervalle | 間隔 | 간격 | 間隔 | intervalo | intervalo | intervall | intervall | interval | annosväli |
| minimum time between doses **(S)** | мінімальний інтервал між дозами | Mindestabstand zwischen den Dosen | intervalle minimal entre deux doses | 服薬の最短間隔 | 최소 투여 간격 | 兩劑至少間隔 | intervalo mínimo entre doses | intervalo mínimo entre doses | minsta tid mellan doser | minste tid mellom doser | mindste tid mellem doser | vähimmäisaika annosten välillä |
| most doses in 24 hours **(S)** | максимум доз за 24 години | höchstens … Dosen in 24 Stunden | au maximum … doses en 24 heures | 24時間の最大回数 | 24시간 최대 투여 횟수 | 24小時內最多次數 | máximo de doses em 24 horas | máximo de doses em 24 horas | högst … doser per dygn | høyst … doser per døgn | højst … doser pr. døgn | enintään … annosta vuorokaudessa |
| not before **(S)** | не раніше ніж | frühestens | pas avant | 〜以降 | ~ 이후 | 最早 | não antes de | não antes de | tidigast | tidligst | tidligst | aikaisintaan |
| the interval has passed **(S)** | інтервал минув | der Abstand ist vorbei | l’intervalle est écoulé | 間隔が過ぎました | 간격이 지났어요 | 已過間隔 / 間隔已過 | o intervalo já passou | o intervalo já passou | intervallet har gått | intervallet er over | intervallet er gået | annosväli on kulunut |
| ended (medications) | завершені | beendet | terminés | 終了 | 종료됨 | 已結束 | encerrados | terminados | avslutade | avsluttet | afsluttede | päättyneet |

Notes:
- **uk «доза», never «прийом»**, as ru «доза», never «приём». The leaflets write «інтервал між прийомами»; we write
  «між дозами».
- **uk «записана доза»** for a logged dose, never «відмічена» (a calque); it matches the verb «записати». The
  ceiling is «максимум доз за 24 години», as in «ваш максимум»; «найбільше доз» reads as a count of the past.
- **ja and ko split "dose" by meaning.**
  - The amount: 用量 / 용량.
  - A logged event: 服薬 / 투여 (Apple Health: 前回の服薬, 마지막 투여).
  - A count: 回 / 회 (the leaflets: 1日5回, 1일 5회).
  - Never ja 服用 for "dose": it means "taking", and next to a time it reads as a call to take.
- **zh-Hant**: the amount is 劑量, one event is 一劑 (Apple: 最後一劑), and a count is 次 (the leaflet: 每24小時之內不可超過5次).
- **pt-PT «não antes de»**, not «não antes das»: the slot takes a time («de 01:30») and a day with a time
  («de amanhã às 01:30»); «das» breaks before a day. The pt-PT time phrases carry «às» («ontem às 22:10»).
- **de «Abstand»**: the leaflet writes «Der zeitliche Abstand zwischen zwei Einnahmen soll mindestens 6 Stunden
  betragen». Apple's «Intervall» is fine in the chips («Abstand: 6 Std.»); keep one word per screen.
- **sv, nb and da write "24 hours" as «dygn» / «døgn»** in the maximum, as the leaflets do («högst 4 gånger per
  dygn», «Maksimal døgndose», «døgndosis»). The digits "24" then leave the sentence; the digit check accepts
  dygn / døgn for 24 h.
- **fi «annosväli»** is the leaflet word for the interval («Annosten välillä pitää olla vähintään 4 tuntia»).
- **fi «viimeisin annos»**, not «viimeinen annos»: «viimeinen» also reads as the final dose of a course;
  «viimeisin» is only the most recent one. The before/after alert titles carry «jälkeen» / «ennen», never a bare
  case ending («kirjatusta» / «kirjattuun» leave the direction to the reader).
- **de «frühestens» stands alone before a time slot**: the when-strings carry «um» themselves («morgen um 01:30»),
  so «frühestens um» would double it. "Log a dose" is «eintragen», as in «eingetragene Dosis».
- **"Not before" is the earliest time, never a prompt.** de «frühestens», sv/nb/da «tidigast / tidligst»,
  fi «aikaisintaan» carry it in one word. ja 「〜以降」 and ko 「~ 이후」 follow the time.
- **"The interval has passed" says only that time passed.** It never says "you can give", in any language.
- **Forbidden words**: tone.md § 4 lists them per language. The medication check fails a value that
  contains one.

## 8. Premium and the paywall

| en | uk | de | fr | ja | ko | zh-Hant | pt-BR | pt-PT | sv | nb | da | fi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium | Premium |
| subscription | підписка | Abonnement | abonnement | サブスクリプション | 구독 | 訂閱 | assinatura | assinatura | abonnemang | abonnement | abonnement | tilaus |
| free trial | безкоштовний пробний період | kostenloser Testzeitraum | essai gratuit | 無料トライアル | 무료 체험 | 免費試用 | avaliação gratuita | período experimental gratuito | gratis provperiod | gratis prøveperiode | gratis prøveperiode | ilmainen kokeilu |
| per month / per year / per week | на місяць / на рік / на тиждень | pro Monat / pro Jahr / pro Woche | par mois / par an / par semaine | 月額 / 年額 / 週額 | 월 / 연 / 주 | 每月 / 每年 / 每週 | por mês / por ano / por semana | por mês / por ano / por semana | per månad / per år / per vecka | per måned / per år / per uke | pr. måned / pr. år / pr. uge | kuukaudessa / vuodessa / viikossa |
| Best value (the badge) | Найвигідніше | Bestes Angebot | Meilleure offre | いちばんお得 | 최고의 혜택 | 最划算 | Melhor valor | Melhor valor | Bästa värde | Best verdi | Bedste værdi | Edullisin |

Notes:
- ja 月額 / 年額 and ko 월 / 연 go **before** the price («月額 ¥480», «월 ₩4,400»); the price-per-period
  templates are written that way.
- The trial wording names the length with the plural template ("7 days free"), never a bare number.
- zh-Hant 最划算 is Taiwan usage (划 is also a Traditional character); it is not a Simplified slip.

## 9. Units and number formats

From Foundation (CLDR) for the pinned region of each language. The app formats numbers through the locale. Where
the copy holds a unit itself (`unit.*`, `duration.*`, chips), it writes these symbols.

| language | g | kg | ml | cm | h | min | s | weeks (short) | decimal | percent | time |
|---|---|---|---|---|---|---|---|---|---|---|---|
| uk | г | кг | мл | см | год | хв | с | тиж. | 2,5 | 10% | 04:13 |
| de | g | kg | ml | cm | Std. | Min. | Sek. | Wo. | 2,5 | 10 % | 04:13 |
| fr | g | kg | ml | cm | h | min | s | sem. | 2,5 | 10 % | 04:13 |
| ja | g | kg | ml | cm | 時間 | 分 | 秒 | 週 | 2.5 | 10% | 4:13 |
| ko | g | kg | mL | cm | 시간 | 분 | 초 | 주 | 2.5 | 10% | 오전 4:13 |
| zh-Hant | 克 | 公斤 | 毫升 | 公分 | 小時 | 分鐘 | 秒 | 週 | 2.5 | 10% | 凌晨4:13 |
| pt-BR | g | kg | ml | cm | h | min | seg | sem. | 2,5 | 10% | 04:13 |
| pt-PT | g | kg | ml | cm | h | min | seg | sem. | 2,5 | 10% | 04:13 |
| sv | g | kg | ml | cm | tim | min | s | v. | 2,5 | 10 % | 04:13 |
| nb | g | kg | ml | cm | t | min | sek | u. | 2,5 | 10 % | 04:13 |
| da | g | kg | ml | cm | t. | min. | sek. | u. | 2,5 | 10 % | 04.13 |
| fi | g | kg | ml | cm | t | min | s | vk | 2,5 | 10 % | 4.13 |

Spacing between the number and the unit:
- **All Latin and Cyrillic languages**: a no-break space (U+00A0): «120 ml», «2 год 15 хв», «Abstand: 6 Std.».
- **ja**: U+00A0 before a Latin symbol («3,500 g», «120 ml»); no space before a native counter (2時間15分, 3回, 5日).
- **ko**: no space anywhere: «3,500g», «120mL», «52cm», «2시간 15분» (a space between the two parts only), 3회.
- **zh-Hant**: no space anywhere: «3500克», «120毫升», «52公分», «2小時15分鐘», 3次.
- **Percent**: de, fr, sv, nb, da and fi write a no-break space before % («10 %», `%d %%`); uk, ja, ko, zh-Hant and
  pt write none.
- **Group separator**: the locale's own (de 3.500, fr 3 500 with U+202F, sv/nb/fi 3 500 with U+00A0, pt-PT 3500
  with none for four digits). The app's number formatter writes it; the copy never types a grouped number.
- **Duration with two parts**: uk «2 год 15 хв», de «2 Std. 15 Min.», fr «2 h 15 min», ja 2時間15分,
  ko 2시간 15분, zh-Hant 2小時15分鐘. `duration.h_min` follows the same shape in each language.

## 10. Punctuation, quotes and line breaks

| language | quotes | inner quotes | other |
|---|---|---|---|
| uk | «…» | „…“ | the em dash spaced, U+00A0 before it (as ru) |
| de | „…“ | ‚…‘ | no space before ? ! : |
| fr | « … » | “…” | **U+00A0 before : ? ! ; and inside « »** — Apple writes U+00A0, not the narrow U+202F |
| ja | 「…」 | 『…』 | full-width 。、：！？; no spaces between Japanese and Latin or digits («Bittyで記録») |
| ko | ‘…’ in UI labels (Apple) / “…” in sentences | ‘…’ | Western punctuation . , ? ! with spaces between words |
| zh-Hant | 「…」 | 『…』 | full-width ，。：；！？、（）; no spaces between Han and Latin or digits («在Bitty中», «5分鐘») |
| pt-BR | “…” | ‘…’ | — |
| pt-PT | “…” | ‘…’ | Apple writes “…” (CLDR says «»; follow Apple) |
| sv | ”…” | ’…’ | both marks are the closing shape |
| nb | «…» | ‘…’ | — |
| da | “…” | ‘…’ | — |
| fi | ”…” | ’…’ | both marks are the closing shape |

- The apostrophe is ’ (U+2019) in fr, pt, sv, nb, da and fi (Apple: «Supprimer l’app»); uk uses ʼ (U+02BC).
- The rules from voice.md hold in every language: the word joiner after a range dash («6–⁠10»), the no-break space
  before a spaced em dash, U+2060 after a unit slash (g/⁠week).
- ja and zh-Hant break lines between any two characters; CoreText keeps 。、，」 off a line start. A line that must not
  break (a number and its counter) is short enough to need no glue.
- **zh-Hant spacing correction**: an earlier plan said zh-Hant spaces Han from Latin and digits. Apple's zh-TW
  strings do not (Han + digit with no space 5004 times, with a space 10 times). The templates write no space.

## 11. zh-Hant checks

### 11.1 Characters that are Simplified only

A drafting model slips into Simplified. The check rejects any character of a zh-Hant value that does not encode
in Big5 (the Traditional character set; Latin, digits and our space characters excepted). It also rejects this
list, which catches the Simplified forms Big5 happens to hold or that look alike:

体 着 为 们 这 说 时 会 个 对 过 还 进 动 从 么 开 关 门 见 问 头 买 卖 东 车 让 认 识 语 读 写 钟 错 线 电 话 图
书 亲 儿 妈 岁 觉 热 疗 医 师 宝 爷 样 养 温 湿 脏 记 录 统 计 数 据 设 订 阅 隐 条 复 购 删 编 辑 确
继 续 显 历 围 卫 组 织 药 剂 间 长 发 后 尽 种 号 断

Characters written the same in both scripts (置, 示, 私, 款, 恢) are not on the list; nor are 里 and 准, which
Taiwan writes too (公里, 准許). Apple's zh-TW strings use none of the listed characters except 温, once, where
Taiwan's standard form is 溫.

### 11.2 Mainland terms

| mainland | Taiwan (use) | meaning |
|---|---|---|
| 软件 / 軟件 | 軟體 | software |
| 视频 / 視頻 | 影片 | video |
| 信息 | 訊息 / 資訊 | message / information |
| 默认 / 默認 | 預設 | default |
| 用户 / 用戶 | 使用者 | user |
| 质量 / 質量 | 品質 | quality |
| 屏幕 | 螢幕 | screen |
| 网络 / 網絡 | 網路 | network |
| 设置 / 設置 | 設定 | settings |
| 文件 | 檔案 | file |
| 打印 | 列印 | print |
| 菜单 / 菜單 | 選單 | menu |
| 登录 / 登錄 | 登入 | sign in |
| 支持 | 支援 | support |
| 激活 | 啟用 | activate |
| 程序 | 程式 | program |
| 数据 / 數據 | 資料 | data |
| 通过 / 通過 (by means of) | 透過 | through |
| 保存 | 儲存 | save |
| 账户 / 賬戶 | 帳號 | account |
| 厘米 / 釐米 | 公分 | centimetre |
| 尿不湿 / 尿不濕 | 尿布 | diaper |
| 周 (week) | 週 | week |
| 宝宝 / 寶寶 | 寶寶 is fine in Taiwan; prefer 寶寶 only in warm lines, 嬰兒 in clinical ones | baby |

### 11.3 zh-Hant voice

- **你**, never 您, as Apple's zh-TW system voice («你的 iPhone»).
- "App" in Latin; Apple writes 「健康」App, 刪除App.
- Quotes 「」 for names of places in iOS: 打開「設定」.

## 12. How the check reads this file

The localization check parses the tables of § 3–8 by their `en` column and language headers. For each language it
looks for the glossary value in the strings whose en value holds the en term, and reports a key that uses
another word. Cells with "/" list alternatives in order; cells with "…" hold a number slot. Rows marked **(S)**
fail the check; other rows warn.

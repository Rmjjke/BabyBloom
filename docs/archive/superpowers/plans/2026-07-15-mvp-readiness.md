# BabyBloom MVP Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Довести BabyBloom v1.0 до состояния MVP: закоммитить незакоммиченный слой, починить найденные аудитом баги, включить CloudKit-синк, оживить виджет, убрать мёртвый код и дубли.

**Architecture:** Чистый SwiftUI + SwiftData без view-моделей (сохраняем текущий подход). Три параллельных workstream'а по непересекающимся файлам: (A) модели/инфраструктура, (B) сервисы/монетизация, (C) UI-слой. Контракты между workstream'ами зафиксированы в блоках Interfaces.

**Tech Stack:** Swift 6, SwiftUI, SwiftData (+CloudKit), StoreKit 2, UserNotifications, WidgetKit, XcodeGen, XCTest.

## Global Constraints

- iOS 17.0+, Swift 6.0, Xcode 16 (из project.yml — не менять).
- Проект генерируется XcodeGen: после изменения project.yml всегда `xcodegen generate`.
- Все пользовательские строки — только через ключи в `en.json`/`ru.json` и `.l`. Новые ключи добавлять в ОБА файла (сейчас наборы идентичны — 312 ключей, сохранить паритет).
- Bundle IDs: app `com.babybloom.app`, widget `com.babybloom.app.widget`. App Group: `group.com.babybloom.app`. iCloud container: `iCloud.com.babybloom.app`.
- Проверка после каждой задачи: `xcodebuild -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'generic/platform=iOS Simulator' build` → BUILD SUCCEEDED.
- Тесты: `xcodebuild test -project BabyBloom.xcodeproj -scheme BabyBloom -destination 'platform=iOS Simulator,name=iPhone 16'`.
- НЕ делать: App Store-релизную подготовку (PrivacyInfo.xcprivacy, DEVELOPMENT_TEAM, скриншоты) — отдельный план после MVP.
- Коммитить после каждой задачи. Сообщения на английском, `feat:`/`fix:`/`refactor:`/`test:`/`docs:`.

---

## Phase 0 — Baseline commits (выполняет тимлид ДО параллельной работы)

### Task 0: Закоммитить текущий незакоммиченный пласт

**Files:** всё из `git status` (Modify + Untracked).

- [ ] **Step 1:** Добавить `.DS_Store` в `.gitignore` (строки `.DS_Store` и `**/.DS_Store`), `git rm --cached .DS_Store BabyBloom/.DS_Store`.
- [ ] **Step 2:** Коммит 1 — notifications: `git add BabyBloom/Services/NotificationManager.swift NOTIFICATIONS.md NOTIFICATIONS_DESIGN.md BabyBloom/App/BabyBloomApp.swift BabyBloom/Resources/Localization/ BabyBloom/Resources/Info.plist` + изменённые вьюхи с вызовами NotificationManager (`Features/Feeding Features/Sleep Features/Diaper Features/Growth Features/Dashboard`); `git commit -m "feat: local notification system with age-based schedules"`.
- [ ] **Step 3:** Коммит 2 — premium/export/profile: `git add BabyBloom/Services/SubscriptionManager.swift BabyBloom/Features/Premium BabyBloom/Features/Export BabyBloom/Features/Profile BabyBloom/App/MainTabView.swift BabyBloom/Features/Onboarding BabyBloom/DesignSystem BabyBloom.xcodeproj project.yml`; `git commit -m "feat: StoreKit 2 subscriptions, paywall, data export, profile editing"`.
- [ ] **Step 4:** `git status` чистый (кроме docs/), сборка зелёная.

---

## Workstream A — «Data & Sync» (Агент 1, Opus 4.8, worktree `ws-a-data-sync`)

Владеет: `BabyBloom/Core/Models/*`, `BabyBloom/App/BabyBloomApp.swift`, `project.yml`, `BabyBloomWidget/*`. НЕ трогает Features/ и Services/.

### Task A1: CloudKit-совместимые модели

**Files:**
- Modify: `BabyBloom/Core/Models/Baby.swift`, `FeedingEntry.swift`, `SleepEntry.swift`, `DiaperEntry.swift`, `GrowthEntry.swift`, `CustomEvent.swift`

**Interfaces:**
- Produces: у каждой entry-модели появляется `var baby: Baby?`; инварианты init не меняются (параметры init прежние).

Требования CloudKit для SwiftData: каждый атрибут — с дефолтом или optional; каждая связь — optional с inverse; без `.unique` (уже нет).

- [ ] **Step 1:** В каждой модели дать дефолты всем неопциональным свойствам. Шаблон для Baby:

```swift
var id: UUID = UUID()
var name: String = ""
var birthDate: Date = Date()
var gender: Gender = .female
var feedingType: FeedingType = .breast
var createdAt: Date = Date()
```

Аналогично: `FeedingEntry` (`id`, `startTime = Date()`, `type = .breast`, `createdAt = Date()`), `SleepEntry`, `DiaperEntry`, `GrowthEntry`, `CustomEvent` — дефолты по типам полей (Date → `Date()`, enum → первый кейс, числа → `0`). Существующие `init(...)` оставить как есть.

- [ ] **Step 2:** Inverse-связи. В каждую entry-модель добавить `var baby: Baby?`. В `Baby.swift:16-20` связать:

```swift
@Relationship(deleteRule: .cascade, inverse: \FeedingEntry.baby) var feedingEntries: [FeedingEntry]? = []
@Relationship(deleteRule: .cascade, inverse: \SleepEntry.baby) var sleepEntries: [SleepEntry]? = []
@Relationship(deleteRule: .cascade, inverse: \DiaperEntry.baby) var diaperEntries: [DiaperEntry]? = []
@Relationship(deleteRule: .cascade, inverse: \GrowthEntry.baby) var growthEntries: [GrowthEntry]? = []
@Relationship(deleteRule: .cascade, inverse: \CustomEvent.baby) var customEvents: [CustomEvent]? = []
```

Проверить grep'ом использования `baby.feedingEntries` и т.п. по Features/ — при optional-массивах добавить `?? []` по месту (таких мест мало; если находятся в файлах Workstream C — НЕ править чужой файл, а записать в `docs/superpowers/plans/ws-a-handoff.md` списком для тимлида).

- [ ] **Step 3:** Сборка + существующие тесты зелёные. Коммит `refactor: make SwiftData models CloudKit-compatible (defaults + inverse relationships)`.

### Task A2: App Group + CloudKit entitlements + shared container

**Files:**
- Modify: `project.yml`, `BabyBloom/App/BabyBloomApp.swift:13-28`

- [ ] **Step 1:** В `project.yml` УДАЛИТЬ мёртвый блок `capabilities:` (XcodeGen его игнорирует — подтверждено генерацией) и добавить обоим таргетам:

```yaml
    entitlements:
      path: BabyBloom/Resources/BabyBloom.entitlements   # для виджета: BabyBloomWidget/BabyBloomWidget.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.babybloom.app
        com.apple.developer.icloud-container-identifiers:
          - iCloud.com.babybloom.app
        com.apple.developer.icloud-services:
          - CloudKit
```

(виджету достаточно application-groups; iCloud-ключи — только основному таргету).

- [ ] **Step 2:** В `BabyBloomApp.swift` заменить конфигурацию:

```swift
let config = ModelConfiguration(schema: schema,
                                groupContainer: .identifier("group.com.babybloom.app"),
                                cloudKitDatabase: .automatic)
```

Пользователей в проде нет — миграция старого локального стора не нужна.

- [ ] **Step 3:** `xcodegen generate`, сборка. Проверить, что в pbxproj появились `CODE_SIGN_ENTITLEMENTS`. Коммит `feat: App Group shared container + CloudKit sync enabled`.

### Task A3: Виджет с реальными данными

**Files:**
- Modify: `project.yml` (sources виджета), `BabyBloomWidget/BabyBloomWidget.swift`

- [ ] **Step 1:** В `project.yml` таргету `BabyBloomWidget` добавить в sources модели: `- path: BabyBloom/Core/Models`. Модели тянут `LocalizationManager` (через `.l` в `Int.ageWord`) — добавить также `- path: BabyBloom/Core/Localization` и ресурс `- path: BabyBloom/Resources/Localization` в виджет-таргет.
- [ ] **Step 2:** В `BabyBloomProvider.getTimeline` открыть общий контейнер и читать реальные данные:

```swift
@MainActor private func fetchEntry() -> BabyBloomEntry {
    let schema = Schema([Baby.self, FeedingEntry.self, SleepEntry.self,
                         DiaperEntry.self, GrowthEntry.self, CustomEvent.self])
    let config = ModelConfiguration(schema: schema,
                                    groupContainer: .identifier("group.com.babybloom.app"),
                                    cloudKitDatabase: .automatic)
    guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
        return placeholderEntry()
    }
    let ctx = container.mainContext
    let baby = (try? ctx.fetch(FetchDescriptor<Baby>(sortBy: [SortDescriptor(\.createdAt)])))?.first
    var fd = FetchDescriptor<FeedingEntry>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
    fd.fetchLimit = 50
    let feedings = (try? ctx.fetch(fd)) ?? []
    let todayCount = feedings.filter { Calendar.current.isDateInToday($0.startTime) }.count
    let sd = FetchDescriptor<SleepEntry>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
    let lastSleep = (try? ctx.fetch(sd))?.first
    return BabyBloomEntry(date: Date(),
                          babyName: baby?.name ?? "Baby",
                          lastFeedingTime: feedings.first?.startTime,
                          lastSleepDuration: lastSleep.map { format($0.duration) },
                          todayFeedingCount: todayCount,
                          isAsleep: lastSleep?.isActive ?? false)
}
```

Timeline: одна entry, `policy: .after(Date().addingTimeInterval(15 * 60))`.

- [ ] **Step 3:** Сборка обоих таргетов. Коммит `feat: widget reads live data via shared App Group container`.

### Task A4: Честные перцентили и локализация единиц в GrowthEntry

**Files:**
- Modify: `BabyBloom/Core/Models/GrowthEntry.swift`
- Modify: `BabyBloom/Resources/Localization/en.json`, `ru.json` (ключи `unit.kg`, `unit.g`, `unit.cm`, `percentile.below3`, `percentile.3_15`, `percentile.15_50`, `percentile.50_85`, `percentile.85_97`, `percentile.above97`)
- Test: `BabyBloomTests/BabyBloomTests.swift` (правки `testGrowthEntryFormatting`, `testWHOPercentile*`)

- [ ] **Step 1:** Заменить линейную псевдоформулу (`GrowthEntry.swift:66`) на z-score через WHO LMS-упрощение: таблица медиан и SD по месяцам 0–24 (weight-for-age boys/girls, WHO 2006; SD ≈ (P97−P3)/3.88). Перцентиль из z через нормальную CDF-аппроксимацию:

```swift
static func percentile(value: Double, median: Double, sd: Double) -> Int {
    let z = (value - median) / sd
    let p = 0.5 * (1 + erf(z / 2.0.squareRoot()))
    return max(1, min(99, Int((p * 100).rounded())))
}
```

Таблицу расширить до 24 мес.; для возраста > 24 мес. возвращать перцентиль по 24 мес. с пометкой (не молча).

- [ ] **Step 2:** Синхронизировать бэнды `percentileLabel` и `percentileColor` (одинаковые границы 3/15/50/85/97), label — через ключи локализации вместо хардкода `"< 3-й"` (`GrowthEntry.swift:72-77`).
- [ ] **Step 3:** `weightFormatted/heightFormatted/headFormatted` (`GrowthEntry.swift:31-46`) — единицы через `"unit.kg".l` и т.д. вместо хардкода «кг/см/г».
- [ ] **Step 4:** Обновить тесты: `testGrowthEntryFormatting` — зафиксировать язык `LocalizationManager.shared.setLanguage("ru")` в `setUp`; `testWHOPercentileNormal` оставить (медианный вес → 40–70 диапазон должен проходить), добавить `testWHOPercentileAt18Months` (проверка, что после 12 мес. перцентиль не деградирует). Прогнать тесты. Коммит `fix: WHO percentiles via z-score, bands sync, localized units`.

---

## Workstream B — «Services & Monetization» (Агент 2, Opus 4.8, worktree `ws-b-services`)

Владеет: `BabyBloom/Services/*`, `BabyBloom/Core/Services/*`, `Features/Premium/*`, `Features/Export/*`, `BabyBloomTests/*`, `NOTIFICATIONS*.md`. НЕ трогает Features/ вьюхи трекинга и Core/Models.

### Task B1: Убить мёртвый NotificationService, перенести полезное

**Files:**
- Delete: `BabyBloom/Core/Services/NotificationService.swift`
- Modify: `BabyBloom/Services/NotificationManager.swift`
- Test: `BabyBloomTests/BabyBloomTests.swift:41-57`

**Interfaces:**
- Produces: `NotificationManager.calculateAverageIntervalMinutes(times: [Date]) -> Double` (внутренний, testable); smart-интервал кормления.

- [ ] **Step 1:** Перенести в `NotificationManager` из мёртвого сервиса: `calculateAverageIntervalMinutes(times:)` (логика 1:1 — последние 7, отбрасывание пауз >8 ч, дефолт 120 мин) как `internal` метод.
- [ ] **Step 2:** Умный интервал: `onFeedingSaved` получает новый параметр `recentFeedingTimes: [Date]` (даты последних ≤7 кормлений, передаёт вьюха). Если ≥3 записей — интервал = `calculateAverageIntervalMinutes * 60 + 10*60` (буфер), иначе fallback на возрастную таблицу `feedingInterval(ageMonths:)`. Сигнатура: `func onFeedingSaved(ageMonths: Int, babyName: String, isActiveBF: Bool, recentFeedingTimes: [Date] = [])` — дефолт пустой, чтобы существующие вызовы компилировались.
- [ ] **Step 3:** В `post()` добавить `content.interruptionLevel = .timeSensitive` для `feedingActiveBF` и `sleepActive` (передавать флагом).
- [ ] **Step 4:** Удалить `NotificationService.swift`. Переписать тесты `testAverageIntervalCalculation`/`testAverageIntervalWithSingleEntry` на `NotificationManager.shared` (убрать async/await — метод синхронный). Тесты зелёные. Коммит `refactor: remove dead NotificationService, add smart feeding intervals to NotificationManager`.

### Task B2: Дыры NotificationManager

**Files:**
- Modify: `BabyBloom/Services/NotificationManager.swift`
- Test: новый `BabyBloomTests/NotificationManagerTests.swift`

**Interfaces:**
- Produces (для Workstream C): 
  - `func onFeedingDeleted(remainingActive: Bool)` — отменяет `feedingReminder` и, если активных ГВ не осталось, `feedingActiveBF`
  - `func onSleepDeleted(remainingActive: Bool)` — отменяет `sleepActive`/`sleepWakeWindow` если активных не осталось
  - `func onDiaperDeleted()` — отменяет `diaperReminder`
  - `func onSleepEnded(ageMonths: Int, endedAt: Date)` — wake-window от `endedAt`, не от «сейчас»

- [ ] **Step 1:** Добавить три публичных delete-метода (выше) на базе приватного `cancel(_:)`.
- [ ] **Step 2:** Починить `scheduleDiaperReminderIfNeeded` (`:145-152`) — мёртвая ветка: флаги `kFirstFeeding/kFirstSleep` выставляются ДО вызова, условие `!alreadyActive` всегда false. Исправление: передавать `isFirstActivation: Bool` из call-site (`onFeedingSaved:64`, `onSleepStarted:104` уже знают `isFirst`) и планировать при нём.
- [ ] **Step 3:** `onSleepEnded(ageMonths:endedAt:)`: интервал = `wakeWindow - Date().timeIntervalSince(endedAt)`; если ≤ 0 — не планировать. Старую сигнатуру удалить (call-sites обновит Workstream C; в СВОЁМ worktree обновить только компилируемость — оставить deprecated-обёртку `onSleepEnded(ageMonths:)` вызывающую новую с `endedAt: Date()`).
- [ ] **Step 4:** Weekly summary: убрать гейт `kWeeklyScheduled` из `scheduleWeeklySummary` пути «разрешение выдано позже» — вызывать `scheduleWeeklySummary()` также из `onAppForegrounded()` (идемпотентно: сам ставит по фикс. ID, `cancel` перед `add`; флаг оставить лишь как оптимизацию, сбрасывать не нужно, просто удалить `guard`).
- [ ] **Step 5:** Тесты (через `UNUserNotificationCenter` мокать нельзя без DI — тестировать чистые функции): `testFeedingIntervalNilAt12Months`, `testWakeWindowTable`, `testDiaperIntervalTable`, `testSmartIntervalPreferredOverTable`, `testSmartIntervalFallbackUnder3Feedings`. Сделать интервальные функции `internal` для `@testable`. Коммит `fix: notification cancellation on delete, diaper activation, wake-window from real end time`.

### Task B3: StoreKit UX

**Files:**
- Modify: `BabyBloom/Services/SubscriptionManager.swift`, `BabyBloom/Features/Premium/PaywallView.swift`
- Modify: `en.json`/`ru.json` — ключи `premium.pending_message`, `premium.error_verification`, `premium.error_load`, `premium.retry`

- [ ] **Step 1:** `.pending` (`SubscriptionManager.swift:71-72`): добавить `private(set) var purchasePending = false`, ставить в true; PaywallView показывает `premium.pending_message` («Покупка ожидает подтверждения…»).
- [ ] **Step 2:** `SubscriptionError.errorDescription` → `"premium.error_verification".l`; ошибки `loadProducts` показывать как `premium.error_load` + кнопка `premium.retry`, вызывающая `store.loadProducts()` повторно (`PaywallView` при `purchaseError != nil && monthlyProduct == nil`).
- [ ] **Step 3:** `selectedID` fallback (`PaywallView.swift:10`): в `.task` после `loadProducts()` — если `yearlyProduct == nil && monthlyProduct != nil`, переключить `selectedID = SubscriptionManager.monthlyID`.
- [ ] **Step 4:** Заменить `Task.detached` на `Task` в `listenForTransactions` (`SubscriptionManager.swift:115`). Градиент `Color(hex:)` в `PaywallView.swift:81` → `BBTheme` (добавить `BBTheme.Colors.premiumGradient`). Сборка, коммит `fix: paywall pending state, localized errors, product fallback`.

### Task B4: ExportGenerator корректность

**Files:**
- Modify: `BabyBloom/Features/Export/ExportGenerator.swift`, `ExportView.swift`
- Test: новый `BabyBloomTests/ExportGeneratorTests.swift`

- [ ] **Step 1:** CSV-локализация: значения через `displayName.l` (как в PDF), заголовки колонок через новые ключи `export.csv.date`, `export.csv.type` и т.д. (добавить в оба json).
- [ ] **Step 2:** Правильное CSV-экранирование — одна функция на все поля:

```swift
private func csvField(_ raw: String) -> String {
    if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
        return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return raw
}
```

- [ ] **Step 3:** HTML-экранирование в PDF (`tableSection:336-347`, `babyName:321`): `&`→`&amp;`, `<`→`&lt;`, `>`→`&gt;` для всех пользовательских значений.
- [ ] **Step 4:** `avgFeedPerDay` для `.all` (`:182-186`): вместо `?? 30` считать `days` от самой ранней записи: `max(1, Calendar.current.dateComponents([.day], from: earliest, to: Date()).day ?? 1)`.
- [ ] **Step 5:** Чистка temp-файлов: перед записью `try? FileManager.default.removeItem(...)` старых экспортов (или писать в подпапку `exports/` и чистить её), при ошибке записи возвращать nil и показывать алерт (не URL на несуществующий файл). Пер-категорийная проверка пустоты в `ExportView`: дизейблить категорию с 0 записей в выбранном диапазоне.
- [ ] **Step 6:** Тесты: `testCSVEscapesQuotesAndCommas`, `testCSVUsesLocalizedValues`, `testAvgPerDayForAllRangeUsesEarliestEntry`. Коммит `fix: export CSV localization/escaping, HTML escaping, avg-per-day for all-time range`.

### Task B5: Документация уведомлений

**Files:**
- Delete: `NOTIFICATIONS_DESIGN.md`
- Rewrite: `NOTIFICATIONS.md`

- [ ] **Step 1:** Переписать `NOTIFICATIONS.md` по факту кода ПОСЛЕ задач B1–B2: реальные ID (`bb.feeding.active.bf`, `bb.sleep.wake_window`…), age-based таблицы интервалов, smart-интервал, активационные гейты, delete-отмены. Удалить `NOTIFICATIONS_DESIGN.md` (устарел, противоречит сам себе). Коммит `docs: rewrite NOTIFICATIONS.md to match implementation, drop stale design doc`.

---

## Workstream C — «UI & UX» (Агент 3, Opus 4.8, worktree `ws-c-ui`)

Владеет: `Features/Dashboard|Feeding|Sleep|Diaper|Growth|Events|Onboarding/*` (вьюхи), `DesignSystem/*`. НЕ трогает Core/Models, Services/, Premium/, Export/.

### Task C1: Честная статистика (активные таймеры)

**Files:**
- Modify: `Features/Sleep/SleepView.swift:21-23`, `Features/Feeding/FeedingView.swift:147-158`, `Features/Dashboard/DashboardView.swift:32-34`

- [ ] **Step 1:** Во всех today-тоталах исключить активные записи: `todayEntries.filter { !$0.isActive }` перед суммированием `duration` (сон: SleepView/Dashboard; кормление-минуты: FeedingView).
- [ ] **Step 2:** Недельный график кормлений (`FeedingView.swift:158`) — добавить `&& !$0.isActive` (как уже сделано у сна `SleepView.swift:151`).
- [ ] **Step 3:** Сборка, визуальная проверка не требуется. Коммит `fix: exclude active timers from daily totals and weekly feeding chart`.

### Task C2: Dashboard recentEvents + двойные вычисления

**Files:**
- Modify: `Features/Dashboard/DashboardView.swift:44-56,245,257-259`
- Modify: `FeedingView.swift:171,180`, `SleepView.swift:167,176`, `DiaperView.swift:179,188`

- [ ] **Step 1:** `recentEvents`: убрать `prefix(3)` по типам — собрать все события с датой, отсортировать, взять `prefix(6)`. Убрать `AnyView`: сделать `enum RecentEvent: Identifiable` с кейсами по типам и `switch` в `ForEach` (стабильный `id` = id записи). Вычислять один раз: `let events = recentEvents` в `body` (или локально в секции), не дважды.
- [ ] **Step 2:** В трёх вьюхах истории — `let filtered = filteredEntries` один раз в секции вместо повторного вызова в `.isEmpty` и `ForEach`.
- [ ] **Step 3:** Сборка. Коммит `fix: dashboard recent events show true latest 6, remove duplicate computed passes`.

### Task C3: Отмена уведомлений при удалении записей

**Files:**
- Modify: `FeedingView.swift:216-224`, `SleepView.swift:214-222`, `DiaperView.swift:212-220`, `DashboardView.swift:268-270`, `SleepView.swift:360-366` (AddSleepSheet)

**Interfaces:**
- Consumes (контракт Workstream B, Task B2 — сигнатуры зафиксированы, компилировать после merge B; в worktree C до merge — писать вызовы по контракту): `onFeedingDeleted(remainingActive: Bool)`, `onSleepDeleted(remainingActive: Bool)`, `onDiaperDeleted()`, `onSleepEnded(ageMonths: Int, endedAt: Date)`.

- [ ] **Step 1:** Во всех delete/deleteFiltered путях после `modelContext.delete` вызвать соответствующий `on*Deleted` (`remainingActive` = остались ли активные записи после удаления).
- [ ] **Step 2:** `AddSleepSheet.save` — вызывать `onSleepEnded(ageMonths:, endedAt: endTime)` с фактическим временем окончания.
- [ ] **Step 3:** Задача компилируется только после merge с Workstream B — пометить коммит и оставить в конце очереди ветки. Коммит `fix: cancel scheduled notifications when entries are deleted`.

### Task C4: Дедупликация UI-компонентов

**Files:**
- Create: `DesignSystem/Components/BBHistorySection.swift`, `DesignSystem/Components/BBMeasureSlider.swift`, `DesignSystem/Components/BBElapsedTimer.swift`, `DesignSystem/Components/RoundedCorner.swift`
- Modify: `FeedingView.swift`, `SleepView.swift`, `DiaperView.swift`, `GrowthView.swift:468-496,401-443`, `OnboardingView.swift:581-609,533-571,926-943`, `DashboardView.swift:274-320`

- [ ] **Step 1:** `BBHistorySection<Entry: PersistentModel, Row: View>` — generic: пикер `HistoryFilter`, empty-state, `ForEach` + swipe-delete + delete-all кнопка; параметры: entries, dateKeyPath, row-builder, onDelete. Внедрить в Feeding/Sleep/Diaper.
- [ ] **Step 2:** `BBMeasureSlider` — вынести идентичные `measureSlider` (GrowthView) / `growthSlider` (Onboarding), внедрить в оба места. Блок «обхват головы (опц.)» — общий `BBOptionalMeasureToggle`.
- [ ] **Step 3:** `BBElapsedTimer` — вью с `Timer.publish(every: 1)` и форматированием, внедрить в три таймер-карточки (Dashboard/Feeding/Sleep).
- [ ] **Step 4:** `RoundedCorner` + `cornerRadius(_:corners:)` из Onboarding → DesignSystem.
- [ ] **Step 5:** Убрать хак-парсинг `"form.notes_optional"` (`GrowthView.swift:408-412`) — отдельный ключ `form.head_optional_hint` в оба json. Сборка, коммит `refactor: extract BBHistorySection, BBMeasureSlider, BBElapsedTimer, RoundedCorner into DesignSystem`.

### Task C5: Распил OnboardingView (943 строки)

**Files:**
- Create: `Features/Onboarding/Pages/WelcomePage.swift`, `NamePage.swift`, `BirthPage.swift`, `FeedingPage.swift`, `GrowthPage.swift`, `FactPage.swift`, `GeneratingPage.swift`, `PremiumPage.swift`
- Modify: `Features/Onboarding/OnboardingView.swift` (остаётся ~135 строк: state, body, progressBar, bottomNav, next/back, createAndFinish)

- [ ] **Step 1:** Перенести страницы по карте выше (строки исходника: Welcome 142-289, Name 293-336, Birth 340-409, Feeding 413-482, Growth 486-610, Fact 614-688, Generating 692-785, Premium 789-904; backButton 908-923 → OnboardingHelpers.swift). `private` → internal.
- [ ] **Step 2:** Починить хрупкий `GeneratingPage:731` — заменить `replacingOccurrences(of: "…")` на отдельный ключ `onboarding.gen.title_named` со `%@`: `String(format: "onboarding.gen.title_named".l, name)` (ключ в оба json).
- [ ] **Step 3:** Ввести `enum OnboardingStep: Int, CaseIterable` вместо магических индексов `page` в `switch :43-57`. Сборка после каждого переноса. Коммит `refactor: split OnboardingView into page files, typed steps`.

### Task C6: Единый фолбэк имени + пустые @Query-предикаты

**Files:**
- Modify: `FeedingView.swift:201-202,469`, `SleepView.swift:203`, `DiaperView.swift:208,425` (хардкод `"Baby"` → `"baby.default_name".l`)
- Modify: `DashboardView.swift:5-9` (минимум: оставить как есть, если предикаты по дате нетривиальны — НЕ переусложнять; допустимо ограничиться `.sorted` + `fetchLimit`-подходом только там, где просто)

- [ ] **Step 1:** Заменить все `?? "Baby"` на `?? "baby.default_name".l`.
- [ ] **Step 2 (опционально, если быстро):** Dashboard `@Query` с `#Predicate` по сегодняшней дате для diapers/feedings. Если предикаты со SwiftData капризничают — пропустить, записать в handoff. Коммит `fix: localized default baby name fallback`.

---

## Phase 2 — Интеграция (тимлид, после завершения A/B/C)

- [ ] **Step 1:** Merge порядок: A → B → C (C зависит от контрактов B). Конфликты ожидаемы только в json-локализациях (все три добавляют ключи) и project.pbxproj (перегенерировать: `xcodegen generate`).
- [ ] **Step 2:** Полная сборка + все тесты.
- [ ] **Step 3:** Запуск на симуляторе (skill ios-debugger-agent): онбординг → кормление → сон → удаление записи → экспорт → paywall. Проверить CloudKit-контейнер не падает без iCloud-аккаунта симулятора.
- [ ] **Step 4:** /code-review диффа, применить критичные находки.
- [ ] **Step 5:** Финальный коммит + обновить README (виджет и CloudKit теперь правда).

## Вне охвата (следующий план — релиз)

PrivacyInfo.xcprivacy (блокер ревью Apple), DEVELOPMENT_TEAM, StoreKit .storekit-конфиг для тестов покупок, скриншоты/метаданные App Store, полный WHO LMS-датасет (сейчас — упрощённый z-score).

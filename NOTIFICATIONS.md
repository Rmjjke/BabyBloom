# Bitty — Локальные уведомления

Все уведомления — локальные (`UNUserNotificationCenter`, без сервера).
Единственный источник истины: `BabyBloom/Services/NotificationManager.swift`
(`NotificationManager.shared`, singleton).

Этот документ описывает фактическую реализацию. Любое значение ниже прослеживается
до строки кода в `NotificationManager.swift`.

---

## 1. Идентификаторы уведомлений

Все ID заданы в `enum NID` внутри `NotificationManager`.

| ID | Тип | Тип триггера | Time-sensitive |
|---|---|---|---|
| `bb.feeding.reminder` | Напоминание о кормлении | interval, one-shot | нет |
| `bb.feeding.active.bf` | Долгая активная сессия ГВ | interval (40 мин), one-shot | **да** |
| `bb.sleep.wake_window` | Конец «окна бодрствования» после сна | interval, one-shot | нет |
| `bb.sleep.active` | Активный таймер сна ещё идёт | interval, one-shot | **да** |
| `bb.diaper.reminder` | Напоминание о подгузнике | interval, one-shot | нет |
| `bb.engage.measurements` | Разовый промпт «добавь измерения» | interval (3 дня), one-shot | нет |
| `bb.engage.monthly_growth` | Ежемесячное измерение роста | calendar, повтор | нет |
| `bb.engage.weekly_summary` | Итоги недели | calendar, повтор | нет |
| `bb.engage.idle` | Нет записей 2 дня | interval (48 ч), one-shot | нет |

Каждый ID планируется через `cancel(_:)` перед `post(...)` (или `add`), поэтому в очереди
всегда не более одного экземпляра каждого ID — повторное планирование заменяет предыдущее.

Time-sensitive уведомления (`bb.feeding.active.bf`, `bb.sleep.active`) ставят
`content.interruptionLevel = .timeSensitive`, чтобы пробиваться сквозь Focus/«Не беспокоить».

---

## 2. Возрастные таблицы интервалов

Возраст (`ageMonths`) передаётся вызывающей стороной. `nil` = уведомление для этой
возрастной группы не планируется.

### 2.1 Кормление — `feedingInterval(ageMonths:)`
| Возраст (мес.) | Интервал |
|---|---|
| 0 | 2.5 ч |
| 1–2 | 3.0 ч |
| 3–5 | 3.5 ч |
| 6–8 | 4.0 ч |
| 9–11 | 4.5 ч |
| 12+ | — (не планируется, кормление ведёт родитель) |

### 2.2 Окно бодрствования после сна — `wakeWindow(ageMonths:)`
| Возраст (мес.) | Окно |
|---|---|
| 0 | 1.0 ч |
| 1–2 | 1.5 ч |
| 3–5 | 2.0 ч |
| 6–7 | 2.5 ч |
| 8–11 | 3.0 ч |
| 12–17 | 4.0 ч |
| 18+ | — |

### 2.3 Подгузник — `diaperInterval(ageMonths:)`
| Возраст (мес.) | Интервал |
|---|---|
| 0 | 4 ч |
| 1–5 | 6 ч |
| 6–11 | 8 ч |
| 12+ | — |

### 2.4 Активный таймер сна — `activeSleepInterval(isNight:ageMonths:)`
| Условие | Интервал |
|---|---|
| Ночной сон (`isNight == true`) | 9 ч |
| Дневной сон, возраст ≤ 2 мес. | 2.5 ч |
| Дневной сон, возраст > 2 мес. | 2.0 ч |

---

## 3. Умный интервал кормления

`feedingReminderInterval(ageMonths:recentFeedingTimes:)` выбирает интервал для
`bb.feeding.reminder`:

- **≥ 3 недавних кормления** переданы → используется наблюдаемое среднее:
  `calculateAverageIntervalMinutes(times:) * 60 + 10 мин` (буфер +10 минут).
- **< 3** → откат на возрастную таблицу `feedingInterval(ageMonths:)`.

`calculateAverageIntervalMinutes(times:)`:
- берёт последние 7 записей (`suffix(7)`);
- игнорирует промежутки ≤ 0 и ≥ 480 мин (8 ч) как выбросы;
- при < 2 записей или отсутствии пригодных промежутков возвращает 120 мин (2 ч) по умолчанию.

`recentFeedingTimes` — параметр `onFeedingSaved(...)` со значением по умолчанию `[]`,
поэтому без данных о недавних кормлениях поведение автоматически откатывается на таблицу.

Текст напоминания **не** подстраивается под интервал — это фиксированные строки
`notification.feeding_title` / `notification.feeding_body`; изменяется только момент срабатывания.

> `onFeedingTimerStopped(ageMonths:)` перепланирует `bb.feeding.reminder` по «сырой»
> возрастной таблице `feedingInterval(...)`, а **не** по умному интервалу (у него нет
> списка недавних кормлений).

---

## 4. События и планирование

### Кормление — `onFeedingSaved(ageMonths:babyName:isActiveBF:recentFeedingTimes:)`
1. Сохраняет имя ребёнка (`bb.storedBabyName`).
2. Если это **первое** кормление (флаг `hasLoggedFirstFeeding` ещё не стоял):
   ставит флаг, планирует `bb.engage.measurements`, активирует напоминания о подгузнике
   (см. §5, гейт первой активации).
3. Перепланирует `bb.feeding.reminder` от «сейчас» через умный/возрастной интервал (§3).
4. Если `isActiveBF == true` — планирует `bb.feeding.active.bf` через 40 мин (time-sensitive).

### Остановка таймера ГВ — `onFeedingTimerStopped(ageMonths:)`
Отменяет `bb.feeding.active.bf` и `bb.feeding.reminder`, затем перепланирует
`bb.feeding.reminder` по возрастной таблице.

### Начало сна — `onSleepStarted(ageMonths:babyName:isNight:)`
1. Сохраняет имя. 2. Первый сон → ставит `hasLoggedFirstSleep`, активирует напоминания о подгузнике.
3. Отменяет `bb.sleep.wake_window` и `bb.sleep.active`, планирует `bb.sleep.active`
   через `activeSleepInterval` (§2.4, time-sensitive).

### Конец сна — `onSleepEnded(ageMonths:endedAt:)`
Отменяет `bb.sleep.active` и `bb.sleep.wake_window`. Планирует `bb.sleep.wake_window`
относительно **`endedAt`**, а не «сейчас»:
`remaining = wakeWindow(ageMonths) − now.timeIntervalSince(endedAt)`.
Если `remaining ≤ 0` (сон внесён задним числом, окно уже прошло) — ничего не планируется.

> `onSleepEnded(ageMonths:)` — устаревшая обёртка (`@available(*, deprecated)`), которая
> подставляет `endedAt = Date()`. Оставлена, чтобы существующие вызовы компилировались до
> перевода на точное время в рамках Workstream C.

### Подгузник — `onDiaperSaved(ageMonths:babyName:)`
Сохраняет имя и перепланирует `bb.diaper.reminder` через `diaperInterval` (§2.3).

### Первое измерение роста — `onFirstGrowthEntrySaved()`
Отменяет `bb.engage.measurements`, ставит `hasFirstGrowthEntry`, планирует
повторяющееся `bb.engage.monthly_growth`.

---

## 5. Гейты активации

- **Первое кормление / первый сон** определяются по инверсии флагов
  `hasLoggedFirstFeeding` / `hasLoggedFirstSleep` **до** их установки.
- **Напоминания о подгузнике** запускаются один раз — при первой активации кормления
  **или** сна. Флаги к моменту вызова `scheduleDiaperReminderIfNeeded(...)` уже установлены,
  поэтому «первичность» передаётся явным параметром `isFirstActivation`, а не перечитывается
  из `UserDefaults`.
- **Промпт измерений** (`bb.engage.measurements`) планируется только если
  `hasFirstGrowthEntry == false` (нет смысла просить измерения у того, кто их уже вносит).

---

## 6. Отмена при удалении записей (delete-cancellation)

Публичный API для вызова из view при удалении записи:

| Метод | Поведение |
|---|---|
| `onFeedingDeleted(remainingActive:)` | Всегда отменяет `bb.feeding.reminder`; `bb.feeding.active.bf` отменяется только если активной сессии ГВ не осталось (`remainingActive == false`). |
| `onSleepDeleted(remainingActive:)` | При `remainingActive == false` отменяет `bb.sleep.active` и `bb.sleep.wake_window`. |
| `onDiaperDeleted()` | Отменяет `bb.diaper.reminder`. |

Точки вызова: пути удаления во `FeedingView` / `SleepView` / `DiaperView`.

> **Статус интеграции.** Сам вызов delete-cancellation API из view и передача
> `recentFeedingTimes` в `onFeedingSaved(...)` выполняются в параллельном workstream (задача C3).
> Провязка на стороне view появится с мержем C-линии; в NotificationManager API уже готов.

---

## 7. Запрос разрешения

`requestPermission(completion:)` запрашивает `[.alert, .sound, .badge]`. При выдаче
разрешения сразу планирует `bb.engage.weekly_summary`. Необязательный `completion`
получает ответ пользователя **на главном акторе** — он нужен странице онбординга,
которая идёт дальше при любом ответе.

| Когда | Место в коде |
|---|---|
| На странице «Уведомления» в онбординге (стр. 7 из 10, перед Generating) — по тапу на CTA | `NotificationsPage.swift` → `NotificationManager.shared.requestPermission { _ in onContinue() }` |

Это единственная точка вызова во всём приложении. Раньше запрос уходил из
`BabyBloomApp.swift` по завершении онбординга, и системный диалог появлялся
поверх дашборда; этот вызов удалён.

`onAppForegrounded()` вызывается при переходе сцены в active (`scenePhase`, `BabyBloomApp.swift`)
и делает две вещи (см. §8).

---

## 8. Вовлекающие (engagement) уведомления

| ID | Расписание | Когда планируется | Разовое/повтор |
|---|---|---|---|
| `bb.engage.measurements` | через 3 дня | при первом кормлении, если `hasFirstGrowthEntry == false` | разовое |
| `bb.engage.monthly_growth` | 1-е число, 10:00, повтор (`UNCalendarNotificationTrigger`) | при `onFirstGrowthEntrySaved()` | повтор |
| `bb.engage.weekly_summary` | воскресенье (`weekday = 1`), 20:00, повтор | при выдаче разрешения и при `onAppForegrounded()` | повтор, идемпотентно |
| `bb.engage.idle` | через 48 ч | при `onAppForegrounded()`, если стоит `hasLoggedFirstFeeding` **или** `hasLoggedFirstSleep` | разовое |

Детали:
- **`scheduleWeeklySummary()` идемпотентно**: фиксированный ID + cancel-before-add, поэтому
  безопасно вызывать многократно. Планируется в `onAppForegrounded()` — чтобы пользователи,
  выдавшие разрешение уже после запуска, всё равно получали дайджест.
- **`bb.engage.idle`** использует сохранённое имя ребёнка (`storedBabyName`, дефолт `"Baby"`)
  в теле уведомления (`String(format:...)`).
- **`bb.engage.measurements`** и **`bb.engage.idle`** — форматируемые строки с именем ребёнка.

---

## 9. Ключи UserDefaults

Фактически используемые ключи (в `NotificationManager`):

| Ключ | Назначение |
|---|---|
| `hasLoggedFirstFeeding` | было ли хоть одно кормление (гейт первой активации) |
| `hasLoggedFirstSleep` | был ли хоть один сон (гейт первой активации) |
| `hasFirstGrowthEntry` | внесено ли первое измерение роста (гейт промпта измерений) |
| `hasScheduledWeeklySummary` | флаг «weekly summary запланирован» (ставится в `scheduleWeeklySummary()`) |
| `bb.storedBabyName` | сохранённое имя ребёнка для форматируемых текстов |

---

## 10. Тексты уведомлений (обе локали)

Все строки — через ключи в `en.json` / `ru.json` (`.l`). `%@` = имя ребёнка.

| Ключ | Русский | Английский |
|---|---|---|
| `notification.feeding_title` | Время кормления 🍼 | Feeding Time 🍼 |
| `notification.feeding_body` | Малыш давно не кормился… | Your baby hasn't fed in a while… |
| `notification.feeding_long_title` | Кормление идёт долго ⏱ | Long Feeding Session ⏱ |
| `notification.feeding_long_body` | Кормление продолжается уже 40 минут… | The feeding session has been going for 40 minutes… |
| `notification.sleep_title` | Пора поспать 😴 | Nap Time 😴 |
| `notification.sleep_body` | Малыш уже долго бодрствует… | Baby's been awake for a while… |
| `notification.sleep_active_title` | Малыш ещё спит? | Still sleeping? |
| `notification.sleep_active_body` | Не забудьте нажать «Проснулся»… | Don't forget to tap 'Woke Up'… |
| `notification.diaper_title` | Проверь подгузник 🩲 | Diaper check 🩲 |
| `notification.diaper_body` | Давно не было записей о подгузнике. Пора проверить %@? | No diaper logged in a while. Time to check on %@? |
| `notification.measurements_title` | Отслеживай рост %@ 📏 | Track %@'s growth 📏 |
| `notification.measurements_body` | Уже 3 дня ведёшь записи… | You've been logging for 3 days… |
| `notification.monthly_growth_title` | Ежемесячный контроль 📊 | Monthly check-up 📊 |
| `notification.monthly_growth_body` | Пора записать новые измерения… | Time to record new measurements… |
| `notification.weekly_title` | Итоги недели 📋 | Weekly recap 📋 |
| `notification.weekly_body` | Как прошла неделя… | See how feedings, sleep and diapers looked this week… |
| `notification.idle_title` | Всё в порядке? 👀 | Everything ok? 👀 |
| `notification.idle_body` | Уже 2 дня нет новых записей… %@ | You haven't logged anything in 2 days… %@ |

---

## 11. Технические детали

- `post(id:title:body:in:timeSensitive:)` — звук `.default`, триггер
  `UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)`
  (минимум 1 с, чтобы триггер был валиден), `interruptionLevel = .timeSensitive`
  при `timeSensitive == true`.
- `cancel(_:)` — `removePendingNotificationRequests(withIdentifiers:)` по одному ID.
- Повторяющиеся (`bb.engage.monthly_growth`, `bb.engage.weekly_summary`) собираются
  вручную через `UNCalendarNotificationTrigger(repeats: true)`.

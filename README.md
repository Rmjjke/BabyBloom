# 🌸 Bitty

> iOS-приложение для умного трекинга здоровья и развития новорождённого

[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-purple)](https://developer.apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange)](https://swift.org)
[![Status](https://img.shields.io/badge/Status-In%20Development-lavender)](https://github.com/Rmjjke/BabyBloom)

## О приложении

Bitty — интеллектуальный помощник для родителей новорождённых. Трекинг кормлений, сна, подгузников и роста ребёнка в едином приложении с персонализированными рекомендациями.

## Дорожная карта

| Версия | Фокус | Срок |
|--------|-------|------|
| **v1.0** | Базовый трекинг: кормление, сон, подгузники, рост/вес | Q3 2026 |
| v2.0 | AI-прикорм: введение продуктов, баланс питания | Q1 2027 |
| v3.0 | Здоровье: прививки, анализы, медицинский архив | Q3 2027 |

## Функциональность v1.0

### Трекинг
- **Кормление** — таймер (грудь/смесь/сцеженное), история, статистика 24ч/7 дней
- **Сон** — таймер одним касанием, визуальный timeline дня, суточная статистика
- **Подгузники** — тип, цветовая шкала стула, суточная норма по возрасту
- **Рост и вес** — перцентили ВОЗ, кривые роста, напоминания о взвешивании
- **События** — купание, прогулки, лекарства, настроение, кастомные категории

### Умные уведомления
- Напоминание о кормлении на основе средних интервалов последних 5-7 кормлений
- Сигнал «признаки усталости» по возрастной норме бодрствования
- Напоминание о подгузнике каждые 2-3 часа

### Dashboard
- Карточка «Следующее» — что нужно сделать прямо сейчас
- Виджеты быстрого ввода (1 касание)
- Прогресс-индикаторы: норма сна и кормлений за сутки

### Прочее
- iOS Home Screen Widgets (Small, Medium) через WidgetKit
- Тёмная тема — обязательна для ночных кормлений
- Universal App (iPhone + iPad)
- Офлайн-режим, синхронизация через SwiftData + CloudKit

## Дизайн-система

Femtech Wellness iOS — мягкие пастельные тона, округлые карточки, тёплый интерфейс.

| Элемент | Цвет |
|---------|------|
| Основной | Лавандово-фиолетовый `#6B5EA8` |
| Акцентный | Пудровый розовый `#E8A0BF` |
| Фоновый | Молочно-белый `#F7F3FF` |
| Успех | Мятный зелёный `#A8D5C2` |

## Технический стек

- **Language:** Swift 6.0
- **UI:** SwiftUI
- **Storage:** SwiftData (local) + CloudKit (sync)
- **Notifications:** UserNotifications / APNs
- **Widgets:** WidgetKit
- **Testing:** XCTest
- **Build:** XcodeGen

## Архитектура

```
BabyBloom/
├── App/                    # Entry point, navigation
├── Core/
│   ├── Models/             # SwiftData models (CloudKit-compatible): Baby, FeedingEntry...
│   └── Localization/       # JSON-based LocalizationManager (ru/en)
├── Services/               # NotificationManager, SubscriptionManager (StoreKit 2)
├── DesignSystem/
│   ├── BBTheme.swift       # Colors, spacing, typography, shadows
│   └── Components/         # BBButton, BBCard, BBCharts, BBHistorySection...
├── Features/
│   ├── Onboarding/         # 8-page onboarding (Pages/ + typed steps)
│   ├── Dashboard/          # Main screen
│   ├── Feeding/            # Feeding tracker + timer
│   ├── Sleep/              # Sleep tracker + timeline
│   ├── Diaper/             # Diaper tracker
│   ├── Growth/             # Growth charts + WHO percentiles (z-score, 0–24 mo)
│   ├── Events/             # Bath, walks, medication, mood
│   ├── Export/             # PDF/CSV export (premium)
│   ├── Premium/            # Paywall, subscriptions
│   └── Profile/            # Baby profile editing
BabyBloomWidget/            # WidgetKit extension (live data via App Group)
WidgetResources/            # Widget copies of localization JSONs (keep in sync!)
BabyBloomTests/             # Unit tests
```

Документация уведомлений: [NOTIFICATIONS.md](NOTIFICATIONS.md). План MVP-работ: [docs/superpowers/plans/](docs/superpowers/plans/).

## Запуск

1. Убедитесь что установлен Xcode 16+ и [`xcodegen`](https://github.com/yonaskolb/XcodeGen)
2. Клонируйте репозиторий
3. Сгенерируйте проект: `xcodegen generate`
4. Откройте `BabyBloom.xcodeproj`
5. Выберите симулятор (iOS 17+) и запустите

## Требования

- iOS 17.0+
- iPhone and iPad (Universal)
- Xcode 16+

---

*Bitty — потому что здоровье вашего ребёнка для нас как своё 🌸*

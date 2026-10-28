# TASK: Заменить чужие legal-ссылки на пейволле (блокер сабмита)

**Приоритет: критический — блокирует App Store submission. Правка на 2 строки.**

## Проблема

`BabyBloom/Features/Premium/PlanPickerSection.swift`, `footerLinks` (строки ~248-250):
кнопки Terms и Privacy ведут на `https://babybloom.app/terms` и `https://babybloom.app/privacy`.

`babybloom.app` — НЕ наш домен. Это живой сайт чужого продукта («BabyBloom · Watch your baby
bloom») с их собственными Terms of Service (проверено 2026-09-08, отвечает 200). Наш пейволл
предлагает юзеру согласиться с чужими юридическими документами. Это реджект по guideline 3.1.2
и юридическая дыра.

## Правка

```swift
Link("premium.terms".l,
     destination: URL(string: "https://bitty.okapps.org/bitty/terms")!)
Link("premium.privacy".l,
     destination: URL(string: "https://bitty.okapps.org/bitty/privacy")!)
```

Это наши задеплоенные страницы (Cloudflare Pages, оба URL отвечают 200, содержимое наше —
Privacy «данные в вашем iCloud, мы их не видим», Terms с медицинским дисклеймером и разделом
про подписки). В App Store Connect эти же URL уже стоят в Privacy Policy URL и в описаниях —
после правки приложение и стор станут консистентны.

## Проверить заодно

`grep -rn "babybloom.app" BabyBloom/` — на 2026-09-08 вхождения только в PlanPickerSection.swift,
но если после widget-redesign появились новые экраны с legal-ссылками — заменить и там.

## После правки

Merge в main → поднять build (текущий в TestFlight — 11, он с чужими ссылками и для сабмита
непригоден) → залить новый билд в TestFlight. Дальше ASO-поток прикрепит его к версии 1.0.

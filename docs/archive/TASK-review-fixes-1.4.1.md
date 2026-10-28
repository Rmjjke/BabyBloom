# TASK: Реджект App Review 11.09.2026 — цитаты источников в приложении (guideline 1.4.1) + build 18

**Приоритет: критический — приложение отклонено, без этого не пересабмитить.**
Submission ID `ca34baff-b632-4aeb-a533-e1bc538549fe`, ревью на iPad Air 11" (M3), версия 1.0 (17).

Реджект содержит три пункта; **этот файл — только про пункт 1.4.1, код.**
(2.1(b) — подписки не приложены к сабмиту — и 1.5 — Support URL — закрывает ASO-поток в ASC
и на лендинге, кода не касаются.)

## Что сказал Apple

> The app includes medical information but does not include citations for the medical information.
> Specifically, the app provides health or medical references in the "Did you know?",
> "WHO percentiles" sections without citations, such as links to sources for this information.
> Next steps: include citations in the app of the sources… easy for the user to find.

## Что сделать

Три UI-точки + 12 ключей локализации. Все URL проверены живьём 2026-09-14 (11 × HTTP 200),
и это те же документы, на которых реально построена арифметика в `Core/Growth` — цитируем то,
что код действительно использует, а не декоративную библиографию.

1. **`OnboardingFacts.swift`** — каждому факту добавить `sourceKey` (ключ локализации названия
   источника) и `source: URL`. Маппинг: newborn1/infant2 → AAP «how often and how much», newborn2/infant1 → NHS sleep,
   older1 → WHO complementary feeding, older2 → WHO growth standards, breast1 → AAP breastfeeding,
   formula1 → AAP formula schedule.
2. **`FactPage.swift`** — под текстом факта tappable `Link`: «Source: {название} ↗».
3. **`GrowthInsightCards.swift`** —
   а) `GrowthExplainer.sources: [(labelKey, url)]` per-случай: newborn → NICE NG75 + NHS baby weight;
      percentile → WHO weight-for-age; gain → WHO weight-velocity; trend → NICE NG75;
      nutrition → AAP feeding + NHS enough-milk;
   б) в `ExplainerSheet` после body — секция «Sources» со ссылками;
   в) `WHOFootnote` — добавить ссылку на WHO standards под текстом сноски.
4. **Локализация**: 12 ключей (`common.source`, `common.sources`, `source.*`) в en/ru/es.json
   **и синхронизировать WidgetResources-копии** (`cp`), иначе pre-build скрипт валит сборку.
5. Bump `CURRENT_PROJECT_VERSION` до **18**, xcodegen, build, upload в TestFlight.
   Apple явно требует новый бинарь: «submit the In-App Purchase products AND upload a new binary».

## Готовый патч

Ниже дифф, который уже был собран и откатан (владелец решил провести правку через тебя).
Можно применить как есть (`git apply`) или переписать по-своему — поведение важнее формы.
В патче НЕТ ключей локализации и бампа версии — их сделай шагами 4-5 выше. Ключи и переводы:

| Ключ | en | ru | es |
|---|---|---|---|
| common.source | Source | Источник | Fuente |
| common.sources | Sources | Источники | Fuentes |
| source.who_standards | WHO Child Growth Standards | ВОЗ — стандарты роста детей | OMS — Estándares de crecimiento infantil |
| source.who_velocity | WHO growth velocity standards | ВОЗ — нормы прибавки веса | OMS — Normas de aumento de peso |
| source.who_complementary | WHO — complementary feeding | ВОЗ — введение прикорма | OMS — Alimentación complementaria |
| source.nice_ng75 | NICE guideline NG75 (faltering growth) | NICE, руководство NG75 (замедление роста) | Guía NICE NG75 (crecimiento insuficiente) |
| source.aap_feeding_amount | AAP — how often and how much to feed | AAP — частота и объём кормлений | AAP — frecuencia y cantidad de tomas |
| source.aap_breastfeeding | AAP — how often to breastfeed | AAP — частота грудных кормлений | AAP — frecuencia de lactancia |
| source.aap_formula | AAP — formula feeding schedule | AAP — режим кормления смесью | AAP — horario de tomas de fórmula |
| source.nhs_enough_milk | NHS — is my baby getting enough milk? | NHS — хватает ли ребёнку молока | NHS — ¿toma suficiente leche? |
| source.nhs_baby_weight | NHS — baby height and weight | NHS — рост и вес малыша | NHS — talla y peso del bebé |
| source.nhs_sleep | NHS — helping your baby to sleep | NHS — сон малыша | NHS — el sueño del bebé |

```diff
diff --git a/BabyBloom/Features/Growth/GrowthInsightCards.swift b/BabyBloom/Features/Growth/GrowthInsightCards.swift
index 73130f7..0865536 100644
--- a/BabyBloom/Features/Growth/GrowthInsightCards.swift
+++ b/BabyBloom/Features/Growth/GrowthInsightCards.swift
@@ -302,6 +302,34 @@ enum GrowthExplainer {
         case .nutrition:         BBTheme.Colors.feeding
         }
     }
+
+    /// The references each card's numbers actually come from, shown as
+    /// tappable links at the bottom of the sheet. Guideline 1.4.1 requires
+    /// health information to cite its sources where the user can find them —
+    /// and these are the same documents the arithmetic behind the card is
+    /// implemented from (see Core/Growth), so the sheet cites what the code
+    /// really uses rather than a decorative bibliography.
+    var sources: [(labelKey: String, url: URL)] {
+        switch self {
+        case .newborn: [
+            ("source.nice_ng75", URL(string: "https://www.nice.org.uk/guidance/ng75")!),
+            ("source.nhs_baby_weight", URL(string: "https://www.nhs.uk/baby/babys-development/height-weight-and-reviews/baby-height-and-weight/")!),
+        ]
+        case .percentile: [
+            ("source.who_standards", URL(string: "https://www.who.int/tools/child-growth-standards/standards/weight-for-age")!),
+        ]
+        case .gain: [
+            ("source.who_velocity", URL(string: "https://www.who.int/tools/child-growth-standards/standards/weight-velocity")!),
+        ]
+        case .trend: [
+            ("source.nice_ng75", URL(string: "https://www.nice.org.uk/guidance/ng75")!),
+        ]
+        case .nutrition: [
+            ("source.aap_feeding_amount", URL(string: "https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/how-often-and-how-much-should-your-baby-eat.aspx")!),
+            ("source.nhs_enough_milk", URL(string: "https://www.nhs.uk/baby/breastfeeding-and-bottle-feeding/breastfeeding-problems/enough-milk/")!),
+        ]
+        }
+    }
 }
 
 /// The explainer sheet: icon, title, copy, «Закрыть» — the shape the percentile
@@ -333,6 +361,30 @@ struct ExplainerSheet: View {
                         .foregroundStyle(BBTheme.Colors.textSecondary)
                         .lineSpacing(4)
 
+                    // Guideline 1.4.1: the documents behind the card's
+                    // arithmetic, as links the user can actually open.
+                    VStack(alignment: .leading, spacing: BBTheme.Spacing.sm) {
+                        Text("common.sources".l)
+                            .font(BBTheme.Typography.scaled(13, relativeTo: .caption, weight: .semibold, design: .rounded))
+                            .foregroundStyle(BBTheme.Colors.textPrimary)
+
+                        ForEach(explainer.sources, id: \.url) { source in
+                            Link(destination: source.url) {
+                                HStack(spacing: 6) {
+                                    Image(systemName: "link")
+                                        .font(.system(size: 10, weight: .semibold))
+                                    Text(source.labelKey.l)
+                                        .multilineTextAlignment(.leading)
+                                    Image(systemName: "arrow.up.right")
+                                        .font(.system(size: 9, weight: .semibold))
+                                }
+                                .font(BBTheme.Typography.scaled(13, relativeTo: .caption, weight: .medium, design: .rounded))
+                                .foregroundStyle(explainer.tint)
+                            }
+                        }
+                    }
+                    .padding(.top, BBTheme.Spacing.sm)
+
                     Spacer()
                 }
                 .padding(BBTheme.Spacing.lg)
@@ -785,13 +837,27 @@ struct CorrectedAgeChip: View {
     }
 }
 
-/// The line that keeps every number on this screen in its place.
+/// The line that keeps every number on this screen in its place — and, since
+/// the 1.4.1 review round, the link that lets the user open the WHO standards
+/// the screen keeps referring to.
 struct WHOFootnote: View {
     var body: some View {
-        Text("growth.who_footnote".l)
-            .font(.system(size: 11, weight: .regular, design: .rounded))
-            .foregroundStyle(BBTheme.Colors.textSecondary)
-            .fixedSize(horizontal: false, vertical: true)
-            .frame(maxWidth: .infinity, alignment: .leading)
+        VStack(alignment: .leading, spacing: 4) {
+            Text("growth.who_footnote".l)
+                .font(.system(size: 11, weight: .regular, design: .rounded))
+                .foregroundStyle(BBTheme.Colors.textSecondary)
+                .fixedSize(horizontal: false, vertical: true)
+
+            Link(destination: URL(string: "https://www.who.int/tools/child-growth-standards/standards")!) {
+                HStack(spacing: 4) {
+                    Text("\("common.source".l): \("source.who_standards".l)")
+                    Image(systemName: "arrow.up.right")
+                        .font(.system(size: 8, weight: .semibold))
+                }
+                .font(.system(size: 11, weight: .medium, design: .rounded))
+                .foregroundStyle(BBTheme.Colors.growth)
+            }
+        }
+        .frame(maxWidth: .infinity, alignment: .leading)
     }
 }
diff --git a/BabyBloom/Features/Onboarding/OnboardingFacts.swift b/BabyBloom/Features/Onboarding/OnboardingFacts.swift
index e7fdf94..8107475 100644
--- a/BabyBloom/Features/Onboarding/OnboardingFacts.swift
+++ b/BabyBloom/Features/Onboarding/OnboardingFacts.swift
@@ -17,19 +17,40 @@ enum OnboardingFacts {
         let ageRange: Range<Int>
         /// nil = any feeding type.
         let feeding: Baby.FeedingType?
+        /// Localization key naming the authority behind the fact.
+        let sourceKey: String
+        /// Where the fact comes from. Every fact must carry one — App Review
+        /// (guideline 1.4.1) requires health information to cite its source,
+        /// and a fact we cannot source does not belong in the pool.
+        let source: URL
     }
 
+    private static let aapFeedingAmounts = URL(string: "https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/how-often-and-how-much-should-your-baby-eat.aspx")!
+    private static let nhsSleep = URL(string: "https://www.nhs.uk/baby/caring-for-a-newborn/helping-your-baby-to-sleep/")!
+
     /// Order is stable on purpose: the seed indexes into the eligible subset,
     /// so a new fact appended at the end never reshuffles existing picks.
     static let pool: [Fact] = [
-        Fact(key: "onboarding.fact.newborn1", number: 12, ageRange: 0..<2,   feeding: nil),
-        Fact(key: "onboarding.fact.newborn2", number: 18, ageRange: 0..<2,   feeding: nil),
-        Fact(key: "onboarding.fact.infant1",  number: 6,  ageRange: 2..<5,   feeding: nil),
-        Fact(key: "onboarding.fact.infant2",  number: 8,  ageRange: 2..<5,   feeding: nil),
-        Fact(key: "onboarding.fact.older1",   number: 6,  ageRange: 5..<36,  feeding: nil),
-        Fact(key: "onboarding.fact.older2",   number: 5,  ageRange: 5..<36,  feeding: nil),
-        Fact(key: "onboarding.fact.breast1",  number: 3,  ageRange: 0..<12,  feeding: .breast),
-        Fact(key: "onboarding.fact.formula1", number: 4,  ageRange: 0..<12,  feeding: .formula),
+        Fact(key: "onboarding.fact.newborn1", number: 12, ageRange: 0..<2,   feeding: nil,
+             sourceKey: "source.aap_feeding_amount", source: aapFeedingAmounts),
+        Fact(key: "onboarding.fact.newborn2", number: 18, ageRange: 0..<2,   feeding: nil,
+             sourceKey: "source.nhs_sleep", source: nhsSleep),
+        Fact(key: "onboarding.fact.infant1",  number: 6,  ageRange: 2..<5,   feeding: nil,
+             sourceKey: "source.nhs_sleep", source: nhsSleep),
+        Fact(key: "onboarding.fact.infant2",  number: 8,  ageRange: 2..<5,   feeding: nil,
+             sourceKey: "source.aap_feeding_amount", source: aapFeedingAmounts),
+        Fact(key: "onboarding.fact.older1",   number: 6,  ageRange: 5..<36,  feeding: nil,
+             sourceKey: "source.who_complementary",
+             source: URL(string: "https://www.who.int/health-topics/complementary-feeding")!),
+        Fact(key: "onboarding.fact.older2",   number: 5,  ageRange: 5..<36,  feeding: nil,
+             sourceKey: "source.who_standards",
+             source: URL(string: "https://www.who.int/tools/child-growth-standards/standards")!),
+        Fact(key: "onboarding.fact.breast1",  number: 3,  ageRange: 0..<12,  feeding: .breast,
+             sourceKey: "source.aap_breastfeeding",
+             source: URL(string: "https://www.healthychildren.org/English/ages-stages/baby/breastfeeding/Pages/How-Often-to-Breastfeed.aspx")!),
+        Fact(key: "onboarding.fact.formula1", number: 4,  ageRange: 0..<12,  feeding: .formula,
+             sourceKey: "source.aap_formula",
+             source: URL(string: "https://www.healthychildren.org/English/ages-stages/baby/formula-feeding/Pages/amount-and-schedule-of-formula-feedings.aspx")!),
     ]
 
     /// Age-eligible facts for this baby; feeding-typed facts require a match
diff --git a/BabyBloom/Features/Onboarding/Pages/FactPage.swift b/BabyBloom/Features/Onboarding/Pages/FactPage.swift
index b3bbd15..cde1461 100644
--- a/BabyBloom/Features/Onboarding/Pages/FactPage.swift
+++ b/BabyBloom/Features/Onboarding/Pages/FactPage.swift
@@ -43,6 +43,20 @@ struct FactPage: View {
                         .multilineTextAlignment(.center)
                         .padding(.horizontal, BBTheme.Spacing.lg)
                         .fixedSize(horizontal: false, vertical: true)
+
+                    // Guideline 1.4.1: health information cites its source,
+                    // and the citation is easy for the user to find — right
+                    // under the claim, as a tappable link.
+                    Link(destination: fact.source) {
+                        HStack(spacing: 4) {
+                            Text("\("common.source".l): \(fact.sourceKey.l)")
+                            Image(systemName: "arrow.up.right")
+                                .font(.system(size: 9, weight: .semibold))
+                        }
+                        .font(BBTheme.Typography.scaled(12, relativeTo: .caption, weight: .medium, design: .rounded))
+                        .foregroundStyle(BBTheme.Colors.textSecondary)
+                    }
+                    .padding(.horizontal, BBTheme.Spacing.lg)
                 }
                 .offset(y: appear ? 0 : 20)
                 .opacity(appear ? 1 : 0)
diff --git a/BabyBloom/Resources/Localization/en.json b/BabyBloom/Resources/Localization/en.json
index 0f348de..c395564 100644
--- a/BabyBloom/Resources/Localization/en.json
+++ b/BabyBloom/Resources/Localization/en.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "The widget on your Home Screen",
   "onboarding.widget.subtitle": "How long until the next feed — at a glance, without opening the app.",
   "onboarding.widget.howto": "Touch and hold the Home Screen → “+” → %@",
-  "onboarding.widget.cta": "Build My Tracker"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Build My Tracker",
+  "common.source": "Source",
+  "common.sources": "Sources",
+  "source.who_standards": "WHO Child Growth Standards",
+  "source.who_velocity": "WHO growth velocity standards",
+  "source.who_complementary": "WHO — complementary feeding",
+  "source.nice_ng75": "NICE guideline NG75 (faltering growth)",
+  "source.aap_feeding_amount": "AAP — how often and how much to feed",
+  "source.aap_breastfeeding": "AAP — how often to breastfeed",
+  "source.aap_formula": "AAP — formula feeding schedule",
+  "source.nhs_enough_milk": "NHS — is my baby getting enough milk?",
+  "source.nhs_baby_weight": "NHS — baby height and weight",
+  "source.nhs_sleep": "NHS — helping your baby to sleep"
+}
diff --git a/BabyBloom/Resources/Localization/es.json b/BabyBloom/Resources/Localization/es.json
index d4aa4e3..71344b3 100644
--- a/BabyBloom/Resources/Localization/es.json
+++ b/BabyBloom/Resources/Localization/es.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "El widget en la pantalla de inicio",
   "onboarding.widget.subtitle": "Cuánto falta para la próxima toma, de un vistazo y sin abrir la app.",
   "onboarding.widget.howto": "Mantén pulsada la pantalla de inicio → «+» → %@",
-  "onboarding.widget.cta": "Crear mi registro"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Crear mi registro",
+  "common.source": "Fuente",
+  "common.sources": "Fuentes",
+  "source.who_standards": "OMS — Estándares de crecimiento infantil",
+  "source.who_velocity": "OMS — Normas de aumento de peso",
+  "source.who_complementary": "OMS — Alimentación complementaria",
+  "source.nice_ng75": "Guía NICE NG75 (crecimiento insuficiente)",
+  "source.aap_feeding_amount": "AAP — frecuencia y cantidad de tomas",
+  "source.aap_breastfeeding": "AAP — frecuencia de lactancia",
+  "source.aap_formula": "AAP — horario de tomas de fórmula",
+  "source.nhs_enough_milk": "NHS — ¿toma suficiente leche?",
+  "source.nhs_baby_weight": "NHS — talla y peso del bebé",
+  "source.nhs_sleep": "NHS — el sueño del bebé"
+}
diff --git a/BabyBloom/Resources/Localization/ru.json b/BabyBloom/Resources/Localization/ru.json
index 304e166..b223d69 100644
--- a/BabyBloom/Resources/Localization/ru.json
+++ b/BabyBloom/Resources/Localization/ru.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "Виджет на домашнем экране",
   "onboarding.widget.subtitle": "Сколько осталось до следующего кормления — одним взглядом, не открывая приложение.",
   "onboarding.widget.howto": "Долгое нажатие на домашний экран → «+» → %@",
-  "onboarding.widget.cta": "Создать мой трекер"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Создать мой трекер",
+  "common.source": "Источник",
+  "common.sources": "Источники",
+  "source.who_standards": "ВОЗ — стандарты роста детей",
+  "source.who_velocity": "ВОЗ — нормы прибавки веса",
+  "source.who_complementary": "ВОЗ — введение прикорма",
+  "source.nice_ng75": "NICE, руководство NG75 (замедление роста)",
+  "source.aap_feeding_amount": "AAP — частота и объём кормлений",
+  "source.aap_breastfeeding": "AAP — частота грудных кормлений",
+  "source.aap_formula": "AAP — режим кормления смесью",
+  "source.nhs_enough_milk": "NHS — хватает ли ребёнку молока",
+  "source.nhs_baby_weight": "NHS — рост и вес малыша",
+  "source.nhs_sleep": "NHS — сон малыша"
+}
diff --git a/WidgetResources/Localization/en.json b/WidgetResources/Localization/en.json
index 0f348de..c395564 100644
--- a/WidgetResources/Localization/en.json
+++ b/WidgetResources/Localization/en.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "The widget on your Home Screen",
   "onboarding.widget.subtitle": "How long until the next feed — at a glance, without opening the app.",
   "onboarding.widget.howto": "Touch and hold the Home Screen → “+” → %@",
-  "onboarding.widget.cta": "Build My Tracker"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Build My Tracker",
+  "common.source": "Source",
+  "common.sources": "Sources",
+  "source.who_standards": "WHO Child Growth Standards",
+  "source.who_velocity": "WHO growth velocity standards",
+  "source.who_complementary": "WHO — complementary feeding",
+  "source.nice_ng75": "NICE guideline NG75 (faltering growth)",
+  "source.aap_feeding_amount": "AAP — how often and how much to feed",
+  "source.aap_breastfeeding": "AAP — how often to breastfeed",
+  "source.aap_formula": "AAP — formula feeding schedule",
+  "source.nhs_enough_milk": "NHS — is my baby getting enough milk?",
+  "source.nhs_baby_weight": "NHS — baby height and weight",
+  "source.nhs_sleep": "NHS — helping your baby to sleep"
+}
diff --git a/WidgetResources/Localization/es.json b/WidgetResources/Localization/es.json
index d4aa4e3..71344b3 100644
--- a/WidgetResources/Localization/es.json
+++ b/WidgetResources/Localization/es.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "El widget en la pantalla de inicio",
   "onboarding.widget.subtitle": "Cuánto falta para la próxima toma, de un vistazo y sin abrir la app.",
   "onboarding.widget.howto": "Mantén pulsada la pantalla de inicio → «+» → %@",
-  "onboarding.widget.cta": "Crear mi registro"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Crear mi registro",
+  "common.source": "Fuente",
+  "common.sources": "Fuentes",
+  "source.who_standards": "OMS — Estándares de crecimiento infantil",
+  "source.who_velocity": "OMS — Normas de aumento de peso",
+  "source.who_complementary": "OMS — Alimentación complementaria",
+  "source.nice_ng75": "Guía NICE NG75 (crecimiento insuficiente)",
+  "source.aap_feeding_amount": "AAP — frecuencia y cantidad de tomas",
+  "source.aap_breastfeeding": "AAP — frecuencia de lactancia",
+  "source.aap_formula": "AAP — horario de tomas de fórmula",
+  "source.nhs_enough_milk": "NHS — ¿toma suficiente leche?",
+  "source.nhs_baby_weight": "NHS — talla y peso del bebé",
+  "source.nhs_sleep": "NHS — el sueño del bebé"
+}
diff --git a/WidgetResources/Localization/ru.json b/WidgetResources/Localization/ru.json
index 304e166..b223d69 100644
--- a/WidgetResources/Localization/ru.json
+++ b/WidgetResources/Localization/ru.json
@@ -470,5 +470,17 @@
   "onboarding.widget.title": "Виджет на домашнем экране",
   "onboarding.widget.subtitle": "Сколько осталось до следующего кормления — одним взглядом, не открывая приложение.",
   "onboarding.widget.howto": "Долгое нажатие на домашний экран → «+» → %@",
-  "onboarding.widget.cta": "Создать мой трекер"
-}
\ No newline at end of file
+  "onboarding.widget.cta": "Создать мой трекер",
+  "common.source": "Источник",
+  "common.sources": "Источники",
+  "source.who_standards": "ВОЗ — стандарты роста детей",
+  "source.who_velocity": "ВОЗ — нормы прибавки веса",
+  "source.who_complementary": "ВОЗ — введение прикорма",
+  "source.nice_ng75": "NICE, руководство NG75 (замедление роста)",
+  "source.aap_feeding_amount": "AAP — частота и объём кормлений",
+  "source.aap_breastfeeding": "AAP — частота грудных кормлений",
+  "source.aap_formula": "AAP — режим кормления смесью",
+  "source.nhs_enough_milk": "NHS — хватает ли ребёнку молока",
+  "source.nhs_baby_weight": "NHS — рост и вес малыша",
+  "source.nhs_sleep": "NHS — сон малыша"
+}
```

## Проверка перед аплоадом

- Все 11 URL открываются (проверены 2026-09-14, но перепроверь после применения).
- Онбординг: страница факта показывает ссылку «Source: …» для КАЖДОГО из 8 фактов.
- Экран роста: «?» на карточках → шит со секцией Sources; сноска ВОЗ внизу — со ссылкой.
- Локали: en/ru/es — ссылки подписаны на языке интерфейса, JSON-ы виджета синхронны.
- Build 18 в TestFlight → сообщить ASO-потоку: он прикрепит билд, приложит подписки и пересабмитит.

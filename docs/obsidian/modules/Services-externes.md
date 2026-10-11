---
tags: [ardane, module, services]
---

# Services externes et frameworks Apple

Zone : **Services externes** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Ce qui sort de l'appareil (API web, sans compte) et les frameworks système utilisés.

## Ce qui existe (vérifié dans le code)

- Open Food Facts (`world.openfoodfacts.org`) : recherche et code-barres — `FoodDatabase`, appelé par `NutritionSpace`.
- Open-Meteo (`api.open-meteo.com`) : météo — `WeatherService` (AppModel, PayloadLoader, DesignProvider, Voyage).
- CoinGecko (`api.coingecko.com`) : crypto — `CryptoService`, `MarketService`.
- Finnhub (`finnhub.io`) : cours des actions — `MarketService`.
- SEC (`data.sec.gov`, `www.sec.gov`) : données des sociétés cotées — `CompanyService`.
- Frankfurter (`api.frankfurter.dev`) : taux de change — `FXService`.
- Frameworks : StoreKit, WidgetKit, ActivityKit, AppIntents, VisionKit et Vision (scanner), EventKit (calendrier), CoreLocation (ville), CoreMotion (pas), UserNotifications, Charts, PhotosUI, FoundationModels (`AIPhraser`, iOS 26).

## Fichiers sources

- [Shared/Domains/FoodDatabase.swift](../../../Shared/Domains/FoodDatabase.swift)
- [Shared/Data/WeatherService.swift](../../../Shared/Data/WeatherService.swift)
- [Shared/Data/CryptoService.swift](../../../Shared/Data/CryptoService.swift)
- [Shared/Domains/Portfolio.swift](../../../Shared/Domains/Portfolio.swift)
- [Shared/Domains/Companies.swift](../../../Shared/Domains/Companies.swift)
- [Shared/Domains/Travel.swift](../../../Shared/Domains/Travel.swift)
- [Shared/Data/CalendarService.swift](../../../Shared/Data/CalendarService.swift)
- [App/Services/LocationService.swift](../../../App/Services/LocationService.swift)
- [App/Core/StepCounter.swift](../../../App/Core/StepCounter.swift)
- [App/Services/AIPhraser.swift](../../../App/Services/AIPhraser.swift)
- [App/Services/NotificationScheduler.swift](../../../App/Services/NotificationScheduler.swift)
- [App/Premium/PremiumStore.swift](../../../App/Premium/PremiumStore.swift)

## Relations

- [[Noyau-AppModel]] : caches réseau
- [[Widgets-extension]] : rafraîchissement des widgets
- [[Nutrition]] : Open Food Facts
- [[Premium-et-abonnements]] : StoreKit

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

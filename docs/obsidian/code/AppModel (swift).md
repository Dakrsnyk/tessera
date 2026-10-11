---
tags: [ardane, code, zone/metier]
source: App/Core/AppModel.swift
---

# AppModel.swift

Module : [[Noyau-AppModel]] · Fichier : [App/Core/AppModel.swift](../../../App/Core/AppModel.swift) · 815 lignes

> Single source of truth for the app's data. Everything is written through to the shared store,

**Déclare :** `AppModel`

## Utilise (autres modules)

- Domaines métier (Shared/Domains) : `Budget.swift`, `Business.swift`, `Car.swift`, `Companies.swift`, `Fitness.swift`, `Life.swift`, `Nutrition.swift`, `Portfolio.swift`, `Productivity.swift`, `Profile.swift`, `Student.swift`, `Travel.swift`
- Données et stockage : `DataBackup.swift`, `DomainData.swift`, `Insights.swift`, `PayloadLoader.swift`, `SharedStore.swift`
- Boutons des widgets, activité en direct et liens : `WorkoutLiveActivity.swift`
- Outils partagés (Shared/Support) : `DateMath.swift`
- Planning, tâches et habitudes : `CalendarService.swift`, `Content.swift`
- Profil et réglages : `NotificationScheduler.swift`, `ReviewPrompt.swift`, `Settings.swift`, `SmartReminders.swift`, `AppStyle.swift`
- Services externes et frameworks Apple : `AIPhraser.swift`, `CryptoService.swift`, `WeatherService.swift`
- Store : `Packs.swift`
- Studio (éditeur de widgets) : `WidgetDesign.swift`, `WidgetStyle.swift`
- Tests, CI et outils : `ScreenshotMode.swift`

## Services et frameworks

- WidgetKit
- App Group

Utilisé par 76 fichier(s) : `SaveFlight.swift`, `StylePicker.swift`, `Agenda.swift`, `AppModel+Debug.swift`, `DailyBrief.swift`, `DailyCategories.swift`, `DataItems.swift`, `Router.swift`, `ScreenshotMode.swift`, `PaywallView.swift`, `PremiumStore.swift`, `HabitsView.swift` …

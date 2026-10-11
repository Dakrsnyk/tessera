---
tags: [ardane, code, zone/ios]
source: Shared/Intents/SpaceIntents.swift
---

# SpaceIntents.swift

Module : [[Intents-et-activite-en-direct]] · Fichier : [Shared/Intents/SpaceIntents.swift](../../../Shared/Intents/SpaceIntents.swift) · 259 lignes

> The workout was changed outside the app's screens (Lock Screen, Dynamic Island, a widget):

**Déclare :** `CompleteSetIntent`, `CounterStepIntent`, `GradeCardIntent`, `LogFoodIntent`, `PauseRestIntent`, `QuickExpenseIntent`, `ResumeRestIntent`, `RevealCardIntent`, `SkipRestIntent`, `ToggleAssignmentIntent`, `TogglePriorityIntent`, `ToggleProjectTaskIntent`

## Utilise (même module)

- [[WorkoutLiveActivity (swift)]]

## Utilise (autres modules)

- Domaines métier (Shared/Domains) : `Budget.swift`, `Fitness.swift`, `FoodDatabase.swift`, `Nutrition.swift`, `Productivity.swift`, `Student.swift`
- Données et stockage : `SharedStore.swift`
- Profil et réglages : `SmartReminders.swift`

## Services et frameworks

- WidgetKit
- AppIntents
- App Group

Utilisé par 3 fichier(s) : `WorkoutLiveActivity.swift`, `TileView.swift`, `WorkoutLiveActivityWidget.swift`

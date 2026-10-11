---
tags: [ardane, module, zone/ios]
---

# Boutons des widgets, activité en direct et liens

Zone : **Widgets et système iOS** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Les actions qui changent les données sans ouvrir l'app (App Intents des widgets iOS 17), l'activité en direct de la séance et les liens profonds `tessera://`.

## Ce qui existe (vérifié dans le code)

- Widgets interactifs : `AddWaterIntent`, `ToggleHabitIntent`, `ToggleTaskIntent`, `StartFocusIntent`, `StopFocusIntent` (InteractiveIntents).
- Espaces : `LogFoodIntent`, `QuickExpenseIntent`, `TogglePriorityIntent`, `ToggleProjectTaskIntent`, `ToggleAssignmentIntent`, `CounterStepIntent`, `GradeCardIntent`, `RevealCardIntent` (SpaceIntents).
- Activité en direct (ActivityKit) : `CompleteSetIntent` (Série faite), `PauseRestIntent`, `ResumeRestIntent`, `SkipRestIntent`.
- Liens profonds `tessera://` : design, premium, tâches, habitudes, eau, argent, météo, calendrier, Store, espace, scan-food ; reçus par `onOpenURL` puis `router.handle`.

## Fichiers sources

- [Shared/Intents/InteractiveIntents.swift](../../../Shared/Intents/InteractiveIntents.swift)
- [Shared/Intents/SpaceIntents.swift](../../../Shared/Intents/SpaceIntents.swift)
- [Shared/Intents/DesignIntent.swift](../../../Shared/Intents/DesignIntent.swift)
- [Shared/Live/WorkoutLiveActivity.swift](../../../Shared/Live/WorkoutLiveActivity.swift)
- [Widgets/WorkoutLiveActivityWidget.swift](../../../Widgets/WorkoutLiveActivityWidget.swift)
- [Shared/Support/DeepLink.swift](../../../Shared/Support/DeepLink.swift)

## Relations

- [[Donnees-et-stockage]] : écrivent dans le SharedStore
- [[Fitness]] : séance en cours
- [[Noyau-AppModel]] : liens reçus par le Router

## Fichiers du module (4)

- [[InteractiveIntents (swift)]]
- [[SpaceIntents (swift)]]
- [[WorkoutLiveActivity (swift)]]
- [[DeepLink (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

---
tags: [ardane, module, zone/interface]
---

# Fitness

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Programme de la semaine, séance en direct, repos, bibliothèque d'exercices avec démonstrations animées, progression.

## Ce qui existe (vérifié dans le code)

- Séance en direct : série en cours, répétitions et charge, repos minuté (pause, passer), « Série faite ».
- Activité en direct sur l'écran verrouillé et dans la Dynamic Island, boutons actifs sans ouvrir l'app.
- Bibliothèque d'exercices (163) avec démonstration animée (`DemoRenderer`, `ExerciseDemos.json`) et technique.
- Semaine en ronds, records, progression, historique, séances rattrapées, calories estimées.
- Pas du jour via le capteur de mouvement (`StepCounter`, CoreMotion).

## Fichiers sources

- [App/Screens/MiniApps/Fitness/FitnessApp.swift](../../../App/Screens/MiniApps/Fitness/FitnessApp.swift)
- [App/Screens/MiniApps/Fitness/FitnessSession.swift](../../../App/Screens/MiniApps/Fitness/FitnessSession.swift)
- [App/Screens/MiniApps/Fitness/FitnessPages.swift](../../../App/Screens/MiniApps/Fitness/FitnessPages.swift)
- [App/Screens/MiniApps/Fitness/ExerciseLibraryViews.swift](../../../App/Screens/MiniApps/Fitness/ExerciseLibraryViews.swift)
- [App/Screens/MiniApps/Fitness/ExerciseDemo.swift](../../../App/Screens/MiniApps/Fitness/ExerciseDemo.swift)
- [App/Screens/Spaces/FitnessSpace.swift](../../../App/Screens/Spaces/FitnessSpace.swift)
- [Shared/Domains/Fitness.swift](../../../Shared/Domains/Fitness.swift)
- [Shared/Domains/ExerciseLibrary.swift](../../../Shared/Domains/ExerciseLibrary.swift)
- [App/Core/StepCounter.swift](../../../App/Core/StepCounter.swift)
- [Shared/Render/Tiles/FitnessTiles.swift](../../../Shared/Render/Tiles/FitnessTiles.swift)

## Relations

- [[Intents-et-activite-en-direct]] : Série faite, pause, passer
- [[Domaines-metier]] : FitnessState
- [[Donnees-et-stockage]] : ExerciseDemos.json

## Fichiers du module (8)

- [[StepCounter (swift)]]
- [[ExerciseDemo (swift)]]
- [[ExerciseLibraryViews (swift)]]
- [[FitnessApp (swift)]]
- [[FitnessPages (swift)]]
- [[FitnessSession (swift)]]
- [[FitnessSpace (swift)]]
- [[FitnessTiles (swift)]]

## Dépend de (mesuré dans le code)

- [[Widgets-extension]] : 4 fichier(s)
- [[Mini-apps]] : 3 fichier(s)
- [[Outils-partages]] : 3 fichier(s)
- Créer : les espaces : 2 fichier(s)
- Domaines métier (Shared/Domains) : 2 fichier(s)
- Noyau : AppModel et Router : 2 fichier(s)
- Accueil : Mon Quotidien : 1 fichier(s)
- Nutrition : 1 fichier(s)

## Services et frameworks

- [[Swift Charts]] : 2 fichier(s)
- [[CoreMotion]] : 1 fichier(s)
- [[Demos des exercices]] : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

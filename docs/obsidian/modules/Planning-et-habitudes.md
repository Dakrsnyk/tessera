---
tags: [ardane, module, interface]
---

# Planning, tâches et habitudes

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

La semaine en tableau et le jour choisi, les tâches, le Top 3, les projets, la concentration, les études, les habitudes et l'eau.

## Ce qui existe (vérifié dans le code)

- Semaine en tableau (blocs, ligne « maintenant », balayage de semaine), agenda du jour.
- Tâches avec répétition, Top 3 du jour, mois, projets, minuteur de concentration.
- Études (cours, examens, devoirs, notes) dans le Planning.
- Habitudes quotidiennes (série, rappel), eau en verres.
- Calendrier lu seulement (EventKit), sur autorisation.

## Fichiers sources

- [App/Screens/MiniApps/Planning/PlanningApp.swift](../../../App/Screens/MiniApps/Planning/PlanningApp.swift)
- [App/Screens/MiniApps/Planning/PlanningPages.swift](../../../App/Screens/MiniApps/Planning/PlanningPages.swift)
- [App/Screens/MiniApps/Studies/StudiesApp.swift](../../../App/Screens/MiniApps/Studies/StudiesApp.swift)
- [App/Screens/MiniApps/Studies/StudiesPages.swift](../../../App/Screens/MiniApps/Studies/StudiesPages.swift)
- [App/Screens/Content/HabitsView.swift](../../../App/Screens/Content/HabitsView.swift)
- [App/Screens/Content/HydrationView.swift](../../../App/Screens/Content/HydrationView.swift)
- [App/Screens/Content/TasksView.swift](../../../App/Screens/Content/TasksView.swift)
- [Shared/Domains/Productivity.swift](../../../Shared/Domains/Productivity.swift)
- [Shared/Domains/Student.swift](../../../Shared/Domains/Student.swift)
- [Shared/Model/Content.swift](../../../Shared/Model/Content.swift)
- [Shared/Data/CalendarService.swift](../../../Shared/Data/CalendarService.swift)

## Relations

- [[Services-externes]] : EventKit (calendrier)
- [[Intents-et-activite-en-direct]] : cocher une habitude ou une tâche depuis un widget
- [[Domaines-metier]]

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

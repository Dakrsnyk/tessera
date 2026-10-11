---
tags: [ardane, module, zone/interface]
---

# Accueil : Mon Quotidien

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

L'onglet Accueil : « Mon Quotidien » rassemble ce qui compte aujourd'hui, construit seulement à partir de ce que la personne a saisi, puis « Mes informations ».

## Ce qui existe (vérifié dans le code)

- Cartes du jour (nutrition, séance, habitudes, À ne pas oublier, planning, eau, budget, Top 3…), classées selon le moment de la journée.
- Cartes à plusieurs vues (balayage), disposition à la main (ordre, demi ou large, masquer).
- « Mes informations » : complétude du profil et chaque domaine suivi d'un coup d'œil.
- `MiniAppsRow.swift` est présent mais le type `MiniAppsRow` n'est instancié nulle part.

## Fichiers sources

- [App/Screens/Home/HomeView.swift](../../../App/Screens/Home/HomeView.swift)
- [App/Screens/Home/DailySection.swift](../../../App/Screens/Home/DailySection.swift)
- [App/Screens/Home/DailyPager.swift](../../../App/Screens/Home/DailyPager.swift)
- [App/Screens/Home/DailyLayoutEditor.swift](../../../App/Screens/Home/DailyLayoutEditor.swift)
- [App/Screens/Home/MyInfoCenter.swift](../../../App/Screens/Home/MyInfoCenter.swift)
- [App/Screens/Home/MyInfoSection.swift](../../../App/Screens/Home/MyInfoSection.swift)
- [App/Screens/Home/MiniAppsRow.swift](../../../App/Screens/Home/MiniAppsRow.swift)
- [App/Core/DailyBrief.swift](../../../App/Core/DailyBrief.swift)
- [App/Core/DailyCategories.swift](../../../App/Core/DailyCategories.swift)
- [App/Core/Agenda.swift](../../../App/Core/Agenda.swift)

## Relations

- [[Mini-apps]] : chaque carte ouvre sa mini-app
- [[Noyau-AppModel]] : lit l'état
- [[Nutrition]] : carte et bouton Scanner
- [[Fitness]] : carte séance en cours

## Fichiers du module (10)

- [[Agenda (swift)]]
- [[DailyBrief (swift)]]
- [[DailyCategories (swift)]]
- [[DailyLayoutEditor (swift)]]
- [[DailyPager (swift)]]
- [[DailySection (swift)]]
- [[HomeView (swift)]]
- [[MiniAppsRow (swift)]]
- [[MyInfoCenter (swift)]]
- [[MyInfoSection (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

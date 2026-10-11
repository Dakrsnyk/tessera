---
tags: [ardane, module, zone/interface]
---

# Créer : les espaces

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

L'onglet Créer : chaque espace est l'endroit où l'on saisit les données d'une famille de widgets, puis où l'on crée ses widgets.

## Ce qui existe (vérifié dans le code)

- `Space` : productivity, habits, nutrition, fitness, budget, investing, business, markets, student, travel, car, life.
- Création de widgets depuis un espace (taille, un ou plusieurs widgets), envol vers « Mes widgets ».
- « Écran verrouillé » : les widgets prévus pour l'écran verrouillé, par univers.
- Formulaires des espaces (aliment, séance, dépense, plein…).

## Fichiers sources

- [App/Screens/Spaces/SpacesView.swift](../../../App/Screens/Spaces/SpacesView.swift)
- [App/Screens/Spaces/SpaceBuilderView.swift](../../../App/Screens/Spaces/SpaceBuilderView.swift)
- [App/Screens/Spaces/LockScreenCreator.swift](../../../App/Screens/Spaces/LockScreenCreator.swift)
- [App/Screens/Spaces/SpaceForms.swift](../../../App/Screens/Spaces/SpaceForms.swift)
- [App/Screens/Spaces/SpaceSheets.swift](../../../App/Screens/Spaces/SpaceSheets.swift)
- [App/Screens/Spaces/ProductivitySpace.swift](../../../App/Screens/Spaces/ProductivitySpace.swift)
- [App/Screens/Spaces/StudentSpace.swift](../../../App/Screens/Spaces/StudentSpace.swift)
- [App/Components/SaveFlight.swift](../../../App/Components/SaveFlight.swift)
- [Shared/Model/KindCatalog.swift](../../../Shared/Model/KindCatalog.swift)

## Relations

- [[Studio-editeur]] : ouvre le Studio (openEditor)
- [[Domaines-metier]] : saisie des données
- [[Mes-widgets]] : les widgets créés y arrivent

## Fichiers du module (9)

- [[SaveFlight (swift)]]
- [[LockScreenCreator (swift)]]
- [[ProductivitySpace (swift)]]
- [[SpaceBuilderView (swift)]]
- [[SpaceForms (swift)]]
- [[SpaceSheets (swift)]]
- [[SpacesView (swift)]]
- [[StudentSpace (swift)]]
- [[KindCatalog (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

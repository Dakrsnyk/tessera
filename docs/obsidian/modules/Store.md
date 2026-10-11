---
tags: [ardane, module, interface]
---

# Store

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

L'onglet Store (Explore) : la sélection de la semaine, des écrans d'accueil complets, des widgets seuls, des packs et des combinés.

## Ce qui existe (vérifié dans le code)

- 23 écrans d'accueil prêts (fond, widgets, icônes et écran verrouillé assortis), 18 fonds d'écran dessinés en code.
- 34 packs, saisons du Store (Halloween en octobre, Noël en décembre), widgets combinés, modèles.
- Un modèle ouvre le Studio sur une copie (`router.openEditor`).

## Fichiers sources

- [App/Screens/Explore/ExploreView.swift](../../../App/Screens/Explore/ExploreView.swift)
- [App/Screens/Explore/HomeSetups.swift](../../../App/Screens/Explore/HomeSetups.swift)
- [App/Screens/Explore/HomeSetupViews.swift](../../../App/Screens/Explore/HomeSetupViews.swift)
- [App/Screens/Explore/SetupWallpapers.swift](../../../App/Screens/Explore/SetupWallpapers.swift)
- [App/Screens/Explore/StoreCombos.swift](../../../App/Screens/Explore/StoreCombos.swift)
- [App/Screens/Explore/StoreMagazine.swift](../../../App/Screens/Explore/StoreMagazine.swift)
- [App/Screens/Explore/StoreShowcase.swift](../../../App/Screens/Explore/StoreShowcase.swift)
- [Shared/Model/Packs.swift](../../../Shared/Model/Packs.swift)
- [Shared/Model/Templates.swift](../../../Shared/Model/Templates.swift)
- [Shared/Model/Combo.swift](../../../Shared/Model/Combo.swift)

## Relations

- [[Studio-editeur]] : ouvre un modèle
- [[Premium-et-abonnements]] : packs et styles Premium
- [[Mes-widgets]] : installe des widgets

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

---
tags: [ardane, module, zone/ios]
---

# Widgets : extension et rendu

Zone : **Widgets et système iOS** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

L'extension WidgetKit (cible TesseraWidgets) et le rendu partagé : un même code dessine les vrais widgets et tous les aperçus de l'app.

## Ce qui existe (vérifié dans le code)

- 103 types de widgets (`WidgetKind`), tailles petite, moyenne, grande et écran verrouillé (circulaire, rectangulaire, en ligne).
- Un fournisseur pour tous les types (`DesignProvider`), configuration « Modifier le widget » (`DesignWidgetIntent`).
- Rendu : `WidgetCanvas`, tuiles par domaine (`Tile`, `TileFactory`, `TileView`), widgets d'écran verrouillé (`AccessoryViews`).
- QuickWidget : le dernier design enregistré, sans configuration.

## Fichiers sources

- [Widgets/TesseraWidgetsBundle.swift](../../../Widgets/TesseraWidgetsBundle.swift)
- [Widgets/DesignProvider.swift](../../../Widgets/DesignProvider.swift)
- [Widgets/DesignWidgets.swift](../../../Widgets/DesignWidgets.swift)
- [Widgets/QuickWidget.swift](../../../Widgets/QuickWidget.swift)
- [Widgets/WorkoutLiveActivityWidget.swift](../../../Widgets/WorkoutLiveActivityWidget.swift)
- [Shared/Render/WidgetCanvas.swift](../../../Shared/Render/WidgetCanvas.swift)
- [Shared/Render/Tiles/TileView.swift](../../../Shared/Render/Tiles/TileView.swift)
- [Shared/Render/Tiles/TileFactory.swift](../../../Shared/Render/Tiles/TileFactory.swift)
- [Shared/Render/Tiles/Tile.swift](../../../Shared/Render/Tiles/Tile.swift)
- [Shared/Render/AccessoryViews.swift](../../../Shared/Render/AccessoryViews.swift)
- [Shared/Render/StyleRendering.swift](../../../Shared/Render/StyleRendering.swift)
- [Shared/Model/WidgetKind.swift](../../../Shared/Model/WidgetKind.swift)
- [Shared/Model/WidgetGroup.swift](../../../Shared/Model/WidgetGroup.swift)
- [Shared/Model/KindCatalog.swift](../../../Shared/Model/KindCatalog.swift)
- [Shared/Intents/DesignIntent.swift](../../../Shared/Intents/DesignIntent.swift)
- [Config/Widgets-Info.plist](../../../Config/Widgets-Info.plist)

## Relations

- [[Donnees-et-stockage]] : lit le SharedStore
- [[Intents-et-activite-en-direct]] : boutons interactifs
- [[Services-externes]] : météo, crypto, taux de change au rafraîchissement
- [[Studio-editeur]] : les designs

## Fichiers du module (29)

- [[UIComponents (swift)]]
- [[DesignIntent (swift)]]
- [[WidgetGroup (swift)]]
- [[WidgetKind (swift)]]
- [[WorldCities (swift)]]
- [[AccessoryViews (swift)]]
- [[DataWidgets (swift)]]
- [[ProductivityWidgets (swift)]]
- [[TimeWidgets (swift)]]
- [[RenderComponents (swift)]]
- [[StyleRendering (swift)]]
- [[BusinessTiles (swift)]]
- [[CarTiles (swift)]]
- [[DashboardTiles (swift)]]
- [[ProductivityTiles (swift)]]
- [[StudentTiles (swift)]]
- [[Tile (swift)]]
- [[TileFactory (swift)]]
- [[TileView (swift)]]
- [[TimeTiles (swift)]]
- [[TravelTiles (swift)]]
- [[WeatherTiles (swift)]]
- [[WidgetCanvas (swift)]]
- [[DesignProvider (swift)]]
- [[DesignWidgets (swift)]]
- [[QuickWidget (swift)]]
- [[TesseraWidgetsBundle (swift)]]
- [[WidgetLog (swift)]]
- [[WorkoutLiveActivityWidget (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

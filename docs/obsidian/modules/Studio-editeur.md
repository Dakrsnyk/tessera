---
tags: [ardane, module, zone/interface]
---

# Studio (éditeur de widgets)

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Le Studio : contenu, taille, style, couleurs, fond, bordure et réglages propres au type de widget, avec un aperçu réel.

## Ce qui existe (vérifié dans le code)

- 57 styles (`ThemeID`), 16 thèmes complets (`StylePreset`), 14 palettes, couleur principale, fonds et textures, bordures.
- « Mes styles » : looks enregistrés pour plusieurs widgets.
- Réglages du type de widget et de l'élément suivi, guide d'ajout à l'écran d'accueil.

## Fichiers sources

- [App/Screens/Editor/EditorView.swift](../../../App/Screens/Editor/EditorView.swift)
- [App/Screens/Editor/StudioComponents.swift](../../../App/Screens/Editor/StudioComponents.swift)
- [App/Screens/Editor/StudioPanels.swift](../../../App/Screens/Editor/StudioPanels.swift)
- [App/Screens/Editor/KindOptionsSection.swift](../../../App/Screens/Editor/KindOptionsSection.swift)
- [App/Screens/Editor/SpaceOptionsSection.swift](../../../App/Screens/Editor/SpaceOptionsSection.swift)
- [App/Screens/Editor/AddToHomeScreenGuide.swift](../../../App/Screens/Editor/AddToHomeScreenGuide.swift)
- [App/Components/StylePicker.swift](../../../App/Components/StylePicker.swift)
- [Shared/Model/WidgetDesign.swift](../../../Shared/Model/WidgetDesign.swift)
- [Shared/Model/WidgetStyle.swift](../../../Shared/Model/WidgetStyle.swift)
- [Shared/Model/StyleColors.swift](../../../Shared/Model/StyleColors.swift)
- [Shared/Model/DesignOptions.swift](../../../Shared/Model/DesignOptions.swift)
- [Shared/Theme/Theme.swift](../../../Shared/Theme/Theme.swift)

## Relations

- [[Widgets-extension]] : le design est rendu par WidgetCanvas
- [[Noyau-AppModel]] : enregistre le design
- [[Premium-et-abonnements]] : styles et couleurs Premium

## Fichiers du module (12)

- [[StylePicker (swift)]]
- [[AddToHomeScreenGuide (swift)]]
- [[EditorView (swift)]]
- [[KindOptionsSection (swift)]]
- [[SpaceOptionsSection (swift)]]
- [[StudioComponents (swift)]]
- [[StudioPanels (swift)]]
- [[DesignOptions (swift)]]
- [[StyleColors (swift)]]
- [[WidgetDesign (swift)]]
- [[WidgetStyle (swift)]]
- [[Theme (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

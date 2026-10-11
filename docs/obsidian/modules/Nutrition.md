---
tags: [ardane, module, zone/interface]
---

# Nutrition

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Calories et macros du jour, repas, recherche d'aliments, scanner de code-barres, idées, historique.

## Ce qui existe (vérifié dans le code)

- Anneau des calories restantes, protéines, glucides, lipides, repas du jour, idée, semaine.
- Ajout d'un aliment : recherche (aliments intégrés, base CNF, Open Food Facts si peu de résultats) puis feuille de quantité.
- Scanner de code-barres (VisionKit, EAN/UPC) avec carré de visée ; produit inconnu → créer l'aliment.
- Widgets nutrition ; le bouton « Scanner » des tailles moyenne et grande ouvre l'app sur le scanner (`tessera://scan-food`).
- Ajout rapide depuis un widget (`LogFoodIntent`).

## Fichiers sources

- [App/Screens/MiniApps/Nutrition/NutritionApp.swift](../../../App/Screens/MiniApps/Nutrition/NutritionApp.swift)
- [App/Screens/MiniApps/Nutrition/NutritionPages.swift](../../../App/Screens/MiniApps/Nutrition/NutritionPages.swift)
- [App/Screens/Spaces/NutritionSpace.swift](../../../App/Screens/Spaces/NutritionSpace.swift)
- [Shared/Domains/Nutrition.swift](../../../Shared/Domains/Nutrition.swift)
- [Shared/Domains/FoodDatabase.swift](../../../Shared/Domains/FoodDatabase.swift)
- [App/Core/NutrientFile.swift](../../../App/Core/NutrientFile.swift)
- [Shared/Render/Tiles/NutritionTiles.swift](../../../Shared/Render/Tiles/NutritionTiles.swift)

## Relations

- [[Services-externes]] : Open Food Facts
- [[Domaines-metier]] : NutritionState
- [[Intents-et-activite-en-direct]] : LogFoodIntent, lien scan-food

## Fichiers du module (4)

- [[NutritionApp (swift)]]
- [[NutritionPages (swift)]]
- [[NutritionSpace (swift)]]
- [[NutritionTiles (swift)]]

## Dépend de (mesuré dans le code)

- [[Widgets-extension]] : 5 fichier(s)
- [[Domaines-metier]] : 4 fichier(s)
- [[Mini-apps]] : 3 fichier(s)
- Créer : les espaces : 2 fichier(s)
- Données et stockage : 2 fichier(s)
- Outils partagés (Shared/Support) : 2 fichier(s)
- Accueil : Mon Quotidien : 1 fichier(s)
- Noyau : AppModel et Router : 1 fichier(s)
- Premium et abonnements : 1 fichier(s)
- Store : 1 fichier(s)

## Services et frameworks

- [[VisionKit]] : 2 fichier(s)
- [[Swift Charts]] : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

---
tags: [ardane, module, zone/donnees]
---

# Données et stockage

Zone : **Données et stockage** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Tout est stocké sur l'appareil, dans le conteneur App Group partagé par l'app et l'extension widgets : un fichier JSON par domaine pour qu'un widget qui écrit un domaine ne touche jamais les autres.

## Ce qui existe (vérifié dans le code)

- App Group `group.com.dakrsnyk.tessera`, dossier `Tessera/` (nom conservé après le renommage en Ardane).
- `StoreFile` : designs, content, settings, premium, weather, crypto, nutrition, fitness, budget, business, portfolio, following, student, travel, car, productivity, life, profile, styles, markets, companies, fx, tripWeather, insights.
- Sauvegarde : un fichier qui contient tout, à garder où on veut ; les sauvegardes « Tessera » s'importent toujours.
- Données d'un widget : `PayloadLoader` charge seulement ce que le type de widget utilise (`DataNeeds`, `DomainData`).
- Données de démonstration (galerie système, aperçus du Store, builds de test) : `SampleData`.
- Ressources embarquées : base alimentaire CNF (`cnf-foods.json`, ~5 600 aliments) et démos d'exercices (`ExerciseDemos.json`).

## Fichiers sources

- [Shared/Support/SharedStore.swift](../../../Shared/Support/SharedStore.swift)
- [App/Core/DataBackup.swift](../../../App/Core/DataBackup.swift)
- [App/Core/DataItems.swift](../../../App/Core/DataItems.swift)
- [Shared/Data/PayloadLoader.swift](../../../Shared/Data/PayloadLoader.swift)
- [Shared/Data/DomainData.swift](../../../Shared/Data/DomainData.swift)
- [Shared/Data/SampleData.swift](../../../Shared/Data/SampleData.swift)
- [Shared/Data/Insights.swift](../../../Shared/Data/Insights.swift)
- [App/Core/NutrientFile.swift](../../../App/Core/NutrientFile.swift)
- [App/Resources/cnf-foods.json](../../../App/Resources/cnf-foods.json)
- [App/Resources/ExerciseDemos.json](../../../App/Resources/ExerciseDemos.json)
- [Config/Tessera.entitlements](../../../Config/Tessera.entitlements)
- [Config/TesseraWidgets.entitlements](../../../Config/TesseraWidgets.entitlements)

## Relations

- [[Noyau-AppModel]] : écrit par AppModel
- [[Widgets-extension]] : lu par l'extension
- [[Intents-et-activite-en-direct]] : écrit par les boutons des widgets
- [[Profil-et-reglages]] : sauvegarde et import

## Fichiers du module (8)

- [[DataBackup (swift)]]
- [[DataItems (swift)]]
- [[NutrientFile (swift)]]
- [[DomainData (swift)]]
- [[Insights (swift)]]
- [[PayloadLoader (swift)]]
- [[SampleData (swift)]]
- [[SharedStore (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

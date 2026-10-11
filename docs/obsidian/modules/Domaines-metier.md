---
tags: [ardane, module, zone/metier]
---

# Domaines métier (Shared/Domains)

Zone : **Logique métier et état** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Les règles et les états de chaque partie de la vie gérée par Ardane, partagés par l'app et l'extension (calculs, objectifs, historiques).

## Ce qui existe (vérifié dans le code)

- Nutrition (`NutritionState`, base d'aliments `FoodDatabase`), Fitness (`FitnessState`, bibliothèque `ExerciseLibrary`, `ExerciseTechniques`).
- Budget (`BudgetState`), Business (`BusinessState`), Placements (`PortfolioState`), Marchés et sociétés (`MarketsState`).
- Études (`StudentState`), Voyage (`TravelState`), Auto (`CarState`), Productivité (`ProductivityState`), Ma vie (`LifeState`).
- Profil (`UserProfile`) : centres d'intérêt et informations de la personne.

## Fichiers sources

- [Shared/Domains/Nutrition.swift](../../../Shared/Domains/Nutrition.swift)
- [Shared/Domains/FoodDatabase.swift](../../../Shared/Domains/FoodDatabase.swift)
- [Shared/Domains/Fitness.swift](../../../Shared/Domains/Fitness.swift)
- [Shared/Domains/ExerciseLibrary.swift](../../../Shared/Domains/ExerciseLibrary.swift)
- [Shared/Domains/ExerciseTechniques.swift](../../../Shared/Domains/ExerciseTechniques.swift)
- [Shared/Domains/Budget.swift](../../../Shared/Domains/Budget.swift)
- [Shared/Domains/Business.swift](../../../Shared/Domains/Business.swift)
- [Shared/Domains/Portfolio.swift](../../../Shared/Domains/Portfolio.swift)
- [Shared/Domains/Companies.swift](../../../Shared/Domains/Companies.swift)
- [Shared/Domains/Student.swift](../../../Shared/Domains/Student.swift)
- [Shared/Domains/Travel.swift](../../../Shared/Domains/Travel.swift)
- [Shared/Domains/Car.swift](../../../Shared/Domains/Car.swift)
- [Shared/Domains/Productivity.swift](../../../Shared/Domains/Productivity.swift)
- [Shared/Domains/Life.swift](../../../Shared/Domains/Life.swift)
- [Shared/Domains/Profile.swift](../../../Shared/Domains/Profile.swift)
- [Shared/Domains/StoredStates.swift](../../../Shared/Domains/StoredStates.swift)

## Relations

- [[Noyau-AppModel]] : états tenus par AppModel
- [[Donnees-et-stockage]] : un fichier par domaine
- [[Services-externes]] : Open Food Facts, CoinGecko, Finnhub, SEC, Frankfurter
- [[Mini-apps]] : affichés et modifiés par les mini-apps

## Fichiers du module (16)

- [[Budget (swift)]]
- [[Business (swift)]]
- [[Car (swift)]]
- [[Companies (swift)]]
- [[ExerciseLibrary (swift)]]
- [[ExerciseTechniques (swift)]]
- [[Fitness (swift)]]
- [[FoodDatabase (swift)]]
- [[Life (swift)]]
- [[Nutrition (swift)]]
- [[Portfolio (swift)]]
- [[Productivity (swift)]]
- [[Profile (swift)]]
- [[StoredStates (swift)]]
- [[Student (swift)]]
- [[Travel (swift)]]

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

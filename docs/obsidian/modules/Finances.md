---
tags: [ardane, module, zone/interface]
---

# Finances

Zone : **Interface (App/Screens)** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Saisie manuelle des revenus et dépenses : solde, reste du mois, catégories, factures, épargne. Aucune connexion bancaire.

## Ce qui existe (vérifié dans le code)

- Graphique du solde (mois, 3 mois, année), solde de départ facultatif.
- Reste ce mois-ci, revenus / dépenses / solde, catégories avec limites, factures à venir, objectifs d'épargne, valeur nette.
- Évolution (Premium), dépense rapide depuis un widget (`QuickExpenseIntent`).

## Fichiers sources

- [App/Screens/MiniApps/Finances/FinancesApp.swift](../../../App/Screens/MiniApps/Finances/FinancesApp.swift)
- [App/Screens/MiniApps/Finances/FinancesPages.swift](../../../App/Screens/MiniApps/Finances/FinancesPages.swift)
- [App/Screens/Spaces/BudgetSpace.swift](../../../App/Screens/Spaces/BudgetSpace.swift)
- [App/Screens/Content/MoneyView.swift](../../../App/Screens/Content/MoneyView.swift)
- [Shared/Domains/Budget.swift](../../../Shared/Domains/Budget.swift)
- [Shared/Data/MoneyMath.swift](../../../Shared/Data/MoneyMath.swift)
- [Shared/Render/Tiles/MoneyTiles.swift](../../../Shared/Render/Tiles/MoneyTiles.swift)

## Relations

- [[Domaines-metier]] : BudgetState
- [[Premium-et-abonnements]] : historique et évolution
- [[Intents-et-activite-en-direct]] : QuickExpenseIntent

## Fichiers du module (6)

- [[MoneyView (swift)]]
- [[FinancesApp (swift)]]
- [[FinancesPages (swift)]]
- [[BudgetSpace (swift)]]
- [[MoneyMath (swift)]]
- [[MoneyTiles (swift)]]

## Dépend de (mesuré dans le code)

- [[Widgets-extension]] : 4 fichier(s)
- [[Domaines-metier]] : 3 fichier(s)
- [[Creer-espaces]] : 2 fichier(s)
- Mini-apps : 2 fichier(s)
- Noyau : AppModel et Router : 2 fichier(s)
- Outils partagés (Shared/Support) : 2 fichier(s)
- Accueil : Mon Quotidien : 1 fichier(s)
- Données et stockage : 1 fichier(s)
- Planning, tâches et habitudes : 1 fichier(s)
- Premium et abonnements : 1 fichier(s)
- Profil et réglages : 1 fichier(s)
- Studio (éditeur de widgets) : 1 fichier(s)

## Services et frameworks

- [[Swift Charts]] : 2 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

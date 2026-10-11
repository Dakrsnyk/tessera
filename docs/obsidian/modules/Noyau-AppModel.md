---
tags: [ardane, module, zone/metier]
---

# Noyau : AppModel et Router

Zone : **Logique métier et état** · Cartes : [[Vue-Globale.canvas|Vue globale]] · [[Architecture.canvas|Architecture]] · [[Fonctionnalites.canvas|Fonctionnalités]]

Source unique des données de l'app et navigation. `AppModel` (@Observable, @MainActor) garde l'état de chaque domaine, l'écrit dans le stockage partagé, recharge les widgets et tient les caches réseau ; `Router` décide de l'onglet, des feuilles et des liens profonds.

## Ce qui existe (vérifié dans le code)

- État : designs (widgets), contenu (tâches, habitudes, eau, argent), réglages, Premium, 11 domaines métier, profil, « Mes styles ».
- Caches réseau : météo, crypto, marchés, entreprises, taux de change, météo de voyage, analyses.
- Limites gratuites : `freeDesignLimit = 8` widgets, `freeHabitLimit = 5` habitudes.
- Rappels intelligents (SmartReminders), activité en direct de la séance, « bons moments » pour la demande de note.
- Router : onglets `home`, `spaces` (Créer), `explore` (Store), `mine` (Mes widgets) ; `openEditor`, `openApp`, `showPaywall`, `handle(DeepLink)`.

## Fichiers sources

- [App/Core/AppModel.swift](../../../App/Core/AppModel.swift)
- [App/Core/Router.swift](../../../App/Core/Router.swift)
- [App/TesseraApp.swift](../../../App/TesseraApp.swift)
- [App/Core/AppModel+Debug.swift](../../../App/Core/AppModel+Debug.swift)

## Relations

- [[Donnees-et-stockage]] : écrit chaque domaine en JSON
- [[Domaines-metier]] : tient les états
- [[Widgets-extension]] : recharge les widgets (WidgetCenter)
- [[Services-externes]] : remplit les caches réseau
- [[Intents-et-activite-en-direct]] : démarre l'activité en direct
- [[Premium-et-abonnements]] : état Premium

## Fichiers du module (4)

- [[AppModel+Debug (swift)]]
- [[AppModel (swift)]]
- [[Router (swift)]]
- [[TesseraApp (swift)]]

## Dépend de (mesuré dans le code)

- [[Domaines-metier]] : 12 fichier(s)
- [[Profil-et-reglages]] : 9 fichier(s)
- [[Planning-et-habitudes]] : 6 fichier(s)
- Données et stockage : 5 fichier(s)
- Lancement, premier lancement et tutoriel : 4 fichier(s)
- Premium et abonnements : 4 fichier(s)
- Studio (éditeur de widgets) : 4 fichier(s)
- Tests, CI et outils : 4 fichier(s)
- Créer : les espaces : 3 fichier(s)
- Services externes et frameworks Apple : 3 fichier(s)
- Accueil : Mon Quotidien : 2 fichier(s)
- Boutons des widgets, activité en direct et liens : 2 fichier(s)
- Store : 2 fichier(s)
- Finances : 1 fichier(s)
- Mes widgets : 1 fichier(s)
- Mini-apps : 1 fichier(s)
- Nutrition : 1 fichier(s)
- Outils partagés (Shared/Support) : 1 fichier(s)
- Widgets : extension et rendu : 1 fichier(s)

## Services et frameworks

- [[WidgetKit]] : 2 fichier(s)
- [[App Group]] : 1 fichier(s)
- [[StoreKit]] : 1 fichier(s)

Partie de [[Ardane]].

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).

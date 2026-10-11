---
tags: [ardane, module, metier]
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

> À mettre à jour quand ce module change (voir `CLAUDE.md` et `scripts/obsidian_map.py`).
